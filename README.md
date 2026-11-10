# Grp2_Big_Data
Big Data project for CESI A4 students

## Chaîne ETL (Hive sur la VM Cloudera)

| Fichier | Rôle |
|---|---|
| `ETL/hql/00_DDL.hql` | **À lancer une fois avant les jobs.** Crée les bases `bronze`, `silver`, `gold`, `audit`, les tables Bronze (fichiers déposés par Talend dans `/datalake/bronze/...`), les vues de nettoyage `silver.v_j1_etablissement` à `silver.v_j8_satisfaction`, les tables Silver, Gold (`dim_*`, `fait_*`), `gold.dual`, `audit.journal_chargements`, et remplit les tables fixes (`dim_type_satisfaction`, `dim_patient`). |
| `ETL/hql/J0_Temps.hql` à `J8_Satisfaction.hql` | Jobs de chargement Bronze → Silver → Gold (lancés par les tHiveRow des jobs Talend). |
| `ETL/talend/` | Jobs Talend : dépôt des sources dans HDFS, puis exécution des requêtes Hive. |
| `SQL/DDL_modele_L1.sql` | Modèle Gold du livrable 1 (noms du L1) et version `gold_opt`. |

Les jobs Talend ne créent ni les tables ni les vues : ils ajoutent seulement la partition du lot
(`ALTER TABLE ... ADD PARTITION`) et lancent les `INSERT`. Sans `00_DDL.hql`, J0 échoue dès la
première requête (`bronze.temps_genere` introuvable).

Ordre d'exécution :

```bash
hive -f ETL/hql/00_DDL.hql        # après le dépôt de temps.csv dans /datalake/bronze/temps
# puis les jobs Talend J0 à J8 (ou J9_Orchestration), qui passent DATE_LOT et SEL aux requêtes
```

À prévoir côté données : le fichier `Referentiel/ref_departement_region.csv`
(`code_departement;nom_departement;region`), utilisé par J1, n'est pas fourni dans les données du projet.

## Contrôle qualité et benchmark (livrable 2)

| Fichier | Rôle |
|---|---|
| `qualite/09_qualite_groupe.hql` | Contrôle qualité complet de la chaîne Hive (complétude, cohérence FINESS/ADELI, orphelins, rejets, journal, volumes) dans la base `qualite_groupe`. |
| `qualite/09a_qualite_partielle.hql`, `09b_...`, `09c_volumes_adeli.hql`, `09d_adeli.hql` | Version découpée lancée le 09/11 sur les tables chargées par J1 à J4, J7 et J8 (J5 et J6 non exécutés). |
| `qualite/09e_consultations_hospitalisations.hql` | Complétude, cohérence et orphelins des consultations et hospitalisations (lancé le 10/11 après J5 et J6). |
| `benchmark/01_gold_brut.sql`, `01b_gold_brut_partiel.sql` | Impala : base `gold_brut_grp`, mêmes données que `gold` en Parquet sans partition (référence « avant »). |
| `benchmark/02_gold_opt_buckets.hql` | Hive : base `gold_opt` (partitions + buckets). |
| `benchmark/requetes/`, `benchmark/requetes_grp/` | Requêtes du benchmark (Q1 à Q8 sur toute la Gold ; Q7 à Q11 sur décès et satisfaction). |
| `benchmark/requetes_tout/` | Les 12 requêtes (Q1 à Q11 et Q7b) sur la Gold complète du groupe. |
| `benchmark/bench_impala.js`, `graphiques.js` | Mesure (1 chauffe + 3 exécutions, médiane) par scénario `avant`, `stats`, `partition`, `partition_stats`, `buckets`, puis graphiques PNG. |

## Mise à jour du rapport

| Fichier | Rôle |
|---|---|
| `rapport/gen_maj.js` | Lit les exports qualité (TSV) et les résultats du benchmark et prépare les tableaux et textes à remplacer. |
| `rapport/maj_chaine_complete.ps1` | Applique ces remplacements dans le Word du livrable (tableaux, paragraphes, graphiques, sommaire). |
