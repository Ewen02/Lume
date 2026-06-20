#!/usr/bin/env bash
#
# lume-ios.sh — tâches iOS de Lume (générer/ouvrir/build/run/test le projet Xcode).
#
# L'app iOS n'est pas dans le workspace pnpm. Ces tâches sont exposées à la racine via
# des alias `pnpm ios:*` (voir package.json racine) qui appellent ce script.
#
# Usage : ./lume-ios.sh <commande> [args]
#   open        Génère le projet (XcodeGen) et l'ouvre dans Xcode
#   generate    Génère le projet seulement (sans ouvrir)
#   run         Build + lance l'app dans le simulateur (SIM="iPhone 15 Pro" par défaut)
#   build       Compile pour simulateur (sans signing)
#   test        Lance les tests unitaires (LumeTests) sur simulateur
#   sim         Démarre juste le simulateur + ouvre l'app Simulator
#   shot        Capture l'écran du simulateur → /tmp/lume.png
#   log         Stream les logs de l'app dans le simulateur
#   clean       Supprime Lume.xcodeproj + DerivedData du projet
#   devices     Liste les simulateurs iPhone disponibles
#
# Variables d'env :
#   SIM    nom du simulateur (def: "iPhone 15 Pro")
#   SCHEME nom du scheme      (def: "Lume")
#
set -euo pipefail
SELF="$(cd "$(dirname "$0")" && pwd)/$(basename "$0")"
cd "$(dirname "$0")"

SCHEME="${SCHEME:-Lume}"
SIM="${SIM:-iPhone 15 Pro}"
PROJECT="Lume.xcodeproj"
BUNDLE_ID="com.ewen.lume"
DEST="platform=iOS Simulator,name=${SIM}"

require_xcodegen() {
  command -v xcodegen >/dev/null 2>&1 || { echo "❌ xcodegen manquant. brew install xcodegen"; exit 1; }
}
ensure_project() {
  [[ -d "$PROJECT" ]] || { require_xcodegen; echo "⚙️  Génération du projet…"; xcodegen generate; }
}
# Pretty-print xcodebuild si xcbeautify est installé, sinon brut.
pretty() { if command -v xcbeautify >/dev/null 2>&1; then xcbeautify; else cat; fi; }

# Résout l'UDID d'un simulateur booté (ou en boote un) pour le nom $SIM.
booted_sim_udid() {
  local udid
  udid=$(xcrun simctl list devices booted | grep -Eo '[0-9A-F-]{36}' | head -1 || true)
  if [[ -z "$udid" ]]; then
    udid=$(xcrun simctl list devices available | grep -F "$SIM (" | grep -Eo '[0-9A-F-]{36}' | head -1 || true)
    [[ -n "$udid" ]] || { echo "❌ Simulateur '$SIM' introuvable. Essaie: ./lume-ios.sh devices" >&2; exit 1; }
    xcrun simctl boot "$udid" 2>/dev/null || true
  fi
  echo "$udid"
}

cmd="${1:-}"; shift || true
case "$cmd" in
  open)
    require_xcodegen; echo "⚙️  Génération…"; xcodegen generate
    echo "🚀 Ouverture de Xcode…"; open "$PROJECT"
    echo "✅ Dans Xcode : choisis un simulateur puis ⌘R." ;;

  generate|gen)
    require_xcodegen; xcodegen generate; echo "✅ $PROJECT généré." ;;

  build)
    ensure_project
    udid=$(booted_sim_udid)   # cible un simulateur par UDID (évite un iPhone physique homonyme)
    echo "🔨 Build ($SCHEME · $SIM)…"
    xcodebuild -project "$PROJECT" -scheme "$SCHEME" -destination "id=$udid" \
      -configuration Debug build CODE_SIGNING_ALLOWED=NO | pretty ;;

  run)
    ensure_project
    udid=$(booted_sim_udid)
    open -a Simulator || true
    echo "🔨 Build…"
    xcodebuild -project "$PROJECT" -scheme "$SCHEME" -destination "id=$udid" \
      -configuration Debug build CODE_SIGNING_ALLOWED=NO | pretty
    app=$(find ~/Library/Developer/Xcode/DerivedData/Lume-*/Build/Products/Debug-iphonesimulator \
            -maxdepth 1 -name "${SCHEME}.app" 2>/dev/null | head -1)
    [[ -n "$app" ]] || { echo "❌ ${SCHEME}.app introuvable après build"; exit 1; }
    echo "📲 Installation + lancement…"
    xcrun simctl install "$udid" "$app"
    xcrun simctl launch "$udid" "$BUNDLE_ID"
    echo "✅ Lancée sur '$SIM'." ;;

  test)
    ensure_project
    udid=$(booted_sim_udid)   # cible un simulateur par UDID (évite un iPhone physique homonyme)
    echo "🧪 Tests ($SCHEME · $SIM)…"
    xcodebuild -project "$PROJECT" -scheme "$SCHEME" -destination "id=$udid" \
      -configuration Debug test CODE_SIGNING_ALLOWED=NO | pretty ;;

  sim)
    udid=$(booted_sim_udid); open -a Simulator; echo "✅ Simulateur '$SIM' prêt ($udid)." ;;

  shot)
    udid=$(booted_sim_udid); out="${1:-/tmp/lume.png}"
    xcrun simctl io "$udid" screenshot "$out" && echo "✅ Capture → $out" ;;

  log)
    udid=$(booted_sim_udid)
    echo "📜 Logs de $BUNDLE_ID (Ctrl-C pour arrêter)…"
    xcrun simctl spawn "$udid" log stream --level debug \
      --predicate "subsystem CONTAINS[c] 'com.ewen' OR processImagePath CONTAINS 'Lume'" ;;

  clean)
    rm -rf "$PROJECT"
    rm -rf ~/Library/Developer/Xcode/DerivedData/Lume-*
    echo "✅ Projet + DerivedData supprimés. Régénère avec: pnpm ios:open" ;;

  devices|sims)
    xcrun simctl list devices available | grep -E "iPhone|iPad" ;;

  ""|help|-h|--help)
    sed -n '2,27p' "$SELF" | sed 's/^# \{0,1\}//' ;;

  *)
    echo "❌ Commande inconnue: $cmd"; echo "   ./lume-ios.sh help"; exit 1 ;;
esac
