module webdriver

import x.json2

fn echo_executor(_ string, arguments []json2.Any, _ bool) !json2.Any {
	return arguments[0]
}

fn failing_executor(_ string, _ []json2.Any, _ bool) !json2.Any {
	return error('boom')
}

fn fake_png(image FramebufferImage) ![]u8 {
	return [u8(image.width), u8(image.height)]
}

fn test_route_matching_extracts_ordered_parameters() {
	matched := match_route(.get, '/session/abc/element/def/attribute/title') or { panic(err) }
	assert matched.command == 'get_element_attribute'
	assert matched.parameters == ['abc', 'def', 'title']
	match_route(.get, '/not-an-endpoint') or {
		assert err.msg().contains('unknown command')
		return
	}
	assert false
}

fn test_script_clone_timer_and_screenshot_boundaries() {
	result := execute_script('return arguments[0]', [json2.Any('value')], echo_executor)
	assert result.state == .fulfilled
	assert result.value as string == 'value'
	assert execute_async_script('', [], failing_executor).state == .rejected
	mut timer := HeapTimer{}
	timer.start(10)
	assert !timer.tick(9)
	assert timer.tick(1)
	frame := FramebufferImage{
		width: 2
		height: 2
		rgba: [u8(1), 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16]
	}
	crop := draw_bounding_box_from_framebuffer(frame, Rect{ x: 1, width: 1, height: 2 }) or {
		panic(err)
	}
	assert crop.rgba == [u8(5), 6, 7, 8, 13, 14, 15, 16]
	assert !encode_canvas_element(crop, fake_png).is_error()
}

fn test_screenshot_paints_from_origin_to_viewport_edge_and_rejects_empty_canvas() {
	frame := FramebufferImage{
		width: 3
		height: 1
		rgba: [u8(1), 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12]
	}
	crop := draw_bounding_box_from_framebuffer(frame, Rect{ x: 1, width: 1, height: 1 }) or {
		panic(err)
	}
	assert crop.width == 2
	assert crop.rgba == [u8(5), 6, 7, 8, 9, 10, 11, 12]
	empty := FramebufferImage{}
	assert encode_canvas_element(empty, fake_png).is_error()
}

fn test_upstream_client_entry_points_parse_route_and_frame_response() {
	mut client := Client.new()
	client.on_ready_to_read('GET /status HTTP/1.1\r\nHost: localhost\r\nConnection: keep-alive\r\n\r\nGET /status HTTP/1.1\r\nHost: localhost\r\nConnection: keep-alive\r\n\r\n')!
	assert client.responses.len == 2
	assert client.responses[0].status == 200
	assert client.responses[0].raw.starts_with('HTTP/1.1 200 OK')
	assert client.responses[0].raw.contains('Connection: keep-alive')
	assert client.response_log.last().contains('GET /status')
	assert client.alive
	assert client.pending_requests.len == 0
	client.on_ready_to_read('GET /status HTTP/1.1\r\nHost: localhost\r\n\r\n')!
	assert client.responses.len == 3
	assert !client.alive
}

fn test_keep_alive_request_is_ascii_case_insensitive_and_trimmed() {
	assert is_keep_alive_request({
		'cOnNeCtIoN': '  Keep-Alive  '
	})
	assert !is_keep_alive_request({
		'Connection': 'close'
	})
}

fn test_upstream_script_completion_helpers_observe_timeout() {
	result := execute_a_function_body('return arguments[0]', [json2.Any('ok')], echo_executor)
	assert promise_call(result).state == .fulfilled
	mut timer := HeapTimer{}
	timer.start(10)
	assert fire_completion_when_resolved(result, mut timer).state == .fulfilled
	assert !timer.running
	mut expired := HeapTimer{}
	expired.start(1)
	expired.tick(1)
	assert fire_completion_when_resolved(result, mut expired).state == .pending
}

fn test_heap_timer_timed_out_flag_matches_upstream_lifecycle() {
	mut manually_fired := HeapTimer{}
	manually_fired.start(10)
	assert manually_fired.stop_and_fire_timeout_handler()
	assert !manually_fired.is_timed_out()

	mut expired := HeapTimer{}
	expired.start(1)
	assert expired.tick(1)
	assert expired.is_timed_out()
	expired.start(100)
	assert expired.is_timed_out()
}
