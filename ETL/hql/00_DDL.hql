-- =====================================================================================================
-- Livrable 2 - Groupe 2 (Datavengers) - 00_DDL.hql (prérequis des jobs J0 à J8 du groupe)
-- tables Bronze (dépôts Talend sur HDFS), vues silver.v_j1 à v_j8 (règles de nettoyage), tables Silver,
-- Gold (dim_* et fait_*), audit et gold.dual. Les règles des vues reprennent celles du livrable 1.
-- Hive 1.1 (CDH 5.12) : pas de point-virgule dans les commentaires (beeline découpe dessus),
-- le séparateur « point-virgule » des fichiers est écrit '\073' (code octal).
-- Version 1.0
-- =====================================================================================================
-- Mêmes réglages que les jobs du groupe : mémoire des tâches et pas de map join (la tâche locale
-- manque de mémoire sur la VM, erreur MapredLocalTask)
SET mapreduce.map.memory.mb = 1024;
SET mapreduce.map.java.opts = -Xmx820m;
SET mapreduce.reduce.memory.mb = 1024;
SET mapreduce.reduce.java.opts = -Xmx820m;
SET hive.auto.convert.join = false;

CREATE DATABASE IF NOT EXISTS bronze;
CREATE DATABASE IF NOT EXISTS silver;
CREATE DATABASE IF NOT EXISTS gold;
CREATE DATABASE IF NOT EXISTS audit;

-- ============================================ BRONZE ================================================
-- Tables externes : les fichiers sont déposés tels quels par Talend (tHDFSPut / tHDFSOutput) dans un
-- dossier par lot (date_ingestion), aux emplacements utilisés par les jobs Talend du dépôt du groupe.
-- Tout est en texte, rien n'est transformé.

-- Calendrier généré par Talend (tRowGenerator -> tMap -> tHDFSOutput)
CREATE EXTERNAL TABLE IF NOT EXISTS bronze.temps_genere (
  id BIGINT, date_jour STRING, jour_semaine INT, jour INT, semaine INT, mois INT, trimestre INT, semestre INT, annee INT)
ROW FORMAT DELIMITED FIELDS TERMINATED BY '\073'
LOCATION '/datalake/bronze/temps'
TBLPROPERTIES ('skip.header.line.count' = '1');

-- etablissement_sante.csv : guillemets possibles (3 e-mails contiennent le séparateur), donc OpenCSVSerde
CREATE EXTERNAL TABLE IF NOT EXISTS bronze.etablissement_sante (
  adresse STRING, cedex STRING, code_commune STRING, code_postal STRING, commune STRING,
  complement_destinataire STRING, complement_point_geographique STRING, email STRING,
  enseigne_commerciale_site STRING, finess_etablissement_juridique STRING, finess_site STRING,
  identifiant_organisation STRING, indice_repetition_voie STRING, mention_distribution STRING,
  numero_voie STRING, pays STRING, raison_sociale_site STRING, siren_site STRING, siret_site STRING,
  telecopie STRING, telephone STRING, telephone_2 STRING, type_voie STRING, voie STRING)
PARTITIONED BY (date_ingestion STRING)
ROW FORMAT SERDE 'org.apache.hadoop.hive.serde2.OpenCSVSerde'
WITH SERDEPROPERTIES ('separatorChar' = '\073', 'quoteChar' = '"')
LOCATION '/datalake/bronze/etablissements/etablissement_sante'
TBLPROPERTIES ('skip.header.line.count' = '1');

CREATE EXTERNAL TABLE IF NOT EXISTS bronze.ref_departement_region (
  code_departement STRING, nom_departement STRING, region STRING)
PARTITIONED BY (date_ingestion STRING)
ROW FORMAT DELIMITED FIELDS TERMINATED BY '\073'
LOCATION '/datalake/bronze/referentiel/departement_region'
TBLPROPERTIES ('skip.header.line.count' = '1');

-- Base opérationnelle PostgreSQL (tPostgresqlInput -> tHDFSOutput), fichiers tabulés, NULL = \N
CREATE EXTERNAL TABLE IF NOT EXISTS bronze.professionnel_de_sante (
  identifiant STRING, civilite STRING, categorie_professionnelle STRING, nom STRING, prenom STRING,
  profession STRING, type_identifiant STRING, code_specialite STRING)
