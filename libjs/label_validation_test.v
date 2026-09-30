module libjs

fn test_reserved_words_cannot_be_used_as_labels() {
	for source in ['super: ;', 'true: ;', 'false: ;', 'null: ;', 'enum: ;',
		'\\u0073uper: ;'] {
		mut parser := Parser.new(utf16(source), .script)
		parser.parse_program(false)
		assert parser.has_errors(), source
	}
}

fn test_contextual_words_keep_their_sloppy_label_grammar() {
	for source in ['await: ;', 'yield: ;', 'let: ;', 'async: ;', 'ordinary: ;'] {
		mut parser := Parser.new(utf16(source), .script)
		parser.parse_program(false)
		assert !parser.has_errors(), '${source}: ${parser.errors}'
	}
	for source in ['"use strict"; yield: ;', 'function* f() { yield: ; }',
		'async function f() { await: ; }'] {
		mut parser := Parser.new(utf16(source), .script)
		parser.parse_program(false)
		assert parser.has_errors(), source
	}
}
