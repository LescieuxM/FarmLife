#!/bin/sh
printf '\033c\033]0;%s\a' FarmLife
base_path="$(dirname "$(realpath "$0")")"
"$base_path/FarmLife.x86_64" "$@"
