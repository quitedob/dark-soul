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

& $Godot --headless --path $GameRoot --import
Assert-LastExitCode "Godot project import"

# 委托本地 CI：完整 GUT + 可收集 JUnit（build/ci/gut-results.xml）
& (Join-Path $PSScriptRoot "ci.ps1") -Godot $Godot -SkipImport
Assert-LastExitCode "Godot GUT CI suite"

& $Godot --headless --path $GameRoot --script "res://tests/smoke/core_contract_test.gd"
Assert-LastExitCode "Godot core contracts"

& $Godot --headless --path $GameRoot --script "res://tests/smoke/combat_contract_test.gd"
Assert-LastExitCode "Godot combat contracts"

& $Godot --headless --path $GameRoot --script "res://tests/smoke/combat_style_resource_contract_test.gd"
Assert-LastExitCode "Godot combat style resource contracts"

& $Godot --headless --path $GameRoot --script "res://tests/smoke/feedback_contract_test.gd"
Assert-LastExitCode "Godot feedback contracts"

& $Godot --headless --path $GameRoot --script "res://tests/smoke/weapon_trail_contract_test.gd"
Assert-LastExitCode "Godot weapon trail contracts"

& $Godot --headless --path $GameRoot --script "res://tests/smoke/enemy_ai_tuning_contract_test.gd"
Assert-LastExitCode "Godot enemy AI tuning contracts"

& $Godot --headless --path $GameRoot --script "res://tests/smoke/boss_chapter_powers_contract_test.gd"
Assert-LastExitCode "Godot boss chapter powers contracts"

& $Godot --headless --path $GameRoot --script "res://tests/smoke/enemy_attack_catalog_contract_test.gd"
Assert-LastExitCode "Godot enemy attack catalog contracts"

& $Godot --headless --path $GameRoot --script "res://tests/smoke/poise_contract_test.gd"
Assert-LastExitCode "Godot poise contracts"

& $Godot --headless --path $GameRoot --script "res://tests/smoke/content_registry_contract_test.gd"
Assert-LastExitCode "Godot content registry contracts"

& $Godot --headless --path $GameRoot --script "res://tests/smoke/level_id_migration_contract_test.gd"
Assert-LastExitCode "Godot level ID migration contracts"

& $Godot --headless --path $GameRoot --script "res://tests/smoke/level_module_contract_test.gd"
Assert-LastExitCode "Godot level module contracts"

& $Godot --headless --path $GameRoot --script "res://tests/smoke/campaign_generation_contract_test.gd"
Assert-LastExitCode "Godot campaign generation contracts"

& $Godot --headless --path $GameRoot --script "res://tests/smoke/chapter1_slice_contract_test.gd"
Assert-LastExitCode "Godot Chapter 1 vertical slice contracts"

& $Godot --headless --path $GameRoot --script "res://tests/smoke/chapter2_slice_contract_test.gd"
Assert-LastExitCode "Godot Chapter 2 vertical slice contracts"

& $Godot --headless --path $GameRoot --script "res://tests/smoke/jump_collision_contract_test.gd"
Assert-LastExitCode "Godot jump/collision contracts"

& $Godot --headless --path $GameRoot --script "res://tests/smoke/context_attack_contract_test.gd"
Assert-LastExitCode "Godot context attack contracts"

& $Godot --headless --path $GameRoot --script "res://tests/smoke/grip_charge_contract_test.gd"
Assert-LastExitCode "Godot grip/charge contracts"

& $Godot --headless --path $GameRoot --script "res://tests/smoke/guard_execution_contract_test.gd"
Assert-LastExitCode "Godot guard/execution contracts"

& $Godot --headless --path $GameRoot --script "res://tests/smoke/combat_polish_contract_test.gd"
Assert-LastExitCode "Godot combat polish contracts"

& $Godot --headless --path $GameRoot --script "res://tests/smoke/boss_weakpoint_contract_test.gd"
Assert-LastExitCode "Godot boss weak-point contracts"

& $Godot --headless --path $GameRoot --script "res://tests/smoke/boss_polish_contract_test.gd"
Assert-LastExitCode "Godot boss polish contracts"

& $Godot --headless --path $GameRoot --script "res://tests/smoke/g01_macro_bt_contract_test.gd"
Assert-LastExitCode "Godot G-01 macro BT contracts"

& $Godot --headless --path $GameRoot --script "res://tests/smoke/lock_on_contract_test.gd"
Assert-LastExitCode "Godot lock-on contracts"

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
