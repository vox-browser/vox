import json
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
from unittest import mock

import sealed_browser_profile as profile


class SealedProfileTests(unittest.TestCase):
    def test_library_relocation_requires_original_bytes_and_rejects_newer_content(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            cache = root / 'Build/v/libengine.dylib'
            cache.parent.mkdir(parents=True)
            cache.write_bytes(b'original linker bytes')
            expected = profile.digest(cache)
            signed = root / 'Build/v/Vox.app/Contents/MacOS/libengine.dylib'
            signed.parent.mkdir(parents=True)
            signed.write_bytes(b'signed canonical app')
            staged = root / 'Build/.production-output-moved/libengine.dylib'
            with mock.patch.object(profile, 'ROOT', root):
                self.assertEqual(profile.resolve_library(str(staged), expected), cache)
                cache.write_bytes(b'newer build')
                with self.assertRaisesRegex(ValueError, 'No byte-identical'):
                    profile.resolve_library(str(staged), expected)
                # Arbitrary missing paths never silently select a cache file.
                with self.assertRaises(ValueError):
                    profile.resolve_library(str(root / 'other/libengine.dylib'), profile.digest(cache))

    def test_main_injection_preserves_every_other_byte(self):
        source = 'void helper(void) {}\nvoid main__main(void) {\n helper();\n}\n'
        changed = profile.inject_entry(source)
        inserted = '\n extern void vox_cprofile_start(void *);\n vox_cprofile_start((void *)&main__main);'
        self.assertEqual(changed.replace(inserted, ''), source)
        for wrong in ['', source + source, changed, source.replace('void main__main', 'int main__main')]:
            with self.assertRaises(ValueError):
                profile.inject_entry(wrong)

    def test_compile_command_preserves_link_order_and_source_languages(self):
        command = ['clang', '-x', 'objective-c-cpp-output', '/sealed/main.i', '-x', 'none',
                   '/sealed/a.o', '-x', 'objective-c-cpp-output', '/sealed/module.i',
                   '-x', 'none', '-O3', '-ObjC', '-lengine', '-lc++', '-o', '/old/Vox']
        actual = profile.profile_command(command, Path('/sealed/main.i'), Path('/new/main.i'),
                                         Path('/new/helper.o'), Path('/new/Vox'),
                                         {'engine': Path('/canonical/libengine.dylib')})
        self.assertEqual(actual, ['clang', '-x', 'objective-c-cpp-output', '/new/main.i',
            '-x', 'none', '/sealed/a.o', '-x', 'objective-c-cpp-output', '/sealed/module.i',
            '-x', 'none', '-O1', '-ObjC', '/canonical/libengine.dylib', '-lc++',
            '-x', 'none', '/new/helper.o', '-finstrument-functions-after-inlining',
            '-O1', '-o', '/new/Vox'])
        for wrong in [command + ['-o', 'second'], command[4:]]:
            with self.assertRaises(ValueError):
                profile.profile_command(wrong, Path('/sealed/main.i'), Path('new'),
                                        Path('helper'), Path('binary'), {})

    def test_current_v_entry_starts_after_module_initialization(self):
        source = 'int main(int argc, char** argv) {\n g_main_argc=argc;\n _vinit();\n run();\n}'
        changed = profile.inject_entry(source)
        inserted = '\n extern void vox_cprofile_start(void *);\n vox_cprofile_start((void *)&main);'
        self.assertEqual(changed.replace(inserted, ''), source)
        self.assertIn('_vinit();' + inserted, changed)
        with self.assertRaises(ValueError):
            profile.inject_entry(source.replace('_vinit();', 'unknown_init();'))

    def test_changed_sealed_input_is_rejected_before_creating_outputs(self):
        with tempfile.TemporaryDirectory() as temporary:
            out = Path(temporary)
            binary = out / 'Vox'
            binary.write_bytes(b'browser')
            source = out / '0-Vox.c.i'
            source.write_bytes(b'changed compiler input')
            compiler = out / 'clang'
            compiler.write_bytes(b'compiler identity; must never execute')
            frozen = out / 'frozen.json'
            frozen.write_text(json.dumps(dict(complete=True, compiler_exit=0,
                compiler=str(compiler), sealed_inputs={str(source): '0'*64},
                resolved_libraries={}, live_inputs={str(compiler): profile.digest(compiler)})))
            receipt = out / 'latest.json'
            receipt.write_text(json.dumps(dict(exit=0, executable=str(binary),
                executable_sha256=profile.digest(binary), frozen_compilation=str(frozen),
                c_compile=dict(mode='single'))))
            with self.assertRaisesRegex(ValueError, 'Changed sealed/link input'):
                profile.build(receipt, out / 'diagnostic')
            self.assertFalse((out / 'diagnostic').exists())

    def test_profile_faults_duplicates_and_invalid_counts_fail_closed(self):
        row = dict(address=1, calls=2, partial_calls=1, self_ns=4, inclusive_ns=8)
        text = 'VOX_CPROFILE_META {"faults":0,"unfinished_frames":1}\nVOX_CPROFILE ' + json.dumps(row)
        result = profile.parse_profile(text)
        self.assertEqual(result['rows'], [row])
        for wrong in ['', text.replace('"faults":0', '"faults":1'),
                      text + '\nVOX_CPROFILE ' + json.dumps(row),
                      text.replace('"self_ns": 4', '"self_ns": 9')]:
            with self.assertRaises(ValueError):
                profile.parse_profile(wrong)

    @unittest.skipUnless(sys.platform == 'darwin', 'Mach timing helper')
    def test_real_after_inline_callbacks_recursion_threads_and_partial_exit(self):
        # A real compiler/runtime control checks the callback ABI and TLS gate.
        source = r'''
#include <pthread.h>
#include <stdint.h>
extern void vox_cprofile_start(void *);
extern void vox_cprofile_flush(void);
volatile int result;
__attribute__((noinline)) void leaf(void) { ++result; }
__attribute__((noinline)) void recursive(int n) { leaf(); if(n) recursive(n-1); }
void *background(void *p) { (void)p; leaf(); return 0; }
__attribute__((noinline)) void flush_inside(void) { vox_cprofile_flush(); }
int main(void) {
 leaf(); vox_cprofile_start((void *)&main);
 recursive(3);
 pthread_t thread; pthread_create(&thread,0,background,0); pthread_join(thread,0);
 flush_inside(); return result == 6 ? 0 : 1;
}
'''
        with tempfile.TemporaryDirectory() as temporary:
            out = Path(temporary)
            (out / 'input.c').write_text(source)
            subprocess.run(['clang', '-O2', '-Wall', '-Wextra', '-Werror', '-c',
                            str(profile.HELPER), '-o', str(out / 'helper.o')], check=True)
            subprocess.run(['clang', '-O1', '-fno-optimize-sibling-calls',
                            '-finstrument-functions-after-inlining', str(out / 'input.c'),
                            str(out / 'helper.o'), '-o', str(out / 'probe')], check=True)
            completed = subprocess.run([str(out / 'probe')], check=True, capture_output=True, text=True)
            result = profile.parse_profile(completed.stdout)
            rows = {r['function']: r for r in result['rows']}
            self.assertEqual(rows['leaf']['calls'], 4)
            self.assertEqual(rows['recursive']['calls'], 4)
            self.assertEqual(rows['flush_inside']['partial_calls'], 1)
            self.assertNotIn('background', rows)
            self.assertEqual(result['metadata']['unfinished_frames'], 1)
            self.assertTrue(all(Path(r['image']).resolve() == (out / 'probe').resolve() for r in rows.values()))


if __name__ == '__main__':
    unittest.main()
