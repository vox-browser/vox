module libjs

// LibRegex/Rust/src/vm.rs::{match_simple_with_modifiers,match_simple_match}
// and Vm::match_simple. The three predicates retain their distinct source case
// rules; consuming scans, loop execution and VM dispatch are separate slices.
pub fn regex_match_simple_with_modifiers(matcher RegexSimpleMatch, point u32, modifiers RegexActiveModifiers) bool {
	return match matcher {
		RegexAnyChar {
			matcher.dot_all || modifiers.dot_all || !regex_is_line_terminator(point)
		}
		RegexLiteral {
			if modifiers.ignore_case {
				regex_case_fold_eq(point, matcher.code_point, false)
			} else {
				point == matcher.code_point
			}
		}
		RegexCharNoCase {
			regex_case_fold_eq(point, matcher.first, false)
		}
		RegexBytecodeCharClass {
			regex_match_char_class(point, matcher.ranges, modifiers.ignore_case, false, false) != matcher.negated
		}
		RegexBuiltinCharacterClass {
			regex_match_builtin_class(point, matcher, false)
		}
		RegexUnicodePropertyData {
			regex_match_unicode_property_resolved(point, matcher.name, matcher.value,
				matcher.resolved) != matcher.negated
		}
		RegexSimpleUnion {
			regex_match_simple_with_modifiers(*matcher.left, point, modifiers)
				|| regex_match_simple_with_modifiers(*matcher.right, point, modifiers)
		}
	}
}

pub fn regex_match_simple_match(matcher RegexSimpleMatch, point u32) bool {
	return match matcher {
		RegexAnyChar {
			matcher.dot_all || !regex_is_line_terminator(point)
		}
		RegexLiteral {
			point == matcher.code_point
		}
		RegexCharNoCase {
			point == matcher.first || point == matcher.second
		}
		RegexBytecodeCharClass {
			regex_char_in_ranges(point, matcher.ranges) != matcher.negated
		}
		RegexBuiltinCharacterClass {
			regex_match_builtin_class(point, matcher, false)
		}
		RegexUnicodePropertyData {
			regex_match_unicode_property_resolved(point, matcher.name, matcher.value,
				matcher.resolved) != matcher.negated
		}
		RegexSimpleUnion {
			regex_match_simple_match(*matcher.left, point)
				|| regex_match_simple_match(*matcher.right, point)
		}
	}
}

pub fn (vm RegexVm) match_simple(point u32, matcher RegexSimpleMatch) bool {
	match matcher {
		RegexAnyChar {
			return matcher.dot_all || vm.modifiers.dot_all || !regex_is_line_terminator(point)
		}
		RegexLiteral {
			return if vm.modifiers.ignore_case {
				regex_case_fold_eq(point, matcher.code_point, vm.program.unicode)
			} else {
				point == matcher.code_point
			}
		}
		RegexCharNoCase {
			return regex_case_fold_eq(point, matcher.first, vm.program.unicode)
		}
		RegexBytecodeCharClass {
			return regex_match_char_class(point, matcher.ranges, vm.modifiers.ignore_case,
				vm.program.unicode, vm.program.unicode_sets) != matcher.negated
		}
		RegexBuiltinCharacterClass {
			return regex_match_builtin_class(point, matcher, vm.modifiers.ignore_case
				&& vm.program.unicode)
		}
		RegexUnicodePropertyData {
			if vm.modifiers.ignore_case && vm.program.unicode {
				if matcher.negated && !vm.program.unicode_sets {
					return !regex_match_unicode_property_all_case_equivalents(point, matcher.name,
						matcher.value)
				} else {
					matched := regex_match_unicode_property_case_insensitive(point, matcher.name,
						matcher.value)
					return if matcher.negated {
						!matched
					} else {
						matched
					}
				}
			} else {
				return regex_match_unicode_property_resolved(point, matcher.name, matcher.value,
					matcher.resolved) != matcher.negated
			}
		}
		RegexSimpleUnion {
			return vm.match_simple(point, *matcher.left) || vm.match_simple(point, *matcher.right)
		}
	}
}
