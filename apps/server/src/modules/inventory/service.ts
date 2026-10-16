import { sql } from 'drizzle-orm';
import type { Db } from '../../core/database.js';
import { AppError, requireValue } from '../../core/errors.js';
import { audit } from '../../core/transactions.js';
import type { Actor } from '../../../../../packages/shared/src/schemas.js';
export async function item(tx:Db,org:string,id:string){return requireValue((await tx.all(sql`SELECT * FROM inventory_items WHERE org_id=${org} AND id=${id}`))[0]);}
export async function rawItem(tx:Db,org:string,kind:'GRADE_A'|'GRADE_B'){return requireValue((await tx.all(sql`SELECT * FROM inventory_items WHERE org_id=${org} AND kind=${kind}`))[0],'Stok awal organisasi belum disiapkan.');}
export async function move(tx:Db,a:Actor,itemId:string,delta:bigint,type:string,sourceType:string,sourceId:string,reason=''){
 const current=await item(tx,a.org_id,itemId);
 if(BigInt(current.balance)+delta<0n)throw new AppError(409,'INSUFFICIENT_STOCK','Stok tidak cukup. Muat ulang dan periksa jumlah yang tersedia.',{item_id:itemId,available:String(current.balance)});
 await tx.all(sql`INSERT INTO inventory_movements(org_id,item_id,delta,movement_type,source_type,source_id,actor_id,reason) VALUES(${a.org_id},${itemId},${delta.toString()},${type},${sourceType},${sourceId},${a.id},${reason})`);
}
export async function reconcilePlans(tx:Db,a:Actor,reason:string){
 const b=await rawItem(tx,a.org_id,'GRADE_B');
 const [total]=await tx.all(sql`SELECT coalesce(sum(planned_g),0)::text AS total FROM production_plans WHERE org_id=${a.org_id} AND status='OPEN'`);
 if(BigInt(total.total)<=BigInt(b.balance))return [];
 const changed=await tx.all(sql`UPDATE production_plans SET status='NEEDS_REVIEW' WHERE org_id=${a.org_id} AND status='OPEN' RETURNING id,planned_g,product_id`);
 for(const p of changed)await audit(tx,a,'PLAN_NEEDS_REVIEW','PRODUCTION_PLAN',p.id,{status:'OPEN'},{status:'NEEDS_REVIEW',planned_g:p.planned_g},reason);
 return changed.map(p=>p.id);
}
export async function inventoryList(db:Db,org:string){return db.all(sql`SELECT i.*,coalesce(p.name,CASE WHEN i.kind='GRADE_A' THEN 'Kentang Grade A' ELSE 'Kentang Grade B' END) AS name,p.archived,coalesce((SELECT sum(planned_g) FROM production_plans pp WHERE pp.org_id=i.org_id AND pp.status='OPEN' AND i.kind='GRADE_B'),0)::text AS planned_g FROM inventory_items i LEFT JOIN products p ON p.org_id=i.org_id AND p.id=i.product_id WHERE i.org_id=${org} ORDER BY i.kind,p.name`);}
export async function movements(db:Db,org:string,itemId:string,limit:number,offset:number){
 await item(db,org,itemId);
 return db.all(sql`SELECT m.*,u.name AS actor_name FROM inventory_movements m JOIN users u ON u.id=m.actor_id WHERE m.org_id=${org} AND m.item_id=${itemId} ORDER BY m.created_at DESC,m.id DESC LIMIT ${limit} OFFSET ${offset}`);
}
