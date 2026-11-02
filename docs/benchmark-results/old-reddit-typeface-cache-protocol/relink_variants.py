#!/usr/bin/env python3
"""Validate an identical control relink, then link the one-object native change."""
import hashlib
import json
from pathlib import Path
import shlex
import subprocess

root = Path(__file__).resolve().parent
repo = root.parent.parent
baseline = root / 'baseline-c/vox2'
common = root / 'common-object/vox2.o'
control_archive = root / 'native-control/skia.a'
candidate_archive = repo / 'Build/linux/native/skia.a'
native = shlex.split((root / 'baseline-c/build.sh').read_text().splitlines()[2])
sha = lambda path: hashlib.sha256(Path(path).read_bytes()).hexdigest()
assert common.is_file()
assert json.loads((root / 'common-object/result.json').read_text())['exit_code'] == 0
archive_report = json.loads((root / 'native-archive-comparison.json').read_text())
assert sha(control_archive) == archive_report['original_archive_sha256']
assert sha(candidate_archive) == archive_report['candidate_archive_sha256']
assert archive_report['changed_members'] == ['shadow_raster.o']
outputs = {'control':root/'control-relinked', 'candidate':root/'candidate-c'}
record = {'common_object_sha256':sha(common), 'baseline_binary_sha256':sha(baseline),
          'native_archive_comparison':archive_report, 'variants':{}}
report = root/'relink-variants.json'
assert not report.exists()
for label, directory in outputs.items():
    directory.mkdir()
    command = list(native)
    command[command.index('-o')+1] = str(directory/'vox2')
    command[command.index(str(root/'baseline-c/vox2.c'))] = str(common)
    if label == 'control':
        positions = [i for i,arg in enumerate(command) if arg.endswith('/skia.a')]
        assert len(positions) == 1
        command[positions[0]] = str(control_archive)
    row = {'command':command, 'archive_sha256':sha(control_archive if label=='control' else candidate_archive)}
    record['variants'][label] = row
    report.write_text(json.dumps(record,indent=2)+'\n')
    with (directory/'link.log').open('x') as log:
        result = subprocess.run(command,cwd=repo,stdout=log,stderr=subprocess.STDOUT)
    row['exit_code'] = result.returncode
    if result.returncode == 0:
        row['binary_sha256'] = sha(directory/'vox2')
    report.write_text(json.dumps(record,indent=2)+'\n')
    assert result.returncode == 0, directory/'link.log'
    if label == 'control':
        row['byte_identical_to_original'] = row['binary_sha256'] == record['baseline_binary_sha256']
        report.write_text(json.dumps(record,indent=2)+'\n')
        assert row['byte_identical_to_original'], 'Control relink differs; inspect before attributing any change'
assert sha(common) == record['common_object_sha256']
assert sha(baseline) == record['baseline_binary_sha256']
assert sha(control_archive) == archive_report['original_archive_sha256']
assert sha(candidate_archive) == archive_report['candidate_archive_sha256']
record['accepted'] = True
report.write_text(json.dumps(record,indent=2)+'\n')
print(json.dumps({'accepted':True,'variants':record['variants']},indent=2))
