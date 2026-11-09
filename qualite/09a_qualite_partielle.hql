-- =====================================================================================================
-- Livrable 2 - Groupe 2 - 09_qualite_groupe.hql
-- Rapport qualité de la chaîne du groupe : complétude de la Silver, cohérence référentielle (FINESS, ADELI,
-- rattachements), doublons et rejets enregistrés par les jobs J1 à J8, journal des chargements.
-- La complétude des sources (Bronze) ne dépend pas des jobs : elle est reprise du script sql/09_qualite.sql.
-- =====================================================================================================
SET mapreduce.map.memory.mb = 1024;
SET mapreduce.map.java.opts = -Xmx820m;
SET mapreduce.reduce.memory.mb = 1024;
SET mapreduce.reduce.java.opts = -Xmx820m;
SET hive.auto.convert.join = false;
DROP DATABASE IF EXISTS qualite_groupe CASCADE;
CREATE DATABASE qualite_groupe;

-- ------------------------------------- 1. Complétude de la Silver -------------------------------------
-- Une valeur est renseignée si elle n'est ni NULL ni vide. Une seule lecture de chaque table (stack).
CREATE TABLE qualite_groupe.completude (couche STRING, table_nom STRING, colonne STRING, lignes BIGINT, renseignees BIGINT);
INSERT INTO TABLE qualite_groupe.completude
SELECT 'silver', 'etablissement', s.colonne, x.lignes, s.n
FROM (SELECT count(*) AS lignes, count(CASE WHEN identifiant_organisation IS NOT NULL AND trim(CAST(identifiant_organisation AS STRING)) <> '' THEN 1 END) AS c0,
             count(CASE WHEN type_organisation IS NOT NULL AND trim(CAST(type_organisation AS STRING)) <> '' THEN 1 END) AS c1,
             count(CASE WHEN finess_site IS NOT NULL AND trim(CAST(finess_site AS STRING)) <> '' THEN 1 END) AS c2,
             count(CASE WHEN finess_juridique IS NOT NULL AND trim(CAST(finess_juridique AS STRING)) <> '' THEN 1 END) AS c3,
             count(CASE WHEN raison_sociale IS NOT NULL AND trim(CAST(raison_sociale AS STRING)) <> '' THEN 1 END) AS c4,
             count(CASE WHEN code_commune IS NOT NULL AND trim(CAST(code_commune AS STRING)) <> '' THEN 1 END) AS c5,
             count(CASE WHEN commune IS NOT NULL AND trim(CAST(commune AS STRING)) <> '' THEN 1 END) AS c6,
             count(CASE WHEN code_postal IS NOT NULL AND trim(CAST(code_postal AS STRING)) <> '' THEN 1 END) AS c7,
             count(CASE WHEN code_departement IS NOT NULL AND trim(CAST(code_departement AS STRING)) <> '' THEN 1 END) AS c8
      FROM silver.etablissement) x
LATERAL VIEW stack(9, 'identifiant_organisation', c0, 'type_organisation', c1, 'finess_site', c2, 'finess_juridique', c3, 'raison_sociale', c4, 'code_commune', c5, 'commune', c6, 'code_postal', c7, 'code_departement', c8) s AS colonne, n;
INSERT INTO TABLE qualite_groupe.completude
SELECT 'silver', 'professionnel', s.colonne, x.lignes, s.n
FROM (SELECT count(*) AS lignes, count(CASE WHEN identifiant IS NOT NULL AND trim(CAST(identifiant AS STRING)) <> '' THEN 1 END) AS c0,
             count(CASE WHEN type_identifiant IS NOT NULL AND trim(CAST(type_identifiant AS STRING)) <> '' THEN 1 END) AS c1,
             count(CASE WHEN categorie_professionnelle IS NOT NULL AND trim(CAST(categorie_professionnelle AS STRING)) <> '' THEN 1 END) AS c2,
             count(CASE WHEN profession IS NOT NULL AND trim(CAST(profession AS STRING)) <> '' THEN 1 END) AS c3,
             count(CASE WHEN code_specialite IS NOT NULL AND trim(CAST(code_specialite AS STRING)) <> '' THEN 1 END) AS c4,
             count(CASE WHEN specialite IS NOT NULL AND trim(CAST(specialite AS STRING)) <> '' THEN 1 END) AS c5,
             count(CASE WHEN etablissement_code IS NOT NULL AND trim(CAST(etablissement_code AS STRING)) <> '' THEN 1 END) AS c6
      FROM silver.professionnel) x
