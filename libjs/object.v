module libjs

// Translated from the parts of LibJS/Runtime/Object.{h,cpp} and PropertyKey.h that
// the VM, environments, and error records depend on. Ordinary and array exotic
// properties plus String/Boolean/Symbol internal slots are translated; shapes, proxies,
// and other exotic hooks remain pending.
// The parser owns the name PropertyKey, so the runtime key is PropertyName.

pub enum PropertyNameKind {
	string_key
	symbol_key
	number_key
}

pub struct PropertyName {
pub:
	kind         PropertyNameKind = .string_key
	string_value Utf16String
	symbol       ?&Symbol
	number       u32
}

pub fn PropertyName.from_utf16(name Utf16String) PropertyName {
	// Runtime/PropertyKey.h: canonical decimal indices share numeric storage
	// with integer keys. Leading zeros and 2^32-1 remain string keys.
	if name.data.len > 0 && name.data[0] >= u16(`0`) && name.data[0] <= u16(`9`)
		&& !(name.data[0] == u16(`0`) && name.data.len > 1) {
		mut number := u64(0)
		mut valid := true
		for unit in name.data {
			if unit < u16(`0`) || unit > u16(`9`) {
				valid = false
				break
			}
			number = number * 10 + u64(unit - u16(`0`))
			if number >= 0xffffffff {
				valid = false
				break
			}
		}
		if valid { return PropertyName.from_number(u32(number)) }
	}
	return PropertyName{
		kind:         .string_key
		string_value: name
	}
}

pub fn PropertyName.from_str(name string) PropertyName {
	return PropertyName.from_utf16(utf16_string(name))
}

pub fn PropertyName.from_symbol(symbol &Symbol) PropertyName {
	return PropertyName{
		kind:   .symbol_key
		symbol: symbol
	}
}

pub fn PropertyName.from_number(number u32) PropertyName {
	if number == 0xffffffff { return PropertyName.from_utf16(utf16_string(number.str())) }
	return PropertyName{
		kind:   .number_key
		number: number
	}
}

pub fn (name PropertyName) is_string() bool {
	return name.kind == .string_key
}

pub fn (name PropertyName) is_symbol() bool {
	return name.kind == .symbol_key
}

pub fn (name PropertyName) is_number() bool {
	return name.kind == .number_key
}

pub fn (name PropertyName) as_string() Utf16String {
	if name.kind != .string_key {
		panic('PropertyName.as_string() called on a ${name.kind} key')
	}
	return name.string_value
}

pub fn (name PropertyName) as_symbol() &Symbol {
	return name.symbol or { panic('PropertyName.as_symbol() called on a ${name.kind} key') }
}

pub fn (a PropertyName) equals(b PropertyName) bool {
	if a.kind != b.kind {
		return false
	}
	return match a.kind {
		.string_key { a.string_value == b.string_value }
		.number_key { a.number == b.number }
		.symbol_key { voidptr(a.as_symbol()) == voidptr(b.as_symbol()) }
	}
}

pub fn (name PropertyName) str() string {
	return match name.kind {
		.string_key { name.string_value.str() }
		.number_key { name.number.str() }
		.symbol_key { name.as_symbol().descriptive_string().str() }
	}
}

pub const attribute_writable = u8(1)
pub const attribute_enumerable = u8(2)
pub const attribute_configurable = u8(4)

pub struct OwnProperty {
pub mut:
	key          PropertyName
	value        Value
	writable     bool
	enumerable   bool
	configurable bool
}

pub enum ShouldThrowExceptions {
	no
	yes
}

pub enum IntegrityLevel {
	sealed
	frozen
}

// WebIDL legacy platform objects supply live indexed properties without
// copying their native collection into an ordinary JavaScript array.
pub interface HostProperties {
	get_own_property(key PropertyName) ?PropertyDescriptor
	own_property_keys() []PropertyName
}

