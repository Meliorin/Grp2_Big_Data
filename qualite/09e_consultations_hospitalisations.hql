SET mapreduce.map.memory.mb = 1024;
SET mapreduce.map.java.opts = -Xmx820m;
SET mapreduce.reduce.memory.mb = 1024;
SET mapreduce.reduce.java.opts = -Xmx820m;
SET hive.auto.convert.join = false;
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
SELECT 'fait_consultation_etablissement', 'temps_id', count(*), count(CASE WHEN d.id IS NULL THEN 1 END)
FROM gold.fait_consultation_etablissement f LEFT JOIN gold.dim_temps d ON d.id = f.temps_id;
DROP TABLE IF EXISTS qualite_groupe.rejets;
CREATE TABLE qualite_groupe.rejets AS
SELECT job, motif, count(*) AS lignes FROM silver.rejets GROUP BY job, motif;
DROP TABLE IF EXISTS qualite_groupe.journal;
CREATE TABLE qualite_groupe.journal AS
SELECT job, date_lot, horodatage, lignes_bronze, lignes_silver, lignes_rejetees, lignes_gold, statut
FROM audit.journal_chargements;
