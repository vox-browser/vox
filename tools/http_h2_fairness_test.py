import unittest

from http_h2_fairness import patch_h2_pooled_transport


class UpstreamAdmissionTest(unittest.TestCase):
    def source(self):
        return ('fn (mut t H2PooledTransport) lock_io() {\n'
                '\tt.io_admission.lock()\n\tt.io_mu.lock()\n'
                '\tt.io_admission.unlock()\n}\n'
                'fn calls() { t.lock_io(); t.lock_io(); t.lock_io(); t.lock_io() }')

    def test_reuses_the_existing_admission_gate(self):
        source = self.source()
        result = patch_h2_pooled_transport(source)
        self.assertTrue(result.startswith(source))
        self.assertIn('vox_lock_io() { t.lock_io() }', result)
        self.assertNotIn('vox_admission_mu', result)

    def test_unknown_gates_and_call_layouts_are_rejected(self):
        for source in (self.source().replace('io_admission.unlock()', 'io_mu.unlock()'),
                       self.source().replace('t.lock_io(); ', '')):
            with self.subTest(source=source), self.assertRaisesRegex(RuntimeError, 'admission'):
                patch_h2_pooled_transport(source)


if __name__ == '__main__':
    unittest.main()
