import pg from '../backend/node_modules/pg/lib/index.js';
import {readFile,readdir} from 'node:fs/promises';
if(!process.env.DATABASE_URL_UNPOOLED) throw Error('DATABASE_URL_UNPOOLED required');
const pool=new pg.Pool({connectionString:process.env.DATABASE_URL_UNPOOLED,max:1});
const dir=new URL('../backend/db/migrations/',import.meta.url);
try{for(const f of (await readdir(dir)).filter(f=>f.endsWith('.sql')).sort()){
 await pool.query(await readFile(new URL(f,dir),'utf8'));console.log('Applied '+f);
}}finally{await pool.end();}