PARTITIONED BY (date_ingestion STRING)
ROW FORMAT DELIMITED FIELDS TERMINATED BY '\t'
LOCATION '/datalake/bronze/postgres/professionnel_de_sante';

CREATE EXTERNAL TABLE IF NOT EXISTS bronze.specialites (
  code_specialite STRING, fonction STRING, specialite STRING)
PARTITIONED BY (date_ingestion STRING)
ROW FORMAT DELIMITED FIELDS TERMINATED BY '\t'
LOCATION '/datalake/bronze/postgres/specialites';

CREATE EXTERNAL TABLE IF NOT EXISTS bronze.diagnostic (code_diag STRING, diagnostic STRING)
PARTITIONED BY (date_ingestion STRING)
ROW FORMAT DELIMITED FIELDS TERMINATED BY '\t'
LOCATION '/datalake/bronze/postgres/diagnostic';

CREATE EXTERNAL TABLE IF NOT EXISTS bronze.patient (
  id_patient STRING, nom STRING, prenom STRING, sexe STRING, adresse STRING, ville STRING, code_postal STRING,
  pays STRING, email STRING, tel STRING, date_naissance STRING, age STRING, num_secu STRING,
  groupe_sanguin STRING, poids STRING, taille STRING)
PARTITIONED BY (date_ingestion STRING)
ROW FORMAT DELIMITED FIELDS TERMINATED BY '\t'
LOCATION '/datalake/bronze/postgres/patient';

CREATE EXTERNAL TABLE IF NOT EXISTS bronze.consultation (
  num_consultation STRING, id_mut STRING, id_patient STRING, id_prof_sante STRING, code_diag STRING,
  motif STRING, date_consultation STRING, heure_debut STRING, heure_fin STRING)
PARTITIONED BY (date_ingestion STRING)
ROW FORMAT DELIMITED FIELDS TERMINATED BY '\t'
LOCATION '/datalake/bronze/postgres/consultation';

-- Fichiers CSV (tHDFSPut)
CREATE EXTERNAL TABLE IF NOT EXISTS bronze.activite_professionnel_sante (
  identifiant STRING, identifiant_organisation STRING, mode_exercice STRING)
PARTITIONED BY (date_ingestion STRING)
ROW FORMAT DELIMITED FIELDS TERMINATED BY '\073'
LOCATION '/datalake/bronze/etablissements/activite_professionnel_sante'
TBLPROPERTIES ('skip.header.line.count' = '1');

CREATE EXTERNAL TABLE IF NOT EXISTS bronze.hospitalisation (
  num_hospitalisation STRING, id_patient STRING, identifiant_organisation STRING, code_diagnostic STRING,
  suite_diagnostic_consultation STRING, date_entree STRING, jour_hospitalisation STRING)
PARTITIONED BY (date_ingestion STRING)
ROW FORMAT SERDE 'org.apache.hadoop.hive.serde2.OpenCSVSerde'
WITH SERDEPROPERTIES ('separatorChar' = '\073', 'quoteChar' = '"')
LOCATION '/datalake/bronze/hospitalisations'
TBLPROPERTIES ('skip.header.line.count' = '1');

-- deces.csv : 25 millions de lignes, environ 74 000 contiennent une virgule entre guillemets
CREATE EXTERNAL TABLE IF NOT EXISTS bronze.deces (
  nom STRING, prenom STRING, sexe STRING, date_naissance STRING, code_lieu_naissance STRING,
  lieu_naissance STRING, pays_naissance STRING, date_deces STRING, code_lieu_deces STRING, numero_acte_deces STRING)
PARTITIONED BY (date_ingestion STRING)
ROW FORMAT SERDE 'org.apache.hadoop.hive.serde2.OpenCSVSerde'
WITH SERDEPROPERTIES ('separatorChar' = ',', 'quoteChar' = '"')
LOCATION '/datalake/bronze/deces'
TBLPROPERTIES ('skip.header.line.count' = '1');

