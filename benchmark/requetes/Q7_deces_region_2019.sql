-- Q7 - Nombre de décès par région en 2019, filtre sur la colonne de partition annee
SELECT l.region, sum(f.nombre) AS deces
FROM fait_deces f JOIN dim_localisation l ON l.id = f.localisation_id
WHERE f.annee = 2019
GROUP BY l.region
ORDER BY l.region
