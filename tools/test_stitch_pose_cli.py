"""Run the isolated Godot pose CLI against real animated/static GLBs."""
import argparse
import copy
import json
from pathlib import Path
import subprocess
import tempfile


ROOT = Path(__file__).resolve().parents[1]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--godot', type=Path, required=True)
    args = parser.parse_args()
    base = json.loads((ROOT / 'tools/stitch_pose_request.example.json').read_text(encoding='utf8'))
    scratch = ROOT / 'build/glb-models/rigging/stitch-cli-contracts'
    if not scratch.resolve().is_relative_to(ROOT.resolve()):
        raise RuntimeError('Scratch path escapes the workspace')
    scratch.mkdir(parents=True, exist_ok=True)
    cases = [('valid', base, None)]
    embedded = json.loads((ROOT / 'tools/stitch_pose_embedded.example.json').read_text(encoding='utf8'))
    cases.append(('embedded-class', embedded, None))
    for name, role, key, value, error in [
        ('missing-clip', 'prefix', 'clip', 'does_not_exist', 'is missing'),
        ('static-rig', 'prefix', 'scene', str(ROOT / 'build/glb-models/out/characters/player-classes/01-Divine-Marksman.glb'), 'no motion to sample'),
        ('prefix-boundary', 'prefix', 'upper_trim', .95, 'Prefix upper trim'),
        ('zero-quaternion', 'prefix', 'root_node_world_rot', dict(x=0, y=0, z=0, w=0), 'quaternion must not be zero'),
        ('missing-bone', 'suffix', 'bones', dict(pelvis='not_a_bone'), 'Expected one pelvis bone'),
        ('duplicate-hip', 'prefix', 'bones', dict(pelvis='DEF-hips', left_hip='DEF-thigh.L', right_hip='DEF-thigh.L'), 'must be distinct'),
        ('bad-units', 'suffix', 'meters_per_unit', 0, 'Invalid meters_per_unit'),
    ]:
        request = copy.deepcopy(base)
        request[role][key] = value
        cases.append((name, request, error))
    cases.append(('invalid-json', '{broken', 'Invalid request JSON'))
    request = copy.deepcopy(base)
    request['stitch_duration'] = 0
    cases.append(('zero-duration', request, 'stitch_duration must be'))
    with tempfile.TemporaryDirectory(prefix='run-', dir=scratch) as name:
        work = Path(name).resolve()
        if not work.is_relative_to(scratch.resolve()):
            raise RuntimeError('Unexpected temporary directory')
        for label, request, expected_error in cases:
            input_path, output_path = work / (label + '-request.json'), work / (label + '-output.json')
            input_path.write_text(request if isinstance(request, str) else json.dumps(request), encoding='utf8')
            output_path.write_text('preexisting-output', encoding='utf8')
            command = [str(args.godot.resolve()), '--headless', '--log-file', str(work / (label + '.log')),
                       '--path', str(ROOT / 'game'), '--script', 'res://scripts/tools/sample_stitch_poses.gd',
                       '--', '--request', str(input_path), '--output', str(output_path)]
            result = subprocess.run(command, capture_output=True, text=True, encoding='utf8', errors='replace', timeout=60)
            text = result.stdout + result.stderr
            if expected_error:
                if result.returncode != 1 or 'ASHEN_STITCH_POSES_FAILED:' not in text or expected_error not in text:
                    raise AssertionError(label + ': ' + text)
                if output_path.read_text(encoding='utf8') != 'preexisting-output':
                    raise AssertionError(label + ': failed request changed output')
            else:
                if result.returncode != 0 or 'ASHEN_STITCH_POSES_OK ' not in text:
                    raise AssertionError(label + ': ' + text)
                output = json.loads(output_path.read_text(encoding='utf8'))
                if abs(output['connection']['pelvis_distance_m'] - 1) > 1e-5:
                    raise AssertionError('Expected one-meter connection gap')
                for role in ('prefix', 'suffix'):
                    if len(output['sampling'][role]['samples']) != 3:
                        raise AssertionError('Expected three real time samples')
                if label == 'embedded-class':
                    poses = output['poses']['prefix']
                    if poses['at_zero_time']['pelvis_world_pos'] == poses['at_upper_trim_time']['pelvis_world_pos']:
                        raise AssertionError('Newly animated class must supply temporal pelvis poses')
            print('PASS', label)
    print('STITCH_POSE_CLI_CONTRACTS_OK', len(cases))


if __name__ == '__main__':
    main()
