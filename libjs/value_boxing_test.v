module libjs

@[heap]
struct BoxingLog {
mut:
	events []string
}

fn test_to_object_boxes_every_primitive_with_preserved_payload_and_fresh_identity() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	realm := vm.realm()
	number_parent := Object.create(realm, none)
	bigint_parent := Object.create(realm, none)
	string_parent := Object.create(realm, none)
	mut log := &BoxingLog{}
	prototypes := PrimitiveObjectPrototypes{
		number: fn [number_parent, mut log, realm] (current &Realm) &Object {
			assert voidptr(current) == voidptr(realm)
			log.events << 'number'
			return number_parent
		}
		bigint: fn [bigint_parent, mut log, realm] (current &Realm) &Object {
			assert voidptr(current) == voidptr(realm)
			log.events << 'bigint'
			return bigint_parent
		}
		string: fn [string_parent, mut log, realm] (current &Realm) &Object {
			assert voidptr(current) == voidptr(realm)
			log.events << 'string'
			return string_parent
		}
	}
	text := vm.create_string(Utf16String.from_slice([u16(`A`), 0xd800, 0, 0xd83d, 0xde00]))
	bigint := string_to_bigint(utf16_string('9007199254740993'))?
	symbol := Symbol.create(utf16_string('identity'), .unique)
	values := [Value.from_f64(-0.0), Value.from_bigint(bigint), Value.from_string(text),
		Value.from_bool(false), Value.from_symbol(symbol)]
	parents := [number_parent, bigint_parent, string_parent, realm.boolean_prototype_record(),
		realm.symbol_prototype_record()]
	for index, value in values {
		a := value.to_object_with_prototypes(mut vm, prototypes)!
		b := value.to_object_with_prototypes(mut vm, prototypes)!
		assert voidptr(a) != voidptr(b)
		assert voidptr(a.prototype?) == voidptr(parents[index])
		match index {
			0 {
				assert same_value(Value.from_f64(a.number_object?.value), value)
			}
			1 {
				assert voidptr(a.bigint_object?.bigint) == voidptr(bigint)
			}
			2 {
				assert voidptr(a.string_object?.value) == voidptr(text)
				assert a.get(mut vm, PropertyName.from_str('length'))!.number == 5
				assert a.get(mut vm, PropertyName.from_number(1))!.as_string().utf16.data == [u16(0xd800)]
			}
			3 {
				assert !a.boolean_object?.value
			}
			else {
				assert voidptr(a.symbol_object?.symbol) == voidptr(symbol)
			}
		}
	}
	assert log.events == ['number', 'number', 'bigint', 'bigint', 'string', 'string']
}

fn test_to_object_returns_objects_without_intrinsic_lookups_and_rejects_nullish_values() {
	mut vm := VM.create()
	base := create_simple_execution_context(mut vm)
	mut object := Object.create(vm.realm(), none)
	method := NativeFunction.create(mut vm, vm.realm(), vm.realm().function_prototype, fn (mut vm VM) !Value {
		return throw_completion(Value.from_i32(99))
	}, 0, PropertyName.from_str('valueOf'), none)
	object.define_direct_property(PropertyName.from_str('valueOf'), Value.from_object(method.object), 7)
	assert voidptr(Value.from_object(object).to_object_with_prototypes(mut vm, PrimitiveObjectPrototypes{})!) == voidptr(object)
	for value in [js_null(), js_undefined()] {
		if _ := value.to_object_with_prototypes(mut vm, PrimitiveObjectPrototypes{}) {
			assert false
		} else {
			assert thrown_value(err).as_object().error_kind()? == .type_error
			assert thrown_value(err).as_object().error_message()?.str() == 'ToObject on null or undefined'
		}
	}
	assert vm.running_execution_context() == base && vm.interpreter_stack().depth() == 0
}

fn test_to_object_selects_missing_intrinsics_from_the_running_realm() {
	mut vm := VM.create()
	local := create_simple_execution_context(mut vm)
	foreign := create_simple_execution_context(mut vm)
	prototypes := PrimitiveObjectPrototypes{
		number: fn (realm &Realm) &Object { return realm.array_buffer_prototype_record() }
		bigint: fn (realm &Realm) &Object { return realm.data_view_prototype_record() }
		string: fn (realm &Realm) &Object { return realm.shared_array_buffer_prototype_record() }
	}
	for context in [foreign, local] {
		assert vm.running_execution_context() == context
		realm := context.realm?
		number := Value.from_i32(42).to_object_with_prototypes(mut vm, prototypes)!
		bigint := Value.from_bigint(string_to_bigint(utf16_string('42')) or { panic('invalid BigInt literal') }).to_object_with_prototypes(mut vm, prototypes)!
		text := Value.from_string(vm.create_string_from_str('42')).to_object_with_prototypes(mut vm, prototypes)!
		assert voidptr(number.prototype?) == voidptr(realm.array_buffer_prototype_record())
		assert voidptr(bigint.prototype?) == voidptr(realm.data_view_prototype_record())
		assert voidptr(text.prototype?) == voidptr(realm.shared_array_buffer_prototype_record())
		if context == foreign { vm.pop_execution_context() }
	}
}
