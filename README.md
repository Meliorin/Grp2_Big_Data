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