@[heap]
pub struct Object {
pub mut:
	prototype  ?&Object
	properties []OwnProperty
	private_elements []PrivateElement // [[PrivateElements]], separate from own properties
	extensible bool   = true
	class_name string = 'Object'
	// ObjectPrototype's immutable-prototype exotic [[SetPrototypeOf]] override.
	// The intrinsic record that selects this override remains a separate slice.
	immutable_prototype bool
	// [[ErrorData]] for Error instances created through create_error().
	error_data ?&ErrorData
	// FunctionObject inheritance is represented by a callable implementation.
	callable             ?FunctionObject
	constructor          ?ConstructorFunction
	native_callable      bool
	native_initial_name  ?Utf16String
	bound_function       ?&BoundFunction
	function_source_text ?Utf16String // [[SourceText]] on ECMAScript callables
	regexp_object ?&RegExpObject
	host_properties ?HostProperties
	array_object         ?&ArrayObject
	boolean_object       ?&BooleanObject // [[BooleanData]]
	number_object        ?&NumberObject  // [[NumberData]]
	bigint_object        ?&BigIntObject  // [[BigIntData]]
	symbol_object        ?&SymbolObject // [[SymbolData]]
	string_object        ?&StringObject // [[StringData]] and virtual indexed properties
	string_iterator      ?&StringIterator
	array_iterator       ?&ArrayIterator
	array_buffer         ?&ArrayBufferObject
	data_view            ?&DataView
	typed_array          ?&TypedArray
}

// 10.1.12 OrdinaryObjectCreate ( proto [ , additionalInternalSlotsList ] ), https://tc39.es/ecma262/#sec-ordinaryobjectcreate
// The realm is reserved for intrinsic-backed shapes, which are not translated yet.
pub fn Object.create(realm &Realm, prototype ?&Object) &Object {
	return &Object{
		prototype: prototype
	}
}

fn (object &Object) find_own_property(key PropertyName) int {
	for index, property in object.properties {
		if property.key.equals(key) {
			return index
		}
	}
	return -1
}

// Object.cpp::OrdinaryGetPrototypeOf / OrdinarySetPrototypeOf, with the
// ObjectPrototype immutable-prototype override. ProxyObject is pending.
pub fn (object &Object) internal_get_prototype_of() ?&Object {
	return object.prototype
}

pub fn (mut object Object) internal_set_prototype_of(new_prototype ?&Object) bool {
	if object.immutable_prototype { return object.set_immutable_prototype(new_prototype) }
	if current := object.prototype {
		if proposed := new_prototype {
			if voidptr(current) == voidptr(proposed) { return true }
		}
	} else if new_prototype == none {
		return true
	}
	if !object.extensible { return false }
	mut prototype := new_prototype
	for {
		current := prototype or { break }
		if voidptr(current) == voidptr(&object) { return false }
		prototype = current.prototype
	}
	object.prototype = new_prototype
	return true
}

// 10.1.3 [[IsExtensible]] and 10.1.4 [[PreventExtensions]].
pub fn (object &Object) internal_is_extensible() bool {
	return object.extensible
}

pub fn (mut object Object) internal_prevent_extensions() bool {
	if array := object.typed_array { if !is_typed_array_fixed_length(array) { return false } }
	object.extensible = false
	return true
}

// 7.3.16 SetIntegrityLevel ( O, level ).
pub fn (mut object Object) set_integrity_level(mut vm VM, level IntegrityLevel) !bool {
	if !object.internal_prevent_extensions() { return false }
	keys := object.own_property_keys()
	if level == .sealed {
		for key in keys {
			object.define_property_or_throw(mut vm, key, PropertyDescriptor{ configurable: false })!
		}
	} else {
		for key in keys {
			if current := object.internal_get_own_property(key) {
				if current.is_accessor_descriptor() {
					object.define_property_or_throw(mut vm, key, PropertyDescriptor{
						configurable: false
					})!
					continue
				}
				object.define_property_or_throw(mut vm, key, PropertyDescriptor{
					writable:     false
					configurable: false
				})!
			}
		}
	}
	return true
}

// 7.3.17 TestIntegrityLevel ( O, level ).
pub fn (object &Object) test_integrity_level(level IntegrityLevel) bool {
	if object.internal_is_extensible() { return false }
	for key in object.own_property_keys() {
		if descriptor := object.internal_get_own_property(key) {
			if descriptor.configurable or { false } { return false }
			if level == .frozen && descriptor.is_data_descriptor() && (descriptor.writable or {
				false
			}) {
				return false
			}
		}
	}
	return true
}

pub fn (object &Object) is_error_object() bool {
	return object.error_data != none
}

