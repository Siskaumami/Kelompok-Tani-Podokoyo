import { beforeAll,afterAll,beforeEach,describe,it,expect } from 'vitest';
import { randomUUID,randomBytes } from 'node:crypto';
import { sql } from 'drizzle-orm';
import { fixture,memoryDatabase } from './helpers.js';
import { mutate,hash,authorize } from '../apps/server/src/core/transactions.js';
import * as harvest from '../apps/server/src/modules/harvest/service.js';
import * as prod from '../apps/server/src/modules/production/service.js';
import * as inventory from '../apps/server/src/modules/inventory/service.js';
import * as sales from '../apps/server/src/modules/sales/service.js';
import * as opname from '../apps/server/src/modules/stock-opname/service.js';
import * as products from '../apps/server/src/modules/products/service.js';
import * as auth from '../apps/server/src/modules/auth/service.js';
import { buildReport,reportPdf } from '../apps/server/src/modules/reports/service.js';
import { notificationState,runReminderJob } from '../apps/server/src/modules/notifications/service.js';
import { config } from '../apps/server/src/core/config.js';
import { publicData } from '../apps/server/src/modules/public-content/service.js';
import { harvestSchema,planSchema,productionSchema,saleSchema,economicsSchema,opnameCompleteSchema,type Actor } from '../packages/shared/src/schemas.js';
import type { Db } from '../apps/server/src/core/database.js';
let db:Db,close:()=>Promise<void>,f:Awaited<ReturnType<typeof fixture>>;
beforeAll(async()=>{({db,close}=await memoryDatabase());});afterAll(async()=>{await close();});beforeEach(async()=>{f=await fixture(db);});
const transact=<T>(op:string,input:unknown,fn:(tx:Db)=>Promise<T>,a?:Actor,key=randomUUID())=>mutate(db,a??f.owner,key,op,input,fn);
async function harvestStock(a='40000',b='55000',reject='5000'){
 const d=harvestSchema.parse({business_date:'2026-10-15',total_g:(BigInt(a)+BigInt(b)+BigInt(reject)).toString(),grade_a_g:a,grade_b_g:b,reject_g:reject});
 const h=await transact('draft',d,tx=>harvest.saveHarvest(tx,f.owner,null,d));await transact('finalize',{id:h.id},tx=>harvest.finalizeHarvest(tx,f.owner,h.id));return h;
}
async function produce(units='10',actual='1000',plan_id:string|null=null){const d=productionSchema.parse({product_id:f.product.id,business_date:'2026-10-15',actual_g:actual,output_units:units,plan_id});return transact('produce',d,tx=>prod.completeProduction(tx,f.owner,d));}
async function finished(){return (await inventory.inventoryList(db,f.orgId)).find(i=>i.product_id===f.product.id)!;}
describe('harvest and immutable ledger',()=>{
 it('permits unfinished draft grading but rejects unbalanced finalization atomically',async()=>{
  const d=harvestSchema.parse({business_date:'2026-10-15',total_g:'100000',grade_a_g:'20000',grade_b_g:'30000',reject_g:'0'});
  const h=await transact('draft',d,tx=>harvest.saveHarvest(tx,f.owner,null,d));
  expect((await inventory.rawItem(db,f.orgId,'GRADE_A')).balance).toBe('0');
  await expect(transact('final',{id:h.id},tx=>harvest.finalizeHarvest(tx,f.owner,h.id))).rejects.toThrow(/klasifikasi/);
  expect((await harvest.getHarvest(db,f.orgId,h.id)).status).toBe('DRAFT');
  expect((await inventory.rawItem(db,f.orgId,'GRADE_A')).balance).toBe('0');
 });
 it('creates the two correct stock movements and prohibits a second finalization',async()=>{
  const h=await harvestStock();expect((await inventory.rawItem(db,f.orgId,'GRADE_A')).balance).toBe('40000');expect((await inventory.rawItem(db,f.orgId,'GRADE_B')).balance).toBe('55000');
  const m=await db.all(sql`SELECT delta FROM inventory_movements WHERE org_id=${f.orgId} ORDER BY movement_type`);expect(m.map(x=>x.delta)).toEqual(['40000','55000']);
  await expect(transact('final-again',{},tx=>harvest.finalizeHarvest(tx,f.owner,h.id))).rejects.toThrow();
 });
 it('blocks direct stock rewriting, history rewriting and negative movement balances',async()=>{
  await harvestStock();const i=await inventory.rawItem(db,f.orgId,'GRADE_A');
  await expect(db.all(sql`UPDATE inventory_items SET balance=0 WHERE id=${i.id}`)).rejects.toThrow();
  await expect(db.all(sql`UPDATE inventory_movements SET delta=0 WHERE org_id=${f.orgId}`)).rejects.toThrow();
  await expect(transact('reduce',{},tx=>inventory.move(tx,f.owner,i.id,-40001n,'GRADE_A_SALE','SALE',randomUUID()))).rejects.toThrow(/Stok/);
  const [v]=await db.all(sql`SELECT coalesce(sum(delta),0)::text AS total FROM inventory_movements WHERE org_id=${f.orgId} AND item_id=${i.id}`);expect(v.total).toBe(i.balance);
 });
 it('voids harvest with reversals and retains the original header and audit',async()=>{
  const h=await harvestStock();await transact('void',{},tx=>harvest.voidHarvest(tx,f.owner,h.id,'Input needs correction'));
  expect((await inventory.rawItem(db,f.orgId,'GRADE_A')).balance).toBe('0');expect((await harvest.getHarvest(db,f.orgId,h.id)).status).toBe('VOIDED');
  await expect(db.all(sql`DELETE FROM harvests WHERE id=${h.id}`)).rejects.toThrow();
  expect((await db.all(sql`SELECT id FROM audit_logs WHERE org_id=${f.orgId} AND action='HARVEST_VOIDED'`)).length).toBe(1);
 });
});
describe('planning versus physical production',()=>{
 it('reserves planning capacity without consuming Grade B and prevents over-allocation',async()=>{
  await harvestStock();const d=planSchema.parse({product_id:f.product.id,business_date:'2026-10-15',planned_g:'40000'});
  await transact('plan',d,tx=>prod.savePlan(tx,f.owner,null,d));expect((await inventory.rawItem(db,f.orgId,'GRADE_B')).balance).toBe('55000');
  await expect(transact('overplan',{...d,planned_g:'16000'},tx=>prod.savePlan(tx,f.owner,null,{...d,planned_g:'16000'}))).rejects.toThrow(/Alokasi/);
 });
 it('allows material variance and records actual input, output, and economics snapshot',async()=>{
  await harvestStock();const b=await produce('480','10000');expect(b.theoretical_g).toBe('9600');expect(b.actual_g).toBe('10000');expect(b.hpp_rp).toBe('1500');expect((await inventory.rawItem(db,f.orgId,'GRADE_B')).balance).toBe('45000');expect((await finished()).balance).toBe('480');
 });
 it('marks excess plans NEEDS_REVIEW after physical consumption without falsifying reality',async()=>{
  await harvestStock();const d=planSchema.parse({product_id:f.product.id,business_date:'2026-10-15',planned_g:'50000'});const p=await transact('plan',d,tx=>prod.savePlan(tx,f.owner,null,d));
  const b=await produce('100','10000');expect(b.plans_needing_review).toEqual([p.id]);expect((await inventory.rawItem(db,f.orgId,'GRADE_B')).balance).toBe('45000');
 });
});
describe('sales history, idempotency and corrections',()=>{
 it('keeps historical price and HPP after new economics and uses them for report/PDF',async()=>{
  await harvestStock();await produce();const i=await finished(),d=saleSchema.parse({business_date:'2026-10-15',channel:'SHOPEE',discount_rp:'1000',fee_rp:'500',items:[{item_id:i.id,quantity:'3'}]});
  const s=await transact('sale',d,tx=>sales.recordSale(tx,f.owner,d));const e=economicsSchema.parse({material_g:'25',material_rp:'2000',packaging_rp:'400',production_rp:'300',other_rp:'0',price_rp:'6000',reason:'New real costing'});await transact('economics',e,tx=>products.appendEconomics(tx,f.owner,f.product.id,e));
  const old=await sales.saleDetail(db,f.orgId,s.id);expect(old.items[0].unit_price_rp).toBe('4000');expect(old.items[0].unit_hpp_rp).toBe('1500');
  const r=await buildReport(db,f.orgId,'2026-10-15','2026-10-15');expect(r.totals).toMatchObject({gross_rp:'12000',discount_rp:'1000',fee_rp:'500',net_rp:'10500',hpp_rp:'4500',profit_rp:'6000'});
  const pdf=await reportPdf(r,f.owner);expect(pdf.subarray(0,4).toString()).toBe('%PDF');expect(pdf.length).toBeGreaterThan(1000);
 });
 it('replays duplicate submissions and rejects a key reused for another payload',async()=>{
  await harvestStock();await produce();const i=await finished(),key=randomUUID(),d=saleSchema.parse({business_date:'2026-10-15',channel:'OFFLINE',items:[{item_id:i.id,quantity:'2'}]});
  const run=()=>transact('sale',d,tx=>sales.recordSale(tx,f.owner,d),f.owner,key);const first=await run(),again=await run();expect(again).toEqual(first);expect((await finished()).balance).toBe('8');
  await expect(transact('sale',{...d,discount_rp:'1'},tx=>sales.recordSale(tx,f.owner,d),f.owner,key)).rejects.toThrow(/Kunci/);
  expect((await db.all(sql`SELECT id FROM sales WHERE org_id=${f.orgId}`)).length).toBe(1);
 });
 it('rejects overselling and restores stock through an audited void',async()=>{
  await harvestStock();await produce();const i=await finished();
  const d=saleSchema.parse({business_date:'2026-10-15',channel:'OFFLINE',items:[{item_id:i.id,quantity:'11'}]});await expect(transact('sale',d,tx=>sales.recordSale(tx,f.owner,d))).rejects.toThrow(/Stok/);expect((await finished()).balance).toBe('10');
  const valid={...d,items:[{item_id:i.id,quantity:'7'}]},s=await transact('sale',valid,tx=>sales.recordSale(tx,f.owner,valid));await transact('void-sale',{},tx=>sales.voidSale(tx,f.owner,s.id,'Order cancelled'));expect((await finished()).balance).toBe('10');
  expect((await buildReport(db,f.orgId,'2026-10-15','2026-10-15')).totals.sale_count).toBe(0);
 });
 it('rounds Grade A per-kg prices using integer arithmetic',async()=>{
  await harvestStock();await db.all(sql`UPDATE organizations SET grade_a_price_rp=15000,grade_a_hpp_rp=10000 WHERE id=${f.orgId}`);const i=await inventory.rawItem(db,f.orgId,'GRADE_A');
  const d=saleSchema.parse({business_date:'2026-10-15',channel:'WHATSAPP',items:[{item_id:i.id,quantity:'1250'}]});const s=await transact('raw-sale',d,tx=>sales.recordSale(tx,f.owner,d));expect(s.gross_rp).toBe('18750');expect(s.hpp_rp).toBe('12500');
 });
});
describe('physical stock checks',()=>{
 it('creates an adjustment, refuses overlapping checks and detects stale revisions',async()=>{
  await harvestStock();const i=await inventory.rawItem(db,f.orgId,'GRADE_A');const o=await transact('start',{},tx=>opname.startOpname(tx,f.owner,i.id));
  await expect(transact('overlap',{},tx=>opname.startOpname(tx,f.owner,i.id))).rejects.toThrow(/aktif/);
  const d=saleSchema.parse({business_date:'2026-10-15',channel:'OFFLINE',items:[{item_id:i.id,quantity:'1000'}]});const s=await transact('sale',d,tx=>sales.recordSale(tx,f.owner,d));await transact('void',{},tx=>sales.voidSale(tx,f.owner,s.id,'Recount scenario'));
  const actual=opnameCompleteSchema.parse({physical_quantity:'38000',reason:'SHRINKAGE_OR_DAMAGE'});await expect(transact('complete',actual,tx=>opname.completeOpname(tx,f.owner,o.id,actual))).rejects.toThrow(/berubah/);
  await transact('refresh',{},tx=>opname.refreshOpname(tx,f.owner,o.id));await transact('complete-refreshed',actual,tx=>opname.completeOpname(tx,f.owner,o.id,actual));expect((await inventory.rawItem(db,f.orgId,'GRADE_A')).balance).toBe('38000');
  const [m]=await db.all(sql`SELECT delta FROM inventory_movements WHERE org_id=${f.orgId} AND source_id=${o.id}`);expect(m.delta).toBe('-2000');
 });
 it('requires an explanation for OTHER',()=>{expect(opnameCompleteSchema.safeParse({physical_quantity:'0',reason:'OTHER'}).success).toBe(false);});
});
describe('authorization, public DTOs and tenancy',()=>{
 it('permits Owner invitations and refuses Admin role management',()=>{expect(()=>authorize(f.owner,'MANAGE_USERS')).not.toThrow();expect(()=>authorize(f.admin,'MANAGE_USERS')).toThrow(/Owner/);});
 it('does not publish drafts or leak economics or internal inventory',async()=>{
  const [org]=await db.all(sql`SELECT slug FROM organizations WHERE id=${f.orgId}`);let p=await publicData(db,org.slug);expect(p.products).toEqual([]);
  await db.all(sql`UPDATE products SET publication='PUBLISHED' WHERE id=${f.product.id}`);p=await publicData(db,org.slug);expect(p.products).toHaveLength(1);const body=JSON.stringify(p);for(const forbidden of ['hpp','balance','material_rp','org_id','password','notes'])expect(body).not.toContain(forbidden);
  expect(Object.keys(p.products[0]).sort()).toEqual(['description','id','imageUrl','name','sellingPrice','shopeeUrl','tokopediaUrl','whatsappUrl'].sort());
 });
 it('blocks cross-organization relationships and scoped access',async()=>{const other=await fixture(db);await expect(products.product(db,other.orgId,f.product.id)).rejects.toThrow(/ditemukan/);await expect(db.all(sql`INSERT INTO production_plans(org_id,product_id,planned_g,business_date,created_by) VALUES(${other.orgId},${f.product.id},1,'2026-10-15',${other.owner.id})`)).rejects.toThrow();});
});
describe('authentication tokens and reminders',()=>{
 it('accepts uniform durable reset requests, without asserting or simulating provider delivery',async()=>{
  const before={key:config.BREVO_API_KEY,from:config.EMAIL_FROM};
  try{config.BREVO_API_KEY='test-only-configuration-not-used-for-delivery';config.EMAIL_FROM='test-sender@example.test';
   expect((await auth.forgotPassword(db,f.owner.email,'queue-test')).queued).toBe(true);
   expect((await auth.forgotPassword(db,'unregistered@example.test','queue-test')).queued).toBe(true);
   expect((await db.all(sql`SELECT id FROM password_reset_requests WHERE status='PENDING'`)).length).toBe(2);
   expect((await db.all(sql`SELECT id FROM auth_tokens WHERE org_id=${f.orgId}`)).length).toBe(0);
  }finally{config.BREVO_API_KEY=before.key;config.EMAIL_FROM=before.from;}
  const result=await auth.runResetEmailJob(db);expect(result.processed).toBe(0);expect(result.failed).toBe(2);
  expect((await db.all(sql`SELECT id FROM password_reset_requests WHERE status='SENT'`)).length).toBe(0);
 });
 it('consumes a reset once, hashes the new password and revokes all sessions',async()=>{
  const token=randomBytes(32).toString('hex');await db.all(sql`INSERT INTO auth_tokens(org_id,email,token_hash,kind,expires_at) VALUES(${f.orgId},${f.owner.email},${hash(token)},'RESET',now()+interval '10 minutes')`);
  const r=await auth.resetPassword(db,token,'Changed-test-password-971!','test-ip');expect(r.email_notification).toBe('NOT_CONFIGURED');
  const [u]=await db.all(sql`SELECT password_hash FROM users WHERE id=${f.owner.id}`);expect(await auth.verifyPassword(u.password_hash,'Changed-test-password-971!')).toBe(true);
  expect((await db.all(sql`SELECT token_hash FROM sessions WHERE user_id=${f.owner.id}`)).length).toBe(0);await expect(auth.resetPassword(db,token,'Another-test-password-971!','test-ip')).rejects.toThrow(/Tautan/);
 });
 it('reconciles NO_SALES after later entry without treating the day as closed',async()=>{
  await harvestStock();await transact('confirm',{},tx=>sales.confirmSalesDay(tx,f.owner,{business_date:'2026-10-15',status:'NO_SALES'}));const i=await inventory.rawItem(db,f.orgId,'GRADE_A');const d=saleSchema.parse({business_date:'2026-10-15',channel:'OFFLINE',items:[{item_id:i.id,quantity:'1000'}]});await transact('late-sale',d,tx=>sales.recordSale(tx,f.owner,d));
  const [c]=await db.all(sql`SELECT status FROM sales_day_confirmations WHERE org_id=${f.orgId}`);expect(c.status).toBe('COMPLETED');
 });
 it('offers real in-app reminders, records no fake provider delivery and stops after confirmation',async()=>{
  const before=await notificationState(db,f.orgId,f.owner.id);const day=before.business_date;
  await db.all(sql`UPDATE organizations SET reminder_time='00:00' WHERE id=${f.orgId}`);const due=await notificationState(db,f.orgId,f.owner.id);expect(due.reminder_due).toBe(true);
  const result=await runReminderJob(db);expect(result.sent).toBe(0);expect((await db.all(sql`SELECT id FROM notification_deliveries WHERE org_id=${f.orgId}`)).length).toBe(0);
  await transact('confirm',{},tx=>sales.confirmSalesDay(tx,f.owner,{business_date:day,status:'NO_SALES'}));expect((await notificationState(db,f.orgId,f.owner.id)).reminder_due).toBe(false);
 });
});
