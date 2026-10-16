import { sql } from 'drizzle-orm';
import type { z } from 'zod';
import type { Db } from '../../core/database.js';
import { assert, checked, kgAmount, requireValue } from '../../core/errors.js';
import { audit } from '../../core/transactions.js';
import { item,move } from '../inventory/service.js';
import { product,economics } from '../products/service.js';
import { organization,localDate } from '../organizations/service.js';
import { saleSchema,confirmationSchema,type Actor,type Row } from '../../../../../packages/shared/src/schemas.js';
export async function listSales(db:Db,org:string,limit:number,offset:number){return db.all(sql`SELECT * FROM sales WHERE org_id=${org} ORDER BY business_date DESC,created_at DESC,id LIMIT ${limit} OFFSET ${offset}`);}
export async function saleDetail(db:Db,org:string,id:string):Promise<Row>{
 const sale=requireValue((await db.all(sql`SELECT * FROM sales WHERE org_id=${org} AND id=${id}`))[0]);
 return {...sale,items:await db.all(sql`SELECT * FROM sale_lines WHERE org_id=${org} AND sale_id=${id} ORDER BY id`)};
}
export async function recordSale(tx:Db,a:Actor,d:z.infer<typeof saleSchema>):Promise<Row>{
 const org=await organization(tx,a.org_id),lines:Row[]=[];
 let gross=0n,hpp=0n;
 for(const input of d.items){
  const i=await item(tx,a.org_id,input.item_id);assert(i.kind!=='GRADE_B','Grade B dialokasikan untuk produksi, bukan penjualan langsung.');
  let unitPrice:string,unitHpp:string,name:string,versionId:string|null=null;
  if(i.kind==='FINISHED'){const p=await product(tx,a.org_id,i.product_id),v=await economics(tx,a.org_id,p.id);name=p.name;unitPrice=input.unit_price_rp??String(v.price_rp);unitHpp=String(v.hpp_rp);versionId=v.id;}
  else{name='Kentang Grade A';unitPrice=input.unit_price_rp??String(org.grade_a_price_rp);unitHpp=String(org.grade_a_hpp_rp);}
  const q=BigInt(input.quantity),lineGross=i.kind==='GRADE_A'?kgAmount(q,BigInt(unitPrice)):q*BigInt(unitPrice),lineHpp=i.kind==='GRADE_A'?kgAmount(q,BigInt(unitHpp)):q*BigInt(unitHpp);
  gross+=lineGross;hpp+=lineHpp;
  lines.push({item_id:i.id,product_id:i.product_id,version_id:versionId,kind:i.kind,name_snapshot:name,quantity:input.quantity,unit_price_rp:unitPrice,unit_hpp_rp:unitHpp,gross_rp:checked(lineGross),hpp_rp:checked(lineHpp)});
 }
 checked(gross);checked(hpp);
 assert(BigInt(d.discount_rp)+BigInt(d.fee_rp)<=gross,'Diskon dan biaya tidak boleh melebihi nilai penjualan.','INVALID_TOTAL');
 const [sale]=await tx.all(sql`INSERT INTO sales(org_id,business_date,channel,external_ref,discount_rp,fee_rp,gross_rp,hpp_rp,notes,created_by) VALUES(${a.org_id},${d.business_date},${d.channel},${d.external_ref},${d.discount_rp},${d.fee_rp},${gross.toString()},${hpp.toString()},${d.notes},${a.id}) RETURNING *`);
 for(const l of lines){
  await tx.all(sql`INSERT INTO sale_lines(org_id,sale_id,item_id,product_id,version_id,kind,name_snapshot,quantity,unit_price_rp,unit_hpp_rp,gross_rp,hpp_rp) VALUES(${a.org_id},${sale.id},${l.item_id},${l.product_id},${l.version_id},${l.kind},${l.name_snapshot},${l.quantity},${l.unit_price_rp},${l.unit_hpp_rp},${l.gross_rp},${l.hpp_rp})`);
  await move(tx,a,l.item_id,-BigInt(l.quantity),l.kind==='GRADE_A'?'GRADE_A_SALE':'FINISHED_GOOD_SALE','SALE',sale.id);
 }
 const previous=(await tx.all(sql`SELECT * FROM sales_day_confirmations WHERE org_id=${a.org_id} AND business_date=${d.business_date}`))[0];
 if(previous?.status==='NO_SALES'){
  await tx.all(sql`UPDATE sales_day_confirmations SET status='COMPLETED',actor_id=${a.id},updated_at=now() WHERE org_id=${a.org_id} AND business_date=${d.business_date}`);
  await audit(tx,a,'SALES_DAY_RECONCILED','SALES_DAY',null,previous,{business_date:d.business_date,status:'COMPLETED'},'Penjualan dicatat setelah konfirmasi tidak ada penjualan.');
 }
 await audit(tx,a,'SALE_RECORDED','SALE',sale.id,null,{...sale,items:lines});return {...sale,items:lines};
}
export async function voidSale(tx:Db,a:Actor,id:string,reason:string){
 const s=await saleDetail(tx,a.org_id,id);assert(s.status==='COMPLETED','Penjualan ini sudah dibatalkan.');
 for(const m of await tx.all(sql`SELECT * FROM inventory_movements WHERE org_id=${a.org_id} AND source_type='SALE' AND source_id=${id} AND movement_type<>'CORRECTION'`))await move(tx,a,m.item_id,-BigInt(m.delta),'CORRECTION','SALE',id,reason);
 const [after]=await tx.all(sql`UPDATE sales SET status='VOIDED',void_reason=${reason} WHERE org_id=${a.org_id} AND id=${id} RETURNING *`);
 await audit(tx,a,'SALE_VOIDED','SALE',id,s,after,reason);return after;
}
export async function confirmSalesDay(tx:Db,a:Actor,d:z.infer<typeof confirmationSchema>){
 const org=await organization(tx,a.org_id);assert(d.business_date<=localDate(org.timezone),'Tanggal konfirmasi tidak boleh di masa depan.');
 if(d.status==='NO_SALES'){const [count]=await tx.all(sql`SELECT count(*)::text AS total FROM sales WHERE org_id=${a.org_id} AND business_date=${d.business_date} AND status='COMPLETED'`);assert(count.total==='0','Sudah ada penjualan pada tanggal ini. Gunakan Selesai mencatat.');}
 const before=(await tx.all(sql`SELECT * FROM sales_day_confirmations WHERE org_id=${a.org_id} AND business_date=${d.business_date}`))[0]??null;
 const [after]=await tx.all(sql`INSERT INTO sales_day_confirmations(org_id,business_date,status,actor_id) VALUES(${a.org_id},${d.business_date},${d.status},${a.id}) ON CONFLICT(org_id,business_date) DO UPDATE SET status=excluded.status,actor_id=excluded.actor_id,updated_at=now() RETURNING *`);
 await tx.all(sql`UPDATE reminders SET dismissed=true WHERE org_id=${a.org_id} AND business_date=${d.business_date}`);
 await audit(tx,a,'SALES_DAY_CONFIRMED','SALES_DAY',null,before,after);return after;
}
