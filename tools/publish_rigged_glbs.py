"""Publish explicitly reviewed GLBs; never infer visual approval from batch evidence.

Review contract (paths use forward slashes):
  files: nonempty relative GLB list, or "current" for current-batch.json
  models: [{file, sha256, screenshots: [name, ...], note, improvement?}, ...]
  godot_evidence: path to the parent-authored Godot wrapper JSON:
    {log, log_sha256, exit_code: 0, hashes: {relative_glb: digest, ...},
     summary: {...}, command: [original_command_arguments, ...]}
  Alternatively, inline godot: {log, log_sha256, sha256: {relative_glb: digest}}
  devlog: optional repository-relative docs/devlog/*.md path

Screenshots are relative to WORK/screenshots; Godot evidence/logs are relative to
WORK (absolute paths inside WORK also work). The parent must capture a fresh, complete
Godot run against staged paths, confirm selected hashes before AND after that run,
and bind those hashes and the complete log hash in its evidence. Hashes must match the
final visually inspected 007/008-style evidence, not be filled from staged files
after the fact. This publisher checks that attestation, not its human provenance.

publish(review_path, devlog=None) and the historical default remain available;
--devlog overrides the review field. Only the chosen log is regenerated, using
its own ledger entries; legacy entries without devlog belong to the old default.
The parent serializes publication and input writers. This is not a multi-file
transaction: I/O failure during publication can leave a partially copied batch.
"""
import argparse
import datetime
import hashlib
import json
import math
from pathlib import Path, PurePosixPath
import re
import shutil
import subprocess
import sys
import tempfile

ROOT = Path(__file__).resolve().parents[1]
BASE = ROOT / 'build/glb-models'
WORK = BASE / 'rigging'
DEFAULT_DEVLOG = 'docs/devlog/2026-09-06/02-blender-conversion-continuation.md'


class PublicationError(RuntimeError):
    """Required publication evidence is missing, inconsistent, or changed."""


def require(condition, message):
    if not condition:
        raise PublicationError(message)


def decode_json(data, label):
    try:
        return json.loads(data)
    except (ValueError, UnicodeError) as error:
        raise PublicationError(f'Invalid JSON in {label}: {error}') from error


def relative_name(value, label):
    require(isinstance(value, str) and bool(value), f'Missing {label}')
    path = PurePosixPath(value)
    require(not path.is_absolute() and path.as_posix() == value
            and not any(p in ('.', '..') for p in path.parts)
            and '\\' not in value and ':' not in value, f'Unsafe {label}: {value}')
    return value


def inside(base, value):
    require(isinstance(value, (str, Path)) and bool(str(value)), 'Missing path')
    path = (base / value).resolve()
    require(path != base.resolve() and path.is_relative_to(base.resolve()),
            f'Path escapes {base}: {value}')
    return path


def sha256(data):
    return hashlib.sha256(data).hexdigest()


def fingerprint(path):
    stat = path.stat()
    return stat.st_dev, stat.st_ino, stat.st_size, stat.st_mtime_ns, stat.st_ctime_ns


def snapshot(path, snapshots):
    if path not in snapshots:
        before = fingerprint(path)
        data = path.read_bytes()
        require(before == fingerprint(path), f'Input changed while reading: {path}')
        snapshots[path] = (data, sha256(data), before)
    return snapshots[path][0]


def require_unchanged(snapshots):
    for path, (_, digest, stat) in snapshots.items():
        require(path.is_file() and fingerprint(path) == stat
                and sha256(path.read_bytes()) == digest and fingerprint(path) == stat,
                f'Input changed before publication: {path}')


def model_index(records, label):
    require(isinstance(records, list) and bool(records), f'Missing {label} models')
    result = {}
    for record in records:
        require(isinstance(record, dict), f'Invalid {label} model')
        name = relative_name(record.get('file'), f'{label} file')
        require(name not in result, f'Duplicate {label} model: {name}')
        result[name] = record
    return result


def require_path(value, expected, label):
    require(isinstance(value, str) and Path(value).is_absolute()
            and Path(value).resolve() == expected.resolve(), f'{label} path mismatch: {value}')


