// SPDX-License-Identifier: BSD-2-Clause
module libjs

fn test_fixed_ascii_spelling_comparison_preserves_exact_units_and_boundaries() {
	for spelling in ['', 'arguments', 'eval', 'await', 'async', 'yield', '#constructor', 'use strict', '\x00x'] {
		units := utf16(spelling)
		assert utf16_equals_ascii(units, spelling)
		assert !utf16_equals_ascii(units, spelling+'x')
		if units.len > 0 {
			mut changed := units.clone()
			changed[changed.len-1] = 0xd800
			assert !utf16_equals_ascii(changed, spelling)
		}
	}
	assert !utf16_equals_ascii([u16(0xc3), 0xa9], 'é')
	assert !utf16_equals_ascii(utf16('аrguments'), 'arguments') // Cyrillic first letter.
}

fn test_escaped_ascii_identifiers_still_mark_the_implicit_arguments_object() {
	parsed := parse_source('function f(a){return \\u0061rguments[0]}', .script)
	assert !parsed.has_errors()
	function := parsed.function_table.entries[0] or { panic('Missing function') }
	assert function.body.kind.scope?.contains_access_to_arguments_object
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	mut script := Script.parse('function f(a){return \\u0061rguments[0]};f(42)', vm.realm(), 'ascii-identifiers.js', unsafe { nil })!
	assert vm.run(mut script)!.number == 42
}