pub fn (object &Object) own_property_keys() []PropertyName {
	if host := object.host_properties {
		mut keys := host.own_property_keys()
		for property in object.properties { if !keys.any(it.equals(property.key)) { keys << property.key } }
		return keys
	}
	if array := object.typed_array { return array.own_property_keys() }
	// Object.cpp::OrdinaryOwnPropertyKeys: indices in ascending order, followed
	// by strings and then symbols in their respective creation orders.
	mut indices := []PropertyName{}
	string_length := if text := object.string_object { text.value.utf16.len() } else { 0 }
	mut strings := if object.array_object != none {
		[PropertyName.from_str('length')]
	} else {
		[]PropertyName{}
	}
	mut symbols := []PropertyName{}
	for property in object.properties {
		match property.key.kind {
			.number_key {
				if u64(property.key.number) >= u64(string_length) { indices << property.key }
			}
			.string_key {
				strings << property.key
			}
			.symbol_key {
				if !property.key.as_symbol().is_private() { symbols << property.key }
			}
		}
	}
	indices.sort(a.number < b.number)
	if string_length > 0 {
		mut characters := []PropertyName{cap: string_length + indices.len}
		for index in 0 .. string_length { characters << PropertyName.from_number(u32(index)) }
		characters << indices
		indices = unsafe { characters }
	}
	indices << strings
	indices << symbols
	return indices
}

// 10.1.5 [[GetOwnProperty]] ( P ), https://tc39.es/ecma262/#sec-ordinary-object-internal-methods-and-internal-slots-getownproperty-p
pub fn (object &Object) internal_get_own_property(key PropertyName) ?PropertyDescriptor {
	if host := object.host_properties { if descriptor := host.get_own_property(key) { return descriptor } }
	if array := object.typed_array {
		if index := typed_array_property_index(key) {
			value := typed_array_get_element(array, index)
			if value.is_undefined() { return none }
			return PropertyDescriptor{value: value, writable: true, enumerable: true, configurable: true}
		}
	}
	if array := object.array_object {
		if key.equals(PropertyName.from_str('length')) { return array.length_descriptor() }
	}
	index := object.find_own_property(key)
	if index < 0 {
		if text := object.string_object { return text.character_descriptor(key) }
		return none
	}
	property := object.properties[index]
	if property.value.is_accessor() {
		accessor := property.value.as_accessor()
		return PropertyDescriptor{
			getter:       accessor_function_value(accessor.getter)
			setter:       accessor_function_value(accessor.setter)
			enumerable:   property.enumerable
			configurable: property.configurable
		}
	}
	return PropertyDescriptor{
		value:        property.value
		writable:     property.writable
		enumerable:   property.enumerable
		configurable: property.configurable
	}
}

// 10.1.6 [[DefineOwnProperty]] ( P, Desc ), https://tc39.es/ecma262/#sec-ordinary-object-internal-methods-and-internal-slots-defineownproperty-p-desc
pub fn (mut object Object) internal_define_own_property(mut vm VM, key PropertyName, descriptor PropertyDescriptor) !bool {
	if mut array := object.typed_array { return array.internal_define_own_property(mut vm, key, descriptor) }
	if mut array := object.array_object {
		return array.internal_define_own_property(mut vm, key, descriptor)
	}
	if text := object.string_object {
		if character := text.character_descriptor(key) {
			return is_compatible_property_descriptor(object.extensible, descriptor, character)
		}
	}
	return object.ordinary_define_own_property(key, descriptor)
}

fn (mut object Object) ordinary_define_own_property(key PropertyName, descriptor PropertyDescriptor) bool {
	return validate_and_apply_property_descriptor(&object, key, object.extensible, descriptor,
		object.internal_get_own_property(key))
}

// 10.1.7 [[HasProperty]] ( P ), https://tc39.es/ecma262/#sec-ordinary-object-internal-methods-and-internal-slots-hasproperty-p
pub fn (object &Object) internal_has_property(key PropertyName) bool {
	if array := object.typed_array {
		if index := typed_array_property_index(key) { return is_valid_integer_index(array, index) }
	}
	if object.internal_get_own_property(key) != none {
		return true
	}
	if parent := object.prototype {
		return parent.internal_has_property(key)
	}
	return false
}

