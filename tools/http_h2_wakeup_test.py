import os
from pathlib import Path
import unittest

from http_h2_wakeup import patch_h2_mux_read_chunk, patch_h2_wakeup

VLIB = Path(os.environ.get('VOX_TEST_VLIB', Path.home() / 'code/v/vlib'))

MUX = '''pub struct H2MuxConn {
mut:
\tidle_since          time.Time
}

fn (mut c H2MuxConn) mux_fill_at_least(n int) ! {
\tfor c.rbuf.len < n {
\t\tmut tmp := []u8{len: h2_conn_read_chunk}
\t\tgot := c.transport.read(mut tmp)!
\t\tif got <= 0 {
\t\t\treturn error('connection closed by peer')
\t\t}
\t\tc.rbuf << tmp[..got]
\t}
}
'''


class H2ReadChunkPatchTest(unittest.TestCase):
    def test_idle_reads_reuse_one_chunk_per_connection(self):
        patched = patch_h2_mux_read_chunk(MUX)
        self.assertIn('\tvox_read_chunk      []u8\n', patched)
        self.assertNotIn('mut tmp := []u8', patched)
        self.assertEqual(patched.count('c.vox_read_chunk = []u8{len: h2_conn_read_chunk}'), 1)
        # The allocation happens before the read loop, never per attempt.
        self.assertLess(patched.index('c.vox_read_chunk = []u8'), patched.index('for c.rbuf.len < n'))
        self.assertIn('c.rbuf << c.vox_read_chunk[..got]', patched)

    def test_unknown_reader_shapes_fail_before_staging(self):
        with self.assertRaises(RuntimeError):
            patch_h2_mux_read_chunk(MUX.replace('\tidle_since          time.Time\n', ''))
        with self.assertRaises(RuntimeError):
            patch_h2_mux_read_chunk(MUX.replace('mut tmp := []u8{len: h2_conn_read_chunk}', 'mut tmp := []u8{len: 4}'))

    @unittest.skipUnless((VLIB / 'net/http/h2_pooled_transport.v').exists(), 'V checkout unavailable')
    def test_mbedtls_read_deadlines_enter_the_idle_wait(self):
        source = (VLIB / 'net/http/h2_pooled_transport.v').read_text()
        patched = patch_h2_wakeup(source)
        start = patched.index('fn (mut t H2PooledTransport) read(')
        read = patched[start:patched.index('\n}', start)]
        # mbedTLS reports MBEDTLS_ERR_SSL_TIMEOUT for the 5 ms deadline.
        self.assertIn('err.code() == net.err_timed_out_code\n            || is_transport_timeout_error(err)', read)
        self.assertIn('C.vox_h2_wake_wait(wake, i32(socket), 500)', read)


if __name__ == '__main__':
    unittest.main()
