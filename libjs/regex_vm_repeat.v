module libjs

// LibRegex/Rust/src/vm.rs::{handle_repeat_start,handle_repeat_check}.
pub fn (mut vm RegexVm) handle_repeat_start(counter_reg u32) {
	reg := uint(counter_reg)
	if reg < uint(vm.scratch.registers.len) { vm.scratch.registers[int(reg)] = 0 }
	vm.pc++
}

pub fn (mut vm RegexVm) handle_repeat_check(counter_reg u32, min u32, max ?u32, body u32, greedy bool) {
	reg := int(counter_reg)
	count := u32(vm.scratch.registers[reg])
	if count < min {
		vm.scratch.registers[reg] = i32(count + 1)
		vm.pc = body
		return
	}
	if maximum := max {
		if count >= maximum {
			vm.pc++
			return
		}
	}
	if greedy {
		vm.push_backtrack(vm.pc + 1, vm.pos)
		vm.scratch.registers[reg] = i32(count + 1)
		vm.pc = body
	} else {
		// The optimized Rust source uses wrapping release-mode i32 arithmetic.
		vm.push_backtrack_modified(body, vm.pos, uint(counter_reg), i32(count + 1))
		vm.pc++
	}
}

pub fn (vm RegexVm) same_matcher_loop_suffix_min(start uint, matcher RegexSimpleMatch) ?u32 {
	mut pc := start
	mut total := u32(0)
	mut saw_positive_min := false
	for pc < uint(vm.program.instructions.len) {
		instruction := vm.program.instructions[int(pc)]
		mut minimum := u32(0)
		match instruction {
			RegexGreedyLoop {
				if instruction.matcher != matcher { break
				 }
				minimum = instruction.min
			}
			RegexLazyLoop {
				if instruction.matcher != matcher { break
				 }
				minimum = instruction.min
			}
			else {
				break
			}
		}

		if minimum > u32(0xffffffff) - total { return none }
		total += minimum
		saw_positive_min = saw_positive_min || minimum > 0
		pc++
	}
	if saw_positive_min { return total }
	return none
}
