// SPDX-License-Identifier: BSD-2-Clause
module libjs

// WebIDL legacy platform objects retain their native indexed owner. These
// hooks are separate from HostProperties: module namespaces and other native
// property providers must keep their own object semantics.
pub interface LegacyIndexedProperties {
	is_supported_property_index(u32) bool
}

pub interface LegacyIndexedPropertySetter {
	set_indexed_property(mut VM, u32, Value) !
}

pub struct LegacyPlatformObject {
pub:
	indexed_properties ?LegacyIndexedProperties
	indexed_setter ?LegacyIndexedPropertySetter
}

fn (object &Object) legacy_indexed_descriptor(key PropertyName, descriptor PropertyDescriptor) PropertyDescriptor {
	if key.is_number() {
		if legacy := object.legacy_platform_object {
			if legacy.indexed_properties != none {
				return PropertyDescriptor{value: descriptor.value, writable: legacy.indexed_setter != none, enumerable: true, configurable: true}
			}
		}
	}
	return descriptor
}

fn (object &Object) legacy_define_indexed_property(mut vm VM, key PropertyName, descriptor PropertyDescriptor) !bool {
	if !descriptor.is_data_descriptor() { return false }
	legacy := object.legacy_platform_object or { return false }
	setter := legacy.indexed_setter or { return false }
	setter.set_indexed_property(mut vm, key.number, descriptor.value or { js_undefined() })!
	return true
}
