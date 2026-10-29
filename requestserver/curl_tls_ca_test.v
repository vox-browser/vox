module requestserver

import dom
import html
import os
import time
import xhr

fn tls_ca_test_fetch(address string, expected_status u16, expected_body string) {
	mut document := dom.Document.create(dom.URL{value: address})
	document.set_origin(document.url.origin())
	window := html.WindowModel.create_top_level(document, none, 'tls-ca') or { panic(err) }
	mut realm := &html.ScriptingRealm{}
	settings := html.WindowEnvironmentSettingsObject.setup(window, document.url, mut realm, none, document.url, document.origin()).settings
	mut owner := settings.responsible_event_loop()
	mut connection := CurlConnection.create() or { panic(err) }
	defer { connection.close() }
	mut request := xhr.XMLHttpRequest.construct_in_settings(settings, connection.fetch_host())
	request.open('GET', '/resource', true, none, none) or { panic(err) }
	request.send() or { panic(err) }
	deadline := time.sys_mono_now() + 5 * time.second
	owner.spin_until(fn [request, deadline] () bool {
		return request.state == .done || time.sys_mono_now() >= deadline
	})
	assert request.state == .done, '${address}: expected ${expected_status}'
	assert request.status() == expected_status, address
	assert request.response_text() or { panic(err) } == expected_body
	assert connection.active_request_count() == 0
}

fn test_native_https_uses_configured_ca_without_disabling_certificate_or_hostname_verification() {
	$if !darwin && !linux { return }
	directory := os.join_path(os.temp_dir(), 'vox-native-tls-${os.getpid()}-${time.sys_mono_now()}')
	os.mkdir_all(directory)!
	defer { os.rmdir_all(directory) or {} }
	mut server := os.new_process(os.find_abs_path_of_executable('python3')!)
	server.set_args([os.join_path(os.dir(@FILE), '..', 'tools', 'requestserver_tls_fixture.py'), directory])
	server.run()
	defer {
		server.signal_kill()
		server.wait()
		server.close()
	}
	deadline := time.sys_mono_now() + 10 * time.second
	port_path := os.join_path(directory, 'port')
	for !os.is_file(port_path) && time.sys_mono_now() < deadline { time.sleep(10 * time.millisecond) }
	assert os.is_file(port_path), 'TLS fixture did not start'
	port := os.read_file(port_path)!
	previous_ca := os.getenv_opt('SSL_CERT_FILE')
	previous_proxy := os.getenv_opt('VOX_PROXY')
	defer {
		if value := previous_ca { os.setenv('SSL_CERT_FILE', value, true) } else { os.unsetenv('SSL_CERT_FILE') }
		if value := previous_proxy { os.setenv('VOX_PROXY', value, true) } else { os.unsetenv('VOX_PROXY') }
	}
	os.setenv('VOX_PROXY', '', true)
	os.setenv('SSL_CERT_FILE', os.join_path(directory, 'trusted.pem'), true)
	tls_ca_test_fetch('https://127.0.0.1:${port}/owner', 200, 'private CA resource')
	// The CA is trusted only for the certificate's actual IP address.
	tls_ca_test_fetch('https://localhost:${port}/owner', 0, '')
	os.setenv('SSL_CERT_FILE', os.join_path(directory, 'unrelated.pem'), true)
	tls_ca_test_fetch('https://127.0.0.1:${port}/owner', 0, '')
}
