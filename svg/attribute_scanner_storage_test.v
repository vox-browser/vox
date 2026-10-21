module svg

import platform

fn test_attribute_numeric_scanning_has_no_per_coordinate_workspace_allocations() {
	mut parser := AttributeParser.from_string('12.5 '.repeat(4096))
	before := platform.thread_arena_usage().used
	mut sum := f64(0)
	for _ in 0 .. 4096 {
		sum += parser.parse_number() or { panic('missing coordinate') }
		parser.parse_whitespace()
	}
	after := platform.thread_arena_usage().used
	assert sum == 51200
	assert parser.done()
	$if prealloc { assert after - before < 1024 }
}

fn test_attribute_parser_copies_keep_independent_numeric_cursors_and_recovery() {
	mut original := AttributeParser.from_string('1.5 2e+ 3 -17')
	assert original.parse_number()? == 1.5
	original.parse_whitespace()
	mut copied := original
	assert original.parse_number()? == 2
	assert copied.parse_number()? == 2
	assert original.ch() == `e` && copied.ch() == `e`
	original.consume()
	assert original.parse_number() == none
	assert copied.ch() == `e`
	mut integers := AttributeParser.from_string('-17 +42')
	assert integers.parse_integer()? == -17
	integers.parse_whitespace()
	assert integers.parse_integer()? == 42
}
