module libjs

// Runtime/ArrayIterator.{h,cpp}: CreateArrayIterator and next, including the
// TypedArray witness path and the ordinary-array-like observable length path.
pub enum PropertyKind {
	key
	value
	key_and_value
}

@[heap]
pub struct ArrayIterator {
pub:
	object         &Object
	iteration_kind PropertyKind
pub mut:
	array Value
	index u64
}

pub fn ArrayIterator.create(realm &Realm, array Value, kind PropertyKind, prototype &Object) &ArrayIterator {
	mut object := Object.create(realm, prototype)
	object.class_name = 'ArrayIterator'
	iterator := &ArrayIterator{object: object, array: array, iteration_kind: kind}
	object.array_iterator = iterator
	return iterator
}

// The entry-pair Array prototype is explicit until Array intrinsics are wired.
pub fn (mut iterator ArrayIterator) next(mut vm VM, array_prototype &Object) !IteratorStepValue {
	target := iterator.array
	if target.is_undefined() { return IteratorStepValue{done: true, value: js_undefined()} }
	assert target.is_object()
	array := target.as_object()
	index := iterator.index
	length := if typed_array := array.typed_array {
		record := make_typed_array_with_buffer_witness_record(typed_array, .seq_cst)
		if is_typed_array_out_of_bounds(record) {
			return vm.throw_error_type(.type_error, .buffer_out_of_bounds, 'TypedArray')
		}
		u64(typed_array_length(record))
	} else { length_of_array_like(mut vm, array)! }
	if index >= length {
		iterator.array = js_undefined()
		return IteratorStepValue{done: true, value: js_undefined()}
	}
	// The pinned source increments the current slot after the observable length
// getter; it does not overwrite a change made by a reentrant next call.
	iterator.index++
	// Array-like indices can exceed INT32_MAX; keep their exact Number value.
	index_number := Value.from_f64(f64(index))
	if iterator.iteration_kind == .key { return IteratorStepValue{value: index_number} }
	element := array.get(mut vm, PropertyName.from_str(index.str()))!
	if iterator.iteration_kind == .value { return IteratorStepValue{value: element} }
	pair := ArrayObject.create_from(mut vm, vm.realm(), [index_number, element], array_prototype)!
	return IteratorStepValue{value: Value.from_object(pair.object)}
}
