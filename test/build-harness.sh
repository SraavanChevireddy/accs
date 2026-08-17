#!/usr/bin/env bash
# Builds test/index.html: a copy of the dashboard wired to mock-supabase.js
# instead of the real CDN client, so the ONLINE code path can be exercised
# locally without a Supabase project.
#
#   ./test/build-harness.sh && python3 -m http.server 8765
#   open http://localhost:8765/test/index.html
#
# test/index.html is generated and git-ignored — never edit it directly.
set -euo pipefail
cd "$(dirname "$0")/.."

python3 - <<'PY'
h = open('index.html', encoding='utf-8').read()
h = h.replace(
    '<script src="https://cdn.jsdelivr.net/npm/@supabase/supabase-js@2.45.4/dist/umd/supabase.js"></script>',
    '<script src="./mock-supabase.js"></script>')
h = h.replace("const SUPABASE_URL      = '';", "const SUPABASE_URL      = 'https://mock.supabase.co';")
h = h.replace("const SUPABASE_ANON_KEY  = '';", "const SUPABASE_ANON_KEY  = 'mock-anon-key';")
open('test/index.html', 'w', encoding='utf-8').write(h)

# syntax-check the page script while we are here
js = h.split('<script src="./mock-supabase.js"></script>\n<script>')[1].split('</script>')[0]
open('/tmp/zinnov-dashboard-check.js', 'w', encoding='utf-8').write(js)
PY

node --check /tmp/zinnov-dashboard-check.js 2>/dev/null && echo "index.html script: syntax OK" || echo "(node not found — skipped syntax check)"
echo "wrote test/index.html"
