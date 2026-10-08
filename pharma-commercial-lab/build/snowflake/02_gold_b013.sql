-- Draft Snowflake reference for all five scenarios, to execute after a loader.
-- No Snowflake account was used to validate this file. STOP on the first error.
-- Session-local derived tables are intentional for Crawl; publishing is separate.
-- USE SCHEMA <your isolated database.schema> before running this file.
ALTER SESSION SET TIMEZONE = 'UTC';
SET AS_OF = '2026-10-13T06:00:00Z';

CREATE OR REPLACE VIEW "raw_iqvia_like_affiliation" AS SELECT * FROM SRC_IQVIA_LIKE_AFFILIATION;

CREATE OR REPLACE VIEW "raw_iqvia_like_organisation" AS SELECT * FROM SRC_IQVIA_LIKE_ORGANISATION;

CREATE OR REPLACE VIEW "raw_iqvia_like_product" AS SELECT * FROM SRC_IQVIA_LIKE_PRODUCT;

CREATE OR REPLACE VIEW "raw_iqvia_like_provider" AS SELECT * FROM SRC_IQVIA_LIKE_PROVIDER;

CREATE OR REPLACE VIEW "raw_iqvia_like_rx_weekly" AS SELECT * FROM SRC_IQVIA_LIKE_RX_WEEKLY;

CREATE OR REPLACE VIEW "raw_manual_territory_mapping" AS SELECT * FROM SRC_MANUAL_TERRITORY_MAPPING;

CREATE OR REPLACE VIEW "raw_salesforce_like_campaign" AS SELECT * FROM SRC_SALESFORCE_LIKE_CAMPAIGN;

CREATE OR REPLACE VIEW "raw_salesforce_like_campaign_member" AS SELECT * FROM SRC_SALESFORCE_LIKE_CAMPAIGN_MEMBER;

CREATE OR REPLACE VIEW "raw_salesforce_like_consent" AS SELECT * FROM SRC_SALESFORCE_LIKE_CONSENT;

CREATE OR REPLACE VIEW "raw_salesforce_like_contact" AS SELECT * FROM SRC_SALESFORCE_LIKE_CONTACT;

CREATE OR REPLACE VIEW "raw_veeva_like_activity" AS SELECT * FROM SRC_VEEVA_LIKE_ACTIVITY;

CREATE OR REPLACE VIEW "raw_veeva_like_activity_product" AS SELECT * FROM SRC_VEEVA_LIKE_ACTIVITY_PRODUCT;

CREATE OR REPLACE VIEW "raw_veeva_like_customer" AS SELECT * FROM SRC_VEEVA_LIKE_CUSTOMER;

CREATE OR REPLACE VIEW "raw_veeva_like_staff" AS SELECT * FROM SRC_VEEVA_LIKE_STAFF;

CREATE OR REPLACE VIEW "raw_veeva_like_territory" AS SELECT * FROM SRC_VEEVA_LIKE_TERRITORY;

EXECUTE IMMEDIATE $$ DECLARE bad EXCEPTION (-20011, 'iqvia_like/affiliation/affiliation_key semantic type'); n NUMBER; BEGIN SELECT COUNT(*) INTO :n FROM SRC_IQVIA_LIKE_AFFILIATION WHERE _available_at<=TO_TIMESTAMP_NTZ($AS_OF) AND (affiliation_key IS NULL); IF (n<>0) THEN RAISE bad; END IF; END; $$;

EXECUTE IMMEDIATE $$ DECLARE bad EXCEPTION (-20011, 'iqvia_like/affiliation/effective_from semantic type'); n NUMBER; BEGIN SELECT COUNT(*) INTO :n FROM SRC_IQVIA_LIKE_AFFILIATION WHERE _available_at<=TO_TIMESTAMP_NTZ($AS_OF) AND (effective_from IS NULL OR (effective_from IS NOT NULL AND (TRY_TO_DATE(effective_from) IS NULL OR NOT REGEXP_LIKE(effective_from,'[0-9]{4}-[0-9]{2}-[0-9]{2}')))); IF (n<>0) THEN RAISE bad; END IF; END; $$;

EXECUTE IMMEDIATE $$ DECLARE bad EXCEPTION (-20011, 'iqvia_like/affiliation/effective_to semantic type'); n NUMBER; BEGIN SELECT COUNT(*) INTO :n FROM SRC_IQVIA_LIKE_AFFILIATION WHERE _available_at<=TO_TIMESTAMP_NTZ($AS_OF) AND (FALSE OR (effective_to IS NOT NULL AND (TRY_TO_DATE(effective_to) IS NULL OR NOT REGEXP_LIKE(effective_to,'[0-9]{4}-[0-9]{2}-[0-9]{2}')))); IF (n<>0) THEN RAISE bad; END IF; END; $$;

EXECUTE IMMEDIATE $$ DECLARE bad EXCEPTION (-20011, 'iqvia_like/affiliation/is_primary semantic type'); n NUMBER; BEGIN SELECT COUNT(*) INTO :n FROM SRC_IQVIA_LIKE_AFFILIATION WHERE _available_at<=TO_TIMESTAMP_NTZ($AS_OF) AND (is_primary IS NULL OR (is_primary IS NOT NULL AND is_primary NOT IN ('true','false'))); IF (n<>0) THEN RAISE bad; END IF; END; $$;

EXECUTE IMMEDIATE $$ DECLARE bad EXCEPTION (-20011, 'iqvia_like/affiliation/organisation_key semantic type'); n NUMBER; BEGIN SELECT COUNT(*) INTO :n FROM SRC_IQVIA_LIKE_AFFILIATION WHERE _available_at<=TO_TIMESTAMP_NTZ($AS_OF) AND (organisation_key IS NULL); IF (n<>0) THEN RAISE bad; END IF; END; $$;

EXECUTE IMMEDIATE $$ DECLARE bad EXCEPTION (-20011, 'iqvia_like/affiliation/provider_key semantic type'); n NUMBER; BEGIN SELECT COUNT(*) INTO :n FROM SRC_IQVIA_LIKE_AFFILIATION WHERE _available_at<=TO_TIMESTAMP_NTZ($AS_OF) AND (provider_key IS NULL); IF (n<>0) THEN RAISE bad; END IF; END; $$;

EXECUTE IMMEDIATE $$ DECLARE bad EXCEPTION (-20011, 'iqvia_like/affiliation/relationship_type semantic type'); n NUMBER; BEGIN SELECT COUNT(*) INTO :n FROM SRC_IQVIA_LIKE_AFFILIATION WHERE _available_at<=TO_TIMESTAMP_NTZ($AS_OF) AND (relationship_type IS NULL); IF (n<>0) THEN RAISE bad; END IF; END; $$;

EXECUTE IMMEDIATE $$ DECLARE bad EXCEPTION (-20011, 'iqvia_like/affiliation conflicting business key'); n NUMBER; BEGIN SELECT COUNT(*) INTO :n FROM (SELECT affiliation_key FROM (SELECT DISTINCT affiliation_key,provider_key,organisation_key,relationship_type,is_primary,effective_from,effective_to FROM SRC_IQVIA_LIKE_AFFILIATION WHERE _available_at<=TO_TIMESTAMP_NTZ($AS_OF)) GROUP BY affiliation_key HAVING COUNT(*)>1); IF (n<>0) THEN RAISE bad; END IF; END; $$;

