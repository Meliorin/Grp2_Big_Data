-- =====================================================================
-- J8 - Satisfaction e-Satis 48h MCO 2019 (CSV) et 2020 (Excel)
-- Sources : CSV 2019 (tHDFSPut) et xlsx 2020 (tFileInputExcel -> tHDFSOutput)
-- Prerequis : J1 (gold.dim_etablissement)
-- =====================================================================
-- Memoire des taches MapReduce (la VM ne donne que 128 Mo par defaut)
SET mapreduce.map.memory.mb = 1024;
SET mapreduce.map.java.opts = -Xmx820m;
SET mapreduce.reduce.memory.mb = 1024;
SET mapreduce.reduce.java.opts = -Xmx820m;
SET hive.auto.convert.join = false;
SET hive.exec.dynamic.partition = true;
SET hive.exec.dynamic.partition.mode = nonstrict;

-- Declaration des partitions du lot deposees par Talend (comme J1 a J7)
ALTER TABLE bronze.esatis_csv  ADD IF NOT EXISTS PARTITION (date_ingestion = '${DATE_LOT}', annee = 2019);
ALTER TABLE bronze.esatis_xlsx ADD IF NOT EXISTS PARTITION (date_ingestion = '${DATE_LOT}', annee = 2020);

-- ---------- SILVER : une ligne par (etablissement, annee, type de score) ----------
INSERT OVERWRITE TABLE silver.satisfaction PARTITION (annee)
SELECT identifiant_organisation, finess_juridique, type_score, score, nb_reponses, annee
FROM silver.v_j8_satisfaction
WHERE date_ingestion = '${DATE_LOT}'
  AND score IS NOT NULL AND score BETWEEN 0 AND 100 AND nb_reponses IS NOT NULL AND nb_reponses > 0;

-- Rejets : score vide = classe DI (< 30 reponses) ; score sans nb de reponses = non ponderable
INSERT OVERWRITE TABLE silver.rejets PARTITION (job = 'J8_Satisfaction', date_lot = '${DATE_LOT}')
SELECT concat('esatis_', CAST(annee AS STRING)), concat(identifiant_organisation, '/', type_score),
       CASE WHEN score IS NULL THEN 'non calculable (classe DI)'
            WHEN score NOT BETWEEN 0 AND 100 THEN 'score hors bornes'
            ELSE 'non ponderable (nb de reponses absent)' END,
       concat_ws('|', CAST(annee AS STRING), coalesce(CAST(score AS STRING), ''), coalesce(CAST(nb_reponses AS STRING), ''))
FROM silver.v_j8_satisfaction
WHERE date_ingestion = '${DATE_LOT}'
  AND (score IS NULL OR score NOT BETWEEN 0 AND 100 OR nb_reponses IS NULL OR nb_reponses <= 0);

-- ---------- GOLD : moyenne ponderee par le nombre de reponses ----------
INSERT OVERWRITE TABLE gold.fait_satisfaction PARTITION (annee)
SELECT coalesce(e.localisation_id, -1), t.id, CAST(concat(CAST(s.annee AS STRING), '0101') AS BIGINT),
       sum(s.score * s.nb_reponses) / sum(s.nb_reponses), CAST(sum(s.nb_reponses) AS INT), s.annee
FROM silver.satisfaction s
JOIN gold.dim_type_satisfaction t ON t.code = s.type_score
LEFT JOIN gold.dim_etablissement e ON e.code = s.identifiant_organisation
GROUP BY coalesce(e.localisation_id, -1), t.id, s.annee
DISTRIBUTE BY annee;

-- ---------- AUDIT ----------
INSERT INTO TABLE audit.journal_chargements
SELECT 'J8_Satisfaction', '${DATE_LOT}', from_unixtime(unix_timestamp()), sum(b), sum(s), sum(r), sum(g), 'OK'
FROM (
  SELECT CAST(n AS BIGINT) AS b, CAST(0 AS BIGINT) AS s, CAST(0 AS BIGINT) AS r, CAST(0 AS BIGINT) AS g FROM (SELECT count(*) AS n FROM (SELECT finess FROM bronze.esatis_csv WHERE date_ingestion = '${DATE_LOT}' UNION ALL SELECT finess FROM bronze.esatis_xlsx WHERE date_ingestion = '${DATE_LOT}') x) b0
  UNION ALL
  SELECT CAST(0 AS BIGINT) AS b, CAST(n AS BIGINT) AS s, CAST(0 AS BIGINT) AS r, CAST(0 AS BIGINT) AS g FROM (SELECT count(*) AS n FROM silver.satisfaction) s0
  UNION ALL
  SELECT CAST(0 AS BIGINT) AS b, CAST(0 AS BIGINT) AS s, CAST(n AS BIGINT) AS r, CAST(0 AS BIGINT) AS g FROM (SELECT count(*) AS n FROM silver.rejets WHERE job = 'J8_Satisfaction' AND date_lot = '${DATE_LOT}') r0
  UNION ALL
  SELECT CAST(0 AS BIGINT) AS b, CAST(0 AS BIGINT) AS s, CAST(0 AS BIGINT) AS r, CAST(n AS BIGINT) AS g FROM (SELECT count(*) AS n FROM gold.fait_satisfaction) g0
) x;