-- e-Satis 48h MCO : même structure en 2019 (CSV) et 2020 (xlsx lu par tFileInputExcel)
CREATE EXTERNAL TABLE IF NOT EXISTS bronze.esatis_csv (
  finess STRING, rs_finess STRING, finess_geo STRING, rs_finess_geo STRING, region STRING, participation STRING,
  depot STRING, nb_rep_score_all_rea_ajust STRING, score_all_rea_ajust STRING, classement STRING, evolution STRING,
  nb_rep_score_accueil_rea_ajust STRING, score_accueil_rea_ajust STRING, nb_rep_score_pecinf_rea_ajust STRING,
  score_pecinf_rea_ajust STRING, nb_rep_score_pecmed_rea_ajust STRING, score_pecmed_rea_ajust STRING,
  nb_rep_score_chambre_rea_ajust STRING, score_chambre_rea_ajust STRING, nb_rep_score_repas_rea_ajust STRING,
  score_repas_rea_ajust STRING, nb_rep_score_sortie_rea_ajust STRING, score_sortie_rea_ajust STRING,
  taux_reco_brut STRING, nb_reco_brut STRING)
PARTITIONED BY (date_ingestion STRING, annee INT)
ROW FORMAT SERDE 'org.apache.hadoop.hive.serde2.OpenCSVSerde'
WITH SERDEPROPERTIES ('separatorChar' = '\073', 'quoteChar' = '"')
LOCATION '/datalake/bronze/satisfaction/esatis_csv'
TBLPROPERTIES ('skip.header.line.count' = '1');

CREATE EXTERNAL TABLE IF NOT EXISTS bronze.esatis_xlsx LIKE bronze.esatis_csv
LOCATION '/datalake/bronze/satisfaction/esatis_xlsx';

-- ============================================ SILVER ================================================
-- Tables ORC (format colonne compressé), alimentées par INSERT OVERWRITE dans les jobs J1 à J8.
CREATE TABLE IF NOT EXISTS silver.ref_departement (code_departement STRING, nom_departement STRING, region STRING)
STORED AS ORC;

CREATE TABLE IF NOT EXISTS silver.etablissement (
  identifiant_organisation STRING, type_organisation STRING, finess_site STRING, finess_juridique STRING,
  raison_sociale STRING, code_commune STRING, commune STRING, code_postal STRING, code_departement STRING)
STORED AS ORC;

CREATE TABLE IF NOT EXISTS silver.professionnel (
  identifiant STRING, type_identifiant STRING, categorie_professionnelle STRING, profession STRING,
  code_specialite STRING, specialite STRING, etablissement_code STRING)
STORED AS ORC;

CREATE TABLE IF NOT EXISTS silver.diagnostic (code_diag STRING, libelle STRING) STORED AS ORC;

CREATE TABLE IF NOT EXISTS silver.patient (
  id_patient_hash STRING, sexe STRING, date_naissance STRING, code_postal STRING, code_departement STRING)
STORED AS ORC;

CREATE TABLE IF NOT EXISTS silver.consultation (
  num_consultation BIGINT, id_patient_hash STRING, id_prof_sante STRING, code_diag STRING, motif STRING,
  date_consultation STRING, duree_min INT, etablissement_code STRING, sexe STRING, age INT)
PARTITIONED BY (annee INT) STORED AS ORC;

CREATE TABLE IF NOT EXISTS silver.hospitalisation (
  num_hospitalisation BIGINT, id_patient_hash STRING, etablissement_code STRING, code_diag STRING,
  date_entree STRING, duree_jours INT, sexe STRING, age INT)
PARTITIONED BY (annee INT) STORED AS ORC;

CREATE TABLE IF NOT EXISTS silver.deces (
  sexe STRING, date_naissance STRING, date_deces STRING, code_lieu_deces STRING, code_departement STRING, age INT)
PARTITIONED BY (annee INT) STORED AS ORC;

CREATE TABLE IF NOT EXISTS silver.satisfaction (
  identifiant_organisation STRING, finess_juridique STRING, type_score STRING, score DOUBLE, nb_reponses INT)
PARTITIONED BY (annee INT) STORED AS ORC;

-- Lignes écartées, avec leur motif (une partition par job et par lot)
CREATE TABLE IF NOT EXISTS silver.rejets (source STRING, cle STRING, motif STRING, ligne STRING)
PARTITIONED BY (job STRING, date_lot STRING) STORED AS ORC;

-- ---------------------------------- Vues de nettoyage (règles J1 à J8) ----------------------------------
-- Département : 3 caractères pour les DOM (97x), 2A / 2B pour la Corse (20000 à 20199 = 2A), sinon 2.
-- La colonne rang (ROW_NUMBER) vaut 1 pour la première occurrence de la clé métier : rang > 1 = doublon.

