BEGIN;
INSERT INTO sources VALUES('test-private','original','Private fixture','https://example.org','Fixture',NULL,'restricted','fixture',false);
INSERT INTO content_items(canonical_id,category,status,source_id) VALUES('test-draft','home','draft','circulation'),('test-unlicensed','home','published','test-private');
INSERT INTO content_translations(content_id,locale,title,body) VALUES('test-draft','ar','hidden','hidden'),('test-unlicensed','ar','hidden','hidden');
INSERT INTO media_assets(id,content_id,source_id,bucket,object_key,mime_type,bytes,sha256,status) VALUES('test-draft-asset','test-draft','circulation','offline-packs','hidden/test','image/png',1,repeat('0',64),'published');
DO $$ BEGIN
 IF EXISTS(SELECT 1 FROM public_assets WHERE id='test-draft-asset') THEN RAISE EXCEPTION 'Draft asset leak'; END IF;
 IF EXISTS(SELECT 1 FROM public_content WHERE canonical_id LIKE 'test-%') THEN RAISE EXCEPTION 'Draft/license leak'; END IF;
 BEGIN
  INSERT INTO content_items(canonical_id,category,status,clinical,source_id) VALUES('test-dose','medicines','published',true,'circulation');
  RAISE EXCEPTION 'Clinical publication guard failed';
 EXCEPTION WHEN check_violation THEN NULL;
 END;
END $$;
SET LOCAL ROLE dawa_reader;
SELECT count(*) AS public_rows FROM public_content;
DO $$ BEGIN
 BEGIN
  PERFORM * FROM content_items;
  RAISE EXCEPTION 'Reader accessed private table';
 EXCEPTION WHEN insufficient_privilege THEN NULL;
 END;
 BEGIN
  INSERT INTO audit_logs(actor_id,action,target_id) VALUES('anonymous','write','test');
  RAISE EXCEPTION 'Reader wrote private table';
 EXCEPTION WHEN insufficient_privilege THEN NULL;
 END;
END $$;
ROLLBACK;
