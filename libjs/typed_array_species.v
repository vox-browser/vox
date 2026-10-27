module libjs

// Concrete TypedArray.cpp factories and TypedArrayPrototype.cpp's
// TypedArraySpeciesCreate optimization. Intrinsic lookups stay explicit until
// the complete concrete constructor/prototype graph is installed.
pub type TypedArrayIntrinsicPrototypeGetter = fn (realm &Realm, kind BufferElementType) &Object

pub type TypedArrayDefaultConstruct = fn (mut vm VM) !&TypedArray

pub fn (exemplar &TypedArray) create_default(mut vm VM, realm &Realm, length u32, prototype_getter TypedArrayIntrinsicPrototypeGetter) !&TypedArray {
	validate_typed_array_length(mut vm, uint(length), exemplar.kind.size())!
	buffer := ArrayBufferObject.create(mut vm, realm, uint(length) * exemplar.kind.size(),
		realm.array_buffer_prototype_record())!
	return TypedArray.create(realm, exemplar.kind, length, buffer, prototype_getter(realm,
		exemplar.kind))
}

pub fn (exemplar &TypedArray) create_default_view_on_buffer(realm &Realm, buffer &ArrayBufferObject, prototype_getter TypedArrayIntrinsicPrototypeGetter) &TypedArray {
	return TypedArray.create(realm, exemplar.kind, 0, buffer,
		prototype_getter(realm, exemplar.kind))
}

pub fn typed_array_species_create(mut vm VM, exemplar &TypedArray, default_construct TypedArrayDefaultConstruct, arguments []Value, constructor_getter TypedArrayIntrinsicConstructorGetter) !&TypedArray {
	default_constructor := constructor_getter(vm.realm(), exemplar.kind)
	constructor := species_constructor(mut vm, exemplar.object, default_constructor)!
	result := if voidptr(constructor) == voidptr(default_constructor) {
		default_construct(mut vm)!
	} else {
		typed_array_create(mut vm, constructor, arguments)!
	}
	if result.content_type() != exemplar.content_type() {
		return vm.throw_error_type(.type_error, .typed_array_content_type_mismatch,
			result.object.class_name, exemplar.object.class_name)
	}
	return result
}
