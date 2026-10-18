USE mediatheque;

CREATE OR REPLACE VIEW v_catalogue AS
SELECT o.id,
       o.titre,
       o.auteur,
       o.annee_publication,
       c.libelle                          AS categorie,
       COUNT(e.id)                        AS nb_exemplaires,
       COALESCE(SUM(e.disponible = 1), 0) AS nb_disponibles
  FROM ouvrage o
  JOIN categorie c       ON c.id = o.categorie_id
  LEFT JOIN exemplaire e ON e.ouvrage_id = o.id
 GROUP BY o.id, o.titre, o.auteur, o.annee_publication, c.libelle;

CREATE OR REPLACE VIEW v_adherent_public AS
SELECT id, nom, prenom, ville, date_inscription, actif
  FROM adherent;

CREATE OR REPLACE VIEW v_emprunt_en_cours AS
SELECT em.id                                     AS emprunt_id,
       em.date_emprunt,
       em.date_retour_prevue,
       DATEDIFF(CURDATE(), em.date_retour_prevue) AS jours_de_retard,
       CONCAT(a.prenom, ' ', a.nom)              AS adherent,
       o.titre,
       ex.code_barre
  FROM emprunt em
  JOIN adherent a    ON a.id = em.adherent_id
  JOIN exemplaire ex ON ex.id = em.exemplaire_id
  JOIN ouvrage o     ON o.id = ex.ouvrage_id
 WHERE em.date_retour_reelle IS NULL;

CREATE OR REPLACE VIEW v_retard AS
SELECT emprunt_id, date_emprunt, date_retour_prevue, jours_de_retard,
       adherent, titre, code_barre
  FROM v_emprunt_en_cours
 WHERE jours_de_retard > 0;

SELECT * FROM v_catalogue WHERE nb_exemplaires = 0;
SELECT COUNT(*) AS en_cours FROM v_emprunt_en_cours;
SELECT COUNT(*) AS en_retard FROM v_retard;

REVOKE IF EXISTS SELECT (id, nom, prenom, ville, date_inscription, actif)
    ON mediatheque.adherent FROM 'stagiaire'@'localhost';
REVOKE IF EXISTS 'role_catalogue' FROM 'stagiaire'@'localhost';

GRANT SELECT ON mediatheque.v_adherent_public  TO 'stagiaire'@'localhost';
GRANT SELECT ON mediatheque.v_catalogue        TO 'stagiaire'@'localhost';
GRANT SELECT ON mediatheque.v_emprunt_en_cours TO 'stagiaire'@'localhost';

SHOW GRANTS FOR 'stagiaire'@'localhost';

-- Connecté en stagiaire :
--   SELECT * FROM v_adherent_public;   -- OK
--   SELECT * FROM adherent;            -- ERROR 1142 (42000): SELECT command denied
-- Une vue est SQL SECURITY DEFINER par défaut : les tables sont lues avec les
-- droits de son créateur, le stagiaire n'a besoin que du droit sur la vue.
