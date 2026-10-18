USE mediatheque;

SET @code = (SELECT code_barre FROM exemplaire
              WHERE disponible = 1 AND etat <> 'hors_service' ORDER BY id LIMIT 1);

SET @adherent = (SELECT a.id FROM adherent a
                  WHERE a.actif = 1
                    AND f_nb_emprunts_en_cours(a.id) = 0
                    AND f_penalites_dues(a.id) = 0
                  ORDER BY a.id LIMIT 1);

SET @autre = (SELECT id FROM adherent
               WHERE actif = 1 AND id <> @adherent
                 AND f_nb_emprunts_en_cours(id) < 5
                 AND f_penalites_dues(id) <= 10
               ORDER BY id LIMIT 1);

SET @inactif = (SELECT id FROM adherent WHERE actif = 0 ORDER BY id LIMIT 1);

SET @mauvais_payeur = (SELECT adherent_id FROM penalite
                        WHERE payee = 0 GROUP BY adherent_id
                       HAVING SUM(montant) > 10 ORDER BY adherent_id LIMIT 1);

SET @code_retard = (SELECT ex.code_barre
                      FROM emprunt em JOIN exemplaire ex ON ex.id = em.exemplaire_id
                     WHERE em.date_retour_reelle IS NULL
                       AND em.date_retour_prevue < CURDATE()
                     ORDER BY em.date_retour_prevue LIMIT 1);

SELECT @code, @adherent, @autre, @inactif, @mauvais_payeur, @code_retard;


-- T1
CALL p_emprunter(@code, @adherent, @id);

SELECT @id AS emprunt_cree;
SELECT id, exemplaire_id, adherent_id, date_emprunt, date_retour_prevue
  FROM emprunt WHERE id = @id;
SELECT code_barre, disponible FROM exemplaire WHERE code_barre = @code;
SELECT operation, cle, auteur, details FROM journal_action ORDER BY id DESC LIMIT 1;

-- T2
-- CALL p_emprunter(@code, @autre, @id);
--   ERROR 1644 (45000): Cet exemplaire est déjà emprunté.

-- T3
SET @code2 = (SELECT code_barre FROM exemplaire
               WHERE disponible = 1 AND etat <> 'hors_service' ORDER BY id LIMIT 1);
-- CALL p_emprunter(@code2, @inactif, @id);
--   ERROR 1644 (45000): Inscription inactive : cet adhérent ne peut pas emprunter.

-- T4
-- CALL p_emprunter('MED-99999', 1, @id);
--   ERROR 1644 (45000): Code-barres MED-99999 inconnu.

-- T5 (@adherent a déjà l'emprunt de T1)
SET @c = (SELECT code_barre FROM exemplaire WHERE disponible = 1 AND etat <> 'hors_service' ORDER BY id LIMIT 1);
CALL p_emprunter(@c, @adherent, @id);
SET @c = (SELECT code_barre FROM exemplaire WHERE disponible = 1 AND etat <> 'hors_service' ORDER BY id LIMIT 1);
CALL p_emprunter(@c, @adherent, @id);
SET @c = (SELECT code_barre FROM exemplaire WHERE disponible = 1 AND etat <> 'hors_service' ORDER BY id LIMIT 1);
CALL p_emprunter(@c, @adherent, @id);
SET @c = (SELECT code_barre FROM exemplaire WHERE disponible = 1 AND etat <> 'hors_service' ORDER BY id LIMIT 1);
CALL p_emprunter(@c, @adherent, @id);

SELECT f_nb_emprunts_en_cours(@adherent) AS emprunts_en_cours;

SET @c = (SELECT code_barre FROM exemplaire WHERE disponible = 1 AND etat <> 'hors_service' ORDER BY id LIMIT 1);
-- CALL p_emprunter(@c, @adherent, @id);
--   ERROR 1644 (45000): Quota atteint : 5 documents sont déjà empruntés par cet adhérent.

-- T6
-- CALL p_emprunter(@c, @mauvais_payeur, @id);
--   ERROR 1644 (45000): Pénalités impayées de 12.00 € : régularisez avant tout nouvel emprunt.

-- T7 : une variable et INSERT … VALUES, car un INSERT … SELECT FROM exemplaire
-- échouerait en erreur 1442 (le trigger écrit dans exemplaire).
SET @libre = (SELECT id FROM exemplaire
               WHERE disponible = 1 AND etat <> 'hors_service' ORDER BY id LIMIT 1);

INSERT INTO emprunt (exemplaire_id, adherent_id, date_emprunt, date_retour_prevue)
VALUES (@libre, 2, NULL, NULL);

SET @id_t7 = LAST_INSERT_ID();
SELECT id, date_emprunt, date_retour_prevue,
       DATEDIFF(date_retour_prevue, date_emprunt) AS duree_jours
  FROM emprunt WHERE id = @id_t7;
SELECT id, disponible FROM exemplaire WHERE id = @libre;

-- INSERT INTO emprunt (exemplaire_id, adherent_id, date_emprunt, date_retour_prevue)
-- VALUES (@libre, 2, CURDATE(), CURDATE() - INTERVAL 1 DAY);
--   ERROR 1644 (45000): La date de retour prévue ne peut pas précéder la date d'emprunt.

-- Une prolongation ne doit pas rendre l'exemplaire disponible.
UPDATE emprunt SET date_retour_prevue = date_retour_prevue + INTERVAL 7 DAY
 WHERE id = @id_t7;
SELECT id, disponible FROM exemplaire WHERE id = @libre;

-- T8
SET @jours_attendus = (SELECT DATEDIFF(CURDATE(), em.date_retour_prevue)
                         FROM emprunt em JOIN exemplaire ex ON ex.id = em.exemplaire_id
                        WHERE ex.code_barre = @code_retard
                          AND em.date_retour_reelle IS NULL);
SELECT @jours_attendus AS jours_attendus, @jours_attendus * 0.20 AS montant_attendu;

CALL p_rendre(@code_retard);

SELECT code_barre, disponible FROM exemplaire WHERE code_barre = @code_retard;
SELECT adherent_id, montant, motif FROM penalite ORDER BY id DESC LIMIT 1;
SELECT operation, cle, details FROM journal_action ORDER BY id DESC LIMIT 1;

-- T9
-- CALL p_rendre(@code_retard);
--   ERROR 1644 (45000): Aucun emprunt en cours pour le code-barres MED-00107.

CALL p_bilan_adherent(@adherent);
