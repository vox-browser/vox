module adblock

import platform

// json2 publishes each struct type's field table in a process-wide static the
// first time that type is encoded or decoded. The browser's first request
// check can run while a document's native storage is entered (the New Tab
// page does), and fetch workers keep using the table after that document is
// retired. Only this test may touch these types before releasing the owner.
fn test_transport_struct_tables_survive_release_of_first_caller_storage() {
	request := Request{
		url:          'https://cdn.test/中/app.js'
		source_url:   'https://site.test/'
		request_type: 'script'
	}
	headers := [ResponseHeader{
		name:  'Content-Type'
		value: 'text/javascript'
	}]
	log := RequestLog{
		phase:            'response'
		response_headers: headers
		url:              request.url
		blocked:          true
		rule:             '||cdn.test^'
	}
	decision_source := '{"blocked":true,"exception":false,"rule":"||cdn.test^","redirect_url":"","error":""}'
	mut document := platform.new_arena('released first transport caller')
	entry := document.enter()
	first_request := encode_transport_json(request)
	first_headers := encode_transport_json(headers)
	first_log := encode_transport_json(log)
	first_decision := decode_transport_json[Decision](decision_source) or { panic(err) }
	document.leave(entry)
	// Copy the first results out before their owner is released.
	encoded_request := first_request.clone()
	encoded_headers := first_headers.clone()
	encoded_log := first_log.clone()
	first_blocked := first_decision.blocked
	document.release()
	for _ in 0 .. 4 {
		work := platform.begin_thread_scratch('transport table overwrite')
		_ = []u8{len: 256 * 1024, init: u8(0xa5)}
		work.finish()
	}
	assert encode_transport_json(request) == encoded_request
	assert encode_transport_json(headers) == encoded_headers
	assert encode_transport_json(log) == encoded_log
	assert encoded_request.contains('"request_type":"script"')
	assert encoded_headers.contains('"name":"Content-Type"')
	assert encoded_log.contains('"phase":"response"')
	decision := decode_transport_json[Decision](decision_source)!
	assert decision.blocked && decision.rule == '||cdn.test^'
	assert first_blocked
}
