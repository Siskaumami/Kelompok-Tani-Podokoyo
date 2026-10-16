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
 const transactions=report.transactions??[];
 const lineCount=transactions.reduce((n,s)=>n+4+(Array.isArray(s.items)?s.items.length:0)+(s.void_reason?1:0),0);
 if(lineCount>5000)throw new AppError(422,'PDF_TOO_LARGE','Rincian PDF terlalu besar. Pilih periode yang lebih singkat.');

 const doc=new PDFDocument({
  size:'A4',
  margin:44,
  info:{Title:'Laporan Penjualan',Author:actor.name}
 });

 const chunks:Buffer[]=[];
 const result=new Promise<Buffer>((resolve,reject)=>{
  doc.on('data',(c:Buffer)=>chunks.push(c));
  doc.on('end',()=>resolve(Buffer.concat(chunks)));
  doc.on('error',reject);
 });

 const C={
  green:'#148339',
  dark:'#173E29',
  muted:'#63756A',
  border:'#DCE8E0',
  soft:'#F5FAF7',
  highlight:'#E8F6EC',
  cancelled:'#FFF4F4',
  white:'#FFFFFF'
 };

 const margin=44;
 const contentWidth=doc.page.width-(margin*2);
 let y=44;

 const money=(value:unknown)=>rp(String(value??'0'));

 const dateLabel=(value:unknown)=>{
  const raw=String(value??'').slice(0,10);
  const [year,month,day]=raw.split('-').map(Number);
  if(!year||!month||!day)return raw;
  return new Intl.DateTimeFormat('id-ID',{
   day:'2-digit',
   month:'short',
   year:'numeric',
   timeZone:'UTC'
  }).format(new Date(Date.UTC(year,month-1,day)));
 };

 const dateLong=(value:string)=>{
  const [year,month,day]=value.split('-').map(Number);
  return new Intl.DateTimeFormat('id-ID',{
   day:'numeric',
   month:'long',
   year:'numeric',
   timeZone:'UTC'
  }).format(new Date(Date.UTC(year,month-1,day)));
 };

 const channelLabel=(value:unknown)=>{
  const labels:Record<string,string>={
   OFFLINE:'Langsung',
   SHOPEE:'Shopee',
   TOKOPEDIA:'Tokopedia',
   WHATSAPP:'WhatsApp'
  };
  const key=String(value??'');
  return labels[key]??key;
 };

 const statusLabel=(value:unknown)=>{
  const labels:Record<string,string>={
   COMPLETED:'Selesai',
   VOIDED:'Dibatalkan'
  };
  const key=String(value??'');
  return labels[key]??key;
 };

 const quantityLabel=(item:any)=>{
  const quantity=Number(item.quantity??0);
  if(item.kind==='GRADE_A'){
   const kg=quantity/1000;
   return `${new Intl.NumberFormat('id-ID',{maximumFractionDigits:3}).format(kg)} kg`;
  }
  return `${new Intl.NumberFormat('id-ID',{maximumFractionDigits:2}).format(quantity)} unit`;
 };

 const addPage=()=>{
  doc.addPage();
  y=44;
 };

 const ensureSpace=(height:number)=>{
  if(y+height>doc.page.height-margin)addPage();
 };

 const cellText=(
  text:string,
  x:number,
  top:number,
  width:number,
  options:{bold?:boolean;size?:number;align?:'left'|'right'|'center';color?:string}={}
 )=>{
  doc
   .font(options.bold?'Helvetica-Bold':'Helvetica')
   .fontSize(options.size??9)
   .fillColor(options.color??C.dark)
   .text(text,x,top,{
    width,
    align:options.align??'left',
    lineGap:1
   });
 };

 const textHeight=(text:string,width:number,size=9,bold=false)=>{
  doc.font(bold?'Helvetica-Bold':'Helvetica').fontSize(size);
  return doc.heightOfString(text,{width,lineGap:1});
 };

 // HEADER
 doc.font('Helvetica-Bold').fontSize(25).fillColor(C.green)
  .text('Laporan penjualan',margin,y,{width:contentWidth});
 y+=37;

 doc.font('Helvetica-Bold').fontSize(12).fillColor(C.dark)
  .text(report.organization.name,margin,y);
 y+=19;

 doc.font('Helvetica').fontSize(9).fillColor(C.muted)
  .text(`Periode: ${dateLong(report.period.from)} - ${dateLong(report.period.to)}`,margin,y);
 y+=14;

 const generated=new Intl.DateTimeFormat('id-ID',{
  day:'2-digit',
  month:'long',
  year:'numeric',
  hour:'2-digit',
  minute:'2-digit',
  timeZone:'Asia/Jakarta'
 }).format(new Date(report.generated_at));

 doc.text(`Dibuat: ${generated} WIB`,margin,y);
 y+=14;
 doc.text(`Dibuat oleh: ${actor.name}`,margin,y);
 y+=22;

 doc.moveTo(margin,y).lineTo(margin+contentWidth,y).strokeColor(C.border).stroke();
 y+=24;

 // RINGKASAN
 doc.font('Helvetica-Bold').fontSize(14).fillColor(C.dark)
  .text('Ringkasan pendapatan',margin,y);
 y+=24;

 const summaryRows=[
  ['Penjualan Grade A',money(report.totals.grade_a_gross_rp)],
  ['Penjualan produk jadi',money(report.totals.finished_gross_rp)],
  ['Pendapatan kotor',money(report.totals.gross_rp)],
  ['(-) Diskon',money(report.totals.discount_rp)],
  ['(-) Biaya marketplace',money(report.totals.fee_rp)],
  ['Pendapatan bersih',money(report.totals.net_rp)],
  ['(-) HPP',money(report.totals.hpp_rp)],
  ['Estimasi laba kotor',money(report.totals.profit_rp)]
 ] as const;

 const summaryLabelWidth=330;
 const summaryValueWidth=contentWidth-summaryLabelWidth;
 const summaryHeaderHeight=28;

 doc.rect(margin,y,contentWidth,summaryHeaderHeight).fill(C.green);
 cellText('Keterangan',margin+10,y+8,summaryLabelWidth-20,{bold:true,color:C.white});
 cellText('Nilai',margin+summaryLabelWidth,y+8,summaryValueWidth-10,{
  bold:true,
  align:'center',
  color:C.white
 });
 y+=summaryHeaderHeight;

 summaryRows.forEach(([label,value],index)=>{
  const highlight=label==='Pendapatan bersih'||label==='Estimasi laba kotor';
  const rowHeight=28;
  doc.rect(margin,y,contentWidth,rowHeight)
   .fillAndStroke(
    highlight?C.highlight:(index%2===0?C.white:C.soft),
    C.border
   );

  cellText(label,margin+10,y+8,summaryLabelWidth-20,{bold:highlight});
  cellText(value,margin+summaryLabelWidth,y+8,summaryValueWidth-10,{
   bold:highlight,
   align:'center'
  });
  y+=rowHeight;
 });

 y+=28;

 // RINCIAN TRANSAKSI
 ensureSpace(70);

 doc.font('Helvetica-Bold').fontSize(14).fillColor(C.dark)
  .text('Rincian transaksi',margin,y);
 y+=17;

 doc.font('Helvetica').fontSize(8.5).fillColor(C.muted)
  .text(
   `${report.totals.sale_count} transaksi selesai - ${report.totals.voided_count} transaksi dibatalkan`,
   margin,
   y
  );
 y+=22;

 const cols=[
 {label:'Tanggal',width:62},
 {label:'Penjualan',width:60},
 {label:'Status',width:58},
 {label:'Rincian',width:137},
 {label:'Pendapatan',width:65},
 {label:'HPP',width:60},
 {label:'Profit',width:65}
];

