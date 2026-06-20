#!/usr/bin/env bash
# Hook PostToolUse : formate ce qui peut l'être, no-op sinon. Ne bloque jamais l'édition.
if command -v swiftformat >/dev/null 2>&1; then
  swiftformat apps/ios/Lume --quiet >/dev/null 2>&1 || true
fi
if command -v pnpm >/dev/null 2>&1 && [ -f apps/server/package.json ]; then
  (cd apps/server && pnpm exec prettier --write "src/**/*.ts" >/dev/null 2>&1) || true
fi
exit 0
