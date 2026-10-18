USE mediatheque;

CREATE TABLE IF NOT EXISTS journal_action (
  id          BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  table_cible VARCHAR(40)     NOT NULL,
  operation   VARCHAR(10)     NOT NULL,
  cle         VARCHAR(40)     NOT NULL,
  auteur      VARCHAR(100)    NOT NULL,
  horodatage  DATETIME        NOT NULL,
  details     VARCHAR(255)        NULL,
  PRIMARY KEY (id)
) ENGINE=InnoDB;

DROP TRIGGER IF EXISTS trg_emprunt_before_insert;
DROP TRIGGER IF EXISTS trg_emprunt_after_insert;
DROP TRIGGER IF EXISTS trg_emprunt_after_update;

DELIMITER //

CREATE TRIGGER trg_emprunt_before_insert
BEFORE INSERT ON emprunt
FOR EACH ROW
BEGIN
  IF NEW.date_emprunt IS NULL THEN
    SET NEW.date_emprunt = CURDATE();
  END IF;

  IF NEW.date_retour_prevue IS NULL THEN
    SET NEW.date_retour_prevue = NEW.date_emprunt + INTERVAL 14 DAY;
  END IF;

  IF NEW.date_retour_prevue < NEW.date_emprunt THEN
    SIGNAL SQLSTATE '45000'
      SET MESSAGE_TEXT = 'La date de retour prévue ne peut pas précéder la date d''emprunt.';
  END IF;
END //

-- USER() et pas CURRENT_USER(), qui renverrait le DEFINER de la procédure.
-- Un emprunt inséré déjà rendu (archive de 03-volume.sql) ne bloque pas
-- l'exemplaire.
CREATE TRIGGER trg_emprunt_after_insert
AFTER INSERT ON emprunt
FOR EACH ROW
BEGIN
  IF NEW.date_retour_reelle IS NULL THEN
    UPDATE exemplaire
       SET disponible = 0
     WHERE id = NEW.exemplaire_id;
  END IF;

  INSERT INTO journal_action (table_cible, operation, cle, auteur, horodatage, details)
  VALUES ('emprunt', 'INSERT', NEW.id, USER(), NOW(),
          CONCAT('exemplaire ', NEW.exemplaire_id, ' -> adhérent ', NEW.adherent_id,
                 ', retour prévu le ', NEW.date_retour_prevue));
END //

-- Sans la comparaison OLD / NEW, n'importe quelle modification de la ligne
-- rendrait l'exemplaire disponible.
CREATE TRIGGER trg_emprunt_after_update
AFTER UPDATE ON emprunt
FOR EACH ROW
BEGIN
  IF OLD.date_retour_reelle IS NULL AND NEW.date_retour_reelle IS NOT NULL THEN
    UPDATE exemplaire
       SET disponible = 1
     WHERE id = NEW.exemplaire_id;

    INSERT INTO journal_action (table_cible, operation, cle, auteur, horodatage, details)
    VALUES ('emprunt', 'RETOUR', NEW.id, USER(), NOW(),
            CONCAT('exemplaire ', NEW.exemplaire_id, ' rendu le ', NEW.date_retour_reelle));
  ELSE
    INSERT INTO journal_action (table_cible, operation, cle, auteur, horodatage, details)
    VALUES ('emprunt', 'UPDATE', NEW.id, USER(), NOW(),
            CONCAT('retour prévu : ', OLD.date_retour_prevue, ' -> ', NEW.date_retour_prevue));
  END IF;
END //

DELIMITER ;

SHOW TRIGGERS FROM mediatheque;
