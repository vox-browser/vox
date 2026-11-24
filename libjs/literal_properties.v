module libjs

// Object and array literals define each property with CreateDataPropertyOrThrow
// on the object they just created. For an extensible ordinary object without
// the key, OrdinaryDefineOwnProperty reduces to appending a data property with
// all attributes set, which is what ValidateAndApplyPropertyDescriptor does
// there through define_direct_property. Exotic objects, existing keys (a
// duplicate literal key or an earlier accessor) and non-extensible objects keep
// the generic path.

$if test {
	__global literal_property_fast_path_disabled bool
	pub fn set_literal_property_fast_path_for_testing(enabled bool) {
		literal_property_fast_path_disabled = !enabled
	}
}

fn (object &Object) is_ordinary_for_data_definition() bool {
	return object.extensible && object.proxy_object == none && object.legacy_platform_object == none
		&& object.arguments_object == none && object.typed_array == none
		&& object.array_object == none && object.string_object == none
}

// `fresh` is the compiler's proof that no earlier definition of this literal
// created the key. Otherwise one lookup decides between appending and the
// generic path; the literal object is ordinary and not an array, so appending
// needs none of define_direct_property's length or index bookkeeping.
fn define_literal_property(mut vm VM, mut object Object, key PropertyName, value Value, fresh bool) ! {
	$if test {
		if literal_property_fast_path_disabled {
			object.create_data_property_or_throw(mut vm, key, value)!
			return
		}
	}
	if object.is_ordinary_for_data_definition() && (fresh || object.find_own_property(key) < 0) {
		object.properties << OwnProperty{key: key, value: value, writable: true, enumerable: true,
			configurable: true}
		return
	}
	// An array literal's elements, on the array new_array created with their
	// count: ArrayObject [[DefineOwnProperty]] of an absent index on an
	// extensible array with a writable length appends it and extends the length.
	if fresh && key.kind == .number_key && object.extensible && object.indexed_properties == none {
		if mut array := object.array_object {
			if array.length_writable {
				push_within_capacity(mut object.properties, OwnProperty{key: key, value: value, writable: true,
					enumerable: true, configurable: true})
				if key.number >= array.length { array.length = key.number + 1 }
				return
			}
		}
	}
	object.create_data_property_or_throw(mut vm, key, value)!
}

// ToPropertyKey returns a string or symbol argument itself. Converting it to a
// PropertyName and back allocated a new string for every literal key.
fn property_key_value(mut vm VM, value Value) !Value {
	$if test {
		if literal_property_fast_path_disabled { return value.to_property_key(mut vm)!.to_value(mut vm) }
	}
	if value.is_string() || value.is_symbol() { return value }
	return value.to_property_key(mut vm)!.to_value(mut vm)
}
