module libjs

// LibRegex/Rust/src/vm.rs::Vm::backtrack. This restores and resumes saved
// choices; the fast/general instruction loops remain separate slices.
pub fn (mut vm RegexVm) backtrack() bool {
	if uint(vm.scratch.backtrack_stack.len) <= vm.bt_floor { return false }
	state := vm.scratch.backtrack_stack.pop()
	match state {
		RegexSavedNormal {
			vm.pc = state.pc
			vm.pos = state.pos
			vm.restore_registers(state.reg_snapshot_offset)
			vm.scratch.register_pool.trim(int(state.reg_snapshot_offset))
			vm.modifiers = state.modifiers
			vm.undo_modifier_changes(state.modifier_trail_len)
			if state.modifier_stack_len < uint(vm.scratch.modifier_stack.len) {
				vm.scratch.modifier_stack.trim(int(state.modifier_stack_len))
			}
		}
		RegexSavedGreedy {
			vm.restore_registers(state.reg_snapshot_offset)
			vm.scratch.register_pool.trim(int(state.reg_snapshot_offset))
			vm.modifiers = state.modifiers
			vm.undo_modifier_changes(state.modifier_trail_len)
			if state.modifier_stack_len < uint(vm.scratch.modifier_stack.len) {
				vm.scratch.modifier_stack.trim(int(state.modifier_stack_len))
			}
			deficit := vm.same_matcher_loop_suffix_deficit(uint(state.pc), state.current_pos,
				state.backward)
			if state.backward {
				mut max_pos := state.start_pos
				if vm.program.unicode {
					for _ in 0 .. state.min {
						max_pos = vm.retreat_one_char(max_pos)
					}
				} else {
					max_pos -= uint(state.min)
				}
				mut target := ?u32(none)
				next_pc := uint(state.pc) + 1
				if next_pc < uint(vm.program.instructions.len) {
					next := vm.program.instructions[int(next_pc)]
					if next is RegexLiteral && !vm.modifiers.ignore_case {
						target = next.code_point
					}
				}
				mut new_pos := uint(0)
				if missing := deficit {
					advanced := vm.advance_n_chars(state.current_pos, missing) or {
						return vm.backtrack()
					}
					if advanced > max_pos { return vm.backtrack() }
					new_pos = advanced
				} else if literal := target {
					if literal <= 0xffff {
						unit := u16(literal)
						mut scan_pos := vm.advance_one_char(state.current_pos)
						for {
							if scan_pos > max_pos { return vm.backtrack() }
							if scan_pos > 0 && vm.input_code_unit(scan_pos - 1) == unit {
								break
							}
							advanced := vm.advance_one_char(scan_pos)
							if advanced == scan_pos { return vm.backtrack() }
							scan_pos = advanced
						}
						new_pos = scan_pos
					} else {
						hi := u16((literal - 0x10000) >> 10) + u16(0xd800)
						lo := u16((literal - 0x10000) & 0x3ff) + u16(0xdc00)
						mut scan_pos := vm.advance_one_char(state.current_pos)
						for {
							if scan_pos > max_pos { return vm.backtrack() }
							if scan_pos >= 2 && vm.input_code_unit(scan_pos - 2) == hi
								&& vm.input_code_unit(scan_pos - 1) == lo {
								break
							}
							advanced := vm.advance_one_char(scan_pos)
							if advanced == scan_pos { return vm.backtrack() }
							scan_pos = advanced
						}
						new_pos = scan_pos
					}
				} else {
					advanced := vm.advance_one_char(state.current_pos)
					if advanced > max_pos { return vm.backtrack() }
					new_pos = advanced
				}
				if new_pos < max_pos {
					offset := vm.snapshot_registers()
					vm.scratch.backtrack_stack << RegexSavedGreedy{
						pc:                  state.pc
						start_pos:           state.start_pos
						current_pos:         new_pos
						reg_snapshot_offset: offset
						min:                 state.min
						backward:            state.backward
						modifiers:           state.modifiers
						modifier_stack_len:  state.modifier_stack_len
						modifier_trail_len:  state.modifier_trail_len
					}
				}
				vm.pos = new_pos
				vm.pc = state.pc + 1
			} else {
				mut min_pos := state.start_pos
				if vm.program.unicode {
					for _ in 0 .. state.min {
						min_pos = vm.advance_one_char(min_pos)
					}
				} else {
					min_pos += uint(state.min)
				}
				mut target := ?u32(none)
				next_pc := uint(state.pc) + 1
				if next_pc < uint(vm.program.instructions.len) {
					next := vm.program.instructions[int(next_pc)]
					if next is RegexLiteral && !vm.modifiers.ignore_case {
						target = next.code_point
					}
				}
				mut new_pos := uint(0)
				if missing := deficit {
					retreated := vm.retreat_n_chars(state.current_pos, missing) or {
						return vm.backtrack()
					}
					if retreated < min_pos { return vm.backtrack() }
					new_pos = retreated
				} else if literal := target {
					if literal <= 0xffff {
						unit := u16(literal)
						mut scan_pos := if state.current_pos > 0 {
							state.current_pos - 1
						} else {
							uint(0)
						}
						for {
							if scan_pos < min_pos { return vm.backtrack() }
							if vm.input_code_unit(scan_pos) == unit {
								break
							}
							if scan_pos == 0 { return vm.backtrack() }
							scan_pos--
						}
						new_pos = scan_pos
					} else {
						hi := u16((literal - 0x10000) >> 10) + u16(0xd800)
						lo := u16((literal - 0x10000) & 0x3ff) + u16(0xdc00)
						mut scan_pos := if state.current_pos > 1 {
							state.current_pos - 2
						} else {
							uint(0)
						}
						for {
							if scan_pos < min_pos { return vm.backtrack() }
							if scan_pos + 1 < vm.input_len() && vm.input_code_unit(scan_pos) == hi
								&& vm.input_code_unit(scan_pos + 1) == lo {
								break
							}
							if scan_pos == 0 { return vm.backtrack() }
							scan_pos--
						}
						new_pos = scan_pos
					}
				} else {
					retreated := vm.retreat_one_char(state.current_pos)
					if retreated < min_pos { return vm.backtrack() }
					new_pos = retreated
				}
				if new_pos > min_pos {
					offset := vm.snapshot_registers()
					vm.scratch.backtrack_stack << RegexSavedGreedy{
						pc:                  state.pc
						start_pos:           state.start_pos
						current_pos:         new_pos
						reg_snapshot_offset: offset
						min:                 state.min
						backward:            state.backward
						modifiers:           state.modifiers
						modifier_stack_len:  state.modifier_stack_len
						modifier_trail_len:  state.modifier_trail_len
					}
				}
				vm.pos = new_pos
				vm.pc = state.pc + 1
			}
		}
		RegexSavedLazy {
			vm.restore_registers(state.reg_snapshot_offset)
			vm.scratch.register_pool.trim(int(state.reg_snapshot_offset))
			vm.modifiers = state.modifiers
			vm.undo_modifier_changes(state.modifier_trail_len)
			if state.modifier_stack_len < uint(vm.scratch.modifier_stack.len) {
				vm.scratch.modifier_stack.trim(int(state.modifier_stack_len))
			}
			if maximum := state.max {
				if state.consumed >= maximum { return vm.backtrack() }
			}
			vm.pos = state.pos
			if point := vm.current_code_point() {
				instruction := vm.program.instructions[int(state.pc)]
				matcher := match instruction {
					RegexLazyLoop { instruction.matcher }
					else { panic('Regex lazy backtrack requires a lazy loop') }
				}

				if vm.match_simple(point, matcher) {
					vm.advance_char()
					vm.push_lazy_backtrack(state.pc, vm.pos, state.max, state.consumed + 1)
					vm.pc = state.pc + 1
				} else {
					return vm.backtrack()
				}
			} else {
				return vm.backtrack()
			}
		}
	}

	return true
}
