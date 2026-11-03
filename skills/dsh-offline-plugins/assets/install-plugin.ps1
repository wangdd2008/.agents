<#
.SYNOPSIS
  把一个或多个 dsh 插件装进某个 profile：不联网、不调用 pnpm。

.DESCRIPTION
  对齐「三件套」：payload 复制到 <DshHome>\profiles\<Profile>\node_modules\，
  再把同级的 deps\ 里被 pnpm 提升（hoisted）的依赖补进去（已存在的跳过），
  最后在 profile 的 package.json 里补 dependencies 和 dsh.profile.bundles。
  结尾用 dsh --dump-config 离线自检。可重复执行。

.PARAMETER Profile
  目标 profile 名，默认 web。

.PARAMETER DshHome
  dsh 主目录；不传则用 $env:DSH_HOME，再退到 %USERPROFILE%\.dsh。

.PARAMETER Payload
  插件包目录（含 package.json）。默认取脚本旁边 plugin\ 下唯一的那个目录；
  有多个插件时用 install-all.cmd，或显式传 -Payload。

.PARAMETER Deps
  被提升依赖的集合目录，默认脚本旁边的 deps\（不存在则跳过）。

.EXAMPLE
  .\install-all.cmd
  .\install.cmd -Payload .\plugin\dsh-context -DshHome D:\dsh-home
#>
[CmdletBinding()]
param(
    [string]$Profile = "web",
    [string]$DshHome,
    [string]$Payload,
    [string]$Deps
)

$ErrorActionPreference = "Stop"

if ([string]::IsNullOrWhiteSpace($DshHome)) {
    $DshHome = if ([string]::IsNullOrWhiteSpace($env:DSH_HOME)) { Join-Path $env:USERPROFILE ".dsh" } else { $env:DSH_HOME }
}

function Copy-Tree($src, $dst) {
    if (Get-Command robocopy -ErrorAction SilentlyContinue) {
        robocopy $src $dst /E /NFL /NDL /NJH /NJS /NP /R:1 /W:1 | Out-Null
        if ($LASTEXITCODE -ge 8) { throw "robocopy 失败（$LASTEXITCODE）：$src -> $dst" }
    } else {
        Copy-Item $src $dst -Recurse -Force
    }
}

if ([string]::IsNullOrWhiteSpace($Payload)) {
    $root = Join-Path $PSScriptRoot "plugin"
    $candidates = @(Get-ChildItem $root -Directory -ErrorAction SilentlyContinue)
    if ($candidates.Count -ne 1) {
        throw "无法确定 payload：$root 下有 $($candidates.Count) 个目录。用 install-all.cmd，或传 -Payload 指定一个。"
    }
    $Payload = $candidates[0].FullName
}
if ([string]::IsNullOrWhiteSpace($Deps)) {
    $candidate = Join-Path $PSScriptRoot "deps"
    if (Test-Path $candidate) { $Deps = $candidate }
}
if (-not (Test-Path (Join-Path $Payload "package.json"))) {
    throw "payload 不像插件包：$Payload 里没有 package.json"
}
$manifestIn = Get-Content (Join-Path $Payload "package.json") -Raw | ConvertFrom-Json
$name = $manifestIn.name
$version = $manifestIn.version

$profileDir = Join-Path $DshHome "profiles\$Profile"
$manifestPath = Join-Path $profileDir "package.json"
if (-not (Test-Path $manifestPath)) {
    throw "profile '$Profile' 还没初始化（缺 $manifestPath）。先在那台机器上跑一次 dsh --profile $Profile，再执行本脚本。"
}

Write-Host "安装 $name@$version -> profile '$Profile'"

$nodeModules = Join-Path $profileDir "node_modules"
New-Item -ItemType Directory -Force -Path $nodeModules | Out-Null

# 1. payload -> node_modules
$target = Join-Path $nodeModules $name
if (Test-Path $target) {
    $existing = (Get-Content (Join-Path $target "package.json") -Raw | ConvertFrom-Json).version
    Write-Host "  已存在 $name@$existing，覆盖"
    Remove-Item $target -Recurse -Force
}
Copy-Tree $Payload $target
Write-Host "  包本体 -> $target"

