USE mediatheque;

CREATE OR REPLACE VIEW v_adherent_lyon AS
SELECT id, nom, prenom, email, telephone, date_naissance,
       ville, date_inscription, actif
  FROM adherent
 WHERE ville = 'Lyon'
  WITH CHECK OPTION;

DELETE FROM adherent WHERE email IN ('claire.test@exemple.fr', 'paul.test@exemple.fr');

INSERT INTO v_adherent_lyon (nom, prenom, email, ville, date_inscription)
VALUES ('Test', 'Claire', 'claire.test@exemple.fr', 'Lyon', CURDATE());

SELECT id, nom, prenom, ville FROM adherent WHERE email = 'claire.test@exemple.fr';

-- INSERT INTO v_adherent_lyon (nom, prenom, email, ville, date_inscription)
-- VALUES ('Test', 'Paul', 'paul.test@exemple.fr', 'Bron', CURDATE());
--   ERROR 1369 (HY000): CHECK OPTION failed 'mediatheque.v_adherent_lyon'
-- Le serveur refuse une ligne qui ne respecte pas le WHERE de la vue.

-- UPDATE v_catalogue SET titre = 'Nouveau titre' WHERE id = 1;
--   ERROR 1288 (HY000): The target table v_catalogue of the UPDATE is not updatable
-- Une ligne de la vue vient d'un GROUP BY : elle ne correspond à aucune ligne
-- précise d'une table.

SELECT table_name, is_updatable
  FROM information_schema.views
 WHERE table_schema = 'mediatheque'
 ORDER BY table_name;

-- v_catalogue = NO : GROUP BY et agrégats (COUNT, SUM), le serveur ne sait pas
-- quelle ligne de quelle table modifier. Les quatre autres sont YES.

-- Sans ce DELETE, 03-volume.sql échoue (ERROR 1452) : il tire des adherent_id
-- entre 1 et COUNT(*), et l'id 41 n'existe pas.
DELETE FROM adherent WHERE email = 'claire.test@exemple.fr';
