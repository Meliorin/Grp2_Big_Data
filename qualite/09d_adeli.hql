SET mapreduce.map.memory.mb = 1024;
SET mapreduce.map.java.opts = -Xmx820m;
SET mapreduce.reduce.memory.mb = 1024;
SET mapreduce.reduce.java.opts = -Xmx820m;
SET hive.auto.convert.join = false;
-- ADELI avant correction : identifiant brut (sans le 0) retrouvé tel quel dans le fichier d'activité
INSERT INTO TABLE qualite_groupe.coherence
SELECT 'ADELI retrouve dans activite_professionnel_sante SANS correction du 0', 'bronze.professionnel_de_sante',
       count(*), count(a.identifiant)
FROM (SELECT DISTINCT identifiant FROM bronze.professionnel_de_sante WHERE type_identifiant = 'ADELI') p
LEFT JOIN (SELECT DISTINCT identifiant FROM bronze.activite_professionnel_sante) a ON a.identifiant = p.identifiant;
INSERT INTO TABLE qualite_groupe.coherence
SELECT 'ADELI retrouve dans activite_professionnel_sante AVEC correction du 0', 'bronze.professionnel_de_sante',
       count(*), count(a.identifiant)
FROM (SELECT DISTINCT CASE WHEN identifiant RLIKE '^[0-9]{8}$' THEN concat('0', identifiant) ELSE identifiant END AS identifiant
      FROM bronze.professionnel_de_sante WHERE type_identifiant = 'ADELI') p
LEFT JOIN (SELECT DISTINCT identifiant FROM bronze.activite_professionnel_sante) a ON a.identifiant = p.identifiant;
