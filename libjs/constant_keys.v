module libjs

import os
import platform

// Same-binary control: convert every key operand with ToPropertyKey again.
const convert_constant_keys = os.getenv('VOX_LIBJS_CONVERT_CONSTANT_KEYS') != ''

$if test {
	__global constant_key_hits u64
}

// A property instruction's key is usually a string constant (`o.name`, a
// literal's `name:`), and ToPropertyKey of a string is the same PropertyName
// every time. The compiled body keeps one per string constant; closures share it.
@[inline]
fn (mut vm VM) operand_property_key(executable &Executable, operand Operand, value Value) !PropertyName {
	if operand.raw >> 29 == u32(OperandType.constant) && value.is_string() && !convert_constant_keys {
		index := operand.raw & 0x1fffffff
		if executable.constant_keys.len != executable.constants.len { executable.allocate_constant_keys() }
		if index < u32(executable.constant_keys.len) {
			$if test {
				// The frame's constant slot is the executable's own constant.
				assert voidptr(value.as_string()) == voidptr(executable.constants[index].as_string())
				constant_key_hits++
			}
			return unsafe { (&PropertyName(executable.constant_keys.data))[index] }
		}
	}
	return value.to_property_key(mut vm)
}

fn (executable &Executable) allocate_constant_keys() {
	persistent := platform.enter_persistent()
	mut keys := []PropertyName{len: executable.constants.len}
	for index, constant in executable.constants {
		if constant.is_string() { keys[index] = PropertyName.from_primitive_string(constant.as_string()) }
	}
	mut owner := unsafe { &Executable(executable) }
	owner.constant_keys = keys
	platform.leave_persistent(persistent)
}
