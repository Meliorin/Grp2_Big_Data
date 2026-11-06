CREATE DATABASE IF NOT EXISTS gold COMMENT 'Couche Gold : modele decisionnel du Livrable 1';

CREATE TABLE IF NOT EXISTS gold.Temps (
  id           BIGINT   COMMENT 'PK - cle au format yyyyMMdd',
  jour_semaine SMALLINT COMMENT '1 = lundi ... 7 = dimanche',
  jour         SMALLINT COMMENT 'Jour du mois',
  semaine      SMALLINT COMMENT 'Numero de semaine',
  mois         SMALLINT,
  trimestre    SMALLINT,
  semestre     SMALLINT,
  annee        SMALLINT,
  `date`       TIMESTAMP COMMENT 'Date du jour a minuit (DATE dans le L1)'
)
COMMENT 'Dimension Temps (L1)'
STORED AS PARQUET;

CREATE TABLE IF NOT EXISTS gold.Localisation (
  id          INT          COMMENT 'PK',
  commune     VARCHAR(100) COMMENT 'Nom de la commune',
  departement VARCHAR(100) COMMENT 'Departement',
  region      VARCHAR(100) COMMENT 'Region'
)
COMMENT 'Dimension Localisation (L1)'
STORED AS PARQUET;

CREATE TABLE IF NOT EXISTS gold.Etablissement (
  id           INT          COMMENT 'PK',
  code         VARCHAR(20)  COMMENT 'Code de l etablissement (identifiant_organisation / FINESS)',
  nom          VARCHAR(255) COMMENT 'Raison sociale',
  localisation INT          COMMENT 'FK -> Localisation.id'
)
COMMENT 'Dimension Etablissement (L1)'
STORED AS PARQUET;

CREATE TABLE IF NOT EXISTS gold.ProfessionnelSante (
  id                        BIGINT       COMMENT 'PK',
  categorie_professionnelle CHAR(10)     COMMENT 'Civil / Militaire / Etudiant',
  profession                VARCHAR(100) COMMENT 'Profession',
  etablissement             INT          COMMENT 'FK -> Etablissement.id'
)
COMMENT 'Dimension Professionnel de sante (L1)'
STORED AS PARQUET;

CREATE TABLE IF NOT EXISTS gold.Patient (
  id   INT      COMMENT 'PK',
  sexe CHAR(1)  COMMENT 'M / F',
  age  SMALLINT COMMENT 'Age a la date de l evenement'
)
COMMENT 'Dimension Patient anonymisee (L1)'
STORED AS PARQUET;

CREATE TABLE IF NOT EXISTS gold.Diagnostic (
  id   INT          COMMENT 'PK',
  code VARCHAR(10)  COMMENT 'Code CIM-10',
  nom  VARCHAR(255) COMMENT 'Libelle du diagnostic'
)
COMMENT 'Dimension Diagnostic (L1)'
STORED AS PARQUET;

CREATE TABLE IF NOT EXISTS gold.TypeSatisfaction (
  id      INT          COMMENT 'PK',
  libelle VARCHAR(100) COMMENT 'Global, accueil, repas, chambre...'
)
COMMENT 'Dimension Type de satisfaction (L1)'
STORED AS PARQUET;

CREATE TABLE IF NOT EXISTS gold.ConsultationEtablissement (
  etablissement INT    COMMENT 'PK, FK -> Etablissement.id',
  temps         BIGINT COMMENT 'PK, FK -> Temps.id',
  nombre        INT    COMMENT 'Nombre de consultations',
  temps_total   INT    COMMENT 'Duree totale en minutes (INTERVAL dans le L1)'
)
COMMENT 'Fait Consultation par etablissement (L1)'
STORED AS PARQUET;

CREATE TABLE IF NOT EXISTS gold.ConsultationProfessionnel (
  professionnel BIGINT COMMENT 'PK, FK -> ProfessionnelSante.id',
  nombre        INT    COMMENT 'Nombre de consultations',
  temps_total   INT    COMMENT 'Duree totale en minutes (INTERVAL dans le L1)'
)
COMMENT 'Fait Consultation par professionnel (L1)'
STORED AS PARQUET;

CREATE TABLE IF NOT EXISTS gold.ConsultationDiagnostic (
  diagnostic  INT    COMMENT 'PK, FK -> Diagnostic.id',
  temps       BIGINT COMMENT 'PK, FK -> Temps.id',
  nombre      INT    COMMENT 'Nombre de consultations',
  temps_total INT    COMMENT 'Duree totale en minutes (INTERVAL dans le L1)'
)
COMMENT 'Fait Consultation par diagnostic (L1)'
STORED AS PARQUET;

