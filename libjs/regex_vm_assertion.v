module libjs

// LibRegex/Rust/src/vm.rs::Vm::{fail_current_path,handle_assert_start,
// handle_assert_end,handle_word_boundary_assert}. None means execution can
// continue, including when a failed assertion resumes a saved alternative.
pub fn (mut vm RegexVm) fail_current_path() ?RegexVmResult {
	if vm.backtrack() { return none }
	return .no_match
}

pub fn (mut vm RegexVm) handle_assert_start(multiline_flag bool) ?RegexVmResult {
	multiline := multiline_flag || vm.modifiers.multiline
	at_start := vm.pos == 0 || (multiline && vm.pos > 0
		&& regex_is_line_terminator(u32(vm.input_code_unit(vm.pos - 1))))
	if at_start {
		vm.pc++
		return none
	}
	return vm.fail_current_path()
}

pub fn (mut vm RegexVm) handle_assert_end(multiline_flag bool, input_len uint) ?RegexVmResult {
	multiline := multiline_flag || vm.modifiers.multiline
	at_end := vm.pos >= input_len || (multiline
		&& regex_is_line_terminator(u32(vm.input_code_unit(vm.pos))))
	if at_end {
		vm.pc++
		return none
	}
	return vm.fail_current_path()
}

pub fn (mut vm RegexVm) handle_word_boundary_assert(should_match_boundary bool) ?RegexVmResult {
	if vm.at_word_boundary() == should_match_boundary {
		vm.pc++
		return none
	}
	return vm.fail_current_path()
}
