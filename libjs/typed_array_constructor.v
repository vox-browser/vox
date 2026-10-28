module libjs

// Runtime/TypedArrayConstructor.{h,cpp}. The abstract constructor/prototype
// dependency is explicit until the concrete TypedArray intrinsic graph exists.
@[heap]
pub struct TypedArrayConstructor {
pub:
	object &Object
}

pub fn TypedArrayConstructor.create(mut vm VM, realm &Realm, typed_array_prototype &Object, prototypes PrimitiveObjectPrototypes) &TypedArrayConstructor {
	function := NativeFunction.create_constructor_record(mut vm, realm, realm.function_prototype,
		typed_array_constructor_call, typed_array_constructor_construct,
		PropertyName.from_str('TypedArray'))
	mut object := function.object
	object.define_direct_property(PropertyName.from_str('prototype'),
		Value.from_object(typed_array_prototype), 0)
	attributes := attribute_writable | attribute_configurable
	for name in ['from', 'of'] {
		behaviour := fn [name, prototypes] (mut vm VM) !Value {
			return if name == 'from' {
				typed_array_constructor_from(mut vm, prototypes)!
			} else {
				typed_array_constructor_of(mut vm)!
			}
		}
		method := NativeFunction.create(mut vm, realm, realm.function_prototype, behaviour, if name == 'from' {
			1.0
		} else {
			0.0
		}, PropertyName.from_str(name), none)
		object.define_direct_property(PropertyName.from_str(name),
			Value.from_object(method.object), attributes)
	}
	object.define_native_accessor(mut vm, realm,
		PropertyName.from_symbol(vm.well_known_symbol_species()),
		typed_array_constructor_species_getter, unsafe { nil }, attribute_configurable,
		realm.function_prototype)
	object.set_function_length(0)
	// Intrinsics.cpp::initialize_constructor follows the subclass initializer.
	object.set_function_name(mut vm, PropertyName.from_str('TypedArray'), none)
	mut prototype := unsafe { typed_array_prototype }
	prototype.define_direct_property(PropertyName.from_str('constructor'),
		Value.from_object(object), attributes)
	return &TypedArrayConstructor{
		object: object
	}
}

fn typed_array_constructor_call(mut vm VM) !Value {
	// The active call body delegates to Construct with an empty argument list,
	// allocating the nested constructor frame before the abstract-class error.
	function := vm.running_execution_context().function or { panic('missing TypedArray callee') }
	match function {
		NativeFunction { return Value.from_object(construct(mut vm,
				Value.from_object(function.object), []Value{}, none)!) }
		else { panic('TypedArray call requires its native callee') }
	}
}

fn typed_array_constructor_construct(mut vm VM, _ &Object) !&Object {
	return vm.throw_error_type(.type_error, .class_is_abstract, 'TypedArray')
}

pub fn typed_array_constructor_from(mut vm VM, prototypes PrimitiveObjectPrototypes) !Value {
	source := vm.argument(0)
	map_fn := vm.argument(1)
	this_arg := vm.argument(2)
	constructor := vm.this_value()
	if !constructor.is_constructor() {
		return vm.throw_error_type(.type_error, .not_a_constructor, constructor.str())
	}
	if !map_fn.is_undefined() && !map_fn.is_function() {
		return vm.throw_error_type(.type_error, .not_a_function, map_fn.str())
	}
	iterator := source.get_method_with_prototypes(mut vm,
		PropertyName.from_symbol(vm.well_known_symbol_iterator()), prototypes)!
	if !iterator.is_undefined() {
		mut record := get_iterator_from_method(mut vm, source, iterator)!
		values := iterator_to_list(mut vm, mut record)!
		array := typed_array_create(mut vm, constructor.as_object(), [
			Value.from_f64(f64(values.len)),
		])!
		mut object := array.object
		for index, value in values {
			mapped := if map_fn.is_undefined() { value } else { call(mut vm, map_fn, this_arg, [
					value,
					Value.from_f64(f64(index)),
				])! }
			object.set(mut vm, PropertyName.from_number(u32(index)), mapped, .yes)!
		}
		return Value.from_object(object)
	}
	array_like := source.to_object_with_prototypes(mut vm, prototypes) or { panic(err) }
	length := length_of_array_like(mut vm, array_like)!
	array := typed_array_create(mut vm, constructor.as_object(), [
		Value.from_f64(f64(length)),
	])!
	mut object := array.object
	for index := u64(0); index < length; index++ {
		key := PropertyName.from_number(u32(index))
		value := array_like.get(mut vm, key)!
		mapped := if map_fn.is_undefined() { value } else { call(mut vm, map_fn, this_arg, [
				value,
				Value.from_f64(f64(index)),
			])! }
		object.set(mut vm, key, mapped, .yes)!
	}
	return Value.from_object(object)
}

pub fn typed_array_constructor_of(mut vm VM) !Value {
	length := vm.argument_count()
	constructor := vm.this_value()
	if !constructor.is_constructor() {
		return vm.throw_error_type(.type_error, .not_a_constructor, constructor.str())
	}
	array := typed_array_create(mut vm, constructor.as_object(), [
		Value.from_f64(f64(length)),
	])!
	mut object := array.object
	for index := u32(0); index < length; index++ {
		object.set(mut vm, PropertyName.from_number(index), vm.argument(index), .yes)!
	}
	return Value.from_object(object)
}

pub fn typed_array_constructor_species_getter(mut vm VM) !Value {
	return vm.this_value()
}