EXECUTE IMMEDIATE $$ DECLARE bad EXCEPTION (-20011, 'iqvia_like/organisation/country semantic type'); n NUMBER; BEGIN SELECT COUNT(*) INTO :n FROM SRC_IQVIA_LIKE_ORGANISATION WHERE _available_at<=TO_TIMESTAMP_NTZ($AS_OF) AND (country IS NULL); IF (n<>0) THEN RAISE bad; END IF; END; $$;

EXECUTE IMMEDIATE $$ DECLARE bad EXCEPTION (-20011, 'iqvia_like/organisation/organisation_key semantic type'); n NUMBER; BEGIN SELECT COUNT(*) INTO :n FROM SRC_IQVIA_LIKE_ORGANISATION WHERE _available_at<=TO_TIMESTAMP_NTZ($AS_OF) AND (organisation_key IS NULL); IF (n<>0) THEN RAISE bad; END IF; END; $$;

EXECUTE IMMEDIATE $$ DECLARE bad EXCEPTION (-20011, 'iqvia_like/organisation/organisation_name semantic type'); n NUMBER; BEGIN SELECT COUNT(*) INTO :n FROM SRC_IQVIA_LIKE_ORGANISATION WHERE _available_at<=TO_TIMESTAMP_NTZ($AS_OF) AND (organisation_name IS NULL); IF (n<>0) THEN RAISE bad; END IF; END; $$;

EXECUTE IMMEDIATE $$ DECLARE bad EXCEPTION (-20011, 'iqvia_like/organisation conflicting business key'); n NUMBER; BEGIN SELECT COUNT(*) INTO :n FROM (SELECT organisation_key FROM (SELECT DISTINCT organisation_key,organisation_name,country FROM SRC_IQVIA_LIKE_ORGANISATION WHERE _available_at<=TO_TIMESTAMP_NTZ($AS_OF)) GROUP BY organisation_key HAVING COUNT(*)>1); IF (n<>0) THEN RAISE bad; END IF; END; $$;

EXECUTE IMMEDIATE $$ DECLARE bad EXCEPTION (-20011, 'iqvia_like/product/active semantic type'); n NUMBER; BEGIN SELECT COUNT(*) INTO :n FROM SRC_IQVIA_LIKE_PRODUCT WHERE _available_at<=TO_TIMESTAMP_NTZ($AS_OF) AND (active IS NULL OR (active IS NOT NULL AND active NOT IN ('true','false'))); IF (n<>0) THEN RAISE bad; END IF; END; $$;

EXECUTE IMMEDIATE $$ DECLARE bad EXCEPTION (-20011, 'iqvia_like/product/brand semantic type'); n NUMBER; BEGIN SELECT COUNT(*) INTO :n FROM SRC_IQVIA_LIKE_PRODUCT WHERE _available_at<=TO_TIMESTAMP_NTZ($AS_OF) AND (brand IS NULL); IF (n<>0) THEN RAISE bad; END IF; END; $$;

EXECUTE IMMEDIATE $$ DECLARE bad EXCEPTION (-20011, 'iqvia_like/product/product_code semantic type'); n NUMBER; BEGIN SELECT COUNT(*) INTO :n FROM SRC_IQVIA_LIKE_PRODUCT WHERE _available_at<=TO_TIMESTAMP_NTZ($AS_OF) AND (product_code IS NULL); IF (n<>0) THEN RAISE bad; END IF; END; $$;

EXECUTE IMMEDIATE $$ DECLARE bad EXCEPTION (-20011, 'iqvia_like/product/therapy semantic type'); n NUMBER; BEGIN SELECT COUNT(*) INTO :n FROM SRC_IQVIA_LIKE_PRODUCT WHERE _available_at<=TO_TIMESTAMP_NTZ($AS_OF) AND (therapy IS NULL); IF (n<>0) THEN RAISE bad; END IF; END; $$;

EXECUTE IMMEDIATE $$ DECLARE bad EXCEPTION (-20011, 'iqvia_like/product/valid_from semantic type'); n NUMBER; BEGIN SELECT COUNT(*) INTO :n FROM SRC_IQVIA_LIKE_PRODUCT WHERE _available_at<=TO_TIMESTAMP_NTZ($AS_OF) AND (valid_from IS NULL OR (valid_from IS NOT NULL AND (TRY_TO_DATE(valid_from) IS NULL OR NOT REGEXP_LIKE(valid_from,'[0-9]{4}-[0-9]{2}-[0-9]{2}')))); IF (n<>0) THEN RAISE bad; END IF; END; $$;

EXECUTE IMMEDIATE $$ DECLARE bad EXCEPTION (-20011, 'iqvia_like/product/valid_to semantic type'); n NUMBER; BEGIN SELECT COUNT(*) INTO :n FROM SRC_IQVIA_LIKE_PRODUCT WHERE _available_at<=TO_TIMESTAMP_NTZ($AS_OF) AND (FALSE OR (valid_to IS NOT NULL AND (TRY_TO_DATE(valid_to) IS NULL OR NOT REGEXP_LIKE(valid_to,'[0-9]{4}-[0-9]{2}-[0-9]{2}')))); IF (n<>0) THEN RAISE bad; END IF; END; $$;

EXECUTE IMMEDIATE $$ DECLARE bad EXCEPTION (-20011, 'iqvia_like/product conflicting business key'); n NUMBER; BEGIN SELECT COUNT(*) INTO :n FROM (SELECT product_code,valid_from FROM (SELECT DISTINCT product_code,brand,therapy,valid_from,valid_to,active FROM SRC_IQVIA_LIKE_PRODUCT WHERE _available_at<=TO_TIMESTAMP_NTZ($AS_OF)) GROUP BY product_code,valid_from HAVING COUNT(*)>1); IF (n<>0) THEN RAISE bad; END IF; END; $$;

EXECUTE IMMEDIATE $$ DECLARE bad EXCEPTION (-20011, 'iqvia_like/provider/active semantic type'); n NUMBER; BEGIN SELECT COUNT(*) INTO :n FROM SRC_IQVIA_LIKE_PROVIDER WHERE _available_at<=TO_TIMESTAMP_NTZ($AS_OF) AND (active IS NULL OR (active IS NOT NULL AND active NOT IN ('true','false'))); IF (n<>0) THEN RAISE bad; END IF; END; $$;

EXECUTE IMMEDIATE $$ DECLARE bad EXCEPTION (-20011, 'iqvia_like/provider/country semantic type'); n NUMBER; BEGIN SELECT COUNT(*) INTO :n FROM SRC_IQVIA_LIKE_PROVIDER WHERE _available_at<=TO_TIMESTAMP_NTZ($AS_OF) AND (country IS NULL); IF (n<>0) THEN RAISE bad; END IF; END; $$;

EXECUTE IMMEDIATE $$ DECLARE bad EXCEPTION (-20011, 'iqvia_like/provider/label semantic type'); n NUMBER; BEGIN SELECT COUNT(*) INTO :n FROM SRC_IQVIA_LIKE_PROVIDER WHERE _available_at<=TO_TIMESTAMP_NTZ($AS_OF) AND (label IS NULL); IF (n<>0) THEN RAISE bad; END IF; END; $$;

EXECUTE IMMEDIATE $$ DECLARE bad EXCEPTION (-20011, 'iqvia_like/provider/link_token semantic type'); n NUMBER; BEGIN SELECT COUNT(*) INTO :n FROM SRC_IQVIA_LIKE_PROVIDER WHERE _available_at<=TO_TIMESTAMP_NTZ($AS_OF) AND (FALSE); IF (n<>0) THEN RAISE bad; END IF; END; $$;

