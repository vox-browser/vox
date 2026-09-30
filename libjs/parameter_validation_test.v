module libjs

fn parse_parameter_test_script(source string) (Statement, Parser) {
	mut parser := Parser.new(utf16(source), .script)
	program := parser.parse_program(false)
	parser.scope_collector.analyze(false)
	return program, parser
}

fn test_duplicate_parameters_use_the_complete_parameter_list() {
	for source in [
		'function f(a, a, ...rest) {}',
		'function f(a, a, b = 1) {}',
		'function f(a, a, {b}) {}',
		'function f({a}, a) {}',
		'function f({a}, {a}) {}',
	] {
		_, parser := parse_parameter_test_script(source)
		assert parser.errors.any(it.message.contains('Duplicate parameter')), source
	}
	_, parser := parse_parameter_test_script('function f(a, a) {}')
	assert !parser.has_errors(), '${parser.errors}'
}

fn test_object_methods_require_unique_formal_parameters() {
	for source in [
		'({method(a, a) {}});',
		'({*method(a, a) {}});',
		'({async method(a, a) {}});',
		'({method({a}, a) {}});',
	] {
		_, parser := parse_parameter_test_script(source)
		assert parser.errors.any(it.message.contains('Duplicate parameter')), source
	}
	_, parser := parse_parameter_test_script('({method(a, b) {}, set value(v) {}, get value() {}});')
	assert !parser.has_errors(), '${parser.errors}'
}

fn test_strict_destructured_parameter_names_are_checked_without_a_body_directive() {
	for source in [
		'"use strict"; function f({eval}) {}',
		'"use strict"; function f([arguments]) {}',
		'"use strict"; (function({x: eval}) {});',
		'"use strict"; ({method({arguments}) {}});',
		'class C { method({eval}) {} }',
		'class C { constructor([arguments]) {} }',
	] {
		_, parser := parse_parameter_test_script(source)
		assert parser.errors.any(it.message.contains("'arguments' or 'eval'")), source
	}
	for source in ['function f({eval}) {}', 'function f([arguments]) {}',
		'({method({eval}) {}});', '"use strict"; function f({x: valid}) {}'] {
		_, parser := parse_parameter_test_script(source)
		assert !parser.has_errors(), '${source}: ${parser.errors}'
	}
}
