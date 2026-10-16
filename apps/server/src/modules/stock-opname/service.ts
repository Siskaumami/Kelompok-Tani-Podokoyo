import { sql } from 'drizzle-orm';
import type { z } from 'zod';
import type { Db } from '../../core/database.js';
import { assert,requireValue } from '../../core/errors.js';
import { audit } from '../../core/transactions.js';
import { item,move,reconcilePlans } from '../inventory/service.js';
import { opnameCompleteSchema,type Actor } from '../../../../../packages/shared/src/schemas.js';
export async function listOpnames(db:Db,org:string,limit:number,offset:number){return db.all(sql`SELECT o.*,coalesce(p.name,CASE WHEN i.kind='GRADE_A' THEN 'Kentang Grade A' ELSE 'Kentang Grade B' END) AS item_name,i.kind FROM stock_opnames o JOIN inventory_items i ON i.org_id=o.org_id AND i.id=o.item_id LEFT JOIN products p ON p.org_id=i.org_id AND p.id=i.product_id WHERE o.org_id=${org} ORDER BY o.created_at DESC,o.id LIMIT ${limit} OFFSET ${offset}`);}
export async function startOpname(tx:Db,a:Actor,itemId:string){
 const i=await item(tx,a.org_id,itemId);
 const active=(await tx.all(sql`SELECT id FROM stock_opnames WHERE org_id=${a.org_id} AND item_id=${itemId} AND status='OPEN'`))[0];assert(!active,'Masih ada pemeriksaan stok aktif untuk barang ini.');
 const [o]=await tx.all(sql`INSERT INTO stock_opnames(org_id,item_id,baseline_quantity,baseline_revision,created_by) VALUES(${a.org_id},${itemId},${i.balance},${i.revision},${a.id}) RETURNING *`);
 await audit(tx,a,'OPNAME_STARTED','OPNAME',o.id,null,o);return o;
}
export async function getOpname(db:Db,org:string,id:string){return requireValue((await db.all(sql`SELECT * FROM stock_opnames WHERE org_id=${org} AND id=${id}`))[0]);}
export async function refreshOpname(tx:Db,a:Actor,id:string){
 const o=await getOpname(tx,a.org_id,id);assert(o.status==='OPEN','Pemeriksaan stok sudah ditutup.');const i=await item(tx,a.org_id,o.item_id);
 const [after]=await tx.all(sql`UPDATE stock_opnames SET baseline_quantity=${i.balance},baseline_revision=${i.revision} WHERE org_id=${a.org_id} AND id=${id} RETURNING *`);
 await audit(tx,a,'OPNAME_BASELINE_REFRESHED','OPNAME',id,o,after,'Hitung ulang stok fisik terhadap baseline terbaru.');return after;
}
export async function completeOpname(tx:Db,a:Actor,id:string,d:z.infer<typeof opnameCompleteSchema>){
 const o=await getOpname(tx,a.org_id,id);assert(o.status==='OPEN','Pemeriksaan stok sudah ditutup.');
 const i=await item(tx,a.org_id,o.item_id);
 assert(String(i.revision)===String(o.baseline_revision),'Stok berubah selama pemeriksaan. Gunakan stok terbaru dan hitung ulang sebelum menyimpan.','STALE_BASELINE');
 const difference=BigInt(d.physical_quantity)-BigInt(o.baseline_quantity);
 const reason=d.reason??null;
 assert(difference===0n?reason===null:reason!==null,difference===0n?'Alasan selisih tidak boleh diisi jika stok fisik sesuai.':'Pilih alasan selisih sebelum menyimpan.');
 const explanation=difference===0n?'Stok fisik sesuai dengan stok tercatat.':reason+(d.notes?': '+d.notes:'');
 await move(tx,a,o.item_id,difference,'OPNAME_ADJUSTMENT','OPNAME',id,explanation);
 const [after]=await tx.all(sql`UPDATE stock_opnames SET physical_quantity=${d.physical_quantity},difference=${difference.toString()},reason=${reason},notes=${d.notes},status='COMPLETED',completed_by=${a.id},completed_at=now() WHERE org_id=${a.org_id} AND id=${id} RETURNING *`);
 const plans_needing_review=await reconcilePlans(tx,a,'Hasil cek stok mengubah stok fisik.');
 await audit(tx,a,'OPNAME_COMPLETED','OPNAME',id,o,after,explanation);
 return {...after,plans_needing_review};
}
export async function cancelOpname(tx:Db,a:Actor,id:string,reason:string){
 const o=await getOpname(tx,a.org_id,id);assert(o.status==='OPEN','Pemeriksaan stok sudah ditutup.');
 const [after]=await tx.all(sql`UPDATE stock_opnames SET status='CANCELLED' WHERE org_id=${a.org_id} AND id=${id} RETURNING *`);
 await audit(tx,a,'OPNAME_CANCELLED','OPNAME',id,o,after,reason);return after;
}
