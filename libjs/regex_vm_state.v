module libjs

// LibRegex/Rust/src/vm.rs::{SavedState,ActiveModifiers,VmScratch,Vm}: storage,
// construction/reset, snapshots, saved choices and modifier transitions.
// Instruction-loop dispatch remains a separate untranslated slice.
pub struct RegexActiveModifiers {
pub mut:
	ignore_case bool
	multiline   bool
	dot_all     bool
}

pub type RegexSavedState = RegexSavedNormal | RegexSavedGreedy | RegexSavedLazy

pub struct RegexSavedNormal {
pub mut:
	pc                  u32
	pos                 uint
	reg_snapshot_offset uint
	modifiers           RegexActiveModifiers
	modifier_stack_len  uint
	modifier_trail_len  uint
}

pub struct RegexSavedGreedy {
pub mut:
	pc                  u32
	start_pos           uint
	current_pos         uint
	reg_snapshot_offset uint
	min                 u32
	backward            bool
	modifiers           RegexActiveModifiers
	modifier_stack_len  uint
	modifier_trail_len  uint
}

pub struct RegexSavedLazy {
pub mut:
	pc                  u32
	pos                 uint
	reg_snapshot_offset uint
	max                 ?u32
	consumed            u32
	modifiers           RegexActiveModifiers
	modifier_stack_len  uint
	modifier_trail_len  uint
}

pub struct RegexModifierUndo {
pub:
	pushed    bool
	modifiers RegexActiveModifiers
}

@[heap]
pub struct RegexVmScratch {
pub mut:
	registers       []i32
	backtrack_stack []RegexSavedState
	register_pool   []i32
	modifier_stack  []RegexActiveModifiers
	modifier_trail  []RegexModifierUndo
}

pub fn RegexVmScratch.new() &RegexVmScratch {
	return &RegexVmScratch{}
}

pub struct RegexVm {
pub:
	program &RegexProgram @[required]
	input   RegexInput
pub mut:
	pc         u32
	pos        uint
	scratch    &RegexVmScratch @[required]
	steps      u64
	modifiers  RegexActiveModifiers
	backward   bool
	bt_floor   uint
	look_depth int
}

// The VM borrows the stable program/input and this scratch owner. Callers must
// retain all three and use one active VM per scratch, matching Rust's exclusive
// borrow of its scratch vectors. One owner reference replaces those vector borrows.
pub fn RegexVm.new(program &RegexProgram, input RegexInput, start_pos uint, mut scratch RegexVmScratch) &RegexVm {
	if program.register_count > u32(max_int) {
		panic('Regex register count exceeds V array capacity')
	}
	reg_count := int(program.register_count)
	if scratch.registers.len > reg_count { scratch.registers.trim(reg_count) }
	for scratch.registers.len < reg_count {
		scratch.registers << i32(-1)
	}
	for index in 0 .. scratch.registers.len {
		scratch.registers[index] = -1
	}
	scratch.backtrack_stack.clear()
	scratch.register_pool.clear()
	scratch.modifier_stack.clear()
	scratch.modifier_trail.clear()
	return &RegexVm{
		program:   program
		input:     input
		pos:       start_pos
		scratch:   &scratch
		modifiers: RegexActiveModifiers{
			ignore_case: program.ignore_case
			multiline:   program.multiline
			dot_all:     program.dot_all
		}
	}
}

pub fn (vm RegexVm) input_len() uint {
	return vm.input.len()
}

pub fn (vm RegexVm) input_code_unit(pos uint) u16 {
	return vm.input.code_unit(pos)
}

pub fn (mut vm RegexVm) reset(pos uint) {
	vm.pc = 0
	vm.pos = pos
	for index in 0 .. vm.scratch.registers.len {
		vm.scratch.registers[index] = -1
	}
	vm.scratch.backtrack_stack.clear()
	vm.scratch.register_pool.clear()
	vm.steps = 0
	vm.modifiers = RegexActiveModifiers{
		ignore_case: vm.program.ignore_case
		multiline:   vm.program.multiline
		dot_all:     vm.program.dot_all
	}
	vm.scratch.modifier_stack.clear()
	vm.scratch.modifier_trail.clear()
	vm.backward = false
	vm.bt_floor = 0
	vm.look_depth = 0
}

pub fn (mut vm RegexVm) snapshot_registers() uint {
	offset := uint(vm.scratch.register_pool.len)
	vm.scratch.register_pool << vm.scratch.registers
	return offset
}

