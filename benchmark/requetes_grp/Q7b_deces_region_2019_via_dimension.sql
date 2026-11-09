-- Q7b - Même indicateur, filtre « année = 2019 » posé sur la dimension Temps (comme un outil BI)
SELECT l.region, sum(f.nombre) AS deces
FROM fait_deces f JOIN dim_localisation l ON l.id = f.localisation_id JOIN dim_temps t ON t.id = f.temps_id
WHERE t.annee = 2019
GROUP BY l.region
ORDER BY l.region
