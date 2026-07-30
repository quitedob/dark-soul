#!/usr/bin/env bash
# 本地 / Linux CI：无头跑完整 GUT，收集 JUnit XML
# 用法: ./tools/ci.sh [--godot PATH] [--junit PATH] [--skip-import] [--strict-import]
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
GAME_ROOT="$PROJECT_ROOT/game"
JUNIT_OUT="$PROJECT_ROOT/build/ci/gut-results.xml"
GODOT_BIN="${GODOT_BIN:-}"
SKIP_IMPORT=0
STRICT_IMPORT=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --godot) GODOT_BIN="$2"; shift 2 ;;
    --junit) JUNIT_OUT="$2"; shift 2 ;;
    --skip-import) SKIP_IMPORT=1; shift ;;
    --strict-import) STRICT_IMPORT=1; shift ;;
    *) echo "Unknown arg: $1" >&2; exit 2 ;;
  esac
done

# 解析 Godot 可执行文件
resolve_godot() {
  if [[ -n "${1:-}" && -x "$1" ]]; then
    echo "$1"
    return
  fi
  if [[ -n "${GODOT_BIN:-}" && -x "$GODOT_BIN" ]]; then
    echo "$GODOT_BIN"
    return
  fi
  for c in \
    "/usr/local/bin/godot" \
    "/opt/godot/Godot_v4.7.1-stable_linux.x86_64" \
    "$HOME/godot/Godot_v4.7.1-stable_linux.x86_64"
  do
    if [[ -x "$c" ]]; then
      echo "$c"
      return
    fi
  done
  echo "Godot not found. Set --godot or GODOT_BIN." >&2
  exit 1
}

# 只收集存在的测试目录
resolve_gut_dirs() {
  local dirs=()
  for rel in tests/unit tests/integration; do
    if [[ -d "$GAME_ROOT/$rel" ]]; then
      dirs+=("res://${rel}/")
    fi
  done
  if [[ ${#dirs[@]} -eq 0 ]]; then
    echo "No GUT test directories found under game/tests/." >&2
    exit 1
  fi
  local IFS=,
  echo "${dirs[*]}"
}

assert_junit() {
  local path="$1"
  if [[ ! -f "$path" ]]; then
    echo "JUnit XML missing: $path" >&2
    exit 1
  fi
  local size
  size=$(wc -c < "$path" | tr -d ' ')
  if [[ "$size" -lt 32 ]]; then
    echo "JUnit XML empty ($size bytes)" >&2
    exit 1
  fi
  if ! grep -q "testsuites" "$path"; then
    echo "JUnit XML missing <testsuites>" >&2
    exit 1
  fi
  echo "ASHEN_CI: JUnit XML collected ($size bytes) -> $path"
}

GODOT="$(resolve_godot "${GODOT_BIN:-}")"
GUT_DIRS="$(resolve_gut_dirs)"
mkdir -p "$(dirname "$JUNIT_OUT")"
rm -f "$JUNIT_OUT"

echo "ASHEN_CI: Godot=$GODOT"
echo "ASHEN_CI: GameRoot=$GAME_ROOT"
echo "ASHEN_CI: GutDirs=$GUT_DIRS"
echo "ASHEN_CI: JUnitOut=$JUNIT_OUT"

if [[ "$SKIP_IMPORT" -eq 0 ]]; then
  set +e
  IMPORT_OUT="$("$GODOT" --headless --path "$GAME_ROOT" --editor --quit 2>&1)"
  IMPORT_EXIT=$?
  set -e
  if echo "$IMPORT_OUT" | grep -Eq "SCRIPT ERROR|Parse Error|Failed to load script"; then
    if [[ "$STRICT_IMPORT" -eq 1 ]]; then
      echo "$IMPORT_OUT"
      echo "Godot script validation failed (--strict-import)." >&2
      exit 1
    fi
    echo "ASHEN_CI: WARN import reported SCRIPT/Parse errors (continuing; use --strict-import to fail)."
  fi
  if [[ "$IMPORT_EXIT" -ne 0 ]]; then
    echo "Godot editor import failed with exit code $IMPORT_EXIT" >&2
    exit "$IMPORT_EXIT"
  fi
  "$GODOT" --headless --path "$GAME_ROOT" --import
fi

set +e
"$GODOT" --headless --path "$GAME_ROOT" \
  -s addons/gut/gut_cmdln.gd \
  "-gdir=$GUT_DIRS" \
  -ginclude_subdirs \
  -gexit \
  "-gjunit_xml_file=$JUNIT_OUT"
GUT_EXIT=$?
set -e

assert_junit "$JUNIT_OUT"

if [[ "$GUT_EXIT" -ne 0 ]]; then
  echo "ASHEN_CI: GUT failed with exit code $GUT_EXIT (JUnit retained)."
  exit "$GUT_EXIT"
fi

echo "ASHEN_HOLLOW_CI_OK"
exit 0
