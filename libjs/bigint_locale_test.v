module libjs

@[heap]
struct BigIntLocaleLog {
mut:
	events []string
}

fn bigint_locale_call(mut vm VM, dependencies BigIntLocaleDependencies, receiver Value, arguments []Value) !Value {
	function := NativeFunction.create(mut vm, vm.realm(), vm.realm().function_prototype, fn [dependencies] (mut vm VM) !Value {
		return bigint_prototype_to_locale_string(mut vm, dependencies)
	}, 0, PropertyName.from_str('toLocaleString'), none)
	return call(mut vm, Value.from_object(function.object), receiver, arguments)
}

fn test_bigint_locale_body_preserves_realm_retained_constructor_arguments_payload_and_utf16() {
	mut vm := VM.create()
	base := create_simple_execution_context(mut vm)
	realm := vm.realm()
	parent := Object.create(realm, none)
	integer := string_to_bigint(utf16_string('123456789123456789123456789123456789')) or {
		panic('fixture')
	}
	wrapper := BigIntObject.create(realm, integer, parent)
	locales := Value.from_object(Object.create(realm, none))
	options := Value.from_object(Object.create(realm, none))
	text := Utf16String.from_slice([u16(0xd800), 0, 0xdc00, 0x661])
	mut log := &BigIntLocaleLog{}
	// These host dependencies assert plumbing only; they do not implement Intl.
	for supplied in [false, true] {
		constructor := NativeFunction.create_constructor(mut vm, realm, realm.function_prototype, fn (mut vm VM) !Value {
			assert false, 'NumberFormat must be constructed'
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
		dependencies := BigIntLocaleDependencies{
			constructor_getter: fn [realm, constructor, mut log] (current &Realm) &Object {
				log.events << 'intrinsic'
				assert voidptr(current) == voidptr(realm)
				return constructor
			}
			format_numeric:     fn [parent, integer, text, mut log] (formatter &Object, number Value) Utf16String {
				log.events << 'format'
				assert voidptr(formatter) == voidptr(parent)
				assert number.is_bigint() && voidptr(number.as_bigint()) == voidptr(integer)
				return text
			}
		}
		for receiver in [Value.from_bigint(integer), Value.from_object(wrapper.object)] {
			mut arguments := []Value{}
			if supplied { arguments << [locales, options, Value.from_i32(99)] }
			result := bigint_locale_call(mut vm, dependencies, receiver, arguments)!
			assert result.as_string().utf16 == text
			assert log.events == ['intrinsic', 'construct', 'format']
			log.events.clear()
		}
	}
	assert vm.running_execution_context() == base && vm.interpreter_stack().depth() == 0
}

fn test_bigint_locale_brand_check_and_constructor_errors_prevent_later_dependencies() {
	mut vm := VM.create()
	base := create_simple_execution_context(mut vm)
	mut log := &BigIntLocaleLog{}
	constructor := NativeFunction.create_constructor(mut vm, vm.realm(),
		vm.realm().function_prototype, fn (mut vm VM) !Value {
		return js_undefined()
	}, fn [mut log] (mut vm VM, target &Object) !&Object {
		log.events << 'construct'
		return throw_completion(Value.from_i32(77))
	}, 0, PropertyName.from_str('HostNumberFormat')).object
	dependencies := BigIntLocaleDependencies{
		constructor_getter: fn [constructor, mut log] (realm &Realm) &Object {
			log.events << 'intrinsic'
			return constructor
		}
		format_numeric:     fn (formatter &Object, number Value) Utf16String {
			assert false, 'a failed construction must not reach FormatNumeric'
			return Utf16String.new()
		}
	}
	for receiver in [js_undefined(), js_null(), Value.from_i32(42),
		Value.from_object(Object.create(vm.realm(), none))] {
		if _ := bigint_locale_call(mut vm, dependencies, receiver, []Value{}) {
			assert false
		} else {
			assert thrown_value(err).as_object().error_message()?.str() == 'Not an object of type BigInt'
		}
		assert log.events.len == 0
	}
	integer := string_to_bigint(utf16_string('42')) or { panic('fixture') }
	if _ := bigint_locale_call(mut vm, dependencies, Value.from_bigint(integer), []Value{}) {
		assert false
	} else {
		assert thrown_value(err).number == 77
	}
	assert log.events == ['intrinsic', 'construct']
	assert vm.running_execution_context() == base && vm.interpreter_stack().depth() == 0
}
