import pg from '../backend/node_modules/pg/lib/index.js';
import {readFile} from 'node:fs/promises';
if(!process.env.DATABASE_URL_UNPOOLED) throw Error('DATABASE_URL_UNPOOLED required');
const pool=new pg.Pool({connectionString:process.env.DATABASE_URL_UNPOOLED,max:1});
const seed=JSON.parse(await readFile(new URL('../backend/db/seed/content.json',import.meta.url)));
const c=await pool.connect();
try{await c.query('BEGIN');for(const x of seed.items){
 await c.query(`INSERT INTO sources(id,source_type,source_title,source_url,publisher,license,attribution,redistribution_allowed) VALUES($1,'original_summary',$2,$3,'Dawa & Hayah',$4,$5,true) ON CONFLICT DO NOTHING`,[x.id,x.source_title,x.source_url,x.license,x.attribution]);
 await c.query(`INSERT INTO content_items(canonical_id,category,status,review_status,clinical,source_id) VALUES($1,$2,$3,$4,false,$1) ON CONFLICT DO NOTHING`,[x.id,x.category,x.status,x.review_status]);
 for(const lang of ['ar','en']) await c.query(`INSERT INTO content_translations(content_id,locale,title,body) VALUES($1,$2,$3,$4) ON CONFLICT DO NOTHING`,[x.id,lang,x['title_'+lang],x['body_'+lang]]);
}await c.query('COMMIT');console.log('Seed: '+seed.items.length);}catch(e){await c.query('ROLLBACK');throw e;}finally{c.release();await pool.end();}
