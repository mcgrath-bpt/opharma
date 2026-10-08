USE SCHEMA PHARMA_LAB.PHARMA_MODEL;

EXECUTE IMMEDIATE $$ DECLARE bad EXCEPTION (-20010, 'Schema belongs to another release or registry'); n NUMBER; BEGIN SELECT COUNT(*) INTO :n FROM (SELECT * FROM ODCS_MODEL_IDENTITY WHERE release_id<>'pharma-lab-0.2.0' OR registry_sha256<>'27073c77045040ad84e10495e2a2a19995bfd7b94d1c9fdb0ca8b05ca8bf2cbe'); IF (n<>0) THEN RAISE bad; END IF; END; $$;

EXECUTE IMMEDIATE $$ DECLARE bad EXCEPTION (-20010, 'Checkpoint fingerprint differs'); n NUMBER; BEGIN SELECT COUNT(*) INTO :n FROM (SELECT * FROM ODCS_SNAPSHOT_AUDIT WHERE snapshot_id='b001' AND (manifest_sha256<>'63d6b60b4b6b13fea4cc3464baba711481f780a23806d0966cb32eced186df31' OR registry_sha256<>'27073c77045040ad84e10495e2a2a19995bfd7b94d1c9fdb0ca8b05ca8bf2cbe')); IF (n<>0) THEN RAISE bad; END IF; END; $$;

EXECUTE IMMEDIATE $$ DECLARE bad EXCEPTION (-20010, 'Missing predecessor checkpoint'); n NUMBER; BEGIN SELECT COUNT(*) INTO :n FROM (SELECT * FROM ODCS_SNAPSHOT_AUDIT WHERE snapshot_id<'b001' AND status='PUBLISHED'); IF (n<>0) THEN RAISE bad; END IF; END; $$;

-- Harness skips publication for an already identical checkpoint. Single writer required.

BEGIN TRANSACTION;

INSERT INTO ODCS_MODEL_IDENTITY SELECT 'pharma-lab-0.2.0','27073c77045040ad84e10495e2a2a19995bfd7b94d1c9fdb0ca8b05ca8bf2cbe' WHERE NOT EXISTS (SELECT 1 FROM ODCS_MODEL_IDENTITY);

INSERT INTO "canonical_organisation" SELECT DISTINCT 'b001',s.organisation_key,s.organisation_name,s.country FROM SRC_IQVIA_LIKE_ORGANISATION s WHERE s._available_at<=TO_TIMESTAMP_NTZ($AS_OF);

INSERT INTO "canonical_affiliation" SELECT DISTINCT 'b001',s.affiliation_key,s.provider_key,s.organisation_key,s.relationship_type,TO_BOOLEAN(s.is_primary),TO_DATE(s.effective_from),TO_DATE(s.effective_to) FROM SRC_IQVIA_LIKE_AFFILIATION s WHERE s._available_at<=TO_TIMESTAMP_NTZ($AS_OF);

INSERT INTO "canonical_representative" SELECT DISTINCT 'b001',s.staff_key,s.staff_name FROM SRC_VEEVA_LIKE_STAFF s WHERE s._available_at<=TO_TIMESTAMP_NTZ($AS_OF);

INSERT INTO "canonical_customer" SELECT DISTINCT 'b001',s.provider_key,s.label,s.speciality,s.country,s.postal_sector,TO_BOOLEAN(s.active) FROM SRC_IQVIA_LIKE_PROVIDER s WHERE s._available_at<=TO_TIMESTAMP_NTZ($AS_OF);

INSERT INTO "canonical_product_interval" SELECT DISTINCT 'b001',s.product_code,TO_DATE(s.valid_from),TO_DATE(s.valid_to),s.brand,s.therapy,TO_BOOLEAN(s.active) FROM SRC_IQVIA_LIKE_PRODUCT s WHERE s._available_at<=TO_TIMESTAMP_NTZ($AS_OF);

INSERT INTO "canonical_territory" SELECT DISTINCT 'b001',s.territory_code,s.territory_name FROM SRC_VEEVA_LIKE_TERRITORY s WHERE s._available_at<=TO_TIMESTAMP_NTZ($AS_OF);

