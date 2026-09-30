module libjs

// Runtime/PropertyDescriptor.{h,cpp}. Optional Value fields distinguish an
// omitted getter/setter from a present JavaScript undefined value. Present
// getter/setter fields must contain a callable object or undefined.
pub struct PropertyDescriptor {
pub mut:
	value        ?Value
	getter       ?Value
	setter       ?Value
	writable     ?bool
	enumerable   ?bool
	configurable ?bool
}

pub fn (descriptor PropertyDescriptor) is_accessor_descriptor() bool {
	return descriptor.getter != none || descriptor.setter != none
}

pub fn (descriptor PropertyDescriptor) is_data_descriptor() bool {
	return descriptor.value != none || descriptor.writable != none
}

pub fn (descriptor PropertyDescriptor) is_generic_descriptor() bool {
	return !descriptor.is_accessor_descriptor() && !descriptor.is_data_descriptor()
}

pub fn (descriptor PropertyDescriptor) is_empty() bool {
	return descriptor.is_generic_descriptor() && descriptor.enumerable == none
		&& descriptor.configurable == none
}

pub fn (mut descriptor PropertyDescriptor) complete() {
	if descriptor.is_generic_descriptor() || descriptor.is_data_descriptor() {
		if descriptor.value == none { descriptor.value = js_undefined() }
		if descriptor.writable == none { descriptor.writable = false }
	} else {
		if descriptor.getter == none { descriptor.getter = js_undefined() }
		if descriptor.setter == none { descriptor.setter = js_undefined() }
	}
	if descriptor.enumerable == none { descriptor.enumerable = false }
	if descriptor.configurable == none { descriptor.configurable = false }
}

pub fn (descriptor PropertyDescriptor) attributes() u8 {
	mut attributes := u8(0)
	if descriptor.writable or { false } { attributes |= attribute_writable }
	if descriptor.enumerable or { false } { attributes |= attribute_enumerable }
	if descriptor.configurable or { false } { attributes |= attribute_configurable }
	return attributes
}

// AbstractOperations.cpp::IsCompatiblePropertyDescriptor.
pub fn is_compatible_property_descriptor(extensible bool, descriptor PropertyDescriptor, current ?PropertyDescriptor) bool {
	return validate_and_apply_property_descriptor(none, PropertyName.from_str(''), extensible,
		descriptor, current)
}

// AbstractOperations.cpp::ValidateAndApplyPropertyDescriptor. Property storage
// is the translated ordinary object's list rather than upstream Shape slots.
pub fn validate_and_apply_property_descriptor(object ?&Object, key PropertyName, extensible bool, descriptor PropertyDescriptor, current ?PropertyDescriptor) bool {
	assert !(descriptor.is_accessor_descriptor() && descriptor.is_data_descriptor())
	if current == none {
		if !extensible { return false }
		if target := object {
			mut receiver := unsafe { &Object(target) }
			value := if descriptor.is_accessor_descriptor() {
				Value.from_accessor(Accessor.create(accessor_function(descriptor.getter or {
					js_undefined()
				}), accessor_function(descriptor.setter or { js_undefined() }), none))
			} else {
				descriptor.value or { js_undefined() }
			}
			receiver.define_direct_property(key, value, descriptor.attributes())
		}
		return true
	}
	previous := current
	if descriptor.is_empty() { return true }
	if !(previous.configurable or { false }) {
		if descriptor.configurable or { false } { return false }
		if enumerable := descriptor.enumerable {
			if enumerable != (previous.enumerable or { false }) { return false }
		}
		if !descriptor.is_generic_descriptor()
			&& descriptor.is_accessor_descriptor() != previous.is_accessor_descriptor() {
			return false
		}
		if previous.is_accessor_descriptor() {
			if getter := descriptor.getter {
				if !same_value(getter, previous.getter or { js_undefined() }) { return false }
			}
			if setter := descriptor.setter {
				if !same_value(setter, previous.setter or { js_undefined() }) { return false }
			}
		} else if !(previous.writable or { false }) {
			if descriptor.writable or { false } { return false }
			if value := descriptor.value {
				if !same_value(value, previous.value or { js_undefined() }) { return false }
			}
		}
	}
	if target := object {
		mut receiver := unsafe { &Object(target) }
		mut applied := descriptor
		if previous.is_data_descriptor() && descriptor.is_accessor_descriptor() {
			applied.complete()
		} else if previous.is_accessor_descriptor() && descriptor.is_data_descriptor() {
			applied.complete()
		} else if descriptor.is_accessor_descriptor()
			|| (previous.is_accessor_descriptor() && !descriptor.is_data_descriptor()) {
			applied.getter = descriptor.getter or { previous.getter or { js_undefined() } }
			applied.setter = descriptor.setter or { previous.setter or { js_undefined() } }
		} else {
			applied.value = descriptor.value or { previous.value or { js_undefined() } }
			applied.writable = descriptor.writable or { previous.writable or { false } }
		}
		// Enumerable/configurable survive a descriptor-kind transition unless
		// explicitly supplied, even though complete() filled default fields.
		applied.enumerable = descriptor.enumerable or { previous.enumerable or { false } }
		applied.configurable = descriptor.configurable or { previous.configurable or { false } }
		value := if applied.is_accessor_descriptor() {
			Value.from_accessor(Accessor.create(accessor_function(applied.getter or {
				js_undefined()
			}), accessor_function(applied.setter or { js_undefined() }), none))
		} else {
			applied.value or { js_undefined() }
		}
		receiver.define_direct_property(key, value, applied.attributes())
	}
	return true
}
