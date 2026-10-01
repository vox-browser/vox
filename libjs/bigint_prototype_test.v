module libjs

fn bigint_prototype_test_dependencies(mut vm VM, realm &Realm, parent &Object) BigIntLocaleDependencies {
	// Test host dependency returns a marker, without pretending to format Intl.
	constructor := NativeFunction.create_constructor(mut vm, realm, realm.function_prototype, fn (mut vm VM) !Value {
		return js_undefined()
	}, fn [realm, parent] (mut vm VM, target &Object) !&Object {
		assert voidptr(vm.realm()) == voidptr(realm) && vm.argument_count() == 2
		return parent
	}, 0, PropertyName.from_str('HostNumberFormat')).object
	return BigIntLocaleDependencies{
		constructor_getter: fn [realm, constructor] (current &Realm) &Object {
			assert voidptr(current) == voidptr(realm)
			return constructor
		}
		format_numeric:     fn [parent] (formatter &Object, number Value) Utf16String {
			assert voidptr(formatter) == voidptr(parent) && number.is_bigint()
			return utf16_string('host Intl marker')
		}
	}
}

fn test_bigint_prototype_initialization_preserves_ordinary_record_source_order_and_descriptors() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	realm := vm.realm()
	parent := Object.create(realm, none)
	prototype := BigIntPrototype.create(mut vm, realm, parent, bigint_prototype_test_dependencies(mut vm,
		realm, parent)).object
	assert voidptr(prototype.internal_get_prototype_of()?) == voidptr(parent)
	assert prototype.bigint_object == none && prototype.class_name == 'BigIntPrototype'
	assert Value.from_object(prototype).str() == '[object BigIntPrototype]'
	if _ := call(mut vm, Value.from_object(prototype), js_null(), []Value{}) {
		assert false
	} else {
		assert thrown_value(err).as_object().error_message()?.str() == '[object BigIntPrototype] is not a function'
	}
	assert !Value.from_object(prototype).is_function()
	assert prototype.own_property_keys().map(it.str()) == ['toString', 'toLocaleString', 'valueOf',
		'Symbol(Symbol.toStringTag)']
	for name in ['toString', 'toLocaleString', 'valueOf'] {
		descriptor := prototype.internal_get_own_property(PropertyName.from_str(name))?
		assert descriptor.writable? && descriptor.configurable? && !descriptor.enumerable?
		method := descriptor.value?.as_object()
		assert method.get(mut vm, PropertyName.from_str('name'))!.as_string().str() == name
		assert method.get(mut vm, PropertyName.from_str('length'))!.number == 0
		assert voidptr(method.internal_get_prototype_of()?) == voidptr(realm.function_prototype_record())
		if _ := call(mut vm, Value.from_object(method), Value.from_object(prototype), []Value{}) {
			assert false
		} else {
			assert thrown_value(err).as_object().error_message()?.str() == 'Not an object of type BigInt'
		}
	}
	tag :=
		prototype.internal_get_own_property(PropertyName.from_symbol(vm.well_known_symbol_to_string_tag()))?
	assert tag.value?.as_string().str() == 'BigInt'
	assert !tag.writable? && !tag.enumerable? && tag.configurable?
	constructor := BigIntConstructor.create(mut vm, realm, prototype).object
	assert prototype.own_property_keys().map(it.str()) == ['toString', 'toLocaleString', 'valueOf',
		'constructor', 'Symbol(Symbol.toStringTag)']
	assert voidptr(prototype.get(mut vm, PropertyName.from_str('constructor'))!.as_object()) == voidptr(constructor)
}

fn test_bigint_records_cooperate_with_explicit_boxing_and_bound_prototype_calls() {
	mut vm := VM.create()
	base := create_simple_execution_context(mut vm)
	realm := vm.realm()
	parent := Object.create(realm, none)
	prototype := BigIntPrototype.create(mut vm, realm, parent, bigint_prototype_test_dependencies(mut vm,
		realm, parent)).object
	constructor := BigIntConstructor.create(mut vm, realm, prototype).object
	integer := call(mut vm, Value.from_object(constructor), js_null(), [
		Value.from_i32(42),
	])!
	primitives := PrimitiveObjectPrototypes{
		bigint: fn [prototype] (realm &Realm) &Object {
			return prototype
		}
	}
	wrapper := integer.to_object_with_prototypes(mut vm, primitives)!
	assert voidptr(wrapper.bigint_object?.bigint) == voidptr(integer.as_bigint())
	text := wrapper.get(mut vm, PropertyName.from_str('toString'))!
	assert call(mut vm, text, Value.from_object(wrapper), [Value.from_i32(16)])!.as_string().str() == '2a'
	assert integer.invoke_with_prototypes(mut vm, PropertyName.from_str('toString'), [
		Value.from_i32(2),
	], primitives)!.as_string().str() == '101010'
	bound := BoundFunction.create(realm, text.as_object(), Value.from_object(wrapper), [
		Value.from_i32(16),
	])
	assert call(mut vm, Value.from_object(bound.object), js_null(), []Value{})!.as_string().str() == '2a'
	value_of := wrapper.get(mut vm, PropertyName.from_str('valueOf'))!
	assert voidptr(call(mut vm, value_of, Value.from_object(wrapper), []Value{})!.as_bigint()) == voidptr(integer.as_bigint())
	assert Value.from_object(wrapper).to_bigint(mut vm)!.big_integer.str() == '42'
	primitive_text := Value.from_object(wrapper).to_primitive_string(mut vm)!
	assert primitive_text.str() == '42'
	assert vm.running_execution_context() == base && vm.interpreter_stack().depth() == 0
}

fn test_bigint_locale_record_uses_callee_realm_intrinsics_after_public_global_replacement() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	local := vm.realm()
	parent := Object.create(local, none)
	prototype := BigIntPrototype.create(mut vm, local, parent, bigint_prototype_test_dependencies(mut vm,
		local, parent)).object
	method := prototype.get(mut vm, PropertyName.from_str('toLocaleString'))!
	mut global := local.global_object_record()
	global.define_direct_property(PropertyName.from_str('Intl'), Value.from_i32(77), 7)
	foreign := create_simple_execution_context(mut vm)
	assert voidptr(foreign.realm?) != voidptr(local)
	integer := Value.from_bigint(string_to_bigint(utf16_string('42')) or { panic('fixture') })
	assert call(mut vm, method, integer, []Value{})!.as_string().str() == 'host Intl marker'
	assert vm.running_execution_context() == foreign && vm.interpreter_stack().depth() == 0
}
