-- Q4 - Taux d'hospitalisation par diagnostic, toutes années, top 15
WITH c AS (SELECT diagnostic_id, sum(nombre) AS nb_consult FROM fait_consultation_diagnostic GROUP BY diagnostic_id),
     h AS (SELECT diagnostic_id, sum(nombre) AS nombre, sum(duree_totale) AS duree_totale
           FROM fait_hospitalisation_diagnostic GROUP BY diagnostic_id)
SELECT d.code, d.nom, h.nombre AS hospitalisations, c.nb_consult,
       round(100 * h.nombre / nullif(c.nb_consult, 0), 2) AS taux_pct,
       round(h.duree_totale / h.nombre, 1) AS duree_moy_jours
FROM h JOIN dim_diagnostic d ON d.id = h.diagnostic_id
LEFT JOIN c ON c.diagnostic_id = h.diagnostic_id
ORDER BY h.nombre DESC, d.code
LIMIT 15
