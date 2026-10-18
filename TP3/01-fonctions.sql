USE mediatheque;

DROP FUNCTION IF EXISTS f_nb_emprunts_en_cours;
DROP FUNCTION IF EXISTS f_penalites_dues;
DROP FUNCTION IF EXISTS f_jours_de_retard;

DELIMITER //

CREATE FUNCTION f_nb_emprunts_en_cours(p_adherent_id INT UNSIGNED)
RETURNS INT
NOT DETERMINISTIC
READS SQL DATA
BEGIN
  DECLARE v_nb INT DEFAULT 0;

  SELECT COUNT(*) INTO v_nb
    FROM emprunt
   WHERE adherent_id = p_adherent_id
     AND date_retour_reelle IS NULL;

  RETURN v_nb;
END //

-- COALESCE : SUM() sur zéro ligne renvoie NULL, pas 0.
CREATE FUNCTION f_penalites_dues(p_adherent_id INT UNSIGNED)
RETURNS DECIMAL(8,2)
NOT DETERMINISTIC
READS SQL DATA
BEGIN
  DECLARE v_total DECIMAL(8,2) DEFAULT 0.00;

  SELECT COALESCE(SUM(montant), 0.00) INTO v_total
    FROM penalite
   WHERE adherent_id = p_adherent_id
     AND payee = 0;

  RETURN v_total;
END //

CREATE FUNCTION f_jours_de_retard(p_emprunt_id INT UNSIGNED)
RETURNS INT
NOT DETERMINISTIC
READS SQL DATA
BEGIN
  DECLARE v_jours INT DEFAULT NULL;

  SELECT GREATEST(DATEDIFF(COALESCE(date_retour_reelle, CURDATE()),
                           date_retour_prevue), 0)
    INTO v_jours
    FROM emprunt
   WHERE id = p_emprunt_id;

  RETURN v_jours;
END //

DELIMITER ;

SELECT a.id,
       a.nom,
       a.prenom,
       f_nb_emprunts_en_cours(a.id)  AS emprunts_en_cours,
       f_penalites_dues(a.id)        AS penalites_dues,
       (SELECT MAX(f_jours_de_retard(em.id))
          FROM emprunt em
         WHERE em.adherent_id = a.id
           AND em.date_retour_reelle IS NULL) AS max_jours_de_retard
  FROM adherent a
 WHERE f_nb_emprunts_en_cours(a.id) > 0
 ORDER BY penalites_dues DESC, a.id;

SELECT f_penalites_dues(2) AS penalites_adherent_2;
