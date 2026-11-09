-- Q6 - Taux de consultation par professionnel, regroupé par profession
SELECT p.profession, count(DISTINCT f.professionnel_id) AS professionnels, sum(f.nombre) AS consultations,
       round(sum(f.nombre) / count(DISTINCT f.professionnel_id), 2) AS consult_par_pro,
       round(sum(f.duree_totale) / sum(f.nombre), 1) AS duree_moyenne_min
FROM fait_consultation_professionnel f JOIN dim_professionnel p ON p.id = f.professionnel_id
GROUP BY p.profession
ORDER BY consultations DESC