EXECUTE IMMEDIATE $$ DECLARE bad EXCEPTION (-20011, 'iqvia_like/provider/postal_sector semantic type'); n NUMBER; BEGIN SELECT COUNT(*) INTO :n FROM SRC_IQVIA_LIKE_PROVIDER WHERE _available_at<=TO_TIMESTAMP_NTZ($AS_OF) AND (postal_sector IS NULL); IF (n<>0) THEN RAISE bad; END IF; END; $$;

EXECUTE IMMEDIATE $$ DECLARE bad EXCEPTION (-20011, 'iqvia_like/provider/provider_key semantic type'); n NUMBER; BEGIN SELECT COUNT(*) INTO :n FROM SRC_IQVIA_LIKE_PROVIDER WHERE _available_at<=TO_TIMESTAMP_NTZ($AS_OF) AND (provider_key IS NULL); IF (n<>0) THEN RAISE bad; END IF; END; $$;

EXECUTE IMMEDIATE $$ DECLARE bad EXCEPTION (-20011, 'iqvia_like/provider/speciality semantic type'); n NUMBER; BEGIN SELECT COUNT(*) INTO :n FROM SRC_IQVIA_LIKE_PROVIDER WHERE _available_at<=TO_TIMESTAMP_NTZ($AS_OF) AND (speciality IS NULL); IF (n<>0) THEN RAISE bad; END IF; END; $$;

EXECUTE IMMEDIATE $$ DECLARE bad EXCEPTION (-20011, 'iqvia_like/provider conflicting business key'); n NUMBER; BEGIN SELECT COUNT(*) INTO :n FROM (SELECT provider_key FROM (SELECT DISTINCT provider_key,link_token,label,speciality,active,country,postal_sector FROM SRC_IQVIA_LIKE_PROVIDER WHERE _available_at<=TO_TIMESTAMP_NTZ($AS_OF)) GROUP BY provider_key HAVING COUNT(*)>1); IF (n<>0) THEN RAISE bad; END IF; END; $$;

EXECUTE IMMEDIATE $$ DECLARE bad EXCEPTION (-20011, 'iqvia_like/rx_weekly/nrx_count semantic type'); n NUMBER; BEGIN SELECT COUNT(*) INTO :n FROM SRC_IQVIA_LIKE_RX_WEEKLY WHERE _available_at<=TO_TIMESTAMP_NTZ($AS_OF) AND (nrx_count IS NULL OR (nrx_count IS NOT NULL AND NOT REGEXP_LIKE(nrx_count,'-?[0-9]+'))); IF (n<>0) THEN RAISE bad; END IF; END; $$;

EXECUTE IMMEDIATE $$ DECLARE bad EXCEPTION (-20011, 'iqvia_like/rx_weekly/observation_key semantic type'); n NUMBER; BEGIN SELECT COUNT(*) INTO :n FROM SRC_IQVIA_LIKE_RX_WEEKLY WHERE _available_at<=TO_TIMESTAMP_NTZ($AS_OF) AND (observation_key IS NULL); IF (n<>0) THEN RAISE bad; END IF; END; $$;

EXECUTE IMMEDIATE $$ DECLARE bad EXCEPTION (-20011, 'iqvia_like/rx_weekly/product_code semantic type'); n NUMBER; BEGIN SELECT COUNT(*) INTO :n FROM SRC_IQVIA_LIKE_RX_WEEKLY WHERE _available_at<=TO_TIMESTAMP_NTZ($AS_OF) AND (product_code IS NULL); IF (n<>0) THEN RAISE bad; END IF; END; $$;

EXECUTE IMMEDIATE $$ DECLARE bad EXCEPTION (-20011, 'iqvia_like/rx_weekly/provider_key semantic type'); n NUMBER; BEGIN SELECT COUNT(*) INTO :n FROM SRC_IQVIA_LIKE_RX_WEEKLY WHERE _available_at<=TO_TIMESTAMP_NTZ($AS_OF) AND (provider_key IS NULL); IF (n<>0) THEN RAISE bad; END IF; END; $$;

EXECUTE IMMEDIATE $$ DECLARE bad EXCEPTION (-20011, 'iqvia_like/rx_weekly/sales_units semantic type'); n NUMBER; BEGIN SELECT COUNT(*) INTO :n FROM SRC_IQVIA_LIKE_RX_WEEKLY WHERE _available_at<=TO_TIMESTAMP_NTZ($AS_OF) AND (sales_units IS NULL OR (sales_units IS NOT NULL AND NOT REGEXP_LIKE(sales_units,'-?[0-9]+'))); IF (n<>0) THEN RAISE bad; END IF; END; $$;

EXECUTE IMMEDIATE $$ DECLARE bad EXCEPTION (-20011, 'iqvia_like/rx_weekly/trx_count semantic type'); n NUMBER; BEGIN SELECT COUNT(*) INTO :n FROM SRC_IQVIA_LIKE_RX_WEEKLY WHERE _available_at<=TO_TIMESTAMP_NTZ($AS_OF) AND (trx_count IS NULL OR (trx_count IS NOT NULL AND NOT REGEXP_LIKE(trx_count,'-?[0-9]+'))); IF (n<>0) THEN RAISE bad; END IF; END; $$;

EXECUTE IMMEDIATE $$ DECLARE bad EXCEPTION (-20011, 'iqvia_like/rx_weekly/version_no semantic type'); n NUMBER; BEGIN SELECT COUNT(*) INTO :n FROM SRC_IQVIA_LIKE_RX_WEEKLY WHERE _available_at<=TO_TIMESTAMP_NTZ($AS_OF) AND (version_no IS NULL OR (version_no IS NOT NULL AND NOT REGEXP_LIKE(version_no,'-?[0-9]+'))); IF (n<>0) THEN RAISE bad; END IF; END; $$;

EXECUTE IMMEDIATE $$ DECLARE bad EXCEPTION (-20011, 'iqvia_like/rx_weekly/week_ending semantic type'); n NUMBER; BEGIN SELECT COUNT(*) INTO :n FROM SRC_IQVIA_LIKE_RX_WEEKLY WHERE _available_at<=TO_TIMESTAMP_NTZ($AS_OF) AND (week_ending IS NULL OR (week_ending IS NOT NULL AND (TRY_TO_DATE(week_ending) IS NULL OR NOT REGEXP_LIKE(week_ending,'[0-9]{4}-[0-9]{2}-[0-9]{2}')))); IF (n<>0) THEN RAISE bad; END IF; END; $$;

EXECUTE IMMEDIATE $$ DECLARE bad EXCEPTION (-20011, 'iqvia_like/rx_weekly conflicting business key'); n NUMBER; BEGIN SELECT COUNT(*) INTO :n FROM (SELECT observation_key,version_no FROM (SELECT DISTINCT observation_key,provider_key,product_code,week_ending,trx_count,nrx_count,sales_units,version_no FROM SRC_IQVIA_LIKE_RX_WEEKLY WHERE _available_at<=TO_TIMESTAMP_NTZ($AS_OF)) GROUP BY observation_key,version_no HAVING COUNT(*)>1); IF (n<>0) THEN RAISE bad; END IF; END; $$;

EXECUTE IMMEDIATE $$ DECLARE bad EXCEPTION (-20011, 'manual/territory_mapping/assignment_key semantic type'); n NUMBER; BEGIN SELECT COUNT(*) INTO :n FROM SRC_MANUAL_TERRITORY_MAPPING WHERE _available_at<=TO_TIMESTAMP_NTZ($AS_OF) AND (assignment_key IS NULL); IF (n<>0) THEN RAISE bad; END IF; END; $$;

