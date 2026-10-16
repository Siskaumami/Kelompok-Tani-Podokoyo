import { describe,it,expect } from 'vitest';
import { grams,quantity,money } from '../apps/web/src/format.js';
import { sql } from 'drizzle-orm';
import { memoryDatabase } from './helpers.js';
describe('quantity and integer transport safety',()=>{
 it('preserves kg decimals and rejects ambiguous Indonesian thousand dots',()=>{expect(grams('1000')).toBe('1000000');expect(grams('1,250')).toBe('1250');expect(()=>grams('1.000')).toThrow(/tanpa titik/);expect(()=>grams('1,0001')).toThrow();expect(()=>grams('-1')).toThrow();});
 it('displays large money and signed stock differences without floating-point loss',()=>{expect(money('9007199254740993')).toBe('Rp9.007.199.254.740.993');expect(quantity('-1250','GRADE_B')).toBe('-1,25 kg');});
 it('transports PostgreSQL BIGINT beyond JS safe integer as an exact decimal string',async()=>{const {db,close}=await memoryDatabase();try{const [row]=await db.all(sql`SELECT '9007199254740993'::bigint AS value`);expect(row.value).toBe('9007199254740993');}finally{await close();}});
});