INSERT INTO "canonical_interaction_version" SELECT DISTINCT 'b001',s.activity_key,TO_NUMBER(s.source_version),s.customer_key,m.provider_key,s.staff_key,s.primary_product_code,TO_TIMESTAMP_NTZ(s.occurred_at),s.channel,s.approval,TO_NUMBER(s.duration_minutes),TO_TIMESTAMP_NTZ(s.modified_at),s.operation,s._batch_id FROM ACTIVITY_CLASSIFIED s LEFT JOIN CRM_MAP m ON s.customer_key=m.customer_key WHERE s._available_at<=TO_TIMESTAMP_NTZ($AS_OF) AND s.disposition='ACCEPT' QUALIFY ROW_NUMBER() OVER(PARTITION BY s.activity_key,s.source_version ORDER BY s._available_at)=1;

INSERT INTO "canonical_interaction_product" SELECT DISTINCT 'b001',s.activity_key,TO_NUMBER(s.source_version),s.product_code FROM DETAIL s JOIN (SELECT DISTINCT activity_key,source_version FROM ACTIVITY_CLASSIFIED WHERE disposition='ACCEPT') a ON s.activity_key=a.activity_key AND s.source_version=TRY_TO_NUMBER(a.source_version);

INSERT INTO "canonical_consent_event" SELECT DISTINCT 'b001',s.preference_key,m.provider_key,s.contact_key,s.channel,s.purpose,s.status,TO_TIMESTAMP_NTZ(s.effective_at),TO_NUMBER(s.sequence_no),s._batch_id FROM SRC_SALESFORCE_LIKE_CONSENT s LEFT JOIN SF_MAP m ON s.contact_key=m.contact_key WHERE s._available_at<=TO_TIMESTAMP_NTZ($AS_OF) QUALIFY ROW_NUMBER() OVER(PARTITION BY s.preference_key ORDER BY s._available_at)=1;

INSERT INTO "canonical_customer_territory" SELECT DISTINCT 'b001',s.assignment_key,s.provider_key,s.territory_code,TO_DATE(s.effective_from),TO_DATE(s.effective_to) FROM SRC_MANUAL_TERRITORY_MAPPING s WHERE s._available_at<=TO_TIMESTAMP_NTZ($AS_OF);

INSERT INTO "canonical_campaign" SELECT DISTINCT 'b001',s.campaign_key,s.product_code,TO_DATE(s.start_date),TO_DATE(s.end_date_exclusive),s.status FROM SRC_SALESFORCE_LIKE_CAMPAIGN s WHERE s._available_at<=TO_TIMESTAMP_NTZ($AS_OF);

INSERT INTO "canonical_campaign_member" SELECT DISTINCT 'b001',s.membership_key,s.campaign_key,m.provider_key,s.contact_key,s.member_status FROM SRC_SALESFORCE_LIKE_CAMPAIGN_MEMBER s LEFT JOIN SF_MAP m ON s.contact_key=m.contact_key WHERE s._available_at<=TO_TIMESTAMP_NTZ($AS_OF);

INSERT INTO "canonical_rx_version" SELECT DISTINCT 'b001',s.observation_key,TO_NUMBER(s.version_no),s.provider_key,s.product_code,TO_DATE(s.week_ending),TO_NUMBER(s.trx_count),TO_NUMBER(s.nrx_count),TO_NUMBER(s.sales_units) FROM SRC_IQVIA_LIKE_RX_WEEKLY s WHERE s._available_at<=TO_TIMESTAMP_NTZ($AS_OF);

INSERT INTO "pipeline_s01_engagement" SELECT 'b001',TO_TIMESTAMP_NTZ($AS_OF),activity_key,customer_key,activity_date,consent_status FROM GOLD_S01_ENGAGEMENT;

INSERT INTO "pipeline_s02_product_activity" SELECT 'b001',TO_TIMESTAMP_NTZ($AS_OF),customer_key,product_code,activity_date,brand,therapy,interaction_count FROM GOLD_S02_PRODUCT_ACTIVITY;

INSERT INTO "pipeline_s03_customer_territory" SELECT 'b001',TO_TIMESTAMP_NTZ($AS_OF),customer_key,territory_code,assignment_status FROM GOLD_S03_CUSTOMER_TERRITORY;

INSERT INTO "pipeline_s04_interaction" SELECT 'b001',TO_TIMESTAMP_NTZ($AS_OF),activity_key,customer_key,primary_product_code,occurred_at,channel,duration_minutes,source_version FROM GOLD_S04_INTERACTION;

INSERT INTO "pipeline_s05_campaign" SELECT 'b001',TO_TIMESTAMP_NTZ($AS_OF),campaign_key,customer_key,product_code,TO_BOOLEAN(contacted),qualifying_interactions FROM GOLD_S05_CAMPAIGN;

