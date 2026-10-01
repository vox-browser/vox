module libjs

// Runtime/StringObject.{h,cpp}, including StringCreate and the three exotic
// internal methods (dispatched by Object). The explicit prototype matches the
// upstream factory; String's constructor and prototype are separate work.
@[heap]
pub struct StringObject {
pub:
	object &Object
	value  &PrimitiveString
}

pub fn StringObject.create(realm &Realm, value &PrimitiveString, prototype &Object) &StringObject {
	mut object := Object.create(realm, prototype)
	object.class_name = 'String'
	text := &StringObject{
		object: object
		value: value
	}
	object.string_object = text
	object.define_direct_property(PropertyName.from_str('length'),
		Value.from_f64(f64(value.length_in_utf16_code_units())), 0)
	return text
}

// 10.4.3.5 StringGetOwnProperty: PropertyName's numeric storage supplies the
// IgnoreNumericRoundtrip canonical indices used by the pinned upstream source.
fn (text &StringObject) character_descriptor(key PropertyName) ?PropertyDescriptor {
	if !key.is_number() || u64(key.number) >= u64(text.value.utf16.len()) { return none }
	// Object's descriptor API has no VM parameter. Like the existing flattened
// string representation, this copies the code unit instead of making a cached
// substring cell. Strings compare by contents, including unpaired surrogates.
	character := &PrimitiveString{
		utf16: Utf16String.from_slice([text.value.utf16.data[int(key.number)]])
	}
	return PropertyDescriptor{
		value: Value.from_string(character)
		writable: false
		enumerable: true
		configurable: false
	}
}
