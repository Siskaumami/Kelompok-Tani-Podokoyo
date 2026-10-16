import { sql } from 'drizzle-orm';
import type { Db } from '../../core/database.js';
import { assert,requireValue } from '../../core/errors.js';
import { audit } from '../../core/transactions.js';
import type { Actor } from '../../../../../packages/shared/src/schemas.js';
export const listUsers=(db:Db,org:string)=>db.all(sql`SELECT id,name,email,role,active,created_at FROM users WHERE org_id=${org} ORDER BY role DESC,name,id`);
export async function setAdminActive(tx:Db,a:Actor,id:string,active:boolean){
 const before=requireValue((await tx.all(sql`SELECT id,name,email,role,active FROM users WHERE org_id=${a.org_id} AND id=${id}`))[0]);assert(before.role==='ADMIN','Hanya akun Admin yang dapat dikelola melalui halaman ini.');
 const [after]=await tx.all(sql`UPDATE users SET active=${active} WHERE org_id=${a.org_id} AND id=${id} RETURNING id,name,email,role,active`);
 if(!active)await tx.all(sql`DELETE FROM sessions WHERE user_id=${id}`);
 await audit(tx,a,active?'ADMIN_REACTIVATED':'ADMIN_DEACTIVATED','USER',id,before,after);return after;
}
