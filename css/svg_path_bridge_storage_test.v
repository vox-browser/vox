module css

import platform

fn test_svg_path_bridge_retires_serialization_buffers_and_owns_its_css_text() {
	value := svg_presentation_path_value('M0 0 ' + 'c1.25 2.5 -3.75 4.125 5.5 6.25 '.repeat(2048)) or { panic('missing path') }
	expected := value.serialize(.normal)
	before := platform.thread_arena_usage().used
	bridge := dom_style_value_from_value_logic(value)
	after := platform.thread_arena_usage().used
	$if prealloc { assert after - before < bridge.css_text.len + 4096 }
	mut reuse := platform.begin_thread_scratch('reuse path bridge serialization')
	_ = []u8{len: expected.len * 4, init: 0xa5}
	reuse.finish()
	assert bridge.css_text == expected
	assert typed_style_value_logic_from_dom(bridge)?.serialize(.normal) == expected
}
