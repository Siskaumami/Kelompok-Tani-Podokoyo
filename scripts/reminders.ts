import { connectDatabase } from '../apps/server/src/core/database.js';
import { runResetEmailJob } from '../apps/server/src/modules/auth/service.js';
import { runReminderJob } from '../apps/server/src/modules/notifications/service.js';
const {db,pool}=connectDatabase();
try{console.info(JSON.stringify({password_reset:await runResetEmailJob(db),reminders:await runReminderJob(db)}));}catch{console.error('Reminder job failed. Check database and provider configuration.');process.exitCode=1;}finally{await pool?.end();}
