-- =====================================================================================================
-- Livrable 2 - Groupe 2 - 01_gold_brut_grp.sql (Impala)
-- Base de comparaison « avant optimisation » : mêmes tables que gold, en Parquet, mais sans partition.
-- L'année reste une colonne ordinaire, les requêtes du benchmark sont donc identiques.
-- Lancement : impala-shell -f 01_gold_brut_grp.sql
-- =====================================================================================================
INVALIDATE METADATA;
DROP DATABASE IF EXISTS gold_brut_grp CASCADE;
CREATE DATABASE gold_brut_grp;
CREATE TABLE gold_brut_grp.dim_temps STORED AS PARQUET AS SELECT * FROM gold.dim_temps;
CREATE TABLE gold_brut_grp.dim_localisation STORED AS PARQUET AS SELECT * FROM gold.dim_localisation;
CREATE TABLE gold_brut_grp.dim_etablissement STORED AS PARQUET AS SELECT * FROM gold.dim_etablissement;
CREATE TABLE gold_brut_grp.dim_professionnel STORED AS PARQUET AS SELECT * FROM gold.dim_professionnel;
CREATE TABLE gold_brut_grp.dim_patient STORED AS PARQUET AS SELECT * FROM gold.dim_patient;
CREATE TABLE gold_brut_grp.dim_diagnostic STORED AS PARQUET AS SELECT * FROM gold.dim_diagnostic;
CREATE TABLE gold_brut_grp.dim_type_satisfaction STORED AS PARQUET AS SELECT * FROM gold.dim_type_satisfaction;
CREATE TABLE gold_brut_grp.fait_population_patient STORED AS PARQUET AS SELECT * FROM gold.fait_population_patient;
CREATE TABLE gold_brut_grp.fait_consultation_etablissement STORED AS PARQUET AS SELECT * FROM gold.fait_consultation_etablissement;
CREATE TABLE gold_brut_grp.fait_consultation_diagnostic STORED AS PARQUET AS SELECT * FROM gold.fait_consultation_diagnostic;
CREATE TABLE gold_brut_grp.fait_consultation_professionnel STORED AS PARQUET AS SELECT * FROM gold.fait_consultation_professionnel;
CREATE TABLE gold_brut_grp.fait_hospitalisation_globale STORED AS PARQUET AS SELECT * FROM gold.fait_hospitalisation_globale;
CREATE TABLE gold_brut_grp.fait_hospitalisation_diagnostic STORED AS PARQUET AS SELECT * FROM gold.fait_hospitalisation_diagnostic;
CREATE TABLE gold_brut_grp.fait_hospitalisation_patient STORED AS PARQUET AS SELECT * FROM gold.fait_hospitalisation_patient;
CREATE TABLE gold_brut_grp.fait_hospitalisation_etablissement STORED AS PARQUET AS SELECT * FROM gold.fait_hospitalisation_etablissement;
CREATE TABLE gold_brut_grp.fait_deces STORED AS PARQUET AS SELECT * FROM gold.fait_deces;
CREATE TABLE gold_brut_grp.fait_satisfaction STORED AS PARQUET AS SELECT * FROM gold.fait_satisfaction;
