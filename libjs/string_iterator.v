module libjs

// Runtime/StringIterator.{h,cpp}. The prototype is explicit while the Iterator
// and String intrinsic graph is pending. A code-unit offset represents the
// source's AK::Utf16CodePointIterator over the retained string.
@[heap]
pub struct StringIterator {
pub:
	object &Object
	text   Utf16String
pub mut:
	index int
	done  bool
}

pub fn StringIterator.create(realm &Realm, text Utf16String, prototype &Object) &StringIterator {
	mut object := Object.create(realm, prototype)
	object.class_name = 'StringIterator'
	iterator := &StringIterator{object: object, text: text.clone()}
	object.string_iterator = iterator
	return iterator
}

pub fn (mut iterator StringIterator) next(mut vm VM) IteratorStepValue {
	if iterator.done { return IteratorStepValue{done: true, value: js_undefined()} }
	if iterator.index == iterator.text.len() {
		iterator.done = true
		return IteratorStepValue{done: true, value: js_undefined()}
	}
	start := iterator.index
	mut width := 1
	if is_utf16_high_surrogate(iterator.text.data[start]) && start + 1 < iterator.text.len()
		&& is_utf16_low_surrogate(iterator.text.data[start + 1]) { width = 2 }
	// AK decodes and re-encodes a valid surrogate pair and preserves lone units.
	code_point := Utf16String.from_slice(iterator.text.data[start..start + width])
	iterator.index += width
	return IteratorStepValue{value: Value.from_string(vm.create_string(code_point))}
}
