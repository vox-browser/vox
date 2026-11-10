// Copyright (c) 2026-present, the Ladybird developers.
//
// SPDX-License-Identifier: BSD-2-Clause

module libjs

// Ladybird 159e288ee23a9575252a16e0102c0ffaef3ff17c: `var arguments` in a
// non-arrow function names that function's arguments object, not a shadow.
// Function execution is not translated yet, so verify the frontend metadata
// that keeps mapped parameters in the function environment.
fn arguments_scope_function(source string, name string) &JsFunctionData {
	parsed := parse_source(source, .script)
	assert !parsed.has_errors(), '${parsed.diagnostics}'
	for entry in parsed.function_table.entries {
		if function := entry {
			if identifier := function.name {
				if identifier.name.str() == name { return function }
			}
		}
	}
	panic('missing function ${name}')
}

fn assert_arguments_parameter_mapping(function &JsFunctionData, mapped bool) {
	scope := function.body.kind.scope or { panic('missing function scope') }
	assert scope.contains_access_to_arguments_object == mapped
	binding := function.parameters[0].binding
	assert binding is IdentifierBinding
	if binding is IdentifierBinding {
		assert binding.identifier.is_local() == !mapped
	}
}

fn test_var_arguments_before_first_use_keeps_parameters_mapped() {
	for body in [
		'var arguments; arguments[0] = 2; return a;',
		'var arguments; a = 3; return arguments[0];',
		'{ var arguments; } arguments[0] = 4; return a;',
		'{ var arguments; arguments[0] = 4; } return a;',
		'var arguments; var arguments; return arguments[0] + a;',
	] {
		function := arguments_scope_function('function f(a) { ${body} }', 'f')
		assert_arguments_parameter_mapping(function, true)
	}
}

fn test_var_arguments_mapping_is_local_to_each_non_arrow_function() {
	for source in [
		'function outer() { var a = "outer"; function f(a) { var arguments; arguments[0] = "inner"; return a; } return f(1); }',
		'function outer() { var unrelated = 1; function f(a) { var arguments; return arguments[0]; } return f(1); }',
		'function* f(a) { var arguments; arguments[0] = 7; yield a; }',
		'async function f(a) { var arguments; arguments[0] = 8; return a; }',
	] {
		function := arguments_scope_function(source, 'f')
		assert_arguments_parameter_mapping(function, true)
	}
	parsed := parse_source('const object = { method(a) { var arguments; arguments[0] = 6; return a; } };', .script)
	assert !parsed.has_errors(), '${parsed.diagnostics}'
	assert parsed.function_table.entries.len == 1
	method := parsed.function_table.entries[0] or { panic('missing method') }
	assert_arguments_parameter_mapping(method, true)
}

fn test_arguments_declarations_that_shadow_the_object_keep_parameters_local() {
	for body in [
		'let arguments = []; return arguments[0] + a;',
		'const arguments = []; return arguments[0] + a;',
		'function arguments() {} return arguments + a;',
		'function* arguments() {} return arguments + a;',
		'async function arguments() {} return arguments + a;',
		'function arguments() {} var arguments; return arguments + a;',
		'{ function arguments() {} return arguments + a; }',
	] {
		function := arguments_scope_function('function f(a) { ${body} }', 'f')
		assert_arguments_parameter_mapping(function, false)
	}
	function := arguments_scope_function('function f(arguments, a) { return arguments[0] + a; }', 'f')
	assert_arguments_parameter_mapping(function, false)
}

fn test_arrow_var_arguments_does_not_use_the_enclosing_arguments_object() {
	function := arguments_scope_function('function f(a) { return (() => { var arguments; return typeof arguments; })() + a; }', 'f')
	assert_arguments_parameter_mapping(function, false)
	parsed := parse_source('const arrow = (a) => { var arguments; return arguments + a; };', .script)
	assert !parsed.has_errors(), '${parsed.diagnostics}'
	assert parsed.function_table.entries.len == 1
	arrow := parsed.function_table.entries[0] or { panic('missing arrow') }
	assert arrow.is_arrow_function
	assert_arguments_parameter_mapping(arrow, false)
}