INSERT INTO "pipeline_exceptions" SELECT 'b001',TO_TIMESTAMP_NTZ($AS_OF),scenario,record_key,reason FROM GOLD_EXCEPTIONS;

INSERT INTO "pipeline_dq" SELECT 'b001',TO_TIMESTAMP_NTZ($AS_OF),scenario,scope,numerator,denominator,threshold,status FROM GOLD_DQ;

INSERT INTO "consumption_s01_engagement" SELECT 'b001',TO_TIMESTAMP_NTZ($AS_OF),activity_key,customer_key,activity_date,consent_status FROM GOLD_S01_ENGAGEMENT;

INSERT INTO "consumption_s02_product_activity" SELECT 'b001',TO_TIMESTAMP_NTZ($AS_OF),customer_key,product_code,activity_date,brand,therapy,interaction_count FROM GOLD_S02_PRODUCT_ACTIVITY;

INSERT INTO "consumption_s03_customer_territory" SELECT 'b001',TO_TIMESTAMP_NTZ($AS_OF),customer_key,territory_code,assignment_status FROM GOLD_S03_CUSTOMER_TERRITORY;

INSERT INTO "consumption_s04_interaction" SELECT 'b001',TO_TIMESTAMP_NTZ($AS_OF),activity_key,customer_key,primary_product_code,occurred_at,channel,duration_minutes,source_version FROM GOLD_S04_INTERACTION;

INSERT INTO "consumption_exceptions" SELECT 'b001',TO_TIMESTAMP_NTZ($AS_OF),scenario,record_key,reason FROM GOLD_EXCEPTIONS;

INSERT INTO "consumption_dq" SELECT 'b001',TO_TIMESTAMP_NTZ($AS_OF),scenario,scope,numerator,denominator,threshold,status FROM GOLD_DQ;

INSERT INTO "visualization_scenario_scorecard" SELECT 'b001',TO_TIMESTAMP_NTZ($AS_OF),d.scenario,d.scope,CASE d.scenario WHEN 'S01' THEN (SELECT COUNT(*) FROM "pipeline_s01_engagement" WHERE "snapshot_id"='b001') WHEN 'S02' THEN (SELECT COUNT(*) FROM "pipeline_s02_product_activity" WHERE "snapshot_id"='b001') WHEN 'S03' THEN (SELECT COUNT(*) FROM "pipeline_s03_customer_territory" WHERE "snapshot_id"='b001') WHEN 'S04' THEN (SELECT COUNT(*) FROM "pipeline_s04_interaction" WHERE "snapshot_id"='b001') WHEN 'S05' THEN (SELECT COUNT(*) FROM "pipeline_s05_campaign" WHERE "snapshot_id"='b001' AND "campaign_key"=d.scope) END,(SELECT COUNT(*) FROM "pipeline_exceptions" e WHERE e."snapshot_id"='b001' AND e."scenario"=d.scenario AND (d.scenario<>'S05' OR SPLIT_PART(e."record_key",'|',1)=d.scope)),d.numerator,d.denominator,d.threshold,d.status,IFF(d.scenario='S05',DAYOFWEEKISO(TO_TIMESTAMP_NTZ($AS_OF))=1,TRUE) FROM (SELECT scenario,scope,numerator,denominator,threshold,status FROM GOLD_DQ UNION ALL SELECT 'S03','ALL',0,0,0,'DIAGNOSTIC' UNION ALL SELECT 'S04','ALL',0,0,0,'DIAGNOSTIC') d;

EXECUTE IMMEDIATE $$ DECLARE bad EXCEPTION (-20011, 'organisation/uniqueGrain'); n NUMBER; BEGIN SELECT COUNT(*) INTO :n FROM (SELECT "snapshot_id","organisation_key" FROM "canonical_organisation" WHERE "snapshot_id"='b001' GROUP BY "snapshot_id","organisation_key" HAVING COUNT(*)>1); IF (n<>0) THEN RAISE bad; END IF; END; $$;

EXECUTE IMMEDIATE $$ DECLARE bad EXCEPTION (-20011, 'affiliation/uniqueGrain'); n NUMBER; BEGIN SELECT COUNT(*) INTO :n FROM (SELECT "snapshot_id","affiliation_key" FROM "canonical_affiliation" WHERE "snapshot_id"='b001' GROUP BY "snapshot_id","affiliation_key" HAVING COUNT(*)>1); IF (n<>0) THEN RAISE bad; END IF; END; $$;

