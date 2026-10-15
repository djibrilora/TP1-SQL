DROP ROLE IF EXISTS 'role_catalogue'@'%';
DROP ROLE IF EXISTS 'role_prets'@'%';
DROP ROLE IF EXISTS 'role_adherents'@'%';

DROP USER IF EXISTS 'app_media'@'localhost';
DROP USER IF EXISTS 'analyste'@'localhost';
DROP USER IF EXISTS 'biblio_marie'@'localhost';
DROP USER IF EXISTS 'stagiaire'@'localhost';

CREATE ROLE 'role_catalogue';
CREATE ROLE 'role_prets';
CREATE ROLE 'role_adherents';

GRANT SELECT ON mediatheque.ouvrage TO 'role_catalogue';
GRANT SELECT ON mediatheque.exemplaire TO 'role_catalogue';
GRANT SELECT ON mediatheque.categorie TO 'role_catalogue';

GRANT SELECT, INSERT, UPDATE ON mediatheque.emprunt TO 'role_prets';
GRANT SELECT, INSERT, UPDATE ON mediatheque.reservation TO 'role_prets';
GRANT SELECT, INSERT, UPDATE ON mediatheque.penalite TO 'role_prets';
GRANT UPDATE (disponible) ON mediatheque.exemplaire TO 'role_prets';

GRANT SELECT, INSERT, UPDATE ON mediatheque.adherent TO 'role_adherents';

CREATE USER IF NOT EXISTS 'app_media'@'localhost' IDENTIFIED BY 'AppMedia!2026';
CREATE USER IF NOT EXISTS 'analyste'@'localhost' IDENTIFIED BY 'Analyste!2026';
CREATE USER IF NOT EXISTS 'biblio_marie'@'localhost' IDENTIFIED BY 'BiblioMarie!2026';
CREATE USER IF NOT EXISTS 'stagiaire'@'localhost' IDENTIFIED BY 'Stagiaire!2026';

GRANT SELECT (id, nom, prenom, actif) ON mediatheque.adherent TO 'app_media'@'localhost';
GRANT SELECT (id, nom, prenom, ville, date_inscription, actif) ON mediatheque.adherent TO 'stagiaire'@'localhost';
GRANT SELECT ON mediatheque.emprunt TO 'analyste'@'localhost';

GRANT 'role_catalogue', 'role_prets' TO 'app_media'@'localhost';
GRANT 'role_catalogue', 'role_prets', 'role_adherents' TO 'biblio_marie'@'localhost';
GRANT 'role_catalogue' TO 'stagiaire'@'localhost';
GRANT 'role_catalogue' TO 'analyste'@'localhost';

ALTER USER 'app_media'@'localhost' DEFAULT ROLE ALL;
ALTER USER 'biblio_marie'@'localhost' DEFAULT ROLE ALL;
ALTER USER 'stagiaire'@'localhost' DEFAULT ROLE ALL;
ALTER USER 'analyste'@'localhost' DEFAULT ROLE ALL;

SHOW GRANTS FOR 'app_media'@'localhost';
SHOW GRANTS FOR 'biblio_marie'@'localhost';
SHOW GRANTS FOR 'stagiaire'@'localhost';
SHOW GRANTS FOR 'analyste'@'localhost';

SELECT TABLE_NAME, COLUMN_NAME, GRANTEE, PRIVILEGE_TYPE 
FROM information_schema.column_privileges 
WHERE TABLE_SCHEMA = 'mediatheque';

GRANT SELECT ON mediatheque.reservation TO 'analyste'@'localhost';
SHOW GRANTS FOR 'analyste'@'localhost';
REVOKE SELECT ON mediatheque.reservation FROM 'analyste'@'localhost';
SHOW GRANTS FOR 'analyste'@'localhost';
