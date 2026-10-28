#!/usr/bin/env bash
# Re-mirror the Grok-built apps into /workspace/region09/<app>/ (served at region09.com/<app>/)
# and deploy region09.com to Netlify once at the end.
#   update-apps.sh                 # refresh all apps, then deploy
#   update-apps.sh gra             # refresh only one (or several: ypi gra), then deploy
#   update-apps.sh --no-deploy ... # mirror only
#   update-apps.sh --deploy-only   # just deploy what is in /workspace/region09
#   update-apps.sh --target aws    # deploy target: netlify | aws | both (default: both)
set -euo pipefail

# ---- App registry: <path-name> <source site> ------------------------------
APPS=(
  "alarm https://alarmreport.grok.me"
  "ypi   https://ypicountplanner.grok.me"
  "gra   https://gra.grok.me"
  "cash  https://r9cashtracker.grok.me"
  "songque https://songque.grok.me"
  "apalert https://apalert.grok.me"
  "r9guide https://r9guide.grok.me"
)
ROOT="/workspace/region09"
SITE_ID="9b468fde-3a4e-4c2f-8ca5-133ec27b0911"
NETLIFY="$(npm prefix -g)/bin/netlify"
# AWS Amplify Hosting (manual deploys, no Git)
AMPLIFY_APP_ID="d3tzb6kiqfs6ei"
AMPLIFY_BRANCH="main"
AWS_REGION_AMPLIFY="us-east-1"
export PATH="$HOME/.local/bin:$PATH"
TARGET="both"

DEPLOY=1; MIRROR=1; WANT=()
args=("$@"); i=0
while (( i < ${#args[@]} )); do
  a="${args[$i]}"; i=$((i+1))
  case "$a" in
    --target) TARGET="${args[$i]:-}"; i=$((i+1)) ;;
    --target=*) TARGET="${a#--target=}" ;;
    --no-deploy) DEPLOY=0 ;;
    --deploy-only) MIRROR=0 ;;
    -h|--help) sed -n '2,9p' "$0"; exit 0 ;;
    *) WANT+=("$a") ;;
  esac
done
[[ "$TARGET" =~ ^(netlify|aws|both)$ ]] || { echo "--target must be netlify, aws or both" >&2; exit 2; }
known=" $(for e in "${APPS[@]}"; do set -- $e; printf '%s ' "$1"; done)"
for w in "${WANT[@]}"; do [[ "$known" == *" $w "* ]] || { echo "Unknown app '$w'. Known:$known" >&2; exit 2; }; done

# ---- "Back to main menu" pill, injected into each app's index.html (not into download files) ----
read -r -d '' MENU_INJECT <<'HTML' || true
<script id="r9-menu-inject">(function(){var s=document.currentScript;if(s)s.remove();var ID="r9-menu",CSS="#r9-menu{position:fixed;top:10px;left:10px;z-index:2147483000;display:inline-flex;align-items:center;gap:6px;height:34px;padding:0 13px 0 10px;border-radius:999px;background:rgba(15,19,25,.82);color:#fff!important;border:1px solid rgba(255,255,255,.22);box-shadow:0 4px 14px -4px rgba(0,0,0,.35),0 0 0 1px rgba(0,0,0,.08);-webkit-backdrop-filter:blur(8px);backdrop-filter:blur(8px);font:500 13px/1 'IBM Plex Sans','Segoe UI',system-ui,-apple-system,sans-serif;letter-spacing:.01em;text-decoration:none!important;transition:background .15s,transform .15s}#r9-menu:hover{background:rgba(58,83,107,.95)}#r9-menu:active{transform:scale(.96)}#r9-menu:focus-visible{outline:2px solid #9aafc4;outline-offset:2px}#r9-menu svg{width:15px;height:15px;flex:none}body{padding-top:50px!important}@media print{#r9-menu{display:none}body{padding-top:0!important}}";function add(){if(!document.getElementById(ID+"-style")){var st=document.createElement("style");st.id=ID+"-style";st.textContent=CSS;document.head.appendChild(st)}if(!document.getElementById(ID)){var a=document.createElement("a");a.id=ID;a.href="/";a.setAttribute("aria-label","Back to Region 9 main menu");a.innerHTML='<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="m15 18-6-6 6-6"/></svg><span>Menu</span>';document.body.appendChild(a)}}function start(){setTimeout(function(){add();new MutationObserver(function(){if(!document.getElementById(ID)||!document.getElementById(ID+"-style"))add()}).observe(document.documentElement,{childList:true,subtree:true})},0)}if(document.readyState==="complete")start();else window.addEventListener("load",start)})();</script>
HTML

