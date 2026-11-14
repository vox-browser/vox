module libjs

fn test_embedding_parser_options_allow_deeper_input_without_changing_the_default() {
	source := '('.repeat(64)+'42'+')'.repeat(64)
	assert parse_source(source, .script).reached_recursion_limit
	parsed := parse_source_with_options(source, .script, ParseOptions{max_recursion_depth: 128})
	assert !parsed.has_errors(), '${parsed.diagnostics}'
	assert !parsed.reached_recursion_limit
	assert !parse_source_with_options('export const value=42;', .module, ParseOptions{max_recursion_depth:128}).has_errors()
	assert parse_source_with_options('('.repeat(40)+'0'+')'.repeat(40), .script, ParseOptions{max_recursion_depth:0}).reached_recursion_limit
}

fn test_embedding_depth_limit_still_stops_hostile_input_and_unwinds_the_parser() {
	for depth in [u32(128), 1024, 0xffffffff] {
		parsed := parse_source_with_options('('.repeat(5000)+'0'+')'.repeat(5000), .script, ParseOptions{max_recursion_depth:depth})
		assert parsed.reached_recursion_limit
		assert parsed.has_errors()
	}
	mut parser := Parser.new(utf16('1'), .script)
	parser.recursion_limit=128
	// Exercise the reserve check independently from the configurable depth.
	parser.stack_info=StackInfo{base:C.vox_ak_current_frame_address()-256*1024, size:512*1024}
	parser.parse_program(false)
	assert parser.recursion_limit_reached
	assert parser.recursion_depth == 0
}
