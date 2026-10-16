import { Pool } from 'pg';
import { drizzle } from 'drizzle-orm/node-postgres';
import { type SQL } from 'drizzle-orm';
import { config } from './config.js';
import { AppError } from './errors.js';
import type { Row } from '../../../../packages/shared/src/schemas.js';
export interface Db { all<T=Row>(query:SQL):Promise<T[]>; transaction<T>(fn:(tx:Db)=>Promise<T>):Promise<T>; }
interface Executor {execute(q:SQL):Promise<{rows:unknown[]}>;}
export function executorDb(exec:Executor,transact:<T>(fn:(tx:Executor)=>Promise<T>)=>Promise<T>):Db {
 return {all:async<T>(q:SQL)=>JSON.parse(JSON.stringify((await exec.execute(q)).rows,(_key,v)=>typeof v==='bigint'?v.toString():v)) as T[],transaction:fn=>transact(tx=>fn(executorDb(tx,async()=>{throw new Error('Nested transaction is not supported here.');})))};
}
export function connectDatabase(url=config.DATABASE_URL):{db:Db;pool:Pool|null}{
 if(!url){const unavailable=()=>{throw new AppError(503,'DATABASE_NOT_CONFIGURED','Koneksi database belum dikonfigurasi.');};return {db:{all:unavailable,transaction:unavailable},pool:null};}
 const pool=new Pool({connectionString:url,max:10,connectionTimeoutMillis:10000,idleTimeoutMillis:30000,statement_timeout:20000});
 pool.on('error',()=>console.error(JSON.stringify({event:'database_pool_error'})));
 const driver=drizzle(pool);
 return {db:executorDb(driver,fn=>driver.transaction(tx=>fn(tx))),pool};
}
