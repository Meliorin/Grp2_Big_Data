-- =====================================================================
-- J3 - Diagnostics CIM-10
-- Source : PostgreSQL Diagnostic (tPostgresqlInput -> tHDFSOutput)
-- =====================================================================
-- Memoire des taches MapReduce (la VM ne donne que 128 Mo par defaut)
SET mapreduce.map.memory.mb = 1024;
SET mapreduce.map.java.opts = -Xmx820m;
SET mapreduce.reduce.memory.mb = 1024;
SET mapreduce.reduce.java.opts = -Xmx820m;
SET hive.auto.convert.join = false;

ALTER TABLE bronze.diagnostic ADD IF NOT EXISTS PARTITION (date_ingestion = '${DATE_LOT}');

INSERT OVERWRITE TABLE silver.diagnostic
SELECT code_diag, libelle FROM silver.v_j3_diagnostic
WHERE date_ingestion = '${DATE_LOT}' AND code_diag IS NOT NULL AND rang = 1;

INSERT OVERWRITE TABLE silver.rejets PARTITION (job = 'J3_Diagnostics', date_lot = '${DATE_LOT}')
SELECT 'Diagnostic', coalesce(code_diag, ''),
       CASE WHEN code_diag IS NULL THEN 'code absent' ELSE 'doublon code_diag' END, libelle
FROM silver.v_j3_diagnostic
WHERE date_ingestion = '${DATE_LOT}' AND (code_diag IS NULL OR rang > 1);

INSERT OVERWRITE TABLE gold.dim_diagnostic
SELECT id, code, nom FROM (
  SELECT -1 AS id, 'NR' AS code, 'Non renseigne' AS nom FROM gold.dual
  UNION ALL
  SELECT CAST(row_number() OVER (ORDER BY code_diag) AS INT) AS id, code_diag AS code, libelle AS nom
  FROM silver.diagnostic
) u;

INSERT INTO TABLE audit.journal_chargements
SELECT 'J3_Diagnostics', '${DATE_LOT}', from_unixtime(unix_timestamp()), sum(b), sum(s), sum(r), sum(g), 'OK'
FROM (
  SELECT CAST(n AS BIGINT) AS b, CAST(0 AS BIGINT) AS s, CAST(0 AS BIGINT) AS r, CAST(0 AS BIGINT) AS g FROM (SELECT count(*) AS n FROM bronze.diagnostic WHERE date_ingestion = '${DATE_LOT}') b0
  UNION ALL
  SELECT CAST(0 AS BIGINT) AS b, CAST(n AS BIGINT) AS s, CAST(0 AS BIGINT) AS r, CAST(0 AS BIGINT) AS g FROM (SELECT count(*) AS n FROM silver.diagnostic) s0
  UNION ALL
  SELECT CAST(0 AS BIGINT) AS b, CAST(0 AS BIGINT) AS s, CAST(n AS BIGINT) AS r, CAST(0 AS BIGINT) AS g FROM (SELECT count(*) AS n FROM silver.rejets WHERE job = 'J3_Diagnostics' AND date_lot = '${DATE_LOT}') r0
  UNION ALL
  SELECT CAST(0 AS BIGINT) AS b, CAST(0 AS BIGINT) AS s, CAST(0 AS BIGINT) AS r, CAST(n AS BIGINT) AS g FROM (SELECT count(*) AS n FROM gold.dim_diagnostic) g0
) x;
