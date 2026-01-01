USE bibliotheque;
WITH RECURSIVE calendrier AS (
  SELECT 2025 AS annee, 1 AS mois
  UNION ALL
  SELECT annee, mois + 1
  FROM calendrier
  WHERE mois < 12
),

base_emprunts_2025 AS (
  SELECT
    YEAR(e.date_debut) AS annee,
    MONTH(e.date_debut) AS mois,
    e.abonne_id,
    e.ouvrage_id
  FROM emprunt e
  WHERE YEAR(e.date_debut) = 2025
),

indicateurs_mensuels AS (
  SELECT
    be.annee,
    be.mois,
    COUNT(*) AS total_emprunts,
    COUNT(DISTINCT be.abonne_id) AS abonnes_actifs
  FROM base_emprunts_2025 be
  GROUP BY be.annee, be.mois
),

ouvrages_mensuels AS (
  SELECT
    be.annee,
    be.mois,
    be.ouvrage_id,
    COUNT(*) AS nb_emprunts
  FROM base_emprunts_2025 be
  GROUP BY be.annee, be.mois, be.ouvrage_id
),

top_ouvrages_mensuels AS (
  SELECT
    om.annee,
    om.mois,
    om.ouvrage_id,
    o.titre,
    om.nb_emprunts,
    ROW_NUMBER() OVER (
      PARTITION BY om.annee, om.mois
      ORDER BY om.nb_emprunts DESC, om.ouvrage_id ASC
    ) AS rn
  FROM ouvrages_mensuels om
  JOIN ouvrage o ON o.id = om.ouvrage_id
),

top3_titres_mensuels AS (
  SELECT
    t.annee,
    t.mois,
    GROUP_CONCAT(t.titre ORDER BY t.nb_emprunts DESC, t.ouvrage_id ASC SEPARATOR ', ') AS top3_ouvrages
  FROM top_ouvrages_mensuels t
  WHERE t.rn <= 3
  GROUP BY t.annee, t.mois
),

ouvrages_empruntes_mensuels AS (
  SELECT
    be.annee,
    be.mois,
    COUNT(DISTINCT be.ouvrage_id) AS ouvrages_empruntes
  FROM base_emprunts_2025 be
  GROUP BY be.annee, be.mois
),


total_ouvrages AS (
  SELECT COUNT(*) AS total_ouvrages FROM ouvrage
)

SELECT
  c.annee,
  c.mois,
  COALESCE(im.total_emprunts, 0) AS total_emprunts,
  COALESCE(im.abonnes_actifs, 0) AS abonnes_actifs,
  
  CASE
    WHEN COALESCE(im.abonnes_actifs, 0) = 0 THEN 0
    ELSE ROUND(COALESCE(im.total_emprunts, 0) / COALESCE(im.abonnes_actifs, 0), 2)
  END AS moyenne_par_abonne,
 
  CASE
    WHEN (SELECT total_ouvrages FROM total_ouvrages) = 0 THEN 0
    ELSE ROUND(
      COALESCE(oem.ouvrages_empruntes, 0) * 100
      / (SELECT total_ouvrages FROM total_ouvrages),
      2
    )
  END AS pct_empruntes,
  COALESCE(t3.top3_ouvrages, '') AS top3_ouvrages
FROM calendrier c
LEFT JOIN indicateurs_mensuels im
  ON im.annee = c.annee AND im.mois = c.mois
LEFT JOIN ouvrages_empruntes_mensuels oem
  ON oem.annee = c.annee AND oem.mois = c.mois
LEFT JOIN top3_titres_mensuels t3
  ON t3.annee = c.annee AND t3.mois = c.mois
ORDER BY c.annee, c.mois;
