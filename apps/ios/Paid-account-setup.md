# Restaurer HealthKit · CloudKit · Push (compte Apple payant)

Pour **builder et lancer avec un compte Apple gratuit (Personal Team)**, trois capacités ont été
**désactivées** : elles exigent un compte **Apple Developer payant** (99 €/an). Sans ça, Xcode refuse de
créer le provisioning profile (« Personal development teams do not support Push Notifications, HealthKit
Access, and iCloud capabilities ») et l'app ne se lance pas, même sur simulateur.

Ce document explique comment **tout remettre** une fois le compte payant en place.

## Ce qui a été désactivé

| Capacité | Où | État actuel (gratuit) | À restaurer |
|---|---|---|---|
| HealthKit | `Lume.entitlements` | entitlements vidés | restaurer les clés HealthKit |
| CloudKit / iCloud | `Lume.entitlements` + `LumeStore.swift` | vidé + `cloudKitDatabase: .none` | restaurer + `.automatic` |
| Push / Remote notifications | `Lume.entitlements` + `project.yml` | `aps-environment` retiré + `UIBackgroundModes` commenté | restaurer les deux |

> La version complète des entitlements est sauvegardée dans **`Lume.entitlements.full-account.bak`**.

## Marche à suivre (3 étapes)

### 1. Restaurer les entitlements
```bash
cd apps/ios
cp Lume.entitlements.full-account.bak Lume.entitlements
```
Ça réactive d'un coup : `com.apple.developer.healthkit`, `icloud-container-identifiers`
(`iCloud.com.ewen.lume`), `icloud-services: CloudKit`, et `aps-environment: development`.

### 2. Réactiver le background mode push dans `project.yml`
Dé-commenter la ligne (section `info.properties` du target `Lume`) :
```yaml
        # CloudKit : notifications distantes en arrière-plan
        UIBackgroundModes: [remote-notification]
```

### 3. Réactiver la synchro CloudKit dans `LumeStore.swift`
Remettre `.automatic` à la place de `.none` :
```swift
let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false, cloudKitDatabase: .automatic)
```
> ⚠️ `.automatic` **crashe au lancement** si l'entitlement CloudKit n'est pas actif. Ne le remets
> qu'après les étapes 1 et 2, avec une vraie équipe Apple Developer payante sélectionnée dans Xcode.

### Puis régénérer + sélectionner l'équipe
```bash
pnpm ios:open
```
Dans Xcode → target **Lume** → **Signing & Capabilities** → choisir le **Team** payant.
Renseigner aussi `DEVELOPMENT_TEAM` dans `project.yml` (ligne ~15) pour que ce soit persistant.

## Vérification
- Build simulateur : `xcodebuild -project Lume.xcodeproj -scheme Lume -destination 'platform=iOS Simulator,name=iPhone 15 Pro' build`
- Pour CloudKit/HealthKit en vrai : tester sur un **device physique** connecté à un compte iCloud.

## Voir aussi
- `HealthKit-setup.md` — détails capability HealthKit + clés `NSHealth*UsageDescription`.
- `Camera-API-setup.md` — caméra + ATS local + config API.