EXECUTE IMMEDIATE $$ DECLARE bad EXCEPTION (-20011, 'manual/territory_mapping/effective_from semantic type'); n NUMBER; BEGIN SELECT COUNT(*) INTO :n FROM SRC_MANUAL_TERRITORY_MAPPING WHERE _available_at<=TO_TIMESTAMP_NTZ($AS_OF) AND (effective_from IS NULL OR (effective_from IS NOT NULL AND (TRY_TO_DATE(effective_from) IS NULL OR NOT REGEXP_LIKE(effective_from,'[0-9]{4}-[0-9]{2}-[0-9]{2}')))); IF (n<>0) THEN RAISE bad; END IF; END; $$;

EXECUTE IMMEDIATE $$ DECLARE bad EXCEPTION (-20011, 'manual/territory_mapping/effective_to semantic type'); n NUMBER; BEGIN SELECT COUNT(*) INTO :n FROM SRC_MANUAL_TERRITORY_MAPPING WHERE _available_at<=TO_TIMESTAMP_NTZ($AS_OF) AND (FALSE OR (effective_to IS NOT NULL AND (TRY_TO_DATE(effective_to) IS NULL OR NOT REGEXP_LIKE(effective_to,'[0-9]{4}-[0-9]{2}-[0-9]{2}')))); IF (n<>0) THEN RAISE bad; END IF; END; $$;

EXECUTE IMMEDIATE $$ DECLARE bad EXCEPTION (-20011, 'manual/territory_mapping/provider_key semantic type'); n NUMBER; BEGIN SELECT COUNT(*) INTO :n FROM SRC_MANUAL_TERRITORY_MAPPING WHERE _available_at<=TO_TIMESTAMP_NTZ($AS_OF) AND (provider_key IS NULL); IF (n<>0) THEN RAISE bad; END IF; END; $$;

EXECUTE IMMEDIATE $$ DECLARE bad EXCEPTION (-20011, 'manual/territory_mapping/territory_code semantic type'); n NUMBER; BEGIN SELECT COUNT(*) INTO :n FROM SRC_MANUAL_TERRITORY_MAPPING WHERE _available_at<=TO_TIMESTAMP_NTZ($AS_OF) AND (territory_code IS NULL); IF (n<>0) THEN RAISE bad; END IF; END; $$;

EXECUTE IMMEDIATE $$ DECLARE bad EXCEPTION (-20011, 'manual/territory_mapping conflicting business key'); n NUMBER; BEGIN SELECT COUNT(*) INTO :n FROM (SELECT assignment_key FROM (SELECT DISTINCT assignment_key,provider_key,territory_code,effective_from,effective_to FROM SRC_MANUAL_TERRITORY_MAPPING WHERE _available_at<=TO_TIMESTAMP_NTZ($AS_OF)) GROUP BY assignment_key HAVING COUNT(*)>1); IF (n<>0) THEN RAISE bad; END IF; END; $$;

EXECUTE IMMEDIATE $$ DECLARE bad EXCEPTION (-20011, 'salesforce_like/campaign/campaign_key semantic type'); n NUMBER; BEGIN SELECT COUNT(*) INTO :n FROM SRC_SALESFORCE_LIKE_CAMPAIGN WHERE _available_at<=TO_TIMESTAMP_NTZ($AS_OF) AND (campaign_key IS NULL); IF (n<>0) THEN RAISE bad; END IF; END; $$;

EXECUTE IMMEDIATE $$ DECLARE bad EXCEPTION (-20011, 'salesforce_like/campaign/end_date_exclusive semantic type'); n NUMBER; BEGIN SELECT COUNT(*) INTO :n FROM SRC_SALESFORCE_LIKE_CAMPAIGN WHERE _available_at<=TO_TIMESTAMP_NTZ($AS_OF) AND (end_date_exclusive IS NULL OR (end_date_exclusive IS NOT NULL AND (TRY_TO_DATE(end_date_exclusive) IS NULL OR NOT REGEXP_LIKE(end_date_exclusive,'[0-9]{4}-[0-9]{2}-[0-9]{2}')))); IF (n<>0) THEN RAISE bad; END IF; END; $$;

EXECUTE IMMEDIATE $$ DECLARE bad EXCEPTION (-20011, 'salesforce_like/campaign/product_code semantic type'); n NUMBER; BEGIN SELECT COUNT(*) INTO :n FROM SRC_SALESFORCE_LIKE_CAMPAIGN WHERE _available_at<=TO_TIMESTAMP_NTZ($AS_OF) AND (product_code IS NULL); IF (n<>0) THEN RAISE bad; END IF; END; $$;

EXECUTE IMMEDIATE $$ DECLARE bad EXCEPTION (-20011, 'salesforce_like/campaign/start_date semantic type'); n NUMBER; BEGIN SELECT COUNT(*) INTO :n FROM SRC_SALESFORCE_LIKE_CAMPAIGN WHERE _available_at<=TO_TIMESTAMP_NTZ($AS_OF) AND (start_date IS NULL OR (start_date IS NOT NULL AND (TRY_TO_DATE(start_date) IS NULL OR NOT REGEXP_LIKE(start_date,'[0-9]{4}-[0-9]{2}-[0-9]{2}')))); IF (n<>0) THEN RAISE bad; END IF; END; $$;

EXECUTE IMMEDIATE $$ DECLARE bad EXCEPTION (-20011, 'salesforce_like/campaign/status semantic type'); n NUMBER; BEGIN SELECT COUNT(*) INTO :n FROM SRC_SALESFORCE_LIKE_CAMPAIGN WHERE _available_at<=TO_TIMESTAMP_NTZ($AS_OF) AND (status IS NULL); IF (n<>0) THEN RAISE bad; END IF; END; $$;

EXECUTE IMMEDIATE $$ DECLARE bad EXCEPTION (-20011, 'salesforce_like/campaign conflicting business key'); n NUMBER; BEGIN SELECT COUNT(*) INTO :n FROM (SELECT campaign_key FROM (SELECT DISTINCT campaign_key,product_code,start_date,end_date_exclusive,status FROM SRC_SALESFORCE_LIKE_CAMPAIGN WHERE _available_at<=TO_TIMESTAMP_NTZ($AS_OF)) GROUP BY campaign_key HAVING COUNT(*)>1); IF (n<>0) THEN RAISE bad; END IF; END; $$;

EXECUTE IMMEDIATE $$ DECLARE bad EXCEPTION (-20011, 'salesforce_like/campaign_member/campaign_key semantic type'); n NUMBER; BEGIN SELECT COUNT(*) INTO :n FROM SRC_SALESFORCE_LIKE_CAMPAIGN_MEMBER WHERE _available_at<=TO_TIMESTAMP_NTZ($AS_OF) AND (campaign_key IS NULL); IF (n<>0) THEN RAISE bad; END IF; END; $$;

EXECUTE IMMEDIATE $$ DECLARE bad EXCEPTION (-20011, 'salesforce_like/campaign_member/contact_key semantic type'); n NUMBER; BEGIN SELECT COUNT(*) INTO :n FROM SRC_SALESFORCE_LIKE_CAMPAIGN_MEMBER WHERE _available_at<=TO_TIMESTAMP_NTZ($AS_OF) AND (contact_key IS NULL); IF (n<>0) THEN RAISE bad; END IF; END; $$;

