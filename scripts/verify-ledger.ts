import { sql } from 'drizzle-orm';
import { connectDatabase } from '../apps/server/src/core/database.js';
const {db,pool}=connectDatabase();
try{
 const drift=await db.all(sql`SELECT i.org_id,i.id,i.balance,coalesce(sum(m.delta),0)::text AS ledger_balance FROM inventory_items i LEFT JOIN inventory_movements m ON m.org_id=i.org_id AND m.item_id=i.id GROUP BY i.id HAVING i.balance<>coalesce(sum(m.delta),0)`);
 if(drift.length){console.error(JSON.stringify({event:'ledger_drift',items:drift}));process.exitCode=1;}else console.info('All cached inventory balances match their immutable movements.');
}catch{console.error('Ledger verification failed. No balances were modified.');process.exitCode=1;}finally{await pool?.end();}
