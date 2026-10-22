import pg from '../backend/node_modules/pg/lib/index.js';
import {seedSourceRegistry} from '../backend/knowledge/service.mjs';
if(!process.env.DATABASE_URL_UNPOOLED) throw Error('DATABASE_URL_UNPOOLED required');
const pool=new pg.Pool({connectionString:process.env.DATABASE_URL_UNPOOLED,max:1});
const client=await pool.connect();
try{await seedSourceRegistry(client);console.log('Source registry seeded; clinical text disabled');}finally{client.release();await pool.end();}
