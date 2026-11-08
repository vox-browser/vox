import json,os,plistlib,subprocess,sys,time
from pathlib import Path
from browser_bundle_lease import ROOT,canonical_bundle_lease
from freeze_browser_compile import validate,digest
from rebuild_browser import write_json

job=ROOT/'Build/github-20-instr';source=job/'native-candidate5/receipt';frozen=json.loads((source/'frozen-compile.json').read_text())
output=job/sys.argv[1];output.mkdir();receipt=output/'receipt';receipt.mkdir();contents=output/'Vox.app/Contents';macos=contents/'MacOS';macos.mkdir(parents=True)
shared=ROOT/'Build/v/Vox.app';(contents/'Resources').symlink_to(shared/'Contents/Resources',target_is_directory=True);(macos/'VoxAdblockWorker').symlink_to(shared/'Contents/MacOS/VoxAdblockWorker');(contents/'Info.plist').write_bytes(plistlib.dumps(plistlib.loads((ROOT/'packaging/Info.plist').read_bytes())))
binary=macos/'Vox';original=Path(os.environ.get('ZZ_NATIVE_INPUT_IR','/var/folders/5s/gdmd5zq90y52hchygpfzp2m00000gn/T/0-Vox-4330b0.o'));bitcode=output/'optimized-main.bc';original.rename(bitcode);main_object=output/'main.o'
backend=['clang','-O3','-mcpu=native','-fno-lto','-Xclang','-disable-llvm-passes','-mllvm','-enable-machine-outliner=never','-x','ir',str(bitcode),'-c','-o',str(main_object)]
command=frozen['compiler_command'].copy();main_source=str(source/'frozen-compiler-inputs/0-Vox.c.i');at=command.index(main_source);assert command[at-2:at]==['-x','objective-c-cpp-output'];command[at-1]='none';command[at]=str(main_object);command[command.index('-o')+1]=str(binary);command += ['-fno-lto','-mllvm','-enable-machine-outliner=never']
identity=digest(__file__)
write_json(receipt/'commands.json',dict(backend=backend,link=command,cwd=frozen['cwd'],coordinator_sha256=identity,source_compilation=str(source),source_frozen_receipt_sha256=digest(source/'frozen-compile.json'),source_manifest_sha256=digest(source/'source-manifest.json'),optimized_ir_sha256=digest(bitcode),note='The source-proven candidate5 frontend completed and emitted this optimized LLVM module before its linker exceeded the memory cap. This candidate emits native code from that unchanged module without another IR optimization pipeline, disables machine outlining, then links the original sealed native inputs with LTO disabled for the generated C units. The original failed build remains failed. No source tree or app bundle copied.'))
with canonical_bundle_lease(shared):
 validate(source,frozen['source_inputs'],require_complete=False)
 started=time.monotonic();result=subprocess.run(backend,cwd=frozen['cwd']);write_json(receipt/'backend.json',dict(exit=result.returncode,wall_seconds=time.monotonic()-started))
 if result.returncode:raise SystemExit(result.returncode)
 started=time.monotonic();result=subprocess.run(command,cwd=frozen['cwd']);write_json(receipt/'link.json',dict(exit=result.returncode,wall_seconds=time.monotonic()-started))
 if result.returncode:raise SystemExit(result.returncode)
 validate(source,frozen['source_inputs'],require_complete=False)
 raw=output/'native-Vox';binary.rename(raw)
 try:
  subprocess.run(['codesign','--force','--sign','-','--entitlements',str(ROOT/'packaging/Vox.entitlements.plist'),str(raw)],check=True)
  subprocess.run(['codesign','--verify',str(raw)],check=True)
 finally:raw.rename(binary)
 if digest(__file__)!=identity:raise RuntimeError('Coordinator changed')
 write_json(receipt/'executable.json',dict(path=str(binary),sha256=digest(binary),helper_path=str((macos/'VoxAdblockWorker').resolve()),helper_sha256=digest(macos/'VoxAdblockWorker'),info_plist_sha256=digest(contents/'Info.plist'),complete=True))
print(str(binary),flush=True)