CREATE TABLE IF NOT EXISTS gold.HospitalisationGlobale (
  temps         BIGINT COMMENT 'PK, FK -> Temps.id',
  nombre        INT    COMMENT 'Nombre d hospitalisations',
  duree_moyenne FLOAT  COMMENT 'Duree moyenne de sejour en jours (REAL dans le L1)'
)
COMMENT 'Fait Hospitalisation globale (L1)'
STORED AS PARQUET;

CREATE TABLE IF NOT EXISTS gold.HospitalisationPatient (
  id           INT COMMENT 'PK, FK -> Patient.id',
  nombre       INT COMMENT 'Nombre d hospitalisations',
  duree_totale INT COMMENT 'Duree totale en jours'
)
COMMENT 'Fait Hospitalisation par patient (sexe, age) (L1)'
STORED AS PARQUET;

CREATE TABLE IF NOT EXISTS gold.HospitalisationDiagnostic (
  diagnostic   INT COMMENT 'PK, FK -> Diagnostic.id',
  nombre       INT COMMENT 'Nombre d hospitalisations',
  duree_totale INT COMMENT 'Duree totale en jours'
)
COMMENT 'Fait Hospitalisation par diagnostic (L1)'
STORED AS PARQUET;

CREATE TABLE IF NOT EXISTS gold.Deces (
  localisation INT    COMMENT 'PK, FK -> Localisation.id',
  temps        BIGINT COMMENT 'PK, FK -> Temps.id',
  nombre       INT    COMMENT 'Nombre de deces'
)
COMMENT 'Fait Deces (L1)'
STORED AS PARQUET;

CREATE TABLE IF NOT EXISTS gold.Satisfaction (
  localisation INT    COMMENT 'PK, FK -> Localisation.id',
  `type`       INT    COMMENT 'PK, FK -> TypeSatisfaction.id',
  temps        BIGINT COMMENT 'PK, FK -> Temps.id',
  satisfaction FLOAT  COMMENT 'Score moyen pondere par nb_reponses (REAL dans le L1)',
  nb_reponses  INT    COMMENT 'Nombre de reponses (sert a la ponderation)'
)
COMMENT 'Fait Satisfaction (L1)'
STORED AS PARQUET;

CREATE DATABASE IF NOT EXISTS gold_opt COMMENT 'Couche Gold optimisee : partitions et buckets';

CREATE TABLE IF NOT EXISTS gold_opt.Temps (
  id           BIGINT    COMMENT 'PK - cle au format yyyyMMdd',
  jour_semaine SMALLINT  COMMENT '1 = lundi ... 7 = dimanche',
  jour         SMALLINT  COMMENT 'Jour du mois',
  semaine      SMALLINT  COMMENT 'Numero de semaine',
  mois         SMALLINT,
  trimestre    SMALLINT,
  semestre     SMALLINT,
  annee        SMALLINT,
  `date`       TIMESTAMP COMMENT 'Date du jour a minuit (DATE dans le L1)'
)
COMMENT 'Dimension Temps (L1)'
STORED AS PARQUET;

CREATE TABLE IF NOT EXISTS gold_opt.Localisation (
  id          INT          COMMENT 'PK',
  commune     VARCHAR(100) COMMENT 'Nom de la commune',
  departement VARCHAR(100) COMMENT 'Departement',
  region      VARCHAR(100) COMMENT 'Region'
)
COMMENT 'Dimension Localisation (L1)'
CLUSTERED BY (id) SORTED BY (id) INTO 4 BUCKETS
STORED AS PARQUET;

CREATE TABLE IF NOT EXISTS gold_opt.Etablissement (
  id           INT          COMMENT 'PK',
  code         VARCHAR(20)  COMMENT 'Code de l etablissement (identifiant_organisation / FINESS)',
  nom          VARCHAR(255) COMMENT 'Raison sociale',
  localisation INT          COMMENT 'FK -> Localisation.id'
)
COMMENT 'Dimension Etablissement (L1)'
CLUSTERED BY (id) SORTED BY (id) INTO 4 BUCKETS
STORED AS PARQUET;

CREATE TABLE IF NOT EXISTS gold_opt.ProfessionnelSante (
  id                        BIGINT       COMMENT 'PK',
  categorie_professionnelle CHAR(10)     COMMENT 'Civil / Militaire / Etudiant',
  profession                VARCHAR(100) COMMENT 'Profession',
  etablissement             INT          COMMENT 'FK -> Etablissement.id'
)
COMMENT 'Dimension Professionnel de sante (L1)'
CLUSTERED BY (id) SORTED BY (id) INTO 8 BUCKETS
STORED AS PARQUET;

CREATE TABLE IF NOT EXISTS gold_opt.Patient (
  id   INT      COMMENT 'PK',
  sexe CHAR(1)  COMMENT 'M / F',
  age  SMALLINT COMMENT 'Age a la date de l evenement'
)
COMMENT 'Dimension Patient anonymisee (L1)'
STORED AS PARQUET;

