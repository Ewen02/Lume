# AppIcon — étape d'export (PNG requis par iOS)

iOS n'accepte PAS de SVG pour l'icône d'app : il faut un **PNG 1024×1024, opaque (sans alpha)**.

## À produire (depuis les SVG sources de ce dossier)
- `AppIcon-1024.png`      ← depuis `source-light.svg` (fond crème #F6F5F1)
- `AppIcon-1024-Dark.png` ← depuis `source-dark.svg`  (fond encre #1B1B1D)

Pose ces 2 PNG dans CE dossier (à côté de Contents.json). Le `.appiconset` est déjà configuré.

## Comment exporter le SVG en PNG 1024 (sans Mac)
- Web : svgtopng.com / cloudconvert.com → règle la sortie sur 1024×1024.
- macOS : ouvrir le SVG dans un éditeur (Sketch/Figma/Affinity/Inkscape) → export 1024×1024 PNG.
- Important : PNG **sans transparence** (Apple rejette l'alpha sur l'AppIcon). Le fond crème/encre fait office de fond plein → OK.

## Variante "tinted" (iOS 18, optionnelle)
Pour ajouter l'icône teintée monochrome, exporte `lume-horizon-mono.svg` en `AppIcon-1024-Tinted.png`
(sur fond clair) puis ajoute cette entrée dans Contents.json :
```
{ "appearances":[{"appearance":"luminosity","value":"tinted"}],
  "filename":"AppIcon-1024-Tinted.png","idiom":"universal","platform":"ios","size":"1024x1024" }
```

## Brancher dans Xcode
1. Glisse `Resources/Assets.xcassets` dans le projet (s'il n'y est pas déjà).
2. Target → General → App Icons and Launch Screen → App Icon = `AppIcon`.
