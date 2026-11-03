#!/usr/bin/env bash
# 把一个 dsh 插件装进某个 profile：不联网、不调用 pnpm。
#
# 与 install-plugin.ps1 一一对应（Windows 用 .ps1，macOS/Linux 用这个）：
#   payload 复制到 <DshHome>/profiles/<Profile>/node_modules/<name>
#   deps/ 里被 pnpm 提升的依赖补进同一个 node_modules（已存在的跳过）
#   profile 的 package.json 补 dependencies 与 dsh.profile.bundles
#   结尾用 dsh --dump-config 离线自检
# 可重复执行。bash 3.2 兼容——macOS 自带的就是 3.2，别用关联数组 / mapfile。

set -eu

Profile=web
DshHome=
Payload=
Deps=

die() { printf '%s\n' "$*" >&2; exit 1; }

usage() {
    cat <<'EOF'
用法: install.sh [-Payload <dir>] [-Profile <name>] [-DshHome <dir>] [-Deps <dir>]

  -Payload  插件包目录（含 package.json）。默认取脚本旁边 plugin/ 下唯一的目录。
  -Profile  目标 profile 名，默认 web。
  -DshHome  dsh 主目录；默认 $DSH_HOME，再退到 ~/.dsh。
  -Deps     被提升依赖的集合目录，默认脚本旁边的 deps/（不存在则跳过）。
EOF
}

while [ $# -gt 0 ]; do
    case "$1" in
        -Payload|--payload)   [ $# -ge 2 ] || die "缺少 $1 的值"; Payload=$2;  shift 2 ;;
        -Profile|--profile)   [ $# -ge 2 ] || die "缺少 $1 的值"; Profile=$2;  shift 2 ;;
        -DshHome|--dsh-home)  [ $# -ge 2 ] || die "缺少 $1 的值"; DshHome=$2;  shift 2 ;;
        -Deps|--deps)         [ $# -ge 2 ] || die "缺少 $1 的值"; Deps=$2;     shift 2 ;;
        -h|--help)            usage; exit 0 ;;
        *)                    usage >&2; die "未知参数: $1" ;;
    esac
done

here=$(cd "$(dirname "$0")" && pwd)

if [ -z "$DshHome" ]; then
    if [ -n "${DSH_HOME:-}" ]; then DshHome=$DSH_HOME; else DshHome=$HOME/.dsh; fi
fi

