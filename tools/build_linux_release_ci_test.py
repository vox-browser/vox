import copy
from pathlib import Path
import subprocess
import tempfile
import unittest
from unittest.mock import patch

import build_linux_release_ci as release


class ReleaseBuildTests(unittest.TestCase):
    def test_native_packaging_uses_current_tools_with_the_pinned_source_and_environment(self):
        source = Path('/clean/release')
        environment = dict(V_BIN='/pinned/v', CC='/pinned/clang')
        for distribution, module in [('arch', 'deploy_arch'), ('debian', 'deploy_linux')]:
            with patch(module + '.deploy', return_value=Path('/release/package')) as deploy:
                self.assertEqual(release.build_native_package(source, distribution, environment),
                                 Path('/release/package'))
                deploy.assert_called_once_with(root=source, build_environment=environment)
    def test_json2_field_adapter_preserves_the_generic_pointer_and_rejects_unknown_layouts(self):
        field = 'mut target := unsafe { field }\n\t\t\tdecoder.decode_value(mut target)!'
        source = 'module json2\n' + field + '\nmut target := unsafe { field }\n target.clear()\n'
        patched = release.typed_json2_fields(source)
        self.assertIn('decoder.decode_value[F](mut *field)!', patched)
        self.assertIn('mut target := unsafe { field }\n target.clear()', patched)
        self.assertEqual(release.typed_json2_fields(patched), patched)
        for bad in ('module json2', source + field):
            with self.assertRaisesRegex(RuntimeError, 'Unsupported JSON2'):
                release.typed_json2_fields(bad)

    def test_portable_clip_preserves_the_release_function_without_gpu_uploads(self):
        function = 'pub fn document_image_clip_requires_msaa(rect Rect, radii [4]Point) bool {\n\treturn true\n}'
        source = 'module canvas\nfn gpu_upload() {}\n' + function + '\nfn another_gpu_upload() {}\n'
        self.assertEqual(release.portable_clip(source), 'module canvas\n\n' + function + '\n')
        for bad in ('module canvas', source + '\n' + function):
            with self.assertRaisesRegex(RuntimeError, 'exactly one'):
                release.portable_clip(bad)

    def test_package_must_have_native_prod_mode_and_the_clean_release_commit(self):
        manifest = dict(architecture='amd64', source_build=dict(exit=0,
            c_compile=dict(backend='c', mode='single', requested='single', v_prod=True),
            inputs=dict(head='a' * 40, dirty=False),
            verified_inputs=dict(head='a' * 40, dirty=False)))
        release.verify_package_manifest(manifest, 'a' * 40, 'amd64')
        for field, value in (('backend', 'fastc'), ('v_prod', False), ('mode', 'parallel')):
            changed = copy.deepcopy(manifest)
            changed['source_build']['c_compile'][field] = value
            with self.assertRaises(RuntimeError):
                release.verify_package_manifest(changed, 'a' * 40, 'amd64')
        for key in ('inputs', 'verified_inputs'):
            for field, value in (('head', 'b' * 40), ('dirty', True)):
                changed = copy.deepcopy(manifest)
                changed['source_build'][key][field] = value
                with self.assertRaises(RuntimeError):
                    release.verify_package_manifest(changed, 'a' * 40, 'amd64')
        with self.assertRaises(RuntimeError):
            release.verify_package_manifest(manifest, 'a' * 40, 'arm64')

    def test_arch_install_must_succeed_and_match_the_package_before_browser_checks(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            package, executable = root / 'vox.pkg.tar.zst', root / 'installed-vox'
            package.write_bytes(b'archive')
            executable.write_bytes(b'ELF fixture')
            manifest = dict(package_sha256=release.digest(package),
                            packaged_executable_sha256=release.digest(executable))
            calls = []

            def guarded(command, name, *args):
                calls.append((command, name, args))

            release.validate_package(root, root, package, manifest, 'arch', guarded, {}, executable)
            self.assertEqual(calls[0], (['sudo', '-n', 'pacman', '-U', '--noconfirm', package], 'install', ()))
            self.assertEqual(calls[1][0][2], executable)
            self.assertEqual(calls[1][1:], ('browser', (3, {})))
            calls.clear()
            executable.write_bytes(b'wrong installed bytes')
            with self.assertRaisesRegex(RuntimeError, 'Installed executable'):
                release.validate_package(root, root, package, manifest, 'arch', guarded, {}, executable)
            self.assertEqual(len(calls), 1)
            executable.write_bytes(b'ELF fixture')

            def failed_install(command, name, *args):
                raise subprocess.CalledProcessError(1, command)

            with self.assertRaises(subprocess.CalledProcessError):
                release.validate_package(root, root, package, manifest, 'arch', failed_install, {}, executable)

    def test_changed_package_is_rejected_before_installation_and_after_browser_checks(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            package, executable = root / 'vox.pkg.tar.zst', root / 'installed-vox'
            package.write_bytes(b'archive')
            executable.write_bytes(b'ELF fixture')
            manifest = dict(package_sha256=release.digest(package),
                            packaged_executable_sha256=release.digest(executable))

            def tamper(command, name, *args):
                if name == 'browser':
                    package.write_bytes(b'changed package')

            with self.assertRaisesRegex(RuntimeError, 'changed during validation'):
                release.validate_package(root, root, package, manifest, 'arch', tamper, {}, executable)
            with self.assertRaisesRegex(RuntimeError, 'recorded checksum'):
                release.validate_package(root, root, package, manifest, 'arch', tamper, {}, executable)


if __name__ == '__main__':
    unittest.main()
