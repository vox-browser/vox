module css

import dom
import platform

fn test_raw_svg_presentation_path_matches_css_string_round_trip() {
	mut document := dom.Document.create(dom.url_about_blank())
	defer { document.finalize() }
	for source in ['', 'none', 'M0 0', 'M1 2L3 4z', 'm1,2 c3 4 5 6 7 8',
		'M1 2 A3 4 5 0 1 6 7', 'M1 2 L3', 'M1 2 garbage', 'M1 2"L3 4',
		'M1 2\\L3 4', 'M1 2\u0000L3 4', 'M1 2\r\nL3\t4', 'M1 2😀L3 4',
		'M1e2 -.5 L.25 4e-2', 'Z', 'M1 2 A-1 2 0 0 1 3 4'] {
		mut parser := Parser.with_context(ParsingParams{
			document: document
			mode: .svg_presentation_attribute
		}, 'path(${serialize_a_string(source)})')
		expected := parser.parse_css_value(.d)
		actual := parse_svg_presentation_attribute_value(document, .d, source)
		if reference := expected {
			value := actual or { panic('lost path: ${source}') }
			assert value.serialize(.normal) == reference.serialize(.normal)
		} else { assert actual == none }
	}
}

fn test_presentation_path_retires_parse_and_formatting_workspace() {
	source := 'M0 0 ' + 'c1.25 2.5 -3.75 4.125 5.5 6.25 '.repeat(2048)
	before := platform.thread_arena_usage().used
	value := svg_presentation_path_value(source) or { panic('missing path') }
	after := platform.thread_arena_usage().used
	assert value is BasicShapeStyleValue
	shape := value.basic_shape()
	assert shape is BasicShapePath
	$if prealloc { assert after - before < shape.path_instructions.len + 2048 }
	mut reuse := platform.begin_thread_scratch('reuse presentation workspace')
	_ = []u8{len: source.len * 8, init: 0xa5}
	reuse.finish()
	assert shape.path_instructions.starts_with('M 0 0 c 1.25')
	assert shape.path_instructions.ends_with('5.5 6.25')
}
