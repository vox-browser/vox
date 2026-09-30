module libjs

// LibJS/Rust/src/bytecode/operand.rs: three type bits, 29 index bits.
pub enum OperandType as u32 {
	register
	local
	constant
	argument
}

pub struct Operand {
pub:
	raw u32 = 0xffffffff
}

pub fn Operand.register(index u32) Operand {
	return Operand.from_index(.register, index)
}

pub fn Operand.local(index u32) Operand {
	return Operand.from_index(.local, index)
}

pub fn Operand.constant(index u32) Operand {
	return Operand.from_index(.constant, index)
}

pub fn Operand.argument(index u32) Operand {
	return Operand.from_index(.argument, index)
}

fn Operand.from_index(kind OperandType, index u32) Operand {
	if index > 0x1fffffff { panic('Operand index exceeds 29 bits') }
	return Operand{
		raw: (u32(kind) << 29) | index
	}
}

pub fn (operand Operand) index() u32 {
	return operand.raw & 0x1fffffff
}

pub fn (operand Operand) operand_type() !OperandType {
	tag := operand.raw >> 29
	if tag > 3 { return error('Invalid bytecode operand ${operand.raw}') }
	return unsafe { OperandType(tag) }
}

fn (operand Operand) slot(executable &Executable, arguments_count u32, writing bool) !u32 {
	index := operand.index()
	kind := operand.operand_type()!
	match kind {
		.register {
			if index >= executable.registers_and_locals_count {
				return error('Register out of range')
			}
			return index
		}
		.local {
			slot := u64(executable.local_index_base) + index
			if index >= u32(executable.local_variable_names.len)
				|| slot >= executable.registers_and_locals_count {
				return error('Local out of range')
			}
			return u32(slot)
		}
		.constant {
			if writing { return error('Cannot write to a constant operand') }
			if index >= u32(executable.constants.len) { return error('Constant out of range') }
			return executable.registers_and_locals_count + index
		}
		.argument {
			if index >= arguments_count { return error('Argument out of range') }
			return executable.registers_and_locals_count + u32(executable.constants.len) + index
		}
	}
}
