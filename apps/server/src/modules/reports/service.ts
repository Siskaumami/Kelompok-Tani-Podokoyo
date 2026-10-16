import { sql } from 'drizzle-orm';
import PDFDocument from 'pdfkit';
import type { Db } from '../../core/database.js';
import { AppError } from '../../core/errors.js';
import { organization } from '../organizations/service.js';
import type { Actor,Row } from '../../../../../packages/shared/src/schemas.js';
export async function buildReport(db:Db,orgId:string,from:string,to:string){
 if(from>to||Date.parse(to)-Date.parse(from)>366*86400000)throw new AppError(422,'REPORT_RANGE','Pilih rentang laporan paling lama 367 hari.');
 const org=await organization(db,orgId);
 // Every sale and its lines are read in one PostgreSQL statement snapshot.
 const records=await db.all(sql`SELECT s.*,coalesce(jsonb_agg(jsonb_build_object('name',l.name_snapshot,'kind',l.kind,'quantity',l.quantity::text,'unit_price_rp',l.unit_price_rp::text,'unit_hpp_rp',l.unit_hpp_rp::text,'gross_rp',l.gross_rp::text,'hpp_rp',l.hpp_rp::text)) FILTER(WHERE l.id IS NOT NULL),'[]'::jsonb) AS items FROM sales s LEFT JOIN sale_lines l ON l.org_id=s.org_id AND l.sale_id=s.id WHERE s.org_id=${orgId} AND s.business_date>=${from}::date AND s.business_date<=${to}::date GROUP BY s.id ORDER BY s.business_date,s.created_at,s.id LIMIT 5001`);
 if(records.length>5000)throw new AppError(422,'REPORT_TOO_LARGE','Rentang ini terlalu besar. Pilih periode yang lebih singkat.');
 let gradeA=0n,finished=0n,gross=0n,discount=0n,fees=0n,hpp=0n;let count=0,voided=0;
 for(const s of records){if(s.status==='VOIDED'){voided++;continue;}count++;gross+=BigInt(s.gross_rp);discount+=BigInt(s.discount_rp);fees+=BigInt(s.fee_rp);hpp+=BigInt(s.hpp_rp);for(const l of s.items){if(l.kind==='GRADE_A')gradeA+=BigInt(l.gross_rp);else finished+=BigInt(l.gross_rp);}}
 const net=gross-discount-fees;
 return {organization:{name:org.name,timezone:org.timezone},period:{from,to},generated_at:new Date().toISOString(),totals:{grade_a_gross_rp:gradeA.toString(),finished_gross_rp:finished.toString(),gross_rp:gross.toString(),discount_rp:discount.toString(),fee_rp:fees.toString(),net_rp:net.toString(),hpp_rp:hpp.toString(),profit_rp:(net-hpp).toString(),sale_count:count,voided_count:voided},transactions:records};
}
export type Report=Awaited<ReturnType<typeof buildReport>>;
const rp=(n:string)=>'Rp'+new Intl.NumberFormat('id-ID').format(BigInt(n));
export async function reportPdf(report:Report,actor:Actor):Promise<Buffer>{
 const lineCount=report.transactions.reduce((n,s)=>n+4+s.items.length+(s.void_reason?1:0),0);
 if(lineCount>5000)throw new AppError(422,'PDF_TOO_LARGE','Rincian PDF terlalu besar. Pilih periode yang lebih singkat.');
 const doc=new PDFDocument({size:'A4',margin:44,bufferPages:true,info:{Title:'Laporan Penjualan',Author:actor.name}});
 const chunks:Buffer[]=[];const result=new Promise<Buffer>((resolve,reject)=>{doc.on('data',c=>chunks.push(c));doc.on('end',()=>resolve(Buffer.concat(chunks)));doc.on('error',reject);});
 const line=(left:string,right='',bold=false)=>{doc.font(bold?'Helvetica-Bold':'Helvetica').fontSize(10);const height=Math.max(doc.heightOfString(left,{width:325}),right?doc.heightOfString(right,{width:170}):0,14)+7;if(doc.y+height>doc.page.height-doc.page.margins.bottom)doc.addPage();const y=doc.y;doc.fillColor('#193b28').text(left,44,y,{width:325});if(right)doc.text(right,380,y,{width:170,align:'right'});doc.y=y+height;};
 doc.fillColor('#148339').fontSize(24).text('Laporan penjualan');doc.moveDown(.4);
 doc.fillColor('#193b28').fontSize(12).text(report.organization.name);
 doc.fontSize(10).text(`${report.period.from} sampai ${report.period.to} | ${report.organization.timezone}`);
 doc.text(`Dibuat: ${report.generated_at} (UTC)`);doc.text(`Oleh: ${actor.name}`);doc.moveDown();
 const labels:Record<string,string>={grade_a_gross_rp:'Penjualan Grade A',finished_gross_rp:'Penjualan produk jadi',gross_rp:'Pendapatan kotor',discount_rp:'Diskon',fee_rp:'Biaya marketplace',net_rp:'Pendapatan bersih',hpp_rp:'HPP',profit_rp:'Estimasi laba kotor'};
 for(const [key,label] of Object.entries(labels))line(label,rp((report.totals as unknown as Row)[key]),['net_rp','profit_rp'].includes(key));
 doc.moveDown();line('Rincian transaksi','',true);
 if(!report.transactions.length)line('Tidak ada transaksi dalam periode ini.');
 for(const s of report.transactions){
  doc.font('Helvetica').fontSize(10);
  const first=s.items[0];
  const firstHeight=first?doc.heightOfString(`${first.name} - ${first.quantity} ${first.kind==='GRADE_A'?'g':'unit'}`,{width:325})+7:0;
  if(doc.y+firstHeight+70>doc.page.height-doc.page.margins.bottom)doc.addPage();
  line(`${String(s.business_date)} | ${s.channel} | ${s.status}`,s.status==='COMPLETED'?rp(String(s.net_rp)):'Dibatalkan',true);
  line(`ID: ${s.id}`);
  for(const l of s.items)line(`${l.name} - ${l.quantity} ${l.kind==='GRADE_A'?'g':'unit'}`,rp(l.gross_rp));
  line(`Diskon ${rp(String(s.discount_rp))}; biaya ${rp(String(s.fee_rp))}; HPP ${rp(String(s.hpp_rp))}`);
  if(s.void_reason)line(`Alasan pembatalan: ${s.void_reason}`);
 }
 doc.moveDown();doc.fontSize(9).fillColor('#5e7164').text('Laporan operasional berdasarkan snapshot transaksi. Pembatalan mengoreksi periode transaksi asal. Stock opname tidak otomatis membukukan nilai kerugian.');
 const range=doc.bufferedPageRange();
 for(let page=range.start;page<range.start+range.count;page++){doc.switchToPage(page);const bottom=doc.page.margins.bottom;doc.page.margins.bottom=0;doc.font('Helvetica').fontSize(8).fillColor('#6b8273').text(`Tani Desa | ${page+1} / ${range.count}`,44,doc.page.height-28,{width:doc.page.width-88,align:'right',lineBreak:false});doc.page.margins.bottom=bottom;}
 doc.end();return result;
}
