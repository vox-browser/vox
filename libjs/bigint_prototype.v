module libjs

// Runtime/BigIntPrototype.{h,cpp}. This ordinary prototype has no BigIntData
// slot. Its Object parent and Intl operations remain explicit dependencies;
// creation does not install the unfinished intrinsic graph as production globals.
@[heap]
pub struct BigIntPrototype {
pub:
	object &Object
}

pub fn BigIntPrototype.create(mut vm VM, realm &Realm, object_prototype &Object, locale BigIntLocaleDependencies) &BigIntPrototype {
	mut object := Object.create(realm, object_prototype)
	for index, name in ['toString', 'toLocaleString', 'valueOf'] {
		function := if index == 1 {
			NativeFunction.create(mut vm, realm, realm.function_prototype, fn [locale] (mut vm VM) !Value {
				return bigint_prototype_to_locale_string(mut vm, locale)
			}, 0, PropertyName.from_str(name), none)
		} else {
			behaviour := if index == 0 {
				NativeFunctionPointer(bigint_prototype_to_string)
			} else {
				NativeFunctionPointer(bigint_prototype_value_of)
			}
			NativeFunction.create_raw(mut vm, realm, realm.function_prototype, behaviour, 0,
				PropertyName.from_str(name), none)
		}
		object.define_direct_property(PropertyName.from_str(name),
			Value.from_object(function.object), attribute_writable | attribute_configurable)
	}
	object.define_direct_property(PropertyName.from_symbol(vm.well_known_symbol_to_string_tag()),
		Value.from_string(vm.create_string_from_str('BigInt')), attribute_configurable)
	return &BigIntPrototype{
		object: object
	}
}
