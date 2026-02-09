# Rapport de réorganisation – Farm-Life (Godot 4)

## Structure cible

```
res://
├── assets/
│   ├── sprites/
│   ├── fonts/
│   └── shaders/
├── scenes/
│   ├── ui/
│   │   └── main_menu.tscn
│   ├── world/
│   │     └── outside.tscn
│   └── main_game.tscn
├── scripts/
│   ├── ui/
│   │   └── main_menu.gd
│   └── systems/
│       └── scene_transition.gd
├── tilesets/
│   └── MathileTileSet.tres
├── project.godot
└── icon.svg
```

---

## 1. Chemins de scripts mis à jour

| Fichier | Ancien chemin | Nouveau chemin | Statut |
|---------|----------------|----------------|--------|
| scenes/ui/main_menu.tscn | res://scripts/ui/main_menu.gd | (inchangé) | Déjà correct |
| scenes/main_game.tscn | res://scenes/Map.gd | (inchangé) | Déjà correct |
| scenes/player.tscn | res://scenes/player.gd | (inchangé) | Déjà correct |

Aucune modification nécessaire : les scènes pointaient déjà vers les bons scripts.

---

## 2. Chemins de ressources mis à jour

### Modifications effectuées

| Fichier | Type | Ancien chemin | Nouveau chemin |
|---------|------|----------------|----------------|
| **scripts/ui/main_menu.gd** | Scène | res://main_game.tscn | **res://scenes/main_game.tscn** |
| **scripts/systems/scene_transition.gd** | Shader | res://Shaders/circle_wipe.gdshader | **res://assets/shaders/circle_wipe.gdshader** |
| **scenes/player.tscn** | Texture | res://Sprites/Player_Main_All1.png | **res://assets/sprites/Player_Main_All1.png** |

### Déjà conformes à la structure

- **scenes/ui/main_menu.tscn** : res://assets/sprites/..., res://assets/fonts/Minecraft.ttf
- **scenes/main_game.tscn** : res://assets/sprites/Cute_Fantasy/..., res://scenes/player.tscn
- **scenes/world/Outside.tscn** : res://assets/sprites/...

### À vérifier manuellement

Les fichiers suivants utilisent **res://art/tilemap/** alors que le dossier `art/` n’apparaît pas à la racine du projet. Si tes tuiles sont sous `assets/sprites/`, adapte les chemins (ex. **res://assets/sprites/tilemap/...**) :

| Fichier | Ressource |
|---------|-----------|
| scenes/Rock.tscn | res://art/tilemap/Stones.png |
| scenes/Tree.tscn | res://art/tilemap/Trees.png |
| MathileTileSet.tres (si présent à la racine) | res://art/tilemap/Tileset Spring.png, House.png, etc. |

---

## 3. Autoloads (Project Settings)

**Aucune modification** : l’autoload est déjà correct.

- **SceneTransition** → `res://scripts/systems/scene_transition.gd`

---

## 4. Noms de fichiers (snake_case)

### À faire manuellement

Le renommage automatique a échoué (droits d’accès). À faire dans l’explorateur de fichiers ou Godot :

- **scenes/world/Outside.tscn** → **scenes/world/outside.tscn**

Après renommage, toute référence à `res://scenes/world/Outside.tscn` doit être remplacée par **res://scenes/world/outside.tscn** (aucune référence trouvée dans les .gd/.tscn pour l’instant).

---

## 5. Déplacements de fichiers à faire manuellement (si pas déjà faits)

Pour coller à la structure cible :

1. **Sprites/** → déplacer le contenu (ex. `Player_Main_All1.png` + `.import`) dans **assets/sprites/**.
2. **MathileTileSet.tres** (à la racine) → déplacer dans **tilesets/MathileTileSet.tres** (créer le dossier `tilesets/` si besoin).

Les chemins dans le code ont été mis à jour pour **assets/sprites/** et **assets/shaders/** ; il reste à déplacer les fichiers réels si ce n’est pas déjà fait.

---

## 6. Récapitulatif

- **Chemins corrigés** : 3 (main_game.tscn, circle_wipe.gdshader, Player_Main_All1.png).
- **Autoload** : inchangé, déjà correct.
- **À faire par toi** : renommer `Outside.tscn` en `outside.tscn`, déplacer `Sprites/` et `MathileTileSet.tres` si besoin, corriger les chemins **res://art/tilemap/** si tu utilises `assets/sprites/tilemap/`.

Aucune suppression de `.git/`, `.godot/` ou `project.godot` n’a été effectuée.