EXECUTE IMMEDIATE $$ DECLARE bad EXCEPTION (-20011, 'salesforce_like/campaign_member/member_status semantic type'); n NUMBER; BEGIN SELECT COUNT(*) INTO :n FROM SRC_SALESFORCE_LIKE_CAMPAIGN_MEMBER WHERE _available_at<=TO_TIMESTAMP_NTZ($AS_OF) AND (member_status IS NULL); IF (n<>0) THEN RAISE bad; END IF; END; $$;

EXECUTE IMMEDIATE $$ DECLARE bad EXCEPTION (-20011, 'salesforce_like/campaign_member/membership_key semantic type'); n NUMBER; BEGIN SELECT COUNT(*) INTO :n FROM SRC_SALESFORCE_LIKE_CAMPAIGN_MEMBER WHERE _available_at<=TO_TIMESTAMP_NTZ($AS_OF) AND (membership_key IS NULL); IF (n<>0) THEN RAISE bad; END IF; END; $$;

EXECUTE IMMEDIATE $$ DECLARE bad EXCEPTION (-20011, 'salesforce_like/campaign_member conflicting business key'); n NUMBER; BEGIN SELECT COUNT(*) INTO :n FROM (SELECT membership_key FROM (SELECT DISTINCT membership_key,campaign_key,contact_key,member_status FROM SRC_SALESFORCE_LIKE_CAMPAIGN_MEMBER WHERE _available_at<=TO_TIMESTAMP_NTZ($AS_OF)) GROUP BY membership_key HAVING COUNT(*)>1); IF (n<>0) THEN RAISE bad; END IF; END; $$;

EXECUTE IMMEDIATE $$ DECLARE bad EXCEPTION (-20011, 'salesforce_like/consent/channel semantic type'); n NUMBER; BEGIN SELECT COUNT(*) INTO :n FROM SRC_SALESFORCE_LIKE_CONSENT WHERE _available_at<=TO_TIMESTAMP_NTZ($AS_OF) AND (channel IS NULL); IF (n<>0) THEN RAISE bad; END IF; END; $$;

EXECUTE IMMEDIATE $$ DECLARE bad EXCEPTION (-20011, 'salesforce_like/consent/contact_key semantic type'); n NUMBER; BEGIN SELECT COUNT(*) INTO :n FROM SRC_SALESFORCE_LIKE_CONSENT WHERE _available_at<=TO_TIMESTAMP_NTZ($AS_OF) AND (contact_key IS NULL); IF (n<>0) THEN RAISE bad; END IF; END; $$;

EXECUTE IMMEDIATE $$ DECLARE bad EXCEPTION (-20011, 'salesforce_like/consent/effective_at semantic type'); n NUMBER; BEGIN SELECT COUNT(*) INTO :n FROM SRC_SALESFORCE_LIKE_CONSENT WHERE _available_at<=TO_TIMESTAMP_NTZ($AS_OF) AND (effective_at IS NULL OR (effective_at IS NOT NULL AND (TRY_TO_TIMESTAMP_NTZ(effective_at) IS NULL OR NOT REGEXP_LIKE(effective_at,'.*(Z|[+]00:00)$')))); IF (n<>0) THEN RAISE bad; END IF; END; $$;

EXECUTE IMMEDIATE $$ DECLARE bad EXCEPTION (-20011, 'salesforce_like/consent/preference_key semantic type'); n NUMBER; BEGIN SELECT COUNT(*) INTO :n FROM SRC_SALESFORCE_LIKE_CONSENT WHERE _available_at<=TO_TIMESTAMP_NTZ($AS_OF) AND (preference_key IS NULL); IF (n<>0) THEN RAISE bad; END IF; END; $$;

EXECUTE IMMEDIATE $$ DECLARE bad EXCEPTION (-20011, 'salesforce_like/consent/purpose semantic type'); n NUMBER; BEGIN SELECT COUNT(*) INTO :n FROM SRC_SALESFORCE_LIKE_CONSENT WHERE _available_at<=TO_TIMESTAMP_NTZ($AS_OF) AND (purpose IS NULL); IF (n<>0) THEN RAISE bad; END IF; END; $$;

EXECUTE IMMEDIATE $$ DECLARE bad EXCEPTION (-20011, 'salesforce_like/consent/sequence_no semantic type'); n NUMBER; BEGIN SELECT COUNT(*) INTO :n FROM SRC_SALESFORCE_LIKE_CONSENT WHERE _available_at<=TO_TIMESTAMP_NTZ($AS_OF) AND (sequence_no IS NULL OR (sequence_no IS NOT NULL AND NOT REGEXP_LIKE(sequence_no,'-?[0-9]+'))); IF (n<>0) THEN RAISE bad; END IF; END; $$;

EXECUTE IMMEDIATE $$ DECLARE bad EXCEPTION (-20011, 'salesforce_like/consent/status semantic type'); n NUMBER; BEGIN SELECT COUNT(*) INTO :n FROM SRC_SALESFORCE_LIKE_CONSENT WHERE _available_at<=TO_TIMESTAMP_NTZ($AS_OF) AND (status IS NULL); IF (n<>0) THEN RAISE bad; END IF; END; $$;

EXECUTE IMMEDIATE $$ DECLARE bad EXCEPTION (-20011, 'salesforce_like/consent conflicting business key'); n NUMBER; BEGIN SELECT COUNT(*) INTO :n FROM (SELECT preference_key FROM (SELECT DISTINCT preference_key,contact_key,channel,purpose,status,effective_at,sequence_no FROM SRC_SALESFORCE_LIKE_CONSENT WHERE _available_at<=TO_TIMESTAMP_NTZ($AS_OF)) GROUP BY preference_key HAVING COUNT(*)>1); IF (n<>0) THEN RAISE bad; END IF; END; $$;

EXECUTE IMMEDIATE $$ DECLARE bad EXCEPTION (-20011, 'salesforce_like/contact/contact_key semantic type'); n NUMBER; BEGIN SELECT COUNT(*) INTO :n FROM SRC_SALESFORCE_LIKE_CONTACT WHERE _available_at<=TO_TIMESTAMP_NTZ($AS_OF) AND (contact_key IS NULL); IF (n<>0) THEN RAISE bad; END IF; END; $$;

EXECUTE IMMEDIATE $$ DECLARE bad EXCEPTION (-20011, 'salesforce_like/contact/display_name semantic type'); n NUMBER; BEGIN SELECT COUNT(*) INTO :n FROM SRC_SALESFORCE_LIKE_CONTACT WHERE _available_at<=TO_TIMESTAMP_NTZ($AS_OF) AND (display_name IS NULL); IF (n<>0) THEN RAISE bad; END IF; END; $$;

EXECUTE IMMEDIATE $$ DECLARE bad EXCEPTION (-20011, 'salesforce_like/contact/match_token semantic type'); n NUMBER; BEGIN SELECT COUNT(*) INTO :n FROM SRC_SALESFORCE_LIKE_CONTACT WHERE _available_at<=TO_TIMESTAMP_NTZ($AS_OF) AND (FALSE); IF (n<>0) THEN RAISE bad; END IF; END; $$;

EXECUTE IMMEDIATE $$ DECLARE bad EXCEPTION (-20011, 'salesforce_like/contact conflicting business key'); n NUMBER; BEGIN SELECT COUNT(*) INTO :n FROM (SELECT contact_key FROM (SELECT DISTINCT contact_key,match_token,display_name FROM SRC_SALESFORCE_LIKE_CONTACT WHERE _available_at<=TO_TIMESTAMP_NTZ($AS_OF)) GROUP BY contact_key HAVING COUNT(*)>1); IF (n<>0) THEN RAISE bad; END IF; END; $$;

