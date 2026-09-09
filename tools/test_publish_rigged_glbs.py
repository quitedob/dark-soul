"""Bounded publisher contracts. All artifacts are synthetic and subprocess is mocked.

python -B tools/test_publish_rigged_glbs.py
python -B -O tools/test_publish_rigged_glbs.py
"""
import contextlib
import copy
import datetime
import io
import json
from pathlib import Path
import subprocess
import tempfile
import unittest
from unittest import mock

import publish_rigged_glbs as publisher


SCRATCH = publisher.WORK / 'publisher-contract-20260908'
NEW_LOG = 'docs/devlog/2026-09-08/02-blender-conversion-continuation.md'


class PublisherContracts(unittest.TestCase):
    def setUp(self):
        SCRATCH.mkdir(parents=True, exist_ok=True)
        temp = tempfile.TemporaryDirectory(prefix='case-', dir=SCRATCH)
        self.addCleanup(temp.cleanup)
        self.root = Path(temp.name).resolve()
        self.base = self.root / 'build/glb-models'
        self.work = self.base / 'rigging'
        for name, value in (('ROOT', self.root), ('BASE', self.base), ('WORK', self.work)):
            patch = mock.patch.object(publisher, name, value)
            patch.start()
            self.addCleanup(patch.stop)
        self.files = ['characters/first.glb', 'characters/second.glb']
        self.staged, self.old_outputs = {}, {}
        self.review = {'files': self.files.copy(), 'models': [], 'devlog': NEW_LOG}
        for index, rel in enumerate(self.files):
            data = f'SYNTHETIC STAGED GLB {index}'.encode()
            self.staged[rel] = data
            self.write(self.work / 'staged' / rel, data)
            self.write(self.work / 'originals' / rel, f'SYNTHETIC ORIGINAL {index}'.encode())
            self.old_outputs[rel] = f'PREEXISTING OUTPUT {index}'.encode()
            self.write(self.base / 'out' / rel, self.old_outputs[rel])
            shot = f'model-{index}-review.png'
            self.write(self.work / 'screenshots' / shot, b'SYNTHETIC SCREENSHOT')
            self.review['models'].append({'file': rel, 'sha256': publisher.sha256(data),
                                          'screenshots': [shot], 'note': f'Parent review {index}'})
            self.write_json(self.work / 'reports' / (rel.replace('/', '__') + '.json'),
                            {'file': rel, 'bones': 3, 'blended_meshes': 1, 'meshes': 2,
                             'family': 'synthetic'})
        self.review['godot'] = {'log': 'godot-current.log',
                                'sha256': {r: publisher.sha256(b) for r, b in self.staged.items()}}
        self.godot_lines = ['Godot Engine synthetic test fixture']
        self.godot_lines += ['ASHEN_BLENDER_GLB_MODEL ' + json.dumps(
            {'file': str(self.work / 'staged' / rel), 'errors': []}) for rel in self.files]
        self.godot_lines.append('ASHEN_BLENDER_GLB_IMPORT_OK ' + json.dumps(
            {'count': 2, 'passed': 2, 'failed': 0}))
        self.save_godot()
        self.history = self.root / publisher.DEFAULT_DEVLOG
        self.history_bytes = b'# Historical log must remain byte-identical\n'
        self.write(self.history, self.history_bytes)
        self.ledger_path = self.work / 'publication.json'
        self.old_record = {'publishedAt': '2026-09-06T00:00:00+00:00', 'sha256': 'historical',
                           'screenshots': ['old.png'], 'review': 'Historical review',
                           'improvement': 'Historical improvement', 'bones': 3,
                           'blended_meshes': 1, 'meshes': 2, 'family': 'synthetic',
                           'rest_error': 0.0, 'pose_displacement': 0.1}
        self.initial_ledger = {'characters/historical.glb': self.old_record}
        self.save_ledger()
        self.review_path = self.work / 'review.json'
        self.transform = lambda report: None
        self.validator_paths = []
        patch = mock.patch.object(publisher.subprocess, 'run', side_effect=self.validator)
        self.run = patch.start()
        self.addCleanup(patch.stop)

    @staticmethod
    def write(path, data):
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_bytes(data)

    def write_json(self, path, data):
        self.write(path, (json.dumps(data) + '\n').encode())

    def save_ledger(self):
        self.write_json(self.ledger_path, self.initial_ledger)
        self.ledger_bytes = self.ledger_path.read_bytes()

    def save_godot(self):
        data = ('\n'.join(self.godot_lines) + '\n').encode()
        self.write(self.work / self.review['godot']['log'], data)
        self.review['godot']['log_sha256'] = publisher.sha256(data)

    def wrapper_evidence(self):
        godot = self.review.pop('godot')
        self.review['godot_evidence'] = str(self.work / 'godot-evidence.json')
        evidence = {'log': str(self.work / godot['log']), 'log_sha256': godot['log_sha256'],
                    'hashes': godot['sha256'], 'exit_code': 0,
                    'summary': json.loads(self.godot_lines[-1].partition(' ')[2]),
                    'command': ['godot', '--headless', '--path', str(self.root / 'game'),
                                '--script', str(self.root / 'tools/verify_blender_glbs.gd'),
                                '--', str(self.work / 'staged')]}
        self.write_json(Path(self.review['godot_evidence']), evidence)
        return evidence

    def validator(self, command, **kwargs):
        self.assertEqual(command[0], 'node')
        self.assertEqual(kwargs, {'capture_output': True, 'text': True})
        path = Path(command[command.index('--report') + 1])
        self.assertTrue(path.is_relative_to(self.work))
        self.assertFalse(path.exists())
        self.assertNotEqual(path, self.work / 'validation.json')
        self.validator_paths.append(path)
        result = {'generatedAt': datetime.datetime.now(datetime.timezone.utc).isoformat(),
                  'source': str(self.work / 'originals'), 'output': str(self.work / 'staged'),
                  'models': [{'file': rel, 'sourcePath': str(self.work / 'originals' / rel),
                              'outputPath': str(self.work / 'staged' / rel), 'ok': True,
                              'failures': [], 'semanticChanges': [], 'changedMaterialMeshGroups': [],
                              'maxRestBoundsError': 0.0, 'maxPoseDisplacement': 0.1}
                             for rel in self.files],
                  'missingPaths': [], 'extraPaths': [], 'ok': True,
                  'summary': {'sourceFiles': 2, 'outputFiles': 2, 'checked': 2,
                              'passed': 2, 'failed': 0, 'missing': 0, 'extra': 0}}
        self.transform(result)
        self.write_json(path, result)
        marker = 'SKINNED_GLBS_VALIDATION_OK' if result['ok'] else 'SKINNED_GLBS_VALIDATION_FAILED'
        return subprocess.CompletedProcess(command, 0 if result['ok'] else 1,
                                           stdout=marker + ' ' + json.dumps(result['summary']) + '\n',
                                           stderr='')

    def publish(self, *args, **kwargs):
        self.write_json(self.review_path, self.review)
        with contextlib.redirect_stdout(io.StringIO()) as output:
            publisher.publish(self.review_path, *args, **kwargs)
        return output.getvalue()

    def assert_untouched(self):
        for rel, data in self.old_outputs.items():
            self.assertEqual((self.base / 'out' / rel).read_bytes(), data)
        self.assertEqual(self.ledger_path.read_bytes(), self.ledger_bytes)
        self.assertEqual(self.history.read_bytes(), self.history_bytes)
        self.assertFalse((self.root / NEW_LOG).exists())

    def rejected(self, message):
        with self.assertRaisesRegex(publisher.PublicationError, message):
            self.publish()
        self.assert_untouched()

    def test_crash_cannot_reuse_stale_validator_report(self):
        stale = self.work / 'validation.json'
        self.write_json(stale, {'ok': True, 'models': []})
        stale_bytes = stale.read_bytes()
        self.run.side_effect = None
        self.run.return_value = subprocess.CompletedProcess([], 1, stdout='', stderr='crash')
        self.rejected('did not write a fresh report')
        self.assertEqual(stale.read_bytes(), stale_bytes)

    def test_copied_stale_report_timestamp_rejected(self):
        self.transform = lambda report: report.update(generatedAt='2026-09-06T00:00:00+00:00')
        self.rejected('Stale or missing validator')

    def test_empty_per_model_screenshots_rejected_before_validator(self):
        self.review['models'][1]['screenshots'] = []
        self.rejected('Empty per-model screenshots')
        self.run.assert_not_called()

    def test_wrong_reviewed_hash_rejected_before_validator(self):
        self.review['models'][1]['sha256'] = '0' * 64
        self.rejected('Reviewed SHA-256 mismatch')
        self.run.assert_not_called()

    def test_batch_evidence_alone_is_not_visual_approval(self):
        del self.review['models'][0]['note']
        self.rejected('Missing per-model note')

    def test_empty_screenshot_file_rejected(self):
        self.write(self.work / 'screenshots/model-0-review.png', b'')
        self.rejected('Empty screenshot')

    def test_staged_mutation_during_validator_rejected_for_entire_batch(self):
        self.transform = lambda report: self.write(self.work / 'staged' / self.files[1], b'MUTATED')
        self.rejected('Input changed before publication')

    def test_original_mutation_during_validator_rejected(self):
        self.transform = lambda report: self.write(self.work / 'originals' / self.files[0], b'MUTATED')
        self.rejected('Input changed before publication')

    def test_screenshot_mutation_during_validator_rejected(self):
        self.transform = lambda report: self.write(self.work / 'screenshots/model-0-review.png', b'MUTATED')
        self.rejected('Input changed before publication')

    def test_mutation_immediately_before_copy_rejected(self):
        unchanged = publisher.require_unchanged
        calls = 0

        def mutate(snapshots):
            nonlocal calls
            calls += 1
            if calls == 2:
                self.write(self.work / 'staged' / self.files[0], b'MUTATED')
            unchanged(snapshots)

        with mock.patch.object(publisher, 'require_unchanged', side_effect=mutate):
            self.rejected('Input changed before publication')
        self.assertEqual(calls, 2)

    def test_validator_paths_are_bound(self):
        cases = [('source', None), ('output', None), ('sourcePath', 0), ('outputPath', 1)]
        for field, index in cases:
            with self.subTest(field=field):
                def transform(report):
                    target = report if index is None else report['models'][index]
                    target[field] = str(self.work / 'unrelated')
                self.transform = transform
                self.rejected('path mismatch')

    def test_selected_model_failure_rejected_even_if_global_ok(self):
        self.transform = lambda report: report['models'][1].update(ok=False, failures=['Invalid skin'])
        self.rejected('Validation failed')

    def test_appearance_failures_rejected_even_if_model_ok(self):
        for field in ('materialProperties', 'imagePayloads'):
            with self.subTest(field=field):
                self.transform = lambda report: report['models'][0].update(semanticChanges=[{'field': field}])
                self.rejected('Appearance changed')
        self.transform = lambda report: report['models'][0].update(changedMaterialMeshGroups=['mesh'])
        self.rejected('Appearance changed')
        self.transform = lambda report: report['models'][0].update(failures=['Material assignment changed'])
        self.rejected('Validation failed')

    def test_duplicate_validator_model_rejected(self):
        self.transform = lambda report: report['models'].append(copy.deepcopy(report['models'][0]))
        self.rejected('Duplicate validator model')

    def test_validator_completion_required_even_with_report(self):
        def incomplete(command, **kwargs):
            response = self.validator(command, **kwargs)
            response.stdout = ''
            return response
        self.run.side_effect = incomplete
        self.rejected('did not complete cleanly')

    def test_godot_overall_ok_required(self):
        self.godot_lines.pop()
        self.save_godot()
        self.rejected('Godot overall OK')

    def test_godot_selected_entries_required(self):
        self.godot_lines[1] = self.godot_lines[1].replace('first.glb', 'unselected.glb')
        self.save_godot()
        self.rejected('Godot log missing selected staged model')

    def test_godot_errors_rejected(self):
        self.godot_lines[1] = self.godot_lines[1].replace('"errors": []', '"errors": ["bad bind"]')
        self.save_godot()
        self.rejected('failed Godot model')

    def test_godot_engine_error_after_ok_rejected(self):
        self.godot_lines.append('ERROR: leaked required resource')
        self.save_godot()
        self.rejected('Godot log contains an error')

    def test_godot_hash_map_bound_to_staged(self):
        self.review['godot']['sha256'][self.files[0]] = '0' * 64
        self.rejected('Godot run SHA-256 mismatch')

    def test_changed_godot_log_rejected(self):
        with (self.work / self.review['godot']['log']).open('ab') as log:
            log.write(b'changed after review\n')
        self.rejected('Godot log SHA-256 mismatch')

    def test_parent_wrapper_evidence_supported(self):
        evidence = self.wrapper_evidence()
        self.assertIn('PUBLICATION_LEDGER 3', self.publish())
        ledger = json.loads(self.ledger_path.read_bytes())
        godot = ledger[self.files[0]]['godot']
        self.assertEqual(godot['summary'], evidence['summary'])
        self.assertEqual(godot['command'], evidence['command'])
        self.assertEqual(godot['exit_code'], 0)
        self.assertEqual(godot['evidence_sha256'],
                         publisher.sha256(Path(self.review['godot_evidence']).read_bytes()))
        self.assertEqual(self.history.read_bytes(), self.history_bytes)

    def test_wrapper_requires_exit_zero_summary_hashes_and_command(self):
        evidence = self.wrapper_evidence()
        cases = [('exit_code', 1, 'exit_code 0'),
                 ('summary', {}, 'summary mismatch'),
                 ('hashes', {}, 'hash file set mismatch'),
                 ('command', ['godot', '--', str(self.work / 'originals')], 'path mismatch')]
        for field, value, message in cases:
            with self.subTest(field=field):
                self.write_json(Path(self.review['godot_evidence']), {**evidence, field: value})
                self.rejected(message)

    def test_wrapper_stale_hashes_rejected(self):
        evidence = self.wrapper_evidence()
        evidence['hashes'][self.files[0]] = '0' * 64
        self.write_json(Path(self.review['godot_evidence']), evidence)
        self.rejected('Godot run SHA-256 mismatch')

    def test_wrapper_mutation_during_validator_rejected(self):
        self.wrapper_evidence()
        self.transform = lambda report: self.write(Path(self.review['godot_evidence']), b'MUTATED')
        self.rejected('Input changed before publication')

    def test_traversal_rejected(self):
        self.review['files'] = ['../outside.glb']
        self.rejected('Unsafe selected model')

    def test_success_new_log_filters_legacy_and_other_owners(self):
        self.initial_ledger['characters/earlier-today.glb'] = {**self.old_record, 'devlog': NEW_LOG}
        self.initial_ledger['characters/other-day.glb'] = {**self.old_record, 'devlog': 'docs/devlog/2026-09-07/old.md'}
        self.save_ledger()
        output = self.publish()
        self.assertIn('PUBLICATION_LEDGER 5', output)
        self.assertEqual(output.count('PUBLISHED '), 2)
        ledger = json.loads(self.ledger_path.read_bytes())
        for rel, data in self.staged.items():
            self.assertEqual((self.base / 'out' / rel).read_bytes(), data)
            self.assertEqual((self.work / 'pre-publish-20260908-continuation' / rel).read_bytes(),
                             self.old_outputs[rel])
            self.assertEqual(ledger[rel]['sha256'], publisher.sha256(data))
            self.assertEqual(ledger[rel]['validation']['output_sha256'], publisher.sha256(data))
            self.assertEqual(ledger[rel]['validation']['source_sha256'],
                             publisher.sha256((self.work / 'originals' / rel).read_bytes()))
            self.assertEqual(ledger[rel]['devlog'], NEW_LOG)
            self.assertEqual(ledger[rel]['godot']['log_sha256'], self.review['godot']['log_sha256'])
        text = (self.root / NEW_LOG).read_text(encoding='utf8')
        self.assertIn('characters/earlier-today.glb', text)
        self.assertNotIn('characters/historical.glb', text)
        self.assertNotIn('characters/other-day.glb', text)
        self.assertEqual(self.history.read_bytes(), self.history_bytes)
        self.assertEqual(ledger['characters/historical.glb'], self.old_record)
        self.assertTrue(all(not p.parent.exists() for p in self.validator_paths))

    def test_callable_default_and_current_selection_remain_available(self):
        del self.review['devlog']
        self.review['files'] = 'current'
        self.write_json(self.work / 'current-batch.json', self.files)
        self.publish()
        self.assertFalse((self.root / NEW_LOG).exists())
        self.assertIn('characters/historical.glb', self.history.read_text(encoding='utf8'))
        ledger = json.loads(self.ledger_path.read_bytes())
        self.assertEqual(ledger[self.files[0]]['devlog'], publisher.DEFAULT_DEVLOG)

    def test_devlog_argument_overrides_review_field(self):
        override = 'docs/devlog/2026-09-09/override.md'
        self.publish(devlog=override)
        self.assertTrue((self.root / override).is_file())
        self.assertFalse((self.root / NEW_LOG).exists())
        self.assertEqual(self.history.read_bytes(), self.history_bytes)

    def test_continuation_accepts_completed_exit_one_with_unselected_missing(self):
        def missing(report):
            report.update(ok=False, missingPaths=['unselected/not-staged.glb'])
            report['summary'].update(sourceFiles=3, missing=1)
        self.transform = missing
        self.assertIn('PUBLICATION_LEDGER 3', self.publish())

    def test_unique_reports_and_backup_preserved_on_repeat(self):
        self.publish()
        self.publish()
        self.assertEqual(len(set(self.validator_paths)), 2)
        for rel, data in self.old_outputs.items():
            self.assertEqual((self.work / 'pre-publish-20260908-continuation' / rel).read_bytes(), data)


if __name__ == '__main__':
    result = unittest.main(verbosity=2, exit=False).result
    if result.wasSuccessful():
        print('PUBLISHER_CONTRACTS_OK')
    raise SystemExit(0 if result.wasSuccessful() else 1)
