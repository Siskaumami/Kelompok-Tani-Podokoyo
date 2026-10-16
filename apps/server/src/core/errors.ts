export class AppError extends Error {
 constructor(public status:number,public code:string,message:string,public details?:unknown){super(message);}
}
export function requireValue<T>(v:T|null|undefined,message='Data tidak ditemukan.'):T{if(v==null)throw new AppError(404,'NOT_FOUND',message);return v;}
export function assert(condition:unknown,message:string,code='INVALID_STATE'):asserts condition{if(!condition)throw new AppError(409,code,message);}
export function checked(v:bigint):string{if(v<0n||v>9_000_000_000_000_000_000n)throw new AppError(422,'AMOUNT_RANGE','Hasil perhitungan di luar batas yang didukung.');return v.toString();}
export const kgAmount=(grams:bigint,rate:bigint)=> (grams*rate+500n)/1000n;
