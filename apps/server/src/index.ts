import { createApp } from './app.js';
import { connectDatabase } from './core/database.js';
import { config,integrationStatus } from './core/config.js';
import { runResetEmailJob } from './modules/auth/service.js';
import { runReminderJob } from './modules/notifications/service.js';
const {db,pool}=connectDatabase();
const server=createApp(db).listen(config.PORT,'0.0.0.0',()=>console.info(JSON.stringify({event:'server_started',port:config.PORT,integrations:integrationStatus()})));
let running=false;
const timer=config.BACKGROUND_WORKER_ENABLED==='true'&&pool?setInterval(async()=>{if(running)return;running=true;try{await runResetEmailJob(db);if(config.REMINDER_WORKER_ENABLED==='true')await runReminderJob(db);}catch{console.error(JSON.stringify({event:'reminder_job_failed'}));}finally{running=false;}},60000):null;
if(timer)timer.unref();
async function stop(){if(timer)clearInterval(timer);server.close(async()=>{await pool?.end();process.exit(0);});setTimeout(()=>process.exit(1),10000).unref();}
process.on('SIGTERM',stop);process.on('SIGINT',stop);
