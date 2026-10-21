import pg from 'pg';
import {attachDatabasePool} from '@neon/functions';
import {S3Client,GetObjectCommand} from '@aws-sdk/client-s3';
import {getSignedUrl} from '@aws-sdk/s3-request-presigner';
import {createApi} from './api.mjs';
const pool=new pg.Pool({connectionString:process.env.DATABASE_URL,max:5,statement_timeout:8000,connectionTimeoutMillis:8000});
attachDatabasePool(pool);
const s3=new S3Client({forcePathStyle:true});
export default createApi({query:async(sql,args)=>{
 const c=await pool.connect();
 try{await c.query('BEGIN READ ONLY');await c.query('SET LOCAL ROLE dawa_reader');const r=await c.query(sql,args);await c.query('COMMIT');return r.rows;}
 catch(e){await c.query('ROLLBACK');throw e;}finally{c.release();}
 },
 access:async a=>getSignedUrl(s3,new GetObjectCommand({Bucket:a.bucket,Key:a.object_key}),{expiresIn:300})});
