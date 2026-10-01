module libjs

import math

@[heap]
struct NumberLocaleLog {
mut:
	events []string
}

fn number_locale_call(mut vm VM, dependencies NumberLocaleDependencies, receiver Value, arguments []Value) !Value {
	function := NativeFunction.create(mut vm, vm.realm(), vm.realm().function_prototype, fn [dependencies] (mut vm VM) !Value {
		return number_prototype_to_locale_string(mut vm, dependencies)
	}, 0, PropertyName.from_str('toLocaleString'), none)
	return call(mut vm, Value.from_object(function.object), receiver, arguments)
}

fn test_number_locale_preserves_special_numeric_payloads_constructor_arguments_and_utf16() {
	mut vm := VM.create()
	base := create_simple_execution_context(mut vm)
	realm := vm.realm()
	parent := Object.create(realm, none)
	locales := Value.from_object(Object.create(realm, none))
	options := Value.from_object(Object.create(realm, none))
	text := Utf16String.from_slice([u16(0xd800), 0, 0xdc00, 0x661])
	mut log := &NumberLocaleLog{}
	for supplied in [false, true] {
		// Test host dependencies assert plumbing only; they do not format Intl.
		constructor := NativeFunction.create_constructor(mut vm, realm, realm.function_prototype, fn (mut vm VM) !Value {
			assert false, 'Intl.NumberFormat must be constructed'
			return js_undefined()
		}, fn [realm, supplied, locales, options, parent, mut log] (mut vm VM, target &Object) !&Object {
			log.events << 'construct'
			assert voidptr(vm.realm()) == voidptr(realm) && vm.argument_count() == 2
			if supplied {
				assert same_value(vm.argument(0), locales) && same_value(vm.argument(1), options)
			} else {
				assert vm.argument(0).is_undefined() && vm.argument(1).is_undefined()
			}
			return parent
		}, 0, PropertyName.from_str('HostNumberFormat')).object
		for number in [0.0, -0.0, 123.456, math.nan(), math.inf(1),
			math.inf(-1)] {
			value := Value.from_f64(number)
			dependencies := NumberLocaleDependencies{
				constructor_getter: fn [realm, constructor, mut log] (current &Realm) &Object {
					log.events << 'intrinsic'
					assert voidptr(current) == voidptr(realm)
					return constructor
				}
				format_numeric:     fn [parent, value, text, mut log] (formatter &Object, numeric Value) Utf16String {
					log.events << 'format'
					assert voidptr(formatter) == voidptr(parent) && same_value(numeric, value)
					return text
				}
			}
			wrapper := NumberObject.create(realm, number, parent)
			for receiver in [value, Value.from_object(wrapper.object)] {
				mut arguments := []Value{}
				if supplied { arguments << [locales, options, Value.from_i32(99)] }
				result := number_locale_call(mut vm, dependencies, receiver, arguments)!
				assert result.as_string().utf16 == text
				assert log.events == ['intrinsic', 'construct', 'format']
				log.events.clear()
			}
		}
	}
	assert vm.running_execution_context() == base && vm.interpreter_stack().depth() == 0
}

fn test_number_locale_brand_and_constructor_errors_prevent_later_dependencies() {
	mut vm := VM.create()
	base := create_simple_execution_context(mut vm)
	mut log := &NumberLocaleLog{}
	constructor := NativeFunction.create_constructor(mut vm, vm.realm(),
		vm.realm().function_prototype, fn (mut vm VM) !Value {
		return js_undefined()
	}, fn [mut log] (mut vm VM, target &Object) !&Object {
		log.events << 'construct'
		return throw_completion(Value.from_i32(77))
	}, 0, PropertyName.from_str('HostNumberFormat')).object
	dependencies := NumberLocaleDependencies{
		constructor_getter: fn [constructor, mut log] (realm &Realm) &Object {
			log.events << 'intrinsic'
			return constructor
		}
		format_numeric:     fn (formatter &Object, number Value) Utf16String {
			assert false, 'failed construction must not reach FormatNumeric'
			return Utf16String.new()
		}
	}
	integer := string_to_bigint(utf16_string('42')) or { panic('fixture') }
	for receiver in [js_undefined(), js_null(), Value.from_bool(true),
		Value.from_bigint(integer), Value.from_object(Object.create(vm.realm(), none))] {
		if _ := number_locale_call(mut vm, dependencies, receiver, []Value{}) {
			assert false
		} else {
			assert thrown_value(err).as_object().error_message()?.str() == 'Not an object of type Number'
		}
		assert log.events.len == 0
	}
	if _ := number_locale_call(mut vm, dependencies, Value.from_i32(42), []Value{}) {
		assert false
	} else {
		assert thrown_value(err).number == 77
	}
	assert log.events == ['intrinsic', 'construct']
	assert vm.running_execution_context() == base && vm.interpreter_stack().depth() == 0
}
