import {randomUUID,timingSafeEqual,createHash} from 'node:crypto';
import {MedicalSourceAdapter} from './adapters.mjs';
import {KnowledgeRepository} from './repository.mjs';
import {registry,sourceById} from './registry.mjs';
import {SourceError} from './transport.mjs';
export function checkServiceToken(request,expected){
 if(typeof expected!=='string'||expected.length<32)return false;
 const provided=request.headers.get('authorization')||'';
 const a=createHash('sha256').update(provided).digest(),b=createHash('sha256').update(`Bearer ${expected}`).digest();
 return timingSafeEqual(a,b);
}
export async function seedSourceRegistry(client){
 await client.query('BEGIN');
 try{for(const s of registry){
  await client.query(`INSERT INTO sources(id,source_type,source_title,source_url,publisher,license,attribution,redistribution_allowed) VALUES($1,'official_api',$2,$3,$2,$4,$5,$6) ON CONFLICT(id) DO UPDATE SET source_title=EXCLUDED.source_title,source_url=EXCLUDED.source_url,license=EXCLUDED.license,attribution=EXCLUDED.attribution,redistribution_allowed=EXCLUDED.redistribution_allowed`,[s.source_id,s.source_name,s.base_url,s.license,s.attribution_text,s.allowed_redistribution]);
  await client.query(`INSERT INTO source_policies(source_id,registry,usage_mode,enabled,metadata_allowed,offline_metadata_allowed,clinical_text_allowed,license_evidence_url,terms_checked_at) VALUES($1,$2,$3,$4,$5,$6,false,$7,$8) ON CONFLICT(source_id) DO UPDATE SET registry=EXCLUDED.registry,usage_mode=EXCLUDED.usage_mode,enabled=EXCLUDED.enabled,metadata_allowed=EXCLUDED.metadata_allowed,offline_metadata_allowed=EXCLUDED.offline_metadata_allowed,license_evidence_url=EXCLUDED.license_evidence_url,terms_checked_at=EXCLUDED.terms_checked_at,updated_at=now()`,[s.source_id,JSON.stringify(s),s.usage_mode,s.enabled,s.allowed_redistribution,s.offline_permission,s.license_url,s.terms_checked_at]);
 }
 await client.query('COMMIT');}catch(e){await client.query('ROLLBACK');throw e;}
}
// Both operator calls and genuine Neon schedules use this one bounded importer.
export function createSourceService(pool){
 const adapters=new Map(registry.map(s=>[s.source_id,new MedicalSourceAdapter(s.source_id)]));
 return {async refresh(id,{query=null,cursor=null,key=null,limit=5,identifiers=null}={}){
  const source=sourceById(id);if(!source?.enabled)throw new SourceError('unknown_source',404);
  if(identifiers!==null&&(!Array.isArray(identifiers)||identifiers.length<1||identifiers.length>5||!identifiers.every(v=>typeof v==='string'&&v.length>0&&v.length<=120)))throw new SourceError('invalid_identifiers',400);
  if(identifiers&&['rxnorm','rxterms','pubmed','pubchem','rxclass'].includes(id)&&!identifiers.every(v=>/^\d{1,12}$/.test(v)))throw new SourceError('invalid_identifiers',400);
  if(query!==null&&(typeof query!=='string'||query.length<1||query.length>200))throw new SourceError('invalid_query',400);
  if(cursor!==null&&(typeof cursor!=='string'||cursor.length>1000))throw new SourceError('invalid_cursor',400);
  if(!Number.isInteger(limit)||limit<1||limit>5)throw new SourceError('invalid_limit',400);
  if(key!==null&&(typeof key!=='string'||!/^[a-zA-Z0-9:_-]{1,180}$/.test(key)))throw new SourceError('invalid_job_key',400);
  const client=await pool.connect(),repo=new KnowledgeRepository(client);let locked=false,job=null;
  const adapter=adapters.get(id);
  try{
   locked=(await repo.sql(`SELECT pg_try_advisory_lock(hashtext('dawa_medical_source_import')) AS locked`))[0].locked;
   if(!locked)throw new SourceError('source_job_busy',429);
   const [status]=await repo.sql('SELECT enabled FROM source_policies WHERE source_id=$1',[id]);if(!status?.enabled)throw new SourceError('source_disabled',403);
   const idempotency=`${id}:${key||randomUUID()}`;
   const requestShape={query:query||source.sample_query,cursor,limit,...(identifiers?{identifiers}: {})};
   const requestHash=createHash('sha256').update(JSON.stringify(requestShape)).digest('hex');
   const [prior]=await repo.sql('SELECT * FROM source_fetch_jobs WHERE idempotency_key=$1',[idempotency]);
   if(prior&&prior.request_hash!==requestHash)throw new SourceError('idempotency_conflict',409);
   if(prior?.status==='completed')return {job_id:prior.id,status:'completed',idempotent_replay:true,next_cursor:prior.cursor_value,imported:prior.imported,updated:prior.updated,skipped:prior.skipped};
   const [circuit]=await repo.sql('SELECT circuit_until>now() AS open FROM source_connector_status WHERE source_id=$1',[id]);if(circuit?.open)throw new SourceError('source_unavailable');
   const [budget]=await repo.sql(`SELECT coalesce(sum(attempts),0)::int AS count FROM source_fetch_jobs WHERE started_at>now()-interval '24 hours'`);if(budget.count>=32)throw new SourceError('daily_source_budget_exceeded',429);
   adapter.transport.resetBudget();
   job={id:prior?.id||randomUUID(),source_id:id,start:Date.now(),query:requestShape.query};
   await repo.sql(`INSERT INTO source_fetch_jobs(id,source_id,idempotency_key,status,request_hash,request_shape) VALUES($1,$2,$3,'running',$4,$5) ON CONFLICT(id) DO UPDATE SET status='running',attempts=source_fetch_jobs.attempts+1,started_at=now(),finished_at=NULL,error_code=NULL`,[job.id,id,idempotency,requestHash,JSON.stringify(requestShape)]);
   let out;
   if(identifiers){const records=[];for(const identifier of identifiers)records.push(...(await adapter.fetchByIdentifier(identifier)).records);out={records,next_cursor:null};}
   else out=await adapter.fetchIncremental({query:query||source.sample_query,cursor,limit});
   const unique=adapter.deduplicate(out.records),counts=await adapter.stage(repo,unique,job);counts.duplicates=out.records.length-unique.length;counts.next_cursor=out.next_cursor;
   await repo.finish(job,counts,adapter.transport.metrics);
   return {job_id:job.id,status:'completed',...counts,metrics:adapter.transport.metrics,coverage:'bounded_sample; not an exhaustive clinical database'};
  }catch(e){
   if(job){try{await repo.finish(job,{quarantined:e.code==='source_schema_error'?1:0},adapter.transport.metrics,e);}catch{/* Keep the original failure; the lease is still released below. */}}
   if(e instanceof SourceError)throw e;throw new SourceError('source_unavailable');
  }finally{if(locked)await repo.sql(`SELECT pg_advisory_unlock(hashtext('dawa_medical_source_import'))`).catch(()=>{});client.release();}
 }};
}