EXECUTE IMMEDIATE $$ DECLARE bad EXCEPTION (-20011, 'veeva_like/customer/active semantic type'); n NUMBER; BEGIN SELECT COUNT(*) INTO :n FROM SRC_VEEVA_LIKE_CUSTOMER WHERE _available_at<=TO_TIMESTAMP_NTZ($AS_OF) AND (active IS NULL OR (active IS NOT NULL AND active NOT IN ('true','false'))); IF (n<>0) THEN RAISE bad; END IF; END; $$;

EXECUTE IMMEDIATE $$ DECLARE bad EXCEPTION (-20011, 'veeva_like/customer/customer_key semantic type'); n NUMBER; BEGIN SELECT COUNT(*) INTO :n FROM SRC_VEEVA_LIKE_CUSTOMER WHERE _available_at<=TO_TIMESTAMP_NTZ($AS_OF) AND (customer_key IS NULL); IF (n<>0) THEN RAISE bad; END IF; END; $$;

EXECUTE IMMEDIATE $$ DECLARE bad EXCEPTION (-20011, 'veeva_like/customer/display_name semantic type'); n NUMBER; BEGIN SELECT COUNT(*) INTO :n FROM SRC_VEEVA_LIKE_CUSTOMER WHERE _available_at<=TO_TIMESTAMP_NTZ($AS_OF) AND (display_name IS NULL); IF (n<>0) THEN RAISE bad; END IF; END; $$;

EXECUTE IMMEDIATE $$ DECLARE bad EXCEPTION (-20011, 'veeva_like/customer/match_token semantic type'); n NUMBER; BEGIN SELECT COUNT(*) INTO :n FROM SRC_VEEVA_LIKE_CUSTOMER WHERE _available_at<=TO_TIMESTAMP_NTZ($AS_OF) AND (FALSE); IF (n<>0) THEN RAISE bad; END IF; END; $$;

EXECUTE IMMEDIATE $$ DECLARE bad EXCEPTION (-20011, 'veeva_like/customer conflicting business key'); n NUMBER; BEGIN SELECT COUNT(*) INTO :n FROM (SELECT customer_key FROM (SELECT DISTINCT customer_key,match_token,display_name,active FROM SRC_VEEVA_LIKE_CUSTOMER WHERE _available_at<=TO_TIMESTAMP_NTZ($AS_OF)) GROUP BY customer_key HAVING COUNT(*)>1); IF (n<>0) THEN RAISE bad; END IF; END; $$;

EXECUTE IMMEDIATE $$ DECLARE bad EXCEPTION (-20011, 'veeva_like/staff/staff_key semantic type'); n NUMBER; BEGIN SELECT COUNT(*) INTO :n FROM SRC_VEEVA_LIKE_STAFF WHERE _available_at<=TO_TIMESTAMP_NTZ($AS_OF) AND (staff_key IS NULL); IF (n<>0) THEN RAISE bad; END IF; END; $$;

EXECUTE IMMEDIATE $$ DECLARE bad EXCEPTION (-20011, 'veeva_like/staff/staff_name semantic type'); n NUMBER; BEGIN SELECT COUNT(*) INTO :n FROM SRC_VEEVA_LIKE_STAFF WHERE _available_at<=TO_TIMESTAMP_NTZ($AS_OF) AND (staff_name IS NULL); IF (n<>0) THEN RAISE bad; END IF; END; $$;

EXECUTE IMMEDIATE $$ DECLARE bad EXCEPTION (-20011, 'veeva_like/staff conflicting business key'); n NUMBER; BEGIN SELECT COUNT(*) INTO :n FROM (SELECT staff_key FROM (SELECT DISTINCT staff_key,staff_name FROM SRC_VEEVA_LIKE_STAFF WHERE _available_at<=TO_TIMESTAMP_NTZ($AS_OF)) GROUP BY staff_key HAVING COUNT(*)>1); IF (n<>0) THEN RAISE bad; END IF; END; $$;

EXECUTE IMMEDIATE $$ DECLARE bad EXCEPTION (-20011, 'veeva_like/territory/territory_code semantic type'); n NUMBER; BEGIN SELECT COUNT(*) INTO :n FROM SRC_VEEVA_LIKE_TERRITORY WHERE _available_at<=TO_TIMESTAMP_NTZ($AS_OF) AND (territory_code IS NULL); IF (n<>0) THEN RAISE bad; END IF; END; $$;

EXECUTE IMMEDIATE $$ DECLARE bad EXCEPTION (-20011, 'veeva_like/territory/territory_name semantic type'); n NUMBER; BEGIN SELECT COUNT(*) INTO :n FROM SRC_VEEVA_LIKE_TERRITORY WHERE _available_at<=TO_TIMESTAMP_NTZ($AS_OF) AND (territory_name IS NULL); IF (n<>0) THEN RAISE bad; END IF; END; $$;

EXECUTE IMMEDIATE $$ DECLARE bad EXCEPTION (-20011, 'veeva_like/territory conflicting business key'); n NUMBER; BEGIN SELECT COUNT(*) INTO :n FROM (SELECT territory_code FROM (SELECT DISTINCT territory_code,territory_name FROM SRC_VEEVA_LIKE_TERRITORY WHERE _available_at<=TO_TIMESTAMP_NTZ($AS_OF)) GROUP BY territory_code HAVING COUNT(*)>1); IF (n<>0) THEN RAISE bad; END IF; END; $$; -- b001: 2026-09-14T06:00:00Z

CREATE OR REPLACE TEMP TABLE APPROVED_CUSTOMER AS
SELECT DISTINCT provider_key,link_token FROM SRC_IQVIA_LIKE_PROVIDER
WHERE active='true' AND _available_at<=TO_TIMESTAMP_NTZ($AS_OF);
CREATE OR REPLACE TEMP TABLE UNIQUE_TOKEN AS
SELECT link_token,MIN(provider_key) provider_key FROM APPROVED_CUSTOMER
WHERE link_token IS NOT NULL GROUP BY link_token HAVING COUNT(DISTINCT provider_key)=1;
CREATE OR REPLACE TEMP TABLE CRM_MAP AS
SELECT c.customer_key,MIN(u.provider_key) provider_key FROM SRC_VEEVA_LIKE_CUSTOMER c
LEFT JOIN UNIQUE_TOKEN u ON c.match_token=u.link_token
WHERE c._available_at<=TO_TIMESTAMP_NTZ($AS_OF)
GROUP BY c.customer_key HAVING COUNT(DISTINCT u.provider_key)=1 AND COUNT_IF(u.provider_key IS NULL)=0;
CREATE OR REPLACE TEMP TABLE SF_MAP AS
SELECT c.contact_key,MIN(u.provider_key) provider_key FROM SRC_SALESFORCE_LIKE_CONTACT c
LEFT JOIN UNIQUE_TOKEN u ON c.match_token=u.link_token
WHERE c._available_at<=TO_TIMESTAMP_NTZ($AS_OF)
GROUP BY c.contact_key HAVING COUNT(DISTINCT u.provider_key)=1 AND COUNT_IF(u.provider_key IS NULL)=0;
CREATE OR REPLACE TEMP TABLE CURRENT_PRODUCT AS
SELECT DISTINCT product_code,brand,therapy FROM SRC_IQVIA_LIKE_PRODUCT
WHERE active='true' AND valid_from::DATE<=TO_DATE(TO_TIMESTAMP_NTZ($AS_OF))
AND (valid_to IS NULL OR TO_DATE(TO_TIMESTAMP_NTZ($AS_OF))<valid_to::DATE)
AND _available_at<=TO_TIMESTAMP_NTZ($AS_OF);

