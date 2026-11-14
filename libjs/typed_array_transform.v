module libjs

// TypedArrayPrototype.cpp::filter/map. Both capture the iteration length;
// filter creates its species result after callbacks, map before callbacks.
pub fn typed_array_prototype_filter(mut vm VM, prototypes PrimitiveObjectPrototypes, constructor_getter TypedArrayIntrinsicConstructorGetter, prototype_getter TypedArrayIntrinsicPrototypeGetter) !Value {
	this_arg := vm.argument(1)
	source := typed_array_from_this(mut vm, prototypes)!
	record := validate_typed_array(mut vm, source.object, .seq_cst)!
	length := typed_array_length(record)
	callback := typed_array_callback_from_args(mut vm, 'filter')!
	mut kept := []Value{}
	mut captured := u32(0)
	for k := u32(0); k < length; k++ {
		value := source.object.get(mut vm, PropertyName.from_number(k))!
		selected := call(mut vm, Value.from_object(callback), this_arg, [value,
			Value.from_f64(f64(k)), Value.from_object(source.object)])!.to_boolean()
		if selected {
			kept << value
			captured++
		}
	}
	realm := vm.realm()
	factory := fn [source, realm, captured, prototype_getter] (mut vm VM) !&TypedArray {
		return source.create_default(mut vm, realm, captured, prototype_getter)
	}
	array := typed_array_species_create(mut vm, source, factory, [
		Value.from_f64(f64(captured)),
	], constructor_getter)!
	mut object := array.object
	for index, value in kept {
		object.set(mut vm, PropertyName.from_number(u32(index)), value, .yes)!
	}
	return Value.from_object(object)
}

pub fn typed_array_prototype_map(mut vm VM, prototypes PrimitiveObjectPrototypes, constructor_getter TypedArrayIntrinsicConstructorGetter, prototype_getter TypedArrayIntrinsicPrototypeGetter) !Value {
	this_arg := vm.argument(1)
	source := typed_array_from_this(mut vm, prototypes)!
	record := validate_typed_array(mut vm, source.object, .seq_cst)!
	length := typed_array_length(record)
	callback := typed_array_callback_from_args(mut vm, 'map')!
	realm := vm.realm()
	factory := fn [source, realm, length, prototype_getter] (mut vm VM) !&TypedArray {
		return source.create_default(mut vm, realm, length, prototype_getter)
	}
	array := typed_array_species_create(mut vm, source, factory, [
		Value.from_f64(f64(length)),
	], constructor_getter)!
	mut object := array.object
	for k := u32(0); k < length; k++ {
		key := PropertyName.from_number(k)
		value := source.object.get(mut vm, key)!
		mapped := call(mut vm, Value.from_object(callback), this_arg, [value, Value.from_f64(f64(k)),
			Value.from_object(source.object)])!
		object.set(mut vm, key, mapped, .yes)!
	}
	return Value.from_object(object)
}
