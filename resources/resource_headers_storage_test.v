module main

import platform

fn test_cached_response_headers_own_names_and_values_after_input_retirement() {
	input := platform.begin_thread_scratch('cached header input')
	encoded := '[{"name":"x-名前","value":"quote\\\" 中😀"},{"name":"set-cookie","value":"a=1"},{"name":"set-cookie","value":"b=2"}]'.clone()
	input.leave()
	headers := decode_browser_cached_response_headers(encoded)!
	input.finish()
	assert headers.len == 3
	assert headers[0].name == 'x-名前'
	assert headers[0].value == 'quote" 中😀'
	assert headers[1].name == 'set-cookie' && headers[1].value == 'a=1'
	assert headers[2].name == 'set-cookie' && headers[2].value == 'b=2'
}

fn test_cached_response_header_json_work_does_not_accumulate_in_the_caller() {
	encoded := '[{"ignored":"' + '\\u0078'.repeat(16384) + '","name":"x-header","value":"kept"}]'
	// Warm reusable native scratch descriptors before measuring caller storage.
	assert decode_browser_cached_response_headers('[]')!.len == 0
	before := platform.thread_arena_usage().used
	headers := decode_browser_cached_response_headers(encoded)!
	$if prealloc { assert platform.thread_arena_usage().used - before < 4096 }
	assert headers.len == 1 && headers[0].name == 'x-header' && headers[0].value == 'kept'
}

fn test_cached_response_header_error_survives_decoder_and_input_retirement() {
	input := platform.begin_thread_scratch('invalid cached header input')
	encoded := '[{"name":"header","value":123}]'.clone()
	input.leave()
	mut message := ''
	if _ := decode_browser_cached_response_headers(encoded) {
		assert false
	} else {
		message = err.msg()
	}
	input.finish()
	assert message == 'cached response header fields are not strings'
}
