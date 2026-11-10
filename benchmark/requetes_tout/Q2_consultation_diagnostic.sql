-- Q2 - Taux de consultation pour le diagnostic X, 2018-2020 par trimestre
WITH total AS (
  SELECT t.annee, t.trimestre, sum(f.nombre) AS nb_total
  FROM fait_consultation_diagnostic f JOIN dim_temps t ON t.id = f.temps_id
  WHERE f.annee BETWEEN 2018 AND 2020 GROUP BY t.annee, t.trimestre
), diag AS (
  SELECT t.annee, t.trimestre, sum(f.nombre) AS nb_diag
  FROM fait_consultation_diagnostic f JOIN dim_diagnostic d ON d.id = f.diagnostic_id
  JOIN dim_temps t ON t.id = f.temps_id
  WHERE d.code = '{{DIAG}}' AND f.annee BETWEEN 2018 AND 2020 GROUP BY t.annee, t.trimestre
)
SELECT total.annee, total.trimestre, coalesce(diag.nb_diag, 0) AS consultations, total.nb_total,
       round(100 * coalesce(diag.nb_diag, 0) / total.nb_total, 4) AS taux_pct
FROM total LEFT JOIN diag ON diag.annee = total.annee AND diag.trimestre = total.trimestre
ORDER BY 1, 2
