module libjs

struct NameAndPropertyDescriptor {
	key        PropertyName
	descriptor PropertyDescriptor
}

// Runtime/Object.cpp::ObjectDefineProperties, after the caller's ToObject
// conversion. Accepting an Object keeps primitive wrapper creation at the
// untranslated Intrinsics boundary instead of substituting a host algorithm.
pub fn (mut object Object) define_properties(mut vm VM, properties &Object) !&Object {
	keys := properties.own_property_keys()
	mut descriptors := []NameAndPropertyDescriptor{}
	for key in keys {
		if property := properties.internal_get_own_property(key) {
			if property.enumerable or { false } {
				descriptor_object := properties.get(mut vm, key)!
				descriptor := to_property_descriptor(mut vm, descriptor_object)!
				descriptors << NameAndPropertyDescriptor{
					key:        key
					descriptor: descriptor
				}
			}
		}
	}
	// Gather all descriptors before the first definition. Conversion failure
	// leaves the target untouched; application failure can retain earlier writes.
	for entry in descriptors {
		object.define_property_or_throw(mut vm, entry.key, entry.descriptor)!
	}
	return &object
}
