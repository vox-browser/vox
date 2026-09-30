module libjs

// Runtime/Object.cpp::define_{native,direct,cached}_accessor and engine-private
// property storage. V heap records replace Shape offsets. Intrinsic function
// prototypes are supplied by the embedding until the Intrinsics graph exists.
pub fn (mut object Object) define_native_accessor(mut vm VM, realm &Realm, key PropertyName, getter NativeFunctionPointer, setter NativeFunctionPointer, attributes u8, function_prototype ?&Object) {
	mut getter_function := ?&Object(none)
	mut setter_function := ?&Object(none)
	if getter != unsafe { nil } {
		function := NativeFunction.create(mut vm, realm, function_prototype, getter, 0, key, 'get')
		getter_function = function.object
	}
	if setter != unsafe { nil } {
		function := NativeFunction.create(mut vm, realm, function_prototype, setter, 1, key, 'set')
		setter_function = function.object
	}
	object.define_direct_accessor(key, getter_function, setter_function, attributes)
}

pub fn (mut object Object) define_direct_accessor(key PropertyName, getter ?&Object, setter ?&Object, attributes u8) {
	index := object.find_own_property(key)
	if index >= 0 && object.properties[index].value.is_accessor() {
		mut accessor := object.properties[index].value.as_accessor()
		// This host helper augments an existing accessor. Absent callbacks leave
		// it unchanged; JavaScript descriptor updates use DefineOwnProperty.
		if function := getter { accessor.set_getter(function) }
		if function := setter { accessor.set_setter(function) }
		return
	}
	object.define_direct_property(key, Value.from_accessor(Accessor.create(getter, setter, none)),
		attributes)
}

pub fn (object &Object) get_engine_private_property(key &Symbol) ?OwnProperty {
	assert key.is_private()
	index := object.find_own_property(PropertyName.from_symbol(key))
	if index < 0 { return none }
	return object.properties[index]
}

pub fn (mut object Object) set_engine_private_property(key &Symbol, value Value) {
	assert key.is_private()
	object.define_direct_property(PropertyName.from_symbol(key), value, 0)
}

pub fn (mut object Object) delete_engine_private_property(key &Symbol) {
	assert key.is_private()
	index := object.find_own_property(PropertyName.from_symbol(key))
	if index >= 0 { object.properties.delete(index) }
}

pub fn (mut object Object) define_direct_cached_accessor(key PropertyName, getter ?&Object, setter ?&Object, attributes u8) {
	object.clear_cached_accessor_value(key)
	object.define_direct_accessor(key, getter, setter, attributes)
	index := object.find_own_property(key)
	assert index >= 0 && object.properties[index].value.is_accessor()
	mut accessor := object.properties[index].value.as_accessor()
	if accessor.cached_value_key == none {
		accessor.set_cached_value_key(Symbol.create_private())
	}
}

pub fn (mut object Object) clear_cached_accessor_value(key PropertyName) {
	index := object.find_own_property(key)
	if index < 0 || !object.properties[index].value.is_accessor() { return }
	accessor := object.properties[index].value.as_accessor()
	if cached_key := accessor.cached_value_key {
		object.delete_engine_private_property(cached_key)
	}
}
