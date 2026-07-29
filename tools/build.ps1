param(
    [string]$Godot = "D:\godot\Godot_v4.7.1-stable_win64_console.exe",
    [string]$Flutter = "D:\flutter\OpenHarmony-flutter\flutter_flutter\bin\flutter.bat",
    [switch]$SkipGodotExport,
    [switch]$SkipFlutter,
    [switch]$SkipFlutterTests,
    [switch]$SkipHap
)

$ErrorActionPreference = "Stop"
$ProjectRoot = Split-Path -Parent $PSScriptRoot
$GameRoot = Join-Path $ProjectRoot "game"
$AppRoot = Join-Path $ProjectRoot "app"

function Assert-LastExitCode([string]$Step) {
    if ($LASTEXITCODE -ne 0) {
        throw "$Step failed with exit code $LASTEXITCODE."
    }
}

if (-not (Test-Path -LiteralPath $Godot -PathType Leaf)) {
    throw "Godot executable not found: $Godot"
}

$parseOutput = & $Godot --headless --path $GameRoot --editor --quit 2>&1
if ($parseOutput -match "SCRIPT ERROR|Parse Error|Failed to load script") {
    $parseOutput | Out-String | Write-Error
    throw "Godot script validation reported an error."
}
Assert-LastExitCode "Godot editor import"

& $Godot --headless --path $GameRoot --script "res://tests/smoke/core_contract_test.gd"
Assert-LastExitCode "Godot core contracts"

& $Godot --headless --path $GameRoot -- --smoke-test --new-run
Assert-LastExitCode "Godot gameplay smoke test"

if (-not $SkipGodotExport) {
    $WebOutput = Join-Path $AppRoot "ohos\entry\src\main\resources\rawfile\game\index.html"
    & $Godot --headless --path $GameRoot --export-debug "Web" $WebOutput
    Assert-LastExitCode "Godot web export"
}

if (-not $SkipFlutter) {
    if (-not (Test-Path -LiteralPath $Flutter -PathType Leaf)) {
        throw "Flutter executable not found: $Flutter"
    }
    Push-Location $AppRoot
    try {
        & $Flutter pub get
        Assert-LastExitCode "Flutter dependency resolution"

        & $Flutter analyze
        Assert-LastExitCode "Flutter analysis"

        if (-not $SkipFlutterTests) {
            & $Flutter test --no-pub
            Assert-LastExitCode "Flutter tests"
        }

        & $Flutter build bundle --debug
        Assert-LastExitCode "Flutter debug bundle"

        if (-not $SkipHap) {
            & $Flutter build hap --debug
            Assert-LastExitCode "OpenHarmony HAP build"
        }
    }
    finally {
        Pop-Location
    }
}

Write-Host "ASHEN_HOLLOW_BUILD_OK"
