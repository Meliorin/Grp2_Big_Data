SET mapreduce.map.memory.mb = 1024;
SET mapreduce.map.java.opts = -Xmx820m;
SET mapreduce.reduce.memory.mb = 1024;
SET mapreduce.reduce.java.opts = -Xmx820m;
SET hive.auto.convert.join = false;
INSERT INTO TABLE qualite_groupe.completude
SELECT 'silver', 'patient', s.colonne, x.lignes, s.n
FROM (SELECT count(*) AS lignes, count(CASE WHEN id_patient_hash IS NOT NULL AND trim(CAST(id_patient_hash AS STRING)) <> '' THEN 1 END) AS c0,
             count(CASE WHEN sexe IS NOT NULL AND trim(CAST(sexe AS STRING)) <> '' THEN 1 END) AS c1,
             count(CASE WHEN date_naissance IS NOT NULL AND trim(CAST(date_naissance AS STRING)) <> '' THEN 1 END) AS c2,
             count(CASE WHEN code_postal IS NOT NULL AND trim(CAST(code_postal AS STRING)) <> '' THEN 1 END) AS c3,
             count(CASE WHEN code_departement IS NOT NULL AND trim(CAST(code_departement AS STRING)) <> '' THEN 1 END) AS c4
      FROM silver.patient) x
LATERAL VIEW stack(5, 'id_patient_hash', c0, 'sexe', c1, 'date_naissance', c2, 'code_postal', c3, 'code_departement', c4) s AS colonne, n;
INSERT INTO TABLE qualite_groupe.completude
SELECT 'silver', 'deces', s.colonne, x.lignes, s.n
FROM (SELECT count(*) AS lignes, count(CASE WHEN sexe IS NOT NULL AND trim(CAST(sexe AS STRING)) <> '' THEN 1 END) AS c0,
             count(CASE WHEN date_naissance IS NOT NULL AND trim(CAST(date_naissance AS STRING)) <> '' THEN 1 END) AS c1,
             count(CASE WHEN date_deces IS NOT NULL AND trim(CAST(date_deces AS STRING)) <> '' THEN 1 END) AS c2,
             count(CASE WHEN code_lieu_deces IS NOT NULL AND trim(CAST(code_lieu_deces AS STRING)) <> '' THEN 1 END) AS c3,
             count(CASE WHEN code_departement IS NOT NULL AND trim(CAST(code_departement AS STRING)) <> '' THEN 1 END) AS c4,
             count(CASE WHEN age IS NOT NULL AND trim(CAST(age AS STRING)) <> '' THEN 1 END) AS c5
      FROM silver.deces) x
LATERAL VIEW stack(6, 'sexe', c0, 'date_naissance', c1, 'date_deces', c2, 'code_lieu_deces', c3, 'code_departement', c4, 'age', c5) s AS colonne, n;
-- Décès : lieu retrouvé au niveau commune (établissements) ou département, sinon -1 « Non renseigné »
INSERT INTO TABLE qualite_groupe.coherence
SELECT 'Deces : lieu retrouve dans dim_localisation (hors -1)', 'gold.fait_deces',
       sum(nombre), sum(CASE WHEN localisation_id <> -1 THEN nombre ELSE 0 END)
