module browsernet

import net
import net.http
import os
import time

fn test_refused_tcp_connection_does_not_initialize_tls_certificates() {
	// Reserve an ephemeral loopback address, then close it so both transports
	// fail before TLS. A nonexistent CA file distinguishes certificate setup
	// from the TCP failure without depending on platform-specific error text.
	mut listener := net.listen_tcp(.ip, '127.0.0.1:0')!
	address := listener.addr()!.str()
	listener.close()!
	missing_ca := os.join_path(os.temp_dir(), 'vox-missing-ca-${os.getpid()}-${time.sys_mono_now()}.pem')
	assert !os.exists(missing_ca)
	for http2 in [false, true] {
		if response := http.fetch(url: 'https://${address}/', verify: missing_ca,
			validate: true, enable_http2: http2, allow_redirect: false,
			read_timeout: time.second, write_timeout: time.second) {
			assert false, 'closed loopback endpoint returned ${response.status_code}'
		} else {
			assert !err.msg().contains('certificates'), err.msg()
			assert !err.msg().contains('SSLConn.init'), err.msg()
		}
		http.close_idle_connections()
	}
}