// 10.1.8 [[Get]] ( P, Receiver ), https://tc39.es/ecma262/#sec-ordinary-object-internal-methods-and-internal-slots-get-p-receiver
pub fn (object &Object) internal_get(mut vm VM, key PropertyName, receiver Value) !Value {
	assert !receiver.is_special_empty_value()
	if array := object.typed_array {
		if index := typed_array_property_index(key) { return typed_array_get_element(array, index) }
	}
	descriptor := object.internal_get_own_property(key) or {
		if parent := object.prototype {
			if vm.did_reach_stack_space_limit() {
				return vm.throw_error_type(.internal_error, .call_stack_size_exceeded)
			}
			return parent.internal_get(mut vm, key, receiver)
		}
		return js_undefined()
	}
	if descriptor.is_data_descriptor() { return descriptor.value or { js_undefined() } }
	assert descriptor.is_accessor_descriptor()
	getter := descriptor.getter or { js_undefined() }
	if getter.is_undefined() { return js_undefined() }
	// Object.cpp retains cached values on the holder, for that holder and
	// receivers whose direct prototype is the holder. Deeper/foreign receivers
	// call the getter without reading or populating that shared cache.
	index := object.find_own_property(key)
	// A host descriptor may have no ordinary property cell, or override a
	// data/accessor cell. Only the matching owned Accessor carries cache state.
	if index<0 || !object.properties[index].value.is_accessor() {
		return call(mut vm,getter,receiver,[]Value{})
	}
	accessor := object.properties[index].value.as_accessor()
	if !same_value(getter,accessor_function_value(accessor.getter)) {
		return call(mut vm,getter,receiver,[]Value{})
	}
	mut receiver_uses_holder_cache := false
	if receiver.is_object() {
		receiver_object := receiver.as_object()
		receiver_uses_holder_cache = voidptr(receiver_object) == voidptr(object)
		if parent := receiver_object.prototype {
			receiver_uses_holder_cache = receiver_uses_holder_cache || voidptr(parent) == voidptr(object)
		}
	}
	if cached_key := accessor.cached_value_key {
		if receiver_uses_holder_cache {
			if cached := object.get_engine_private_property(cached_key) { return cached.value }
		}
	}
	result := call(mut vm, getter, receiver, []Value{})!
	if receiver_uses_holder_cache {
		if cached_key := accessor.cached_value_key {
			current_index := object.find_own_property(key)
			if current_index >= 0 {
				value := object.properties[current_index].value
				// A getter may delete or replace itself. Only the same Accessor
				// cell may publish the value under its private cache key.
				if value.is_accessor() && voidptr(value.as_accessor()) == voidptr(accessor) {
					mut holder := unsafe { &Object(object) }
					holder.set_engine_private_property(cached_key, result)
				}
			}
		}
	}
	return result
}

// 10.1.9 [[Set]] ( P, V, Receiver ), https://tc39.es/ecma262/#sec-ordinary-object-internal-methods-and-internal-slots-set-p-v-receiver
// 10.1.9.2 OrdinarySetWithOwnDescriptor.
pub fn (mut object Object) internal_set(mut vm VM, key PropertyName, value Value, receiver Value) !bool {
	assert !value.is_special_empty_value() && !receiver.is_special_empty_value()
	if mut array := object.typed_array {
		if index := typed_array_property_index(key) {
			if same_value(Value.from_object(&object), receiver) {
				typed_array_set_element(mut vm, mut array, index, value)!
				return true
			}
			if !is_valid_integer_index(array, index) { return true }
		}
	}
	descriptor := object.internal_get_own_property(key) or {
		if parent := object.prototype {
			mut parent_object := unsafe { &Object(parent) }
			return parent_object.internal_set(mut vm, key, value, receiver)
		}
		PropertyDescriptor{
			value:        js_undefined()
			writable:     true
			enumerable:   true
			configurable: true
		}
	}
	if descriptor.is_accessor_descriptor() {
		setter := descriptor.setter or { js_undefined() }
		if setter.is_undefined() { return false }
		call(mut vm, setter, receiver, [value])!
		return true
	}
	if !(descriptor.writable or { false }) { return false }
	if !receiver.is_object() {
		return false
	}
	mut receiver_object := receiver.as_object()
	if existing := receiver_object.internal_get_own_property(key) {
		if existing.is_accessor_descriptor() || !(existing.writable or { false }) {
			return false
		}
		return receiver_object.internal_define_own_property(mut vm, key, PropertyDescriptor{
			value: value
		})
	}
	return receiver_object.create_data_property(mut vm, key, value)
}

// 10.1.10 [[Delete]] ( P ), https://tc39.es/ecma262/#sec-ordinary-object-internal-methods-and-internal-slots-delete-p
pub fn (mut object Object) internal_delete(key PropertyName) bool {
	if array := object.typed_array {
		if index := typed_array_property_index(key) { return !is_valid_integer_index(array, index) }
	}
	if descriptor := object.internal_get_own_property(key) {
		if !(descriptor.configurable or { false }) { return false }
	}
	index := object.find_own_property(key)
	if index < 0 {
		return true
	}
	if !object.properties[index].configurable {
		return false
	}
	object.properties.delete(index)
	return true
}

