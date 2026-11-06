-- =====================================================================
-- J4 - Patients (pseudonymisation RGPD)
-- Source : PostgreSQL Patient (tPostgresqlInput -> tHDFSOutput)
-- Variables : ${DATE_LOT}, ${SEL} (sel de hachage, jamais ecrit dans le code)
-- Les donnees identifiantes restent en Bronze (acces compte ETL uniquement).
-- =====================================================================
-- Memoire des taches MapReduce (la VM ne donne que 128 Mo par defaut)
SET mapreduce.map.memory.mb = 1024;
SET mapreduce.map.java.opts = -Xmx820m;
SET mapreduce.reduce.memory.mb = 1024;
SET mapreduce.reduce.java.opts = -Xmx820m;
SET hive.auto.convert.join = false;

ALTER TABLE bronze.patient ADD IF NOT EXISTS PARTITION (date_ingestion = '${DATE_LOT}');

-- Conversion du sexe PostgreSQL : 'male' -> M, 'female' -> F, sinon I (inconnu)
INSERT OVERWRITE TABLE silver.patient
SELECT sha2(concat('${SEL}', id_patient), 256),
       CASE lower(sexe) WHEN 'male' THEN 'M' WHEN 'female' THEN 'F' ELSE 'I' END,
       date_naissance, code_postal,
       CASE WHEN substr(code_postal, 1, 2) IN ('97', '98') THEN substr(code_postal, 1, 3)
            WHEN substr(code_postal, 1, 2) = '20' THEN (CASE WHEN code_postal < '20200' THEN '2A' ELSE '2B' END)
            ELSE substr(code_postal, 1, 2) END
FROM silver.v_j4_patient
WHERE date_ingestion = '${DATE_LOT}' AND id_patient IS NOT NULL AND date_naissance IS NOT NULL AND rang = 1;

-- Les rejets ne contiennent que le hash (jamais l'identifiant en clair)
INSERT OVERWRITE TABLE silver.rejets PARTITION (job = 'J4_Patients', date_lot = '${DATE_LOT}')
SELECT 'Patient', coalesce(sha2(concat('${SEL}', id_patient), 256), ''),
       CASE WHEN id_patient IS NULL THEN 'identifiant absent'
            WHEN date_naissance IS NULL THEN 'date de naissance invalide'
            ELSE 'doublon id_patient' END,
       sexe
FROM silver.v_j4_patient
WHERE date_ingestion = '${DATE_LOT}' AND (id_patient IS NULL OR date_naissance IS NULL OR rang > 1);

-- Effectif de patients par (sexe, age) et par annee : denominateur des taux
INSERT OVERWRITE TABLE gold.fait_population_patient
SELECT CASE p.sexe WHEN 'M' THEN 1000 WHEN 'F' THEN 2000 ELSE 3000 END + (y.annee - year(p.date_naissance)),
       y.annee, CAST(count(*) AS INT)
FROM silver.patient p
CROSS JOIN (SELECT 2014 + pos AS annee FROM gold.dual LATERAL VIEW posexplode(split(space(9), ' ')) t AS pos, v) y
WHERE y.annee - year(p.date_naissance) BETWEEN 0 AND 120
GROUP BY CASE p.sexe WHEN 'M' THEN 1000 WHEN 'F' THEN 2000 ELSE 3000 END + (y.annee - year(p.date_naissance)), y.annee;

INSERT INTO TABLE audit.journal_chargements
SELECT 'J4_Patients', '${DATE_LOT}', from_unixtime(unix_timestamp()), sum(b), sum(s), sum(r), sum(g), 'OK'
FROM (
  SELECT CAST(n AS BIGINT) AS b, CAST(0 AS BIGINT) AS s, CAST(0 AS BIGINT) AS r, CAST(0 AS BIGINT) AS g FROM (SELECT count(*) AS n FROM bronze.patient WHERE date_ingestion = '${DATE_LOT}') b0
  UNION ALL
  SELECT CAST(0 AS BIGINT) AS b, CAST(n AS BIGINT) AS s, CAST(0 AS BIGINT) AS r, CAST(0 AS BIGINT) AS g FROM (SELECT count(*) AS n FROM silver.patient) s0
  UNION ALL
  SELECT CAST(0 AS BIGINT) AS b, CAST(0 AS BIGINT) AS s, CAST(n AS BIGINT) AS r, CAST(0 AS BIGINT) AS g FROM (SELECT count(*) AS n FROM silver.rejets WHERE job = 'J4_Patients' AND date_lot = '${DATE_LOT}') r0
  UNION ALL
  SELECT CAST(0 AS BIGINT) AS b, CAST(0 AS BIGINT) AS s, CAST(0 AS BIGINT) AS r, CAST(n AS BIGINT) AS g FROM (SELECT count(*) AS n FROM gold.fait_population_patient) g0
) x;
