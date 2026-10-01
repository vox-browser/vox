module libjs

// Runtime/Uint8Array.cpp's constructor/prototype helper initializers. Native
// method names, lengths, descriptors and insertion order follow the source.
pub fn initialize_uint8_array_constructor_helpers(mut vm VM, realm &Realm, mut object Object, prototype_getter IntrinsicPrototypeGetter) {
	for name in ['fromBase64', 'fromHex'] {
		function := NativeFunction.create(mut vm, realm, realm.function_prototype, fn [name, prototype_getter] (mut vm VM) !Value {
			return if name == 'fromBase64' {
				uint8_array_constructor_from_base64(mut vm, prototype_getter)!
			} else {
				uint8_array_constructor_from_hex(mut vm, prototype_getter)!
			}
		}, 1, PropertyName.from_str(name), none)
		object.define_direct_property(PropertyName.from_str(name),
			Value.from_object(function.object), attribute_writable | attribute_configurable)
	}
}

pub fn initialize_uint8_array_prototype_helpers(mut vm VM, realm &Realm, mut object Object, primitives PrimitiveObjectPrototypes, object_prototype &Object) {
	for name in ['setFromBase64', 'setFromHex', 'toBase64', 'toHex'] {
		function := NativeFunction.create(mut vm, realm, realm.function_prototype, fn [name, primitives, object_prototype] (mut vm VM) !Value {
			return match name {
				'setFromBase64' { uint8_array_prototype_set_from_base64(mut vm, primitives,
						object_prototype)! }
				'setFromHex' { uint8_array_prototype_set_from_hex(mut vm, primitives,
						object_prototype)! }
				'toBase64' { uint8_array_prototype_to_base64(mut vm, primitives)! }
				else { uint8_array_prototype_to_hex(mut vm, primitives)! }
			}
		}, if name.starts_with('set') { 1.0 } else { 0.0 }, PropertyName.from_str(name), none)
		object.define_direct_property(PropertyName.from_str(name),
			Value.from_object(function.object), attribute_writable | attribute_configurable)
	}
}
