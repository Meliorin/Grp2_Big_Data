-- =====================================================================
-- J7 - Deces INSEE (datamart Deces)
-- Source : deces.csv, 25 M lignes (tHDFSPut) ; traitement 100 % Hive
-- Prerequis : J1 (gold.dim_localisation)
-- =====================================================================
-- Memoire des taches MapReduce (la VM ne donne que 128 Mo par defaut)
SET mapreduce.map.memory.mb = 1024;
SET mapreduce.map.java.opts = -Xmx820m;
SET mapreduce.reduce.memory.mb = 1024;
SET mapreduce.reduce.java.opts = -Xmx820m;
SET hive.auto.convert.join = false;
SET hive.exec.dynamic.partition = true;
SET hive.exec.dynamic.partition.mode = nonstrict;

ALTER TABLE bronze.deces ADD IF NOT EXISTS PARTITION (date_ingestion = '${DATE_LOT}');

-- ---------- SILVER (annees >= 2014, sans nom ni prenom) ----------
-- Filtre >= 2014 applique AVANT le dedoublonnage (row_number) : seules les lignes 2014+ sont triees, pas les 25 M.
INSERT OVERWRITE TABLE silver.deces PARTITION (annee)
-- Conversion du sexe INSEE : '1' -> M, '2' -> F, sinon I (inconnu)
SELECT CASE sexe WHEN '1' THEN 'M' WHEN '2' THEN 'F' ELSE 'I' END,
       date_naissance, date_deces, code_lieu_deces,
       CASE WHEN substr(code_lieu_deces, 1, 2) IN ('97', '98') THEN substr(code_lieu_deces, 1, 3)
            ELSE substr(code_lieu_deces, 1, 2) END,
       CASE WHEN substr(date_naissance, 1, 4) RLIKE '^[0-9]{4}$'
            THEN year(date_deces) - CAST(substr(date_naissance, 1, 4) AS INT) END,
       year(date_deces) AS annee
FROM (
  SELECT d.*, row_number() OVER (PARTITION BY d.nom, d.prenom, d.date_naissance, d.date_deces, d.code_lieu_deces
                                 ORDER BY d.numero_acte_deces) AS rang
  FROM silver.v_j7_deces d
  WHERE d.date_ingestion = '${DATE_LOT}' AND d.annee_brute >= 2014
) t
WHERE date_deces IS NOT NULL
  AND length(code_lieu_deces) = 5 AND code_lieu_deces NOT LIKE '99%' AND rang = 1;

-- Rejets (sans nom ni prenom)
INSERT OVERWRITE TABLE silver.rejets PARTITION (job = 'J7_Deces', date_lot = '${DATE_LOT}')
SELECT 'deces.csv', coalesce(numero_acte_deces, ''),
       CASE WHEN date_deces IS NULL THEN 'date de deces invalide'
            WHEN code_lieu_deces LIKE '99%' THEN 'deces a l etranger (pas de region)'
            WHEN code_lieu_deces IS NULL OR length(code_lieu_deces) <> 5 THEN 'code lieu invalide'
            ELSE 'doublon' END,
       concat_ws('|', coalesce(date_deces, ''), coalesce(code_lieu_deces, ''))
FROM (
  SELECT d.*, row_number() OVER (PARTITION BY d.nom, d.prenom, d.date_naissance, d.date_deces, d.code_lieu_deces
                                 ORDER BY d.numero_acte_deces) AS rang
  FROM silver.v_j7_deces d
  WHERE d.date_ingestion = '${DATE_LOT}' AND d.annee_brute >= 2014
) t
WHERE (date_deces IS NULL OR code_lieu_deces IS NULL OR length(code_lieu_deces) <> 5
       OR code_lieu_deces LIKE '99%' OR rang > 1);

-- ---------- GOLD ----------
INSERT OVERWRITE TABLE gold.fait_deces PARTITION (annee)
SELECT coalesce(lc.id, ld.id, -1), CAST(regexp_replace(d.date_deces, '-', '') AS BIGINT), CAST(count(*) AS INT), d.annee
FROM silver.deces d
LEFT JOIN gold.dim_localisation lc ON lc.code_commune = d.code_lieu_deces
LEFT JOIN gold.dim_localisation ld ON ld.code_commune = concat('D', d.code_departement)
GROUP BY coalesce(lc.id, ld.id, -1), d.date_deces, d.annee
DISTRIBUTE BY annee;

-- ---------- AUDIT ----------
INSERT INTO TABLE audit.journal_chargements
SELECT 'J7_Deces', '${DATE_LOT}', from_unixtime(unix_timestamp()), sum(b), sum(s), sum(r), sum(g), 'OK'
FROM (
  SELECT CAST(n AS BIGINT) AS b, CAST(0 AS BIGINT) AS s, CAST(0 AS BIGINT) AS r, CAST(0 AS BIGINT) AS g FROM (SELECT count(*) AS n FROM bronze.deces WHERE date_ingestion = '${DATE_LOT}') b0
  UNION ALL
  SELECT CAST(0 AS BIGINT) AS b, CAST(n AS BIGINT) AS s, CAST(0 AS BIGINT) AS r, CAST(0 AS BIGINT) AS g FROM (SELECT count(*) AS n FROM silver.deces) s0
  UNION ALL
  SELECT CAST(0 AS BIGINT) AS b, CAST(0 AS BIGINT) AS s, CAST(n AS BIGINT) AS r, CAST(0 AS BIGINT) AS g FROM (SELECT count(*) AS n FROM silver.rejets WHERE job = 'J7_Deces' AND date_lot = '${DATE_LOT}') r0
  UNION ALL
  SELECT CAST(0 AS BIGINT) AS b, CAST(0 AS BIGINT) AS s, CAST(0 AS BIGINT) AS r, CAST(n AS BIGINT) AS g FROM (SELECT sum(nombre) AS n FROM gold.fait_deces) g0
) x;
