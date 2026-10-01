module libjs

// Runtime/Array.{h,cpp}: ArrayCreate, CreateArrayFromList and the array exotic
// property methods. The caller supplies the prototype while Array intrinsics
// are pending. Ordinary property storage replaces the indexed storage tiers.
@[heap]
pub struct ArrayObject {
pub:
	object &Object
	realm  &Realm
pub mut:
	length          u32
	length_writable bool = true
}

pub fn ArrayObject.create(mut vm VM, realm &Realm, length u64, prototype &Object) !&ArrayObject {
	if length > 0xffffffff { return vm.throw_error_type(.range_error, .invalid_length, 'array') }
	mut object := Object.create(realm, prototype)
	object.class_name = 'Array'
	array := &ArrayObject{
		object: object
		realm:  realm
	}
	object.array_object = array
	assert object.internal_define_own_property(mut vm, PropertyName.from_str('length'), PropertyDescriptor{
		value:        Value.from_f64(f64(length))
		writable:     true
		enumerable:   false
		configurable: false
	})!
	return array
}

pub fn ArrayObject.create_from(mut vm VM, realm &Realm, elements []Value, prototype &Object) !&ArrayObject {
	array := ArrayObject.create(mut vm, realm, 0, prototype)!
	mut object := array.object
	for index, element in elements {
		assert object.create_data_property_or_throw(mut vm, PropertyName.from_number(u32(index)),
			element)!
	}
	return array
}

pub fn (array &ArrayObject) length_descriptor() PropertyDescriptor {
	return PropertyDescriptor{
		value:        Value.from_f64(f64(array.length))
		writable:     array.length_writable
		enumerable:   false
		configurable: false
	}
}

// Array.cpp::set_length follows the optimized ephemeral-property body. Both
// numeric conversions happen before descriptor validation, and a coercion may
// change the old length/writability before those checks run.
pub fn (mut array ArrayObject) set_length(mut vm VM, descriptor PropertyDescriptor) !bool {
	mut new_length := array.length
	if value := descriptor.value {
		new_length = value.to_u32(mut vm)!
		number_length := value.to_number(mut vm)!
		if f64(new_length) != number_length.number {
			return vm.throw_error_type(.range_error, .invalid_length, 'array')
		}
	}
	new_writable := descriptor.writable or { true }
	if descriptor.configurable or { false } { return false }
	if descriptor.enumerable or { false } { return false }
	if !descriptor.is_generic_descriptor() && descriptor.is_accessor_descriptor() { return false }
	if !array.length_writable {
		if descriptor.writable or { false } { return false }
		if new_length != array.length { return false }
	}
	success := array.set_array_like_size(new_length)
	if !new_writable { array.length_writable = false }
	return success
}

// IndexedProperties.cpp::GenericIndexedPropertyStorage::set_array_like_size:
// retain the highest non-configurable index, delete only the configurable
// entries above that boundary, and publish the resulting length on failure.
fn (mut array ArrayObject) set_array_like_size(new_length u32) bool {
	if new_length >= array.length {
		array.length = new_length
		return true
	}
	mut highest_non_configurable := ?u32(none)
	for property in array.object.properties {
		if property.key.is_number() && property.key.number >= new_length && !property.configurable {
			if highest := highest_non_configurable {
				if property.key.number > highest { highest_non_configurable = property.key.number }
			} else {
				highest_non_configurable = property.key.number
			}
		}
	}
	boundary := if highest := highest_non_configurable { highest + 1 } else { new_length }
	mut kept := []OwnProperty{cap: array.object.properties.len}
	for property in array.object.properties {
		if property.key.is_number() && property.key.number >= boundary && property.configurable {
			continue
		}
		kept << property
	}
	mut object := array.object
	object.properties = kept
	array.length = boundary
	return highest_non_configurable == none
}

pub fn (mut array ArrayObject) internal_define_own_property(mut vm VM, key PropertyName, descriptor PropertyDescriptor) !bool {
	if key.equals(PropertyName.from_str('length')) { return array.set_length(mut vm, descriptor) }
	if key.is_number() && key.number >= array.length && !array.length_writable { return false }
	mut object := array.object
	// Object.cpp::indexed_put, reached through ordinary descriptor storage,
	// updates the length only after a successful numeric-property definition.
	return object.ordinary_define_own_property(key, descriptor)
}

// Runtime/Value.cpp::IsArray. Proxy validation belongs to the pending Proxy
// exotic record; all concrete objects currently available use this path.
pub fn (value Value) is_array(mut vm VM) !bool {
	if !value.is_object() { return false }
	return value.as_object().array_object != none
}
