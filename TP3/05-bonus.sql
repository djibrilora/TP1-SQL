USE mediatheque;

-- app_media tient INSERT et UPDATE sur emprunt du rôle role_prets : on lui
-- retire le rôle (sans toucher au rôle, utilisé par biblio_marie) et on lui
-- redonne le reste à la main.
REVOKE IF EXISTS 'role_prets' FROM 'app_media'@'localhost';

GRANT SELECT                 ON mediatheque.emprunt     TO 'app_media'@'localhost';
GRANT SELECT, INSERT, UPDATE ON mediatheque.reservation TO 'app_media'@'localhost';
GRANT SELECT, INSERT, UPDATE ON mediatheque.penalite    TO 'app_media'@'localhost';

GRANT EXECUTE ON PROCEDURE mediatheque.p_emprunter TO 'app_media'@'localhost';
GRANT EXECUTE ON PROCEDURE mediatheque.p_rendre    TO 'app_media'@'localhost';

SHOW GRANTS FOR 'app_media'@'localhost' USING 'role_catalogue';

-- Connecté en app_media :
--   CALL p_emprunter(@code, 3, @id);   -- OK
--   INSERT INTO emprunt (exemplaire_id, adherent_id) VALUES (20, 3);
--     ERROR 1142 (42000): INSERT command denied to user 'app_media'@'localhost'
--     for table 'emprunt'
-- Une procédure est SQL SECURITY DEFINER par défaut : elle s'exécute avec les
-- droits de son créateur. app_media n'a besoin que d'EXECUTE, et ne peut
-- emprunter qu'en passant par les règles de p_emprunter.

-- time mysql -u root -p < Base/03-volume.sql
--   avec les triggers : 22,7 s et 26,9 s
--   sans les triggers :  8,8 s et  8,5 s
-- Environ 3 fois plus lent : le trigger s'exécute pour chacune des 200 000
-- lignes (et journal_action prend 200 000 lignes). Pour un chargement en
-- masse, on supprime les triggers puis on les recrée.
