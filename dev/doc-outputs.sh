#!/bin/bash
# doc-outputs.sh: outputs of the commands in README and tutorials, from a sandbox with a local hub of
# the tagged package repos (the state after publishing; V0.5, step 14); paths shown as ~/…

   if [ "$*" == "-?" ] || [ "$*" == "--help" ]; then
      echo '   usage: dev/doc-outputs.sh [<repos>]    # print the outputs, section by section (### <label>)'
      echo '          dev/doc-outputs.sh --version    # print version'
      echo '   <repos>: the package repos (default ~/git/AIbex); tutorial 05 sets up the workhorses from'
      echo '   PyPI, tutorial 04 clones from GitHub (network); nothing outside the sandbox is changed'
      echo '   see also: doc/tutorials, tests/live/rothirsch.sh'
      exit 1
   fi

#===============================================================================
# print version: dev/doc-outputs.sh --version
#===============================================================================

   if [ "$*" == "--version" ]; then
      echo "0.1.0"; exit 0
   fi

#===============================================================================
# run: dev/doc-outputs.sh [<repos>]
#===============================================================================

   if [ "$2" == "" ]; then
      REPOS="${1:-$HOME/git/AIbex}"
      REPO="$(cd "$(dirname "$0")/.." && pwd)"
      T="${TMPDIR:-/tmp}"; SB="$(cd "$(mktemp -d "${T%/}/aios-doc.XXXXXX")" && pwd -P)" || exit 1
      G() { git -c user.name=du -c user.email=du@example.org "$@"; }

      S="$SB/kernel"                                # the kernel as v0.5.0 (sandbox clone with the tag)
      (cd "$REPO" && git -c core.quotePath=false ls-files -co --exclude-standard) | while IFS= read -r F; do
         mkdir -p "$S/$(dirname "$F")"; cp -p "$REPO/$F" "$S/$F"
      done
      G -C "$S" init -q && G -C "$S" add -A && G -C "$S" commit -q -m v0.5.0 && G -C "$S" tag v0.5.0 || exit 1

      mkdir -p "$SB/hubs/aibex-aios/aios-index" "$SB/hubs/aibex-hub"   # aibex-hub has no index
      printf 'schema: 1\npackages:\n' > "$SB/hubs/aibex-aios/aios-index/index.yaml"
      for D in "$REPOS"/*/; do                      # hubs from the origin of each package repo
         P="$(basename "$D")"
         [ -f "$D/manifest.yaml" ] && [ "$P" != "aibex-aios" ] || continue
         case "$(git -C "$D" remote get-url origin 2>/dev/null)" in *aibex-hub/*) H=aibex-hub ;; *) H=aibex-aios ;; esac
         case "$P" in assistent-*) continue ;; esac  # the index of v0.5 names assistant-*
         G clone -q "$D" "$SB/hubs/$H/$P" || exit 1
         DESC="$(sed -n 's/^description: *//p' "$D/manifest.yaml" | sed 's/^"//; s/"$//')"
         [ "$H" == "aibex-aios" ] && printf '  - name: %s\n    type: %s\n    description: "%s"\n' "$P" \
            "$(sed -n 's/^type: *//p' "$D/manifest.yaml")" "$DESC" >> "$SB/hubs/$H/aios-index/index.yaml"
      done
      G -C "$SB/hubs/aibex-aios/aios-index" init -q && G -C "$SB/hubs/aibex-aios/aios-index" add -A &&
         G -C "$SB/hubs/aibex-aios/aios-index" commit -q -m index

      mkdir -p "$SB/home/bin" "$SB/home/.aios" "$SB/home/tmp"
      export HOME="$SB/home" AIOS_PREFIX="$SB/opt" AIOS_CLAUDE_DIR="$SB/home/.claude"
      export AIOS_GITHUB="file://$SB/hubs"                # the hubs are the GitHub organizations
      printf 'v0.5.0: %s\n' "$S" > "$HOME/.aios/installations.yaml"
      printf '#!/bin/bash\nexec "%s/bin/aios" "$@"\n' "$S" > "$HOME/bin/aios"; chmod +x "$HOME/bin/aios"
      PYDIR=""                                      # never the real ~/bin in PATH: aios --install would
      for P in $(type -ap python3) /opt/homebrew/bin/python3 /usr/local/bin/python3 /usr/bin/python3; do
         [ -x "$P" ] && "$P" -c "import yaml, venv, ensurepip" 2>/dev/null && { PYDIR="$(dirname "$P")"; break; }
      done                                          # update the user's stup there (V0.5, memo 61)
      [ -n "$PYDIR" ] || { echo "*** needs a python3 with PyYAML, venv and ensurepip" >&2; exit 1; }
      export PATH="$HOME/bin:$PYDIR:/usr/bin:/bin:/usr/sbin:/sbin"
      mkdir -p "$AIOS_PREFIX"

      show() {                                      # show <label> <dir> <command...>
         local L="$1" D="$2"; shift 2
         echo "### $L"
         (cd "$D" && "$@" 2>&1) | sed -e "s|$SB/home|~|g" -e "s|file://$SB/hubs|https://github.com|g" \
            -e "s|$SB/hubs|https://github.com|g" -e "s|$SB/opt|/opt/aios|g" -e "s|$S|/opt/aios/v0.5.0|g" \
            -e "s|0\.5\.0-dev|0.5.0|g"
         echo
      }
      V="$HOME/tmp/§Demo"; mkdir -p "$V"

      # tutorial 01
      show "01 activate" "$V" aios --activate v0.5.0 "$V" --yes
      mkdir -p "$V/@/@Rule"; printf '# Stil\nAntworte kurz und auf Deutsch.\n' > "$V/@/@Rule/stil.md"
      for P in G-Garten S-Sternwarte; do mkdir -p "$V/$P"; aios --init "$V/$P" --yes >/dev/null 2>&1; done
      show "01 library assistant" "$V" aios --library assistant
      show "01 fetch gaertner plan" "$V" aios --fetch assistant-gaertner --to "$V" --plan
      show "01 fetch gaertner" "$V" aios --fetch assistant-gaertner --to "$V" --yes
      show "01 config" "$V" cat .aios/config.yaml
      show "01 context garten" "$V/G-Garten" aios --context --list
      show "01 fetch astronom" "$V" aios --fetch assistant-astronom --to "$V/S-Sternwarte" --yes

      # tutorial 02 (the projects of tutorial 01 committed)
      for P in "$V" "$V/G-Garten" "$V/S-Sternwarte"; do G -C "$P" add -A >/dev/null; G -C "$P" commit -qm "Tutorial 01" >/dev/null; done
      mkdir -p "$V/G-Garten/beet"
      show "02 init beet plan" "$V" aios --init "$V/G-Garten/beet" --plan
      show "02 init beet" "$V" aios --init "$V/G-Garten/beet" --name GB-Beet --yes
      G -C "$V" add -A >/dev/null; G -C "$V" commit -qm "GB-Beet" >/dev/null
      rm "$V/S-Sternwarte/.gitignore"
      printf '# Notiz\n' > "$V/G-Garten/@/notiz.md"
      show "02 integrity" "$V" aios --integrity "$V"
      G -C "$V/G-Garten" add -A >/dev/null; G -C "$V/G-Garten" commit -qm notiz >/dev/null
      aios --init "$V/S-Sternwarte" --yes >/dev/null 2>&1

      # tutorial 03
      show "03 hubs" "$V" aios --hubs
      show "03 library rechner" "$V" aios --library rechner
      show "03 library app" "$V" aios --library app-taschenrechner
      show "03 fetch app plan" "$V" aios --fetch app-taschenrechner --plan
      show "03 fetch app" "$V" aios --fetch app-taschenrechner --yes
      show "03 config" "$V" cat .aios/config.yaml
      show "03 lock" "$V" sed -n '/app-taschenrechner:/,/required_by\|requested/p' .aios/lock.yaml
      show "03 gui apps" "$V" aios --gui --apps
      show "03 hubs add" "$V" aios --hubs add aibex-hub --vault --yes
      show "03 hubs 2" "$V" aios --hubs
      show "03 library scorpio search" "$V" aios --library scorpio
      show "03 library scorpio" "$V" aios --library aibex-hub/knowledge-scorpio
      (cd "$V" && aios --fetch knowledge-orion --yes >/dev/null 2>&1)
      show "03 fetch scorpio" "$V" aios --fetch aibex-hub/knowledge-scorpio --yes
      show "03 config 2" "$V" cat .aios/config.yaml
      show "03 fetch 0.3.2 plan" "$V" aios --fetch app-taschenrechner==0.3.2 --plan
      show "03 deploy" "$V" aios --deploy

      # tutorial 05 (a vault of its own)
      V="$HOME/tmp/§Rothirsch"; mkdir -p "$V/P-Projekt"
      show "05 install rothirsch plan" "$V" aios --install distribution-rothirsch "$V" --plan
      show "05 install rothirsch" "$V" aios --install distribution-rothirsch "$V" --yes
      show "05 worker" "$V" aios --worker
      aios --init "$V/P-Projekt" --yes >/dev/null 2>&1
      show "05 which" "$V/P-Projekt" "$HOME/.aios/bin/yt-dlp" ---which
      show "05 version" "$V/P-Projekt" "$HOME/.aios/bin/yt-dlp" --version
      show "05 outside" "$HOME" "$HOME/.aios/bin/yt-dlp" --version
      show "05 workers.yaml" "$V" cat "$AIOS_PREFIX/workers.yaml"
      show "05 config" "$V" cat .aios/config.yaml
      show "05 advise" "$V/P-Projekt" bash -c "chmod -R u+w '$AIOS_PREFIX/workers/worker-yt-dlp' && mv '$AIOS_PREFIX/workers/worker-yt-dlp' '$SB/gone' && aios --context --advise </dev/null | grep AIOS-WORKERS"
      show "05 reconcile plan" "$V" aios --fetch --plan
      show "05 reconcile" "$V" aios --fetch --yes
      show "05 remove plan" "$V" aios --fetch --remove distribution-rothirsch --plan

      # tutorial 04 (network: GitHub)
      V="$HOME/tmp/§Demo"; W="$V/W-Werkstatt"; mkdir -p "$W"
      show "04 init" "$W" aios --init --yes
      mkdir -p "$W/.aios"; cat > "$W/.aios/workspace.yaml" <<'EOF'
schema: 1
remotes:
  aibex: https://github.com/aibex-aios
projects:
  - name: app-taschenrechner
    remote: aibex
    revision: v0.4.0
    path: app-taschenrechner
  - name: skill-memo
    remote: aibex
    revision: main
    path: skill-memo
  - name: knowledge-orion
    remote: aibex
    revision: main
    path: wissen/knowledge-orion
    groups: [wissen]
EOF
      show "04 update plan" "$W" aios --workspace update --plan
      show "04 update" "$W" aios --workspace update --yes
      show "04 log" "$W" git log -3 --format=%s
      show "04 status" "$W" aios --workspace status
      show "04 integrity" "$W" aios --integrity

      chmod -R u+w "$SB"; rm -rf "$SB"
      exit 0
   fi

#===============================================================================
# cannot deal with anything else ...
#===============================================================================

   "$0" -?
   exit 1