CREATE TABLE IF NOT EXISTS gold_opt.Diagnostic (
  id   INT          COMMENT 'PK',
  code VARCHAR(10)  COMMENT 'Code CIM-10',
  nom  VARCHAR(255) COMMENT 'Libelle du diagnostic'
)
COMMENT 'Dimension Diagnostic (L1)'
STORED AS PARQUET;

CREATE TABLE IF NOT EXISTS gold_opt.TypeSatisfaction (
  id      INT          COMMENT 'PK',
  libelle VARCHAR(100) COMMENT 'Global, accueil, repas, chambre...'
)
COMMENT 'Dimension Type de satisfaction (L1)'
STORED AS PARQUET;

CREATE TABLE IF NOT EXISTS gold_opt.ConsultationEtablissement (
  etablissement INT    COMMENT 'PK, FK -> Etablissement.id',
  temps         BIGINT COMMENT 'PK, FK -> Temps.id',
  nombre        INT    COMMENT 'Nombre de consultations',
  temps_total   INT    COMMENT 'Duree totale en minutes (INTERVAL dans le L1)'
)
COMMENT 'Fait Consultation par etablissement (L1)'
PARTITIONED BY (annee INT)
CLUSTERED BY (etablissement) SORTED BY (etablissement) INTO 4 BUCKETS
STORED AS PARQUET;

CREATE TABLE IF NOT EXISTS gold_opt.ConsultationProfessionnel (
  professionnel BIGINT COMMENT 'PK, FK -> ProfessionnelSante.id',
  nombre        INT    COMMENT 'Nombre de consultations',
  temps_total   INT    COMMENT 'Duree totale en minutes (INTERVAL dans le L1)'
)
COMMENT 'Fait Consultation par professionnel (L1)'
CLUSTERED BY (professionnel) SORTED BY (professionnel) INTO 8 BUCKETS
STORED AS PARQUET;

CREATE TABLE IF NOT EXISTS gold_opt.ConsultationDiagnostic (
  diagnostic  INT    COMMENT 'PK, FK -> Diagnostic.id',
  temps       BIGINT COMMENT 'PK, FK -> Temps.id',
  nombre      INT    COMMENT 'Nombre de consultations',
  temps_total INT    COMMENT 'Duree totale en minutes (INTERVAL dans le L1)'
)
COMMENT 'Fait Consultation par diagnostic (L1)'
PARTITIONED BY (annee INT)
STORED AS PARQUET;

CREATE TABLE IF NOT EXISTS gold_opt.HospitalisationGlobale (
  temps         BIGINT COMMENT 'PK, FK -> Temps.id',
  nombre        INT    COMMENT 'Nombre d hospitalisations',
  duree_moyenne FLOAT  COMMENT 'Duree moyenne de sejour en jours (REAL dans le L1)'
)
COMMENT 'Fait Hospitalisation globale (L1)'
PARTITIONED BY (annee INT)
STORED AS PARQUET;

CREATE TABLE IF NOT EXISTS gold_opt.HospitalisationPatient (
  id           INT COMMENT 'PK, FK -> Patient.id',
  nombre       INT COMMENT 'Nombre d hospitalisations',
  duree_totale INT COMMENT 'Duree totale en jours'
)
COMMENT 'Fait Hospitalisation par patient (sexe, age) (L1)'
STORED AS PARQUET;

CREATE TABLE IF NOT EXISTS gold_opt.HospitalisationDiagnostic (
  diagnostic   INT COMMENT 'PK, FK -> Diagnostic.id',
  nombre       INT COMMENT 'Nombre d hospitalisations',
  duree_totale INT COMMENT 'Duree totale en jours'
)
COMMENT 'Fait Hospitalisation par diagnostic (L1)'
STORED AS PARQUET;

CREATE TABLE IF NOT EXISTS gold_opt.Deces (
  localisation INT    COMMENT 'PK, FK -> Localisation.id',
  temps        BIGINT COMMENT 'PK, FK -> Temps.id',
  nombre       INT    COMMENT 'Nombre de deces'
)
COMMENT 'Fait Deces (L1)'
PARTITIONED BY (annee INT)
CLUSTERED BY (localisation) SORTED BY (localisation) INTO 4 BUCKETS
STORED AS PARQUET;

CREATE TABLE IF NOT EXISTS gold_opt.Satisfaction (
  localisation INT    COMMENT 'PK, FK -> Localisation.id',
  `type`       INT    COMMENT 'PK, FK -> TypeSatisfaction.id',
  temps        BIGINT COMMENT 'PK, FK -> Temps.id',
  satisfaction FLOAT  COMMENT 'Score moyen pondere par nb_reponses (REAL dans le L1)',
  nb_reponses  INT    COMMENT 'Nombre de reponses (sert a la ponderation)'
)
COMMENT 'Fait Satisfaction (L1)'
PARTITIONED BY (annee INT)
STORED AS PARQUET;
