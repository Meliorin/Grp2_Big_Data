-- Q10 - Dix départements avec le plus de décès en 2020-2021 (filtre sur deux partitions annee)
SELECT l.code_departement, l.departement, sum(f.nombre) AS deces
FROM fait_deces f JOIN dim_localisation l ON l.id = f.localisation_id
WHERE f.annee IN (2020, 2021)
GROUP BY l.code_departement, l.departement
ORDER BY deces DESC
LIMIT 10
