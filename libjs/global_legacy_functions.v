module libjs

// Runtime/GlobalObject.cpp::{escape,unescape}, Annex B.2.1. The algorithms
// operate on UTF-16 code units, including unpaired surrogates, without the
// UTF-8 transformation used by the URI functions.
fn global_escape(mut vm VM) !Value {
	input := vm.argument(0).to_primitive_string(mut vm)!
	unescaped_set := 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789@*_+-./'.bytes()
	hex := '0123456789ABCDEF'.bytes()
	mut escaped := []u16{}
	for unit in input.utf16.data {
		if unit < 0x80 && unescaped_set.contains(u8(unit)) {
			escaped << unit
		} else if unit < 256 {
			escaped << u16(`%`)
			escaped << u16(hex[unit >> 4])
			escaped << u16(hex[unit & 15])
		} else {
			escaped << u16(`%`)
			escaped << u16(`u`)
			escaped << u16(hex[unit >> 12])
			escaped << u16(hex[(unit >> 8) & 15])
			escaped << u16(hex[(unit >> 4) & 15])
			escaped << u16(hex[unit & 15])
		}
	}
	return Value.from_string(vm.create_string(Utf16String.from_slice(escaped)))
}

fn legacy_hex_value(units []u16) ?u16 {
	mut value := u16(0)
	for unit in units {
		digit := uri_hex_digit(unit) or { return none }
		value = (value << 4) | u16(digit)
	}
	return value
}

fn global_unescape(mut vm VM) !Value {
	input := vm.argument(0).to_primitive_string(mut vm)!
	units := input.utf16.data
	mut unescaped := []u16{cap: units.len}
	mut index := 0
	for index < units.len {
		unit := units[index]
		if unit == u16(`%`) {
			if index + 5 < units.len && units[index + 1] == u16(`u`) {
				if value := legacy_hex_value(units[index + 2..index + 6]) {
					unescaped << value
					index += 6
					continue
				}
			}
			if index + 2 < units.len {
				if value := legacy_hex_value(units[index + 1..index + 3]) {
					unescaped << value
					index += 3
					continue
				}
			}
		}
		unescaped << unit
		index++
	}
	return Value.from_string(vm.create_string(Utf16String.from_slice(unescaped)))
}

// SetDefaultGlobalBindings installs these legacy properties after the value
// properties and intrinsic objects. The remaining intrinsic objects are pending.
fn set_default_global_legacy_functions(mut vm VM, realm &Realm) {
	mut global := realm.global_object_record()
	for name, behaviour in {
		'escape':   NativeFunctionPointer(global_escape)
		'unescape': NativeFunctionPointer(global_unescape)
	} {
		function := NativeFunction.create_raw(mut vm, realm, realm.function_prototype, behaviour,
			1, PropertyName.from_str(name), none)
		global.define_direct_property(PropertyName.from_str(name),
			Value.from_object(function.object), attribute_writable | attribute_configurable)
	}
}
