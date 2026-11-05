import unittest

from http_proxy_pool import patch_pooled_proxy_request, patch_pooled_proxy_transport

REQUEST = '''fn (req &Request) method_and_url_to_response(method Method, url urllib.URL, data string, header Header) !Response {
\tif req.proxy == unsafe { nil } && !req.disable_connection_reuse
\t\t&& (scheme == 'http' || scheme == 'https') {
\t}
}
'''

TRANSPORT = '''fn transport_pool_key(req &Request, scheme string, host string, port int) string {
\treturn '${scheme}|${pk_part(host)}|${port}|${req.in_memory_verification}'
}

fn (mut t Transport) dial_h1_tcp(req &Request, key string, host string, port int) !&H1PooledConn {
\tmut client := net.dial_tcp('${host}:${port}')!
\treturn &H1PooledConn{}
}
'''


class PooledProxyPatchTest(unittest.TestCase):
    def test_proxied_requests_use_the_pool_keyed_by_proxy(self):
        request = patch_pooled_proxy_request(REQUEST)
        self.assertIn('(req.proxy == unsafe { nil } || vox_transport_tunnels_proxy())', request)
        transport = patch_pooled_proxy_transport(TRANSPORT)
        self.assertIn('|${req.in_memory_verification}|${pk_part(vox_transport_proxy_key(req))}\'', transport)
        self.assertIn('mut client := vox_http_dial_tcp(req, host, port)!', transport)
        self.assertNotIn('net.dial_tcp', transport)

    def test_unknown_transport_shapes_fail_before_staging(self):
        with self.assertRaises(RuntimeError):
            patch_pooled_proxy_request(REQUEST.replace('req.proxy == unsafe { nil } && ', ''))
        with self.assertRaises(RuntimeError):
            patch_pooled_proxy_transport(TRANSPORT.replace("net.dial_tcp('${host}:${port}')", 'dial()'))
        with self.assertRaises(RuntimeError):
            patch_pooled_proxy_transport(TRANSPORT.replace('|${req.in_memory_verification}', ''))


if __name__ == '__main__':
    unittest.main()
