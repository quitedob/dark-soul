#!/usr/bin/env bash
set -euo pipefail

GODOT="${GODOT:-godot}"
GAME_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
"$GODOT" --headless --path "$GAME_ROOT" -s addons/gut/gut_cmdln.gd -gconfig=res://.gutconfig.json -gexit -gjunit_xml_file=user://gut-results.xml
