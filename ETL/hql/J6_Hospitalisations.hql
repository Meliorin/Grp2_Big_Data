-- =====================================================================
-- J6 - Hospitalisations (datamart Hospitalisation)
-- Source : Hospitalisations.csv (tHDFSPut)
-- Prerequis : J1, J3, J4
-- =====================================================================
-- Memoire des taches MapReduce (la VM ne donne que 128 Mo par defaut)
SET mapreduce.map.memory.mb = 1024;
SET mapreduce.map.java.opts = -Xmx820m;
SET mapreduce.reduce.memory.mb = 1024;
SET mapreduce.reduce.java.opts = -Xmx820m;
SET hive.auto.convert.join = false;
SET hive.exec.dynamic.partition = true;
SET hive.exec.dynamic.partition.mode = nonstrict;

ALTER TABLE bronze.hospitalisation ADD IF NOT EXISTS PARTITION (date_ingestion = '${DATE_LOT}');

-- ---------- SILVER ----------
INSERT OVERWRITE TABLE silver.hospitalisation PARTITION (annee)
SELECT h.num_hospitalisation, pa.id_patient_hash, h.etablissement_code, h.code_diag, h.date_entree, h.duree_jours,
       pa.sexe, year(h.date_entree) - year(pa.date_naissance), year(h.date_entree) AS annee
FROM silver.v_j6_hospitalisation h
JOIN silver.patient pa ON pa.id_patient_hash = sha2(concat('${SEL}', h.id_patient), 256)
WHERE h.date_ingestion = '${DATE_LOT}' AND h.num_hospitalisation IS NOT NULL AND h.date_entree IS NOT NULL
  AND h.duree_jours BETWEEN 1 AND 365 AND h.rang = 1;

INSERT OVERWRITE TABLE silver.rejets PARTITION (job = 'J6_Hospitalisations', date_lot = '${DATE_LOT}')
SELECT 'Hospitalisations.csv', coalesce(CAST(h.num_hospitalisation AS STRING), ''),
       CASE WHEN h.num_hospitalisation IS NULL THEN 'numero absent'
            WHEN h.date_entree IS NULL THEN 'date d entree invalide'
            WHEN h.duree_jours IS NULL OR h.duree_jours NOT BETWEEN 1 AND 365 THEN 'duree invalide'
            WHEN h.rang > 1 THEN 'doublon num_hospitalisation'
            ELSE 'patient inconnu' END,
       concat_ws('|', coalesce(h.date_entree, ''), coalesce(h.code_diag, ''), coalesce(h.etablissement_code, ''))
FROM silver.v_j6_hospitalisation h
LEFT JOIN silver.patient pa ON pa.id_patient_hash = sha2(concat('${SEL}', h.id_patient), 256)
WHERE h.date_ingestion = '${DATE_LOT}'
  AND (h.num_hospitalisation IS NULL OR h.date_entree IS NULL OR h.duree_jours IS NULL
       OR h.duree_jours NOT BETWEEN 1 AND 365 OR h.rang > 1 OR pa.id_patient_hash IS NULL);

-- ---------- GOLD ----------
INSERT OVERWRITE TABLE gold.fait_hospitalisation_globale PARTITION (annee)
SELECT CAST(regexp_replace(date_entree, '-', '') AS BIGINT), CAST(count(*) AS INT), CAST(sum(duree_jours) AS INT),
       avg(duree_jours), annee
FROM silver.hospitalisation
GROUP BY date_entree, annee
DISTRIBUTE BY annee;

INSERT OVERWRITE TABLE gold.fait_hospitalisation_diagnostic PARTITION (annee)
SELECT coalesce(d.id, -1), CAST(regexp_replace(h.date_entree, '-', '') AS BIGINT), CAST(count(*) AS INT),
       CAST(sum(h.duree_jours) AS INT), h.annee
FROM silver.hospitalisation h
LEFT JOIN gold.dim_diagnostic d ON d.code = h.code_diag
GROUP BY coalesce(d.id, -1), h.date_entree, h.annee
DISTRIBUTE BY annee;

INSERT OVERWRITE TABLE gold.fait_hospitalisation_patient PARTITION (annee)
SELECT CASE WHEN h.age BETWEEN 0 AND 120 THEN (CASE h.sexe WHEN 'M' THEN 1000 WHEN 'F' THEN 2000 ELSE 3000 END) + h.age ELSE -1 END,
       CAST(regexp_replace(h.date_entree, '-', '') AS BIGINT), CAST(count(*) AS INT), CAST(sum(h.duree_jours) AS INT), h.annee
FROM silver.hospitalisation h
GROUP BY CASE WHEN h.age BETWEEN 0 AND 120 THEN (CASE h.sexe WHEN 'M' THEN 1000 WHEN 'F' THEN 2000 ELSE 3000 END) + h.age ELSE -1 END,
         h.date_entree, h.annee
DISTRIBUTE BY annee;

INSERT OVERWRITE TABLE gold.fait_hospitalisation_etablissement PARTITION (annee)
SELECT coalesce(e.id, -1), CAST(regexp_replace(h.date_entree, '-', '') AS BIGINT), CAST(count(*) AS INT),
       CAST(sum(h.duree_jours) AS INT), h.annee
FROM silver.hospitalisation h
LEFT JOIN gold.dim_etablissement e ON e.code = h.etablissement_code
GROUP BY coalesce(e.id, -1), h.date_entree, h.annee
DISTRIBUTE BY annee;

-- ---------- AUDIT ----------
INSERT INTO TABLE audit.journal_chargements
SELECT 'J6_Hospitalisations', '${DATE_LOT}', from_unixtime(unix_timestamp()), sum(b), sum(s), sum(r), sum(g), 'OK'
FROM (
  SELECT CAST(n AS BIGINT) AS b, CAST(0 AS BIGINT) AS s, CAST(0 AS BIGINT) AS r, CAST(0 AS BIGINT) AS g FROM (SELECT count(*) AS n FROM bronze.hospitalisation WHERE date_ingestion = '${DATE_LOT}') b0
  UNION ALL
  SELECT CAST(0 AS BIGINT) AS b, CAST(n AS BIGINT) AS s, CAST(0 AS BIGINT) AS r, CAST(0 AS BIGINT) AS g FROM (SELECT count(*) AS n FROM silver.hospitalisation) s0
  UNION ALL
  SELECT CAST(0 AS BIGINT) AS b, CAST(0 AS BIGINT) AS s, CAST(n AS BIGINT) AS r, CAST(0 AS BIGINT) AS g FROM (SELECT count(*) AS n FROM silver.rejets WHERE job = 'J6_Hospitalisations' AND date_lot = '${DATE_LOT}') r0
  UNION ALL
  SELECT CAST(0 AS BIGINT) AS b, CAST(0 AS BIGINT) AS s, CAST(0 AS BIGINT) AS r, CAST(n AS BIGINT) AS g FROM (SELECT sum(nombre) AS n FROM gold.fait_hospitalisation_globale) g0
) x;
