-- Q9 - Évolution mensuelle des décès sur toute la période chargée (aucun filtre sur la partition : lecture complète)
SELECT t.annee, t.mois, sum(f.nombre) AS deces
FROM fait_deces f JOIN dim_temps t ON t.id = f.temps_id
GROUP BY t.annee, t.mois
ORDER BY t.annee, t.mois
