param(
    [string]$Godot = "E:\godot\Godot_v4.7.1-stable_win64_console.exe"
)

$ErrorActionPreference = "Stop"
$GameRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
& $Godot --headless --path $GameRoot -s addons/gut/gut_cmdln.gd -gconfig=res://.gutconfig.json -gexit -gjunit_xml_file=user://gut-results.xml
if ($LASTEXITCODE -ne 0) {
    throw "GUT failed with exit code $LASTEXITCODE."
}
