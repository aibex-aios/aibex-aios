# t11-project.sh: step 1 of the plan (V0.3, memo 32) - structure S1-S4 and name rule (spec 05)

#===============================================================================
# setup: vault §Demo as root project with repo, projects with and without gaps
#===============================================================================

   export PATH="/usr/bin:/bin:/usr/sbin:/sbin"
   export GIT_AUTHOR_NAME=t GIT_AUTHOR_EMAIL=t@t GIT_COMMITTER_NAME=t GIT_COMMITTER_EMAIL=t@t
   D="$SANDBOX/work/§Demo"
   mk() { mkdir -p "$(dirname "$1")"; printf '%s' "$2" > "$1"; }
   GI=$'.DS_Store\n.claude/skills/\n.aios/registry\n'
   mkproj() { mkdir -p "$1/@"; mk "$1/.gitignore" "$GI"; git -C "$1" init -q; }

   mkproj "$D"
   mk "$D/.gitignore" "$GI"$'/G-Garten/\n/P-Projekte/\n'
   mkproj "$D/G-Garten"                                   # complete
   mkdir -p "$D/S-Sternwarte/@"                           # @/ only, tracked by the root repo
   mk "$D/S-Sternwarte/@/stern.md" $'# Stern\n'
   mkproj "$D/P-Projekte/PB-Blogs"                        # covered by the broader exclusion /P-Projekte/
   mkproj "$D/P-Projekte/PB-Blogs/PB1-Die-KI-Kann-Viel"   # nested: parent repo PB-Blogs does not exclude it
   mkdir -p "$D/L-Labor/@"; mk "$D/L-Labor/.gitignore" $'.DS_Store\n'; git -C "$D/L-Labor" init -q
   git -C "$D" add .gitignore S-Sternwarte && git -C "$D" commit -qm init

   GAPS() { PYTHONPATH="$SRC/lib" python3 -c "
from aios import project
print('|'.join(g.text for g in project.check('$1')))"; }
   NAME() { PYTHONPATH="$SRC/lib" python3 -c "
from aios import project
n = project.check_name('$1'); print(('ok' if n.ok else 'bad') + '|' + n.proposal + '|' + ' / '.join(n.problems))"; }

#===============================================================================
# structure S1-S4
#===============================================================================

   assert_eq "$(GAPS "$D")" "" "root project complete (no parent repo above the vault root)"
   assert_eq "$(GAPS "$D/G-Garten")" "" "G-Garten complete"
   assert_eq "$(GAPS "$D/P-Projekte/PB-Blogs")" "" "broader exclusion /P-Projekte/ counts"
   assert_eq "$(GAPS "$D/S-Sternwarte")" "own git repo|.gitignore lines: .DS_Store, .claude/skills/, .aios/registry|exclusion in parent repo $D" "S-Sternwarte: repo, gitignore, parent"
   assert_eq "$(GAPS "$D/P-Projekte/PB-Blogs/PB1-Die-KI-Kann-Viel")" "exclusion in parent repo $D/P-Projekte/PB-Blogs" "nested repo needs exclusion in the nearest repo above"
   assert_eq "$(GAPS "$D/L-Labor")" ".gitignore lines: .claude/skills/, .aios/registry|exclusion in parent repo $D" "L-Labor: missing lines, not excluded"
   mkdir -p "$D/N-Neu"
   assert_contains "$(GAPS "$D/N-Neu")" "local masterspace @/" "S1 reported"

   OUT="$(PYTHONPATH="$SRC/lib" python3 -c "
from aios import project
p = project.parent_repo('$D/S-Sternwarte'); print(p.rel, p.ignored, p.tracked)")"
   assert_eq "$OUT" "S-Sternwarte False ['S-Sternwarte/@/stern.md']" "parent repo: relative path, not ignored, tracked files"
   echo '/S-Sternwarte/' >> "$D/.gitignore"
   assert_contains "$(GAPS "$D/S-Sternwarte")" "exclusion in parent repo" "ignored but still tracked: gap stays"
   git -C "$D" rm -rq --cached S-Sternwarte
   case "$(GAPS "$D/S-Sternwarte")" in *"exclusion"*) fail "ignored and untracked: S4 fulfilled" ;; *) ok ;; esac

   mkdir -p "$SANDBOX/work/Draussen/X-Proj/@"; git -C "$SANDBOX/work/Draussen" init -q
   assert_eq "$(GAPS "$SANDBOX/work/Draussen/X-Proj")" "own git repo|.gitignore lines: .DS_Store, .claude/skills/, .aios/registry" "outside a vault: no parent repo"