FROM gold.fait_deces;
INSERT INTO TABLE qualite_groupe.coherence
SELECT 'Deces : departement dans le referentiel', 'silver.deces', count(*), count(r.code_departement)
FROM silver.deces d LEFT JOIN silver.ref_departement r ON r.code_departement = d.code_departement;
CREATE TABLE qualite_groupe.orphelins (fait STRING, cle STRING, lignes BIGINT, orphelines BIGINT);
INSERT INTO TABLE qualite_groupe.orphelins
SELECT 'fait_deces', 'localisation_id', count(*), count(CASE WHEN d.id IS NULL THEN 1 END)
FROM gold.fait_deces f LEFT JOIN gold.dim_localisation d ON d.id = f.localisation_id
UNION ALL
SELECT 'fait_deces', 'temps_id', count(*), count(CASE WHEN d.id IS NULL THEN 1 END)
FROM gold.fait_deces f LEFT JOIN gold.dim_temps d ON d.id = f.temps_id
UNION ALL
SELECT 'fait_satisfaction', 'localisation_id', count(*), count(CASE WHEN d.id IS NULL THEN 1 END)
FROM gold.fait_satisfaction f LEFT JOIN gold.dim_localisation d ON d.id = f.localisation_id;
-- ------------------------------------- 3 et 4. Rejets et doublons ------------------------------------
-- Lignes écartées par les jobs, par motif (les doublons sont les motifs « doublon ... »)
CREATE TABLE qualite_groupe.rejets AS
SELECT job, motif, count(*) AS lignes FROM silver.rejets GROUP BY job, motif;

-- Journal des chargements : lignes lues en Bronze, écrites en Silver, rejetées, écrites en Gold
CREATE TABLE qualite_groupe.journal AS
SELECT job, date_lot, horodatage, lignes_bronze, lignes_silver, lignes_rejetees, lignes_gold, statut
FROM audit.journal_chargements;
CREATE TABLE qualite_groupe.volumes AS
SELECT 'silver.etablissement' AS table_nom, count(*) AS lignes FROM silver.etablissement
UNION ALL SELECT 'silver.professionnel', count(*) FROM silver.professionnel
UNION ALL SELECT 'silver.diagnostic', count(*) FROM silver.diagnostic
UNION ALL SELECT 'silver.patient', count(*) FROM silver.patient
UNION ALL SELECT 'silver.deces', count(*) FROM silver.deces
UNION ALL SELECT 'silver.satisfaction', count(*) FROM silver.satisfaction
UNION ALL SELECT 'gold.dim_localisation', count(*) FROM gold.dim_localisation
UNION ALL SELECT 'gold.dim_etablissement', count(*) FROM gold.dim_etablissement
UNION ALL SELECT 'gold.dim_professionnel', count(*) FROM gold.dim_professionnel
UNION ALL SELECT 'gold.dim_diagnostic', count(*) FROM gold.dim_diagnostic
UNION ALL SELECT 'gold.fait_deces', count(*) FROM gold.fait_deces
UNION ALL SELECT 'gold.fait_deces (somme nombre)', sum(nombre) FROM gold.fait_deces
UNION ALL SELECT 'gold.fait_satisfaction', count(*) FROM gold.fait_satisfaction;
SET mapreduce.map.memory.mb = 1024;
SET mapreduce.map.java.opts = -Xmx820m;
SET mapreduce.reduce.memory.mb = 1024;
SET mapreduce.reduce.java.opts = -Xmx820m;
SET hive.auto.convert.join = false;
-- ADELI avant correction : identifiant brut (sans le 0) retrouvé tel quel dans le fichier d'activité
INSERT INTO TABLE qualite_groupe.coherence
SELECT 'ADELI retrouve dans activite_professionnel_sante SANS correction du 0', 'bronze.professionnel_de_sante',
       count(*), count(a.identifiant)
FROM (SELECT DISTINCT identifiant FROM bronze.professionnel_de_sante WHERE type_identifiant = 'ADELI') p
LEFT JOIN (SELECT DISTINCT identifiant FROM bronze.activite_professionnel_sante) a ON a.identifiant = p.identifiant;
INSERT INTO TABLE qualite_groupe.coherence
SELECT 'ADELI retrouve dans activite_professionnel_sante AVEC correction du 0', 'bronze.professionnel_de_sante',
       count(*), count(a.identifiant)
FROM (SELECT DISTINCT CASE WHEN identifiant RLIKE '^[0-9]{8}$' THEN concat('0', identifiant) ELSE identifiant END AS identifiant
      FROM bronze.professionnel_de_sante WHERE type_identifiant = 'ADELI') p
LEFT JOIN (SELECT DISTINCT identifiant FROM bronze.activite_professionnel_sante) a ON a.identifiant = p.identifiant;
