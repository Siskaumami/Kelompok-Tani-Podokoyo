import { readFile,readdir } from 'node:fs/promises';
import { createHash } from 'node:crypto';
import { Pool } from 'pg';
import { config } from '../apps/server/src/core/config.js';
export async function migrate(){
 const url=config.DATABASE_MIGRATION_URL||config.DATABASE_URL;
 if(!url)throw new Error('Set DATABASE_URL or DATABASE_MIGRATION_URL before migration.');
 const pool=new Pool({connectionString:url,max:1});const client=await pool.connect();
 try{
  await client.query('BEGIN');await client.query("SELECT pg_advisory_xact_lock(1548732)");
  await client.query('CREATE TABLE IF NOT EXISTS schema_migrations(name text PRIMARY KEY,checksum text NOT NULL,applied_at timestamptz NOT NULL DEFAULT now())');
  for(const name of (await readdir('database/migrations')).filter(n=>n.endsWith('.sql')).sort()){
   const content=await readFile('database/migrations/'+name,'utf8'),checksum=createHash('sha256').update(content).digest('hex');
   const existing=await client.query('SELECT checksum FROM schema_migrations WHERE name=$1',[name]);
   if(existing.rows[0]){if(existing.rows[0].checksum!==checksum)throw new Error('Applied migration was changed: '+name);continue;}
   await client.query(content);await client.query('INSERT INTO schema_migrations(name,checksum) VALUES($1,$2)',[name,checksum]);console.info('Applied '+name);
  }
  await client.query('COMMIT');
 }catch(e){await client.query('ROLLBACK');throw e;}finally{client.release();await pool.end();}
}
await migrate();
