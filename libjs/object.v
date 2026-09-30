module libjs

// Translated from the parts of LibJS/Runtime/Object.{h,cpp} and PropertyKey.h that
// the VM, environments, and error records depend on. Only ordinary objects with
// data and accessor properties are translated; shapes, proxies, and exotic hooks
// remain pending.
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

@[heap]
pub struct Object {
pub mut:
	prototype  ?&Object
	properties []OwnProperty
	extensible bool   = true
	class_name string = 'Object'
	// [[ErrorData]] for Error instances created through create_error().
	error_data ?&ErrorData
	// FunctionObject inheritance is represented by a callable implementation.
	callable            ?FunctionObject
	native_callable     bool
	native_initial_name ?Utf16String
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

// Object.cpp::OrdinaryGetPrototypeOf / OrdinarySetPrototypeOf. Every Object in
// this runtime slice uses ordinary internal methods; ProxyObject is pending.
pub fn (object &Object) internal_get_prototype_of() ?&Object {
	return object.prototype
}

pub fn (mut object Object) internal_set_prototype_of(new_prototype ?&Object) bool {
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
					object.define_property_or_throw(mut vm, key, PropertyDescriptor{ configurable: false })!
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
	// Object.cpp::OrdinaryOwnPropertyKeys: indices in ascending order, followed
	// by strings and then symbols in their respective creation orders.
	mut indices := []PropertyName{}
	mut strings := []PropertyName{}
	mut symbols := []PropertyName{}
	for property in object.properties {
		match property.key.kind {
			.number_key {
				indices << property.key
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
	indices << strings
	indices << symbols
	return indices
}

// 10.1.5 [[GetOwnProperty]] ( P ), https://tc39.es/ecma262/#sec-ordinary-object-internal-methods-and-internal-slots-getownproperty-p
pub fn (object &Object) internal_get_own_property(key PropertyName) ?PropertyDescriptor {
	index := object.find_own_property(key)
	if index < 0 {
		return none
	}
	property := object.properties[index]
	if property.value.is_accessor() {
		accessor := property.value.as_accessor()
		return PropertyDescriptor{
			getter: accessor_function_value(accessor.getter)
			setter: accessor_function_value(accessor.setter)
			enumerable: property.enumerable
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
pub fn (mut object Object) internal_define_own_property(key PropertyName, descriptor PropertyDescriptor) bool {
	return validate_and_apply_property_descriptor(&object, key, object.extensible,
		descriptor, object.internal_get_own_property(key))
}

// 10.1.7 [[HasProperty]] ( P ), https://tc39.es/ecma262/#sec-ordinary-object-internal-methods-and-internal-slots-hasproperty-p
pub fn (object &Object) internal_has_property(key PropertyName) bool {
	if object.find_own_property(key) >= 0 {
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
	return call(mut vm, getter, receiver, []Value{})
}

// 10.1.9 [[Set]] ( P, V, Receiver ), https://tc39.es/ecma262/#sec-ordinary-object-internal-methods-and-internal-slots-set-p-v-receiver
// 10.1.9.2 OrdinarySetWithOwnDescriptor.
pub fn (mut object Object) internal_set(mut vm VM, key PropertyName, value Value, receiver Value) !bool {
	assert !value.is_special_empty_value() && !receiver.is_special_empty_value()
	descriptor := object.internal_get_own_property(key) or {
		if parent := object.prototype {
			mut parent_object := unsafe { &Object(parent) }
			return parent_object.internal_set(mut vm, key, value, receiver)
		}
		PropertyDescriptor{ value: js_undefined(), writable: true, enumerable: true,
			configurable: true }
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
		return receiver_object.internal_define_own_property(key, PropertyDescriptor{
			value: value
		})
	}
	return receiver_object.create_data_property(key, value)
}

// 10.1.10 [[Delete]] ( P ), https://tc39.es/ecma262/#sec-ordinary-object-internal-methods-and-internal-slots-delete-p
pub fn (mut object Object) internal_delete(key PropertyName) bool {
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
	return object.find_own_property(key) >= 0
}

// Object.cpp::get_without_side_effects: diagnostics inspect stored values,
// including internal Accessor cells, without invoking callable properties.
pub fn (object &Object) get_without_side_effects(key PropertyName) Value {
	mut current := ?&Object(object)
	for {
		holder := current or { return js_special_empty_value() }
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
pub fn (mut object Object) create_data_property(key PropertyName, value Value) bool {
	return object.internal_define_own_property(key, PropertyDescriptor{
		value:        value
		writable:     true
		enumerable:   true
		configurable: true
	})
}

// 7.3.7 CreateDataPropertyOrThrow ( O, P, V ), https://tc39.es/ecma262/#sec-createdatapropertyorthrow
pub fn (mut object Object) create_data_property_or_throw(mut vm VM, key PropertyName, value Value) !bool {
	success := object.create_data_property(key, value)
	if !success {
		return vm.throw_error_type(.type_error, .object_define_own_property_returned_false)
	}
	return success
}

// 7.3.9 DefinePropertyOrThrow ( O, P, desc ), https://tc39.es/ecma262/#sec-definepropertyorthrow
pub fn (mut object Object) define_property_or_throw(mut vm VM, key PropertyName, descriptor PropertyDescriptor) ! {
	success := object.internal_define_own_property(key, descriptor)
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