CREATE OR REPLACE VIEW silver.v_j1_etablissement AS
SELECT identifiant_organisation, finess_site, finess_juridique, raison_sociale, code_commune, commune, code_postal,
       code_departement, date_ingestion,
       row_number() OVER (PARTITION BY date_ingestion, identifiant_organisation ORDER BY raison_sociale) AS rang
FROM (
  SELECT CASE WHEN trim(identifiant_organisation) <> '' THEN trim(identifiant_organisation) END AS identifiant_organisation,
         CASE WHEN trim(finess_site) <> '' THEN trim(finess_site) END AS finess_site,
         CASE WHEN trim(finess_etablissement_juridique) <> '' THEN trim(finess_etablissement_juridique) END AS finess_juridique,
         CASE WHEN trim(raison_sociale_site) <> '' THEN trim(raison_sociale_site) END AS raison_sociale,
         CASE WHEN trim(code_commune) <> '' THEN trim(code_commune) END AS code_commune,
         CASE WHEN trim(commune) <> '' THEN trim(commune) END AS commune,
         CASE WHEN trim(code_postal) <> '' THEN trim(code_postal) END AS code_postal,
         CASE WHEN trim(code_commune) RLIKE '^97' THEN substr(trim(code_commune), 1, 3)
              WHEN trim(code_commune) RLIKE '^2[AB]' THEN substr(trim(code_commune), 1, 2)
              WHEN trim(code_commune) RLIKE '^[0-9]{5}$' THEN substr(trim(code_commune), 1, 2)
              WHEN trim(code_postal) RLIKE '^97' THEN substr(trim(code_postal), 1, 3)
              WHEN trim(code_postal) RLIKE '^20[01]' THEN '2A'
              WHEN trim(code_postal) RLIKE '^20' THEN '2B'
              WHEN trim(code_postal) RLIKE '^[0-9]{5}$' THEN substr(trim(code_postal), 1, 2) END AS code_departement,
         date_ingestion
  FROM bronze.etablissement_sante) e;

-- Professionnels : les numéros ADELI ont perdu leur 0 initial dans la base source (8 chiffres au lieu de 9)
CREATE OR REPLACE VIEW silver.v_j2_professionnel AS
SELECT identifiant, type_identifiant, categorie_professionnelle, profession, code_specialite, date_ingestion,
       row_number() OVER (PARTITION BY date_ingestion, identifiant ORDER BY identifiant_source) AS rang
FROM (
  SELECT CASE WHEN type_identifiant = 'ADELI' AND identifiant RLIKE '^[0-9]{8}$' THEN concat('0', identifiant)
              WHEN trim(identifiant) <> '' THEN trim(identifiant) END AS identifiant,
         identifiant AS identifiant_source, type_identifiant, categorie_professionnelle, profession,
         CASE WHEN trim(code_specialite) <> '' THEN trim(code_specialite) END AS code_specialite, date_ingestion
  FROM bronze.professionnel_de_sante) p;

-- Rattachement : un professionnel peut exercer dans plusieurs organisations connues du référentiel.
-- On garde en priorité un établissement de santé (code F), sinon la première par ordre alphabétique.
CREATE OR REPLACE VIEW silver.v_j2_rattachement AS
SELECT identifiant, etablissement_code, date_ingestion
FROM (
  SELECT a.identifiant, a.identifiant_organisation AS etablissement_code, a.date_ingestion,
         row_number() OVER (PARTITION BY a.date_ingestion, a.identifiant
                            ORDER BY CASE WHEN substr(a.identifiant_organisation, 1, 1) = 'F' THEN 0 ELSE 1 END,
                                     a.identifiant_organisation) AS rn
  FROM bronze.activite_professionnel_sante a
  JOIN silver.etablissement e ON e.identifiant_organisation = a.identifiant_organisation) r
WHERE rn = 1;

CREATE OR REPLACE VIEW silver.v_j3_diagnostic AS
SELECT code_diag, libelle, date_ingestion,
       row_number() OVER (PARTITION BY date_ingestion, code_diag ORDER BY libelle) AS rang
FROM (
  SELECT CASE WHEN trim(code_diag) <> '' THEN trim(code_diag) END AS code_diag,
         CASE WHEN trim(diagnostic) <> '' THEN trim(diagnostic) END AS libelle, date_ingestion
  FROM bronze.diagnostic) d;