EXECUTE IMMEDIATE $$ DECLARE bad EXCEPTION (-20011, 'affiliation/foreignKey1'); n NUMBER; BEGIN SELECT COUNT(*) INTO :n FROM "canonical_affiliation" c LEFT JOIN "canonical_customer" p ON c."snapshot_id"=p."snapshot_id" AND c."customer_key"=p."customer_key" WHERE c."snapshot_id"='b001' AND c."snapshot_id" IS NOT NULL AND c."customer_key" IS NOT NULL AND p."snapshot_id" IS NULL; IF (n<>0) THEN RAISE bad; END IF; END; $$;

EXECUTE IMMEDIATE $$ DECLARE bad EXCEPTION (-20011, 'affiliation/foreignKey2'); n NUMBER; BEGIN SELECT COUNT(*) INTO :n FROM "canonical_affiliation" c LEFT JOIN "canonical_organisation" p ON c."snapshot_id"=p."snapshot_id" AND c."organisation_key"=p."organisation_key" WHERE c."snapshot_id"='b001' AND c."snapshot_id" IS NOT NULL AND c."organisation_key" IS NOT NULL AND p."snapshot_id" IS NULL; IF (n<>0) THEN RAISE bad; END IF; END; $$;

EXECUTE IMMEDIATE $$ DECLARE bad EXCEPTION (-20011, 'representative/uniqueGrain'); n NUMBER; BEGIN SELECT COUNT(*) INTO :n FROM (SELECT "snapshot_id","staff_key" FROM "canonical_representative" WHERE "snapshot_id"='b001' GROUP BY "snapshot_id","staff_key" HAVING COUNT(*)>1); IF (n<>0) THEN RAISE bad; END IF; END; $$;

EXECUTE IMMEDIATE $$ DECLARE bad EXCEPTION (-20011, 'customer/uniqueGrain'); n NUMBER; BEGIN SELECT COUNT(*) INTO :n FROM (SELECT "snapshot_id","customer_key" FROM "canonical_customer" WHERE "snapshot_id"='b001' GROUP BY "snapshot_id","customer_key" HAVING COUNT(*)>1); IF (n<>0) THEN RAISE bad; END IF; END; $$;

EXECUTE IMMEDIATE $$ DECLARE bad EXCEPTION (-20011, 'product_interval/uniqueGrain'); n NUMBER; BEGIN SELECT COUNT(*) INTO :n FROM (SELECT "snapshot_id","product_code","valid_from" FROM "canonical_product_interval" WHERE "snapshot_id"='b001' GROUP BY "snapshot_id","product_code","valid_from" HAVING COUNT(*)>1); IF (n<>0) THEN RAISE bad; END IF; END; $$;

EXECUTE IMMEDIATE $$ DECLARE bad EXCEPTION (-20011, 'territory/uniqueGrain'); n NUMBER; BEGIN SELECT COUNT(*) INTO :n FROM (SELECT "snapshot_id","territory_code" FROM "canonical_territory" WHERE "snapshot_id"='b001' GROUP BY "snapshot_id","territory_code" HAVING COUNT(*)>1); IF (n<>0) THEN RAISE bad; END IF; END; $$;

EXECUTE IMMEDIATE $$ DECLARE bad EXCEPTION (-20011, 'interaction_version/uniqueGrain'); n NUMBER; BEGIN SELECT COUNT(*) INTO :n FROM (SELECT "snapshot_id","activity_key","source_version" FROM "canonical_interaction_version" WHERE "snapshot_id"='b001' GROUP BY "snapshot_id","activity_key","source_version" HAVING COUNT(*)>1); IF (n<>0) THEN RAISE bad; END IF; END; $$;

EXECUTE IMMEDIATE $$ DECLARE bad EXCEPTION (-20011, 'interaction_version/foreignKey1'); n NUMBER; BEGIN SELECT COUNT(*) INTO :n FROM "canonical_interaction_version" c LEFT JOIN "canonical_customer" p ON c."snapshot_id"=p."snapshot_id" AND c."customer_key"=p."customer_key" WHERE c."snapshot_id"='b001' AND c."snapshot_id" IS NOT NULL AND c."customer_key" IS NOT NULL AND p."snapshot_id" IS NULL; IF (n<>0) THEN RAISE bad; END IF; END; $$;

EXECUTE IMMEDIATE $$ DECLARE bad EXCEPTION (-20011, 'interaction_version/foreignKey2'); n NUMBER; BEGIN SELECT COUNT(*) INTO :n FROM "canonical_interaction_version" c LEFT JOIN "canonical_representative" p ON c."snapshot_id"=p."snapshot_id" AND c."staff_key"=p."staff_key" WHERE c."snapshot_id"='b001' AND c."snapshot_id" IS NOT NULL AND c."staff_key" IS NOT NULL AND p."snapshot_id" IS NULL; IF (n<>0) THEN RAISE bad; END IF; END; $$;