CREATE OR REPLACE TEMP TABLE ACTIVITY_VERSION AS
SELECT DISTINCT activity_key,customer_key,primary_product_code,occurred_at,channel,approval,
staff_key,duration_minutes,source_version,modified_at,operation,_available_at,_mode,_batch_id
FROM SRC_VEEVA_LIKE_ACTIVITY WHERE _available_at<=TO_TIMESTAMP_NTZ($AS_OF);
-- Fail conflicting versions before choosing a winner. A row-number tie breaker
-- would merely conceal the source defect.
EXECUTE IMMEDIATE $$
DECLARE bad EXCEPTION (-20003,'Conflicting interaction versions'); n NUMBER;
BEGIN
  SELECT COUNT(*) INTO :n FROM (
    SELECT activity_key,TRY_TO_NUMBER(source_version) source_version FROM (
      SELECT DISTINCT activity_key,customer_key,primary_product_code,occurred_at,channel,
        approval,staff_key,duration_minutes,source_version,modified_at,operation FROM ACTIVITY_VERSION
    ) WHERE REGEXP_LIKE(source_version,'-?[0-9]+')
    GROUP BY activity_key,TRY_TO_NUMBER(source_version) HAVING COUNT(*)>1
  );
  IF (n>0) THEN RAISE bad; END IF;
END; $$;

CREATE OR REPLACE TEMP TABLE ACTIVITY_CLASSIFIED AS
SELECT *, CASE
 WHEN activity_key IS NULL OR customer_key IS NULL OR primary_product_code IS NULL
   OR occurred_at IS NULL OR modified_at IS NULL THEN 'MISSING_REQUIRED'
 WHEN TRY_TO_TIMESTAMP_NTZ(occurred_at) IS NULL OR TRY_TO_TIMESTAMP_NTZ(modified_at) IS NULL
   OR TRY_TO_NUMBER(duration_minutes) IS NULL OR TRY_TO_NUMBER(source_version) IS NULL
   OR NOT REGEXP_LIKE(source_version,'-?[0-9]+') OR NOT REGEXP_LIKE(duration_minutes,'-?[0-9]+')
   OR NOT REGEXP_LIKE(occurred_at,'.*(Z|[+]00:00)$') OR NOT REGEXP_LIKE(modified_at,'.*(Z|[+]00:00)$') THEN 'INVALID_TYPE'
 WHEN TRY_TO_NUMBER(source_version)<1 OR TRY_TO_NUMBER(duration_minutes)<0 OR TRY_TO_TIMESTAMP_NTZ(occurred_at)>TO_TIMESTAMP_NTZ($AS_OF)
   OR TRY_TO_TIMESTAMP_NTZ(modified_at)>_available_at OR operation NOT IN ('UPSERT','DELETE') THEN 'INVALID_VALUE'
 WHEN _mode<>'bootstrap' AND DATEDIFF(day,
   IFF(TRY_TO_NUMBER(source_version)>1,TRY_TO_TIMESTAMP_NTZ(modified_at),TRY_TO_TIMESTAMP_NTZ(occurred_at)),_available_at)>7 THEN 'LATE_BEYOND_WINDOW'
 ELSE 'ACCEPT' END AS disposition
FROM ACTIVITY_VERSION
QUALIFY ROW_NUMBER() OVER(PARTITION BY activity_key,customer_key,primary_product_code,occurred_at,channel,approval,duration_minutes,source_version,modified_at,operation ORDER BY _available_at,_batch_id)=1;
CREATE OR REPLACE TEMP TABLE INTERACTION_LATEST AS
SELECT * FROM ACTIVITY_CLASSIFIED WHERE disposition='ACCEPT'
QUALIFY ROW_NUMBER() OVER(PARTITION BY activity_key ORDER BY source_version::NUMBER DESC,_available_at ASC)=1;
CREATE OR REPLACE TEMP TABLE GOLD_S04_INTERACTION AS
SELECT activity_key,customer_key,primary_product_code,occurred_at,channel,
duration_minutes::NUMBER duration_minutes,source_version::NUMBER source_version
FROM INTERACTION_LATEST WHERE operation<>'DELETE';
CREATE OR REPLACE TEMP TABLE ELIGIBLE AS
SELECT a.*,m.provider_key FROM INTERACTION_LATEST a LEFT JOIN CRM_MAP m USING(customer_key)
WHERE a.operation<>'DELETE' AND a.approval='APPROVED';
CREATE OR REPLACE TEMP TABLE DETAIL AS
SELECT DISTINCT activity_key,TRY_TO_NUMBER(source_version) source_version,product_code
FROM SRC_VEEVA_LIKE_ACTIVITY_PRODUCT WHERE _available_at<=TO_TIMESTAMP_NTZ($AS_OF)
AND REGEXP_LIKE(source_version,'[0-9]+') AND TRY_TO_NUMBER(source_version)>0;
CREATE OR REPLACE TEMP TABLE CONSENT_CANDIDATE AS
SELECT DISTINCT m.provider_key,c.channel,c.status,c.effective_at,c.sequence_no::NUMBER sequence_no
FROM SRC_SALESFORCE_LIKE_CONSENT c JOIN SF_MAP m USING(contact_key)
WHERE c.purpose='COMMERCIAL' AND c.effective_at::TIMESTAMP_NTZ<=TO_TIMESTAMP_NTZ($AS_OF)
AND c._available_at<=TO_TIMESTAMP_NTZ($AS_OF);
EXECUTE IMMEDIATE $$
DECLARE bad EXCEPTION (-20004,'Ambiguous current product or consent'); n NUMBER;
BEGIN
 SELECT COUNT(*) INTO :n FROM (
   SELECT product_code FROM CURRENT_PRODUCT GROUP BY product_code HAVING COUNT(*)>1
   UNION ALL
   SELECT provider_key FROM CONSENT_CANDIDATE GROUP BY provider_key,channel,effective_at,sequence_no HAVING COUNT(DISTINCT status)>1
 );
 IF (n>0) THEN RAISE bad; END IF;
END; $$;
CREATE OR REPLACE TEMP TABLE CURRENT_CONSENT AS
SELECT * FROM CONSENT_CANDIDATE
QUALIFY ROW_NUMBER() OVER(PARTITION BY provider_key,channel ORDER BY effective_at::TIMESTAMP_NTZ DESC,sequence_no DESC)=1;
CREATE OR REPLACE TEMP TABLE GOLD_S01_ENGAGEMENT AS
SELECT a.activity_key,a.provider_key customer_key,LEFT(a.occurred_at,10) activity_date,c.status consent_status
FROM ELIGIBLE a JOIN CURRENT_CONSENT c ON a.provider_key=c.provider_key AND a.channel=c.channel
WHERE c.status='GRANTED';
CREATE OR REPLACE TEMP TABLE GOLD_S02_PRODUCT_ACTIVITY AS
SELECT a.provider_key customer_key,p.product_code,LEFT(a.occurred_at,10) activity_date,
p.brand,p.therapy,COUNT(DISTINCT a.activity_key) interaction_count
FROM ELIGIBLE a JOIN DETAIL d ON a.activity_key=d.activity_key AND a.source_version::NUMBER=d.source_version
JOIN CURRENT_PRODUCT p ON d.product_code=p.product_code WHERE a.provider_key IS NOT NULL
GROUP BY a.provider_key,p.product_code,LEFT(a.occurred_at,10),p.brand,p.therapy;

