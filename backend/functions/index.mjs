import pg from 'pg';
import {attachDatabasePool} from '@neon/functions';
import {parseTriggerDelivery} from '@neon/functions/triggers';
import {S3Client,GetObjectCommand} from '@aws-sdk/client-s3';
import {getSignedUrl} from '@aws-sdk/s3-request-presigner';
import {createApi} from './api.mjs';
import {createKnowledgeApi} from '../knowledge/api.mjs';
import {createSourceService} from '../knowledge/service.mjs';
const pool=new pg.Pool({connectionString:process.env.DATABASE_URL,max:5,statement_timeout:8000,connectionTimeoutMillis:8000});
attachDatabasePool(pool);
// Session advisory locks and import transactions require a direct connection.
const jobPool=new pg.Pool({connectionString:process.env.DATABASE_URL_UNPOOLED,max:2,statement_timeout:8000,connectionTimeoutMillis:8000});
attachDatabasePool(jobPool);
const s3=new S3Client({forcePathStyle:true});
async function publicQuery(sql,args){
 const client=await pool.connect();
 try{await client.query('BEGIN READ ONLY');await client.query('SET LOCAL ROLE dawa_reader');const result=await client.query(sql,args);await client.query('COMMIT');return result.rows;}
 catch(e){await client.query('ROLLBACK');throw e;}finally{client.release();}
}
const base=createApi({query:publicQuery,access:async asset=>getSignedUrl(s3,new GetObjectCommand({Bucket:asset.bucket,Key:asset.object_key}),{expiresIn:300})});
export default createKnowledgeApi({base,query:publicQuery,internalQuery:async(sql,args)=>(await jobPool.query(sql,args)).rows,sourceService:createSourceService(jobPool),serviceToken:process.env.DAWA_SOURCE_SERVICE_TOKEN,parseTrigger:parseTriggerDelivery});