EXECUTE IMMEDIATE $$ DECLARE bad EXCEPTION (-20011, 'interaction_product/uniqueGrain'); n NUMBER; BEGIN SELECT COUNT(*) INTO :n FROM (SELECT "snapshot_id","activity_key","source_version","product_code" FROM "canonical_interaction_product" WHERE "snapshot_id"='b001' GROUP BY "snapshot_id","activity_key","source_version","product_code" HAVING COUNT(*)>1); IF (n<>0) THEN RAISE bad; END IF; END; $$;

EXECUTE IMMEDIATE $$ DECLARE bad EXCEPTION (-20011, 'interaction_product/foreignKey1'); n NUMBER; BEGIN SELECT COUNT(*) INTO :n FROM "canonical_interaction_product" c LEFT JOIN "canonical_interaction_version" p ON c."snapshot_id"=p."snapshot_id" AND c."activity_key"=p."activity_key" AND c."source_version"=p."source_version" WHERE c."snapshot_id"='b001' AND c."snapshot_id" IS NOT NULL AND c."activity_key" IS NOT NULL AND c."source_version" IS NOT NULL AND p."snapshot_id" IS NULL; IF (n<>0) THEN RAISE bad; END IF; END; $$;

EXECUTE IMMEDIATE $$ DECLARE bad EXCEPTION (-20011, 'consent_event/uniqueGrain'); n NUMBER; BEGIN SELECT COUNT(*) INTO :n FROM (SELECT "snapshot_id","preference_key" FROM "canonical_consent_event" WHERE "snapshot_id"='b001' GROUP BY "snapshot_id","preference_key" HAVING COUNT(*)>1); IF (n<>0) THEN RAISE bad; END IF; END; $$;

EXECUTE IMMEDIATE $$ DECLARE bad EXCEPTION (-20011, 'consent_event/foreignKey1'); n NUMBER; BEGIN SELECT COUNT(*) INTO :n FROM "canonical_consent_event" c LEFT JOIN "canonical_customer" p ON c."snapshot_id"=p."snapshot_id" AND c."customer_key"=p."customer_key" WHERE c."snapshot_id"='b001' AND c."snapshot_id" IS NOT NULL AND c."customer_key" IS NOT NULL AND p."snapshot_id" IS NULL; IF (n<>0) THEN RAISE bad; END IF; END; $$;

EXECUTE IMMEDIATE $$ DECLARE bad EXCEPTION (-20011, 'customer_territory/uniqueGrain'); n NUMBER; BEGIN SELECT COUNT(*) INTO :n FROM (SELECT "snapshot_id","assignment_key" FROM "canonical_customer_territory" WHERE "snapshot_id"='b001' GROUP BY "snapshot_id","assignment_key" HAVING COUNT(*)>1); IF (n<>0) THEN RAISE bad; END IF; END; $$;

EXECUTE IMMEDIATE $$ DECLARE bad EXCEPTION (-20011, 'customer_territory/foreignKey1'); n NUMBER; BEGIN SELECT COUNT(*) INTO :n FROM "canonical_customer_territory" c LEFT JOIN "canonical_customer" p ON c."snapshot_id"=p."snapshot_id" AND c."customer_key"=p."customer_key" WHERE c."snapshot_id"='b001' AND c."snapshot_id" IS NOT NULL AND c."customer_key" IS NOT NULL AND p."snapshot_id" IS NULL; IF (n<>0) THEN RAISE bad; END IF; END; $$;

EXECUTE IMMEDIATE $$ DECLARE bad EXCEPTION (-20011, 'customer_territory/foreignKey2'); n NUMBER; BEGIN SELECT COUNT(*) INTO :n FROM "canonical_customer_territory" c LEFT JOIN "canonical_territory" p ON c."snapshot_id"=p."snapshot_id" AND c."territory_code"=p."territory_code" WHERE c."snapshot_id"='b001' AND c."snapshot_id" IS NOT NULL AND c."territory_code" IS NOT NULL AND p."snapshot_id" IS NULL; IF (n<>0) THEN RAISE bad; END IF; END; $$;

