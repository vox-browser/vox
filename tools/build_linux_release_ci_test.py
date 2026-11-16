import copy
import unittest

import build_linux_release_ci as release


class ReleaseBuildTests(unittest.TestCase):
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


if __name__ == '__main__':
    unittest.main()
