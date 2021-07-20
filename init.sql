create schema api;
CREATE TABLE api.isolates (Sample VARCHAR, study_accession VARCHAR, collection_date DATE, completed_date DATE, pango_lineage VARCHAR, scorpio_call VARCHAR, POS SMALLINT, REF VARCHAR, ALT VARCHAR, EFFECT VARCHAR, CODON VARCHAR, TRID VARCHAR, AA VARCHAR, AF FLOAT);
COPY api.isolates FROM '/tmp/data.tsv' DELIMITER E'	';


CREATE FUNCTION api.count_pos_during_period(start_collection_date date, end_collection_date date) RETURNS TABLE(collection_date date, count integer) AS $$ 
SELECT
   collection_date,
   COUNT(POS) 
FROM
   api.isolates 
WHERE
   collection_date >= start_collection_date 
   AND collection_date <= end_collection_date 
GROUP BY
   collection_date;
$$ LANGUAGE SQL IMMUTABLE;

CREATE INDEX isolate_sample ON api.isolates(sample);
CREATE INDEX isolate_pos ON api.isolates(pos);
CREATE INDEX isolate_ref ON api.isolates(ref);
CREATE INDEX isolate_alt ON api.isolates(alt);
CREATE INDEX isolate_effect ON api.isolates(effect);
CREATE INDEX isolate_collection_date ON api.isolates(collection_date);
CREATE INDEX isolate_af ON api.isolates(af);

CREATE MATERIALIZED VIEW api.get_distinct_sample AS
  SELECT distinct on(sample) sample, collection_date, pango_lineage, completed_date, scorpio_call FROM api.isolates;
  

CREATE MATERIALIZED VIEW api.get_boundary_dates AS
  SELECT min(collection_date), max(collection_date)  FROM api.isolates;

CREATE OR REPLACE FUNCTION api.average_af(input_POS integer, input_REF varchar, input_ALT varchar, start_collection_date date, end_collection_date date) RETURNS TABLE(collection_date date, AVG FLOAT, count int) AS $$    
SELECT
   collection_date,
   AVG(AF),
   COUNT(POS)
FROM
   api.isolates 
WHERE
   collection_date >= start_collection_date 
   AND collection_date <= end_collection_date 
   AND POS = input_POS 
   AND REF = input_REF 
   AND ALT = input_ALT 
GROUP BY
   collection_date;
$$ LANGUAGE SQL IMMUTABLE;


CREATE OR REPLACE FUNCTION api.get_analyzed_samples(start_collection_date date, end_collection_date date, top_af_threshold float, bottom_af_threshold float, OUT unique_samples_count int, OUT av_per_sample float, OUT top_av_per_sample float, OUT bottom_av_per_sample float, OUT unique_av integer, OUT mean_non_syn float, OUT mean_syn float) AS 
$func$
BEGIN
SELECT COUNT(*) INTO unique_samples_count FROM api.get_distinct_sample WHERE
         collection_date >= start_collection_date 
         AND collection_date <= end_collection_date;
		 
SELECT ROUND(CAST( count(*) / unique_samples_count::float  AS numeric), 2) INTO av_per_sample FROM api.isolates where collection_date >= start_collection_date AND collection_date <= end_collection_date;
SELECT ROUND(CAST( count(*) / unique_samples_count::float  AS numeric), 2) INTO bottom_av_per_sample FROM api.isolates where af <= bottom_af_threshold and collection_date >= start_collection_date AND collection_date <= end_collection_date;
SELECT ROUND(CAST( count(*) / unique_samples_count::float  AS numeric), 2) INTO top_av_per_sample FROM api.isolates where af >= top_af_threshold and collection_date >= start_collection_date AND collection_date <= end_collection_date;
SELECT ROUND(CAST( count(*) / unique_samples_count::float  AS numeric), 2) INTO mean_syn FROM (SELECT effect  from api.isolates where effect = 'SYNONYMOUS_CODING' and collection_date >= start_collection_date AND collection_date <= end_collection_date) as f;
SELECT ROUND(CAST( count(*) / unique_samples_count::float  AS numeric), 2) INTO mean_non_syn FROM (SELECT effect  from api.isolates where effect = 'NON_SYNONYMOUS_CODING' and collection_date >= start_collection_date AND collection_date <= end_collection_date) as f;
SELECT COUNT(*) INTO unique_av FROM(SELECT distinct pos, ref, alt FROM api.isolates WHERE collection_date >= start_collection_date AND collection_date <= end_collection_date) AS f;

END
$func$  LANGUAGE plpgsql IMMUTABLE;

CREATE INDEX isolates_index ON api.isolates(sample, pos, ref, alt, collection_date, af);

CREATE role web_anon nologin;
GRANT SELECT ON ALL TABLES IN SCHEMA api TO web_anon;
GRANT ALL ON ALL functions IN schema api TO web_anon;
GRANT EXECUTE ON ALL functions IN schema api TO web_anon;
GRANT USAGE ON SCHEMA api TO web_anon ;
CREATE role authenticator noinherit login password 'pangolinsecretpassword';
GRANT web_anon TO authenticator;