mirror_app() { # mirror_app <name> <src>
  local NAME="$1" SRC="$2" BASE="/$1" DEST="$ROOT/$1"
  local TMP; TMP="$(mktemp -d)"
  echo "== [$NAME] mirroring $SRC -> $BASE/"

  get() { # get <path> [optional]; writes $TMP/<path>; returns 1 if missing and optional
    local p="${1#/}" opt="${2:-}"; mkdir -p "$TMP/$(dirname "$p")"
    local out; out=$(curl -sS -L --retry 3 -o "$TMP/$p" -w '%{http_code} %{content_type}' "$SRC/$p") || out="000 -"
    local code="${out%% *}" ctype="${out#* }"
    # reject the SPA shell / 404 page served for paths that are not real files
    if [[ "$code" != 200 ]] || { [[ "$p" != *.html && "$ctype" == text/html* ]]; }; then
      rm -f "$TMP/$p"
      [[ -n "$opt" ]] && return 1
      echo "ERROR: [$NAME] $SRC/$p -> HTTP $code ($ctype)" >&2; exit 1
    fi
    echo "   got /$p"
  }

  local code; code=$(curl -sS -L --retry 3 -o "$TMP/index.html" -w '%{http_code}' "$SRC/")
  [[ "$code" == 200 ]] || { echo "ERROR: [$NAME] $SRC/ -> HTTP $code" >&2; exit 1; }
  echo "   got / (index.html)"

  # 1) every root-relative href/src in the HTML (not protocol-relative //host)
  for p in $(grep -aoE '(href|src)="/[^/"][^"]*"' "$TMP/index.html" | sed -E 's/^[a-z]+="([^"?#]+).*/\1/' | sort -u); do if [[ "$p" == *.* ]]; then get "$p"; else get "$p" opt || true; fi; done
  for p in favicon.svg __grok/manifest.webmanifest __grok/icon-180.png; do [[ -f "$TMP/$p" ]] || get "$p" opt || true; done

  # 2) recursively: hashed chunks + absolute file paths referenced inside JS/CSS
  local EXT='html|xlsx|xls|xlsm|csv|pdf|json|png|jpe?g|svg|webp|gif|ico|mjs|js|css|wasm|woff2?|ttf|otf|txt|zip|docx'
  declare -A tried=()
  while :; do
    local new=0 f name
    for f in $(find "$TMP/assets" -type f \( -name '*.js' -o -name '*.mjs' -o -name '*.css' \) 2>/dev/null); do
      for name in $(grep -aoE '(assets/|\./)?[A-Za-z0-9_.-]+-[A-Za-z0-9_-]{8}\.(js|mjs|css|woff2?|ttf|png|svg|wasm)' "$f" | sed -E 's#^(assets/|\./)##' | sort -u); do
        [[ -f "$TMP/assets/$name" || -n "${tried[assets/$name]:-}" ]] && continue
        tried[assets/$name]=1; get "assets/$name" opt && new=1 || true
      done
      for name in $(grep -aoE "[\`\"']/[A-Za-z0-9_][A-Za-z0-9_./-]*\.($EXT)[\`\"'?#]" "$f" | sed -E 's/^.(\/[^`"'"'"'?#]+).*/\1/' | sort -u); do
        name="${name#/}"
        [[ -f "$TMP/$name" || -n "${tried[$name]:-}" ]] && continue
        tried[$name]=1; get "$name" opt && new=1 || true
      done
    done
    # Download-app files referenced as `${slug}.html` (alarm app pattern)
    for name in $(grep -aohE '=`[a-z0-9-]+`,[A-Za-z_$]+=`\$\{[A-Za-z_$]+\}\.html`' "$TMP"/assets/*.js | sed -E 's/^=`([a-z0-9-]+)`.*/\1.html/' | sort -u); do
      [[ -f "$TMP/$name" || -n "${tried[$name]:-}" ]] && continue
      tried[$name]=1; get "$name" && new=1
    done
    [[ $new == 0 ]] && break
  done

  echo "   rewriting absolute paths -> $BASE/"
  python3 - "$TMP" "$BASE" <<'PY'
import sys, re, pathlib
root, base = pathlib.Path(sys.argv[1]), sys.argv[2]
# top-level names that were mirrored (assets, __grok, favicon.svg, samples, *.html downloads, ...)
names = sorted({p.name for p in root.iterdir() if p.name != 'index.html'}, key=len, reverse=True)
pat = re.compile(r'(?<![\w.:/-])/(' + '|'.join(map(re.escape, names)) + r')(?=[/`"\'?#)\s]|$)')
def fix(s): return pat.sub(lambda m: base + '/' + m.group(1), s)
mirrored_html = [p for p in root.glob('*.html') if p.name != 'index.html']
for f in [root/'index.html', *root.glob('assets/*.js'), *root.glob('assets/*.mjs'), *root.glob('assets/*.css')]:
    s = f.read_text(encoding='utf-8', errors='surrogateescape'); o = s
    s = fix(s)
    if f.suffix in ('.js', '.mjs'):
        s = re.sub(r'(`modulepreload`,[A-Za-z_$][\w$]*=function\(e\)\{return`)/(`\+e\})', r'\1' + base + r'/\2', s)
        s = s.replace('e.update({basepath:``,', 'e.update({basepath:`' + base + '`,')
        s = s.replace('fetch(`/${', 'fetch(`' + base + '/${')
    if s != o:
        f.write_text(s, encoding='utf-8', errors='surrogateescape'); print('     rewrote', f.relative_to(root))
m = root/'__grok/manifest.webmanifest'
if m.exists():
    s = m.read_text()
    s = re.sub(r'"(id|start_url|scope)":\s*"/"', r'"\1": "' + base + '/"', s)
    m.write_text(fix(s)); print('     rewrote __grok/manifest.webmanifest')
PY

  # inject the back-to-menu pill into the app shell only
  MENU_INJECT="$MENU_INJECT" python3 - "$TMP/index.html" <<'PY'
import os, sys
p = sys.argv[1]; s = open(p, encoding='utf-8', errors='surrogateescape').read()
snip = os.environ['MENU_INJECT'].strip()
# Drop Grok's app-builder extensions script: on mirrored copies it adds a "Created with Grok / Remix" bar
# that covers the Menu pill on phones (and links visitors to remix the project).
import re
s, n = re.subn(r'<script[^>]*src="https://grok\.com/grok-app-builder/extensions\.js"[^>]*>\s*</script>', '', s)
if n: print('     removed Grok extensions script')
i = s.rfind('</body>')
s = (s[:i] + snip + s[i:]) if i >= 0 else s + snip
open(p, 'w', encoding='utf-8', errors='surrogateescape').write(s); print('     injected menu pill into index.html')
PY

  # sanity checks
  local fail=0
  grep -aq "basepath:\`$BASE\`" "$TMP"/assets/*.js || { echo "ERROR: [$NAME] router basepath rewrite did not apply" >&2; fail=1; }
  if grep -aqE '`modulepreload`,[A-Za-z_$]+=function\(e\)\{return`/`\+e\}' "$TMP"/assets/*.js; then echo "ERROR: [$NAME] preload helper not rewritten" >&2; fail=1; fi
  if grep -aqE '"/(assets|__grok)/|"/favicon\.svg"' "$TMP/index.html"; then echo "ERROR: [$NAME] unrewritten refs in index.html" >&2; fail=1; fi
  if grep -aqE '[`"'"'"']/(assets|__grok)/' "$TMP"/assets/*.js; then echo "ERROR: [$NAME] unrewritten /assets or /__grok refs in JS" >&2; fail=1; fi
  for p in $(grep -aoE "(href|src)=\"$BASE/[^\"]+\"" "$TMP/index.html" | sed -E 's/^[a-z]+="([^"?#]+).*/\1/' | sort -u); do
    [[ -f "$TMP/${p#$BASE/}" ]] || { echo "ERROR: [$NAME] index.html references missing $p" >&2; fail=1; }
  done
  [[ $(grep -ac 'id="r9-menu-inject"' "$TMP/index.html") == 1 ]] || { echo "ERROR: [$NAME] menu pill missing (or duplicated) in index.html" >&2; fail=1; }
  if grep -aq 'grok-app-builder/extensions.js' "$TMP/index.html"; then echo "ERROR: [$NAME] Grok extensions script still present" >&2; fail=1; fi
  for f in "$TMP"/*.html; do [[ "$f" == "$TMP/index.html" ]] && continue
    if grep -aq 'r9-menu' "$f"; then echo "ERROR: [$NAME] menu pill leaked into download file $(basename "$f")" >&2; fail=1; fi; done
  [[ $fail == 0 ]] || { rm -rf "$TMP"; exit 1; }

  rm -rf "$DEST.new"; mkdir -p "$DEST.new"; cp -a "$TMP"/. "$DEST.new"/; chmod -R a+rX "$DEST.new"; rm -rf "$TMP"
  rm -rf "$DEST.old"; if [[ -d "$DEST" ]]; then mv "$DEST" "$DEST.old"; fi; mv "$DEST.new" "$DEST"; rm -rf "$DEST.old"
  echo "   [$NAME] ok: $(find "$DEST" -type f | wc -l) files in $DEST"
}

write_netlify_config() {
  {
    echo "# Generated by update-apps.sh. Each app is a client-side SPA under /<app>/."
    echo "# Real files are served first; other paths under /<app> fall back to that app's index.html."
    for e in "${APPS[@]}"; do set -- $e
      printf '/%s      /%s/index.html  200\n/%s/*    /%s/index.html  200\n' "$1" "$1" "$1" "$1"
    done
    echo "# Keep local tooling out of the public site"
    printf '%s\n' '/update-apps.sh   /404.html  404!' '/update-alarm.sh  /404.html  404!' '/.gitignore       /404.html  404!' '/shots/*          /404.html  404!'
  } > "$ROOT/_redirects"
  {
    for e in "${APPS[@]}"; do set -- $e
      printf '/%s/__grok/manifest.webmanifest\n  Content-Type: application/manifest+json\n' "$1"
    done
  } > "$ROOT/_headers"
}

if [[ $MIRROR == 1 ]]; then
  for e in "${APPS[@]}"; do set -- $e
    if [[ ${#WANT[@]} == 0 || " ${WANT[*]} " == *" $1 "* ]]; then mirror_app "$1" "$2"; [[ "$1" == apalert ]] && python3 "$ROOT/patch-apalert.py" "$ROOT"/apalert/assets/routes-*.js; fi
    [[ "$1" == r9guide && -f "$ROOT/r9guide/index.html" ]] && perl -pi -e 's{href="/(start|summarize)"}{href="/r9guide/$1"}g' "$ROOT/r9guide/index.html"
  done
fi
write_netlify_config

deploy_netlify() {
  echo "== deploying $ROOT to Netlify (production)"
  "$NETLIFY" deploy --prod --dir "$ROOT" --site "$SITE_ID" --message "update-apps ${WANT[*]:-all} $(date '+%F %T %Z')"
}

deploy_aws() {
  local A="aws --region $AWS_REGION_AMPLIFY"
  echo "== deploying $ROOT to AWS Amplify (app $AMPLIFY_APP_ID, branch $AMPLIFY_BRANCH)"
  $A sts get-caller-identity --query Account --output text >/dev/null 2>&1 || { echo "ERROR: AWS credentials missing or expired (run: aws login)" >&2; return 1; }
  local W; W="$(mktemp -d)"
  # Routing rules equivalent to _redirects: /app -> /app/ (301); extension-less paths under /app/ -> app shell (200);
  # anything else that isn't a real file -> 404.html (Amplify "404-200": served with HTTP 404).
  python3 - "$W" "${APPS[@]}" <<'PY'
import json, sys
w, entries = sys.argv[1], sys.argv[2:]
names = [e.split()[0] for e in entries]
rules = [{"source": f"/{n}", "target": f"/{n}/", "status": "301"} for n in names]
rules += [{"source": f"</^\\/{n}\\/[^.]*$/>", "target": f"/{n}/index.html", "status": "200"} for n in names]
rules.append({"source": "/<*>", "target": "/404.html", "status": "404-200"})
json.dump(rules, open(f"{w}/rules.json", "w"))
open(f"{w}/headers.yml", "w").write("customHeaders:\n  - pattern: '**/*.webmanifest'\n    headers:\n      - key: 'Content-Type'\n        value: 'application/manifest+json'\n")
PY
  $A amplify update-app --app-id "$AMPLIFY_APP_ID" --custom-rules "file://$W/rules.json" --custom-headers "file://$W/headers.yml" --query 'app.appId' --output text >/dev/null
  echo "   routing rules + headers updated"
  # Zip the site, leaving out local tooling and Netlify-only config
  python3 - "$ROOT" "$W/site.zip" <<'PY'
import os, sys, zipfile, fnmatch
root, out = sys.argv[1], sys.argv[2]
skip_dirs = {'shots', '.netlify'}
skip_files = ['update-*.sh', '.gitignore', '_redirects', '_headers']
n = 0
with zipfile.ZipFile(out, 'w', zipfile.ZIP_DEFLATED) as z:
    for d, dirs, files in os.walk(root):
        rel = os.path.relpath(d, root)
        if rel == '.':
            dirs[:] = [x for x in dirs if x not in skip_dirs and not x.endswith(('.new', '.old'))]
        for f in files:
            if rel == '.' and any(fnmatch.fnmatch(f, p) for p in skip_files): continue
            z.write(os.path.join(d, f), os.path.normpath(os.path.join(rel, f))); n += 1
print(f"   zipped {n} files")
PY
  local D JOB URL ST
  D=$($A amplify create-deployment --app-id "$AMPLIFY_APP_ID" --branch-name "$AMPLIFY_BRANCH" --output json)
  JOB=$(python3 -c 'import json,sys;print(json.load(sys.stdin)["jobId"])' <<<"$D")
  URL=$(python3 -c 'import json,sys;print(json.load(sys.stdin)["zipUploadUrl"])' <<<"$D")
  [[ $(curl -sS -o /dev/null -w '%{http_code}' -X PUT -H 'Content-Type: application/zip' --data-binary "@$W/site.zip" "$URL") == 200 ]] || { echo "ERROR: zip upload failed" >&2; rm -rf "$W"; return 1; }
  $A amplify start-deployment --app-id "$AMPLIFY_APP_ID" --branch-name "$AMPLIFY_BRANCH" --job-id "$JOB" >/dev/null
  for _ in $(seq 1 120); do
    ST=$($A amplify get-job --app-id "$AMPLIFY_APP_ID" --branch-name "$AMPLIFY_BRANCH" --job-id "$JOB" --query 'job.summary.status' --output text)
    [[ "$ST" == SUCCEED || "$ST" == FAILED || "$ST" == CANCELLED ]] && break; sleep 5
  done
  rm -rf "$W"
  echo "   Amplify job $JOB: $ST  ->  https://$AMPLIFY_BRANCH.$AMPLIFY_APP_ID.amplifyapp.com"
  [[ "$ST" == SUCCEED ]]
}

if [[ $DEPLOY == 1 ]]; then
  rc=0
  if [[ "$TARGET" == netlify || "$TARGET" == both ]]; then deploy_netlify || { echo "ERROR: Netlify deploy failed" >&2; rc=1; }; fi
  if [[ "$TARGET" == aws || "$TARGET" == both ]]; then deploy_aws || { echo "ERROR: AWS Amplify deploy failed" >&2; rc=1; }; fi
  exit $rc
fi
