import { config,integrationStatus } from '../../core/config.js';
import { AppError } from '../../core/errors.js';
import { email } from '../../../../../packages/shared/src/schemas.js';
export function requireEmail(){if(!integrationStatus().email)throw new AppError(503,'EMAIL_NOT_CONFIGURED','Pengiriman email belum tersedia. Hubungi pengelola.');email.parse(config.EMAIL_FROM);}
export async function sendEmail(to:string,name:string,subject:string,text:string){
 requireEmail();
 try{
  const res=await fetch('https://api.brevo.com/v3/smtp/email',{method:'POST',headers:{'api-key':config.BREVO_API_KEY,'Content-Type':'application/json'},body:JSON.stringify({sender:{email:config.EMAIL_FROM,name:config.EMAIL_FROM_NAME},to:[{email:to,name}],subject,textContent:text}),signal:AbortSignal.timeout(10000)});
  if(!res.ok){const body=await res.text();console.error('Brevo rejected email:',res.status,body);throw new Error('provider_rejected');}
  const result=await res.json() as {messageId?:string};if(!result.messageId)throw new Error('missing_provider_id');
  return {messageId:result.messageId};
 }catch{throw new AppError(502,'EMAIL_DELIVERY_FAILED','Penyedia email belum menerima pengiriman. Coba lagi nanti.');}
}