pub fn (mut vm RegexVm) restore_registers(reg_snapshot_offset uint) {
	reg_count := vm.scratch.registers.len
	// Rust validates the whole slice before copying, including an empty slice.
	if reg_snapshot_offset > uint(vm.scratch.register_pool.len)
		|| uint(reg_count) > uint(vm.scratch.register_pool.len) - reg_snapshot_offset {
		panic('Regex register snapshot index out of bounds')
	}
	start := int(reg_snapshot_offset)
	snapshot := vm.scratch.register_pool[start..start + reg_count].clone()
	for index, value in snapshot {
		vm.scratch.registers[index] = value
	}
}

pub fn (mut vm RegexVm) push_backtrack(pc u32, pos uint) {
	offset := vm.snapshot_registers()
	vm.scratch.backtrack_stack << RegexSavedNormal{
		pc:                  pc
		pos:                 pos
		reg_snapshot_offset: offset
		modifiers:           vm.modifiers
		modifier_stack_len:  uint(vm.scratch.modifier_stack.len)
		modifier_trail_len:  uint(vm.scratch.modifier_trail.len)
	}
}

pub fn (mut vm RegexVm) push_backtrack_modified(pc u32, pos uint, mod_index uint, mod_value i32) {
	offset := vm.snapshot_registers()
	if mod_index >= uint(vm.scratch.registers.len) {
		panic('Regex register snapshot index out of bounds')
	}
	vm.scratch.register_pool[int(offset + mod_index)] = mod_value
	vm.scratch.backtrack_stack << RegexSavedNormal{
		pc:                  pc
		pos:                 pos
		reg_snapshot_offset: offset
		modifiers:           vm.modifiers
		modifier_stack_len:  uint(vm.scratch.modifier_stack.len)
		modifier_trail_len:  uint(vm.scratch.modifier_trail.len)
	}
}

pub fn (mut vm RegexVm) push_greedy_backtrack(pc u32, start_pos uint, current_pos uint, min u32) {
	offset := vm.snapshot_registers()
	vm.scratch.backtrack_stack << RegexSavedGreedy{
		pc:                  pc
		start_pos:           start_pos
		current_pos:         current_pos
		reg_snapshot_offset: offset
		min:                 min
		backward:            vm.backward
		modifiers:           vm.modifiers
		modifier_stack_len:  uint(vm.scratch.modifier_stack.len)
		modifier_trail_len:  uint(vm.scratch.modifier_trail.len)
	}
}

pub fn (mut vm RegexVm) push_lazy_backtrack(pc u32, pos uint, max ?u32, consumed u32) {
	offset := vm.snapshot_registers()
	vm.scratch.backtrack_stack << RegexSavedLazy{
		pc:                  pc
		pos:                 pos
		reg_snapshot_offset: offset
		max:                 max
		consumed:            consumed
		modifiers:           vm.modifiers
		modifier_stack_len:  uint(vm.scratch.modifier_stack.len)
		modifier_trail_len:  uint(vm.scratch.modifier_trail.len)
	}
}

pub fn (mut vm RegexVm) handle_push_modifiers(ignore_case ?bool, multiline ?bool, dot_all ?bool) {
	vm.scratch.modifier_stack << vm.modifiers
	if vm.needs_modifier_undo_entries() {
		vm.scratch.modifier_trail << RegexModifierUndo{ pushed: true }
	} else {
		vm.scratch.modifier_trail.clear()
	}
	if value := ignore_case { vm.modifiers.ignore_case = value }
	if value := multiline { vm.modifiers.multiline = value }
	if value := dot_all { vm.modifiers.dot_all = value }
	vm.pc++
}

pub fn (mut vm RegexVm) handle_pop_modifiers() {
	if vm.scratch.modifier_stack.len > 0 {
		previous := vm.scratch.modifier_stack.pop()
		if vm.needs_modifier_undo_entries() {
			vm.scratch.modifier_trail << RegexModifierUndo{ modifiers: previous }
		} else {
			vm.scratch.modifier_trail.clear()
		}
		vm.modifiers = previous
	}
	vm.pc++
}

fn (vm &RegexVm) needs_modifier_undo_entries() bool {
	return vm.scratch.backtrack_stack.len > 0 || vm.look_depth != 0
}

// Restore pushes and pops, including entries removed after a saved choice.
fn (mut vm RegexVm) undo_modifier_changes(trail_length uint) {
	for uint(vm.scratch.modifier_trail.len) > trail_length {
		change := vm.scratch.modifier_trail.pop()
		if change.pushed {
			if vm.scratch.modifier_stack.len > 0 { vm.scratch.modifier_stack.pop() }
		} else {
			vm.scratch.modifier_stack << change.modifiers
		}
	}
}
