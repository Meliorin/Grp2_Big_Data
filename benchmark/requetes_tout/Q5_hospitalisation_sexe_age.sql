-- Q5 - Taux d'hospitalisation par sexe et tranche d'âge de 10 ans (rapporté à la population de patients)
WITH h AS (
  SELECT p.sexe, cast(floor(p.age / 10) * 10 AS INT) AS tranche, f.annee, sum(f.nombre) AS nb, sum(f.duree_totale) AS duree
  FROM fait_hospitalisation_patient f JOIN dim_patient p ON p.id = f.patient_id
  GROUP BY p.sexe, cast(floor(p.age / 10) * 10 AS INT), f.annee
), pop AS (
  SELECT p.sexe, cast(floor(p.age / 10) * 10 AS INT) AS tranche, f.annee, sum(f.nombre) AS patients
  FROM fait_population_patient f JOIN dim_patient p ON p.id = f.patient_id
  GROUP BY p.sexe, cast(floor(p.age / 10) * 10 AS INT), f.annee
)
SELECT h.sexe, h.tranche AS tranche_age, sum(h.nb) AS hospitalisations, sum(pop.patients) AS patients_annees,
       round(100 * sum(h.nb) / sum(pop.patients), 2) AS taux_pct, round(sum(h.duree) / sum(h.nb), 1) AS duree_moy_jours
FROM h LEFT JOIN pop ON pop.sexe = h.sexe AND pop.tranche = h.tranche AND pop.annee = h.annee
GROUP BY h.sexe, h.tranche
ORDER BY h.sexe, tranche_age
