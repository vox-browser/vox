module browserupdate

import net
import os
import time

fn test_release_version_comparison_is_numeric_and_ignores_equal_or_older_versions() {
	assert is_newer('0.1', '0.2')
	assert is_newer('0.9.9', '0.10.0')
	assert is_newer('1.9', '1.10')
	assert is_newer('1.2.3', 'v2.0.0\n')
	assert is_newer('1.2.3-rc.1', '1.2.3')
	assert !is_newer('1.2.3', '1.2.3-rc.1')
	assert !is_newer('0.1', '0.1.0')
	assert !is_newer('1.2.3+old', '1.2.3+new')
	assert !is_newer('2.0', '1.99.99')
	assert !is_newer('2.0', '2.0')
	for bad in ['', 'Not Found', '<html>2.0</html>', '1..0', '1.2.3.4', '-1.0', '1e2.0',
		'999999999999999999999999.0'] {
		assert !is_newer('0.1', bad), bad
		assert !is_newer(bad, '2.0'), bad
	}
	parse_version(current_version())!
}

fn serve_version(mut listener net.TcpListener, status int, body string, requests chan string) {
	mut connection := listener.accept() or { panic(err) }
	defer { connection.close() or {} }
	connection.set_read_timeout(5 * time.second)
	mut bytes := []u8{len: 4096}
	count := connection.read(mut bytes) or { panic(err) }
	requests <- bytes[..count].bytestr()
	connection.write_string('HTTP/1.1 ${status} Test\r\nContent-Type: text/plain\r\nContent-Length: ${body.len}\r\nConnection: close\r\n\r\n${body}') or { panic(err) }
}

fn local_version_response(status int, body string) string {
	mut listener := net.listen_tcp(.ip, '127.0.0.1:0') or { panic(err) }
	defer { listener.close() or {} }
	listener.set_accept_timeout(5 * time.second)
	requests := chan string{cap: 1}
	worker := spawn serve_version(mut listener, status, body, requests)
	result := fetch_version('http://${listener.addr() or { panic(err) }}/version', '0.1')
	worker.wait()
	request := <-requests
	assert request.starts_with('GET /version HTTP/1.1\r\n')
	assert request.contains('Cache-Control: no-cache')
	return result
}

fn test_check_fetches_version_and_ignores_unavailable_invalid_and_unchanged_responses() {
	assert local_version_response(200, '0.2.0\n') == '0.2.0'
	assert local_version_response(200, '0.1.0') == ''
	assert local_version_response(200, '0.0.9') == ''
	assert local_version_response(404, '9.0.0') == ''
	assert local_version_response(500, '9.0.0') == ''
	assert local_version_response(200, '<html>Unavailable</html>') == ''
	assert local_version_response(200, '9'.repeat(1024)) == ''
	assert fetch_version('not a URL', '0.1') == ''
}

struct HandoffLog {
mut:
	events []string
}

fn test_ok_opens_the_fixed_download_site_before_quitting() {
	mut log := &HandoffLog{}
	open_download_and_quit(fn [mut log] (url string) ! {
		log.events << url
	}, fn [mut log] () {
		log.events << 'quit'
	})!
	assert log.events == ['https://vox-browser.org', 'quit']
}

fn test_failed_browser_launch_does_not_quit_vox() {
	mut log := &HandoffLog{}
	mut failed := false
	open_download_and_quit(fn (_ string) ! {
		return error('No default browser')
	}, fn [mut log] () {
		log.events << 'quit'
	}) or { failed = true }
	assert failed
	assert log.events.len == 0
}

fn test_machine_opt_out_file_disables_checks_for_every_profile() {
	home := os.join_path(os.vtmp_dir(), 'vox-update-opt-out-${os.getpid()}')
	previous_home := os.getenv('HOME')
	previous_profile := os.getenv_opt('VOX_PROFILE_DIR')
	os.setenv('HOME', home, true)
	// Temporary profiles live elsewhere; the opt-out still applies to them.
	os.setenv('VOX_PROFILE_DIR', os.join_path(home, 'temporary-profile'), true)
	defer {
		os.setenv('HOME', previous_home, true)
		if profile := previous_profile {
			os.setenv('VOX_PROFILE_DIR', profile, true)
		} else {
			os.unsetenv('VOX_PROFILE_DIR')
		}
		os.rmdir_all(home) or {}
	}
	assert !disabled_on_this_machine()
	$if macos {
		assert opt_out_path() == os.join_path(home, 'Library', 'Application Support', 'Vox', 'no-update-check')
	}
	os.mkdir_all(os.dir(opt_out_path()))!
	os.write_file(opt_out_path(), '')!
	assert disabled_on_this_machine()
	results := chan string{cap: 1}
	check(results)
	assert <-results == ''
}
