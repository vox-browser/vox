module libregex

import libjs

fn test_compiled_owner_moves_and_destroyed_wrappers_cannot_execute_old_state() {
	mut first := CompiledRegex.compile(libjs.utf16_string('(a)'), ECMAScriptCompileFlags{})!
	mut second := CompiledRegex.compile(libjs.utf16_string('b'), ECMAScriptCompileFlags{})!
	second.move_from(mut first)
	assert first.test(libjs.utf16_string('a'), 0) == 0
	assert second.exec_internal(libjs.utf16_string('a'), 0) == 1
	assert second.capture_count() == 1 && second.capture_slot(2) == 0
	second.move_from(mut second)
	assert second.test(libjs.utf16_string('a'), 0) == 1
	second.destroy()
	second.destroy()
	first.destroy()
	assert second.test(libjs.utf16_string('a'), 0) == 0
}

fn test_utf16_pattern_boundary_replaces_lone_source_surrogates_but_preserves_escaped_units() {
	pattern := libjs.utf16_string_from_code_units([u16(0xd800)])
	mut replaced := CompiledRegex.compile(pattern, ECMAScriptCompileFlags{ unicode: true })!
	defer { replaced.destroy() }
	assert replaced.test(libjs.utf16_string('�'), 0) == 1
	assert replaced.test(pattern, 0) == 0
	mut escaped := CompiledRegex.compile(libjs.utf16_string(r'\uD800'), ECMAScriptCompileFlags{ unicode: true })!
	defer { escaped.destroy() }
	assert escaped.test(pattern, 0) == 1
}

fn compiled_regex_compile_error(pattern libjs.Utf16String) string {
	if mut compiled := CompiledRegex.compile(pattern, ECMAScriptCompileFlags{ unicode: true }) {
		compiled.destroy()
		assert false, 'invalid pattern unexpectedly compiled'
		return ''
	} else {
		return err.msg()
	}
}

fn test_compile_error_strings_remain_owned_across_compiles() {
	ascii := libjs.utf16_string('[z-a]')
	utf16 := libjs.utf16_string('[é-a]')
	assert ascii.has_ascii_storage()
	assert !utf16.has_ascii_storage()
	// Keep earlier messages alive across later parser errors and allocations.
	mut messages := []string{}
	for _ in 0 .. 32 {
		messages << compiled_regex_compile_error(ascii)
		messages << compiled_regex_compile_error(utf16)
	}
	for index, message in messages {
		expected := if index % 2 == 0 {
			"invalid character range 'z'-'a'"
		} else {
			"invalid character range 'é'-'a'"
		}
		assert message == expected
	}
}
