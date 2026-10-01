module libjs

// Runtime/NumberObject.{h,cpp}. The prototype is an explicit dependency until
// Number's intrinsic constructor and prototype have been translated.
@[heap]
pub struct NumberObject {
pub:
	object &Object
	value  f64
}

pub fn NumberObject.create(realm &Realm, value f64, prototype &Object) &NumberObject {
	mut object := Object.create(realm, prototype)
	object.class_name = 'Number'
	wrapper := &NumberObject{ object: object, value: value }
	object.number_object = wrapper
	return wrapper
}
