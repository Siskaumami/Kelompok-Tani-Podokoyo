import { randomBytes,timingSafeEqual } from 'node:crypto';
import argon2 from 'argon2';
import { sql } from 'drizzle-orm';
import type { Request,Response,NextFunction } from 'express';
import type { Db } from '../../core/database.js';
import { AppError,requireValue,assert } from '../../core/errors.js';
import { hash,audit } from '../../core/transactions.js';
import { appOrigin,config,integrationStatus } from '../../core/config.js';
import { sendEmail,requireEmail } from './email.js';
import type { Actor,Row } from '../../../../../packages/shared/src/schemas.js';
const SESSION_COOKIE=config.NODE_ENV==='production'?'__Host-tani_session':'tani_session';
const randomToken=()=>randomBytes(32).toString('hex');
const csrfFor=(session:string)=>hash('csrf:'+session);
const equal=(a:string,b:string)=>a.length===b.length&&timingSafeEqual(Buffer.from(a),Buffer.from(b));
export const hashPassword=(password:string)=>argon2.hash(password,{type:argon2.argon2id,memoryCost:65536,timeCost:3,parallelism:1});
// A per-process dummy hash removes the fast nonexistent-email path without a runtime user record.
let dummyHash:Promise<string>|undefined;
export async function verifyPassword(hashValue:string|undefined,password:string){dummyHash??=hashPassword(randomToken());try{return await argon2.verify(hashValue??await dummyHash,password);}catch{return false;}}
export async function throttle(db:Db,key:string,max=8){
 const [v]=await db.all(sql`INSERT INTO login_limits(key,attempts,window_start) VALUES(${hash(key)},1,now()) ON CONFLICT(key) DO UPDATE SET attempts=CASE WHEN login_limits.window_start<now()-interval '15 minutes' THEN 1 ELSE login_limits.attempts+1 END,window_start=CASE WHEN login_limits.window_start<now()-interval '15 minutes' THEN now() ELSE login_limits.window_start END RETURNING attempts`);
 if(v.attempts>max)throw new AppError(429,'RATE_LIMIT','Terlalu banyak percobaan. Coba lagi setelah 15 menit.');
}
export async function login(db:Db,email:string,password:string,ip:string){
 await throttle(db,'login-ip:'+ip,50);await throttle(db,'login-email:'+email,8);
 const u=(await db.all(sql`SELECT id,org_id,email,name,role,password_hash,active FROM users WHERE email=${email}`))[0];
 const valid=await verifyPassword(u?.password_hash,password);
 if(!valid||!u?.active||!u.org_id)throw new AppError(401,'INVALID_CREDENTIALS','Email atau kata sandi tidak sesuai.');
 const token=randomToken(),csrf=csrfFor(token);
 await db.all(sql`INSERT INTO sessions(token_hash,user_id,csrf_hash,expires_at) VALUES(${hash(token)},${u.id},${hash(csrf)},now()+interval '12 hours')`);
 return {token,csrf,user:{id:u.id,org_id:u.org_id,email:u.email,name:u.name,role:u.role} as Actor};
}
export function setSessionCookie(res:Response,token:string){res.cookie(SESSION_COOKIE,token,{httpOnly:true,secure:config.NODE_ENV==='production',sameSite:'lax',path:'/',maxAge:12*60*60*1000});}
export function clearSessionCookie(res:Response){res.clearCookie(SESSION_COOKIE,{httpOnly:true,secure:config.NODE_ENV==='production',sameSite:'lax',path:'/'});}
declare module 'express-serve-static-core' {interface Request {actor?:Actor;csrf?:string;session_hash?:string;}}
export function sessionMiddleware(db:Db){return async(req:Request,_res:Response,next:NextFunction)=>{
 try{
  const token=req.cookies?.[SESSION_COOKIE];
  if(typeof token!=='string'||!(/^[a-f0-9]{64}$/).test(token))return next();
  const [u]=await db.all(sql`SELECT u.id,u.org_id,u.email,u.name,u.role,s.csrf_hash FROM sessions s JOIN users u ON u.id=s.user_id WHERE s.token_hash=${hash(token)} AND s.expires_at>now() AND s.last_seen_at>now()-interval '2 hours' AND u.active AND u.org_id IS NOT NULL`);
  if(u&&equal(hash(csrfFor(token)),u.csrf_hash)){req.actor={id:u.id,org_id:u.org_id,email:u.email,name:u.name,role:u.role};req.csrf=csrfFor(token);req.session_hash=hash(token);await db.all(sql`UPDATE sessions SET last_seen_at=now() WHERE token_hash=${hash(token)}`);}
  next();
 }catch(e){next(e);}
};}
export function requireAuth(req:Request,_res:Response,next:NextFunction){if(!req.actor)return next(new AppError(401,'AUTH_REQUIRED','Silakan masuk untuk melanjutkan.'));next();}
export function originGuard(req:Request,_res:Response,next:NextFunction){if(['GET','HEAD','OPTIONS'].includes(req.method))return next();if(req.get('origin')!==appOrigin)return next(new AppError(403,'ORIGIN_REJECTED','Asal permintaan tidak diizinkan. Muat ulang aplikasi.'));next();}
export function csrfGuard(req:Request,_res:Response,next:NextFunction){if(['GET','HEAD','OPTIONS'].includes(req.method))return next();const supplied=req.get('x-csrf-token')??'';if(!req.csrf||!equal(supplied,req.csrf))return next(new AppError(403,'CSRF_REJECTED','Sesi formulir tidak valid. Muat ulang halaman.'));next();}
export async function logout(db:Db,sessionHash:string){await db.all(sql`DELETE FROM sessions WHERE token_hash=${sessionHash}`);}
export async function forgotPassword(db:Db,email:string,ip:string){
 requireEmail();await throttle(db,'forgot-ip:'+ip,20);await throttle(db,'forgot:'+email,4);
 // Uniform, durable queue acceptance avoids leaking account existence through
 // provider latency or a provider failure. No email is claimed sent here.
 await db.all(sql`INSERT INTO password_reset_requests(email) VALUES(${email})`);
 return {queued:true,message:'Permintaan pemulihan diterima. Jika email cocok dengan akun aktif, sistem akan memproses tautan pemulihannya. Periksa email beberapa saat lagi.'};
}
export async function runResetEmailJob(db:Db,limit=5){
 let processed=0,failed=0;
 for(let index=0;index<limit;index++){
  const job=await db.transaction(async tx=>{
   const [j]=await tx.all(sql`SELECT * FROM password_reset_requests WHERE attempts<3 AND created_at>now()-interval '1 day' AND (status='PENDING' OR status IN ('FAILED','PROCESSING') AND updated_at<now()-interval '15 minutes') ORDER BY created_at,id LIMIT 1 FOR UPDATE SKIP LOCKED`);
   if(!j)return null;
   await tx.all(sql`UPDATE password_reset_requests SET status='PROCESSING',attempts=attempts+1,updated_at=now() WHERE id=${j.id}`);return j;
  });
  if(!job)break;
  try{
   requireEmail();
   const u=(await db.all(sql`SELECT id,org_id,name,email FROM users WHERE email=${job.email} AND active AND org_id IS NOT NULL`))[0];
   if(!u){await db.all(sql`UPDATE password_reset_requests SET status='SKIPPED',updated_at=now() WHERE id=${job.id}`);processed++;continue;}
   const token=randomToken();
   await db.transaction(async tx=>{
    requireValue((await tx.all(sql`SELECT id FROM users WHERE id=${u.id} AND active FOR UPDATE`))[0]);
    await tx.all(sql`UPDATE auth_tokens SET consumed_at=now() WHERE email=${u.email} AND kind='RESET' AND consumed_at IS NULL`);
    await tx.all(sql`INSERT INTO auth_tokens(org_id,email,token_hash,kind,expires_at) VALUES(${u.org_id},${u.email},${hash(token)},'RESET',now()+interval '30 minutes')`);
    await sendEmail(u.email,u.name,'Atur ulang kata sandi',`Buka tautan Tani Desa berikut dalam 30 menit:\n${appOrigin}/reset-password#token=${token}\nAbaikan jika Anda tidak memintanya.`);
   });
   await db.all(sql`UPDATE password_reset_requests SET status='SENT',updated_at=now(),last_error=NULL WHERE id=${job.id}`);processed++;
  }catch{
   await db.all(sql`UPDATE password_reset_requests SET status='FAILED',updated_at=now(),last_error='EMAIL_DELIVERY_FAILED' WHERE id=${job.id}`);failed++;
  }
 }
 await db.all(sql`DELETE FROM password_reset_requests WHERE created_at<now()-interval '30 days'`);
 return {processed,failed};
}
export async function resetPassword(db:Db,token:string,password:string,ip:string){
 await throttle(db,'reset-ip:'+ip,20);const hashed=await hashPassword(password);
 const account=await db.transaction(async tx=>{
  const initial=requireValue((await tx.all(sql`SELECT email,org_id FROM auth_tokens WHERE token_hash=${hash(token)} AND kind='RESET'`))[0],'Tautan tidak valid atau sudah kedaluwarsa.');
  const u=requireValue((await tx.all(sql`SELECT id,org_id,email,name,role FROM users WHERE email=${initial.email} AND active AND org_id=${initial.org_id} FOR UPDATE`))[0]);
  requireValue((await tx.all(sql`SELECT id FROM auth_tokens WHERE token_hash=${hash(token)} AND kind='RESET' AND consumed_at IS NULL AND expires_at>now() FOR UPDATE`))[0],'Tautan tidak valid atau sudah kedaluwarsa.');
  await tx.all(sql`UPDATE users SET password_hash=${hashed} WHERE id=${u.id}`);await tx.all(sql`DELETE FROM sessions WHERE user_id=${u.id}`);
  await tx.all(sql`UPDATE auth_tokens SET consumed_at=now() WHERE email=${u.email} AND kind='RESET' AND consumed_at IS NULL`);
  await audit(tx,u as Actor,'PASSWORD_RESET','USER',u.id,null,{sessions_revoked:true});return u;
 });
 return {message:'Kata sandi diperbarui. Silakan masuk kembali.',email_notification:await securityNotice(account)};
}
async function securityNotice(u:Row){
 if(!integrationStatus().email)return 'NOT_CONFIGURED';
 try{await sendEmail(u.email,u.name,'Kata sandi akun berubah','Kata sandi akun Tani Desa Anda baru saja diperbarui. Jika Anda tidak melakukan perubahan ini, segera hubungi Owner dan atur ulang kata sandi.');return 'ACCEPTED_BY_PROVIDER';}catch{return 'FAILED';}
}
export async function changePassword(db:Db,a:Actor,current:string,password:string){
 const u=requireValue((await db.all(sql`SELECT password_hash FROM users WHERE id=${a.id} AND org_id=${a.org_id} AND active`))[0]);
 assert(await verifyPassword(u.password_hash,current),'Kata sandi saat ini tidak sesuai.','INVALID_PASSWORD');
 const hashed=await hashPassword(password);
 await db.transaction(async tx=>{
  const latest=requireValue((await tx.all(sql`SELECT password_hash FROM users WHERE id=${a.id} AND org_id=${a.org_id} FOR UPDATE`))[0]);
  assert(latest.password_hash===u.password_hash,'Kata sandi telah berubah. Masuk kembali.');
  await tx.all(sql`UPDATE users SET password_hash=${hashed} WHERE id=${a.id}`);await tx.all(sql`DELETE FROM sessions WHERE user_id=${a.id}`);
  await tx.all(sql`UPDATE auth_tokens SET consumed_at=now() WHERE email=${a.email} AND kind='RESET' AND consumed_at IS NULL`);
  await audit(tx,a,'PASSWORD_CHANGED','USER',a.id,null,{sessions_revoked:true});
 });
 return {message:'Kata sandi diperbarui. Silakan masuk kembali.',email_notification:await securityNotice(a)};
}
export async function inviteAdmin(tx:Db,a:Actor,email:string,name:string){
 requireEmail();
 const exists=(await tx.all(sql`SELECT id FROM users WHERE email=${email}`))[0];assert(!exists,'Email sudah terdaftar.');
 const token=randomToken();
 await tx.all(sql`UPDATE auth_tokens SET consumed_at=now() WHERE email=${email} AND org_id=${a.org_id} AND kind='INVITE' AND consumed_at IS NULL`);
 const [invitation]=await tx.all(sql`INSERT INTO auth_tokens(org_id,email,name,token_hash,kind,expires_at,created_by) VALUES(${a.org_id},${email},${name},${hash(token)},'INVITE',now()+interval '48 hours',${a.id}) RETURNING id,email,name,expires_at`);
 await sendEmail(email,name,'Undangan Admin Tani Desa',`${a.name} mengundang Anda sebagai Admin. Tentukan kata sandi Anda dalam 48 jam:\n${appOrigin}/accept-invitation#token=${token}\nJika undangan ini tidak dikenal, abaikan email ini.`);
 await audit(tx,a,'ADMIN_INVITED','INVITATION',invitation.id,null,invitation);return {...invitation,delivery:'ACCEPTED_BY_PROVIDER'};
}
export async function acceptInvitation(db:Db,token:string,password:string,name:string,ip:string){
 await throttle(db,'invite-ip:'+ip,20);
 const initial=requireValue((await db.all(sql`SELECT org_id FROM auth_tokens WHERE token_hash=${hash(token)} AND kind='INVITE'`))[0],'Undangan tidak valid.');
 const hashed=await hashPassword(password);
 return db.transaction(async tx=>{
  await tx.all(sql`SELECT id FROM organizations WHERE id=${initial.org_id} FOR UPDATE`);
  const t=requireValue((await tx.all(sql`SELECT * FROM auth_tokens WHERE token_hash=${hash(token)} AND kind='INVITE' AND consumed_at IS NULL AND expires_at>now() FOR UPDATE`))[0],'Undangan tidak valid atau sudah kedaluwarsa.');
  const owner=(await tx.all(sql`SELECT id FROM users WHERE id=${t.created_by} AND org_id=${t.org_id} AND role='OWNER' AND active`))[0];assert(owner,'Pengundang tidak lagi memiliki akses.');
  const [u]=await tx.all(sql`INSERT INTO users(org_id,email,name,password_hash,role) VALUES(${t.org_id},${t.email},${name},${hashed},'ADMIN') RETURNING id,org_id,email,name,role`);
  await tx.all(sql`UPDATE auth_tokens SET consumed_at=now() WHERE id=${t.id}`);
  await audit(tx,u as Actor,'INVITATION_ACCEPTED','USER',u.id,null,u);return {message:'Akun Admin aktif. Silakan masuk.'};
 });
}
