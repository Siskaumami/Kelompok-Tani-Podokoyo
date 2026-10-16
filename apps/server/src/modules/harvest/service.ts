import { sql } from 'drizzle-orm';
import type { z } from 'zod';
import type { Db } from '../../core/database.js';
import { assert, requireValue } from '../../core/errors.js';
import { audit } from '../../core/transactions.js';
import { rawItem,move,reconcilePlans } from '../inventory/service.js';
import { harvestSchema, type Actor } from '../../../../../packages/shared/src/schemas.js';
export function validateHarvest(d:z.infer<typeof harvestSchema>,final=false){
 const classified=BigInt(d.grade_a_g)+BigInt(d.grade_b_g)+BigInt(d.reject_g),total=BigInt(d.total_g);
 assert(final?classified===total:classified<=total,final?'Grade A, Grade B dan afkir harus sama dengan total panen.':'Jumlah hasil sortir melebihi total panen.','HARVEST_BALANCE');
}
export async function getHarvest(db:Db,org:string,id:string){return requireValue((await db.all(sql`SELECT * FROM harvests WHERE org_id=${org} AND id=${id}`))[0]);}
export async function listHarvests(db:Db,org:string,limit:number,offset:number){return db.all(sql`SELECT h.*,f.name AS farmer_name,(h.total_g-h.grade_a_g-h.grade_b_g-h.reject_g)::text AS remaining_g FROM harvests h LEFT JOIN farmers f ON f.org_id=h.org_id AND f.id=h.farmer_id WHERE h.org_id=${org} ORDER BY h.business_date DESC,h.created_at DESC,h.id LIMIT ${limit} OFFSET ${offset}`);}
export async function saveHarvest(tx:Db,a:Actor,id:string|null,d:z.infer<typeof harvestSchema>){
 validateHarvest(d);
 const before=id?await getHarvest(tx,a.org_id,id):null;
 if(before)assert(before.status==='DRAFT','Panen final tidak dapat diedit. Batalkan dengan alasan lalu catat penggantinya.');
 const [v]=id?await tx.all(sql`UPDATE harvests SET farmer_id=${d.farmer_id},business_date=${d.business_date},total_g=${d.total_g},grade_a_g=${d.grade_a_g},grade_b_g=${d.grade_b_g},reject_g=${d.reject_g},notes=${d.notes} WHERE org_id=${a.org_id} AND id=${id} RETURNING *`):await tx.all(sql`INSERT INTO harvests(org_id,farmer_id,business_date,total_g,grade_a_g,grade_b_g,reject_g,notes,created_by) VALUES(${a.org_id},${d.farmer_id},${d.business_date},${d.total_g},${d.grade_a_g},${d.grade_b_g},${d.reject_g},${d.notes},${a.id}) RETURNING *`);
 await audit(tx,a,id?'HARVEST_DRAFT_UPDATED':'HARVEST_DRAFT_CREATED','HARVEST',v.id,before,v);return v;
}
export async function finalizeHarvest(tx:Db,a:Actor,id:string){
 const h=await getHarvest(tx,a.org_id,id);assert(h.status==='DRAFT','Panen ini sudah difinalisasi atau dibatalkan.');
 assert(BigInt(h.grade_a_g)+BigInt(h.grade_b_g)+BigInt(h.reject_g)===BigInt(h.total_g),'Selesaikan klasifikasi seluruh hasil panen sebelum finalisasi.','HARVEST_BALANCE');
 const ga=await rawItem(tx,a.org_id,'GRADE_A'),gb=await rawItem(tx,a.org_id,'GRADE_B');
 await move(tx,a,ga.id,BigInt(h.grade_a_g),'HARVEST_GRADE_A','HARVEST',id);
 await move(tx,a,gb.id,BigInt(h.grade_b_g),'HARVEST_GRADE_B','HARVEST',id);
 const [after]=await tx.all(sql`UPDATE harvests SET status='FINALIZED',finalized_at=now() WHERE org_id=${a.org_id} AND id=${id} RETURNING *`);
 await audit(tx,a,'HARVEST_FINALIZED','HARVEST',id,h,after);return after;
}
export async function voidHarvest(tx:Db,a:Actor,id:string,reason:string){
 const h=await getHarvest(tx,a.org_id,id);assert(h.status==='FINALIZED','Hanya panen final yang dapat dibatalkan.');
 for(const m of await tx.all(sql`SELECT * FROM inventory_movements WHERE org_id=${a.org_id} AND source_type='HARVEST' AND source_id=${id} AND movement_type<>'CORRECTION'`))await move(tx,a,m.item_id,-BigInt(m.delta),'CORRECTION','HARVEST',id,reason);
 const [after]=await tx.all(sql`UPDATE harvests SET status='VOIDED',void_reason=${reason} WHERE org_id=${a.org_id} AND id=${id} RETURNING *`);
 const plans_needing_review=await reconcilePlans(tx,a,'Pembatalan panen mengubah stok fisik.');
 await audit(tx,a,'HARVEST_VOIDED','HARVEST',id,h,after,reason);return {...after,plans_needing_review};
}
