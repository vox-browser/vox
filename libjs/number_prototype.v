module libjs

// Runtime/NumberPrototype.{h,cpp}. The prototype is itself a NumberObject with
// [[NumberData]] = +0 and the retained Object prototype as its parent. Object,
// AK's decimal backend and Intl remain explicit untranslated dependencies.
@[heap]
pub struct NumberPrototype {
pub:
	object &Object
}

pub fn NumberPrototype.create(mut vm VM, realm &Realm, object_prototype &Object, decimal NumberDecimalExponentialFormGetter, locale NumberLocaleDependencies) &NumberPrototype {
	mut object := NumberObject.create(realm, 0, object_prototype).object
	object.class_name = 'NumberPrototype'
	names := ['toExponential', 'toFixed', 'toLocaleString', 'toPrecision', 'toString', 'valueOf']
	lengths := [1, 1, 0, 1, 1, 0]
	for index, name in names {
		function := if index == 0 || index == 3 {
			NativeFunction.create(mut vm, realm, realm.function_prototype, fn [index, decimal] (mut vm VM) !Value {
				if index == 0 { return number_prototype_to_exponential(mut vm, decimal) }
				return number_prototype_to_precision(mut vm, decimal)
			}, lengths[index], PropertyName.from_str(name), none)
		} else if index == 2 {
			NativeFunction.create(mut vm, realm, realm.function_prototype, fn [locale] (mut vm VM) !Value {
				return number_prototype_to_locale_string(mut vm, locale)
			}, lengths[index], PropertyName.from_str(name), none)
		} else {
			behaviour := match index {
				1 { NativeFunctionPointer(number_prototype_to_fixed) }
				4 { NativeFunctionPointer(number_prototype_to_string) }
				else { NativeFunctionPointer(number_prototype_value_of) }
			}

			NativeFunction.create_raw(mut vm, realm, realm.function_prototype, behaviour,
				lengths[index], PropertyName.from_str(name), none)
		}
		object.define_direct_property(PropertyName.from_str(name),
			Value.from_object(function.object), attribute_writable | attribute_configurable)
	}
	return &NumberPrototype{
		object: object
	}
}
