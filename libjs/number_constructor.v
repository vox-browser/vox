module libjs

import math

// Runtime/NumberConstructor.{h,cpp}. Retain Number/Object and parse-function
// intrinsics explicitly until the production intrinsic graph is installed.
pub struct NumberConstructorDependencies {
pub:
	prototype        &Object
	prototype_getter IntrinsicPrototypeGetter = unsafe { nil }
	parse_int        &Object
	parse_float      &Object
}

@[heap]
pub struct NumberConstructor {
pub:
	object &Object
}

pub fn NumberConstructor.create(mut vm VM, realm &Realm, dependencies NumberConstructorDependencies) &NumberConstructor {
	function := NativeFunction.create_constructor_record(mut vm, realm, realm.function_prototype,
		number_constructor_call, fn [dependencies] (mut vm VM, target &Object) !&Object {
		return number_constructor_construct(mut vm, target, dependencies.prototype_getter)
	}, PropertyName.from_str('Number'))
	mut object := function.object
	object.class_name = 'NumberConstructor'
	object.define_direct_property(PropertyName.from_str('prototype'),
		Value.from_object(dependencies.prototype), 0)
	behaviours := [NativeFunctionPointer(number_constructor_is_finite), number_constructor_is_integer,
		number_constructor_is_nan, number_constructor_is_safe_integer]
	for index, name in ['isFinite', 'isInteger', 'isNaN', 'isSafeInteger'] {
		method := NativeFunction.create_raw(mut vm, realm, realm.function_prototype,
			behaviours[index], 1, PropertyName.from_str(name), none)
		object.define_direct_property(PropertyName.from_str(name),
			Value.from_object(method.object), attribute_writable | attribute_configurable)
	}
	object.define_direct_property(PropertyName.from_str('parseInt'),
		Value.from_object(dependencies.parse_int), attribute_writable | attribute_configurable)
	object.define_direct_property(PropertyName.from_str('parseFloat'),
		Value.from_object(dependencies.parse_float), attribute_writable | attribute_configurable)
	names := ['EPSILON', 'MAX_VALUE', 'MIN_VALUE', 'MAX_SAFE_INTEGER', 'MIN_SAFE_INTEGER',
		'NEGATIVE_INFINITY', 'POSITIVE_INFINITY', 'NaN']
	values := [math.ldexp(1, -52), math.max_f64, math.f64_from_bits(1), 9007199254740991.0,
		-9007199254740991.0, math.inf(-1), math.inf(1), math.nan()]
	for index, name in names {
		object.define_direct_property(PropertyName.from_str(name), Value.from_f64(values[index]), 0)
	}
	object.set_function_length(1)
	// Intrinsics.cpp::initialize_constructor follows the class initializer.
	object.set_function_name(mut vm, PropertyName.from_str('Number'), none)
	mut prototype := dependencies.prototype
	prototype.define_direct_property(PropertyName.from_str('constructor'),
		Value.from_object(object), attribute_writable | attribute_configurable)
	return &NumberConstructor{
		object: object
	}
}

// NumberConstructor.cpp::get_value_from_constructor_argument.
fn number_constructor_argument(mut vm VM) !Value {
	if vm.argument_count() > 0 {
		primitive := vm.argument(0).to_numeric(mut vm)!
		if primitive.is_bigint() {
			return Value.from_f64(big_integer_to_double(primitive.as_bigint().big_integer,
				.ties_to_even))
		}
		return primitive
	}
	return Value.from_i32(0)
}

pub fn number_constructor_call(mut vm VM) !Value {
	return number_constructor_argument(mut vm)
}

pub fn number_constructor_construct(mut vm VM, new_target &Object, intrinsic_prototype IntrinsicPrototypeGetter) !&Object {
	number := number_constructor_argument(mut vm)!
	prototype := get_prototype_from_constructor(mut vm, new_target, intrinsic_prototype)!
	return NumberObject.create(vm.realm(), number.number, prototype).object
}
