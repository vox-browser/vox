module libjs

fn test_outer_octal_string_does_not_leak_into_nested_strict_directive_prologue() {
	for source in ['function outer() { 0; "\\1"; function inner() { "use strict"; } }',
		'function outer() { 0; "\\1"; const inner = () => { "use strict"; }; }'] {
		mut parser := Parser.new(utf16(source), .script)
		parser.parse_program(false)
		assert !parser.has_errors(), '${parser.errors}'
	}
}

fn test_octal_strings_in_the_same_strict_directive_prologue_remain_errors() {
	for source in ['"\\1"; "use strict";',
		'function f() { "\\1"; "use strict"; }',
		'function outer() { 0; "\\1"; function inner() { "\\2"; "use strict"; } }'] {
		mut parser := Parser.new(utf16(source), .script)
		parser.parse_program(false)
		assert parser.errors.any(it.message.contains('Octal escape sequence')), source
	}
}
