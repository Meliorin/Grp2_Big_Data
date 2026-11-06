-- =====================================================================
-- J5 - Consultations (datamart Consultation)
-- Source : PostgreSQL Consultation (tPostgresqlInput -> tHDFSOutput)
-- Prerequis : J1, J2, J3, J4
-- Les SET ci-dessous servent a beeline ; dans Talend ils sont passes
-- dans l'URL de connexion Hive (parametres JDBC additionnels).
-- =====================================================================
-- Memoire des taches MapReduce (la VM ne donne que 128 Mo par defaut)
SET mapreduce.map.memory.mb = 1024;
SET mapreduce.map.java.opts = -Xmx820m;
SET mapreduce.reduce.memory.mb = 1024;
SET mapreduce.reduce.java.opts = -Xmx820m;
SET hive.auto.convert.join = false;
SET hive.exec.dynamic.partition = true;
SET hive.exec.dynamic.partition.mode = nonstrict;

ALTER TABLE bronze.consultation ADD IF NOT EXISTS PARTITION (date_ingestion = '${DATE_LOT}');

-- ---------- SILVER (partitionne par annee) ----------
INSERT OVERWRITE TABLE silver.consultation PARTITION (annee)
SELECT c.num_consultation, sha2(concat('${SEL}', c.id_patient), 256), c.id_prof_sante, c.code_diag, c.motif,
       c.date_consultation, c.duree_min, pr.etablissement_code, coalesce(pa.sexe, 'I'),
       year(c.date_consultation) - year(pa.date_naissance),
       year(c.date_consultation) AS annee
FROM silver.v_j5_consultation c
LEFT JOIN silver.patient pa ON pa.id_patient_hash = sha2(concat('${SEL}', c.id_patient), 256)
LEFT JOIN silver.professionnel pr ON pr.identifiant = c.id_prof_sante
WHERE c.date_ingestion = '${DATE_LOT}' AND c.num_consultation IS NOT NULL AND c.date_consultation IS NOT NULL
  AND c.code_diag IS NOT NULL AND c.duree_min IS NOT NULL AND c.rang = 1;

INSERT OVERWRITE TABLE silver.rejets PARTITION (job = 'J5_Consultations', date_lot = '${DATE_LOT}')
SELECT 'Consultation', coalesce(CAST(num_consultation AS STRING), ''),
       CASE WHEN num_consultation IS NULL THEN 'numero absent'
            WHEN date_consultation IS NULL THEN 'date absente ou invalide'
            WHEN code_diag IS NULL THEN 'code diagnostic absent'
            WHEN duree_min IS NULL THEN 'heures invalides'
            ELSE 'doublon num_consultation' END,
       concat_ws('|', coalesce(date_consultation, ''), coalesce(code_diag, ''), coalesce(id_prof_sante, ''))
FROM silver.v_j5_consultation
WHERE date_ingestion = '${DATE_LOT}'
  AND (num_consultation IS NULL OR date_consultation IS NULL OR code_diag IS NULL OR duree_min IS NULL OR rang > 1);

-- ---------- GOLD : faits agreges par jour, partitionnes par annee ----------
INSERT OVERWRITE TABLE gold.fait_consultation_etablissement PARTITION (annee)
SELECT coalesce(e.id, -1), CAST(regexp_replace(c.date_consultation, '-', '') AS BIGINT),
       CAST(count(*) AS INT), sum(c.duree_min), c.annee
FROM silver.consultation c
LEFT JOIN gold.dim_etablissement e ON e.code = c.etablissement_code
GROUP BY coalesce(e.id, -1), c.date_consultation, c.annee
DISTRIBUTE BY annee;

INSERT OVERWRITE TABLE gold.fait_consultation_diagnostic PARTITION (annee)
SELECT coalesce(d.id, -1), CAST(regexp_replace(c.date_consultation, '-', '') AS BIGINT),
       CAST(count(*) AS INT), sum(c.duree_min), c.annee
FROM silver.consultation c
LEFT JOIN gold.dim_diagnostic d ON d.code = c.code_diag
GROUP BY coalesce(d.id, -1), c.date_consultation, c.annee
DISTRIBUTE BY annee;

INSERT OVERWRITE TABLE gold.fait_consultation_professionnel PARTITION (annee)
SELECT coalesce(p.id, -1), CAST(regexp_replace(c.date_consultation, '-', '') AS BIGINT),
       CAST(count(*) AS INT), sum(c.duree_min), c.annee
FROM silver.consultation c
LEFT JOIN gold.dim_professionnel p ON p.identifiant = c.id_prof_sante
GROUP BY coalesce(p.id, -1), c.date_consultation, c.annee
DISTRIBUTE BY annee;

-- ---------- AUDIT ----------
INSERT INTO TABLE audit.journal_chargements
SELECT 'J5_Consultations', '${DATE_LOT}', from_unixtime(unix_timestamp()), sum(b), sum(s), sum(r), sum(g), 'OK'
FROM (
  SELECT CAST(n AS BIGINT) AS b, CAST(0 AS BIGINT) AS s, CAST(0 AS BIGINT) AS r, CAST(0 AS BIGINT) AS g FROM (SELECT count(*) AS n FROM bronze.consultation WHERE date_ingestion = '${DATE_LOT}') b0
  UNION ALL
  SELECT CAST(0 AS BIGINT) AS b, CAST(n AS BIGINT) AS s, CAST(0 AS BIGINT) AS r, CAST(0 AS BIGINT) AS g FROM (SELECT count(*) AS n FROM silver.consultation) s0
  UNION ALL
  SELECT CAST(0 AS BIGINT) AS b, CAST(0 AS BIGINT) AS s, CAST(n AS BIGINT) AS r, CAST(0 AS BIGINT) AS g FROM (SELECT count(*) AS n FROM silver.rejets WHERE job = 'J5_Consultations' AND date_lot = '${DATE_LOT}') r0
  UNION ALL
  SELECT CAST(0 AS BIGINT) AS b, CAST(0 AS BIGINT) AS s, CAST(0 AS BIGINT) AS r, CAST(n AS BIGINT) AS g FROM (SELECT sum(nombre) AS n FROM gold.fait_consultation_etablissement) g0
) x;
