import { randomUUID,randomBytes } from 'node:crypto';
import { readFile,readdir } from 'node:fs/promises';
import { PGlite } from '@electric-sql/pglite';
import { drizzle } from 'drizzle-orm/pglite';
import { sql } from 'drizzle-orm';
import { executorDb,type Db } from '../apps/server/src/core/database.js';
import { hash,mutate } from '../apps/server/src/core/transactions.js';
import { hashPassword } from '../apps/server/src/modules/auth/service.js';
import { createProduct } from '../apps/server/src/modules/products/service.js';
import { createProductSchema,type Actor } from '../packages/shared/src/schemas.js';
import { config } from '../apps/server/src/core/config.js';
export const fixturePassword='Test-only-password-492!';
let fixtureHash:Promise<string>|undefined;
export async function memoryDatabase(){config.NODE_ENV='test';config.BREVO_API_KEY='';config.EMAIL_FROM='';config.FILEBASE_ACCESS_KEY_ID='';config.FILEBASE_SECRET_ACCESS_KEY='';config.FILEBASE_BUCKET='';config.VAPID_PUBLIC_KEY='';config.VAPID_PRIVATE_KEY='';config.VAPID_SUBJECT='';const pg=new PGlite({parsers:{20:(value:string)=>value,1700:(value:string)=>value}});for(const name of (await readdir('database/migrations')).filter(v=>v.endsWith('.sql')).sort())await pg.exec(await readFile('database/migrations/'+name,'utf8'));const driver=drizzle(pg);return {db:executorDb(driver,fn=>driver.transaction(tx=>fn(tx))),close:()=>pg.close()};}
export async function fixture(db:Db){
 fixtureHash??=hashPassword(fixturePassword);const orgId=randomUUID(),ownerId=randomUUID(),adminId=randomUUID();
 await db.all(sql`INSERT INTO organizations(id,name,slug) VALUES(${orgId},'Isolated test organization',${'test-'+orgId})`);
 const passwordHash=await fixtureHash;
 const owner={id:ownerId,org_id:orgId,name:'Test Owner',email:`${ownerId}@example.test`,role:'OWNER'} as Actor;
 const admin={id:adminId,org_id:orgId,name:'Test Admin',email:`${adminId}@example.test`,role:'ADMIN'} as Actor;
 for(const a of [owner,admin])await db.all(sql`INSERT INTO users(id,org_id,name,email,role,password_hash) VALUES(${a.id},${orgId},${a.name},${a.email},${a.role},${passwordHash})`);
 await db.all(sql`INSERT INTO inventory_items(org_id,kind) VALUES(${orgId},'GRADE_A'),(${orgId},'GRADE_B')`);
 const token=randomBytes(32).toString('hex'),csrf=hash('csrf:'+token);
 await db.all(sql`INSERT INTO sessions(token_hash,user_id,csrf_hash,expires_at) VALUES(${hash(token)},${owner.id},${hash(csrf)},now()+interval '12 hours')`);
 const productData=createProductSchema.parse({name:'Isolated test output',sku:randomUUID(),economics:{material_g:'20',material_rp:'1000',packaging_rp:'300',production_rp:'200',other_rp:'0',price_rp:'4000',reason:'Initial isolated fixture'}});
 const product=await mutate(db,owner,randomUUID(),'test-create-product',productData,tx=>createProduct(tx,owner,productData));
 return {orgId,owner,admin,product,token,csrf};
}
