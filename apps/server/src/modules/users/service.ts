import { sql } from 'drizzle-orm';
import type { Db } from '../../core/database.js';
import { assert,requireValue } from '../../core/errors.js';
import { audit } from '../../core/transactions.js';
import { verifyPassword } from '../auth/service.js';
import type { Actor } from '../../../../../packages/shared/src/schemas.js';

export const listUsers=(db:Db,org:string)=>
  db.all(
    sql`SELECT id,name,email,role,active,created_at
        FROM users
        WHERE org_id=${org}
        ORDER BY role DESC,name,id`
  );

export async function setAdminActive(
  tx:Db,
  a:Actor,
  id:string,
  active:boolean
){
  const before=requireValue(
    (await tx.all(
      sql`SELECT id,name,email,role,active
          FROM users
          WHERE org_id=${a.org_id}
            AND id=${id}`
    ))[0]
  );

  assert(
    before.role==='ADMIN',
    'Hanya akun Admin yang dapat dikelola melalui halaman ini.'
  );

  const [after]=await tx.all(
    sql`UPDATE users
        SET active=${active}
        WHERE org_id=${a.org_id}
          AND id=${id}
        RETURNING id,name,email,role,active`
  );

  if(!active){
    await tx.all(
      sql`DELETE FROM sessions
          WHERE user_id=${id}`
    );
  }

  await audit(
    tx,
    a,
    active?'ADMIN_REACTIVATED':'ADMIN_DEACTIVATED',
    'USER',
    id,
    before,
    after
  );

  return after;
}

export async function transferOwner(
  tx:Db,
  a:Actor,
  id:string,
  currentPassword:string
){
  const current=requireValue(
    (await tx.all(
      sql`SELECT id,name,email,role,active,password_hash
          FROM users
          WHERE org_id=${a.org_id}
            AND id=${a.id}
          FOR UPDATE`
    ))[0]
  );

  assert(
    current.active && current.role==='OWNER',
    'Akun ini bukan lagi Owner aktif. Muat ulang lalu coba lagi.',
    'ACCOUNT_CHANGED'
  );

  assert(
    await verifyPassword(
      current.password_hash,
      currentPassword
    ),
    'Kata sandi saat ini tidak sesuai.',
    'INVALID_PASSWORD'
  );

  assert(
    id!==a.id,
    'Pilih akun Admin lain sebagai Owner baru.'
  );

  const target=requireValue(
    (await tx.all(
      sql`SELECT id,name,email,role,active
          FROM users
          WHERE org_id=${a.org_id}
            AND id=${id}
          FOR UPDATE`
    ))[0]
  );

  assert(
    target.role==='ADMIN',
    'Owner hanya dapat dipindahkan ke akun Admin.'
  );

  assert(
    target.active,
    'Aktifkan akun Admin ini sebelum menjadikannya Owner.'
  );

  const owners=await tx.all(
    sql`SELECT id
        FROM users
        WHERE org_id=${a.org_id}
          AND role='OWNER'
        FOR UPDATE`
  );

  assert(
    owners.length===1 && owners[0].id===a.id,
    'Status Owner organisasi tidak konsisten. Hubungi pengelola sistem.',
    'OWNER_STATE_INVALID'
  );

  const [previousOwner]=await tx.all(
    sql`UPDATE users
        SET role='ADMIN'
        WHERE org_id=${a.org_id}
          AND id=${a.id}
        RETURNING id,name,email,role,active`
  );

  const [newOwner]=await tx.all(
    sql`UPDATE users
        SET role='OWNER'
        WHERE org_id=${a.org_id}
          AND id=${id}
        RETURNING id,name,email,role,active`
  );

  await tx.all(
    sql`UPDATE auth_tokens
        SET created_by=${id}
        WHERE org_id=${a.org_id}
          AND kind='INVITE'
          AND consumed_at IS NULL
          AND expires_at>now()
          AND created_by=${a.id}`
  );

  await tx.all(
    sql`DELETE FROM sessions
        WHERE user_id=${id}`
  );

  await audit(
    tx,
    a,
    'OWNER_TRANSFERRED',
    'ORGANIZATION',
    a.org_id,
    {
      owner:{
        id:current.id,
        name:current.name,
        email:current.email
      },
      target:{
        id:target.id,
        name:target.name,
        email:target.email,
        role:target.role
      }
    },
    {
      owner:{
        id:newOwner.id,
        name:newOwner.name,
        email:newOwner.email
      },
      previous_owner:{
        id:previousOwner.id,
        name:previousOwner.name,
        email:previousOwner.email,
        role:previousOwner.role
      }
    },
    `Owner dipindahkan dari ${current.name} ke ${target.name}.`
  );

  return {
    owner:newOwner,
    previous_owner:previousOwner
  };
}