#===============================================================================
# name rule and proposal
#===============================================================================

   mkdir -p "$D/G-Garten/GB-Beet" "$D/G-Garten/G1-Eins" "$D/G-Garten/G12-Zwoelf" "$D/G-Garten/GBX-Zu-Lang" "$D/G-Garten/B-Beet" "$D/G-Garten/AT-Test" \
            "$D/labor neu" "$D/garten-zwei" "$D/KI-Tools" "$D/AA-Doppel" "$D/X-V0.3-2026" "$D/X-klein" \
            "$D/P-Projekte/PB-Blogs/PB1-Die-KI-Kann-Viel/PB1A-Teil" "$D/P-Projekte/PB-Blogs/pb2-die-ki" \
            "$D/Notizen/irgendwas" "$D/Notizen/Q-Frei" "$D/Notizen/Q-frei"
   assert_eq "$(NAME "$D")" "ok||" "vault root exempt"
   assert_eq "$(NAME "$D/G-Garten")" "ok||" "one capital letter under the vault root"
   assert_eq "$(NAME "$D/G-Garten/GB-Beet")" "ok||" "parent prefix plus a capital letter"
   assert_eq "$(NAME "$D/G-Garten/G1-Eins")" "ok||" "parent prefix plus a number"
   assert_eq "$(NAME "$D/G-Garten/G12-Zwoelf")" "ok||" "a number may have several digits"
   assert_eq "$(NAME "$D/X-V0.3-2026")" "ok||" "parts may start with a capital letter or a digit"
   assert_eq "$(NAME "$D/P-Projekte/PB-Blogs/PB1-Die-KI-Kann-Viel/PB1A-Teil")" "ok||" "prefix after a number prefix"
   assert_eq "$(NAME "$D/Notizen/Q-Frei")" "ok||" "parent without conforming name: only the form"
   assert_contains "$(NAME "$D/G-Garten/GBX-Zu-Lang")" "bad|" "two letters added is a violation"
   assert_contains "$(NAME "$D/G-Garten/GBX-Zu-Lang")" "does not fit the parent prefix G" "message names the parent prefix"
   assert_eq "$(NAME "$D/labor neu" | cut -d'|' -f1-2)" "bad|L-Labor-Neu" "proposal: whitespace, capitals, prefix"
   assert_eq "$(NAME "$D/garten-zwei" | cut -d'|' -f1-2)" "bad|G-Garten-Zwei" "proposal: initial letter"
   assert_eq "$(NAME "$D/KI-Tools" | cut -d'|' -f1-2)" "bad|K-Tools" "two-letter prefix under the root: replaced (L6)"
   assert_eq "$(NAME "$D/G-Garten/B-Beet" | cut -d'|' -f1-2)" "bad|GB-Beet" "prefix replaced by parent prefix plus its first letter (A11)"
   assert_eq "$(NAME "$D/G-Garten/AT-Test" | cut -d'|' -f1-2)" "bad|GA-Test" "first letter of the old prefix (L6)"
   assert_eq "$(NAME "$D/AA-Doppel" | cut -d'|' -f1-2)" "bad|A-Doppel" "prefix too long under the root (L6)"
   assert_contains "$(NAME "$D/AA-Doppel")" "must be one capital letter directly under the vault root" "root level message"
   assert_eq "$(NAME "$D/X-klein" | cut -d'|' -f1-2)" "bad|X-Klein" "valid prefix kept, part capitalized"
   assert_contains "$(NAME "$D/X-klein")" "the part 'klein' does not start with a capital letter or a digit" "lowercase part reported"
   assert_eq "$(NAME "$D/P-Projekte/PB-Blogs/pb2-die-ki" | cut -d'|' -f1-2)" "bad|PB2-Die-Ki" "lower-case prefix recognized and capitalized"
   assert_eq "$(NAME "$D/Notizen/irgendwas" | cut -d'|' -f1-2)" "bad|I-Irgendwas" "no prefix: proposal from the initial"
   assert_eq "$(NAME "$D/Notizen/Q-frei" | cut -d'|' -f1-2)" "bad|Q-Frei" "only the form under a non-conforming parent"
