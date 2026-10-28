module libjs

// Runtime/ReflectObject.{h,cpp}. Reflect is an ordinary, noncallable object.
// Object/Array intrinsics are explicit dependencies until their graph exists;
// this complete record is not installed as a production global yet.
@[heap]
pub struct ReflectObject {
pub:
	object &Object
}

pub fn ReflectObject.create(mut vm VM, realm &Realm, object_prototype &Object, array_prototype &Object) &ReflectObject {
	mut object := Object.create(realm, object_prototype)
	names := ['apply', 'construct', 'defineProperty', 'deleteProperty', 'get',
		'getOwnPropertyDescriptor', 'getPrototypeOf', 'has', 'isExtensible', 'ownKeys',
		'preventExtensions', 'set', 'setPrototypeOf']
	lengths := [3, 2, 3, 2, 2, 2, 1, 2, 1, 1, 1, 3, 2]
	for index, name in names {
		function := NativeFunction.create(mut vm, realm, realm.function_prototype, fn [name, object_prototype, array_prototype] (mut vm VM) !Value {
			return match name {
				'apply' { reflect_apply(mut vm)! }
				'construct' { reflect_construct(mut vm)! }
				'defineProperty' { reflect_define_property(mut vm)! }
				'deleteProperty' { reflect_delete_property(mut vm)! }
				'get' { reflect_get(mut vm)! }
				'getOwnPropertyDescriptor' { reflect_get_own_property_descriptor(mut vm,
						object_prototype)! }
				'getPrototypeOf' { reflect_get_prototype_of(mut vm)! }
				'has' { reflect_has(mut vm)! }
				'isExtensible' { reflect_is_extensible(mut vm)! }
				'ownKeys' { reflect_own_keys(mut vm, array_prototype)! }
				'preventExtensions' { reflect_prevent_extensions(mut vm)! }
				'set' { reflect_set(mut vm)! }
				'setPrototypeOf' { reflect_set_prototype_of(mut vm)! }
				else { panic('unknown Reflect native function') }
			}
		}, lengths[index], PropertyName.from_str(name), none)
		object.define_direct_property(PropertyName.from_str(name),
			Value.from_object(function.object), attribute_writable | attribute_configurable)
	}
	object.define_direct_property(PropertyName.from_symbol(vm.well_known_symbol_to_string_tag()),
		Value.from_string(vm.create_string_from_str('Reflect')), attribute_configurable)
	return &ReflectObject{
		object: object
	}
}
