USE mediatheque;

-- MySQL n'a pas de DROP INDEX IF EXISTS : on passe par des requêtes préparées
-- pour que le script se rejoue. La clé étrangère est retirée puis recréée,
-- sinon le composite ne peut pas être supprimé (ERROR 1553).
ALTER TABLE emprunt DROP FOREIGN KEY fk_emprunt_adherent;

SET @sql = IF((SELECT COUNT(*) FROM information_schema.statistics
                WHERE table_schema = 'mediatheque' AND table_name = 'emprunt'
                  AND index_name = 'idx_emprunt_adherent_date') > 0,
              'DROP INDEX idx_emprunt_adherent_date ON emprunt', 'DO 0');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @sql = IF((SELECT COUNT(*) FROM information_schema.statistics
                WHERE table_schema = 'mediatheque' AND table_name = 'emprunt'
                  AND index_name = 'fk_emprunt_adherent') > 0,
              'DROP INDEX fk_emprunt_adherent ON emprunt', 'DO 0');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @sql = IF((SELECT COUNT(*) FROM information_schema.statistics
                WHERE table_schema = 'mediatheque' AND table_name = 'emprunt'
                  AND index_name = 'idx_emprunt_date_emprunt') > 0,
              'DROP INDEX idx_emprunt_date_emprunt ON emprunt', 'DO 0');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @sql = IF((SELECT COUNT(*) FROM information_schema.statistics
                WHERE table_schema = 'mediatheque' AND table_name = 'emprunt'
                  AND index_name = 'idx_emprunt_date_retour_reelle') > 0,
              'DROP INDEX idx_emprunt_date_retour_reelle ON emprunt', 'DO 0');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

ALTER TABLE emprunt
  ADD CONSTRAINT fk_emprunt_adherent
      FOREIGN KEY (adherent_id) REFERENCES adherent (id);

ANALYZE TABLE emprunt;

-- Sinon information_schema.tables renvoie des tailles en cache.
SET SESSION information_schema_stats_expiry = 0;

SELECT index_name, column_name, seq_in_index
  FROM information_schema.statistics
 WHERE table_schema = 'mediatheque' AND table_name = 'emprunt'
 ORDER BY index_name, seq_in_index;

SELECT ROUND(data_length  / 1024 / 1024, 2) AS donnees_mo,
       ROUND(index_length / 1024 / 1024, 2) AS index_mo
  FROM information_schema.tables
 WHERE table_schema = 'mediatheque' AND table_name = 'emprunt';

EXPLAIN SELECT * FROM emprunt WHERE date_emprunt = '2024-03-12';
SELECT COUNT(*) AS r1_lignes FROM emprunt WHERE date_emprunt = '2024-03-12';

EXPLAIN SELECT * FROM emprunt WHERE date_retour_reelle IS NULL;
SELECT COUNT(*) AS r2_lignes FROM emprunt WHERE date_retour_reelle IS NULL;

EXPLAIN SELECT id, date_emprunt FROM emprunt
         WHERE adherent_id = 12 AND date_emprunt >= '2025-01-01';
SELECT COUNT(*) AS r3_lignes FROM emprunt
 WHERE adherent_id = 12 AND date_emprunt >= '2025-01-01';

EXPLAIN SELECT COUNT(*) FROM emprunt WHERE YEAR(date_emprunt) = 2024;

-- R1 : égalité sur date_emprunt.
CREATE INDEX idx_emprunt_date_emprunt ON emprunt (date_emprunt);
ANALYZE TABLE emprunt;
EXPLAIN SELECT * FROM emprunt WHERE date_emprunt = '2024-03-12';

-- R2 : date_retour_reelle IS NULL (un index B-tree range aussi les NULL).
CREATE INDEX idx_emprunt_date_retour_reelle ON emprunt (date_retour_reelle);
ANALYZE TABLE emprunt;
EXPLAIN SELECT * FROM emprunt WHERE date_retour_reelle IS NULL;

-- R3 : l'égalité (adherent_id) avant l'intervalle (date_emprunt). Les dates
-- sont alors triées à l'intérieur de chaque adhérent : MySQL lit une seule
-- plage. Dans l'autre ordre, il lirait toutes les dates depuis 2025, tous
-- adhérents confondus.
CREATE INDEX idx_emprunt_adherent_date ON emprunt (adherent_id, date_emprunt);
ANALYZE TABLE emprunt;
EXPLAIN SELECT id, date_emprunt FROM emprunt
         WHERE adherent_id = 12 AND date_emprunt >= '2025-01-01';

-- La première utilise le composite (adherent_id en est le préfixe gauche).
-- La seconde non : date_emprunt n'est que la 2e colonne, ses valeurs sont
-- éparpillées dans l'index. L'optimiseur prend idx_emprunt_date_emprunt.
EXPLAIN SELECT id FROM emprunt WHERE adherent_id = 12;
EXPLAIN SELECT id FROM emprunt WHERE date_emprunt >= '2025-01-01';

-- « Using index » disparaît dans la seconde : exemplaire_id n'est pas dans
-- l'index, MySQL doit relire chaque ligne dans la table.
EXPLAIN SELECT adherent_id, date_emprunt FROM emprunt WHERE adherent_id = 12;
EXPLAIN SELECT adherent_id, date_emprunt, exemplaire_id FROM emprunt WHERE adherent_id = 12;

-- YEAR() sur la colonne empêche la recherche par plage : type = index,
-- tout l'index est parcouru. Réécrite avec un intervalle : type = range.
EXPLAIN SELECT COUNT(*) FROM emprunt WHERE YEAR(date_emprunt) = 2024;
SELECT COUNT(*) AS avec_year FROM emprunt WHERE YEAR(date_emprunt) = 2024;

EXPLAIN SELECT COUNT(*) FROM emprunt
         WHERE date_emprunt >= '2024-01-01' AND date_emprunt < '2025-01-01';
SELECT COUNT(*) AS avec_intervalle FROM emprunt
 WHERE date_emprunt >= '2024-01-01' AND date_emprunt < '2025-01-01';

SELECT ROUND(data_length  / 1024 / 1024, 2) AS donnees_mo,
       ROUND(index_length / 1024 / 1024, 2) AS index_mo
  FROM information_schema.tables
 WHERE table_schema = 'mediatheque' AND table_name = 'emprunt';

-- DROP INDEX idx_emprunt_adherent_date ON emprunt;
--   ERROR 1553 (HY000): Cannot drop index 'idx_emprunt_adherent_date':
--   needed in a foreign key constraint
-- InnoDB exige un index commençant par adherent_id pour la clé étrangère.
-- À la création du composite, MySQL a supprimé fk_emprunt_adherent : c'est
-- maintenant le composite qui porte la clé étrangère.

-- Les quatre tables apparaissent (la vue est fusionnée dans la requête).
-- emprunt passe par idx_emprunt_date_retour_reelle, les autres par leur
-- clé primaire.
EXPLAIN SELECT * FROM v_retard;
