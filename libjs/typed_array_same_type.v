module libjs

// TypedArray.cpp::TypedArrayCreateSameType. The realm's concrete intrinsic
// constructor lookup is explicit until the complete TypedArray graph exists.
pub type TypedArrayIntrinsicConstructorGetter = fn (realm &Realm, kind BufferElementType) &Object

pub fn typed_array_create_same_type(mut vm VM, exemplar &TypedArray, arguments []Value, constructor_getter TypedArrayIntrinsicConstructorGetter) !&TypedArray {
	constructor := constructor_getter(vm.realm(), exemplar.kind)
	return typed_array_create(mut vm, constructor, arguments)
}
