#!/usr/bin/env bash
# 入口：对应 install.cmd。参数原样交给 install-plugin.sh。
# 不直接执行 install-plugin.sh，是为了不依赖它上面的可执行位（拷贝/解压常把它弄丢）。
set -eu
here=$(cd "$(dirname "$0")" && pwd)
exec bash "$here/install-plugin.sh" "$@"
