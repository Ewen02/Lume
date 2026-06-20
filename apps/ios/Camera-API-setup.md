# Configuration Caméra + API (Xcode)

## 1. Permission caméra (obligatoire)
Info.plist → `NSCameraUsageDescription` :
> Lume utilise la caméra pour photographier tes repas et scanner les codes-barres.

Sans cette clé, l'app **crashe** à l'ouverture de la caméra / du scanner.

## 2. Connexion à l'API Lume
L'URL et le jeton sont lus depuis Info.plist (avec repli `http://localhost:3000` / `change-me`) :

| Clé Info.plist | Exemple |
|---|---|
| `LUME_API_BASE_URL` | `https://lume-server.up.railway.app` |
| `LUME_API_TOKEN` | doit matcher `API_TOKEN` côté serveur |

Astuce : définir ces valeurs via des *User-Defined Build Settings* + `$(VAR)` dans l'Info.plist pour séparer Debug (localhost) et Release (Railway).

## 3. App Transport Security (dev local uniquement)
Pour taper `http://localhost:3000` (HTTP en clair), ajouter à Info.plist :
```
NSAppTransportSecurity → NSAllowsLocalNetworking = YES
```
En production l'URL Railway est en HTTPS → aucune exception nécessaire.

## 4. VisionKit (scanner)
`DataScannerViewController` exige un appareil A12+ (Neural Engine) et **ne marche pas en simulateur** (`DataScannerView.isSupported` retombe sur un message). Le mode photo utilise la photothèque en simulateur.

## Flux
- **Scanner** : photo (caméra ou photothèque) → `POST /analyze` → écran Analyse (loading → résultats).
- **Code-barres** : VisionKit → `GET /foods/barcode/:code` → fiche produit.
- **Étiquette** : VisionKit (texte) → `GET /foods/search?q=` → fiche produit (macros déterministes USDA).
