module libjs

// Runtime/RegExpObject.h::Flags. Preserve its bit order, including v before u.
@[flag]
pub enum RegExpFlags {
	has_indices
	global
	ignore_case
	multiline
	dot_all
	unicode_sets
	unicode
	sticky
}

pub struct RegExpFlagError {
	Error
pub:
	message Utf16String
}

pub fn (err RegExpFlagError) msg() string {
	return err.message.str()
}

fn regexp_flag_for_code_unit(unit u16) ?RegExpFlags {
	return match rune(unit) {
		`d` { RegExpFlags.has_indices }
		`g` { RegExpFlags.global }
		`i` { RegExpFlags.ignore_case }
		`m` { RegExpFlags.multiline }
		`s` { RegExpFlags.dot_all }
		`v` { RegExpFlags.unicode_sets }
		`u` { RegExpFlags.unicode }
		`y` { RegExpFlags.sticky }
		else { none }
	}
}

// AK's char16_t formatter passes its WTF-8 code point through
// Utf16String::from_utf8_without_validation, preserving lone surrogates too.
fn regexp_flag_error(kind ErrorType, unit u16) RegExpFlagError {
	mut message := utf16(kind.formatted(''))
	// Both source templates end in '{}': insert the unit between the quotes.
	message.insert(message.len - 1, unit)
	return RegExpFlagError{
		message: Utf16String{
			data: message
		}
	}
}

// Runtime/RegExpObject.cpp::validate_flags. Repetition/bad-character errors
// win before the final incompatible-u/v check, in source order.
pub fn validate_regexp_flags(flags Utf16String) !RegExpFlags {
	mut seen := [128]bool{}
	mut bits := unsafe { RegExpFlags(0) }
	for unit in flags.data {
		flag := regexp_flag_for_code_unit(unit) or {
			return regexp_flag_error(.reg_exp_object_bad_flag, unit)
		}
		if seen[int(unit)] { return regexp_flag_error(.reg_exp_object_repeated_flag, unit) }
		seen[int(unit)] = true
		bits |= flag
	}
	if bits.has(.unicode) && bits.has(.unicode_sets) {
		return RegExpFlagError{
			message: utf16_string(ErrorType.reg_exp_object_incompatible_flags.formatted('u', 'v'))
		}
	}
	return bits
}

// The constructor's to_flag_bits is intentionally permissive: validation is
// a separate initialization step. Unknown characters and repeats are ignored.
pub fn regexp_to_flag_bits(flags Utf16String) RegExpFlags {
	mut bits := unsafe { RegExpFlags(0) }
	for unit in flags.data {
		if flag := regexp_flag_for_code_unit(unit) { bits |= flag }
	}
	return bits
}

pub fn validate_regexp_flags_with_vm(mut vm VM, flags Utf16String) !RegExpFlags {
	return validate_regexp_flags(flags) or {
		if err is RegExpFlagError { return vm.throw_error_utf16(.syntax_error, err.message) }
		panic(err)
	}
}
