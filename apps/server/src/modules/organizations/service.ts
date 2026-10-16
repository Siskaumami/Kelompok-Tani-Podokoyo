import { sql } from 'drizzle-orm';
import type { z } from 'zod';
import type { Db } from '../../core/database.js';
import { requireValue } from '../../core/errors.js';
import { audit } from '../../core/transactions.js';
import type { Actor } from '../../../../../packages/shared/src/schemas.js';
import { settingsSchema } from '../../../../../packages/shared/src/schemas.js';
export const organization=async(db:Db,id:string)=>requireValue((await db.all(sql`SELECT * FROM organizations WHERE id=${id}`))[0]);
export async function saveSettings(tx:Db,a:Actor,d:z.infer<typeof settingsSchema>){
 const before=await organization(tx,a.org_id);
 const [after]=await tx.all(sql`UPDATE organizations SET name=${d.name},timezone=${d.timezone},reminder_time=${d.reminder_time},reminders_enabled=${d.reminders_enabled},reminder_email=${d.reminder_email},grade_a_price_rp=${d.grade_a_price_rp},grade_a_hpp_rp=${d.grade_a_hpp_rp} WHERE id=${a.org_id} RETURNING *`);
 await audit(tx,a,'SETTINGS_UPDATED','ORGANIZATION',a.org_id,before,after,'Perubahan pengaturan organisasi');return after;
}
export function localDate(timezone:string,now=new Date()){return new Intl.DateTimeFormat('en-CA',{timeZone:timezone,year:'numeric',month:'2-digit',day:'2-digit'}).format(now);}
export function localClock(timezone:string,now=new Date()){return new Intl.DateTimeFormat('en-GB',{timeZone:timezone,hour:'2-digit',minute:'2-digit',hourCycle:'h23'}).format(now);}
