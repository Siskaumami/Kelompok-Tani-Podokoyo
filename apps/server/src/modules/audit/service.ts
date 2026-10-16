import { sql } from 'drizzle-orm';
import type { Db } from '../../core/database.js';
export const listAudit=(db:Db,org:string,limit:number,offset:number)=>db.all(sql`SELECT a.*,u.name AS actor_name FROM audit_logs a LEFT JOIN users u ON u.id=a.actor_id WHERE a.org_id=${org} ORDER BY a.created_at DESC,a.id DESC LIMIT ${limit} OFFSET ${offset}`);
