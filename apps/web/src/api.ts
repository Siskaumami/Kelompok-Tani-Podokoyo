import { QueryClient } from '@tanstack/react-query';
export class ApiError extends Error{constructor(message:string,public code:string,public status:number,public details?:unknown){super(message);}}
let csrf='';export const setCsrf=(value:string)=>{csrf=value;};
export const queryClient=new QueryClient({defaultOptions:{queries:{staleTime:15000,refetchOnWindowFocus:true,refetchOnReconnect:true,retry:(attempt,e)=>attempt<1&&(!(e instanceof ApiError)||e.status>=500)},mutations:{retry:false}}});
export async function request<T=any>(path:string,options:RequestInit={},key?:string):Promise<T>{
 const method=options.method??'GET';
 if(method!=='GET'&&!navigator.onLine)throw new ApiError('Tidak ada koneksi. Data belum dikirim atau disimpan.','OFFLINE',0);
 let res:Response;
 try{res=await fetch('/api/v1'+path,{...options,credentials:'same-origin',cache:'no-store',signal:AbortSignal.timeout(25000),headers:{...(options.body instanceof FormData?{}:{'Content-Type':'application/json'}),...(csrf?{'X-CSRF-Token':csrf}:{}),...(key?{'Idempotency-Key':key}:{}),...options.headers}});}catch{throw new ApiError(method==='GET'?'Data belum dapat dimuat. Periksa koneksi internet.':'Respons server belum diterima. Status penyimpanan belum pasti. Coba kirim ulang tanpa mengubah data untuk memeriksa hasilnya.','NETWORK_ERROR',0);}
 let body:any;try{body=await res.json();}catch{throw new ApiError('Respons server belum dapat dibaca. Muat ulang untuk memeriksa catatan.','NETWORK_ERROR',res.status);}
 if(!res.ok)throw new ApiError(body.error?.message??'Permintaan belum berhasil.',body.error?.code??'HTTP_ERROR',res.status,body.error?.details);
 return body.data as T;
}
export async function save(path:string,method:string,payload:unknown,key:string){const result=await request(path,{method,body:JSON.stringify(payload)},key);await queryClient.invalidateQueries();return result;}
export async function downloadPdf(from:string,to:string){
 const response=await fetch(`/api/v1/reports/pdf?from=${from}&to=${to}`,{credentials:'same-origin',cache:'no-store'});
 if(!response.ok){const d=await response.json();throw new Error(d.error?.message??'Laporan belum dapat diunduh.');}
 const url=URL.createObjectURL(await response.blob()),a=document.createElement('a');a.href=url;a.download=`laporan-${from}-${to}.pdf`;a.click();setTimeout(()=>URL.revokeObjectURL(url),1000);
}
