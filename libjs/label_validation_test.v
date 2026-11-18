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

fn test_label_lookahead_preserves_expression_statements_and_trivia() {
	parsed := parse_source('read()\nouter /* label */\n: while (ready()) { continue outer; }\nwritten = 1;',
		.script)
	assert !parsed.has_errors(), '${parsed.diagnostics}'
	program := parsed.program.kind.program_data or { panic('Missing program') }
	assert program.scope.children.len == 3
	assert program.scope.children[0].kind.tag == .expression_stmt
	labelled := program.scope.children[1]
	assert labelled.kind.tag == .labelled
	assert labelled.kind.label.str() == 'outer'
	assert program.scope.children[2].kind.tag == .expression_stmt
}