CREATE OR REPLACE TEMP TABLE TERRITORY_CANDIDATE AS
SELECT DISTINCT provider_key,territory_code,effective_from FROM SRC_MANUAL_TERRITORY_MAPPING
WHERE effective_from::DATE<=TO_DATE(TO_TIMESTAMP_NTZ($AS_OF))
AND (effective_to IS NULL OR TO_DATE(TO_TIMESTAMP_NTZ($AS_OF))<effective_to::DATE)
AND _available_at<=TO_TIMESTAMP_NTZ($AS_OF)
QUALIFY DENSE_RANK() OVER(PARTITION BY provider_key ORDER BY effective_from::DATE DESC)=1;
EXECUTE IMMEDIATE $$
DECLARE bad EXCEPTION (-20005,'Duplicate current or unknown territory'); n NUMBER;
BEGIN
 SELECT COUNT(*) INTO :n FROM (
   SELECT provider_key FROM TERRITORY_CANDIDATE GROUP BY provider_key HAVING COUNT(DISTINCT territory_code)>1
   UNION ALL
   SELECT provider_key FROM TERRITORY_CANDIDATE WHERE territory_code NOT IN (SELECT territory_code FROM SRC_VEEVA_LIKE_TERRITORY)
 );
 IF (n>0) THEN RAISE bad; END IF;
END; $$;
CREATE OR REPLACE TEMP TABLE GOLD_S03_CUSTOMER_TERRITORY AS
SELECT c.provider_key customer_key,COALESCE(t.territory_code,'') territory_code,
IFF(t.territory_code IS NULL,'MISSING','ASSIGNED') assignment_status
FROM APPROVED_CUSTOMER c LEFT JOIN TERRITORY_CANDIDATE t USING(provider_key);

CREATE OR REPLACE TEMP TABLE CAMPAIGN_MEMBER AS
SELECT DISTINCT campaign_key,contact_key FROM SRC_SALESFORCE_LIKE_CAMPAIGN_MEMBER
WHERE member_status='ENROLLED' AND _available_at<=TO_TIMESTAMP_NTZ($AS_OF);
CREATE OR REPLACE TEMP TABLE CAMPAIGN AS
SELECT DISTINCT campaign_key,product_code,start_date,end_date_exclusive,status
FROM SRC_SALESFORCE_LIKE_CAMPAIGN WHERE status<>'CANCELLED' AND _available_at<=TO_TIMESTAMP_NTZ($AS_OF);
CREATE OR REPLACE TEMP TABLE GOLD_S05_CAMPAIGN AS
SELECT c.campaign_key,m.provider_key customer_key,c.product_code,
IFF(COUNT(DISTINCT a.activity_key)>0,'true','false') contacted,
COUNT(DISTINCT a.activity_key) qualifying_interactions
FROM CAMPAIGN c JOIN CAMPAIGN_MEMBER cm USING(campaign_key)
JOIN SF_MAP m USING(contact_key) JOIN CURRENT_PRODUCT p ON c.product_code=p.product_code
LEFT JOIN (
 SELECT e.activity_key,e.provider_key,e.occurred_at,d.product_code FROM ELIGIBLE e
 JOIN DETAIL d ON e.activity_key=d.activity_key AND e.source_version::NUMBER=d.source_version
) a ON a.provider_key=m.provider_key AND a.product_code=c.product_code
 AND LEFT(a.occurred_at,10)>=c.start_date AND LEFT(a.occurred_at,10)<c.end_date_exclusive
GROUP BY c.campaign_key,m.provider_key,c.product_code;

CREATE OR REPLACE TEMP TABLE UNKNOWN_PRODUCT_ACTIVITY AS
SELECT DISTINCT a.activity_key FROM ELIGIBLE a
LEFT JOIN DETAIL d ON a.activity_key=d.activity_key AND a.source_version::NUMBER=d.source_version
LEFT JOIN CURRENT_PRODUCT p ON d.product_code=p.product_code WHERE p.product_code IS NULL;
CREATE OR REPLACE TEMP TABLE GOLD_EXCEPTIONS AS
SELECT DISTINCT 'S04' scenario,activity_key record_key,disposition reason FROM ACTIVITY_CLASSIFIED WHERE disposition<>'ACCEPT'
UNION
SELECT 'S01',activity_key,'UNMATCHED_CUSTOMER' FROM ELIGIBLE WHERE provider_key IS NULL
UNION
SELECT 'S01',a.activity_key,IFF(c.provider_key IS NULL,'MISSING_CONSENT','WITHDRAWN_OR_UNKNOWN_CONSENT')
FROM ELIGIBLE a LEFT JOIN CURRENT_CONSENT c ON a.provider_key=c.provider_key AND a.channel=c.channel
WHERE a.provider_key IS NOT NULL AND (c.provider_key IS NULL OR c.status<>'GRANTED')
UNION
SELECT 'S02',activity_key,'UNKNOWN_PRODUCT' FROM UNKNOWN_PRODUCT_ACTIVITY
UNION
SELECT 'S02',activity_key,'UNMATCHED_CUSTOMER' FROM ELIGIBLE WHERE provider_key IS NULL
UNION
SELECT 'S03',customer_key,'MISSING_TERRITORY' FROM GOLD_S03_CUSTOMER_TERRITORY WHERE assignment_status='MISSING'
UNION
SELECT 'S05',c.campaign_key||'|'||cm.contact_key,'UNMATCHED_MEMBER'
FROM CAMPAIGN c JOIN CAMPAIGN_MEMBER cm USING(campaign_key) LEFT JOIN SF_MAP m USING(contact_key) WHERE m.provider_key IS NULL
UNION
SELECT 'S05',c.campaign_key,'UNKNOWN_PRODUCT' FROM CAMPAIGN c LEFT JOIN CURRENT_PRODUCT p USING(product_code) WHERE p.product_code IS NULL;

CREATE OR REPLACE TEMP TABLE DQ_COUNTS AS
SELECT 'S01' scenario,'ALL' scope,COALESCE(COUNT_IF(provider_key IS NULL),0) numerator,COUNT(*) denominator,0.02::NUMBER(12,6) threshold FROM ELIGIBLE
UNION ALL
SELECT 'S02','ALL',(SELECT COUNT(*) FROM UNKNOWN_PRODUCT_ACTIVITY),COUNT(*),0.01 FROM ELIGIBLE
UNION ALL
SELECT 'S05',c.campaign_key,COALESCE(COUNT_IF(cm.contact_key IS NOT NULL AND m.provider_key IS NULL),0),COUNT(cm.contact_key),0.05
FROM CAMPAIGN c LEFT JOIN CAMPAIGN_MEMBER cm USING(campaign_key) LEFT JOIN SF_MAP m USING(contact_key) GROUP BY c.campaign_key;
CREATE OR REPLACE TEMP TABLE GOLD_DQ AS
SELECT *,CASE WHEN denominator=0 THEN 'NO_DATA' WHEN numerator>denominator*threshold THEN 'ALERT' ELSE 'PASS' END status FROM DQ_COUNTS;

-- Commercial observations are a useful supporting hydration check, not a sixth scenario.
CREATE OR REPLACE TEMP TABLE RX_LATEST AS
SELECT * FROM SRC_IQVIA_LIKE_RX_WEEKLY WHERE _available_at<=TO_TIMESTAMP_NTZ($AS_OF)
QUALIFY ROW_NUMBER() OVER(PARTITION BY observation_key ORDER BY version_no::NUMBER DESC)=1;
-- Export named GOLD_* tables with lowercase headers matching contracts/output-columns.json.
-- Reconcile all seven tables before publishing. Alerts do not imply failed row correctness.

