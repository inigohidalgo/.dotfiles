#!/usr/bin/env bash
# Shared allowlist and scanning helpers for the email guard hooks.
# Sourced by commit-msg and pre-push; not executable on its own.
#
# Only these addresses may appear as a commit author/committer, or anywhere
# in a commit message body. Anything else is refused.
#
# Kept deliberately in sync with ../identity-personal and ../identity-work.
# Written for bash 3.2 so it still works under macOS /bin/bash.

ALLOWED_EMAILS=(
	"inigohrey@gmail.com"       # git/identity-personal
	"inigo.hidalgorey@axpo.com" # git/identity-work
)

EMAIL_RE='[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}'

guard_disabled() {
	[ "${EMAIL_GUARD:-}" = "off" ]
}

lower() {
	printf '%s' "$1" | tr '[:upper:]' '[:lower:]'
}

is_allowed() {
	local candidate allowed
	candidate="$(lower "$1")"
	for allowed in "${ALLOWED_EMAILS[@]}"; do
		[ "$candidate" = "$(lower "$allowed")" ] && return 0
	done
	return 1
}

# Read text on stdin, print each disallowed address once.
find_disallowed() {
	local addrs addr
	addrs="$(grep -oEi "$EMAIL_RE" || true)"
	[ -n "$addrs" ] || return 0
	printf '%s\n' "$addrs" | sort -uf | while IFS= read -r addr; do
		is_allowed "$addr" || printf '%s\n' "$addr"
	done
}

# Pull the address out of a "Name <email> 1700000000 +0000" ident string.
ident_email() {
	printf '%s' "$1" | sed -n 's/.*<\(.*\)>.*/\1/p'
}

is_zero_sha() {
	[[ "$1" =~ ^0+$ ]]
}

guard_fail() {
	printf '\n\033[1;31mBLOCKED by email guard\033[0m — %s\n' "$1" >&2
}

guard_explain() {
	printf '\n  allowed: %s\n' "${ALLOWED_EMAILS[0]}" >&2
	local i
	for ((i = 1; i < ${#ALLOWED_EMAILS[@]}; i++)); do
		printf '           %s\n' "${ALLOWED_EMAILS[$i]}" >&2
	done
	printf '  bypass:  EMAIL_GUARD=off <your git command>\n' >&2
	printf '  hooks:   %s\n\n' "$GUARD_DIR" >&2
}

# Run the repository's own hook of this name, if it has one.
#
# A global core.hooksPath replaces .git/hooks entirely, which would silently
# disable tools that install there (notably the `pre-commit` framework), so we
# hand off explicitly. --git-dir rather than --git-path, since --git-path
# resolves back through core.hooksPath and would re-enter this same file.
chain_repo_hook() {
	local name=$1
	shift
	local git_dir repo_hook
	git_dir="$(git rev-parse --git-dir 2>/dev/null)" || return 0
	repo_hook="$git_dir/hooks/$name"
	[ -x "$repo_hook" ] || return 0
	if [ "$(cd "$(dirname "$repo_hook")" && pwd -P)" = "$(cd "$GUARD_DIR" && pwd -P)" ]; then
		return 0
	fi
	"$repo_hook" "$@"
}
