import re
import unittest

from http_receive_buffer import patch_receive_buffer, receive_buffer_helper


class ReceiveBufferPatchTest(unittest.TestCase):
    def test_only_the_accumulator_is_replaced(self):
        source = '''module http
fn (req &Request) receive_all_data_from_cb_in_builder(mut content strings.Builder, con voidptr, receive_chunk_cb FnReceiveChunk) !ReceivedResponseInfo {
    req.on_progress(req, chunk, total)!
    receive_chunk_cb(con, bytes, count)!
    header := 'content-length: 10'
    unsafe { content.write_ptr(bytes, count) }
    unsafe { content.write_ptr(bytes, count) }
    size := content.len
    content.write(chunk)!
    return ReceivedResponseInfo{}
}
'''
        patched = patch_receive_buffer(source)
        self.assertIn("'content-length: 10'", patched)
        self.assertIn('req.on_progress(req, chunk, total)!', patched)
        self.assertIn('receive_chunk_cb(con, bytes, count)!', patched)
        self.assertIn('defer { received.publish(mut content) }', patched)
        self.assertEqual(2, len(re.findall('received.write_ptr\\(bytes, count\\)', patched)))
        self.assertEqual(patched, patch_receive_buffer(patched))
        self.assertIn('module http', receive_buffer_helper())
        with self.assertRaisesRegex(RuntimeError, 'Unsupported HTTP receive-buffer access'):
            patch_receive_buffer(source.replace('size := content.len',
                                                'size := content.len\n previous := content.cap'))

    def test_changed_receive_implementations_fail_before_staging(self):
        with self.assertRaisesRegex(RuntimeError, 'Unsupported HTTP receive-buffer'):
            patch_receive_buffer('module http')
        with self.assertRaisesRegex(RuntimeError, 'Unsupported HTTP receive-buffer write'):
            patch_receive_buffer('''fn (req &Request) receive_all_data_from_cb_in_builder(mut content strings.Builder, con voidptr, receive_chunk_cb FnReceiveChunk) !ReceivedResponseInfo {
 return ReceivedResponseInfo{}
}''')


if __name__ == '__main__':
    unittest.main()
