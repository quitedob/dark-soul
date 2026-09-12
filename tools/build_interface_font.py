"""Build/check the bundled UI font from an installed OFL Noto Sans SC font.

Requires fonttools. Build: python tools/build_interface_font.py --source FONT.ttf
Check only: python tools/build_interface_font.py --check
The source font is not downloaded or modified. Godot import is a separate step.
"""
import argparse
import hashlib
import json
from pathlib import Path
import re
import unicodedata

from fontTools import subset
from fontTools.ttLib import TTFont
from fontTools.varLib.instancer import instantiateVariableFont

ROOT = Path(__file__).resolve().parents[1]
FONT_PATH = ROOT / "game/assets/fonts/NotoSansSC-AshenHollow.ttf"
GLYPHS_PATH = ROOT / "game/assets/fonts/ashen_hollow_glyphs.txt"


def source_characters():
    paths = []
    for folder in ("scripts", "scenes", "resources"):
        paths.extend(p for p in (ROOT / "game" / folder).rglob("*")
                     if p.is_file() and p.suffix in {".gd", ".tscn", ".tres", ".json", ".csv", ".po"})
    paths.extend((ROOT / "game").glob("*.tscn"))
    characters = set(range(0x20, 0x7f)) | {0x25c7}
    for path in sorted(paths):
        text = path.read_text(encoding="utf-8-sig")
        characters.update(ord(char) for char in text if char.isprintable())
        for match in re.finditer(r"(?<!\\)\\u([0-9a-fA-F]{4})", text):
            code = int(match.group(1), 16)
            if chr(code).isprintable():
                characters.add(code)
    return characters, len(paths)


def missing_glyphs(font, required):
    cmap = font.getBestCmap() or {}
    return sorted(code for code in required if cmap.get(code, ".notdef") == ".notdef")


def description(codes):
    return [{"codepoint": f"U+{code:04X}", "character": chr(code),
             "name": unicodedata.name(chr(code), "UNKNOWN")} for code in codes]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source", type=Path, help="Installed OFL Noto Sans SC source font")
    parser.add_argument("--output", type=Path, default=FONT_PATH)
    parser.add_argument("--check", action="store_true", help="Check current UI/source glyph coverage without writing")
    parser.add_argument("--report", type=Path, help="Optional JSON receipt")
    args = parser.parse_args()
    required, source_files = source_characters()
    result = {"source_files": source_files, "required_codepoints": len(required)}
    if not args.check:
        if args.source is None:
            parser.error("--source is required to build; use --check for read-only validation")
        if args.source.resolve() == args.output.resolve():
            parser.error("Source and output must differ")
        font = TTFont(args.source, recalcTimestamp=False)
        licenses = [record.toUnicode() for record in font["name"].names if record.nameID == 13]
        if not any("SIL Open Font License" in value for value in licenses):
            raise ValueError("Source does not declare the required SIL Open Font License")
        missing = missing_glyphs(font, required)
        if missing:
            raise ValueError("Source font lacks UI glyphs: " + json.dumps(description(missing), ensure_ascii=False))
        options = subset.Options()
        options.name_IDs = ["*"]
        options.name_languages = ["*"]
        options.layout_features = ["*"]
        options.recalc_timestamp = False
        subsetter = subset.Subsetter(options=options)
        subsetter.populate(unicodes=required)
        subsetter.subset(font)
        if "fvar" in font:
            axes = {axis.axisTag: 400 if axis.axisTag == "wght" else axis.defaultValue
                    for axis in font["fvar"].axes}
            instantiateVariableFont(font, axes, inplace=True, updateFontNames=True)
        # Retain copyright/license records; give the derived subset its own name.
        names = {1: "Ashen Hollow Interface", 2: "Regular",
                 3: "Ashen Hollow Interface Regular; Noto Sans SC subset",
                 4: "Ashen Hollow Interface Regular", 6: "AshenHollowInterface-Regular",
                 16: "Ashen Hollow Interface", 17: "Regular"}
        for record in list(font["name"].names):
            if record.nameID in names:
                font["name"].setName(names[record.nameID], record.nameID,
                                     record.platformID, record.platEncID, record.langID)
        args.output.parent.mkdir(parents=True, exist_ok=True)
        font.save(args.output)
        font.close()
        GLYPHS_PATH.write_text("".join(chr(code) for code in sorted(required)) + "\n", encoding="utf-8")
        result["source_sha256"] = hashlib.sha256(args.source.read_bytes()).hexdigest()
        result["source_font"] = args.source.name
        result["weight"] = 400
    font = TTFont(args.output)
    missing = missing_glyphs(font, required)
    result.update({"output": str(args.output), "mapped_codepoints": len(font.getBestCmap() or {}),
                   "missing": description(missing), "ok": not missing,
                   "bytes": args.output.stat().st_size,
                   "sha256": hashlib.sha256(args.output.read_bytes()).hexdigest()})
    font.close()
    if args.report:
        args.report.parent.mkdir(parents=True, exist_ok=True)
        args.report.write_text(json.dumps(result, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    summary = {key: result[key] for key in ("source_files", "required_codepoints", "mapped_codepoints", "bytes", "sha256", "ok")}
    summary.update({"missing_count": len(missing), "missing_sample": description(missing[:12])})
    print(("INTERFACE_FONT_COVERAGE_OK " if result["ok"] else "INTERFACE_FONT_COVERAGE_FAILED ")
          + json.dumps(summary, ensure_ascii=True))
    return 0 if result["ok"] else 1


if __name__ == "__main__":
    raise SystemExit(main())