if [ -z "$Payload" ]; then
    found=0
    only=
    for d in "$here"/plugin/*/; do
        [ -d "$d" ] || continue
        found=$((found + 1))
        only=${d%/}
    done
    [ "$found" -eq 1 ] || die "无法确定 payload：$here/plugin 下有 $found 个目录。用 install-all.sh，或传 -Payload 指定一个。"
    Payload=$only
fi

if [ -z "$Deps" ] && [ -d "$here/deps" ]; then Deps=$here/deps; fi
if [ -n "$Deps" ] && [ ! -d "$Deps" ]; then die "deps 目录不存在：$Deps"; fi
[ -f "$Payload/package.json" ] || die "payload 不像插件包：$Payload 里没有 package.json"

command -v node >/dev/null 2>&1 || die "找不到 node —— dsh 本身也要 node，先把它放进 PATH"

read_field() {
    node -e 'const j = require(process.argv[1]); process.stdout.write(String(j[process.argv[2]] ?? ""))' "$Payload/package.json" "$1" 2>/dev/null
}
name=$(read_field name) || die "读不了 $Payload/package.json"
version=$(read_field version) || die "读不了 $Payload/package.json"
[ -n "$name" ] && [ -n "$version" ] || die "payload 的 package.json 缺 name/version：$Payload"

profile_dir=$DshHome/profiles/$Profile
manifest=$profile_dir/package.json
[ -f "$manifest" ] || die "profile '$Profile' 还没初始化（缺 $manifest）。先在那台机器上跑一次 dsh --profile $Profile，再执行本脚本。"

printf '安装 %s@%s -> profile %s\n' "$name" "$version" "$Profile"

node_modules=$profile_dir/node_modules
mkdir -p "$node_modules"

# 1. payload -> node_modules/<name>
target=$node_modules/$name
if [ -d "$target" ]; then
    existing=$(node -e 'try { process.stdout.write(require(process.argv[1]).version) } catch (e) {}' "$target/package.json" 2>/dev/null || true)
    printf '  已存在 %s@%s，覆盖\n' "$name" "${existing:-?}"
    rm -rf "$target"
fi
mkdir -p "$(dirname "$target")"
cp -R "$Payload" "$target"
printf '  包本体 -> %s\n' "$target"

# 2. 被提升的依赖 -> node_modules（已存在的跳过，避免覆盖目标机已有版本）
if [ -n "$Deps" ]; then
    added=0
    kept=0
    for entry in "$Deps"/*/; do
        [ -d "$entry" ] || continue
        entry=${entry%/}
        base=$(basename "$entry")
        case "$base" in
            @*)
                for sub in "$entry"/*/; do
                    [ -d "$sub" ] || continue
                    sub=${sub%/}
                    dst=$node_modules/$base/$(basename "$sub")
                    if [ -e "$dst" ]; then
                        kept=$((kept + 1))
                    else
                        mkdir -p "$node_modules/$base"
                        cp -R "$sub" "$dst"
                        added=$((added + 1))
                    fi
                done
                ;;
            *)
                dst=$node_modules/$base
                if [ -e "$dst" ]; then
                    kept=$((kept + 1))
                else
                    cp -R "$entry" "$dst"
                    added=$((added + 1))
                fi
                ;;
        esac
    done
    printf '  依赖补齐：新增 %s，已存在跳过 %s\n' "$added" "$kept"
fi

# 3. 依赖闭包自检：runtime 依赖要么在包内、要么在 profile 里
dep_list=$(node -e 'const j = require(process.argv[1]); process.stdout.write(Object.keys(j.dependencies || {}).join("\n"))' "$Payload/package.json" 2>/dev/null || true)
if [ -n "$dep_list" ]; then
    saved_ifs=$IFS
    IFS='
'
    for dep in $dep_list; do
        [ -n "$dep" ] || continue
        if [ ! -f "$target/node_modules/$dep/package.json" ] && [ ! -f "$node_modules/$dep/package.json" ]; then
            printf 'WARNING: 依赖 %s 既不在插件包内也不在 profile 里 —— 离线启动会 import 失败\n' "$dep" >&2
        fi
    done
    IFS=$saved_ifs
fi

# 4. 登记到 profile package.json（UTF-8 无 BOM，键序保持原样）
node -e '
const fs = require("fs");
const [p, name, version] = process.argv.slice(1);
const j = JSON.parse(fs.readFileSync(p, "utf8"));
j.dependencies = j.dependencies || {};
j.dependencies[name] = version;
j.dsh = j.dsh || {};
j.dsh.profile = j.dsh.profile || {};
const bundles = j.dsh.profile.bundles = j.dsh.profile.bundles || [];
if (!bundles.includes(name)) bundles.push(name);
fs.writeFileSync(p, JSON.stringify(j, null, 2) + "\n");
' "$manifest" "$name" "$version"
printf '  已登记到 %s\n' "$manifest"

# 5. 断网验收：组合后的 profile 树里必须出现插件层（显式指定 home）
# 有的 profile 由宿主独占（desktop 归 Electron App），dsh 不给 dump，退回结构校验。
dump=$(DSH_HOME=$DshHome dsh --profile "$Profile" --dump-config 2>&1) || dump_status=$?
case ${dump_status:-0} in
    0) ;;
    *)
        printf '  dsh --dump-config 不可用（%s），改查结构\n' "$(printf '%s' "$dump" | head -n 1)"
        node -e '
const fs = require("fs");
const [home, profile, name] = process.argv.slice(1);
const dir = `${home}/profiles/${profile}`;
const body = `${dir}/node_modules/${name}/package.json`;
const man = JSON.parse(fs.readFileSync(`${dir}/package.json`, "utf8"));
const declared = !!(man.dependencies && man.dependencies[name]);
const listed = !!(man.dsh && man.dsh.profile && (man.dsh.profile.bundles || []).includes(name));
const ok = declared && listed && fs.existsSync(body);
if (!ok) {
  console.error(`结构校验未过：${dir}/package.json 里缺 ${name} 声明，或包本体不在 ${body}`);
  process.exit(1);
}
' "$DshHome" "$Profile" "$name" || { printf '结构校验未过\n' >&2; exit 1; }
        printf '  自检通过（结构）：dependencies + bundles + 包本体都在\n\n'
        exit 0
        ;;
esac
case $dump in
    *"$name"*) printf "  自检通过：profile 树含 '%s' 层\n\n" "$name" ;;
    *) printf "组合后的 profile 里看不到 '%s' 层，检查 %s\n" "$name" "$manifest" >&2; exit 1 ;;
esac
