#!/bin/zsh

function version_gt() {
	test "$(printf '%s\n' "$@" | sort -V | head -n 1)" != "$1"
}
version_gt "$@"
