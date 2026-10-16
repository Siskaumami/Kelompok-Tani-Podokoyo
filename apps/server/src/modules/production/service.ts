import { sql } from 'drizzle-orm';
import type { z } from 'zod';
import type { Db } from '../../core/database.js';
import { assert, checked, requireValue } from '../../core/errors.js';
import { audit } from '../../core/transactions.js';
import { rawItem,move,reconcilePlans } from '../inventory/service.js';
import { product,economics } from '../products/service.js';
import { planSchema,productionSchema, type Actor,type Row } from '../../../../../packages/shared/src/schemas.js';
export async function listPlans(db:Db,org:string,limit:number,offset:number){return db.all(sql`SELECT pp.*,p.name AS product_name FROM production_plans pp JOIN products p ON p.org_id=pp.org_id AND p.id=pp.product_id WHERE pp.org_id=${org} ORDER BY pp.created_at DESC,pp.id LIMIT ${limit} OFFSET ${offset}`);}
export async function listBatches(db:Db,org:string,limit:number,offset:number){return db.all(sql`SELECT *, (actual_g-theoretical_g)::text AS variance_g FROM production_batches WHERE org_id=${org} ORDER BY business_date DESC,created_at DESC,id LIMIT ${limit} OFFSET ${offset}`);}
export async function savePlan(tx:Db,a:Actor,id:string|null,d:z.infer<typeof planSchema>){
 const p=await product(tx,a.org_id,d.product_id);assert(!p.archived,'Produk sudah diarsipkan.');
 const before=id?requireValue((await tx.all(sql`SELECT * FROM production_plans WHERE org_id=${a.org_id} AND id=${id}`))[0]):null;
 if(before)assert(['OPEN','NEEDS_REVIEW'].includes(before.status),'Rencana ini sudah selesai atau dibatalkan.');
 const b=await rawItem(tx,a.org_id,'GRADE_B');
 const [t]=await tx.all(sql`SELECT coalesce(sum(planned_g),0)::text AS total FROM production_plans WHERE org_id=${a.org_id} AND status='OPEN' AND (${id}::uuid IS NULL OR id<>${id}::uuid)`);
 assert(BigInt(t.total)+BigInt(d.planned_g)<=BigInt(b.balance),'Alokasi melebihi stok Grade B yang belum direncanakan.','PLAN_EXCEEDS_STOCK');
 const [v]=id?await tx.all(sql`UPDATE production_plans SET product_id=${d.product_id},business_date=${d.business_date},planned_g=${d.planned_g},notes=${d.notes},status='OPEN' WHERE org_id=${a.org_id} AND id=${id} RETURNING *`):await tx.all(sql`INSERT INTO production_plans(org_id,product_id,business_date,planned_g,notes,created_by) VALUES(${a.org_id},${d.product_id},${d.business_date},${d.planned_g},${d.notes},${a.id}) RETURNING *`);
 await audit(tx,a,id?'PLAN_UPDATED':'PLAN_CREATED','PRODUCTION_PLAN',v.id,before,v);return v;
}
export async function cancelPlan(tx:Db,a:Actor,id:string,reason:string){
 const p=requireValue((await tx.all(sql`SELECT * FROM production_plans WHERE org_id=${a.org_id} AND id=${id}`))[0]);
 assert(['OPEN','NEEDS_REVIEW'].includes(p.status),'Rencana sudah ditutup.');
 const [after]=await tx.all(sql`UPDATE production_plans SET status='CANCELLED' WHERE org_id=${a.org_id} AND id=${id} RETURNING *`);
 await audit(tx,a,'PLAN_CANCELLED','PRODUCTION_PLAN',id,p,after,reason);return after;
}
export async function completeProduction(tx:Db,a:Actor,d:z.infer<typeof productionSchema>):Promise<Row>{
 const p=await product(tx,a.org_id,d.product_id),v=await economics(tx,a.org_id,d.product_id);assert(!p.archived,'Produk sudah diarsipkan.');
 if(d.plan_id){const plan=requireValue((await tx.all(sql`SELECT * FROM production_plans WHERE org_id=${a.org_id} AND id=${d.plan_id} AND product_id=${d.product_id}`))[0]);assert(['OPEN','NEEDS_REVIEW'].includes(plan.status),'Rencana sudah ditutup.');}
 const theoretical=checked(BigInt(v.material_g)*BigInt(d.output_units));
 const [batch]=await tx.all(sql`INSERT INTO production_batches(org_id,product_id,version_id,plan_id,business_date,actual_g,output_units,theoretical_g,hpp_rp,product_name_snapshot,notes,created_by) VALUES(${a.org_id},${p.id},${v.id},${d.plan_id},${d.business_date},${d.actual_g},${d.output_units},${theoretical},${v.hpp_rp},${p.name},${d.notes},${a.id}) RETURNING *`);
 const raw=await rawItem(tx,a.org_id,'GRADE_B');
 const finished=requireValue((await tx.all(sql`SELECT * FROM inventory_items WHERE org_id=${a.org_id} AND product_id=${p.id}`))[0]);
 await move(tx,a,raw.id,-BigInt(d.actual_g),'PRODUCTION_CONSUMPTION','PRODUCTION',batch.id);
 await move(tx,a,finished.id,BigInt(d.output_units),'PRODUCTION_OUTPUT','PRODUCTION',batch.id);
 if(d.plan_id)await tx.all(sql`UPDATE production_plans SET status='COMPLETED' WHERE org_id=${a.org_id} AND id=${d.plan_id}`);
 const plans_needing_review=await reconcilePlans(tx,a,'Pemakaian produksi aktual mengubah kapasitas rencana.');
 await audit(tx,a,'PRODUCTION_COMPLETED','PRODUCTION',batch.id,null,batch);return {...batch,plans_needing_review};
}
export async function voidProduction(tx:Db,a:Actor,id:string,reason:string){
 const p=requireValue((await tx.all(sql`SELECT * FROM production_batches WHERE org_id=${a.org_id} AND id=${id}`))[0]);assert(p.status==='COMPLETED','Produksi ini sudah dibatalkan.');
 for(const m of await tx.all(sql`SELECT * FROM inventory_movements WHERE org_id=${a.org_id} AND source_type='PRODUCTION' AND source_id=${id} AND movement_type<>'CORRECTION' ORDER BY delta DESC`))await move(tx,a,m.item_id,-BigInt(m.delta),'CORRECTION','PRODUCTION',id,reason);
 const [after]=await tx.all(sql`UPDATE production_batches SET status='VOIDED',void_reason=${reason} WHERE org_id=${a.org_id} AND id=${id} RETURNING *`);
 await audit(tx,a,'PRODUCTION_VOIDED','PRODUCTION',id,p,after,reason);return after;
}
