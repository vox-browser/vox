module libjs

import math

fn test_narrow_integer_conversions_wrap_after_truncation_and_preserve_signed_ranges() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	inputs := [65535.9, 65536.9, -65537.9, 32768.0, 255.9, 256.9, -257.9, 128.0]
	unsigned16 := [u16(65535), 0, 65535, 32768, 255, 256, 65279, 128]
	signed16 := [i16(-1), 0, -1, -32768, 255, 256, -257, 128]
	unsigned8 := [u8(255), 0, 255, 0, 255, 0, 255, 128]
	signed8 := [i8(-1), 0, -1, 0, -1, 0, -1, -128]
	for index, input in inputs {
		value := Value.from_f64(input)
		assert value.to_u16(mut vm)! == unsigned16[index]
		assert value.to_i16(mut vm)! == signed16[index]
		assert value.to_u8(mut vm)! == unsigned8[index]
		assert value.to_i8(mut vm)! == signed8[index]
	}
	for input in [math.nan(), math.inf(-1), math.inf(1), -0.0, 0.0] {
		value := Value.from_f64(input)
		assert value.to_i16(mut vm)! == 0 && value.to_u16(mut vm)! == 0
		assert value.to_i8(mut vm)! == 0 && value.to_u8(mut vm)! == 0
	}
	assert Value.from_i32(-1).to_u8(mut vm)! == 255
	assert Value.from_string(vm.create_string_from_str('65537')).to_u16(mut vm)! == 1
}

fn test_clamped_byte_conversion_rounds_halfway_values_to_even_and_propagates_coercion_errors() {
	mut vm := VM.create()
	base := create_simple_execution_context(mut vm)
	inputs := [math.nan(), math.inf(-1), -1.0, 0.49, 0.5, 1.5, 2.5, 2.51, 254.5, 254.6,
		math.inf(1)]
	expected := [u8(0), 0, 0, 0, 0, 2, 2, 3, 254, 255, 255]
	for index, input in inputs {
		assert Value.from_f64(input).to_u8_clamp(mut vm)! == expected[index]
	}
	mut object := Object.create(vm.realm(), none)
	convert := NativeFunction.create(mut vm, vm.realm(), vm.realm().function_prototype, fn (mut vm VM) !Value {
		assert vm.argument(0).as_string().str() == 'number'
		return throw_completion(Value.from_i32(42))
	}, 1, PropertyName.from_str('convert'), none)
	object.define_direct_property(PropertyName.from_symbol(vm.well_known_symbol_to_primitive()),
		Value.from_object(convert.object), 7)
	value := Value.from_object(object)
	for method in [0, 1, 2, 3, 4] {
		result := match method {
			0 {
				value.to_u8(mut vm) or {
					assert thrown_value(err).number == 42
					continue
				}
			}
			1 {
				u8(value.to_i8(mut vm) or {
					assert thrown_value(err).number == 42
					continue
				})
			}
			2 {
				u8(value.to_u16(mut vm) or {
					assert thrown_value(err).number == 42
					continue
				})
			}
			3 {
				u8(value.to_i16(mut vm) or {
					assert thrown_value(err).number == 42
					continue
				})
			}
			else {
				value.to_u8_clamp(mut vm) or {
					assert thrown_value(err).number == 42
					continue
				}
			}
		}

		assert false, 'unexpected normal conversion ${result}'
	}
	assert vm.running_execution_context() == base && vm.interpreter_stack().depth() == 0
}