LATERAL VIEW stack(7, 'identifiant', c0, 'type_identifiant', c1, 'categorie_professionnelle', c2, 'profession', c3, 'code_specialite', c4, 'specialite', c5, 'etablissement_code', c6) s AS colonne, n;
INSERT INTO TABLE qualite_groupe.completude
SELECT 'silver', 'diagnostic', s.colonne, x.lignes, s.n
FROM (SELECT count(*) AS lignes, count(CASE WHEN code_diag IS NOT NULL AND trim(CAST(code_diag AS STRING)) <> '' THEN 1 END) AS c0,
             count(CASE WHEN libelle IS NOT NULL AND trim(CAST(libelle AS STRING)) <> '' THEN 1 END) AS c1
      FROM silver.diagnostic) x
LATERAL VIEW stack(2, 'code_diag', c0, 'libelle', c1) s AS colonne, n;
INSERT INTO TABLE qualite_groupe.completude
SELECT 'silver', 'satisfaction', s.colonne, x.lignes, s.n
FROM (SELECT count(*) AS lignes, count(CASE WHEN identifiant_organisation IS NOT NULL AND trim(CAST(identifiant_organisation AS STRING)) <> '' THEN 1 END) AS c0,
             count(CASE WHEN finess_juridique IS NOT NULL AND trim(CAST(finess_juridique AS STRING)) <> '' THEN 1 END) AS c1,
             count(CASE WHEN type_score IS NOT NULL AND trim(CAST(type_score AS STRING)) <> '' THEN 1 END) AS c2,
             count(CASE WHEN score IS NOT NULL AND trim(CAST(score AS STRING)) <> '' THEN 1 END) AS c3,
             count(CASE WHEN nb_reponses IS NOT NULL AND trim(CAST(nb_reponses AS STRING)) <> '' THEN 1 END) AS c4
      FROM silver.satisfaction) x
LATERAL VIEW stack(5, 'identifiant_organisation', c0, 'finess_juridique', c1, 'type_score', c2, 'score', c3, 'nb_reponses', c4) s AS colonne, n;
CREATE TABLE qualite_groupe.coherence (controle STRING, source STRING, lignes BIGINT, conformes BIGINT);
-- Format FINESS des identifiants d'organisation en F (9 chiffres, 2A / 2B pour la Corse, 18 car. pour les officines)
INSERT INTO TABLE qualite_groupe.coherence
SELECT 'Format FINESS valide', 'silver.etablissement (codes F)', count(*),
       count(CASE WHEN identifiant_organisation RLIKE '^F([0-9]{2}|2A|2B)[0-9]{7}([0-9]{8})?$' THEN 1 END)
FROM silver.etablissement WHERE type_organisation = 'F';

-- Professionnels rattachés à une organisation, par type d'identifiant (après remise du 0 des ADELI)
INSERT INTO TABLE qualite_groupe.coherence
SELECT concat('Professionnel rattache a une organisation (', type_identifiant, ')'), 'silver.professionnel',
       count(*), count(etablissement_code)
FROM silver.professionnel GROUP BY type_identifiant;
-- e-Satis : "F" + finess_geo présent dans le référentiel, par année
INSERT INTO TABLE qualite_groupe.coherence
SELECT concat('e-Satis ', CAST(s.annee AS STRING), ' : F + finess_geo dans le referentiel'), 'silver.satisfaction',
       count(*), count(e.identifiant_organisation)
FROM silver.satisfaction s LEFT JOIN silver.etablissement e ON e.identifiant_organisation = s.identifiant_organisation
GROUP BY s.annee;
