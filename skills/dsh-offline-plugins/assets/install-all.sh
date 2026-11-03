#!/usr/bin/env bash
# 安装 plugin/ 下的每个插件，对应 install-all.cmd。可重复执行。
# 额外参数（-Profile desktop / -DshHome ...）会透传给每个 install.sh。
set -eu

here=$(cd "$(dirname "$0")" && pwd)
rc=0
found=0

for d in "$here"/plugin/*/; do
    [ -d "$d" ] || continue
    dir=${d%/}
    found=$((found + 1))
    if [ -f "$dir/package.json" ]; then
        printf '\n'
        bash "$here/install.sh" -Payload "$dir" "$@" || rc=1
    else
        printf 'skip %s (no package.json)\n' "$(basename "$dir")"
    fi
done

[ "$found" -gt 0 ] || { printf '错误：%s/plugin 下没有包目录\n' "$here" >&2; exit 1; }
printf '\n'
if [ "$rc" -ne 0 ]; then
    printf 'Some plugins failed - see the messages above.\n' >&2
    exit 1
fi
printf 'All plugins installed. Restart dsh to load them.\n'
