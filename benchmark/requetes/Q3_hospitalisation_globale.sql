-- Q3 - Taux global d'hospitalisation en 2019, par mois (hospitalisations / consultations)
WITH h AS (
  SELECT t.mois, sum(f.nombre) AS nb_hospit, round(sum(f.duree_totale) / sum(f.nombre), 1) AS duree_moy_jours
  FROM fait_hospitalisation_globale f JOIN dim_temps t ON t.id = f.temps_id
  WHERE f.annee = 2019 GROUP BY t.mois
), c AS (
  SELECT t.mois, sum(f.nombre) AS nb_consult
  FROM fait_consultation_diagnostic f JOIN dim_temps t ON t.id = f.temps_id
  WHERE f.annee = 2019 GROUP BY t.mois
)
SELECT c.mois, coalesce(h.nb_hospit, 0) AS hospitalisations, c.nb_consult,
       round(100 * coalesce(h.nb_hospit, 0) / c.nb_consult, 3) AS taux_pct, h.duree_moy_jours
FROM c LEFT JOIN h ON h.mois = c.mois
ORDER BY c.mois
