module libjs

import platform

// run_executable() addresses an operand as bases[type] + index, and the bases
// depend only on the executable's frame layout. Each instruction's operand
// slots are resolved once per compiled body (closures share them), so the
// inline handlers index the frame directly. Unused operands keep 0xffffffff.
struct OperandSlots {
	dst u32
	lhs u32
	rhs u32
	src u32
}

// Operand.validated_slot()'s per-type bases, indexed by the operand tag.
@[inline]
fn (executable &Executable) operand_bases() [4]u32 {
	return [u32(0), executable.local_index_base, executable.registers_and_locals_count,
		executable.registers_and_locals_count + u32(executable.constants.len)]!
}

@[inline]
fn operand_slot(operand Operand, bases [4]u32) u32 {
	kind := operand.raw >> 29
	if kind > 3 { return 0xffffffff }
	return bases[kind] + (operand.raw & 0x1fffffff)
}

fn (executable &Executable) operand_slots_for(bases [4]u32) &OperandSlots {
	if executable.operand_slots.len != executable.instructions.len
		|| executable.operand_slot_instructions != executable.instructions.data
		|| executable.operand_slot_bases[0] != bases[0] || executable.operand_slot_bases[1] != bases[1]
		|| executable.operand_slot_bases[2] != bases[2] || executable.operand_slot_bases[3] != bases[3] {
		persistent := platform.enter_persistent()
		mut slots := []OperandSlots{len: executable.instructions.len}
		for index, instruction in executable.instructions {
			slots[index] = OperandSlots{
				dst: operand_slot(instruction.dst, bases)
				lhs: operand_slot(instruction.lhs, bases)
				rhs: operand_slot(instruction.rhs, bases)
				src: operand_slot(instruction.src, bases)
			}
		}
		platform.leave_persistent(persistent)
		mut owner := unsafe { &Executable(executable) }
		owner.operand_slots = slots
		owner.operand_slot_instructions = executable.instructions.data
		owner.operand_slot_bases = bases
	}
	return unsafe { &OperandSlots(executable.operand_slots.data) }
}
