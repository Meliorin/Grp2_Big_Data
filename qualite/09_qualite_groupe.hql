-- =====================================================================================================
-- Livrable 2 - Groupe 2 - 09_qualite_groupe.hql
-- Rapport qualité de la chaîne du groupe : complétude de la Silver, cohérence référentielle (FINESS, ADELI,
-- rattachements), doublons et rejets enregistrés par les jobs J1 à J8, journal des chargements.
-- La complétude des sources (Bronze) ne dépend pas des jobs : elle est reprise du script sql/09_qualite.sql.
-- =====================================================================================================
SET mapreduce.map.memory.mb = 1024;
SET mapreduce.map.java.opts = -Xmx820m;
SET mapreduce.reduce.memory.mb = 1024;
SET mapreduce.reduce.java.opts = -Xmx820m;
SET hive.auto.convert.join = false;
DROP DATABASE IF EXISTS qualite_groupe CASCADE;
CREATE DATABASE qualite_groupe;

-- ------------------------------------- 1. Complétude de la Silver -------------------------------------
-- Une valeur est renseignée si elle n'est ni NULL ni vide. Une seule lecture de chaque table (stack).
CREATE TABLE qualite_groupe.completude (couche STRING, table_nom STRING, colonne STRING, lignes BIGINT, renseignees BIGINT);
INSERT INTO TABLE qualite_groupe.completude
SELECT 'silver', 'etablissement', s.colonne, x.lignes, s.n
FROM (SELECT count(*) AS lignes, count(CASE WHEN identifiant_organisation IS NOT NULL AND trim(CAST(identifiant_organisation AS STRING)) <> '' THEN 1 END) AS c0,
             count(CASE WHEN type_organisation IS NOT NULL AND trim(CAST(type_organisation AS STRING)) <> '' THEN 1 END) AS c1,
             count(CASE WHEN finess_site IS NOT NULL AND trim(CAST(finess_site AS STRING)) <> '' THEN 1 END) AS c2,
             count(CASE WHEN finess_juridique IS NOT NULL AND trim(CAST(finess_juridique AS STRING)) <> '' THEN 1 END) AS c3,
             count(CASE WHEN raison_sociale IS NOT NULL AND trim(CAST(raison_sociale AS STRING)) <> '' THEN 1 END) AS c4,
             count(CASE WHEN code_commune IS NOT NULL AND trim(CAST(code_commune AS STRING)) <> '' THEN 1 END) AS c5,
             count(CASE WHEN commune IS NOT NULL AND trim(CAST(commune AS STRING)) <> '' THEN 1 END) AS c6,
             count(CASE WHEN code_postal IS NOT NULL AND trim(CAST(code_postal AS STRING)) <> '' THEN 1 END) AS c7,
             count(CASE WHEN code_departement IS NOT NULL AND trim(CAST(code_departement AS STRING)) <> '' THEN 1 END) AS c8
      FROM silver.etablissement) x
LATERAL VIEW stack(9, 'identifiant_organisation', c0, 'type_organisation', c1, 'finess_site', c2, 'finess_juridique', c3, 'raison_sociale', c4, 'code_commune', c5, 'commune', c6, 'code_postal', c7, 'code_departement', c8) s AS colonne, n;
INSERT INTO TABLE qualite_groupe.completude
SELECT 'silver', 'professionnel', s.colonne, x.lignes, s.n
FROM (SELECT count(*) AS lignes, count(CASE WHEN identifiant IS NOT NULL AND trim(CAST(identifiant AS STRING)) <> '' THEN 1 END) AS c0,
             count(CASE WHEN type_identifiant IS NOT NULL AND trim(CAST(type_identifiant AS STRING)) <> '' THEN 1 END) AS c1,
             count(CASE WHEN categorie_professionnelle IS NOT NULL AND trim(CAST(categorie_professionnelle AS STRING)) <> '' THEN 1 END) AS c2,
             count(CASE WHEN profession IS NOT NULL AND trim(CAST(profession AS STRING)) <> '' THEN 1 END) AS c3,
             count(CASE WHEN code_specialite IS NOT NULL AND trim(CAST(code_specialite AS STRING)) <> '' THEN 1 END) AS c4,
             count(CASE WHEN specialite IS NOT NULL AND trim(CAST(specialite AS STRING)) <> '' THEN 1 END) AS c5,
             count(CASE WHEN etablissement_code IS NOT NULL AND trim(CAST(etablissement_code AS STRING)) <> '' THEN 1 END) AS c6
      FROM silver.professionnel) x
