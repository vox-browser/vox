module libjs

fn test_regexp_pattern_preparation_preserves_ascii_and_normalizes_utf16_by_mode() {
	pattern := Utf16String.from_slice([u16(0), 0x7f, 0x80, 0xe9, 0xd800, 0xdc00, 0xdbff, 0x61,
		0xdfff])
	mut prefix := [u16(0), 0x7f]
	legacy := parse_regex_pattern(pattern, false, false)!
	mut legacy_expected := prefix.clone()
	legacy_expected << utf16('\\u0080\\u00e9\\ud800\\udc00\\udbffa\\udfff')
	assert legacy.data == legacy_expected
	prefix << utf16('\\u{0080}\\u{00e9}\\u{10000}\\u{dbff}a\\u{dfff}')
	assert parse_regex_pattern(pattern, true, false)!.data == prefix
	assert parse_regex_pattern(pattern, false, true)!.data == prefix
	for slashes in 0 .. 6 {
		input := utf16_string('\\'.repeat(slashes) + 'é😀')
		retained := '\\'.repeat(if slashes % 2 == 1 { slashes - 1 } else { slashes })
		assert parse_regex_pattern(input, false, false)!.str() == retained + '\\u00e9\\ud83d\\ude00'
		assert parse_regex_pattern(input, true, false)!.str() == retained + '\\u{00e9}\\u{1f600}'
	}
	// These helpers do not replace the pending regex grammar compiler.
	for ascii in ['', '(?<', '(?<>)', '(?<1>)', '[', '(', '\\', '\\u{}'] {
		assert parse_regex_pattern(utf16_string(ascii), false, false)!.str() == ascii
	}
}

fn test_regexp_group_names_pair_only_compatible_surrogate_origins() {
	high := [Utf16String.from_slice([u16(0xd800)]), utf16_string('\\uD800'),
		utf16_string('\\u{D800}')]
	low := [Utf16String.from_slice([u16(0xdc00)]), utf16_string('\\uDC00'),
		utf16_string('\\u{DC00}')]
	for high_index, first in high {
		for low_index, second in low {
			mut units := utf16('(?<')
			units << first.data
			units << second.data
			units << utf16('>a)')
			pattern := Utf16String.from_slice(units)
			for mode in 0 .. 3 {
				if _ := parse_regex_pattern(pattern, mode == 1, mode == 2) {
					assert high_index == low_index && high_index != 2
				} else {
					assert high_index != low_index || high_index == 2
					assert err is ParseRegexPatternError && err.msg() == 'invalid group name'
				}
			}
		}
	}
	for name in ['\\u{10000}', '\\u{10FFFF}', '\\u{00000000000000000061}', '\\u0061b'] {
		assert parse_regex_pattern(utf16_string('(?<${name}>a)'), true, false)!.str() == '(?<${name}>a)'
	}
	for name in ['\\uD800', '\\uDC00', '\\u{d800}', '\\u{dc00}', '\\u{}', '\\u{110000}',
		'\\u{ffffffff}', '\\u{xyz}', '\\u{123', '\\u123', '\\u123g', '\\x61', '\\', 'a'] {
		// The last entry checks a missing closing angle bracket rather than ID syntax.
		pattern := if name == 'a' { '(?<a' } else { '(?<${name}>a)' }
		if _ := parse_regex_pattern(utf16_string(pattern), false, false) {
			assert false
		} else {
			assert err.msg() == 'invalid group name'
		}
	}
}

fn test_regexp_named_backreferences_follow_class_escape_lookbehind_and_unicode_scans() {
	bad := '\\k<\\uDC00>'
	assert parse_regex_pattern(utf16_string(bad), false, false)!.str() == bad
	for pattern in [bad, bad + '(?<a>a)', '(?<a>a)' + bad] {
		for mode in 0 .. 3 {
			if _ := parse_regex_pattern(utf16_string(pattern), mode == 1, mode == 2) {
				assert pattern == bad && mode == 0
			} else {
				assert err.msg() == 'invalid group name'
			}
		}
	}
	for pattern in ['[' + bad + ']', '[\\](?<\\uDC00>)]', '\\(?<\\uDC00>)', '(?<=a)' + bad,
		'(?<!a)' + bad, '[(?<a>)]' + bad, '\\(?<a>)' + bad] {
		assert parse_regex_pattern(utf16_string(pattern), false, false)!.str() == pattern
	}
	assert parse_regex_pattern(utf16_string('[' + bad + ']'), true, false)!.str() == '[' + bad + ']'
	// Truncated (?< counts as a named capture in the discovery scan, so even
	// an earlier backreference is checked, although (?< itself is left to grammar.
	if _ := parse_regex_pattern(utf16_string(bad + '(?<'), false, false) {
		assert false
	} else {
		assert err.msg() == 'invalid group name'
	}
	if _ := parse_regex_pattern(utf16_string('(?<\\uDC00>a)'), true, true) {
		assert false
	} else {
		assert err.msg() == "RegExp flag 'u' is incompatible with flag 'v'"
	}
}

fn test_regexp_pattern_vm_boundary_keeps_the_unprefixed_syntax_error() {
	mut vm := VM.create()
	base := create_simple_execution_context(mut vm)
	function := NativeFunction.create(mut vm, vm.realm(), vm.realm().function_prototype, fn (mut vm VM) !Value {
		pattern := vm.argument(0).to_primitive_string(mut vm)!.utf16
		result := parse_regex_pattern_with_vm(mut vm, pattern, true, false)!
		return Value.from_string(vm.create_string(result))
	}, 1, PropertyName.from_str('prepare'), none)
	if _ := call(mut vm, Value.from_object(function.object), js_undefined(), [
		Value.from_string(vm.create_string_from_str('(?<\\uDC00>a)')),
	])
	{
		assert false
	} else {
		thrown := thrown_value(err).as_object()
		assert thrown.error_kind()? == .syntax_error
		message := thrown.get(mut vm, PropertyName.from_str('message'))!
		assert message.as_string().utf16.str() == 'invalid group name'
	}
	assert vm.running_execution_context() == base && vm.interpreter_stack().depth() == 0
}
