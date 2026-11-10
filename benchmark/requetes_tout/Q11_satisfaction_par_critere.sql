-- Q11 - Satisfaction moyenne pondérée par critère e-Satis et par année
SELECT f.annee, ts.code AS critere, CAST(round(sum(f.satisfaction * f.nb_reponses) / sum(f.nb_reponses), 2) AS DECIMAL(5,2)) AS satisfaction
FROM fait_satisfaction f JOIN dim_type_satisfaction ts ON ts.id = f.type_id
GROUP BY f.annee, ts.code
ORDER BY f.annee, ts.code
