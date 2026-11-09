-- =====================================================================================================
-- Livrable 2 - Groupe 2 - 02_gold_opt_buckets.hql (Hive)
-- Version « gold_opt » du PDF du groupe : partitions par année + buckets (CLUSTERED BY ... SORTED BY)
-- sur les tables jointes par identifiant. Noms de tables du groupe (dim_* / fait_*).
-- Lancement : hive -f 02_gold_opt_buckets.hql
-- =====================================================================================================
SET mapreduce.map.memory.mb = 1024;
SET mapreduce.map.java.opts = -Xmx820m;
SET mapreduce.reduce.memory.mb = 1024;
SET mapreduce.reduce.java.opts = -Xmx820m;
SET hive.auto.convert.join = false;
SET hive.exec.dynamic.partition = true;
SET hive.exec.dynamic.partition.mode = nonstrict;
SET hive.enforce.bucketing = true;
SET hive.enforce.sorting = true;

DROP DATABASE IF EXISTS gold_opt CASCADE;
CREATE DATABASE gold_opt;

-- Dimensions : buckets sur la clé des trois plus grandes (localisation 4, établissement 4, professionnel 8)
CREATE TABLE gold_opt.dim_temps STORED AS PARQUET AS SELECT * FROM gold.dim_temps;
CREATE TABLE gold_opt.dim_patient STORED AS PARQUET AS SELECT * FROM gold.dim_patient;
CREATE TABLE gold_opt.dim_diagnostic STORED AS PARQUET AS SELECT * FROM gold.dim_diagnostic;
CREATE TABLE gold_opt.dim_type_satisfaction STORED AS PARQUET AS SELECT * FROM gold.dim_type_satisfaction;
CREATE TABLE gold_opt.fait_population_patient STORED AS PARQUET AS SELECT * FROM gold.fait_population_patient;

CREATE TABLE gold_opt.dim_localisation (id INT, code_commune STRING, commune STRING, code_departement STRING, departement STRING, region STRING)
CLUSTERED BY (id) SORTED BY (id) INTO 4 BUCKETS STORED AS PARQUET;
INSERT OVERWRITE TABLE gold_opt.dim_localisation SELECT * FROM gold.dim_localisation;

CREATE TABLE gold_opt.dim_etablissement (id INT, code STRING, finess STRING, nom STRING, localisation_id INT)
CLUSTERED BY (id) SORTED BY (id) INTO 4 BUCKETS STORED AS PARQUET;
INSERT OVERWRITE TABLE gold_opt.dim_etablissement SELECT * FROM gold.dim_etablissement;

CREATE TABLE gold_opt.dim_professionnel (id INT, identifiant STRING, categorie_professionnelle STRING, profession STRING, specialite STRING, etablissement_id INT)
CLUSTERED BY (id) SORTED BY (id) INTO 8 BUCKETS STORED AS PARQUET;
INSERT OVERWRITE TABLE gold_opt.dim_professionnel SELECT * FROM gold.dim_professionnel;

-- Faits : partition par année, buckets sur la clé de jointure principale
CREATE TABLE gold_opt.fait_consultation_etablissement (etablissement_id INT, temps_id BIGINT, nombre INT, duree_totale BIGINT)
PARTITIONED BY (annee INT) CLUSTERED BY (etablissement_id) SORTED BY (etablissement_id) INTO 4 BUCKETS STORED AS PARQUET;
INSERT OVERWRITE TABLE gold_opt.fait_consultation_etablissement PARTITION (annee)
SELECT etablissement_id, temps_id, nombre, duree_totale, annee FROM gold.fait_consultation_etablissement;

-- Consultation par professionnel : pas de partition dans le PDF, 8 buckets (l'année reste une colonne)
CREATE TABLE gold_opt.fait_consultation_professionnel (professionnel_id INT, temps_id BIGINT, nombre INT, duree_totale BIGINT, annee INT)
CLUSTERED BY (professionnel_id) SORTED BY (professionnel_id) INTO 8 BUCKETS STORED AS PARQUET;
INSERT OVERWRITE TABLE gold_opt.fait_consultation_professionnel
SELECT professionnel_id, temps_id, nombre, duree_totale, annee FROM gold.fait_consultation_professionnel;

CREATE TABLE gold_opt.fait_deces (localisation_id INT, temps_id BIGINT, nombre INT)
PARTITIONED BY (annee INT) CLUSTERED BY (localisation_id) SORTED BY (localisation_id) INTO 4 BUCKETS STORED AS PARQUET;
INSERT OVERWRITE TABLE gold_opt.fait_deces PARTITION (annee)
SELECT localisation_id, temps_id, nombre, annee FROM gold.fait_deces;

-- Autres faits : partition par année seulement (comme gold)
CREATE TABLE gold_opt.fait_consultation_diagnostic LIKE gold.fait_consultation_diagnostic;
INSERT OVERWRITE TABLE gold_opt.fait_consultation_diagnostic PARTITION (annee) SELECT * FROM gold.fait_consultation_diagnostic;
CREATE TABLE gold_opt.fait_hospitalisation_globale LIKE gold.fait_hospitalisation_globale;
INSERT OVERWRITE TABLE gold_opt.fait_hospitalisation_globale PARTITION (annee) SELECT * FROM gold.fait_hospitalisation_globale;
CREATE TABLE gold_opt.fait_hospitalisation_diagnostic LIKE gold.fait_hospitalisation_diagnostic;
INSERT OVERWRITE TABLE gold_opt.fait_hospitalisation_diagnostic PARTITION (annee) SELECT * FROM gold.fait_hospitalisation_diagnostic;
CREATE TABLE gold_opt.fait_hospitalisation_patient LIKE gold.fait_hospitalisation_patient;
INSERT OVERWRITE TABLE gold_opt.fait_hospitalisation_patient PARTITION (annee) SELECT * FROM gold.fait_hospitalisation_patient;
CREATE TABLE gold_opt.fait_hospitalisation_etablissement LIKE gold.fait_hospitalisation_etablissement;
INSERT OVERWRITE TABLE gold_opt.fait_hospitalisation_etablissement PARTITION (annee) SELECT * FROM gold.fait_hospitalisation_etablissement;
CREATE TABLE gold_opt.fait_satisfaction LIKE gold.fait_satisfaction;
INSERT OVERWRITE TABLE gold_opt.fait_satisfaction PARTITION (annee) SELECT * FROM gold.fait_satisfaction;
