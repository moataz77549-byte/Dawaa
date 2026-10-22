import {createHash} from 'node:crypto';
import {XMLParser,XMLValidator} from 'fast-xml-parser';
import {sourceById} from './registry.mjs';
import {SourceError,SourceTransport} from './transport.mjs';
const list=x=>x==null?[]:Array.isArray(x)?x:[x];
const text=(x,max=500)=>typeof x==='string'?x.replace(/<[^>]*>/g,'').trim().slice(0,max):'';
const first=x=>text(list(x)[0]);
export const normalizeDoi=value=>{
 const s=text(value,300).replace(/^https?:\/\/(?:dx\.)?doi\.org\//i,'').replace(/^doi:\s*/i,'').toLowerCase();
 return /^10\.\d{4,9}\/[^\s<>]+$/.test(s)?s:null;
};
export function canonicalId(scheme,id,kind){
 const h=createHash('sha256').update(`${scheme}:${id}:${kind}`).digest('hex');
 return `${h.slice(0,8)}-${h.slice(8,12)}-5${h.slice(13,16)}-a${h.slice(17,20)}-${h.slice(20,32)}`;
}
export const normalizeSearch=value=>text(value,2000).normalize('NFKC').toLowerCase().replace(/[أإآٱ]/g,'ا').replace(/ى/g,'ي').replace(/ة/g,'ه').replace(/[\u064B-\u065F\u0670ـ]/g,'');
function json(envelope){try{return JSON.parse(envelope.text);}catch{throw new SourceError('source_schema_error',502);}}
function need(condition){if(!condition)throw new SourceError('source_schema_error',502);}
function native(value){const s=String(value??'');need(s.length>0&&s.length<250&&!/[<>\r\n]/.test(s));return s;}
function record(source,e,id,title,kind,identifiers=[],metadata={},updated=null,url=null){
 const nativeId=native(id),name=text(title);need(name.length>0);
 const primary=identifiers[0];
 return {source_id:source.source_id,source_native_id:nativeId,canonical_id:canonicalId(primary?.scheme||source.source_id,primary?.value||nativeId,kind),title:name,kind,identifiers,
  fetched_at:e.fetched_at,source_updated_at:updated&&Number.isFinite(Date.parse(updated))?new Date(updated).toISOString():typeof updated==='string'&&/^\d{8}$/.test(updated)?`${updated.slice(0,4)}-${updated.slice(4,6)}-${updated.slice(6,8)}T00:00:00Z`:null,raw_payload_hash:e.raw_payload_hash,source_url:url||e.source_url,response_etag:e.etag,last_modified:e.last_modified,
  license:source.license,license_url:source.license_url,attribution:source.attribution_text,notices:source.notices||[],content_class:'metadata',quality_flags:['not_clinically_reviewed'],language:'en',payload_schema_version:1,metadata,review_state:'needs_review',clinical:false,permitted_display_mode:'metadata',offline_permission:source.offline_permission};
}
const identifier=(scheme,value)=>{const v=String(value);const patterns={RxCUI:/^\d{1,12}$/,SPL_SET_ID:/^[a-f0-9-]{36}$/i,NDC:/^[0-9-]{4,20}$/,PubChemCID:/^\d{1,12}$/,PMID:/^\d{1,12}$/,PMCID:/^PMC\d+$/,InChIKey:/^[A-Z]{14}-[A-Z]{10}-[A-Z]$/};need(v.length<250&&(patterns[scheme]?patterns[scheme].test(v):scheme==='DOI'?!!normalizeDoi(v):false));return {scheme,value:v};};
export class MedicalSourceAdapter {
 constructor(id,{transport=new SourceTransport()}={}){this.source=sourceById(id);if(!this.source)throw new SourceError('unknown_source',404);this.transport=transport;}
 async checkHealth(){const r=await this.search(this.source.sample_query,{limit:1});return {source_id:this.source.source_id,ok:true,records:r.records.length,checked_at:new Date().toISOString()};}
 discoverSchema(){return {version:1,projection:'metadata',required:['source_native_id','source_url','raw_payload_hash','fetched_at','license','review_state'],excluded:['abstract','fullText','dosage_instructions','patient_recommendation']};}
 async fetchIncremental({query=this.source.sample_query,cursor,limit=5}={}){return this.search(query,{cursor,limit});}
 async fetchByIdentifier(id){
  const s=this.source,k=s.source_id,v=native(id);let e;
  if(k==='rxnorm'){need(/^\d{1,12}$/.test(v));e=await this.transport.get(s,`/REST/rxcui/${v}/properties.json`);return this.normalize(e);}
  if(k==='rxterms'||k==='rxclass')return this.search(v,{limit:1});
  if(k==='pubchem'){need(/^\d{1,12}$/.test(v));e=await this.transport.get(s,`/rest/pug/compound/cid/${v}/property/MolecularFormula,MolecularWeight,InChIKey/JSON`);return this.normalize(e);}
  if(k==='pubmed'){need(/^\d{1,12}$/.test(v));e=await this.transport.get(s,'/entrez/eutils/esummary.fcgi',{db:'pubmed',id:v,retmode:'json',tool:'DawaHayah'});return this.normalize(e);}
  if(k==='crossref'){const doi=normalizeDoi(v);need(doi);e=await this.transport.get(s,`/works/${encodeURIComponent(doi)}`);return this.normalize(e);}
  if(k==='dailymed'){need(/^[a-f0-9-]{36}$/i.test(v));e=await this.transport.get(s,'/dailymed/services/v2/spls.json',{setid:v,pagesize:1});return this.normalize(e);}
  if(k==='openfda'){need(/^[a-f0-9-]{36}$/i.test(v));e=await this.transport.get(s,'/drug/label.json',{search:`set_id:"${v}"`,limit:1});return this.normalize(e);}
  if(k==='europepmc'){need(/^(?:MED:)?\d{1,12}$/.test(v));return this.search(`EXT_ID:${v.replace(/^MED:/,'')} AND SRC:MED`,{limit:1});}
  throw new SourceError('identifier_lookup_not_supported',400);
 }
 async search(query,{cursor=null,limit=5}={}){
  const s=this.source,k=s.source_id,q=text(query,200);need(q&&Number.isInteger(limit)&&limit>0&&limit<=10);let e;
  if(k==='openfda'){
   // Quotes and FDA search syntax from the caller never become executable query operators.
   const safe=q.replace(/[^\p{L}\p{N} -]/gu,'');need(safe.trim());
   const skip=cursor==null?0:Number(cursor);need(Number.isInteger(skip)&&skip>=0&&skip<=1000);
   e=await this.transport.get(s,'/drug/label.json',{search:`openfda.generic_name:"${safe}"`,limit,skip});const r=this.normalize(e);r.next_cursor=r.records.length===limit?String(skip+limit):null;return r;
  }
  if(k==='dailymed'){const page=cursor==null?1:Number(cursor);need(Number.isInteger(page)&&page>0&&page<=100);e=await this.transport.get(s,'/dailymed/services/v2/spls.json',{drug_name:q,pagesize:limit,page});return this.normalize(e);}
  if(k==='rxnorm'){
   e=await this.transport.get(s,'/REST/rxcui.json',{name:q,search:2});const j=json(e);need(j.idGroup&&typeof j.idGroup==='object');const ids=list(j.idGroup.rxnormId);need(ids.length<=50);
   const records=[];for(const id of ids.slice(0,limit)){const found=await this.fetchByIdentifier(id);records.push(...found.records);}return {records,next_cursor:null,ambiguous:ids.length>1};
  }
  if(k==='rxterms'){need(/^\d{1,12}$/.test(q));e=await this.transport.get(s,`/REST/RxTerms/rxcui/${q}/allinfo.json`);return this.normalize(e);}
  if(k==='rxclass'){need(/^\d{1,12}$/.test(q));e=await this.transport.get(s,'/REST/rxclass/class/byRxcui.json',{rxcui:q,relaSource:'ATC'});return this.normalize(e);}
  if(k==='pubchem'){e=await this.transport.get(s,`/rest/pug/compound/name/${encodeURIComponent(q)}/property/MolecularFormula,MolecularWeight,InChIKey/JSON`);return this.normalize(e);}
  if(k==='pubmed'){
   const start=cursor==null?0:Number(cursor);need(Number.isInteger(start)&&start>=0&&start<=1000);
   const idsEnvelope=await this.transport.get(s,'/entrez/eutils/esearch.fcgi',{db:'pubmed',term:q,retmode:'json',retmax:limit,retstart:start,tool:'DawaHayah'}),j=json(idsEnvelope);need(j.esearchresult&&Array.isArray(j.esearchresult.idlist));
   const ids=j.esearchresult.idlist;need(ids.length<=limit&&ids.every(i=>/^\d+$/.test(i)));if(!ids.length)return {records:[],next_cursor:null};
   e=await this.transport.get(s,'/entrez/eutils/esummary.fcgi',{db:'pubmed',id:ids.join(','),retmode:'json',tool:'DawaHayah'});const r=this.normalize(e);r.next_cursor=start+ids.length<Number(j.esearchresult.count)?String(start+ids.length):null;return r;
  }
  if(k==='medlineplus'){const start=cursor==null?0:Number(cursor);need(Number.isInteger(start)&&start>=0&&start<=100);e=await this.transport.get(s,'/ws/query',{db:'healthTopics',term:q,retmax:limit,retstart:start,tool:'DawaHayah'});return this.normalize(e);}
  if(k==='europepmc'){need(cursor===null||(typeof cursor==='string'&&cursor.length<=1000));e=await this.transport.get(s,'/europepmc/webservices/rest/search',{query:q,format:'json',pageSize:limit,resultType:'lite',cursorMark:cursor||'*'});return this.normalize(e);}
  if(k==='crossref'){const offset=cursor==null?0:Number(cursor);need(Number.isInteger(offset)&&offset>=0&&offset<=1000);e=await this.transport.get(s,'/works',{'query.bibliographic':q,rows:limit,offset,select:'DOI,title,type,published,author,container-title,relation,update-to,license'});const r=this.normalize(e);r.next_cursor=r.records.length===limit?String(offset+limit):null;return r;}
  throw new SourceError('source_disabled',403);
 }
 normalize(e){
  const s=this.source,k=s.source_id;let rows=[],next=null;
  if(k==='medlineplus'){
   need(!/<!DOCTYPE|<!ENTITY/i.test(e.text)&&e.text.length<2*1024*1024&&XMLValidator.validate(e.text)===true);
   const x=new XMLParser({ignoreAttributes:false,processEntities:false,parseTagValue:false}).parse(e.text);need(x.nlmSearchResult&&Object.hasOwn(x.nlmSearchResult,'list'));
   const docs=list(x.nlmSearchResult.list.document);need(docs.length<=10);
   rows=docs.map(d=>{const title=list(d.content).find(c=>c['@_name']==='title');const url=text(d['@_url'],1000);need(/^https:\/\/medlineplus\.gov\//.test(url));return record(s,e,url,text(title?.['#text']), 'disease_topic',[],{official_url:url,original_language:'en',arabic_translation_state:'not_reviewed'},null,url);});
   return {records:rows,next_cursor:null};
  }
  const j=json(e);
  if(k==='openfda'){
   need(Array.isArray(j.results));need(j.results.length<=10);
   rows=j.results.map(x=>{need(x.openfda&&x.set_id);const f=x.openfda;
    const ids=[identifier('SPL_SET_ID',x.set_id),...list(f.product_ndc).map(v=>identifier('NDC',v)),...list(f.rxcui).map(v=>identifier('RxCUI',v))];
    // Presence and hashes support later human review without copying unverified label text.
    const sections=Object.fromEntries(['active_ingredient','indications_and_usage','contraindications','dosage_and_administration','warnings','adverse_reactions','boxed_warning'].filter(a=>x[a]).map(a=>[a,{present:true,sha256:createHash('sha256').update(JSON.stringify(x[a])).digest('hex'),review_state:'needs_review',display_mode:'source_link_only'}]));
    return record(s,e,x.set_id,first(f.generic_name)||`FDA SPL record ${x.set_id}`,'product',ids,{brand_names:list(f.brand_name).map(v=>text(v)),manufacturer:list(f.manufacturer_name).slice(0,30).map(v=>text(v)),spl_version:x.version||null,label_comparison_state:'metadata_only; clinical text not compared',jurisdiction:'US',market_availability:'not_verified',sections},x.effective_time||null,`https://dailymed.nlm.nih.gov/dailymed/drugInfo.cfm?setid=${encodeURIComponent(x.set_id)}`);
   });
  }else if(k==='dailymed'){
   need(Array.isArray(j.data));need(j.data.length<=10);rows=j.data.map(x=>record(s,e,x.setid,x.title,'product',[identifier('SPL_SET_ID',x.setid)],{spl_version:x.spl_version,jurisdiction:'US',market_availability:'not_verified'},x.published_date||null,`https://dailymed.nlm.nih.gov/dailymed/drugInfo.cfm?setid=${encodeURIComponent(x.setid)}`));
   const m=j.metadata;next=m&&Number(m.current_page)<Number(m.total_pages)?String(Number(m.current_page)+1):null;
  }else if(k==='rxnorm'){
   if(!j.properties){need(Object.keys(j).length===0);return {records:[],next_cursor:null};}const x=j.properties;need(/^\d+$/.test(x.rxcui)&&x.name&&x.tty);
   const kind=x.tty==='IN'?'ingredient':x.tty==='PIN'?'precise_ingredient':'clinical_drug';
   rows=[record(s,e,x.rxcui,x.name,kind,[identifier('RxCUI',x.rxcui)],{tty:x.tty,synonym:text(x.synonym),identity_verified:true},null,`https://rxnav.nlm.nih.gov/REST/rxcui/${x.rxcui}/properties.json`)];
  }else if(k==='rxterms'){
   if(!j.rxtermsProperties){need(Object.keys(j).length===0);return {records:[],next_cursor:null};}const x=j.rxtermsProperties;need(/^\d+$/.test(x.rxcui));
   rows=[record(s,e,x.rxcui,x.fullName,'clinical_drug',[identifier('RxCUI',x.rxcui)],{tty:x.termType,display_name:text(x.displayName),synonym:text(x.synonym),identity_verified:true,route:text(x.route),form:text(x.rxtermsDoseForm),strength_text:text(x.strength),strength_is_product_identity_not_dosing:true})];
  }else if(k==='rxclass'){
   need(j.rxclassDrugInfoList&&Array.isArray(j.rxclassDrugInfoList.rxclassDrugInfo));
   const ids=[...new Set(j.rxclassDrugInfoList.rxclassDrugInfo.map(x=>x.minConcept?.rxcui).filter(Boolean))];
   rows=ids.map(id=>record(s,e,`${id}:rxclass`, `RxClass source reference for RxCUI ${id}`,'source_reference',[],{rxcui:String(id),classification_omitted:true,reason:'Underlying vocabulary redistribution not verified'}));
  }else if(k==='pubchem'){
   need(j.PropertyTable&&Array.isArray(j.PropertyTable.Properties));need(j.PropertyTable.Properties.length<=10);
   rows=j.PropertyTable.Properties.map(x=>{need(Number.isSafeInteger(x.CID)&&x.CID>0&&typeof x.MolecularFormula==='string'&&Number.isFinite(Number(x.MolecularWeight))&&Number(x.MolecularWeight)>0&&/^[A-Z]{14}-[A-Z]{10}-[A-Z]$/.test(x.InChIKey));return record(s,e,x.CID,`PubChem CID ${x.CID}`,'chemical_compound',[identifier('PubChemCID',x.CID),identifier('InChIKey',x.InChIKey)],{formula:x.MolecularFormula,molecular_weight:String(x.MolecularWeight),inchikey:x.InChIKey,identity_verified:true},null,`https://pubchem.ncbi.nlm.nih.gov/compound/${x.CID}`);});
  }else if(k==='pubmed'){
   need(j.result&&Array.isArray(j.result.uids));need(j.result.uids.length<=10);
   rows=j.result.uids.map(id=>{const x=j.result[id];need(x&&x.title&&/^\d+$/.test(id));const doi=normalizeDoi(list(x.articleids).find(v=>v.idtype==='doi')?.value),types=list(x.pubtype);const retracted=types.some(v=>/^retracted publication$/i.test(v));const notice=types.some(v=>/^retraction of publication$/i.test(v));
    return record(s,e,id,x.title,'research',[identifier('PMID',id),...(doi?[identifier('DOI',doi)]:[])],{journal:text(x.fulljournalname),authors:list(x.authors).slice(0,30).map(a=>text(a.name)),publication_types:types,publication_date:text(x.pubdate),retraction_state:retracted?'retracted':notice?'notice':'unknown',abstract_omitted:true},null,`https://pubmed.ncbi.nlm.nih.gov/${id}/`);
   });
  }else if(k==='europepmc'){
   need(j.resultList&&Array.isArray(j.resultList.result));need(j.resultList.result.length<=10);
   rows=j.resultList.result.map(x=>{need(x.id&&x.source&&x.title);const ids=[];if(x.source==='MED')ids.push(identifier('PMID',x.id));if(x.pmcid)ids.push(identifier('PMCID',x.pmcid));const doi=normalizeDoi(x.doi);if(doi)ids.push(identifier('DOI',doi));
    return record(s,e,`${x.source}:${x.id}`,x.title,'research',ids,{journal:text(x.journalTitle),publication_date:text(x.firstPublicationDate),author_string:text(x.authorString),retraction_state:/retracted publication/i.test(x.pubType||'')?'retracted':/retraction/i.test(x.pubType||'')?'notice':'unknown',open_access:x.isOpenAccess==='Y',full_text_license_verified:false,abstract_omitted:true},x.firstPublicationDate||null,`https://europepmc.org/article/${encodeURIComponent(x.source)}/${encodeURIComponent(x.id)}`);
   });next=j.nextCursorMark&&rows.length?j.nextCursorMark:null;
  }else if(k==='crossref'){
   need(j.message&&typeof j.message==='object');const items=Array.isArray(j.message.items)?j.message.items:[j.message];need(items.length<=10);
   rows=items.map(x=>{const doi=normalizeDoi(x.DOI);need(doi&&first(x.title));const updates=list(x['update-to']).map(a=>({doi:normalizeDoi(a.DOI),type:text(a.type)}));const flagged=updates.some(a=>/retract|withdraw/i.test(a.type));
    return record(s,e,doi,first(x.title),'research',[identifier('DOI',doi)],{journal:first(x['container-title']),authors:list(x.author).slice(0,30).map(a=>text(`${a.given||''} ${a.family||''}`)),publication_date:x.published?.['date-parts']||null,publication_type:text(x.type),updates,retraction_state:flagged?'notice':'unknown',abstract_omitted:true,full_text_license_verified:false},null,`https://doi.org/${doi}`);
   });
  }
  return {records:rows,next_cursor:next};
 }
 validate(r){need(r.source_id===this.source.source_id&&r.source_native_id&&/^[a-f0-9]{64}$/.test(r.raw_payload_hash)&&r.fetched_at&&r.source_url?.startsWith('https://')&&r.content_class==='metadata');return true;}
 deduplicate(records){const seen=new Set();return records.filter(r=>{this.validate(r);const k=`${r.source_id}:${r.source_native_id}`;if(seen.has(k))return false;seen.add(k);return true;});}
 // Persistence/review operations use the same repository instead of per-provider SQL engines.
 async stage(repository,records,job){return repository.stage(this.source,this.deduplicate(records),job);}
 async quarantine(repository,reason,job){return repository.quarantine(this.source.source_id,reason,job);}
 async publishCandidate(repository,id){return repository.publishCandidate(id);}
 async audit(repository,action,target){return repository.audit(this.source.source_id,action,target);}
 async retry(operation){return operation();} // Transport owns the single bounded retry policy.
}
export const createAdapters=options=>new Map(['openfda','dailymed','rxnorm','rxterms','rxclass','pubchem','pubmed','medlineplus','europepmc','crossref'].map(id=>[id,new MedicalSourceAdapter(id,options)]));
