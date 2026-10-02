module libjs

// LibRegex/Rust/src/vm.rs::{match_char,at_word_boundary}.
pub fn (mut vm RegexVm) match_char(target u32) bool {
	if point := vm.current_code_point() {
		matches := if vm.modifiers.ignore_case {
			regex_case_fold_eq(point, target, vm.program.unicode)
		} else {
			point == target
		}
		if matches {
			vm.advance_char()
			return true
		}
	}
	return false
}

pub fn (vm RegexVm) at_word_boundary() bool {
	unicode_ignore_case := vm.modifiers.ignore_case && vm.program.unicode
	before := if vm.pos > 0 {
		regex_is_word_char_unicode(u32(vm.input_code_unit(vm.pos - 1)), unicode_ignore_case)
	} else {
		false
	}
	after := if vm.pos < vm.input_len() {
		regex_is_word_char_unicode(u32(vm.input_code_unit(vm.pos)), unicode_ignore_case)
	} else {
		false
	}
	return before != after
}
