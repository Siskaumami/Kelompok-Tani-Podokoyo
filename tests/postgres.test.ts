import { beforeAll,afterAll,describe,it,expect } from 'vitest';
import { readFile } from 'node:fs/promises';
import { randomUUID } from 'node:crypto';
import { sql } from 'drizzle-orm';
import { connectDatabase,type Db } from '../apps/server/src/core/database.js';
import { fixture } from './helpers.js';
import { mutate } from '../apps/server/src/core/transactions.js';
import { saveHarvest,finalizeHarvest } from '../apps/server/src/modules/harvest/service.js';
import { completeProduction } from '../apps/server/src/modules/production/service.js';
import { recordSale } from '../apps/server/src/modules/sales/service.js';
import { inventoryList } from '../apps/server/src/modules/inventory/service.js';
import { harvestSchema,productionSchema,saleSchema } from '../packages/shared/src/schemas.js';
const url=process.env.TEST_DATABASE_URL;
describe.skipIf(!url)('real PostgreSQL multi-connection contention',()=>{
 let db:Db,pool:ReturnType<typeof connectDatabase>['pool'];const schema='qa_'+randomUUID().replaceAll('-','');
 beforeAll(async()=>{
  const base=new URL(url!);if(!base.pathname.endsWith('_test'))throw new Error('TEST_DATABASE_URL must select a dedicated database ending in _test.');
  base.searchParams.set('options','-c search_path='+schema);({db,pool}=connectDatabase(base.toString()));
  await pool!.query('CREATE SCHEMA '+schema);await pool!.query(await readFile('database/migrations/0001_initial.sql','utf8'));
 });
 afterAll(async()=>{if(pool){await pool.query('DROP SCHEMA IF EXISTS '+schema+' CASCADE');await pool.end();}});
 async function stocked(){const f=await fixture(db),a=f.owner;const h=harvestSchema.parse({business_date:'2026-10-15',total_g:'1000',grade_a_g:'0',grade_b_g:'1000',reject_g:'0'});const batch=await mutate(db,a,randomUUID(),'draft',h,tx=>saveHarvest(tx,a,null,h));await mutate(db,a,randomUUID(),'finalize',{},tx=>finalizeHarvest(tx,a,batch.id));const p=productionSchema.parse({product_id:f.product.id,business_date:'2026-10-15',actual_g:'1000',output_units:'10'});await mutate(db,a,randomUUID(),'production',p,tx=>completeProduction(tx,a,p));const item=(await inventoryList(db,f.orgId)).find(i=>i.product_id===f.product.id)!;return {...f,item};}
 it('permits only one of simultaneous sales that together oversell',async()=>{
  const f=await stocked();const sale=(quantity:string)=>saleSchema.parse({business_date:'2026-10-15',channel:'OFFLINE',items:[{item_id:f.item.id,quantity}]});const d1=sale('8'),d2=sale('7');
  const outcomes=await Promise.allSettled([mutate(db,f.owner,randomUUID(),'sale',d1,tx=>recordSale(tx,f.owner,d1)),mutate(db,f.admin,randomUUID(),'sale',d2,tx=>recordSale(tx,f.admin,d2))]);
  expect(outcomes.filter(o=>o.status==='fulfilled')).toHaveLength(1);expect(outcomes.filter(o=>o.status==='rejected')).toHaveLength(1);
  const [i]=await db.all(sql`SELECT balance,(SELECT sum(delta)::text FROM inventory_movements WHERE item_id=inventory_items.id) AS ledger FROM inventory_items WHERE id=${f.item.id}`);expect(['2','3']).toContain(i.balance);expect(i.balance).toBe(i.ledger);
 });
 it('serializes identical simultaneous idempotency keys to one real sale',async()=>{
  const f=await stocked(),key=randomUUID(),d=saleSchema.parse({business_date:'2026-10-15',channel:'OFFLINE',items:[{item_id:f.item.id,quantity:'2'}]});
  const run=()=>mutate(db,f.owner,key,'sale',d,tx=>recordSale(tx,f.owner,d));const [first,second]=await Promise.all([run(),run()]);expect(first.id).toBe(second.id);
  const [count]=await db.all(sql`SELECT count(*)::text AS total FROM sales WHERE org_id=${f.orgId}`);expect(count.total).toBe('1');const [i]=await db.all(sql`SELECT balance FROM inventory_items WHERE id=${f.item.id}`);expect(i.balance).toBe('8');
 });
});