LATERAL VIEW stack(7, 'identifiant', c0, 'type_identifiant', c1, 'categorie_professionnelle', c2, 'profession', c3, 'code_specialite', c4, 'specialite', c5, 'etablissement_code', c6) s AS colonne, n;
INSERT INTO TABLE qualite_groupe.completude
SELECT 'silver', 'diagnostic', s.colonne, x.lignes, s.n
FROM (SELECT count(*) AS lignes, count(CASE WHEN code_diag IS NOT NULL AND trim(CAST(code_diag AS STRING)) <> '' THEN 1 END) AS c0,
             count(CASE WHEN libelle IS NOT NULL AND trim(CAST(libelle AS STRING)) <> '' THEN 1 END) AS c1
      FROM silver.diagnostic) x
LATERAL VIEW stack(2, 'code_diag', c0, 'libelle', c1) s AS colonne, n;
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
SELECT 'silver', 'consultation', s.colonne, x.lignes, s.n
FROM (SELECT count(*) AS lignes, count(CASE WHEN num_consultation IS NOT NULL AND trim(CAST(num_consultation AS STRING)) <> '' THEN 1 END) AS c0,
             count(CASE WHEN id_patient_hash IS NOT NULL AND trim(CAST(id_patient_hash AS STRING)) <> '' THEN 1 END) AS c1,
             count(CASE WHEN id_prof_sante IS NOT NULL AND trim(CAST(id_prof_sante AS STRING)) <> '' THEN 1 END) AS c2,
             count(CASE WHEN code_diag IS NOT NULL AND trim(CAST(code_diag AS STRING)) <> '' THEN 1 END) AS c3,
             count(CASE WHEN motif IS NOT NULL AND trim(CAST(motif AS STRING)) <> '' THEN 1 END) AS c4,
             count(CASE WHEN date_consultation IS NOT NULL AND trim(CAST(date_consultation AS STRING)) <> '' THEN 1 END) AS c5,
             count(CASE WHEN duree_min IS NOT NULL AND trim(CAST(duree_min AS STRING)) <> '' THEN 1 END) AS c6,
             count(CASE WHEN etablissement_code IS NOT NULL AND trim(CAST(etablissement_code AS STRING)) <> '' THEN 1 END) AS c7,
             count(CASE WHEN sexe IS NOT NULL AND trim(CAST(sexe AS STRING)) <> '' THEN 1 END) AS c8,
             count(CASE WHEN age IS NOT NULL AND trim(CAST(age AS STRING)) <> '' THEN 1 END) AS c9
      FROM silver.consultation) x
LATERAL VIEW stack(10, 'num_consultation', c0, 'id_patient_hash', c1, 'id_prof_sante', c2, 'code_diag', c3, 'motif', c4, 'date_consultation', c5, 'duree_min', c6, 'etablissement_code', c7, 'sexe', c8, 'age', c9) s AS colonne, n;
INSERT INTO TABLE qualite_groupe.completude
SELECT 'silver', 'hospitalisation', s.colonne, x.lignes, s.n
FROM (SELECT count(*) AS lignes, count(CASE WHEN num_hospitalisation IS NOT NULL AND trim(CAST(num_hospitalisation AS STRING)) <> '' THEN 1 END) AS c0,
             count(CASE WHEN id_patient_hash IS NOT NULL AND trim(CAST(id_patient_hash AS STRING)) <> '' THEN 1 END) AS c1,
             count(CASE WHEN etablissement_code IS NOT NULL AND trim(CAST(etablissement_code AS STRING)) <> '' THEN 1 END) AS c2,
             count(CASE WHEN code_diag IS NOT NULL AND trim(CAST(code_diag AS STRING)) <> '' THEN 1 END) AS c3,
             count(CASE WHEN date_entree IS NOT NULL AND trim(CAST(date_entree AS STRING)) <> '' THEN 1 END) AS c4,
             count(CASE WHEN duree_jours IS NOT NULL AND trim(CAST(duree_jours AS STRING)) <> '' THEN 1 END) AS c5,
             count(CASE WHEN sexe IS NOT NULL AND trim(CAST(sexe AS STRING)) <> '' THEN 1 END) AS c6,
             count(CASE WHEN age IS NOT NULL AND trim(CAST(age AS STRING)) <> '' THEN 1 END) AS c7
      FROM silver.hospitalisation) x
