module libjs

// LibRegex/Rust/src/vm.rs::Vm::{count_available_same_matcher_chars,
// same_matcher_loop_suffix_deficit}. Measurement uses its supplied direction,
// independently of the VM's current direction, without moving VM state.
pub fn (vm RegexVm) count_available_same_matcher_chars(start uint, matcher RegexSimpleMatch, maximum u32, backward bool) u32 {
	mut pos := start
	mut count := u32(0)
	for count < maximum {
		mut point := u32(0)
		if backward {
			next := vm.retreat_one_char(pos)
			if next == pos {
				break
			}
			pos = next
			point = regex_decode_code_point(vm.program.unicode, vm.input, pos)
		} else {
			if pos >= vm.input_len() {
				break
			}
			point = regex_decode_code_point(vm.program.unicode, vm.input, pos)
			pos = vm.advance_one_char(pos)
		}
		if !vm.match_simple(point, matcher) {
			break
		}
		count++
	}
	return count
}

pub fn (vm RegexVm) same_matcher_loop_suffix_deficit(pc uint, current_pos uint, backward bool) ?u32 {
	if pc >= uint(vm.program.instructions.len) { return none }
	instruction := vm.program.instructions[int(pc)]
	if instruction is RegexGreedyLoop {
		minimum := vm.same_matcher_loop_suffix_min(pc + 1, instruction.matcher)?
		available := vm.count_available_same_matcher_chars(current_pos, instruction.matcher,
			minimum, backward)
		deficit := if minimum > available { minimum - available } else { u32(0) }
		if deficit > 0 { return deficit }
	}
	return none
}