EXECUTE IMMEDIATE $$ DECLARE bad EXCEPTION (-20011, 'campaign/uniqueGrain'); n NUMBER; BEGIN SELECT COUNT(*) INTO :n FROM (SELECT "snapshot_id","campaign_key" FROM "canonical_campaign" WHERE "snapshot_id"='b001' GROUP BY "snapshot_id","campaign_key" HAVING COUNT(*)>1); IF (n<>0) THEN RAISE bad; END IF; END; $$;

EXECUTE IMMEDIATE $$ DECLARE bad EXCEPTION (-20011, 'campaign_member/uniqueGrain'); n NUMBER; BEGIN SELECT COUNT(*) INTO :n FROM (SELECT "snapshot_id","membership_key" FROM "canonical_campaign_member" WHERE "snapshot_id"='b001' GROUP BY "snapshot_id","membership_key" HAVING COUNT(*)>1); IF (n<>0) THEN RAISE bad; END IF; END; $$;

EXECUTE IMMEDIATE $$ DECLARE bad EXCEPTION (-20011, 'campaign_member/foreignKey1'); n NUMBER; BEGIN SELECT COUNT(*) INTO :n FROM "canonical_campaign_member" c LEFT JOIN "canonical_campaign" p ON c."snapshot_id"=p."snapshot_id" AND c."campaign_key"=p."campaign_key" WHERE c."snapshot_id"='b001' AND c."snapshot_id" IS NOT NULL AND c."campaign_key" IS NOT NULL AND p."snapshot_id" IS NULL; IF (n<>0) THEN RAISE bad; END IF; END; $$;

EXECUTE IMMEDIATE $$ DECLARE bad EXCEPTION (-20011, 'campaign_member/foreignKey2'); n NUMBER; BEGIN SELECT COUNT(*) INTO :n FROM "canonical_campaign_member" c LEFT JOIN "canonical_customer" p ON c."snapshot_id"=p."snapshot_id" AND c."customer_key"=p."customer_key" WHERE c."snapshot_id"='b001' AND c."snapshot_id" IS NOT NULL AND c."customer_key" IS NOT NULL AND p."snapshot_id" IS NULL; IF (n<>0) THEN RAISE bad; END IF; END; $$;

EXECUTE IMMEDIATE $$ DECLARE bad EXCEPTION (-20011, 'rx_version/uniqueGrain'); n NUMBER; BEGIN SELECT COUNT(*) INTO :n FROM (SELECT "snapshot_id","observation_key","version_no" FROM "canonical_rx_version" WHERE "snapshot_id"='b001' GROUP BY "snapshot_id","observation_key","version_no" HAVING COUNT(*)>1); IF (n<>0) THEN RAISE bad; END IF; END; $$;

EXECUTE IMMEDIATE $$ DECLARE bad EXCEPTION (-20011, 'rx_version/foreignKey1'); n NUMBER; BEGIN SELECT COUNT(*) INTO :n FROM "canonical_rx_version" c LEFT JOIN "canonical_customer" p ON c."snapshot_id"=p."snapshot_id" AND c."customer_key"=p."customer_key" WHERE c."snapshot_id"='b001' AND c."snapshot_id" IS NOT NULL AND c."customer_key" IS NOT NULL AND p."snapshot_id" IS NULL; IF (n<>0) THEN RAISE bad; END IF; END; $$;

EXECUTE IMMEDIATE $$ DECLARE bad EXCEPTION (-20011, 's01_engagement/uniqueGrain'); n NUMBER; BEGIN SELECT COUNT(*) INTO :n FROM (SELECT "snapshot_id","activity_key" FROM "pipeline_s01_engagement" WHERE "snapshot_id"='b001' GROUP BY "snapshot_id","activity_key" HAVING COUNT(*)>1); IF (n<>0) THEN RAISE bad; END IF; END; $$;

EXECUTE IMMEDIATE $$ DECLARE bad EXCEPTION (-20011, 's02_product_activity/uniqueGrain'); n NUMBER; BEGIN SELECT COUNT(*) INTO :n FROM (SELECT "snapshot_id","customer_key","product_code","activity_date" FROM "pipeline_s02_product_activity" WHERE "snapshot_id"='b001' GROUP BY "snapshot_id","customer_key","product_code","activity_date" HAVING COUNT(*)>1); IF (n<>0) THEN RAISE bad; END IF; END; $$;

EXECUTE IMMEDIATE $$ DECLARE bad EXCEPTION (-20011, 's03_customer_territory/uniqueGrain'); n NUMBER; BEGIN SELECT COUNT(*) INTO :n FROM (SELECT "snapshot_id","customer_key" FROM "pipeline_s03_customer_territory" WHERE "snapshot_id"='b001' GROUP BY "snapshot_id","customer_key" HAVING COUNT(*)>1); IF (n<>0) THEN RAISE bad; END IF; END; $$;