const drawTransactionHeader=()=>{
 const h=30;
 let x=margin;

 doc.rect(margin,y,contentWidth,h).fill(C.green);

 for(const col of cols){
  cellText(col.label,x+4,y+9,col.width-8,{
   bold:true,
   size:8.2,
   color:C.white,
   align:'center'
  });

  x+=col.width;
 }

 y+=h;
};

drawTransactionHeader();

if(!transactions.length){
 const h=40;

 doc.rect(margin,y,contentWidth,h).fillAndStroke(C.soft,C.border);

 cellText(
  'Tidak ada transaksi dalam periode ini.',
  margin+10,
  y+13,
  contentWidth-20,
  {color:C.muted}
 );

 y+=h;
}

for(let index=0;index<transactions.length;index++){
 const sale=transactions[index];
 const items=Array.isArray(sale.items)?sale.items:[];

 const itemLines=items.map((item:any)=>
  `${String(item.name??'Barang')} - ${quantityLabel(item)}`
 );

 const extra:string[]=[];

 if(sale.status==='VOIDED'){
  extra.push(`Nilai sebelum dibatalkan: ${money(sale.gross_rp)}`);

  if(sale.void_reason){
   extra.push(`Alasan: ${String(sale.void_reason)}`);
  }
 }else{
  const discount=BigInt(String(sale.discount_rp??'0'));
  const fee=BigInt(String(sale.fee_rp??'0'));

  if(discount>0n){
   extra.push(`Diskon: ${money(sale.discount_rp)}`);
  }

  if(fee>0n){
   extra.push(`Biaya marketplace: ${money(sale.fee_rp)}`);
  }
 }

 const detail=[...itemLines,...extra].join('\n')||'Tidak ada rincian';

 const transactionProfit=
  sale.status==='VOIDED'
   ?0n
   :BigInt(String(sale.net_rp??'0'))-BigInt(String(sale.hpp_rp??'0'));

 const values=[
  dateLabel(sale.business_date),
  channelLabel(sale.channel),
  statusLabel(sale.status),
  detail,
  sale.status==='VOIDED'?'-':money(sale.net_rp),
  sale.status==='VOIDED'?'-':money(sale.hpp_rp),
  sale.status==='VOIDED'?'-':money(transactionProfit)
 ];

 const heights=values.map((value,i)=>
  textHeight(
   value,
   cols[i].width-12,
   8.2,
   i===2
  )
 );

 const rowHeight=Math.max(36,...heights.map(v=>v+14));

 if(y+rowHeight>doc.page.height-margin-28){
  addPage();

  doc.font('Helvetica-Bold')
   .fontSize(12)
   .fillColor(C.dark)
   .text('Rincian transaksi - lanjutan',margin,y);

  y+=22;

  drawTransactionHeader();
 }

 const fill=
  sale.status==='VOIDED'
   ?C.cancelled
   :(index%2===0?C.white:C.soft);

 doc.rect(margin,y,contentWidth,rowHeight)
  .fillAndStroke(fill,C.border);

 let x=margin;

 values.forEach((value,i)=>{
  const isDetail=i===3;

  cellText(value,x+6,y+8,cols[i].width-12,{
   bold:i===2,
   size:8.2,
   align:isDetail?'left':'center',
   color:sale.status==='VOIDED'&&i===2?'#A33A3A':C.dark
  });

  if(i<cols.length-1){
   doc.moveTo(x+cols[i].width,y)
    .lineTo(x+cols[i].width,y+rowHeight)
    .strokeColor(C.border)
    .stroke();
  }

  x+=cols[i].width;
 });

 y+=rowHeight;
}

 y+=20;
 ensureSpace(55);

 doc.moveTo(margin,y).lineTo(margin+contentWidth,y).strokeColor(C.border).stroke();
 y+=12;

 doc.font('Helvetica').fontSize(8).fillColor(C.muted)
  .text(
   'Catatan: transaksi yang dibatalkan tetap ditampilkan sebagai riwayat, tetapi tidak dihitung dalam pendapatan maupun HPP laporan.',
   margin,
   y,
   {width:contentWidth,lineGap:2}
  );

 doc.end();

 const pdf=await result;
 if(!pdf.length)throw new AppError(500,'PDF_EMPTY','Laporan belum berhasil dibuat.');
 return pdf;
}