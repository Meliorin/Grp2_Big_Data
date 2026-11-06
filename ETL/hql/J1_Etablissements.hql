-- =====================================================================
-- J1 - Etablissements + Localisation
-- Sources (tHDFSPut) : etablissement_sante.csv, ref_departement_region.csv
-- Sorties : silver.ref_departement, silver.etablissement,
--           gold.dim_localisation, gold.dim_etablissement
-- =====================================================================
-- Memoire des taches MapReduce (la VM ne donne que 128 Mo par defaut)
SET mapreduce.map.memory.mb = 1024;
SET mapreduce.map.java.opts = -Xmx820m;
SET mapreduce.reduce.memory.mb = 1024;
SET mapreduce.reduce.java.opts = -Xmx820m;
SET hive.auto.convert.join = false;

-- Declaration du lot du jour dans les tables Bronze
ALTER TABLE bronze.etablissement_sante ADD IF NOT EXISTS PARTITION (date_ingestion = '${DATE_LOT}');
ALTER TABLE bronze.ref_departement_region ADD IF NOT EXISTS PARTITION (date_ingestion = '${DATE_LOT}');

-- ---------- SILVER ----------
INSERT OVERWRITE TABLE silver.ref_departement
SELECT trim(code_departement), trim(nom_departement), trim(region)
FROM bronze.ref_departement_region
WHERE date_ingestion = '${DATE_LOT}' AND trim(code_departement) <> '';

INSERT OVERWRITE TABLE silver.etablissement
SELECT identifiant_organisation, substr(identifiant_organisation, 1, 1), finess_site, finess_juridique,
       raison_sociale, code_commune, commune, code_postal, code_departement
FROM silver.v_j1_etablissement
WHERE date_ingestion = '${DATE_LOT}' AND identifiant_organisation IS NOT NULL AND rang = 1;

-- Rejets : identifiant absent / doublon sur la cle metier
INSERT OVERWRITE TABLE silver.rejets PARTITION (job = 'J1_Etablissements', date_lot = '${DATE_LOT}')
SELECT 'etablissement_sante.csv', coalesce(identifiant_organisation, ''),
       CASE WHEN identifiant_organisation IS NULL THEN 'identifiant absent' ELSE 'doublon identifiant_organisation' END,
       concat_ws('|', coalesce(raison_sociale, ''), coalesce(code_commune, ''), coalesce(code_postal, ''))
FROM silver.v_j1_etablissement
WHERE date_ingestion = '${DATE_LOT}' AND (identifiant_organisation IS NULL OR rang > 1);

-- ---------- GOLD ----------
-- Une ligne par commune connue + une ligne "commune inconnue" par departement
INSERT OVERWRITE TABLE gold.dim_localisation
SELECT id, code_commune, commune, code_departement, departement, region FROM (
  SELECT -1 AS id, 'NR' AS code_commune, 'Non renseigne' AS commune, 'NR' AS code_departement,
         'Non renseigne' AS departement, 'Non renseigne' AS region
  FROM gold.dual
  UNION ALL
  SELECT CAST(row_number() OVER (ORDER BY c.code_commune) AS INT) AS id, c.code_commune AS code_commune,
         c.commune AS commune, c.code_departement AS code_departement,
         coalesce(r.nom_departement, 'Inconnu') AS departement, coalesce(r.region, 'Inconnu') AS region
  FROM (
    SELECT code_commune, max(commune) AS commune, max(code_departement) AS code_departement
    FROM silver.etablissement WHERE code_commune IS NOT NULL GROUP BY code_commune
    UNION ALL
    SELECT concat('D', code_departement) AS code_commune, 'Inconnu' AS commune, code_departement
    FROM silver.ref_departement
  ) c
  LEFT JOIN silver.ref_departement r ON c.code_departement = r.code_departement
) u;

-- Etablissements de sante uniquement (codes F)
INSERT OVERWRITE TABLE gold.dim_etablissement
SELECT id, code, finess, nom, localisation_id FROM (
  SELECT -1 AS id, 'NR' AS code, 'NR' AS finess, 'Non renseigne' AS nom, -1 AS localisation_id FROM gold.dual
  UNION ALL
  SELECT CAST(row_number() OVER (ORDER BY e.identifiant_organisation) AS INT) AS id,
         e.identifiant_organisation AS code, e.finess_site AS finess, e.raison_sociale AS nom,
         coalesce(lc.id, ld.id, -1) AS localisation_id
  FROM silver.etablissement e
  LEFT JOIN gold.dim_localisation lc ON lc.code_commune = e.code_commune
  LEFT JOIN gold.dim_localisation ld ON ld.code_commune = concat('D', e.code_departement)
  WHERE e.type_organisation = 'F'
) u;

-- ---------- AUDIT ----------
INSERT INTO TABLE audit.journal_chargements
SELECT 'J1_Etablissements', '${DATE_LOT}', from_unixtime(unix_timestamp()), sum(b), sum(s), sum(r), sum(g), 'OK'
FROM (
  SELECT CAST(n AS BIGINT) AS b, CAST(0 AS BIGINT) AS s, CAST(0 AS BIGINT) AS r, CAST(0 AS BIGINT) AS g FROM (SELECT count(*) AS n FROM bronze.etablissement_sante WHERE date_ingestion = '${DATE_LOT}') b0
  UNION ALL
  SELECT CAST(0 AS BIGINT) AS b, CAST(n AS BIGINT) AS s, CAST(0 AS BIGINT) AS r, CAST(0 AS BIGINT) AS g FROM (SELECT count(*) AS n FROM silver.etablissement) s0
  UNION ALL
  SELECT CAST(0 AS BIGINT) AS b, CAST(0 AS BIGINT) AS s, CAST(n AS BIGINT) AS r, CAST(0 AS BIGINT) AS g FROM (SELECT count(*) AS n FROM silver.rejets WHERE job = 'J1_Etablissements' AND date_lot = '${DATE_LOT}') r0
  UNION ALL
  SELECT CAST(0 AS BIGINT) AS b, CAST(0 AS BIGINT) AS s, CAST(0 AS BIGINT) AS r, CAST(n AS BIGINT) AS g FROM (SELECT count(*) AS n FROM gold.dim_etablissement) g0
) x;
