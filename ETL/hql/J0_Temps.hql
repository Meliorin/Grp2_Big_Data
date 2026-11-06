-- =====================================================================
-- J0 - Chargement de la dimension Temps
-- Source : /datalake/bronze/temps/temps.csv, genere par Talend
--          (tRowGenerator -> tMap -> tHDFSOutput), 01/01/2014 -> 31/12/2023
-- Prerequis : 00_DDL.hql execute une fois
-- =====================================================================
-- Memoire des taches MapReduce (la VM ne donne que 128 Mo par defaut)
SET mapreduce.map.memory.mb = 1024;
SET mapreduce.map.java.opts = -Xmx820m;
SET mapreduce.reduce.memory.mb = 1024;
SET mapreduce.reduce.java.opts = -Xmx820m;

INSERT OVERWRITE TABLE gold.dim_temps
SELECT id, date_jour, jour_semaine, jour, semaine, mois, trimestre, semestre, annee
FROM bronze.temps_genere
WHERE id IS NOT NULL;

INSERT INTO TABLE audit.journal_chargements
SELECT 'J0_Temps', '${DATE_LOT}', from_unixtime(unix_timestamp()), sum(b), sum(s), sum(r), sum(g), 'OK'
FROM (
  SELECT CAST(n AS BIGINT) AS b, CAST(0 AS BIGINT) AS s, CAST(0 AS BIGINT) AS r, CAST(0 AS BIGINT) AS g FROM (SELECT count(*) AS n FROM bronze.temps_genere) b0
  UNION ALL
  SELECT CAST(0 AS BIGINT) AS b, CAST(0 AS BIGINT) AS s, CAST(0 AS BIGINT) AS r, CAST(n AS BIGINT) AS g FROM (SELECT count(*) AS n FROM gold.dim_temps) g0
) x;
