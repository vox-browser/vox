module requestserver

// Keep this file's only test first in its process: it observes whether any
// earlier code has mapped libcurl.
fn test_libcurl_is_mapped_only_when_a_connection_starts_a_transfer() {
	$if !macos {
		return
	}
	assert C.vox_curl_library_loaded() == 0
	mut connection := CurlConnection.create()!
	// Script hosts create a connection for every scripted document.
	assert C.vox_curl_library_loaded() == 0
	connection.ensure_multi()!
	assert C.vox_curl_library_loaded() == 1
	mut request := C.vox_curl_easy_init()
	assert request != unsafe { nil }
	assert C.vox_curl_setopt_long(request, C.CURLOPT_TIMEOUT_MS, 1000) == C.CURLE_OK
	C.vox_curl_easy_cleanup(request)
	connection.close()
}

fn test_closing_a_connection_that_never_transferred_skips_curl() {
	mut connection := CurlConnection.create()!
	connection.close()
	assert connection.multi_ == unsafe { nil }
	assert connection.active_request_count() == 0
}
