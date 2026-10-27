module libjs

// LibRegex/Rust/src/vm.rs::Vm::greedy_consume_fast, for forward legacy mode.
// The updated reference position is returned beside the consumed count because
// V does not accept a mutable uint function argument. The source caller keeps
// start <= input.len(), including for the dot-all subtraction shortcut.
pub fn regex_greedy_consume_fast(input RegexInput, start uint, matcher RegexSimpleMatch, modifiers RegexActiveModifiers, maximum ?u32) (u32, uint) {
	mut pos := start
	mut count := u32(0)
	limit := maximum or { u32(0xffffffff) }
	length := input.len()
	match matcher {
		RegexAnyChar {
			if matcher.dot_all || modifiers.dot_all {
				remaining := length - pos
				advance := if remaining < uint(limit) { remaining } else { uint(limit) }
				pos += advance
				count = u32(advance)
			} else {
				for pos < length && count < limit {
					if regex_is_line_terminator(u32(input.code_unit(pos))) {
						break
					}
					pos++
					count++
				}
			}
		}
		RegexLiteral {
			// The native fast loop narrows Char to a code unit before comparison.
			target := u16(matcher.code_point)
			if modifiers.ignore_case {
				for pos < length && count < limit {
					if !regex_case_fold_eq(u32(input.code_unit(pos)), u32(target), false) {
						break
					}
					pos++
					count++
				}
			} else {
				for pos < length && count < limit {
					if input.code_unit(pos) != target {
						break
					}
					pos++
					count++
				}
			}
		}
		RegexCharNoCase {
			for pos < length && count < limit {
				if !regex_case_fold_eq(u32(input.code_unit(pos)), matcher.first, false) {
					break
				}
				pos++
				count++
			}
		}
		RegexBytecodeCharClass {
			if modifiers.ignore_case {
				for pos < length && count < limit {
					matched := regex_match_char_class(u32(input.code_unit(pos)), matcher.ranges,
						true, false, false)
					if matched == matcher.negated {
						break
					}
					pos++
					count++
				}
			} else {
				for pos < length && count < limit {
					matched := regex_char_in_ranges(u32(input.code_unit(pos)), matcher.ranges)
					if matched == matcher.negated {
						break
					}
					pos++
					count++
				}
			}
		}
		RegexBuiltinCharacterClass {
			for pos < length && count < limit {
				if !regex_match_builtin_class(u32(input.code_unit(pos)), matcher, false) {
					break
				}
				pos++
				count++
			}
		}
		RegexUnicodePropertyData {
			for pos < length && count < limit {
				point := u32(input.code_unit(pos))
				matched := regex_match_unicode_property_resolved(point, matcher.name,
					matcher.value, matcher.resolved)
				if matched == matcher.negated {
					break
				}
				pos++
				count++
			}
		}
		RegexSimpleUnion {
			for pos < length && count < limit {
				point := u32(input.code_unit(pos))
				if !regex_match_simple_with_modifiers(*matcher.left, point, modifiers)
					&& !regex_match_simple_with_modifiers(*matcher.right, point, modifiers) {
					break
				}
				pos++
				count++
			}
		}
	}

	return count, pos
}