LATERAL VIEW stack(8, 'num_hospitalisation', c0, 'id_patient_hash', c1, 'etablissement_code', c2, 'code_diag', c3, 'date_entree', c4, 'duree_jours', c5, 'sexe', c6, 'age', c7) s AS colonne, n;
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
INSERT INTO TABLE qualite_groupe.completude
SELECT 'silver', 'satisfaction', s.colonne, x.lignes, s.n
FROM (SELECT count(*) AS lignes, count(CASE WHEN identifiant_organisation IS NOT NULL AND trim(CAST(identifiant_organisation AS STRING)) <> '' THEN 1 END) AS c0,
             count(CASE WHEN finess_juridique IS NOT NULL AND trim(CAST(finess_juridique AS STRING)) <> '' THEN 1 END) AS c1,
             count(CASE WHEN type_score IS NOT NULL AND trim(CAST(type_score AS STRING)) <> '' THEN 1 END) AS c2,
             count(CASE WHEN score IS NOT NULL AND trim(CAST(score AS STRING)) <> '' THEN 1 END) AS c3,
             count(CASE WHEN nb_reponses IS NOT NULL AND trim(CAST(nb_reponses AS STRING)) <> '' THEN 1 END) AS c4
      FROM silver.satisfaction) x
LATERAL VIEW stack(5, 'identifiant_organisation', c0, 'finess_juridique', c1, 'type_score', c2, 'score', c3, 'nb_reponses', c4) s AS colonne, n;

-- ----------------------------------- 2. Cohérence référentielle --------------------------------------
-- Chaque ligne : un contrôle, le nombre de lignes contrôlées et le nombre de lignes conformes.
CREATE TABLE qualite_groupe.coherence (controle STRING, source STRING, lignes BIGINT, conformes BIGINT);

-- Format FINESS des identifiants d'organisation en F (9 chiffres, 2A / 2B pour la Corse, 18 car. pour les officines)
INSERT INTO TABLE qualite_groupe.coherence
SELECT 'Format FINESS valide', 'silver.etablissement (codes F)', count(*),
       count(CASE WHEN identifiant_organisation RLIKE '^F([0-9]{2}|2A|2B)[0-9]{7}([0-9]{8})?$' THEN 1 END)
FROM silver.etablissement WHERE type_organisation = 'F';

-- Professionnels rattachés à une organisation, par type d'identifiant (après remise du 0 des ADELI)
INSERT INTO TABLE qualite_groupe.coherence
SELECT concat('Professionnel rattache a une organisation (', type_identifiant, ')'), 'silver.professionnel',
       count(*), count(etablissement_code)
FROM silver.professionnel GROUP BY type_identifiant;

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

-- Consultations : patient connu, professionnel connu, établissement de rattachement
INSERT INTO TABLE qualite_groupe.coherence
SELECT 'Consultation avec patient connu (sexe <> I)', 'silver.consultation', count(*), count(CASE WHEN sexe <> 'I' THEN 1 END)
FROM silver.consultation;
INSERT INTO TABLE qualite_groupe.coherence
SELECT 'Consultation avec professionnel connu', 'silver.consultation', count(*), count(p.identifiant)
FROM silver.consultation c LEFT JOIN silver.professionnel p ON p.identifiant = c.id_prof_sante;
INSERT INTO TABLE qualite_groupe.coherence
SELECT 'Consultation rattachee a une organisation', 'silver.consultation', count(*), count(etablissement_code)
FROM silver.consultation;
INSERT INTO TABLE qualite_groupe.coherence
SELECT 'Consultation rattachee a un etablissement de sante (Gold, hors -1)', 'gold.fait_consultation_etablissement',
       sum(nombre), sum(CASE WHEN etablissement_id <> -1 THEN nombre ELSE 0 END)
FROM gold.fait_consultation_etablissement;
INSERT INTO TABLE qualite_groupe.coherence
SELECT 'Consultation avec diagnostic du referentiel (Gold, hors -1)', 'gold.fait_consultation_diagnostic',
       sum(nombre), sum(CASE WHEN diagnostic_id <> -1 THEN nombre ELSE 0 END)
FROM gold.fait_consultation_diagnostic;

-- Hospitalisations : FINESS présent dans le référentiel des établissements
INSERT INTO TABLE qualite_groupe.coherence
SELECT 'Hospitalisation : FINESS dans le referentiel', 'silver.hospitalisation', count(*), count(e.identifiant_organisation)
FROM silver.hospitalisation h LEFT JOIN silver.etablissement e ON e.identifiant_organisation = h.etablissement_code;
INSERT INTO TABLE qualite_groupe.coherence
SELECT 'Hospitalisation : diagnostic du referentiel', 'silver.hospitalisation', count(*), count(d.code_diag)
FROM silver.hospitalisation h LEFT JOIN silver.diagnostic d ON d.code_diag = h.code_diag;

-- e-Satis : "F" + finess_geo présent dans le référentiel, par année
INSERT INTO TABLE qualite_groupe.coherence
SELECT concat('e-Satis ', CAST(s.annee AS STRING), ' : F + finess_geo dans le referentiel'), 'silver.satisfaction',
       count(*), count(e.identifiant_organisation)