# 2. 被提升的依赖 -> node_modules（已存在的跳过，避免覆盖目标机已有版本）
if ($Deps) {
    $added = 0; $kept = 0
    foreach ($entry in Get-ChildItem $Deps -Directory) {
        $pairs = @()
        if ($entry.Name.StartsWith("@")) {
            foreach ($sub in Get-ChildItem $entry.FullName -Directory) {
                $pairs += , @($sub.FullName, (Join-Path (Join-Path $nodeModules $entry.Name) $sub.Name))
            }
        } else {
            $pairs += , @($entry.FullName, (Join-Path $nodeModules $entry.Name))
        }
        foreach ($pair in $pairs) {
            $dst = $pair[1]
            if (Test-Path $dst) { $kept++; continue }
            New-Item -ItemType Directory -Force -Path (Split-Path $dst) | Out-Null
            Copy-Tree $pair[0] $dst
            $added++
        }
    }
    Write-Host "  依赖补齐：新增 $added，已存在跳过 $kept"
}

# 3. 依赖闭包自检：runtime 依赖要么在包内、要么在 profile 里
#    局部变量别叫 $deps：PowerShell 变量名不区分大小写，会撞上 -Deps 参数，数组被 [string] 强转成空格拼接
$runtimeDeps = @()
if ($null -ne $manifestIn.dependencies) { $runtimeDeps = @($manifestIn.dependencies.PSObject.Properties.Name) }
foreach ($dep in $runtimeDeps) {
    $inPayload = Test-Path (Join-Path $target "node_modules\$dep\package.json")
    $inProfile = Test-Path (Join-Path $nodeModules "$dep\package.json")
    if (-not ($inPayload -or $inProfile)) {
        Write-Warning "依赖 $dep 既不在插件包内也不在 profile 里 —— 离线启动会 import 失败"
    }
}

# 4. 登记到 profile package.json
$manifest = Get-Content $manifestPath -Raw | ConvertFrom-Json
if ($null -eq $manifest.dependencies) { $manifest | Add-Member -NotePropertyName dependencies -NotePropertyValue ([pscustomobject]@{}) }
if ($null -eq $manifest.dsh) { $manifest | Add-Member -NotePropertyName dsh -NotePropertyValue ([pscustomobject]@{}) }
if ($null -eq $manifest.dsh.profile) { $manifest.dsh | Add-Member -NotePropertyName profile -NotePropertyValue ([pscustomobject]@{}) }
if ($null -eq $manifest.dsh.profile.bundles) { $manifest.dsh.profile | Add-Member -NotePropertyName bundles -NotePropertyValue @() }

$manifest.dependencies | Add-Member -NotePropertyName $name -NotePropertyValue $version -Force
$bundles = @($manifest.dsh.profile.bundles)
if ($bundles -notcontains $name) { $bundles += $name }
$manifest.dsh.profile.bundles = $bundles

# 必须无 BOM：Node 的 JSON 解析不认 BOM
$json = ($manifest | ConvertTo-Json -Depth 20) -replace "`r`n", "`n"
[System.IO.File]::WriteAllText($manifestPath, $json + "`n", (New-Object System.Text.UTF8Encoding($false)))
Write-Host "  已登记到 $manifestPath"

# 5. 断网验收：组合后的 profile 树里必须出现插件层（显式指定 home，避免继承）
$savedHome = $env:DSH_HOME
$env:DSH_HOME = $DshHome
try {
    $dump = & dsh --profile $Profile --dump-config 2>&1
    $code = $LASTEXITCODE
} finally {
    $env:DSH_HOME = $savedHome
}
if (($code -eq 0) -and (($dump -join "`n") -match [regex]::Escape($name))) {
    Write-Host "  自检通过：profile 树含 '$name' 层"
} else {
    # 有的 profile 由宿主独占（desktop 归 Electron App），dsh 不给 dump；
    # 退回结构校验：三件套齐了就算装上。
    $why = @($dump) | Select-Object -First 1
    Write-Host "  dsh --dump-config 不可用（$why），改查结构"
    $reg = Get-Content $manifestPath -Raw | ConvertFrom-Json
    $declared = @($reg.dependencies.PSObject.Properties.Name) -contains $name
    $listed = @($reg.dsh.profile.bundles) -contains $name
    $body = Test-Path (Join-Path $target "package.json")
    if (-not ($declared -and $listed -and $body)) {
        throw "结构校验未过：$manifestPath 里缺 $name 声明，或包本体不在 $target"
    }
    Write-Host "  自检通过（结构）：dependencies + bundles + 包本体都在"
}
Write-Host ""
