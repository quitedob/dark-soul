# 本地 CI：无头跑完整 GUT（unit + integration），收集 JUnit XML
# 用法: .\tools\ci.ps1 [-Godot <path>] [-JUnitOut <path>] [-SkipImport] [-StrictImport]
param(
    [string]$Godot = "",
    [string]$JUnitOut = "",
    [switch]$SkipImport,
    [switch]$StrictImport
)

$ErrorActionPreference = "Stop"

# 仓库根与 game/ 工程路径
$ProjectRoot = Split-Path -Parent $PSScriptRoot
$GameRoot = Join-Path $ProjectRoot "game"
$DefaultJUnit = Join-Path $ProjectRoot "build\ci\gut-results.xml"

function Resolve-GodotPath {
    param([string]$Explicit)
    # 优先：参数 → 环境变量 → 本机常见安装路径
    if ($Explicit -and (Test-Path -LiteralPath $Explicit -PathType Leaf)) {
        return (Resolve-Path -LiteralPath $Explicit).Path
    }
    if ($env:GODOT_BIN -and (Test-Path -LiteralPath $env:GODOT_BIN -PathType Leaf)) {
        return (Resolve-Path -LiteralPath $env:GODOT_BIN).Path
    }
    $candidates = @(
        "E:\godot\Godot_v4.7.1-stable_win64_console.exe",
        "D:\godot\Godot_v4.7.1-stable_win64_console.exe",
        "C:\godot\Godot_v4.7.1-stable_win64_console.exe"
    )
    foreach ($c in $candidates) {
        if (Test-Path -LiteralPath $c -PathType Leaf) {
            return $c
        }
    }
    throw "Godot console not found. Set -Godot or env GODOT_BIN to Godot_v4.7.1-stable_win64_console.exe"
}

function Get-GutDirs {
    # 只传入磁盘上存在的测试目录，避免 GUT 对空 integration 报 ERROR
    $dirs = @()
    foreach ($rel in @("tests\unit", "tests\integration")) {
        $abs = Join-Path $GameRoot $rel
        if (Test-Path -LiteralPath $abs -PathType Container) {
            $dirs += ("res://" + ($rel -replace '\\', '/') + "/")
        }
    }
    if ($dirs.Count -eq 0) {
        throw "No GUT test directories found under game/tests/."
    }
    return ($dirs -join ",")
}

function Assert-JUnitXml {
    param([string]$Path)
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        throw "JUnit XML was not written: $Path"
    }
    $xmlSize = (Get-Item -LiteralPath $Path).Length
    if ($xmlSize -lt 32) {
        throw "JUnit XML looks empty ($xmlSize bytes): $Path"
    }
    $head = Get-Content -LiteralPath $Path -TotalCount 5 | Out-String
    if ($head -notmatch "testsuites") {
        throw "JUnit XML missing <testsuites>: $Path"
    }
    Write-Host "ASHEN_CI: JUnit XML collected ($xmlSize bytes) -> $Path"
}

$GodotPath = Resolve-GodotPath -Explicit $Godot
if (-not $JUnitOut) {
    $JUnitOut = $DefaultJUnit
}

# JUnit 输出目录（已在 .gitignore 的 build/ 下）
$JUnitDir = Split-Path -Parent $JUnitOut
if (-not (Test-Path -LiteralPath $JUnitDir)) {
    New-Item -ItemType Directory -Path $JUnitDir -Force | Out-Null
}
if (Test-Path -LiteralPath $JUnitOut) {
    Remove-Item -LiteralPath $JUnitOut -Force
}

# Godot FileAccess 需要正斜杠绝对路径
$JUnitGodotPath = ($JUnitOut -replace '\\', '/')
$GutDirs = Get-GutDirs

Write-Host "ASHEN_CI: Godot=$GodotPath"
Write-Host "ASHEN_CI: GameRoot=$GameRoot"
Write-Host "ASHEN_CI: GutDirs=$GutDirs"
Write-Host "ASHEN_CI: JUnitOut=$JUnitOut"

if (-not $SkipImport) {
    # 导入/编辑器退出，确保 .godot 缓存可用（stderr 可能含 SCRIPT ERROR 文本）
    $prevEap = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    $importLines = & $GodotPath --headless --path $GameRoot --editor --quit 2>&1 |
        ForEach-Object { "$_" }
    $importExit = $LASTEXITCODE
    $ErrorActionPreference = $prevEap
    $importOut = $importLines -join "`n"
    if ($importOut -match "SCRIPT ERROR|Parse Error|Failed to load script") {
        if ($StrictImport) {
            Write-Host $importOut
            throw "Godot script validation reported an error (-StrictImport)."
        }
        Write-Host "ASHEN_CI: WARN import reported SCRIPT/Parse errors (continuing; use -StrictImport to fail)."
    }
    if ($importExit -ne 0) {
        throw "Godot editor import failed with exit code $importExit."
    }

    & $GodotPath --headless --path $GameRoot --import
    if ($LASTEXITCODE -ne 0) {
        throw "Godot project import failed with exit code $LASTEXITCODE."
    }
}

# 完整 GUT：显式 dirs + include_subdirs + 可收集 JUnit 绝对路径
& $GodotPath --headless --path $GameRoot `
    -s "addons/gut/gut_cmdln.gd" `
    "-gdir=$GutDirs" `
    -ginclude_subdirs `
    -gexit `
    "-gjunit_xml_file=$JUnitGodotPath"
$gutExit = $LASTEXITCODE

# 无论通过/失败都先校验并保留 JUnit，供 CI artifact 上传
Assert-JUnitXml -Path $JUnitOut

if ($gutExit -ne 0) {
    Write-Host "ASHEN_CI: GUT failed with exit code $gutExit (JUnit retained)."
    exit $gutExit
}

Write-Host "ASHEN_HOLLOW_CI_OK"
exit 0
