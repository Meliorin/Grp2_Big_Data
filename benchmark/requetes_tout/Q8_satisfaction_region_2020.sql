-- Q8 - Satisfaction globale par région en 2020, moyenne pondérée par le nombre de réponses
SELECT l.region, CAST(round(sum(f.satisfaction * f.nb_reponses) / sum(f.nb_reponses), 2) AS DECIMAL(5,2)) AS satisfaction,
       sum(f.nb_reponses) AS reponses, count(*) AS lignes
FROM fait_satisfaction f JOIN dim_localisation l ON l.id = f.localisation_id
JOIN dim_type_satisfaction ts ON ts.id = f.type_id
WHERE ts.code = 'Score global' AND f.annee = 2020
GROUP BY l.region
ORDER BY satisfaction DESC
