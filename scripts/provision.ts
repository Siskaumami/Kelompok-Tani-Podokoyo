import { sql } from 'drizzle-orm';
import { z } from 'zod';
import { email,password,text } from '../packages/shared/src/schemas.js';
import { connectDatabase } from '../apps/server/src/core/database.js';
import { hashPassword,verifyPassword } from '../apps/server/src/modules/auth/service.js';
const {db,pool}=connectDatabase();
try{
 if(process.env.PROVISION_CONFIRM!=='CREATE_ORGANIZATION')throw new Error('Explicit provisioning confirmation is required.');
 const d=z.object({platform_email:email,platform_password:z.string().min(1),name:text,slug:z.string().regex(/^[a-z0-9-]{1,100}$/),owner_email:email,owner_name:text,owner_password:password}).parse({platform_email:process.env.PLATFORM_EMAIL,platform_password:process.env.PLATFORM_PASSWORD,name:process.env.ORG_NAME,slug:process.env.ORG_SLUG,owner_email:process.env.OWNER_EMAIL,owner_name:process.env.OWNER_NAME,owner_password:process.env.OWNER_PASSWORD});
 const [platform]=await db.all(sql`SELECT id,password_hash,active FROM users WHERE email=${d.platform_email} AND role='SUPER_ADMIN'`);
 if(!platform?.active||!await verifyPassword(platform.password_hash,d.platform_password))throw new Error('Platform authentication failed.');
 const ownerHash=await hashPassword(d.owner_password);
 await db.transaction(async tx=>{
  const [org]=await tx.all(sql`INSERT INTO organizations(name,slug) VALUES(${d.name},${d.slug}) RETURNING id`);
  const [owner]=await tx.all(sql`INSERT INTO users(org_id,email,name,password_hash,role) VALUES(${org.id},${d.owner_email},${d.owner_name},${ownerHash},'OWNER') RETURNING id`);
  await tx.all(sql`INSERT INTO inventory_items(org_id,kind) VALUES(${org.id},'GRADE_A'),(${org.id},'GRADE_B')`);
  await tx.all(sql`INSERT INTO audit_logs(org_id,actor_id,action,entity_type,entity_id,after_data) VALUES(${org.id},${platform.id},'ORGANIZATION_PROVISIONED','ORGANIZATION',${org.id},${JSON.stringify({owner_id:owner.id,slug:d.slug})}::jsonb)`);
 });
 console.info('Organization and real Owner created. Set PUBLIC_ORG_SLUG to the chosen slug. Remove provisioning credentials from the environment.');
}catch(error){ console.error(error); process.exitCode=1; }
finally{await pool?.end();}
