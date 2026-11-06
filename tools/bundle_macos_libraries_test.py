from contextlib import redirect_stdout
import io
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import unittest

from bundle_macos_libraries import Image, bundle_libraries, macho_files, verify_self_contained

MAIN = r'''
#include <dlfcn.h>
#include <stdio.h>
int dep_value(void);
int absolute_value(void);
int helper_value(void);
int main(void) {
    void *runtime = dlopen("@rpath/libruntime.3.dylib", RTLD_NOW | RTLD_LOCAL);
    int (*value)(void) = runtime ? (int (*)(void))dlsym(runtime, "runtime_value") : 0;
    void *optional = dlopen("@rpath/libmissing.dylib", RTLD_NOW | RTLD_LOCAL);
    printf("%d\n", dep_value() + absolute_value() + helper_value() + (value ? value() : 0)
        + (optional ? 10000 : 0));
    return 0;
}
'''


@unittest.skipUnless(sys.platform == 'darwin', 'Mach-O packaging requires macOS')
class BundleLibrariesTests(unittest.TestCase):
    def setUp(self):
        temporary = tempfile.TemporaryDirectory(prefix='vox-bundle-test-')
        self.addCleanup(temporary.cleanup)
        self.root = Path(temporary.name)
        # vcpkg addresses its libraries through @rpath; Homebrew by absolute path.
        self.vendor, self.brew = self.root / 'vendor', self.root / 'brew'
        self.app = self.root / 'Vox.app'
        binaries = self.app / 'Contents/MacOS'
        for folder in (self.vendor, self.brew, binaries):
            folder.mkdir(parents=True)
        self.dylib(self.vendor / 'libleaf.1.0.dylib', 'int leaf_value(void) { return 1; }')
        self.dylib(self.vendor / 'libdep.2.0.dylib',
                   'int leaf_value(void);\nint dep_value(void) { return 10 + leaf_value(); }',
                   self.vendor / 'libleaf.1.0.dylib', '-Wl,-rpath,@loader_path')
        self.dylib(self.vendor / 'libruntime.3.4.dylib', 'int runtime_value(void) { return 100; }')
        (self.vendor / 'libruntime.3.dylib').symlink_to('libruntime.3.4.dylib')
        self.dylib(self.brew / 'libabsolute.dylib', 'int absolute_value(void) { return 1000; }',
                   install_name=str(self.brew / 'libabsolute.dylib'))
        self.dylib(binaries / 'libhelper.dylib',
                   'int dep_value(void);\nint helper_value(void) { return dep_value(); }',
                   self.vendor / 'libdep.2.0.dylib', '-Wl,-rpath,' + str(self.vendor))
        source = self.root / 'main.c'
        source.write_text(MAIN)
        self.executable = binaries / 'Vox'
        subprocess.run(['clang', str(source), str(self.vendor / 'libdep.2.0.dylib'),
                        str(self.brew / 'libabsolute.dylib'), str(binaries / 'libhelper.dylib'),
                        '-Wl,-rpath,' + str(self.vendor), '-Wl,-rpath,@executable_path',
                        '-o', str(self.executable)], check=True)

    def dylib(self, path, code, *arguments, install_name=None):
        source = self.root / (path.name + '.c')
        source.write_text(code + '\n')
        subprocess.run(['clang', '-dynamiclib', str(source), *map(str, arguments),
                        '-Wl,-install_name,' + (install_name or '@rpath/' + path.name),
                        '-o', str(path)], check=True)

    def bundle(self):
        output = io.StringIO()
        with redirect_stdout(output):
            modified = bundle_libraries(self.app)
        return modified, output.getvalue()

    def sign(self):
        for path in macho_files(self.app):
            subprocess.run(['codesign', '--force', '--sign', '-', str(path)],
                           check=True, capture_output=True)

    def run_app(self):
        environment = {k: v for k, v in os.environ.items() if not k.startswith('DYLD_')}
        return subprocess.check_output([str(self.executable)], env=environment, text=True).strip()

    def test_release_runs_after_build_machine_libraries_are_removed(self):
        self.assertEqual(self.run_app(), '1122')
        with self.assertRaisesRegex(RuntimeError, 'searches ' + str(self.vendor)):
            verify_self_contained(self.app)
        modified, output = self.bundle()
        self.assertIn('leaving it out: @rpath/libmissing.dylib', output)
        frameworks = self.app / 'Contents/Frameworks'
        self.assertEqual(sorted(path.name for path in frameworks.iterdir()),
                         ['libabsolute.dylib', 'libdep.2.0.dylib', 'libleaf.1.0.dylib',
                          'libruntime.3.4.dylib', 'libruntime.3.dylib'])
        # dlopen's major-version name aliases the copy, which keeps its install name.
        self.assertEqual((frameworks / 'libruntime.3.dylib').readlink(), Path('libruntime.3.4.dylib'))
        self.assertIn(self.executable, modified)
        executable = Image(self.executable)
        self.assertIn(('@rpath/libabsolute.dylib', True), executable.dependencies)
        self.assertEqual(executable.rpaths, ['@executable_path', '@executable_path/../Frameworks'])
        self.assertEqual(Image(self.app / 'Contents/MacOS/libhelper.dylib').rpaths,
                         ['@loader_path/../Frameworks'])
        self.assertEqual(Image(frameworks / 'libabsolute.dylib').identity, '@rpath/libabsolute.dylib')
        self.assertEqual(Image(frameworks / 'libdep.2.0.dylib').rpaths, ['@loader_path'])
        verify_self_contained(self.app)
        self.sign()
        shutil.rmtree(self.vendor)
        shutil.rmtree(self.brew)
        self.assertEqual(self.run_app(), '1122')

    def test_missing_build_machine_library_rejects_the_release(self):
        (self.brew / 'libabsolute.dylib').unlink()
        with self.assertRaisesRegex(RuntimeError, 'MacOS/Vox links .*libabsolute.dylib'):
            self.bundle()


if __name__ == '__main__':
    unittest.main()
