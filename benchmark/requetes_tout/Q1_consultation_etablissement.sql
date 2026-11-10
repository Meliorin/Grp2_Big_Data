-- Q1 - Taux de consultation dans l'établissement X en 2019, par mois
WITH total AS (
  SELECT t.mois, sum(f.nombre) AS nb_total
  FROM fait_consultation_etablissement f JOIN dim_temps t ON t.id = f.temps_id
  WHERE f.annee = 2019 GROUP BY t.mois
), etab AS (
  SELECT t.mois, sum(f.nombre) AS nb_etab
  FROM fait_consultation_etablissement f JOIN dim_etablissement e ON e.id = f.etablissement_id
  JOIN dim_temps t ON t.id = f.temps_id
  WHERE e.code = '{{ETAB}}' AND f.annee = 2019 GROUP BY t.mois
)
SELECT total.mois, coalesce(etab.nb_etab, 0) AS consultations, total.nb_total,
       round(100 * coalesce(etab.nb_etab, 0) / total.nb_total, 3) AS taux_pct
FROM total LEFT JOIN etab ON etab.mois = total.mois
ORDER BY total.mois