-- Patients : date de naissance au format américain M/d/yyyy (ex. 7/25/2013), convertie en yyyy-MM-dd.
-- Les colonnes identifiantes (nom, adresse, n° de sécurité sociale...) ne sortent pas de la Bronze.
CREATE OR REPLACE VIEW silver.v_j4_patient AS
SELECT id_patient, sexe, date_naissance, code_postal, date_ingestion,
       row_number() OVER (PARTITION BY date_ingestion, id_patient ORDER BY date_naissance) AS rang
FROM (
  SELECT CASE WHEN trim(id_patient) <> '' THEN trim(id_patient) END AS id_patient,
         trim(sexe) AS sexe,
         CASE WHEN date_naissance RLIKE '^[0-9]{1,2}/[0-9]{1,2}/[0-9]{4}$'
               AND CAST(split(date_naissance, '/')[0] AS INT) BETWEEN 1 AND 12
               AND CAST(split(date_naissance, '/')[1] AS INT) BETWEEN 1 AND 31
              THEN from_unixtime(unix_timestamp(date_naissance, 'M/d/yyyy'), 'yyyy-MM-dd') END AS date_naissance,
         CASE WHEN trim(code_postal) <> '' THEN trim(code_postal) END AS code_postal, date_ingestion
  FROM bronze.patient) p;

-- Consultations : durée en minutes = fin - début, + 24 h pour une consultation de nuit (fin avant début)
CREATE OR REPLACE VIEW silver.v_j5_consultation AS
SELECT num_consultation, id_patient, id_prof_sante, code_diag, motif, date_consultation, duree_min, date_ingestion,
       row_number() OVER (PARTITION BY date_ingestion, num_consultation ORDER BY date_consultation) AS rang
FROM (
  SELECT CAST(num_consultation AS BIGINT) AS num_consultation,
         CASE WHEN trim(id_patient) <> '' THEN trim(id_patient) END AS id_patient,
         CASE WHEN trim(id_prof_sante) <> '' THEN trim(id_prof_sante) END AS id_prof_sante,
         CASE WHEN trim(code_diag) <> '' THEN trim(code_diag) END AS code_diag,
         motif,
         CASE WHEN date_consultation RLIKE '^[0-9]{4}-[0-9]{2}-[0-9]{2}$'
               AND to_date(date_consultation) = date_consultation THEN date_consultation END AS date_consultation,
         CASE WHEN heure_debut RLIKE '^[0-9]{2}:[0-9]{2}(:[0-9]{2})?$' AND heure_fin RLIKE '^[0-9]{2}:[0-9]{2}(:[0-9]{2})?$'
              THEN CAST(((unix_timestamp(concat('1970-01-02 ', heure_fin), 'yyyy-MM-dd HH:mm')
                        - unix_timestamp(concat('1970-01-02 ', heure_debut), 'yyyy-MM-dd HH:mm')) / 60 + 1440) % 1440 AS INT)
         END AS duree_min,
         date_ingestion
  FROM bronze.consultation) c;

-- Hospitalisations : date d'entrée au format dd/MM/yyyy, durée en jours
CREATE OR REPLACE VIEW silver.v_j6_hospitalisation AS
SELECT num_hospitalisation, id_patient, etablissement_code, code_diag, date_entree, duree_jours, date_ingestion,
       row_number() OVER (PARTITION BY date_ingestion, num_hospitalisation ORDER BY date_entree) AS rang
FROM (
  SELECT CAST(num_hospitalisation AS BIGINT) AS num_hospitalisation,
         CASE WHEN trim(id_patient) <> '' THEN trim(id_patient) END AS id_patient,
         CASE WHEN trim(identifiant_organisation) <> '' THEN trim(identifiant_organisation) END AS etablissement_code,
         CASE WHEN trim(code_diagnostic) <> '' THEN trim(code_diagnostic) END AS code_diag,
         CASE WHEN date_entree RLIKE '^[0-9]{2}/[0-9]{2}/[0-9]{4}$'
               AND from_unixtime(unix_timestamp(date_entree, 'dd/MM/yyyy'), 'dd/MM/yyyy') = date_entree
              THEN from_unixtime(unix_timestamp(date_entree, 'dd/MM/yyyy'), 'yyyy-MM-dd') END AS date_entree,
         CAST(jour_hospitalisation AS INT) AS duree_jours,
         date_ingestion
  FROM bronze.hospitalisation) h;