def validate(files):
    # A newly allocated directory prevents a crashed exit-1 process reusing a report.
    with tempfile.TemporaryDirectory(prefix='publisher-validation-', dir=WORK) as temp:
        validation = Path(temp) / 'validation.json'
        started = datetime.datetime.now(datetime.timezone.utc)
        check = subprocess.run(['node', str(ROOT / 'tools/validate_skinned_glbs.mjs'),
                                '--source', str(WORK / 'originals'),
                                '--output', str(WORK / 'staged'), '--report', str(validation)],
                               capture_output=True, text=True)
        finished = datetime.datetime.now(datetime.timezone.utc)
        require(check.returncode in (0, 1), f'Validator exited {check.returncode}: {check.stderr}')
        require(validation.is_file(), f'Validator did not write a fresh report: {check.stderr}')
        result = decode_json(validation.read_bytes(), validation)
    require(isinstance(result, dict), 'Invalid validation report')
    require_path(result.get('source'), WORK / 'originals', 'Validator source')
    require_path(result.get('output'), WORK / 'staged', 'Validator output')
    try:
        generated = datetime.datetime.fromisoformat(result['generatedAt'].replace('Z', '+00:00'))
        fresh = (generated.tzinfo is not None
                 and started - datetime.timedelta(seconds=1) <= generated
                 <= finished + datetime.timedelta(seconds=1))
    except (KeyError, TypeError, ValueError, AttributeError):
        fresh = False
    require(fresh, 'Stale or missing validator generatedAt')
    require(type(result.get('ok')) is bool and isinstance(result.get('summary'), dict),
            'Missing validator completion summary')
    marker = 'SKINNED_GLBS_VALIDATION_OK' if result['ok'] else 'SKINNED_GLBS_VALIDATION_FAILED'
    completions = [line for line in check.stdout.splitlines()
                   if line.startswith('SKINNED_GLBS_VALIDATION_')]
    require(len(completions) == 1 and completions[0].startswith(marker + ' ')
            and check.returncode == (0 if result['ok'] else 1), 'Validator did not complete cleanly')
    require(decode_json(completions[0][len(marker) + 1:], 'validator summary') == result['summary'],
            'Validator completion summary mismatch')
    models = model_index(result.get('models'), 'validator')
    for rel in files:
        model = models.get(rel)
        require(model is not None and model.get('ok') is True and model.get('failures') == [],
                f'Validation failed for {rel}: {model}')
        require_path(model.get('sourcePath'), WORK / 'originals' / rel, f'{rel} source')
        require_path(model.get('outputPath'), WORK / 'staged' / rel, f'{rel} output')
        changes = model.get('semanticChanges')
        require(isinstance(changes, list) and all(isinstance(c, dict) for c in changes),
                f'Missing semantic changes for {rel}')
        require(not any(c.get('field') in ('materialProperties', 'imagePayloads') for c in changes)
                and not model.get('changedMaterialMeshGroups'), f'Appearance changed: {rel}')
        for field in ('maxRestBoundsError', 'maxPoseDisplacement'):
            value = model.get(field)
            require(type(value) in (int, float) and math.isfinite(value) and value >= 0,
                    f'Invalid {field}: {rel}')
    return result


