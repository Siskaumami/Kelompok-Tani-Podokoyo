import { createHash } from 'node:crypto';
import { sql } from 'drizzle-orm';
import { z } from 'zod';
import { type Db } from './database.js';
import { AppError, requireValue } from './errors.js';
import type { Actor, Row } from '../../../../packages/shared/src/schemas.js';
export const hash=(v:string)=>createHash('sha256').update(v).digest('hex');
function canonical(v:unknown):string{if(Array.isArray(v))return '['+v.map(canonical).join(',')+']';if(v&&typeof v==='object')return '{'+Object.keys(v).sort().map(k=>JSON.stringify(k)+':'+canonical((v as Row)[k])).join(',')+'}';return JSON.stringify(v);}
export async function audit(tx:Db,a:Actor,action:string,type:string,id:string|null,before:unknown,after:unknown,reason=''){
 await tx.all(sql`INSERT INTO audit_logs(org_id,actor_id,action,entity_type,entity_id,before_data,after_data,reason) VALUES(${a.org_id},${a.id},${action},${type},${id},${JSON.stringify(before)}::jsonb,${JSON.stringify(after)}::jsonb,${reason})`);
}
export function authorize(a:Actor,permission:'OPERATE'|'MANAGE_USERS'|'SETTINGS'){
 if(!a.org_id||a.role==='SUPER_ADMIN')throw new AppError(403,'ORG_ACCESS_REQUIRED','Gunakan akun organisasi untuk mengakses operasional.');
 if(permission!=='OPERATE'&&a.role!=='OWNER')throw new AppError(403,'FORBIDDEN','Tindakan ini hanya dapat dilakukan Owner.');
}
export async function mutate<T>(
  db:Db,
  a:Actor,
  key:string,
  operation:string,
  input:unknown,
  fn:(tx:Db)=>Promise<T>,
  permission:'OPERATE'|'MANAGE_USERS'|'SETTINGS'='OPERATE'
):Promise<T>{
  z.uuid().parse(key);

  const requestHash=hash(canonical(input));

  return db.transaction(async tx=>{
    requireValue(
      (await tx.all(
        sql`SELECT id
            FROM organizations
            WHERE id=${a.org_id}
            FOR UPDATE`
      ))[0]
    );

    const current=requireValue(
      (await tx.all(
        sql`SELECT role,active
            FROM users
            WHERE id=${a.id}
              AND org_id=${a.org_id}`
      ))[0]
    );

    if(!current.active){
      throw new AppError(
        403,
        'ACCOUNT_CHANGED',
        'Akses akun berubah. Masuk kembali.'
      );
    }

    const old=(
      await tx.all(
        sql`SELECT *
            FROM idempotency_keys
            WHERE org_id=${a.org_id}
              AND actor_id=${a.id}
              AND key=${key}`
      )
    )[0];

    if(old){
      if(
        old.operation!==operation ||
        old.request_hash!==requestHash
      ){
        throw new AppError(
          409,
          'IDEMPOTENCY_CONFLICT',
          'Kunci pengiriman sudah digunakan untuk data lain.'
        );
      }

      return old.response as T;
    }

    if(current.role!==a.role){
      throw new AppError(
        403,
        'ACCOUNT_CHANGED',
        'Akses akun berubah. Masuk kembali.'
      );
    }

    authorize(a,permission);

    const result=await fn(tx);

    await tx.all(
      sql`INSERT INTO idempotency_keys(
            org_id,
            actor_id,
            key,
            operation,
            request_hash,
            response
          )
          VALUES(
            ${a.org_id},
            ${a.id},
            ${key},
            ${operation},
            ${requestHash},
            ${JSON.stringify(result)}::jsonb
          )`
    );

    return result;
  });
}