FROM silver.satisfaction s LEFT JOIN silver.etablissement e ON e.identifiant_organisation = s.identifiant_organisation
GROUP BY s.annee;

-- Décès : lieu retrouvé au niveau commune (établissements) ou département, sinon -1 « Non renseigné »
INSERT INTO TABLE qualite_groupe.coherence
SELECT 'Deces : lieu retrouve dans dim_localisation (hors -1)', 'gold.fait_deces',
       sum(nombre), sum(CASE WHEN localisation_id <> -1 THEN nombre ELSE 0 END)
FROM gold.fait_deces;
INSERT INTO TABLE qualite_groupe.coherence
SELECT 'Deces : departement dans le referentiel', 'silver.deces', count(*), count(r.code_departement)
FROM silver.deces d LEFT JOIN silver.ref_departement r ON r.code_departement = d.code_departement;

-- Intégrité référentielle de la Gold : clés des faits absentes des dimensions (attendu : 0)
CREATE TABLE qualite_groupe.orphelins (fait STRING, cle STRING, lignes BIGINT, orphelines BIGINT);
INSERT INTO TABLE qualite_groupe.orphelins
SELECT 'fait_consultation_etablissement', 'etablissement_id', count(*), count(CASE WHEN d.id IS NULL THEN 1 END)
FROM gold.fait_consultation_etablissement f LEFT JOIN gold.dim_etablissement d ON d.id = f.etablissement_id
UNION ALL
SELECT 'fait_consultation_diagnostic', 'diagnostic_id', count(*), count(CASE WHEN d.id IS NULL THEN 1 END)
FROM gold.fait_consultation_diagnostic f LEFT JOIN gold.dim_diagnostic d ON d.id = f.diagnostic_id
UNION ALL
SELECT 'fait_consultation_professionnel', 'professionnel_id', count(*), count(CASE WHEN d.id IS NULL THEN 1 END)
FROM gold.fait_consultation_professionnel f LEFT JOIN gold.dim_professionnel d ON d.id = f.professionnel_id
UNION ALL
SELECT 'fait_hospitalisation_patient', 'patient_id', count(*), count(CASE WHEN d.id IS NULL THEN 1 END)
FROM gold.fait_hospitalisation_patient f LEFT JOIN gold.dim_patient d ON d.id = f.patient_id
UNION ALL
SELECT 'fait_deces', 'localisation_id', count(*), count(CASE WHEN d.id IS NULL THEN 1 END)
FROM gold.fait_deces f LEFT JOIN gold.dim_localisation d ON d.id = f.localisation_id
UNION ALL
SELECT 'fait_deces', 'temps_id', count(*), count(CASE WHEN d.id IS NULL THEN 1 END)
FROM gold.fait_deces f LEFT JOIN gold.dim_temps d ON d.id = f.temps_id
UNION ALL
SELECT 'fait_consultation_etablissement', 'temps_id', count(*), count(CASE WHEN d.id IS NULL THEN 1 END)
FROM gold.fait_consultation_etablissement f LEFT JOIN gold.dim_temps d ON d.id = f.temps_id
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

-- Volumes de la Silver et de la Gold
CREATE TABLE qualite_groupe.volumes AS
SELECT 'silver.etablissement' AS table_nom, count(*) AS lignes FROM silver.etablissement
UNION ALL SELECT 'silver.professionnel', count(*) FROM silver.professionnel
UNION ALL SELECT 'silver.diagnostic', count(*) FROM silver.diagnostic
UNION ALL SELECT 'silver.patient', count(*) FROM silver.patient
UNION ALL SELECT 'silver.consultation', count(*) FROM silver.consultation
UNION ALL SELECT 'silver.hospitalisation', count(*) FROM silver.hospitalisation
UNION ALL SELECT 'silver.deces', count(*) FROM silver.deces
UNION ALL SELECT 'silver.satisfaction', count(*) FROM silver.satisfaction
UNION ALL SELECT 'gold.dim_localisation', count(*) FROM gold.dim_localisation
UNION ALL SELECT 'gold.dim_etablissement', count(*) FROM gold.dim_etablissement
UNION ALL SELECT 'gold.dim_professionnel', count(*) FROM gold.dim_professionnel
UNION ALL SELECT 'gold.dim_diagnostic', count(*) FROM gold.dim_diagnostic
UNION ALL SELECT 'gold.fait_consultation_etablissement', count(*) FROM gold.fait_consultation_etablissement
UNION ALL SELECT 'gold.fait_deces', count(*) FROM gold.fait_deces
UNION ALL SELECT 'gold.fait_deces (somme nombre)', sum(nombre) FROM gold.fait_deces
UNION ALL SELECT 'gold.fait_satisfaction', count(*) FROM gold.fait_satisfaction;
