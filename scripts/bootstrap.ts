import { sql } from 'drizzle-orm';
import { email,password,text } from '../packages/shared/src/schemas.js';
import { connectDatabase } from '../apps/server/src/core/database.js';
import { hashPassword } from '../apps/server/src/modules/auth/service.js';
const {db,pool}=connectDatabase();
try{
 if(process.env.BOOTSTRAP_CONFIRM!=='CREATE_SUPER_ADMIN')throw new Error('Set BOOTSTRAP_CONFIRM=CREATE_SUPER_ADMIN for this intentional one-time command.');
 const d={email:email.parse(process.env.BOOTSTRAP_EMAIL),name:text.parse(process.env.BOOTSTRAP_NAME),password:password.parse(process.env.BOOTSTRAP_PASSWORD)};
 const hashed=await hashPassword(d.password);
 await db.transaction(async tx=>{
  await tx.all(sql`SELECT pg_advisory_xact_lock(1548733)`);
  if((await tx.all(sql`SELECT id FROM users WHERE role='SUPER_ADMIN'`)).length)throw new Error('A SUPER_ADMIN already exists. Command refused.');
  await tx.all(sql`INSERT INTO users(email,name,password_hash,role) VALUES(${d.email},${d.name},${hashed},'SUPER_ADMIN')`);
 });
 console.info('Initial platform account created. No business records were inserted. Remove bootstrap variables from the environment.');
}catch{console.error('Bootstrap refused. Check required variables, password policy, database connectivity, and whether the platform account already exists.');process.exitCode=1;}finally{await pool?.end();}