-- Décès : une date est valide si elle existe dans le calendrier (to_date la recalcule à l'identique).
-- annee_brute sert à ne garder que 2014 et après avant le dédoublonnage (fait dans J7).
CREATE OR REPLACE VIEW silver.v_j7_deces AS
SELECT nom, prenom, trim(sexe) AS sexe, date_naissance,
       CASE WHEN date_deces RLIKE '^[0-9]{4}-[0-9]{2}-[0-9]{2}$' AND to_date(date_deces) = date_deces
            THEN date_deces END AS date_deces,
       CASE WHEN trim(code_lieu_deces) <> '' THEN trim(code_lieu_deces) END AS code_lieu_deces,
       numero_acte_deces, CAST(substr(date_deces, 1, 4) AS INT) AS annee_brute, date_ingestion
FROM bronze.deces;

-- Satisfaction : les 8 scores passent en lignes (tSplitRow dans Talend), chacun avec son nombre de réponses.
-- Jointure au référentiel sur "F" + finess_geo. Les fichiers mélangent virgule et point décimaux.
CREATE OR REPLACE VIEW silver.v_j8_satisfaction AS
SELECT concat('F', s.finess_geo) AS identifiant_organisation, s.finess AS finess_juridique, x.v.t AS type_score,
       CAST(regexp_replace(x.v.s, ',', '.') AS DOUBLE) AS score,
       CAST(regexp_replace(x.v.n, '[.,]0+$', '') AS INT) AS nb_reponses,
       s.annee, s.date_ingestion
FROM (SELECT * FROM bronze.esatis_csv UNION ALL SELECT * FROM bronze.esatis_xlsx) s
LATERAL VIEW explode(array(
  named_struct('t', 'Score global', 's', s.score_all_rea_ajust, 'n', s.nb_rep_score_all_rea_ajust),
  named_struct('t', 'Accueil', 's', s.score_accueil_rea_ajust, 'n', s.nb_rep_score_accueil_rea_ajust),
  named_struct('t', 'Prise en charge infirmiere', 's', s.score_pecinf_rea_ajust, 'n', s.nb_rep_score_pecinf_rea_ajust),
  named_struct('t', 'Prise en charge medicale', 's', s.score_pecmed_rea_ajust, 'n', s.nb_rep_score_pecmed_rea_ajust),
  named_struct('t', 'Chambre', 's', s.score_chambre_rea_ajust, 'n', s.nb_rep_score_chambre_rea_ajust),
  named_struct('t', 'Repas', 's', s.score_repas_rea_ajust, 'n', s.nb_rep_score_repas_rea_ajust),
  named_struct('t', 'Sortie', 's', s.score_sortie_rea_ajust, 'n', s.nb_rep_score_sortie_rea_ajust),
  named_struct('t', 'Taux de recommandation', 's', s.taux_reco_brut, 'n', s.nb_reco_brut))) x AS v;

-- ============================================= GOLD =================================================
-- Modèle en constellation du livrable 1 (noms du groupe : dim_* et fait_*), Parquet.
-- Les faits datés sont partitionnés par année (version du groupe). Clé Temps : yyyyMMdd.
CREATE TABLE IF NOT EXISTS gold.dual (x STRING) STORED AS PARQUET;

CREATE TABLE IF NOT EXISTS gold.dim_temps (
  id BIGINT, date_jour STRING, jour_semaine INT, jour INT, semaine INT, mois INT, trimestre INT, semestre INT, annee INT)
STORED AS PARQUET;
CREATE TABLE IF NOT EXISTS gold.dim_localisation (
  id INT, code_commune STRING, commune STRING, code_departement STRING, departement STRING, region STRING)
STORED AS PARQUET;
CREATE TABLE IF NOT EXISTS gold.dim_etablissement (id INT, code STRING, finess STRING, nom STRING, localisation_id INT)
STORED AS PARQUET;
CREATE TABLE IF NOT EXISTS gold.dim_professionnel (
  id INT, identifiant STRING, categorie_professionnelle STRING, profession STRING, specialite STRING, etablissement_id INT)
STORED AS PARQUET;
CREATE TABLE IF NOT EXISTS gold.dim_diagnostic (id INT, code STRING, nom STRING) STORED AS PARQUET;
-- Patient anonyme : id = 1000 + âge (M), 2000 + âge (F), 3000 + âge (inconnu), -1 = non renseigné
CREATE TABLE IF NOT EXISTS gold.dim_patient (id INT, sexe STRING, age INT) STORED AS PARQUET;
CREATE TABLE IF NOT EXISTS gold.dim_type_satisfaction (id INT, code STRING) STORED AS PARQUET;

CREATE TABLE IF NOT EXISTS gold.fait_population_patient (patient_id INT, annee INT, nombre INT) STORED AS PARQUET;
CREATE TABLE IF NOT EXISTS gold.fait_consultation_etablissement (etablissement_id INT, temps_id BIGINT, nombre INT, duree_totale BIGINT)
PARTITIONED BY (annee INT) STORED AS PARQUET;
CREATE TABLE IF NOT EXISTS gold.fait_consultation_diagnostic (diagnostic_id INT, temps_id BIGINT, nombre INT, duree_totale BIGINT)
PARTITIONED BY (annee INT) STORED AS PARQUET;
CREATE TABLE IF NOT EXISTS gold.fait_consultation_professionnel (professionnel_id INT, temps_id BIGINT, nombre INT, duree_totale BIGINT)
PARTITIONED BY (annee INT) STORED AS PARQUET;
CREATE TABLE IF NOT EXISTS gold.fait_hospitalisation_globale (temps_id BIGINT, nombre INT, duree_totale INT, duree_moyenne DOUBLE)
PARTITIONED BY (annee INT) STORED AS PARQUET;
CREATE TABLE IF NOT EXISTS gold.fait_hospitalisation_diagnostic (diagnostic_id INT, temps_id BIGINT, nombre INT, duree_totale INT)
PARTITIONED BY (annee INT) STORED AS PARQUET;
CREATE TABLE IF NOT EXISTS gold.fait_hospitalisation_patient (patient_id INT, temps_id BIGINT, nombre INT, duree_totale INT)
PARTITIONED BY (annee INT) STORED AS PARQUET;
CREATE TABLE IF NOT EXISTS gold.fait_hospitalisation_etablissement (etablissement_id INT, temps_id BIGINT, nombre INT, duree_totale INT)
PARTITIONED BY (annee INT) STORED AS PARQUET;
CREATE TABLE IF NOT EXISTS gold.fait_deces (localisation_id INT, temps_id BIGINT, nombre INT)
PARTITIONED BY (annee INT) STORED AS PARQUET;
CREATE TABLE IF NOT EXISTS gold.fait_satisfaction (localisation_id INT, type_id INT, temps_id BIGINT, satisfaction DOUBLE, nb_reponses INT)
PARTITIONED BY (annee INT) STORED AS PARQUET;

-- Tables fixes : ligne unique de gold.dual, types de satisfaction, patients anonymes (sexe x âge 0 à 120)
INSERT OVERWRITE TABLE gold.dual SELECT 'x' FROM bronze.temps_genere WHERE id = 20140101;
INSERT OVERWRITE TABLE gold.dim_type_satisfaction
SELECT CAST(pos + 1 AS INT), t FROM gold.dual
LATERAL VIEW posexplode(array('Score global', 'Accueil', 'Prise en charge infirmiere', 'Prise en charge medicale',
                              'Chambre', 'Repas', 'Sortie', 'Taux de recommandation')) a AS pos, t;
INSERT OVERWRITE TABLE gold.dim_patient
SELECT CAST(s.base + a.pos AS INT), s.sexe, CAST(a.pos AS INT)
FROM (SELECT sexe, base FROM gold.dual LATERAL VIEW inline(array(named_struct('sexe', 'M', 'base', 1000),
        named_struct('sexe', 'F', 'base', 2000), named_struct('sexe', 'I', 'base', 3000))) z AS sexe, base) s
CROSS JOIN (SELECT pos FROM gold.dual LATERAL VIEW posexplode(split(space(120), ' ')) p AS pos, v) a;
INSERT INTO TABLE gold.dim_patient SELECT -1, 'NR', CAST(NULL AS INT) FROM gold.dual;

-- ============================================= AUDIT ================================================
CREATE TABLE IF NOT EXISTS audit.journal_chargements (
  job STRING, date_lot STRING, horodatage STRING, lignes_bronze BIGINT, lignes_silver BIGINT,
  lignes_rejetees BIGINT, lignes_gold BIGINT, statut STRING)
STORED AS ORC;
