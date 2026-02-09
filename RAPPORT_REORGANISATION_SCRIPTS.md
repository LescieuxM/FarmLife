# Rapport de réorganisation des scripts – Farm-Life (Godot 4)

**Date :** 9 février 2025  
**Objectif :** Déplacer tous les scripts `.gd` situés dans `scenes/` vers `scripts/systems/` et mettre à jour les références.

---

## 1. Scripts déplacés

| Script d’origine | Destination | Fichiers associés déplacés |
|------------------|-------------|----------------------------|
| `scenes/Map.gd` | `scripts/systems/Map.gd` | `Map.gd`, `Map.gd.uid` |
| `scenes/player.gd` | `scripts/systems/player.gd` | `player.gd`, `player.gd.uid` |

**Scripts non déplacés (déjà dans `scripts/`) :**
- `scripts/ui/main_menu.gd` — inchangé (référencé par `scenes/ui/main_menu.tscn`).

---

## 2. Changements de chemins dans les scènes (.tscn)

| Fichier scène | Ancien chemin du script | Nouveau chemin du script |
|---------------|-------------------------|---------------------------|
| `scenes/main_game.tscn` | `res://scenes/Map.gd` | **res://scripts/systems/Map.gd** |
| `scenes/player.tscn` | `res://scenes/player.gd` | **res://scripts/systems/player.gd** |

Les UID Godot (`uid://...`) sont conservés via les fichiers `.gd.uid` déplacés dans `scripts/systems/`, les scènes restent donc liées aux mêmes scripts.

---

## 3. Résumé des actions

- **Créés :** `scripts/systems/Map.gd`, `scripts/systems/Map.gd.uid`, `scripts/systems/player.gd`, `scripts/systems/player.gd.uid`
- **Modifiés :** `scenes/main_game.tscn`, `scenes/player.tscn` (ligne `ext_resource` du script)
- **Supprimés (après déplacement) :** `scenes/Map.gd`, `scenes/Map.gd.uid`, `scenes/player.gd`, `scenes/player.gd.uid`

---

## 4. Vérifications effectuées

- Aucun script dans `scenes/ui/` ou ailleurs sous `scenes/` n’a été déplacé (seuls `Map.gd` et `player.gd` à la racine de `scenes/` l’ont été).
- Aucune référence à `res://scenes/Map.gd` ou `res://scenes/player.gd` ne reste dans le projet après mise à jour des deux scènes.
- Les ressources (TileSets, textures, PackedScene `player.tscn`, etc.) dans `main_game.tscn` et `player.tscn` n’ont pas été modifiées ; seuls les chemins des scripts ont été mis à jour.

---

## 5. Structure actuelle de `scripts/`

```
scripts/
├── systems/
│   ├── Map.gd
│   ├── Map.gd.uid
│   ├── player.gd
│   ├── player.gd.uid
│   └── scene_transition.gd
└── ui/
	└── main_menu.gd
```

La réorganisation est terminée. Vous pouvez ouvrir le projet dans Godot 4 et lancer une scène pour confirmer que tout fonctionne.
