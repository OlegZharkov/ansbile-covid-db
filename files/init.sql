create schema api;
CREATE TABLE api.pangolin (Sample VARCHAR, POS VARCHAR, REF VARCHAR, ALT VARCHAR, AF VARCHAR, EFFECT VARCHAR, CODON VARCHAR, TRID VARCHAR, AA VARCHAR);
COPY api.pangolin FROM '/tmp/all_pangolin_reworked.tsv' DELIMITER E'\t';

create role web_anon nologin;
grant usage on schema api to web_anon;
grant select on api.pangolin to web_anon;
create role authenticator noinherit login password 'pangolinsecretpassword';
grant web_anon to authenticator;