def validate_godot(review, files, snapshots):
    wrapper_path = None
    if 'godot_evidence' in review:
        require('godot' not in review, 'Specify godot_evidence or inline godot, not both')
        wrapper_path = inside(WORK, review['godot_evidence'])
        evidence = decode_json(snapshot(wrapper_path, snapshots), wrapper_path)
        require(isinstance(evidence, dict) and type(evidence.get('exit_code')) is int
                and evidence['exit_code'] == 0, 'Godot evidence requires exit_code 0')
        command = evidence.get('command')
        require(isinstance(command, list) and bool(command)
                and all(isinstance(arg, str) and bool(arg) for arg in command),
                'Missing Godot evidence command')
        arguments = command[command.index('--') + 1:] if '--' in command else []
        require(len(arguments) == 1, 'Godot evidence command must target staged')
        require_path(arguments[0], WORK / 'staged', 'Godot evidence command')
        evidence = {**evidence, 'sha256': evidence.get('hashes')}
    else:
        evidence = review.get('godot')
    require(isinstance(evidence, dict) and isinstance(evidence.get('sha256'), dict),
            'Missing Godot run/hash attestation')
    log = inside(WORK, evidence.get('log'))
    data = snapshot(log, snapshots)
    require(evidence.get('log_sha256') == sha256(data), 'Godot log SHA-256 mismatch')
    models, summary = {}, None
    for line in data.decode('utf-8-sig').splitlines():
        line = line.strip()
        require('ASHEN_BLENDER_GLB_IMPORT_FAILED' not in line
                and re.search(r'\b(?:ERROR|SCRIPT ERROR|FATAL)\b', line) is None,
                f'Godot log contains an error: {line}')
        if line.startswith('ASHEN_BLENDER_GLB_MODEL '):
            require(summary is None, 'Godot model entry after completion')
            model = decode_json(line.partition(' ')[2], 'Godot model')
            require(isinstance(model, dict) and isinstance(model.get('file'), str),
                    'Invalid Godot model entry')
            path = Path(model['file'])
            require(path.is_absolute(), 'Godot model path must be absolute')
            path = path.resolve()
            require(path not in models and model.get('errors') == [],
                    f'Duplicate or failed Godot model: {path}')
            models[path] = model
        elif line.startswith('ASHEN_BLENDER_GLB_IMPORT_OK '):
            require(summary is None, 'Multiple Godot runs in log')
            summary = decode_json(line.partition(' ')[2], 'Godot summary')
    require(isinstance(summary, dict) and summary.get('failed') == 0
            and summary.get('count') == len(models) and summary.get('passed') == len(models)
            and bool(models), 'Missing or inconsistent Godot overall OK')
    if wrapper_path is not None:
        require(evidence.get('summary') == summary, 'Godot evidence summary mismatch')
        require(all(path.is_relative_to((WORK / 'staged').resolve()) for path in models),
                'Godot evidence contains a model outside staged')
        logged = {path.relative_to((WORK / 'staged').resolve()).as_posix() for path in models}
        require(set(evidence['sha256']) == logged, 'Godot evidence hash file set mismatch')
    for rel in files:
        path = inside(WORK / 'staged', rel)
        require(path in models, f'Godot log missing selected staged model: {rel}')
        require(evidence['sha256'].get(rel) == snapshots[path][1],
                f'Godot run SHA-256 mismatch: {rel}')
    result = {'log': log.relative_to(WORK.resolve()).as_posix(),
              'log_sha256': sha256(data), 'sha256': {rel: evidence['sha256'][rel] for rel in files}}
    if wrapper_path is not None:
        result.update(evidence=wrapper_path.relative_to(WORK.resolve()).as_posix(),
                      evidence_sha256=snapshots[wrapper_path][1], exit_code=0,
                      command=evidence['command'], summary=summary)
    return result


