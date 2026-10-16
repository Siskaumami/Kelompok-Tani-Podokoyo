import { randomUUID } from 'node:crypto';
import path from 'node:path';
import { existsSync } from 'node:fs';
import express,{type Request,type Response,type NextFunction} from 'express';
import helmet from 'helmet';
import cookieParser from 'cookie-parser';
import rateLimit from 'express-rate-limit';
import multer from 'multer';
import { z,ZodError } from 'zod';
import { sql } from 'drizzle-orm';
import type { Db } from './core/database.js';
import { AppError } from './core/errors.js';
import { config,integrationStatus } from './core/config.js';
import { mutate,hash } from './core/transactions.js';
import * as S from '../../../packages/shared/src/schemas.js';
import * as auth from './modules/auth/service.js';
import * as farmers from './modules/farmers/service.js';
import * as orgs from './modules/organizations/service.js';
import * as content from './modules/public-content/service.js';
import * as products from './modules/products/service.js';
import * as harvest from './modules/harvest/service.js';
import * as inventory from './modules/inventory/service.js';
import * as production from './modules/production/service.js';
import * as sales from './modules/sales/service.js';
import * as opname from './modules/stock-opname/service.js';
import * as reports from './modules/reports/service.js';
import * as notifications from './modules/notifications/service.js';
import * as files from './modules/files/service.js';
import * as users from './modules/users/service.js';
import * as audit from './modules/audit/service.js';
const empty=z.strictObject({});
const pagination=z.strictObject({limit:z.coerce.number().int().min(1).max(100).default(30),offset:z.coerce.number().int().min(0).max(1000000).default(0)});
const respond=(res:Response,data:unknown)=>res.json({data});
const entityId=(req:Request)=>S.id.parse(req.params.id);
function key(req:Request){const k=req.get('idempotency-key');if(!k)throw new AppError(400,'IDEMPOTENCY_KEY_REQUIRED','Halaman perlu dimuat ulang sebelum menyimpan. Silakan coba lagi.');return z.uuid().parse(k);}
function write<T extends z.ZodType>(db:Db,operation:string,schema:T,fn:(tx:Db,a:S.Actor,body:z.infer<T>,req:Request)=>Promise<unknown>,permission:'OPERATE'|'MANAGE_USERS'|'SETTINGS'='OPERATE'){
 return async(req:Request,res:Response)=>{const input=schema.parse(req.body??{});const a=req.actor!;respond(res,await mutate(db,a,key(req),operation+':'+String(req.params.id??''),input,tx=>fn(tx,a,input,req),permission));};
}
function page(db:Db,fn:(db:Db,org:string,limit:number,offset:number)=>Promise<S.Row[]>){return async(req:Request,res:Response)=>{const {limit,offset}=pagination.parse(req.query);const rows=await fn(db,req.actor!.org_id,limit+1,offset);respond(res,{items:rows.slice(0,limit),next_offset:rows.length>limit?offset+limit:null});};}
export function createApp(db:Db){
 const app=express();app.disable('x-powered-by');if(config.TRUST_PROXY_HOPS)app.set('trust proxy',config.TRUST_PROXY_HOPS);
 app.use((req,res,next)=>{res.locals.request_id=randomUUID();res.setHeader('X-Request-Id',res.locals.request_id);next();});
 app.use(helmet({contentSecurityPolicy:{directives:{defaultSrc:["'self'"],scriptSrc:["'self'"],styleSrc:["'self'","'unsafe-inline'"],imgSrc:["'self'",'https:','data:'],connectSrc:["'self'"],objectSrc:["'none'"],frameAncestors:["'none'"],baseUri:["'self'"],formAction:["'self'"],upgradeInsecureRequests:config.NODE_ENV==='production'?[]:null}},referrerPolicy:{policy:'no-referrer'}}));
 app.use('/api',rateLimit({windowMs:60000,limit:300,standardHeaders:'draft-8',legacyHeaders:false,message:{error:{code:'RATE_LIMIT',message:'Permintaan terlalu sering. Tunggu sebentar.'}}}));
 app.use(express.json({limit:'256kb'}));app.use(cookieParser());
 const api=express.Router();app.use('/api/v1',api);
 api.use((_req,res,next)=>{res.setHeader('Cache-Control','no-store');next();});api.use(auth.originGuard);
 api.get('/health',async(_req,res)=>{try{await db.all(sql`SELECT 1`);respond(res,{status:'ready'});}catch{res.status(503).json({error:{code:'DATABASE_UNAVAILABLE',message:'Database belum siap.'}});}});
 api.get('/public/site',async(_req,res)=>{if(!config.PUBLIC_ORG_SLUG)throw new AppError(503,'PUBLIC_ORG_NOT_CONFIGURED','Profil kelompok belum tersedia.');respond(res,await content.publicData(db,config.PUBLIC_ORG_SLUG));});
 api.get('/public/:slug',async(req,res)=>{const slug=z.string().regex(/^[a-z0-9-]{1,100}$/).parse(req.params.slug);respond(res,await content.publicData(db,slug));});
 api.get('/public/:slug/files/:id',async(req,res)=>{const slug=z.string().regex(/^[a-z0-9-]{1,100}$/).parse(req.params.slug);res.redirect(302,await files.publicImage(db,slug,entityId(req)));});
 api.post('/auth/login',async(req,res)=>{const d=S.loginSchema.parse(req.body);const r=await auth.login(db,d.email,d.password,req.ip??'unknown');auth.setSessionCookie(res,r.token);respond(res,{user:r.user,csrf:r.csrf});});
 api.post('/auth/forgot-password',async(req,res)=>{const d=S.forgotSchema.parse(req.body);const result=await auth.forgotPassword(db,d.email,req.ip??'unknown');res.status(202);respond(res,result);});
 api.post('/auth/reset-password',async(req,res)=>{const d=S.resetSchema.parse(req.body);respond(res,await auth.resetPassword(db,d.token,d.password,req.ip??'unknown'));});
 api.post('/auth/accept-invitation',async(req,res)=>{const d=S.acceptInviteSchema.parse(req.body);respond(res,await auth.acceptInvitation(db,d.token,d.password,d.name,req.ip??'unknown'));});
 api.use(auth.sessionMiddleware(db),auth.requireAuth,auth.csrfGuard);
 api.get('/auth/me',(req,res)=>respond(res,{user:req.actor,csrf:req.csrf}));
 api.post('/auth/logout',async(req,res)=>{empty.parse(req.body);await auth.logout(db,req.session_hash!);auth.clearSessionCookie(res);respond(res,{logged_out:true});});
 api.post('/auth/change-password',async(req,res)=>{const d=S.changePasswordSchema.parse(req.body);await auth.throttle(db,'change:'+req.actor!.id,8);const result=await auth.changePassword(db,req.actor!,d.current_password,d.password);auth.clearSessionCookie(res);respond(res,result);});
 api.get('/organization',async(req,res)=>respond(res,await orgs.organization(db,req.actor!.org_id)));
 api.get('/configuration',(_req,res)=>respond(res,integrationStatus()));
 api.put('/organization/settings',write(db,'SETTINGS',S.settingsSchema,(tx,a,d)=>orgs.saveSettings(tx,a,d),'SETTINGS'));
 api.put('/organization/content',write(db,'CONTENT',S.contentSchema,(tx,a,d)=>content.saveContent(tx,a,d)));
 api.get('/farmers',async(req,res)=>respond(res,await farmers.listFarmers(db,req.actor!.org_id)));
 api.post('/farmers',write(db,'FARMER_CREATE',S.farmerSchema,(tx,a,d)=>farmers.saveFarmer(tx,a,null,d)));
 api.put('/farmers/:id',write(db,'FARMER_UPDATE',S.farmerSchema,(tx,a,d,req)=>farmers.saveFarmer(tx,a,entityId(req),d)));
 api.post('/farmers/:id/archive',write(db,'FARMER_ARCHIVE',empty,(tx,a,_d,req)=>farmers.archiveFarmer(tx,a,entityId(req))));
 api.get('/products',async(req,res)=>respond(res,await products.productList(db,req.actor!.org_id)));
 api.post('/products',write(db,'PRODUCT_CREATE',S.createProductSchema,(tx,a,d)=>products.createProduct(tx,a,d)));
 api.put('/products/:id',write(db,'PRODUCT_UPDATE',S.productSchema,(tx,a,d,req)=>products.updateProduct(tx,a,entityId(req),d)));
 api.post('/products/:id/economics',write(db,'ECONOMICS',S.economicsSchema,(tx,a,d,req)=>products.appendEconomics(tx,a,entityId(req),d)));
 api.get('/products/:id/history',async(req,res)=>{await products.product(db,req.actor!.org_id,entityId(req));respond(res,await db.all(sql`SELECT * FROM product_economics_history WHERE org_id=${req.actor!.org_id} AND product_id=${entityId(req)} ORDER BY version DESC`));});
 api.post('/products/:id/archive',write(db,'PRODUCT_ARCHIVE',empty,(tx,a,_d,req)=>products.archiveProduct(tx,a,entityId(req))));
 api.get('/harvests',page(db,harvest.listHarvests));
 api.post('/harvests',write(db,'HARVEST_CREATE',S.harvestSchema,(tx,a,d)=>harvest.saveHarvest(tx,a,null,d)));
 api.put('/harvests/:id',write(db,'HARVEST_UPDATE',S.harvestSchema,(tx,a,d,req)=>harvest.saveHarvest(tx,a,entityId(req),d)));
 api.post('/harvests/:id/finalize',write(db,'HARVEST_FINALIZE',empty,(tx,a,_d,req)=>harvest.finalizeHarvest(tx,a,entityId(req))));
 api.post('/harvests/:id/void',write(db,'HARVEST_VOID',S.reasonSchema,(tx,a,d,req)=>harvest.voidHarvest(tx,a,entityId(req),d.reason)));
 api.get('/inventory',async(req,res)=>respond(res,await inventory.inventoryList(db,req.actor!.org_id)));
 api.get('/inventory/:id/movements',async(req,res)=>{const p=pagination.parse(req.query);const rows=await inventory.movements(db,req.actor!.org_id,entityId(req),p.limit+1,p.offset);respond(res,{items:rows.slice(0,p.limit),next_offset:rows.length>p.limit?p.offset+p.limit:null});});
 api.get('/production/plans',page(db,production.listPlans));
 api.post('/production/plans',write(db,'PLAN_CREATE',S.planSchema,(tx,a,d)=>production.savePlan(tx,a,null,d)));
 api.put('/production/plans/:id',write(db,'PLAN_UPDATE',S.planSchema,(tx,a,d,req)=>production.savePlan(tx,a,entityId(req),d)));
 api.post('/production/plans/:id/cancel',write(db,'PLAN_CANCEL',S.reasonSchema,(tx,a,d,req)=>production.cancelPlan(tx,a,entityId(req),d.reason)));
 api.get('/production/batches',page(db,production.listBatches));
 api.post('/production/batches',write(db,'PRODUCTION_COMPLETE',S.productionSchema,(tx,a,d)=>production.completeProduction(tx,a,d)));
 api.post('/production/batches/:id/void',write(db,'PRODUCTION_VOID',S.reasonSchema,(tx,a,d,req)=>production.voidProduction(tx,a,entityId(req),d.reason)));
 api.get('/sales',page(db,sales.listSales));
 api.get('/sales/:id',async(req,res)=>respond(res,await sales.saleDetail(db,req.actor!.org_id,entityId(req))));
 api.post('/sales',write(db,'SALE_RECORD',S.saleSchema,(tx,a,d)=>sales.recordSale(tx,a,d)));
 api.post('/sales/:id/void',write(db,'SALE_VOID',S.reasonSchema,(tx,a,d,req)=>sales.voidSale(tx,a,entityId(req),d.reason)));
 api.post('/sales-day/confirm',write(db,'SALES_DAY_CONFIRM',S.confirmationSchema,(tx,a,d)=>sales.confirmSalesDay(tx,a,d)));
 api.get('/opnames',page(db,opname.listOpnames));
 api.post('/opnames',write(db,'OPNAME_START',S.opnameStartSchema,(tx,a,d)=>opname.startOpname(tx,a,d.item_id)));
 api.post('/opnames/:id/refresh',write(db,'OPNAME_REFRESH',empty,(tx,a,_d,req)=>opname.refreshOpname(tx,a,entityId(req))));
 api.post('/opnames/:id/complete',write(db,'OPNAME_COMPLETE',S.opnameCompleteSchema,(tx,a,d,req)=>opname.completeOpname(tx,a,entityId(req),d)));
 api.post('/opnames/:id/cancel',write(db,'OPNAME_CANCEL',S.reasonSchema,(tx,a,d,req)=>opname.cancelOpname(tx,a,entityId(req),d.reason)));
 async function period(req:Request){const org=await orgs.organization(db,req.actor!.org_id),today=orgs.localDate(org.timezone);return z.strictObject({from:S.date.default(today),to:S.date.default(today)}).parse(req.query);}
 api.get('/reports',async(req,res)=>{const p=await period(req);respond(res,await reports.buildReport(db,req.actor!.org_id,p.from,p.to));});
 api.get('/reports/pdf',async(req,res)=>{const p=await period(req);const report=await reports.buildReport(db,req.actor!.org_id,p.from,p.to);const pdf=await reports.reportPdf(report,req.actor!);const filename=`laporan-${p.from}-${p.to}.pdf`;if((req.get('accept')??'').includes('application/json'))return respond(res,{filename,content_base64:pdf.toString('base64')});res.type('application/pdf').setHeader('Content-Disposition',`attachment; filename="${filename}"`);res.send(pdf);});
 api.get('/users',async(req,res)=>respond(res,await users.listUsers(db,req.actor!.org_id)));
 api.post('/users/invitations',write(db,'ADMIN_INVITE',S.inviteSchema,(tx,a,d)=>auth.inviteAdmin(tx,a,d.email,d.name),'MANAGE_USERS'));
 api.get('/users/invitations',async(req,res)=>{if(req.actor!.role!=='OWNER')throw new AppError(403,'FORBIDDEN','Hanya Owner dapat melihat undangan.');respond(res,await db.all(sql`SELECT id,name,email,expires_at,consumed_at,created_at FROM auth_tokens WHERE org_id=${req.actor!.org_id} AND kind='INVITE' ORDER BY created_at DESC LIMIT 100`));});
 api.put('/users/:id/active',write(db,'ADMIN_STATUS',z.strictObject({active:z.boolean()}),(tx,a,d,req)=>users.setAdminActive(tx,a,entityId(req),d.active),'MANAGE_USERS'));
 api.post('/users/:id/transfer-owner',write(db,'OWNER_TRANSFER',S.ownerTransferSchema,(tx,a,d,req)=>users.transferOwner(tx,a,entityId(req),d.current_password),'MANAGE_USERS'));
 api.get('/audit',page(db,audit.listAudit));
 api.get('/notifications',async(req,res)=>respond(res,await notifications.notificationState(db,req.actor!.org_id,req.actor!.id)));
 api.post('/notifications/push',write(db,'PUSH_SUBSCRIBE',S.pushSchema,(tx,a,d)=>notifications.subscribePush(tx,a,d)));
 api.delete('/notifications/push',write(db,'PUSH_UNSUBSCRIBE',empty,(tx,a)=>notifications.unsubscribePush(tx,a)));
 const upload=multer({storage:multer.memoryStorage(),limits:{fileSize:5*1024*1024,files:1,fields:0,parts:1}});
 api.post('/files',upload.single('image'),async(req,res)=>{
  if(!req.file)throw new AppError(422,'FILE_REQUIRED','Pilih gambar terlebih dahulu.');
  const image=await files.prepareImage(req.file.buffer),fingerprint=hash(image.toString('base64'));
  respond(res,await mutate(db,req.actor!,key(req),'IMAGE_UPLOAD',{sha256:fingerprint},tx=>files.uploadImage(tx,req.actor!,image)));
 });
 api.get('/files/:id',async(req,res)=>res.redirect(302,await files.signedImage(db,req.actor!.org_id,entityId(req))));
 api.get('/overview',async(req,res)=>{
  const org=await orgs.organization(db,req.actor!.org_id),today=orgs.localDate(org.timezone);
  const [counts]=await db.all(sql`SELECT (SELECT count(*)::text FROM harvests WHERE org_id=${org.id}) AS harvest_count,(SELECT count(*)::text FROM sales WHERE org_id=${org.id} AND status='COMPLETED') AS sale_count,(SELECT count(*)::text FROM production_plans WHERE org_id=${org.id} AND status='NEEDS_REVIEW') AS plans_needing_review`);
  const [totals]=await db.all(sql`SELECT count(*)::text AS sale_count,coalesce(sum(net_rp),0)::text AS net_rp FROM sales WHERE org_id=${org.id} AND status='COMPLETED' AND business_date=${today}`);
  respond(res,{organization_name:org.name,today,counts,today_sales:totals,inventory:await inventory.inventoryList(db,org.id)});
 });
 app.use('/api',(_req,_res,next)=>next(new AppError(404,'NOT_FOUND','Endpoint tidak ditemukan.')));
 const web=path.resolve('dist/web');
 if(existsSync(web)){
  app.use(express.static(web,{index:false,maxAge:0,setHeaders:(res,file)=>{if(file.includes('/assets/'))res.setHeader('Cache-Control','public,max-age=31536000,immutable');else res.setHeader('Cache-Control','no-cache');}}));
  app.get('/{*path}',(_req,res)=>{res.setHeader('Cache-Control','no-store');res.sendFile(path.join(web,'index.html'));});
 }
 app.use((error:unknown,_req:Request,res:Response,_next:NextFunction)=>{
  let e:any=error;let depth=0;while(e?.cause&&depth++<4)e=e.cause;
  let status=500,code='INTERNAL_ERROR',message='Permintaan belum berhasil. Coba lagi atau hubungi pengelola.',details:unknown;
  if(error instanceof AppError){({status,code,message,details}=error);}
  else if(error instanceof ZodError){status=422;code='VALIDATION';message='Periksa isian yang belum sesuai.';details=error.issues.map(v=>({field:v.path.join('.'),message:v.message}));}
  else if(error instanceof multer.MulterError){status=413;code='UPLOAD_LIMIT';message='Unggah satu gambar JPEG, PNG atau WebP, maksimal 5 MB.';}
  else if(e?.code==='23505'){status=409;code='CONFLICT';message='Data sudah ada atau tindakan berbenturan dengan catatan lain.';}
  else if(e?.code==='23503'){status=422;code='INVALID_REFERENCE';message='Data terkait tidak tersedia dalam organisasi ini.';}
  else if(['23514','22003'].includes(e?.code)){status=409;code='INVALID_QUANTITY';message='Jumlah tidak valid atau stok tidak mencukupi. Muat ulang dan periksa kembali.';}
  else if(['40001','40P01','55P03','57014'].includes(e?.code)){status=409;code='CONCURRENT_CHANGE';message='Data berubah atau sedang digunakan. Muat ulang dan coba lagi.';}
  else if(['ECONNREFUSED','ENOTFOUND','ETIMEDOUT','57P01'].includes(e?.code)){status=503;code='DATABASE_UNAVAILABLE';message='Layanan sedang tidak tersedia. Coba lagi beberapa saat.';}
  else if(e?.type==='entity.too.large'){status=413;code='REQUEST_TOO_LARGE';message='Ukuran permintaan terlalu besar.';}
  else if(e?.type==='entity.parse.failed'){status=400;code='INVALID_JSON';message='Format permintaan tidak valid.';}
  console.error(error);console.error(JSON.stringify({event:'request_failed',request_id:res.locals.request_id,status,code}));
  res.status(status).json({error:{code,message,...(details?{details}:{}),request_id:res.locals.request_id}});
 });
 return app;
}