// 7.3.12 HasProperty ( O, P ), https://tc39.es/ecma262/#sec-hasproperty
pub fn (object &Object) has_property(key PropertyName) bool {
	return object.internal_has_property(key)
}

// 7.3.13 HasOwnProperty ( O, P ), https://tc39.es/ecma262/#sec-hasownproperty
pub fn (object &Object) has_own_property(key PropertyName) bool {
	return object.internal_get_own_property(key) != none
}

// Object.cpp::get_without_side_effects: diagnostics inspect stored values,
// including internal Accessor cells, without invoking callable properties.
pub fn (object &Object) get_without_side_effects(key PropertyName) Value {
	mut current := ?&Object(object)
	for {
		holder := current or { return js_special_empty_value() }
		if array := holder.array_object {
			if key.equals(PropertyName.from_str('length')) {
				return Value.from_f64(f64(array.length))
			}
		}
		index := holder.find_own_property(key)
		if index >= 0 { return holder.properties[index].value }
		current = holder.prototype
	}
	return js_special_empty_value()
}

// 7.3.2 Get ( O, P ), https://tc39.es/ecma262/#sec-get-o-p
pub fn (object &Object) get(mut vm VM, key PropertyName) !Value {
	return object.internal_get(mut vm, key, Value.from_object(object))
}

// 7.3.4 Set ( O, P, V, Throw ), https://tc39.es/ecma262/#sec-set-o-p-v-throw
pub fn (mut object Object) set(mut vm VM, key PropertyName, value Value, throw_exceptions ShouldThrowExceptions) ! {
	success := object.internal_set(mut vm, key, value, Value.from_object(object))!
	if !success && throw_exceptions == .yes {
		return vm.throw_error_type(.type_error, .object_set_returned_false)
	}
}

// 7.3.5 CreateDataProperty ( O, P, V ), https://tc39.es/ecma262/#sec-createdataproperty
pub fn (mut object Object) create_data_property(mut vm VM, key PropertyName, value Value) !bool {
	return object.internal_define_own_property(mut vm, key, PropertyDescriptor{
		value:        value
		writable:     true
		enumerable:   true
		configurable: true
	})
}

// 7.3.7 CreateDataPropertyOrThrow ( O, P, V ), https://tc39.es/ecma262/#sec-createdatapropertyorthrow
pub fn (mut object Object) create_data_property_or_throw(mut vm VM, key PropertyName, value Value) !bool {
	success := object.create_data_property(mut vm, key, value)!
	if !success {
		return vm.throw_error_type(.type_error, .object_define_own_property_returned_false)
	}
	return success
}

// 7.3.9 DefinePropertyOrThrow ( O, P, desc ), https://tc39.es/ecma262/#sec-definepropertyorthrow
pub fn (mut object Object) define_property_or_throw(mut vm VM, key PropertyName, descriptor PropertyDescriptor) ! {
	success := object.internal_define_own_property(mut vm, key, descriptor)!
	if !success {
		return vm.throw_error_type(.type_error, .object_define_own_property_returned_false)
	}
}

// 7.3.10 DeletePropertyOrThrow ( O, P ), https://tc39.es/ecma262/#sec-deletepropertyorthrow
pub fn (mut object Object) delete_property_or_throw(mut vm VM, key PropertyName) ! {
	success := object.internal_delete(key)
	if !success {
		return vm.throw_error_type(.type_error, .object_delete_returned_false)
	}
}

// Object::define_direct_property: installs a data property without validation.
pub fn (mut object Object) define_direct_property(key PropertyName, value Value, attributes u8) {
	if mut array := object.array_object {
		// Object.cpp::storage_set/indexed_put grows the magical array length
		// even when an engine-private caller bypasses descriptor validation.
		assert !key.equals(PropertyName.from_str('length'))
		if key.is_number() && key.number >= array.length { array.length = key.number + 1 }
	}
	property := OwnProperty{
		key:          key
		value:        value
		writable:     attributes & attribute_writable != 0
		enumerable:   attributes & attribute_enumerable != 0
		configurable: attributes & attribute_configurable != 0
	}
	index := object.find_own_property(key)
	if index >= 0 {
		object.properties[index] = property
		return
	}
	object.properties << property
}
