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
		width:  2
		height: 2
		rgba:   [u8(1), 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16]
	}
	crop := draw_bounding_box_from_framebuffer(frame, Rect{ x: 1, width: 1, height: 2 }) or {
		panic(err)
	}
	assert crop.rgba == [u8(5), 6, 7, 8, 13, 14, 15, 16]
	assert !encode_canvas_element(crop, fake_png).is_error()
}

fn test_screenshot_paints_from_origin_to_viewport_edge_and_rejects_empty_canvas() {
	frame := FramebufferImage{
		width:  3
		height: 1
		rgba:   [u8(1), 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12]
	}
	crop := draw_bounding_box_from_framebuffer(frame, Rect{ x: 1, width: 1, height: 1 }) or {
		panic(err)
	}
	assert crop.width == 2
	assert crop.rgba == [u8(5), 6, 7, 8, 9, 10, 11, 12]
	empty := FramebufferImage{}
	assert encode_canvas_element(empty, fake_png).is_error()
}
