module libjs

import platform

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
	persistent := platform.enter_persistent()
	defer { platform.leave_persistent(persistent) }
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
	} else if direct := array.direct_array_record() {
		// An Array's length is its own, non-configurable data property:
		// LengthOfArrayLike observes exactly this value, with no side effects.
		u64(direct.length)
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
	element := array.direct_array_element(index) or { array.get(mut vm, array_index_key(index))! }
	if iterator.iteration_kind == .value { return IteratorStepValue{value: element} }
	pair := ArrayObject.create_from(mut vm, vm.realm(), [index_number, element], array_prototype)!
	return IteratorStepValue{value: Value.from_object(pair.object)}
}

// The Array record of an ordinary Array exotic object (not a Proxy, host or
// other exotic provider), whose length and own elements are read directly.
@[inline]
fn (object &Object) direct_array_record() ?&ArrayObject {
	if object.proxy_object != none || !object.reads_directly() || !use_direct_array_iteration() { return none }
	return object.array_object
}

// Get(array, index) for an own data element; holes, accessors and anything
// else keep the complete [[Get]].
@[inline]
fn (object &Object) direct_array_element(index u64) ?Value {
	if index >= u64(0xffffffff) { return none }
	_ := object.direct_array_record() or { return none }
	position := object.array_index_position(PropertyName.from_number(u32(index)))
	if position < 0 { return none }
	value := object.properties[position].value
	if value.is_accessor() { return none }
	return value
}

$if test {
	__global direct_array_iteration_disabled bool
	pub fn set_direct_array_iteration_for_testing(enabled bool) { direct_array_iteration_disabled = !enabled }
}

@[inline]
fn use_direct_array_iteration() bool {
	$if test { if direct_array_iteration_disabled { return false } }
	return true
}
