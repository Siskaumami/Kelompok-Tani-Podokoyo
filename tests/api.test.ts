import { beforeAll,afterAll,beforeEach,describe,it,expect } from 'vitest';
import { randomBytes,randomUUID } from 'node:crypto';
import { sql } from 'drizzle-orm';
import supertest from 'supertest';
import sharp from 'sharp';
import { fixture,memoryDatabase,fixturePassword } from './helpers.js';
import { createApp } from '../apps/server/src/app.js';
import { hash } from '../apps/server/src/core/transactions.js';
import type { Db } from '../apps/server/src/core/database.js';
let db:Db,close:()=>Promise<void>,f:Awaited<ReturnType<typeof fixture>>,app:ReturnType<typeof createApp>;
beforeAll(async()=>{({db,close}=await memoryDatabase());app=createApp(db);});afterAll(async()=>{await close();});beforeEach(async()=>{f=await fixture(db);});
const client=()=>supertest(app);
const headers=()=>({Origin:'http://localhost:5173',Cookie:`tani_session=${f.token}`,'X-CSRF-Token':f.csrf,'Idempotency-Key':randomUUID()});
describe('HTTP security boundaries',()=>{
 it('requires a real session for private records and rejects forged cookies',async()=>{
  expect((await client().get('/api/v1/products')).status).toBe(401);
  expect((await client().get('/api/v1/products').set('Cookie','tani_session='+randomBytes(32).toString('hex'))).status).toBe(401);
  const ok=await client().get('/api/v1/products').set(headers());expect(ok.status).toBe(200);expect(ok.headers['cache-control']).toBe('no-store');
 });
 it('rejects missing origin, missing CSRF and organization injection',async()=>{
  expect((await client().post('/api/v1/farmers').set('Cookie',`tani_session=${f.token}`).send({name:'Test-only farmer'})).status).toBe(403);
  const noCsrf={...headers()};delete (noCsrf as Record<string,string>)['X-CSRF-Token'];expect((await client().post('/api/v1/farmers').set(noCsrf).send({name:'Test-only farmer'})).status).toBe(403);
  const result=await client().post('/api/v1/farmers').set(headers()).send({name:'Test-only farmer',org_id:randomUUID()});expect(result.status).toBe(422);
 });
 it('enforces Admin permissions server-side and never accepts role escalation fields',async()=>{
  const token=randomBytes(32).toString('hex'),csrf=hash('csrf:'+token);await db.all(sql`INSERT INTO sessions(token_hash,user_id,csrf_hash,expires_at) VALUES(${hash(token)},${f.admin.id},${hash(csrf)},now()+interval '1 hour')`);
  const h={...headers(),Cookie:'tani_session='+token,'X-CSRF-Token':csrf};
  const denied=await client().post('/api/v1/users/invitations').set(h).send({email:'isolated@example.test',name:'Isolated recipient'});expect(denied.status).toBe(403);
  const escalation=await client().post('/api/v1/users/invitations').set(headers()).send({email:'isolated@example.test',name:'Isolated recipient',role:'OWNER'});expect(escalation.status).toBe(422);
  const missingConfig=await client().post('/api/v1/users/invitations').set(headers()).send({email:'isolated@example.test',name:'Isolated recipient'});expect(missingConfig.status).toBe(503);expect(missingConfig.body.error.code).toBe('EMAIL_NOT_CONFIGURED');
  expect((await db.all(sql`SELECT id FROM auth_tokens WHERE org_id=${f.orgId}`)).length).toBe(0);
 });
 it('does not claim email or upload success when providers are unconfigured',async()=>{
  const email=await client().post('/api/v1/auth/forgot-password').set('Origin','http://localhost:5173').send({email:f.owner.email});expect(email.status).toBe(503);
  const png=await sharp({create:{width:2,height:2,channels:3,background:'#148339'}}).png().toBuffer();
  const upload=await client().post('/api/v1/files').set(headers()).attach('image',png,'test-only.png');expect(upload.status).toBe(503);expect(upload.body.error.code).toBe('STORAGE_NOT_CONFIGURED');
  const executable=await client().post('/api/v1/files').set(headers()).attach('image',Buffer.from('<svg onload="alert(1)"/>'),'test-only.svg');expect(executable.status).toBe(422);
 });
 it('sanitizes constraint failures and validates identifiers',async()=>{
  const body={name:'Test-only farmer',image_id:randomUUID()};const result=await client().post('/api/v1/farmers').set(headers()).send(body);expect(result.status).toBe(422);
  expect(JSON.stringify(result.body)).not.toMatch(/INSERT INTO|constraint|stack|password_hash/);
  const injection=await client().get('/api/v1/sales/not-a-uuid').set(headers());expect(injection.status).toBe(422);
 });
 it('keeps unpublished images private even if their IDs are known',async()=>{
  const fileId=randomUUID();await db.all(sql`INSERT INTO file_objects(id,org_id,object_key,mime,size_bytes,uploaded_by) VALUES(${fileId},${f.orgId},${randomUUID()},'image/webp',10,${f.owner.id})`);
  await db.all(sql`UPDATE products SET image_id=${fileId} WHERE id=${f.product.id}`);const [org]=await db.all(sql`SELECT slug FROM organizations WHERE id=${f.orgId}`);
  expect((await client().get(`/api/v1/public/${org.slug}/files/${fileId}`)).status).toBe(404);
  const publicResult=await client().get('/api/v1/public/'+org.slug);expect(publicResult.status).toBe(200);expect(publicResult.body.data.products).toEqual([]);
 });
});
describe('authentication transport and one-time invitations',()=>{
 it('logs in with Argon2 and revokes the server session on logout',async()=>{
  const r=await client().post('/api/v1/auth/login').set('Origin','http://localhost:5173').send({email:f.owner.email,password:fixturePassword});expect(r.status).toBe(200);
  const cookie=r.headers['set-cookie'][0];expect(cookie).toContain('HttpOnly');expect(cookie).toContain('SameSite=Lax');expect(JSON.stringify(r.body)).not.toContain('password_hash');
  const logout=await client().post('/api/v1/auth/logout').set({Origin:'http://localhost:5173',Cookie:cookie.split(';')[0],'X-CSRF-Token':r.body.data.csrf}).send({});expect(logout.status).toBe(200);expect((await client().get('/api/v1/auth/me').set('Cookie',cookie.split(';')[0])).status).toBe(401);
 });
 it('accepts an invitation only once and always creates an Admin',async()=>{
  const token=randomBytes(32).toString('hex'),email=randomUUID()+'@example.test';await db.all(sql`INSERT INTO auth_tokens(org_id,email,name,token_hash,kind,expires_at,created_by) VALUES(${f.orgId},${email},'Test invitee',${hash(token)},'INVITE',now()+interval '1 hour',${f.owner.id})`);
  const body={token,name:'Test invitee',password:'Invitation-test-password-449!'};const first=await client().post('/api/v1/auth/accept-invitation').set('Origin','http://localhost:5173').send(body);expect(first.status).toBe(200);
  const [u]=await db.all(sql`SELECT role FROM users WHERE email=${email}`);expect(u.role).toBe('ADMIN');expect((await client().post('/api/v1/auth/accept-invitation').set('Origin','http://localhost:5173').send(body)).status).toBe(404);
 });
 it('makes an accurate empty report and PDF available from an empty business installation',async()=>{
  const report=await client().get('/api/v1/reports?from=2026-10-15&to=2026-10-15').set(headers());expect(report.status).toBe(200);expect(report.body.data.totals.gross_rp).toBe('0');expect(report.body.data.transactions).toEqual([]);
  const pdf=await client().get('/api/v1/reports/pdf?from=2026-10-15&to=2026-10-15').set(headers());expect(pdf.status).toBe(200);expect(pdf.headers['content-type']).toContain('application/pdf');expect(pdf.body.subarray(0,4).toString()).toBe('%PDF');
 });
});
