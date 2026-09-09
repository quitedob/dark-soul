"""Run Godot's direct-import contract against a hash-stable staged GLB inventory."""
import argparse
import datetime
import hashlib
import json
from pathlib import Path
import subprocess


ROOT = Path(__file__).resolve().parents[1]
WORK = ROOT / 'build/glb-models/rigging'
STAGED = WORK / 'staged'


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def snapshot(directory=STAGED):
    return {p.relative_to(directory).as_posix(): digest(p) for p in sorted(directory.rglob('*.glb'))}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--godot', required=True, type=Path)
    parser.add_argument('--published', action='store_true', help='Verify out instead of staged')
    parser.add_argument('--expected-count', type=int)
    args = parser.parse_args()
    directory = ROOT / 'build/glb-models/out' if args.published else STAGED
    before = snapshot(directory)
    if not before:
        raise RuntimeError('No GLBs in ' + str(directory))
    if args.expected_count is not None and len(before) != args.expected_count:
        raise RuntimeError('Unexpected GLB inventory: %d, expected %d' % (len(before), args.expected_count))
    stamp = datetime.datetime.now(datetime.timezone.utc).strftime('%Y%m%dT%H%M%S%fZ')
    log = WORK / ('godot-' + stamp + '.log')
    evidence_path = WORK / ('godot-' + stamp + '-evidence.json')
    command = [str(args.godot.resolve()), '--headless', '--log-file', str(log),
               '--path', str(ROOT / 'game'), '--script', str(ROOT / 'tools/verify_blender_glbs.gd'),
               '--', str(directory)]
    result = subprocess.run(command, capture_output=True, text=True, encoding='utf8', errors='replace')
    if result.returncode != 0:
        raise RuntimeError('Godot contract failed:\n' + result.stdout + result.stderr)
    records, summary = {}, None
    for line in result.stdout.splitlines():
        if line.startswith('ASHEN_BLENDER_GLB_MODEL '):
            record = json.loads(line.removeprefix('ASHEN_BLENDER_GLB_MODEL '))
            path = Path(record['file']).resolve()
            relative = path.relative_to(directory.resolve()).as_posix()
            if relative in records or record['errors']:
                raise RuntimeError('Duplicate or failed model: ' + relative)
            records[relative] = record
        elif line.startswith('ASHEN_BLENDER_GLB_IMPORT_OK '):
            if summary is not None:
                raise RuntimeError('Duplicate Godot success marker')
            summary = json.loads(line.removeprefix('ASHEN_BLENDER_GLB_IMPORT_OK '))
    if (summary is None or summary['failed'] != 0 or summary['count'] != len(before)
            or summary['passed'] != len(before) or set(records) != set(before)):
        raise RuntimeError('Godot did not verify the exact GLB inventory')
    if before != snapshot(directory):
        raise RuntimeError('GLB files changed during the Godot run')
    if not log.is_file():
        raise RuntimeError('Godot did not write its log')
    evidence = {'log': str(log), 'log_sha256': digest(log), 'exit_code': result.returncode,
                'hashes': before, 'summary': summary, 'command': command, 'models': records,
                'pose_method': 'cpu_imported_skin', 'verified_at': stamp, 'directory': str(directory)}
    evidence_path.write_text(json.dumps(evidence, indent=2) + '\n', encoding='utf8')
    print('GODOT_RIG_BATCH_EVIDENCE_OK', json.dumps(summary), str(evidence_path))


if __name__ == '__main__':
    main()
