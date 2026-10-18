# TP2 — Rapport d'optimisation

> Les chiffres attendus sont des **ordres de grandeur** : l'archive est générée
> aléatoirement, les vôtres seront proches sans être identiques.

Mesures faites sur MySQL 8.0.46, après `Base/03-volume.sql` (200 130 emprunts).

## Avant / après

Pour chaque requête : le plan avant tout index, puis le plan après l'index que vous avez posé.

### R1 — les emprunts d'une journée

```sql
SELECT * FROM emprunt WHERE date_emprunt = '2024-03-12';
```

| | `type` | `key` | `rows` | `Extra` |
|---|---|---|---|---|
| avant | ALL | NULL | 199 875 | Using where |
| après | ref | idx_emprunt_date_emprunt | 104 | NULL |

- Index créé : `CREATE INDEX idx_emprunt_date_emprunt ON emprunt (date_emprunt);`
- Lignes réellement renvoyées : `104`
- Une phrase de conclusion : on passe d'un parcours complet de la table (≈ 200 000 lignes lues pour en garder 104) à une lecture directe des 104 lignes du jour.

### R2 — les emprunts en cours

```sql
SELECT * FROM emprunt WHERE date_retour_reelle IS NULL;
```

| | `type` | `key` | `rows` | `Extra` |
|---|---|---|---|---|
| avant | ALL | NULL | 199 875 | Using where |
| après | ref | idx_emprunt_date_retour_reelle | 30 | Using index condition |

- Index créé : `CREATE INDEX idx_emprunt_date_retour_reelle ON emprunt (date_retour_reelle);`
- Lignes réellement renvoyées : `30`
- Une phrase de conclusion : un index B-tree range aussi les `NULL`, donc `IS NULL` l'utilise ; on lit 30 lignes au lieu de 200 000, et `v_emprunt_en_cours` en profite.

### R3 — l'historique récent d'un adhérent

```sql
SELECT id, date_emprunt FROM emprunt
 WHERE adherent_id = 12 AND date_emprunt >= '2025-01-01';
```

| | `type` | `key` | `rows` | `Extra` |
|---|---|---|---|---|
| avant | ref | fk_emprunt_adherent | 5 070 | Using where |
| après | range | idx_emprunt_adherent_date | 741 | Using where; Using index |

- Index créé : `CREATE INDEX idx_emprunt_adherent_date ON emprunt (adherent_id, date_emprunt);`
- Lignes réellement renvoyées : `741`
- Pourquoi les colonnes sont-elles dans cet ordre, et pas dans l'autre ?
  L'égalité (`adherent_id = 12`) d'abord, l'intervalle (`date_emprunt >= …`) ensuite : dans l'index, les dates sont triées à l'intérieur de chaque adhérent, donc MySQL va sur l'adhérent 12 et lit une seule plage contiguë (741 lignes). Dans l'ordre inverse, il devrait lire toutes les dates depuis 2025 (≈ 55 000 lignes, tous adhérents confondus) et filtrer l'adhérent ensuite. En plus, `id` (clé primaire) est inclus dans tout index secondaire InnoDB : l'index couvre la requête (`Using index`), la table n'est pas lue.

## Le préfixe gauche (consigne 7)

| Requête | L'index composite sert-il ? | Pourquoi |
|---|---|---|
| `WHERE adherent_id = 12` | Oui — `ref`, `idx_emprunt_adherent_date`, 5 070 lignes, `Using index` | `adherent_id` est la première colonne de l'index (son préfixe gauche) |
| `WHERE date_emprunt >= '2025-01-01'` | Non — MySQL prend `idx_emprunt_date_emprunt` (`range`, 55 224 lignes) | `date_emprunt` n'est que la 2ᵉ colonne : ses valeurs sont éparpillées dans tout l'index, rangées adhérent par adhérent |

## L'index couvrant (consigne 8)

- Mention présente dans le premier `Extra` : `Using index`
- Elle disparaît dans le second parce que : `exemplaire_id` n'est pas dans l'index. Pour chacune des 5 070 entrées trouvées, le serveur doit en plus retourner lire la ligne complète dans la table (par la clé primaire) pour y prendre `exemplaire_id`.

## La requête réécrite (consigne 9)

```sql
-- version d'origine
SELECT COUNT(*) FROM emprunt WHERE YEAR(date_emprunt) = 2024;
-- type : index   rows : 199 875   (tout l'index est parcouru, YEAR() calculé sur chaque ligne)

-- version réécrite
SELECT COUNT(*) FROM emprunt
 WHERE date_emprunt >= '2024-01-01' AND date_emprunt < '2025-01-01';
-- type : range   rows : 22 203   (estimation ; seule la plage 2024 est lue)
```

Les deux renvoient bien le même nombre : `43 015`

La colonne doit rester « nue » dans le `WHERE` : une fonction appliquée à la colonne empêche l'optimiseur de chercher une plage dans l'index. La borne haute est stricte (`<`) pour ne pas compter le 1ᵉʳ janvier 2025.

## Le prix des index (consigne 10)

| | `donnees_mo` | `index_mo` |
|---|---|---|
| avant | 8,52 | 11,03 |
| après | 8,52 | 18,06 |

(avec `SET SESSION information_schema_stats_expiry = 0;`, sinon les tailles affichées sont celles en cache)

Conclusion : les index ne changent pas les données, mais ils occupent maintenant plus de deux fois leur place (18 Mo contre 8,5 Mo), et chaque `INSERT` ou `UPDATE` sur `emprunt` doit aussi les tenir à jour : on n'en pose que pour une requête précise qui le justifie.

## Bonus

- Consigne 11 — l'index qu'on ne peut pas supprimer : `ERROR 1553 (HY000): Cannot drop index 'idx_emprunt_adherent_date': needed in a foreign key constraint`. InnoDB exige, pour chaque clé étrangère, un index dont la colonne est en première position. À la création du composite (qui commence par `adherent_id`), MySQL a supprimé de lui-même l'index `fk_emprunt_adherent` devenu redondant : c'est maintenant le composite qui porte la clé étrangère, et il ne peut plus être supprimé tant qu'un autre index sur `adherent_id` ne le remplace pas.
- Consigne 12 — `EXPLAIN` sur `v_retard` : les quatre tables apparaissent (`em`, `a`, `ex`, `o`) ; les deux vues sont fusionnées dans la requête (algorithme `MERGE`), il n'y a pas de table intermédiaire. `emprunt` passe par `idx_emprunt_date_retour_reelle` (`ref`, 30 lignes) grâce à `date_retour_reelle IS NULL`, puis `adherent`, `exemplaire` et `ouvrage` par leur clé primaire (`eq_ref`, 1 ligne chacune). Oui, l'index de R2 sert ; le filtre `jours_de_retard > 0` est appliqué ensuite (`Using where`), car il porte sur un calcul.
