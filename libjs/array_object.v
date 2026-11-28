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
	// Upper bound on own properties that are not array indices (names,
	// symbols, 2^32-1); see array_element_lookup.v.
	named_properties u32
}

pub fn ArrayObject.create(mut vm VM, realm &Realm, length u64, prototype &Object) !&ArrayObject {
	if length > 0xffffffff { return vm.throw_error_type(.range_error, .invalid_length, 'array') }
	mut object := Object.create(realm, prototype)
	object.class_name = 'Array'
	// The fresh array's virtual length descriptor reads these initialized slots.
	array := &ArrayObject{
		object: object
		realm:  realm
		length: u32(length)
	}
	object.array_object = array
	return array
}

pub fn ArrayObject.create_from(mut vm VM, realm &Realm, elements []Value, prototype &Object) !&ArrayObject {
	if use_fresh_array_storage() && u64(elements.len) < u64(0xffffffff) {
		array := ArrayObject.create(mut vm, realm, u64(elements.len), prototype)!
		mut object := array.object
		mut properties := []OwnProperty{len: elements.len}
		for index, value in elements {
			properties[index] = OwnProperty{key: PropertyName.from_number(u32(index)), value: value,
				writable: true, enumerable: true, configurable: true}
		}
		object.properties = properties
		record_fresh_array_storage()
		return array
	}
	array := ArrayObject.create(mut vm, realm, 0, prototype)!
	mut object := array.object
	for index, element in elements {
		defined := object.create_data_property_or_throw(mut vm, PropertyName.from_number(u32(index)),
			element)!
		assert defined
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

// Array.cpp::set_length follows the optimized ephemeral-property body.
// Values that require coercion go through both conversions before descriptor
// validation, since either can change the array's length or writability.
pub fn (mut array ArrayObject) set_length(mut vm VM, descriptor PropertyDescriptor) !bool {
	mut new_length := array.length
	if value := descriptor.value {
		mut number_length := f64(0)
		if value.is_number() {
			number_length = value.number
			// Guard the cast, including NaN, before checking for a fraction.
			if !(number_length >= 0 && number_length <= f64(0xffffffff)) {
				return vm.throw_error_type(.range_error, .invalid_length, 'array')
			}
			new_length = u32(number_length)
		} else {
			new_length = value.to_u32(mut vm)!
			number_length = value.to_number(mut vm)!.number
		}
		if f64(new_length) != number_length {
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
@[direct_array_access]
fn (mut array ArrayObject) set_array_like_size(new_length u32) bool {
	if new_length >= array.length {
		array.length = new_length
		return true
	}
	mut object := array.object
	mut highest_non_configurable := ?u32(none)
	mut removable := false
	for index in 0 .. object.properties.len {
		property := unsafe { &object.properties[index] }
		if property.key.is_number() && property.key.number >= new_length {
			if !property.configurable {
				if highest := highest_non_configurable {
					if property.key.number > highest { highest_non_configurable = property.key.number }
				} else {
					highest_non_configurable = property.key.number
				}
			} else {
				removable = true
			}
		}
	}
	boundary := if highest := highest_non_configurable { highest + 1 } else { new_length }
	// Compact in place, keeping order. Rebuilding the list on every shrink
	// made each pop() allocate and copy the whole array (and the arena kept
	// every copy).
	if removable {
		mut write := 0
		for read in 0 .. object.properties.len {
			property := object.properties[read]
			if property.key.is_number() && property.key.number >= boundary && property.configurable {
				continue
			}
			if write != read { object.properties[write] = property }
			write++
		}
		// A conservative collector also scans the unused capacity.
		for index in write .. object.properties.len { object.properties[index] = OwnProperty{} }
		unsafe {
			object.properties.len = write
		}
	}
	array.length = boundary
	return highest_non_configurable == none
}

pub fn (mut array ArrayObject) internal_define_own_property(mut vm VM, key PropertyName, descriptor PropertyDescriptor) !bool {
	if key.is_length_property() { return array.set_length(mut vm, descriptor) }
	if key.is_number() && key.number >= array.length && !array.length_writable { return false }
	mut object := array.object
	// Object.cpp::indexed_put, reached through ordinary descriptor storage,
	// updates the length only after a successful numeric-property definition.
	return object.ordinary_define_own_property(key, descriptor)
}

// Runtime/Value.cpp::IsArray. Revoked proxies throw even for non-array targets.
pub fn (value Value) is_array(mut vm VM) !bool {
	if !value.is_object() { return false }
	mut object := value.as_object()
	for {
		vm.consume_execution_budget()!
		if object.array_object != none { return true }
		proxy := object.proxy_object or { return false }
		object = proxy.operands(mut vm)!.target
	}
	return false
}
