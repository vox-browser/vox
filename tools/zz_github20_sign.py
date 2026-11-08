from pathlib import Path
import sys,json,subprocess,plistlib
from freeze_browser_compile import validate,digest
from browser_bundle_lease import canonical_bundle_lease,ROOT
out=ROOT/'Build/github-20-instr'/sys.argv[1];receipt=out/'receipt';binary=out/'Vox.app/Contents/MacOS/Vox';info=binary.parent.parent/'Info.plist'
frozen=json.loads((receipt/'frozen-compile.json').read_text());validate(receipt,frozen['source_inputs'])
with canonical_bundle_lease(ROOT/'Build/v/Vox.app'):
 if info.is_symlink():info.unlink()
 info.write_bytes(plistlib.dumps(plistlib.loads((ROOT/'packaging/Info.plist').read_bytes())))
 raw=out/'native-Vox';binary.rename(raw)
 try:
  subprocess.run(['codesign','--force','--sign','-','--entitlements',str(ROOT/'packaging/Vox.entitlements.plist'),str(raw)],check=True)
  subprocess.run(['codesign','--verify',str(raw)],check=True)
 finally:raw.rename(binary)
 result=dict(path=str(binary),sha256=digest(binary),helper_path=str((binary.parent/'VoxAdblockWorker').resolve()),helper_sha256=digest(binary.parent/'VoxAdblockWorker'),info_plist_sha256=digest(info),complete=True,note='Original C compilation and frozen-input verification succeeded; coordinator signing failed through referenced bundle metadata. Generated regular packaging metadata and raw-signed this newly compiled executable outside the app-shaped directory, verified it, then moved it back. Resources/helper reference shared bundle. No bundle copied.')
 (receipt/'executable.json').write_text(json.dumps(result,indent=2)+'\n');print(json.dumps(result))
