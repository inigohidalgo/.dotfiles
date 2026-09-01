#!/usr/bin/env bash
# Exercise the email guard hooks in a throwaway repo.
set -uo pipefail

HOOKS=/Users/inigo/dev/repos/ihr/.dotfiles/git/hooks
WORK=$(mktemp -d /tmp/eg-XXXXXX)
BARE="$WORK/remote.git"
REPO="$WORK/repo"
BAD="cavity_lyrics862@simplelogin.com"
GOOD="inigohrey@gmail.com"

pass=0
fail=0

check() { # check <name> <expected: ok|blocked> <actual rc>
	local name=$1 expect=$2 rc=$3
	local got=ok
	[ "$rc" -ne 0 ] && got=blocked
	if [ "$got" = "$expect" ]; then
		printf '  \033[32mPASS\033[0m  %-52s (%s)\n' "$name" "$got"
		pass=$((pass + 1))
	else
		printf '  \033[31mFAIL\033[0m  %-52s expected %s, got %s\n' "$name" "$expect" "$got"
		fail=$((fail + 1))
	fi
}

git init -q --bare "$BARE"
git init -q "$REPO"
cd "$REPO" || exit 1
git config core.hooksPath "$HOOKS"
git config user.name "Inigo H"
git config user.email "$GOOD"
git remote add origin "$BARE"

echo
echo "--- commit-msg ---"

echo a >a.txt && git add a.txt
git commit -q -m "plain clean message" >/dev/null 2>&1
check "clean commit, allowed author" ok $?

echo b >b.txt && git add b.txt
git commit -q -m "contact $BAD for details" >/dev/null 2>&1
check "body contains disallowed address" blocked $?

git commit -q -m "ping $GOOD about this" >/dev/null 2>&1
check "body contains allowed address" ok $?

echo c >c.txt && git add c.txt
git -c user.email="$BAD" commit -q -m "message is fine" >/dev/null 2>&1
check "disallowed author email" blocked $?

# `git commit -v` places an uncommented diff below the scissors line; addresses
# there never reach the stored message and must not trip the guard.
echo "maintainer: someone@example.org" >>c.txt && git add c.txt
printf 'real subject\n#\n# ------------------------ >8 ------------------------\ndiff --git a/c.txt b/c.txt\n+maintainer: someone@example.org\n' >"$WORK/msg-v"
git commit -q -F "$WORK/msg-v" >/dev/null 2>&1
check "below >8 allowed at commit time (pre-push backstops)" ok $?
git reset -q --hard HEAD~1

# git's -m/-F default cleanup is `whitespace`, which stores # lines verbatim,
# so a commented-out address really does land in the commit and must be caught.
echo d >d.txt && git add d.txt
printf 'real subject\n# reviewer: %s\n' "$BAD" >"$WORK/msg-c"
git commit -q -F "$WORK/msg-c" >/dev/null 2>&1
check "address in a # line that -F would have stored" blocked $?

echo e >e.txt && git add e.txt
EMAIL_GUARD=off git commit -q -m "override: $BAD" >/dev/null 2>&1
check "EMAIL_GUARD=off bypasses the guard" ok $?
# Drop it again so the push tests below start from genuinely clean history.
git reset -q --hard HEAD~1

echo
echo "--- chaining to a repo-local hook ---"
mkdir -p .git/hooks
printf '#!/usr/bin/env bash\necho CHAINED >>"%s/chain.log"\nexit 0\n' "$WORK" >.git/hooks/commit-msg
chmod +x .git/hooks/commit-msg
echo f >f.txt && git add f.txt
git commit -q -m "should reach the repo hook" >/dev/null 2>&1
check "clean commit still succeeds with repo hook" ok $?
[ -f "$WORK/chain.log" ]
check "repo-local .git/hooks/commit-msg was invoked" ok $?

printf '#!/usr/bin/env bash\nexit 3\n' >.git/hooks/commit-msg
chmod +x .git/hooks/commit-msg
echo g >g.txt && git add g.txt
git commit -q -m "repo hook rejects this" >/dev/null 2>&1
check "repo hook's own rejection propagates" blocked $?
rm -f .git/hooks/commit-msg

echo
echo "--- pre-push ---"

git push -q origin HEAD:refs/heads/main >/dev/null 2>&1
check "push of clean history" ok $?

echo h >h.txt && git add h.txt
git commit -q --no-verify -m "slipped past: $BAD" >/dev/null 2>&1
check "--no-verify lets the bad commit be created" ok $?

git push -q origin HEAD:refs/heads/main >/dev/null 2>&1
check "pre-push catches the --no-verify commit" blocked $?

EMAIL_GUARD=off git push -q origin HEAD:refs/heads/main >/dev/null 2>&1
check "EMAIL_GUARD=off bypasses pre-push" ok $?

echo
echo "--- report readability ---"
echo i >i.txt && git add i.txt
git commit -q --no-verify -m "another leak $BAD" >/dev/null 2>&1
git push origin HEAD:refs/heads/other 2>&1 | sed 's/^/  | /'

echo
printf 'passed %d, failed %d\n' "$pass" "$fail"
cd /tmp && rm -rf "$WORK"
[ "$fail" -eq 0 ]