def publish(review_path, devlog=None):
    snapshots = {}
    review = decode_json(snapshot(Path(review_path).resolve(), snapshots), review_path)
    require(isinstance(review, dict), 'Review must be an object')
    files = review.get('files')
    if files == 'current':
        files = decode_json(snapshot(WORK / 'current-batch.json', snapshots), 'current batch')
    require(isinstance(files, list) and bool(files), 'Selected files must be a nonempty list')
    for rel in files:
        relative_name(rel, 'selected model')
        require(rel.lower().endswith('.glb'), f'Not a GLB: {rel}')
    require(len(set(files)) == len(files), 'Duplicate selected files')
    selected = model_index(review.get('models'), 'review')
    require(set(files) <= selected.keys(), 'Missing per-model review')
    sources, destinations, reports = {}, {}, {}
    for rel in files:
        sources[rel] = inside(WORK / 'staged', rel)
        destinations[rel] = inside(BASE / 'out', rel)
        data = snapshot(sources[rel], snapshots)
        require(bool(data) and selected[rel].get('sha256') == sha256(data),
                f'Reviewed SHA-256 mismatch: {rel}')
        snapshot(inside(WORK / 'originals', rel), snapshots)
        shots = selected[rel].get('screenshots')
        require(isinstance(shots, list) and bool(shots), f'Empty per-model screenshots: {rel}')
        for shot in shots:
            relative_name(shot, 'screenshot')
            require(bool(snapshot(inside(WORK / 'screenshots', shot), snapshots)),
                    f'Empty screenshot: {shot}')
        note = selected[rel].get('note')
        require(isinstance(note, str) and bool(note.strip()), f'Missing per-model note: {rel}')
        path = inside(WORK / 'reports', rel.replace('/', '__') + '.json')
        report = decode_json(snapshot(path, snapshots), path)
        require(isinstance(report, dict) and report.get('file') == rel, f'Rig report mismatch: {rel}')
        for key in ('bones', 'blended_meshes', 'meshes'):
            require(type(report.get(key)) is int and report[key] >= 0, f'Invalid rig {key}: {rel}')
        require(isinstance(report.get('family'), str), f'Missing rig family: {rel}')
        reports[rel] = report
    require(len(set(sources.values())) == len(files)
            and len(set(destinations.values())) == len(files), 'Aliased selected paths')
    godot = validate_godot(review, files, snapshots)
    result = validate(files)
    models = model_index(result['models'], 'validator')
    now = datetime.datetime.now(datetime.timezone.utc).isoformat()
    ledger_path = WORK / 'publication.json'
    ledger = decode_json(ledger_path.read_bytes(), ledger_path) if ledger_path.exists() else {}
    require(isinstance(ledger, dict) and all(isinstance(r, dict) for r in ledger.values()),
            'Invalid publication ledger')
    log = inside(ROOT, devlog if devlog is not None else review.get('devlog', DEFAULT_DEVLOG))
    require(log.is_relative_to((ROOT / 'docs/devlog').resolve()) and log.suffix == '.md',
            'Devlog must be a Markdown file under docs/devlog')
    log_name = log.relative_to(ROOT.resolve()).as_posix()
    for rel in files:
        report, inspected = reports[rel], selected[rel]
        ledger[rel] = {'publishedAt': now, 'sha256': snapshots[sources[rel]][1],
                       'screenshots': inspected['screenshots'], 'review': inspected['note'],
                       'screenshot_sha256': {s: snapshots[inside(WORK / 'screenshots', s)][1]
                                             for s in inspected['screenshots']},
                       'godot': godot, 'devlog': log_name,
                       'validation': {'generatedAt': result['generatedAt'],
                                      'source_sha256': snapshots[inside(WORK / 'originals', rel)][1],
                                      'output_sha256': snapshots[sources[rel]][1], 'model': models[rel]},
                       'improvement': inspected.get('improvement', review.get('improvement', '后续做正式动画、极限关节姿态与碰撞避穿精修。')),
                       'bones': report['bones'], 'blended_meshes': report['blended_meshes'],
                       'meshes': report['meshes'], 'family': report['family'],
                       'rest_error': models[rel]['maxRestBoundsError'],
                       'pose_displacement': models[rel]['maxPoseDisplacement']}
    lines = ['# Blender 86 模型续作逐项发布记录', '', '记录时间（UTC）：' + now, '',
             '原始完成记录见 docs/devlog/2026-09-06/01-blender-embedded-skeleton-rebuild.md。下表仅含归属本日志的逐项发布记录。', '',
             '基础骨架与蒙皮完成不代表正式战斗动画或逐骨极限姿态美术验收。游戏 assets 未替换。', '',
             '| 模型（相对 out） | 骨骼 / 混合网格 | 操作与截图判断 | 验证结果 | 后续改进 |',
             '|---|---:|---|---|---|']
    for rel, r in sorted(ledger.items()):
        if r.get('devlog', DEFAULT_DEVLOG) != log_name:
            continue
        shots = ' / '.join(r['screenshots'])
        lines.append(f"| {rel} | {r['bones']} / {r['blended_meshes']} | {r['family']}；{r['review']} 证据：{shots}。 | 已发布；静止误差 {r['rest_error']:.2e}；非根骨位移 {r['pose_displacement']:.3g}；形状/材质/贴图校验通过。 | {r['improvement']} |")
    ledger_text = json.dumps(ledger, ensure_ascii=False, indent=2) + '\n'
    require_unchanged(snapshots)
    for rel in files:
        source, dest = sources[rel], destinations[rel]
        require(inside(WORK / 'staged', rel) == source and inside(BASE / 'out', rel) == dest,
                f'Model path changed: {rel}')
        if dest.exists():
            date = log.parent.name.replace('-', '')
            backup = inside(WORK, f'pre-publish-{date}-continuation/{rel}')
            if not backup.exists():
                backup.parent.mkdir(parents=True, exist_ok=True)
                shutil.copy2(dest, backup)
        dest.parent.mkdir(parents=True, exist_ok=True)
        require_unchanged(snapshots)
        # Copy captured bytes, never reopen staged after the last evidence check.
        dest.write_bytes(snapshots[source][0])
        require(sha256(dest.read_bytes()) == snapshots[source][1], f'Published hash mismatch: {rel}')
        print('PUBLISHED', rel)
    require_unchanged(snapshots)
    ledger_path.write_text(ledger_text, encoding='utf8')
    log.parent.mkdir(parents=True, exist_ok=True)
    log.write_text('\n'.join(lines) + '\n', encoding='utf8')
    print('PUBLICATION_LEDGER', len(ledger))


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('review', type=Path)
    parser.add_argument('--devlog', type=Path)
    args = parser.parse_args()
    try:
        publish(args.review, args.devlog)
    except (PublicationError, OSError, UnicodeError) as error:
        print(f'PUBLICATION_FAILED {error}', file=sys.stderr)
        sys.exit(1)
