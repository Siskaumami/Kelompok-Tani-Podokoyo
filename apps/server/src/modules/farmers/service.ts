import { sql } from 'drizzle-orm';
import type { z } from 'zod';
import type { Db } from '../../core/database.js';
import { requireValue } from '../../core/errors.js';
import { audit } from '../../core/transactions.js';
import type { Actor } from '../../../../../packages/shared/src/schemas.js';
import { farmerSchema } from '../../../../../packages/shared/src/schemas.js';
export const listFarmers=(db:Db,org:string)=>db.all(sql`SELECT * FROM farmers WHERE org_id=${org} ORDER BY name,id`);
export async function saveFarmer(tx:Db,a:Actor,id:string|null,data:z.infer<typeof farmerSchema>){
 const before=id?requireValue((await tx.all(sql`SELECT * FROM farmers WHERE org_id=${a.org_id} AND id=${id}`))[0]):null;
 const [f]=id?await tx.all(sql`UPDATE farmers SET name=${data.name},bio=${data.bio},image_id=${data.image_id},publication=${data.publication} WHERE org_id=${a.org_id} AND id=${id} RETURNING *`):await tx.all(sql`INSERT INTO farmers(org_id,name,bio,image_id,publication) VALUES(${a.org_id},${data.name},${data.bio},${data.image_id},${data.publication}) RETURNING *`);
 await audit(tx,a,id?'FARMER_UPDATED':'FARMER_CREATED','FARMER',f.id,before,f);return f;
}
export async function archiveFarmer(tx:Db,a:Actor,id:string){
 const before=requireValue((await tx.all(sql`SELECT * FROM farmers WHERE org_id=${a.org_id} AND id=${id}`))[0]);
 const [f]=await tx.all(sql`UPDATE farmers SET archived=true,publication='DRAFT' WHERE org_id=${a.org_id} AND id=${id} RETURNING *`);
 await audit(tx,a,'FARMER_ARCHIVED','FARMER',id,before,f);return f;
}
