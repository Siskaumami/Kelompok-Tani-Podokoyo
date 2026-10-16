import { sql } from 'drizzle-orm';
import webpush from 'web-push';
import type { z } from 'zod';
import type { Db } from '../../core/database.js';
import { config,integrationStatus } from '../../core/config.js';
import { AppError } from '../../core/errors.js';
import { audit } from '../../core/transactions.js';
import { organization,localDate,localClock } from '../organizations/service.js';
import { sendEmail } from '../auth/email.js';
import { pushSchema,type Actor,type Row } from '../../../../../packages/shared/src/schemas.js';
export async function notificationState(db:Db,orgId:string,userId:string){
 const org=await organization(db,orgId),day=localDate(org.timezone);
 const confirmation=(await db.all(sql`SELECT business_date,status,updated_at FROM sales_day_confirmations WHERE org_id=${orgId} AND business_date=${day}`))[0]??null;
 const reminder_due=org.reminders_enabled&&!confirmation&&localClock(org.timezone)>=String(org.reminder_time).slice(0,5);
 const [s]=await db.all(sql`SELECT count(*)::text AS total FROM push_subscriptions WHERE org_id=${orgId} AND user_id=${userId}`);
 return {business_date:day,timezone:org.timezone,confirmation,reminder_due,reminder_time:String(org.reminder_time).slice(0,5),push_configured:integrationStatus().push,vapid_public_key:integrationStatus().push?config.VAPID_PUBLIC_KEY:null,push_subscribed:s.total!=='0'};
}
export async function subscribePush(tx:Db,a:Actor,d:z.infer<typeof pushSchema>){
 if(!integrationStatus().push)throw new AppError(503,'PUSH_NOT_CONFIGURED','Notifikasi perangkat belum tersedia.');
 const [p]=await tx.all(sql`INSERT INTO push_subscriptions(org_id,user_id,endpoint,p256dh,auth) VALUES(${a.org_id},${a.id},${d.endpoint},${d.keys.p256dh},${d.keys.auth}) ON CONFLICT(endpoint) DO UPDATE SET org_id=excluded.org_id,user_id=excluded.user_id,p256dh=excluded.p256dh,auth=excluded.auth RETURNING id`);
 await audit(tx,a,'PUSH_SUBSCRIBED','USER',a.id,null,{subscription_id:p.id});return {subscribed:true};
}
export async function unsubscribePush(tx:Db,a:Actor){await tx.all(sql`DELETE FROM push_subscriptions WHERE org_id=${a.org_id} AND user_id=${a.id}`);await audit(tx,a,'PUSH_UNSUBSCRIBED','USER',a.id,null,null);return {subscribed:false};}
export async function runReminderJob(db:Db,now=new Date()){
 const orgs=await db.all(sql`SELECT id FROM organizations ORDER BY id`);let sent=0,failed=0;
 for(const o of orgs){
  const reminder:Row|null=await db.transaction(async tx=>{
   const [org]=await tx.all(sql`SELECT * FROM organizations WHERE id=${o.id} FOR UPDATE`),day=localDate(org.timezone,now);
   if(!org.reminders_enabled||localClock(org.timezone,now)<String(org.reminder_time).slice(0,5))return null;
   const confirmed=(await tx.all(sql`SELECT status FROM sales_day_confirmations WHERE org_id=${org.id} AND business_date=${day}`))[0];if(confirmed)return null;
   const [r]=await tx.all(sql`INSERT INTO reminders(org_id,business_date) VALUES(${org.id},${day}) ON CONFLICT(org_id,business_date) DO UPDATE SET business_date=excluded.business_date RETURNING *`);
   return {...r,email_enabled:org.reminder_email};
  });
  if(!reminder)continue;
  const users=await db.all(sql`SELECT id FROM users WHERE org_id=${o.id} AND active ORDER BY id`);
  for(const u of users)for(const channel of ['PUSH','EMAIL']){
   if(channel==='PUSH'&&!integrationStatus().push||channel==='EMAIL'&&(!integrationStatus().email||!reminder.email_enabled))continue;
   const outcome=await db.transaction(async tx=>{
    await tx.all(sql`SELECT id FROM organizations WHERE id=${o.id} FOR UPDATE`);
    const org=await organization(tx,o.id);
    if(!org.reminders_enabled||localDate(org.timezone,now)!==String(reminder.business_date)||channel==='EMAIL'&&!org.reminder_email)return 'SKIPPED';
    if((await tx.all(sql`SELECT 1 FROM sales_day_confirmations WHERE org_id=${o.id} AND business_date=${reminder.business_date}`)).length)return 'SKIPPED';
    const [user]=await tx.all(sql`SELECT id,name,email FROM users WHERE org_id=${o.id} AND id=${u.id} AND active`);if(!user)return 'SKIPPED';
    const subscriptions=channel==='PUSH'?await tx.all(sql`SELECT * FROM push_subscriptions WHERE org_id=${o.id} AND user_id=${u.id}`):[];
    if(channel==='PUSH'&&!subscriptions.length)return 'SKIPPED';
    await tx.all(sql`INSERT INTO notification_deliveries(org_id,reminder_id,user_id,channel) VALUES(${o.id},${reminder.id},${u.id},${channel}) ON CONFLICT(reminder_id,user_id,channel) DO NOTHING`);
    const [d]=await tx.all(sql`SELECT * FROM notification_deliveries WHERE reminder_id=${reminder.id} AND user_id=${u.id} AND channel=${channel} FOR UPDATE`);
    if(d.status==='SENT'||d.attempts>=3||d.status==='FAILED'&&new Date(d.updated_at).getTime()>now.getTime()-15*60000)return 'SKIPPED';
    try{
     if(channel==='EMAIL')await sendEmail(user.email,user.name,'Pengingat pencatatan penjualan',`Penjualan tanggal ${reminder.business_date} belum dikonfirmasi. Catat penjualan atau pilih Tidak ada penjualan hari ini di ${config.APP_URL}/dashboard/sales`);
     else{
      webpush.setVapidDetails(config.VAPID_SUBJECT,config.VAPID_PUBLIC_KEY,config.VAPID_PRIVATE_KEY);
      // One endpoint per user/day avoids replaying already accepted endpoints after partial failures.
      const s=subscriptions[0];
      try{await webpush.sendNotification({endpoint:s.endpoint,keys:{p256dh:s.p256dh,auth:s.auth}},JSON.stringify({title:'Catat penjualan hari ini',body:'Konfirmasikan pencatatan penjualan atau pilih tidak ada penjualan.',url:'/dashboard/sales'}),{TTL:3600,timeout:10000});}
      catch(e){if([404,410].includes((e as {statusCode?:number}).statusCode??0))await tx.all(sql`DELETE FROM push_subscriptions WHERE id=${s.id}`);throw e;}
     }
     await tx.all(sql`UPDATE notification_deliveries SET status='SENT',attempts=attempts+1,sent_at=now(),updated_at=now(),last_error=NULL WHERE id=${d.id}`);return 'SENT';
    }catch{await tx.all(sql`UPDATE notification_deliveries SET status='FAILED',attempts=attempts+1,updated_at=now(),last_error='PROVIDER_DELIVERY_FAILED' WHERE id=${d.id}`);return 'FAILED';}
   });
   if(outcome==='SENT')sent++;if(outcome==='FAILED')failed++;
  }
 }
 await db.all(sql`DELETE FROM sessions WHERE expires_at<now() OR last_seen_at<now()-interval '2 hours'`);
 await db.all(sql`DELETE FROM login_limits WHERE window_start<now()-interval '1 day'`);
 return {sent,failed};
}