EXECUTE IMMEDIATE $$ DECLARE bad EXCEPTION (-20011, 's04_interaction/uniqueGrain'); n NUMBER; BEGIN SELECT COUNT(*) INTO :n FROM (SELECT "snapshot_id","activity_key" FROM "pipeline_s04_interaction" WHERE "snapshot_id"='b001' GROUP BY "snapshot_id","activity_key" HAVING COUNT(*)>1); IF (n<>0) THEN RAISE bad; END IF; END; $$;

EXECUTE IMMEDIATE $$ DECLARE bad EXCEPTION (-20011, 's05_campaign/uniqueGrain'); n NUMBER; BEGIN SELECT COUNT(*) INTO :n FROM (SELECT "snapshot_id","campaign_key","customer_key" FROM "pipeline_s05_campaign" WHERE "snapshot_id"='b001' GROUP BY "snapshot_id","campaign_key","customer_key" HAVING COUNT(*)>1); IF (n<>0) THEN RAISE bad; END IF; END; $$;

EXECUTE IMMEDIATE $$ DECLARE bad EXCEPTION (-20011, 'exceptions/uniqueGrain'); n NUMBER; BEGIN SELECT COUNT(*) INTO :n FROM (SELECT "snapshot_id","scenario","record_key","reason" FROM "pipeline_exceptions" WHERE "snapshot_id"='b001' GROUP BY "snapshot_id","scenario","record_key","reason" HAVING COUNT(*)>1); IF (n<>0) THEN RAISE bad; END IF; END; $$;

EXECUTE IMMEDIATE $$ DECLARE bad EXCEPTION (-20011, 'dq/uniqueGrain'); n NUMBER; BEGIN SELECT COUNT(*) INTO :n FROM (SELECT "snapshot_id","scenario","scope" FROM "pipeline_dq" WHERE "snapshot_id"='b001' GROUP BY "snapshot_id","scenario","scope" HAVING COUNT(*)>1); IF (n<>0) THEN RAISE bad; END IF; END; $$;

EXECUTE IMMEDIATE $$ DECLARE bad EXCEPTION (-20011, 's01_engagement/uniqueGrain'); n NUMBER; BEGIN SELECT COUNT(*) INTO :n FROM (SELECT "snapshot_id","activity_key" FROM "consumption_s01_engagement" WHERE "snapshot_id"='b001' GROUP BY "snapshot_id","activity_key" HAVING COUNT(*)>1); IF (n<>0) THEN RAISE bad; END IF; END; $$;

EXECUTE IMMEDIATE $$ DECLARE bad EXCEPTION (-20011, 's02_product_activity/uniqueGrain'); n NUMBER; BEGIN SELECT COUNT(*) INTO :n FROM (SELECT "snapshot_id","customer_key","product_code","activity_date" FROM "consumption_s02_product_activity" WHERE "snapshot_id"='b001' GROUP BY "snapshot_id","customer_key","product_code","activity_date" HAVING COUNT(*)>1); IF (n<>0) THEN RAISE bad; END IF; END; $$;

EXECUTE IMMEDIATE $$ DECLARE bad EXCEPTION (-20011, 's03_customer_territory/uniqueGrain'); n NUMBER; BEGIN SELECT COUNT(*) INTO :n FROM (SELECT "snapshot_id","customer_key" FROM "consumption_s03_customer_territory" WHERE "snapshot_id"='b001' GROUP BY "snapshot_id","customer_key" HAVING COUNT(*)>1); IF (n<>0) THEN RAISE bad; END IF; END; $$;

EXECUTE IMMEDIATE $$ DECLARE bad EXCEPTION (-20011, 's04_interaction/uniqueGrain'); n NUMBER; BEGIN SELECT COUNT(*) INTO :n FROM (SELECT "snapshot_id","activity_key" FROM "consumption_s04_interaction" WHERE "snapshot_id"='b001' GROUP BY "snapshot_id","activity_key" HAVING COUNT(*)>1); IF (n<>0) THEN RAISE bad; END IF; END; $$;

EXECUTE IMMEDIATE $$ DECLARE bad EXCEPTION (-20011, 's05_campaign/uniqueGrain'); n NUMBER; BEGIN SELECT COUNT(*) INTO :n FROM (SELECT "snapshot_id","campaign_key","customer_key" FROM "consumption_s05_campaign" WHERE "snapshot_id"='b001' GROUP BY "snapshot_id","campaign_key","customer_key" HAVING COUNT(*)>1); IF (n<>0) THEN RAISE bad; END IF; END; $$;

