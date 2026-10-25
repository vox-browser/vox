module requestserver

import dom
import fetch
import platform

// Run with -prealloc -gc none and
// VOX_ARENA_NO_REUSE=curl-construction,curl-request-start,curl-request-stop.
// Poisoning makes escaped scratch allocations fail deterministically.
fn test_curl_requests_and_deferred_cleanup_outlive_style_scratch() {
	$if !darwin && !linux { return }
	construction := platform.begin_thread_scratch('curl-construction')
	mut connection := CurlConnection.create()!
	construction.finish()
	defer { connection.close() }
	mut request := fetch.Request.create()
	request.url_list = [dom.URL{ value: 'http://127.0.0.1:1/font.woff2' }]
	params := fetch.FetchParams.create(request, fetch.FetchTimingInfo.create())
	mut pending := []&fetch.PendingResponse{}
	for _ in 0 .. 67 {
		scratch := platform.begin_thread_scratch('curl-request-start')
		response := connection.start_fetch(params, request)
		scratch.leave()
		pending << response
		scratch.finish()
	}
	assert connection.active_request_count() == 67
	for response in pending { assert !response.is_resolved() }
	// A cancellation from a body callback queues cleanup across the same
	// asynchronous boundary as a real request. Its closure must also survive.
	connection.in_curl_call_ = true
	cleanup := platform.begin_thread_scratch('curl-request-stop')
	for _, mut native in connection.requests_.clone() { native.stop() }
	cleanup.finish()
	connection.in_curl_call_ = false
	for connection.deferred_.run_one_deferred() {}
	assert connection.active_request_count() == 0
}
