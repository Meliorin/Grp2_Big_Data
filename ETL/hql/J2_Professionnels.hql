-- =====================================================================
-- J2 - Professionnels de sante
-- Sources : PostgreSQL Professionnel_de_sante + Specialites (tPostgresqlInput -> tHDFSOutput)
--           activite_professionnel_sante.csv (tHDFSPut)
-- Prerequis : J1
-- =====================================================================
-- Memoire des taches MapReduce (la VM ne donne que 128 Mo par defaut)
SET mapreduce.map.memory.mb = 1024;
SET mapreduce.map.java.opts = -Xmx820m;
SET mapreduce.reduce.memory.mb = 1024;
SET mapreduce.reduce.java.opts = -Xmx820m;
SET hive.auto.convert.join = false;

ALTER TABLE bronze.professionnel_de_sante ADD IF NOT EXISTS PARTITION (date_ingestion = '${DATE_LOT}');
ALTER TABLE bronze.specialites ADD IF NOT EXISTS PARTITION (date_ingestion = '${DATE_LOT}');
ALTER TABLE bronze.activite_professionnel_sante ADD IF NOT EXISTS PARTITION (date_ingestion = '${DATE_LOT}');

-- ---------- SILVER ----------
INSERT OVERWRITE TABLE silver.professionnel
SELECT p.identifiant, p.type_identifiant, p.categorie_professionnelle, p.profession, p.code_specialite,
       coalesce(trim(s.specialite), 'Inconnu'), r.etablissement_code
FROM silver.v_j2_professionnel p
LEFT JOIN (SELECT code_specialite, max(specialite) AS specialite FROM bronze.specialites
           WHERE date_ingestion = '${DATE_LOT}' GROUP BY code_specialite) s ON s.code_specialite = p.code_specialite
LEFT JOIN (SELECT identifiant, etablissement_code FROM silver.v_j2_rattachement
           WHERE date_ingestion = '${DATE_LOT}') r ON r.identifiant = p.identifiant
WHERE p.date_ingestion = '${DATE_LOT}' AND p.identifiant IS NOT NULL AND p.rang = 1;

INSERT OVERWRITE TABLE silver.rejets PARTITION (job = 'J2_Professionnels', date_lot = '${DATE_LOT}')
SELECT 'Professionnel_de_sante', coalesce(identifiant, ''),
       CASE WHEN identifiant IS NULL THEN 'identifiant absent' ELSE 'doublon identifiant' END,
       concat_ws('|', coalesce(profession, ''), coalesce(code_specialite, ''))
FROM silver.v_j2_professionnel
WHERE date_ingestion = '${DATE_LOT}' AND (identifiant IS NULL OR rang > 1);

-- ---------- GOLD ----------
INSERT OVERWRITE TABLE gold.dim_professionnel
SELECT id, identifiant, categorie_professionnelle, profession, specialite, etablissement_id FROM (
  SELECT -1 AS id, 'NR' AS identifiant, 'Non renseigne' AS categorie_professionnelle, 'Non renseigne' AS profession,
         'Non renseigne' AS specialite, -1 AS etablissement_id
  FROM gold.dual
  UNION ALL
  SELECT CAST(row_number() OVER (ORDER BY p.identifiant) AS INT) AS id, p.identifiant AS identifiant,
         p.categorie_professionnelle AS categorie_professionnelle, p.profession AS profession,
         p.specialite AS specialite, coalesce(e.id, -1) AS etablissement_id
  FROM silver.professionnel p
  LEFT JOIN gold.dim_etablissement e ON e.code = p.etablissement_code
) u;

-- ---------- AUDIT ----------
INSERT INTO TABLE audit.journal_chargements
SELECT 'J2_Professionnels', '${DATE_LOT}', from_unixtime(unix_timestamp()), sum(b), sum(s), sum(r), sum(g), 'OK'
FROM (
  SELECT CAST(n AS BIGINT) AS b, CAST(0 AS BIGINT) AS s, CAST(0 AS BIGINT) AS r, CAST(0 AS BIGINT) AS g FROM (SELECT count(*) AS n FROM bronze.professionnel_de_sante WHERE date_ingestion = '${DATE_LOT}') b0
  UNION ALL
  SELECT CAST(0 AS BIGINT) AS b, CAST(n AS BIGINT) AS s, CAST(0 AS BIGINT) AS r, CAST(0 AS BIGINT) AS g FROM (SELECT count(*) AS n FROM silver.professionnel) s0
  UNION ALL
  SELECT CAST(0 AS BIGINT) AS b, CAST(0 AS BIGINT) AS s, CAST(n AS BIGINT) AS r, CAST(0 AS BIGINT) AS g FROM (SELECT count(*) AS n FROM silver.rejets WHERE job = 'J2_Professionnels' AND date_lot = '${DATE_LOT}') r0
  UNION ALL
  SELECT CAST(0 AS BIGINT) AS b, CAST(0 AS BIGINT) AS s, CAST(0 AS BIGINT) AS r, CAST(n AS BIGINT) AS g FROM (SELECT count(*) AS n FROM gold.dim_professionnel) g0
) x;