EXECUTE IMMEDIATE $$ DECLARE bad EXCEPTION (-20011, 'exceptions/uniqueGrain'); n NUMBER; BEGIN SELECT COUNT(*) INTO :n FROM (SELECT "snapshot_id","scenario","record_key","reason" FROM "consumption_exceptions" WHERE "snapshot_id"='b001' GROUP BY "snapshot_id","scenario","record_key","reason" HAVING COUNT(*)>1); IF (n<>0) THEN RAISE bad; END IF; END; $$;

EXECUTE IMMEDIATE $$ DECLARE bad EXCEPTION (-20011, 'dq/uniqueGrain'); n NUMBER; BEGIN SELECT COUNT(*) INTO :n FROM (SELECT "snapshot_id","scenario","scope" FROM "consumption_dq" WHERE "snapshot_id"='b001' GROUP BY "snapshot_id","scenario","scope" HAVING COUNT(*)>1); IF (n<>0) THEN RAISE bad; END IF; END; $$;

EXECUTE IMMEDIATE $$ DECLARE bad EXCEPTION (-20011, 'scenario_scorecard/uniqueGrain'); n NUMBER; BEGIN SELECT COUNT(*) INTO :n FROM (SELECT "snapshot_id","scenario","scope" FROM "visualization_scenario_scorecard" WHERE "snapshot_id"='b001' GROUP BY "snapshot_id","scenario","scope" HAVING COUNT(*)>1); IF (n<>0) THEN RAISE bad; END IF; END; $$;

EXECUTE IMMEDIATE $$ DECLARE bad EXCEPTION (-20011, 'Invalid commercial measures'); n NUMBER; BEGIN SELECT COUNT(*) INTO :n FROM "canonical_rx_version" WHERE "snapshot_id"='b001' AND ("nrx_count">"trx_count" OR "nrx_count"<0 OR "trx_count"<0 OR "sales_units"<0); IF (n<>0) THEN RAISE bad; END IF; END; $$;

EXECUTE IMMEDIATE $$ DECLARE bad EXCEPTION (-20011, 'Unknown territory reference'); n NUMBER; BEGIN SELECT COUNT(*) INTO :n FROM "canonical_customer_territory" a LEFT JOIN "canonical_territory" t ON a."snapshot_id"=t."snapshot_id" AND a."territory_code"=t."territory_code" WHERE a."snapshot_id"='b001' AND t."territory_code" IS NULL; IF (n<>0) THEN RAISE bad; END IF; END; $$;

EXECUTE IMMEDIATE $$ DECLARE bad EXCEPTION (-20011, 'Missing campaign parent'); n NUMBER; BEGIN SELECT COUNT(*) INTO :n FROM "canonical_campaign_member" m LEFT JOIN "canonical_campaign" c ON m."snapshot_id"=c."snapshot_id" AND m."campaign_key"=c."campaign_key" WHERE m."snapshot_id"='b001' AND c."campaign_key" IS NULL; IF (n<>0) THEN RAISE bad; END IF; END; $$;

EXECUTE IMMEDIATE $$ DECLARE bad EXCEPTION (-20011, 'Invalid product interval'); n NUMBER; BEGIN SELECT COUNT(*) INTO :n FROM "canonical_product_interval" WHERE "snapshot_id"='b001' AND "valid_to" IS NOT NULL AND "valid_to"<= "valid_from"; IF (n<>0) THEN RAISE bad; END IF; END; $$;

EXECUTE IMMEDIATE $$ DECLARE bad EXCEPTION (-20011, 'Invalid assignment interval'); n NUMBER; BEGIN SELECT COUNT(*) INTO :n FROM "canonical_customer_territory" WHERE "snapshot_id"='b001' AND "effective_to" IS NOT NULL AND "effective_to"<= "effective_from"; IF (n<>0) THEN RAISE bad; END IF; END; $$;

INSERT INTO ODCS_SNAPSHOT_AUDIT SELECT 'b001','pharma-lab-0.2.0','63d6b60b4b6b13fea4cc3464baba711481f780a23806d0966cb32eced186df31','27073c77045040ad84e10495e2a2a19995bfd7b94d1c9fdb0ca8b05ca8bf2cbe',TO_TIMESTAMP_NTZ($AS_OF),CURRENT_TIMESTAMP(),'PUBLISHED';

COMMIT;
