import {randomUUID,createHash} from 'node:crypto';
import {normalizeSearch,canonicalId} from './adapters.mjs';
import {SourceError} from './transport.mjs';
export class KnowledgeRepository {
 constructor(client){this.client=client;}
 async sql(sql,values=[]){return (await this.client.query(sql,values)).rows;}
 async stage(source,records,job){
  const counts={items_seen:records.length,imported:0,updated:0,skipped:0,duplicates:0,quarantined:0,failed:0};
  await this.client.query('BEGIN');
  try{
   const [policy]=await this.sql('SELECT enabled,metadata_allowed,offline_metadata_allowed FROM source_policies WHERE source_id=$1',[source.source_id]);
   if(!policy?.enabled)throw new SourceError('source_disabled',403);
   for(const r of records){
    // SPL describes a label group. Shared RxCUIs are cross-references, never proof of product equivalence.
    const matchIds=r.kind==='product'?r.identifiers.filter(x=>x.scheme==='SPL_SET_ID'):r.identifiers;
    const matches=matchIds.length?await this.sql(`SELECT DISTINCT i.concept_id FROM concept_identifiers i JOIN jsonb_to_recordset($1::jsonb) d(scheme text,value text) ON d.scheme=i.scheme AND d.value=i.value WHERE i.entity_kind=$2`,[JSON.stringify(matchIds),r.kind]):[];
    if(matches.length>1){
     const key=createHash('sha256').update(`${r.source_id}:${r.source_native_id}:${r.raw_payload_hash}`).digest('hex');
     await this.sql(`INSERT INTO source_conflicts(id,case_key,kind,identifiers,record_refs) VALUES($1,$2,'identifier_conflict',$3,$4) ON CONFLICT(case_key) DO NOTHING`,[randomUUID(),key,JSON.stringify(matchIds),JSON.stringify(matches)]);counts.quarantined++;continue;
    }
    const concept=matches[0]?.concept_id||r.canonical_id;
    const [prior]=await this.sql('SELECT payload_hash,revision FROM source_records WHERE source_id=$1 AND source_native_id=$2',[r.source_id,r.source_native_id]);
    const unchanged=prior?.payload_hash===r.raw_payload_hash;
    const searchable=normalizeSearch([r.title,...r.identifiers.flatMap(x=>[x.scheme,x.value])].join(' '));
    await this.sql(`INSERT INTO canonical_concepts(id,kind,preferred_name,status,source_id,source_native_id,normalized_search) VALUES($1,$2,$3,$4,$5,$6,$7) ON CONFLICT(id) DO UPDATE SET preferred_name=CASE WHEN canonical_concepts.source_id=EXCLUDED.source_id AND canonical_concepts.source_native_id=EXCLUDED.source_native_id THEN EXCLUDED.preferred_name ELSE canonical_concepts.preferred_name END,updated_at=now()`,[concept,r.kind,r.title,policy.metadata_allowed?'published_metadata':'draft',r.source_id,r.source_native_id,searchable]);
    for(const i of matchIds)await this.sql(`INSERT INTO concept_identifiers(concept_id,scheme,value,entity_kind,source_id,source_native_id,verified_at) VALUES($1,$2,$3,$4,$5,$6,$7) ON CONFLICT(concept_id,scheme,value) DO UPDATE SET verified_at=EXCLUDED.verified_at`,[concept,i.scheme,i.value,r.kind,r.source_id,r.source_native_id,r.fetched_at]);
    await this.sql(`INSERT INTO concept_aliases(concept_id,locale,alias,normalized,source_id) VALUES($1,'en',$2,$3,$4) ON CONFLICT DO NOTHING`,[concept,r.title,normalizeSearch(r.title),r.source_id]);
    // Keep the original text; normalization applies only to the index.
    await this.sql(`UPDATE canonical_concepts SET normalized_search=$2 || ' ' || coalesce((SELECT string_agg(normalized,' ') FROM concept_aliases WHERE concept_id=$1),'') || ' ' || coalesce((SELECT string_agg(scheme || ' ' || value,' ') FROM concept_identifiers WHERE concept_id=$1),'') WHERE id=$1`,[concept,searchable]);
    const snapshot={...r,canonical_id:concept};
    await this.sql(`INSERT INTO source_records(source_id,source_native_id,canonical_id,payload_hash,snapshot,canonical_url,fetched_at,source_updated_at,response_etag,last_modified) VALUES($1,$2,$3,$4,$5,$6,$7,$8,$9,$10) ON CONFLICT(source_id,source_native_id) DO UPDATE SET payload_hash=EXCLUDED.payload_hash,snapshot=EXCLUDED.snapshot,canonical_id=EXCLUDED.canonical_id,canonical_url=EXCLUDED.canonical_url,fetched_at=EXCLUDED.fetched_at,source_updated_at=EXCLUDED.source_updated_at,response_etag=EXCLUDED.response_etag,last_modified=EXCLUDED.last_modified,revision=CASE WHEN source_records.payload_hash=EXCLUDED.payload_hash THEN source_records.revision ELSE source_records.revision+1 END`,[r.source_id,r.source_native_id,concept,r.raw_payload_hash,JSON.stringify(snapshot),r.source_url,r.fetched_at,r.source_updated_at,r.response_etag,r.last_modified]);
    await this.sql(`INSERT INTO source_record_versions(source_id,source_native_id,payload_hash,snapshot) VALUES($1,$2,$3,$4) ON CONFLICT DO NOTHING`,[r.source_id,r.source_native_id,r.raw_payload_hash,JSON.stringify(snapshot)]);
    await this.sql(`INSERT INTO article_candidates(id,source_id,source_native_id,payload_hash,concept_id,reason) VALUES($1,$2,$3,$4,$5,$6) ON CONFLICT(source_id,source_native_id,payload_hash) DO NOTHING`,[randomUUID(),r.source_id,r.source_native_id,r.raw_payload_hash,concept,r.metadata.sections?'source_sections_require_qualified_review':'identity_metadata_is_not_clinical_approval']);
    if(policy.metadata_allowed){
     const claim=r.kind==='research'?'bibliographic':'identity';
     await this.sql(`INSERT INTO knowledge_facts(id,concept_id,claim_type,claim_value,source_id,source_native_id,canonical_url,source_section,provenance_snapshot,payload_hash,fetched_at,source_updated_at,evidence_class,jurisdiction,license,permitted_display_mode,publish_state) VALUES($1,$2,$3,$4,$5,$6,$7,'metadata',$8,$9,$10,$11,'source_metadata',$12,$13,'metadata','published') ON CONFLICT(concept_id,claim_type,locale,source_id,source_native_id,payload_hash) DO NOTHING`,[randomUUID(),concept,claim,JSON.stringify({title:r.title,identifiers:r.identifiers,properties:r.metadata}),r.source_id,r.source_native_id,r.source_url,JSON.stringify(snapshot),r.raw_payload_hash,r.fetched_at,r.source_updated_at,r.metadata.jurisdiction||null,r.license]);
    }
    if(r.kind==='research'){
     const get=scheme=>r.identifiers.find(x=>x.scheme===scheme)?.value||null;
     await this.sql(`INSERT INTO reference_works(concept_id,doi,pmid,pmcid,bibliography,retraction_state) VALUES($1,$2,$3,$4,$5,$6) ON CONFLICT(concept_id) DO UPDATE SET doi=coalesce(reference_works.doi,EXCLUDED.doi),pmid=coalesce(reference_works.pmid,EXCLUDED.pmid),pmcid=coalesce(reference_works.pmcid,EXCLUDED.pmcid),retraction_state=CASE WHEN reference_works.retraction_state='retracted' THEN 'retracted' WHEN EXCLUDED.retraction_state='unknown' THEN reference_works.retraction_state ELSE EXCLUDED.retraction_state END,updated_at=now()`,[concept,get('DOI'),get('PMID'),get('PMCID'),JSON.stringify({title:r.title,...r.metadata,source_url:r.source_url}),r.metadata.retraction_state||'unknown']);
     for(const update of r.metadata.updates||[]){if(update.doi&&/retract|withdraw/i.test(update.type))await this.sql(`UPDATE reference_works SET retraction_state='retracted',updated_at=now() WHERE doi=$1`,[update.doi]);}
    }
    if(unchanged)counts.skipped++;else if(prior)counts.updated++;else counts.imported++;
   }
   await this.audit(source.source_id,'source_page_staged',job.id,{...counts});
   await this.client.query('COMMIT');return counts;
  }catch(e){await this.client.query('ROLLBACK');throw e;}
 }
 async quarantine(source,reason,job){await this.audit(source,'source_page_quarantined',job.id,{reason});}
 async publishCandidate(){throw new SourceError('qualified_human_review_required',403);}
 async audit(source,action,target,details={}){await this.sql('INSERT INTO audit_logs(actor_id,action,target_id,details) VALUES($1,$2,$3,$4)',[`source-service:${source}`,action,String(target),JSON.stringify(details)]);}
 async finish(job,counts,metrics,error=null){
  const code=error?.code&&/^[a-z_]+$/.test(error.code)?error.code:error?'source_unavailable':null;
  await this.sql(`UPDATE source_fetch_jobs SET status=$2,items_seen=$3,imported=$4,updated=$5,skipped=$6,duplicates=$7,quarantined=$8,failed=$9,request_count=$10,response_bytes=$11,cache_hits=$12,duration_ms=$13,error_code=$14,cursor_value=$15,finished_at=now() WHERE id=$1`,[job.id,error?'failed':'completed',counts.items_seen||0,counts.imported||0,counts.updated||0,counts.skipped||0,counts.duplicates||0,counts.quarantined||0,error?1:0,metrics.requests,metrics.bytes,metrics.cache_hits,Date.now()-job.start,code,counts.next_cursor||null]);
  await this.sql(`INSERT INTO source_connector_status(source_id,health_status,last_success_at,last_error_at,error_code,consecutive_failures,circuit_until,last_job_id) VALUES($1,$2,CASE WHEN $3::boolean THEN NULL ELSE now() END,CASE WHEN $3::boolean THEN now() ELSE NULL END,$4,CASE WHEN $3::boolean THEN 1 ELSE 0 END,NULL,$5) ON CONFLICT(source_id) DO UPDATE SET health_status=EXCLUDED.health_status,last_success_at=CASE WHEN $3::boolean THEN source_connector_status.last_success_at ELSE now() END,last_error_at=CASE WHEN $3::boolean THEN now() ELSE source_connector_status.last_error_at END,error_code=$4,consecutive_failures=CASE WHEN $3::boolean THEN source_connector_status.consecutive_failures+1 ELSE 0 END,circuit_until=CASE WHEN $3::boolean AND source_connector_status.consecutive_failures>=2 THEN now()+interval '60 seconds' ELSE NULL END,last_job_id=$5`,[job.source_id,error?'unavailable':'healthy',!!error,code,job.id]);
 }
}
