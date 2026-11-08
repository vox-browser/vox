"""Temporary canonical-source candidate build; no source or app bundle copies."""
import hashlib
import json
import os
from pathlib import Path
import subprocess
import sys
import time
import plistlib

from browser_bundle_lease import canonical_bundle_lease, ROOT
from freeze_browser_compile import prepare, validate, digest
from production_source_manifest import begin, compile_component, combine
from rebuild_browser import repository_state, write_json

job = ROOT / 'Build/github-20-instr'
output = job / sys.argv[1]
output.mkdir()
receipt = output / 'receipt'
receipt.mkdir()
component = receipt / 'browser-sources'
component.mkdir()
generated = output / 'Vox.c'
flags = output / 'Vox.flags'
bundle = output / 'Vox.app'
contents = bundle / 'Contents'
macos = contents / 'MacOS'
macos.mkdir(parents=True)
shared = ROOT / 'Build/v/Vox.app'
(contents / 'Resources').symlink_to(shared / 'Contents/Resources', target_is_directory=True)
(contents / 'Info.plist').write_bytes(plistlib.dumps(plistlib.loads((ROOT / 'packaging/Info.plist').read_bytes())))
(macos / 'VoxAdblockWorker').symlink_to(shared / 'Contents/MacOS/VoxAdblockWorker')
binary = macos / 'Vox'
reference = json.loads((job / 'native-diagnostic/receipt/generation-command.json').read_text())
command = [arg for arg in reference['command'] if arg != '-prod']
literal_prod = os.getenv('ZZ_NATIVE_LITERAL_PROD') == '1'
if literal_prod: command.insert(1, '-prod')
optimization = os.getenv('ZZ_NATIVE_OPTIMIZATION', '-O3 -mllvm -inline-threshold=1500')
command[command.index('-cflags') + 1] += ' ' + optimization
command[command.index('-dump-c-flags') + 1] = str(flags)
command[command.index('-o') + 1] = str(generated)
os.environ.update(V_MACOS_V3_NO_FALLBACK='1', VFLAGS='', CFLAGS='', LDFLAGS='')
identity = digest(__file__)
write_json(receipt / 'generation-command.json', dict(command=command, cwd=reference['cwd'],
    coordinator_sha256=identity, c_mode='single', v_prod=literal_prod, optimization=optimization,
    note='New executable only; resources and the normal small helper reference the shared bundle. No source tree or app bundle was copied. No regression tests run.'))
with canonical_bundle_lease(shared):
    inventory = begin(ROOT)
    write_json(receipt / 'source-inventory.json', inventory)
    before = repository_state(ROOT)
    write_json(receipt / 'inputs-before.json', before)
    os.chdir(reference['cwd'])
    status = compile_component(ROOT, inventory, component, command)
    if status:
        raise SystemExit(status)
    manifest = combine(ROOT, inventory, [component], parsed=True)
    write_json(receipt / 'source-manifest.json', manifest)
    frozen = prepare(ROOT, ROOT / 'Build/v', receipt, generated, flags, binary,
        source_manifest=manifest, source_inventory=inventory, source_components=[component])
    started = time.monotonic()
    result = subprocess.run(frozen['compiler_command'], cwd=frozen['cwd'])
    frozen.update(compiler_exit=result.returncode, complete=result.returncode == 0,
                  wall_seconds=time.monotonic() - started)
    write_json(receipt / 'frozen-compile.json', frozen)
    if result.returncode:
        raise SystemExit(result.returncode)
    validate(receipt, frozen['source_inputs'])
    raw = output / 'native-Vox'
    binary.rename(raw)
    try:
        subprocess.run(['codesign', '--force', '--sign', '-', '--entitlements',
            str(ROOT / 'packaging/Vox.entitlements.plist'), str(raw)], check=True)
        subprocess.run(['codesign', '--verify', str(raw)], check=True)
    finally:
        raw.rename(binary)
    if digest(__file__) != identity:
        raise RuntimeError('Candidate coordinator changed during compilation')
    write_json(receipt / 'executable.json', dict(path=str(binary), sha256=digest(binary),
        helper_path=str((macos / 'VoxAdblockWorker').resolve()),
        helper_sha256=digest(macos / 'VoxAdblockWorker'),
        info_plist_sha256=digest(contents / 'Info.plist'),
        shared_bundle=str(shared), complete=True))
print(str(binary), flush=True)
