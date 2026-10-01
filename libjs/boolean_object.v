module libjs

// Runtime/BooleanObject.{h,cpp}. The ordinary record retains [[BooleanData]];
// the prototype's false-valued slot is created through the explicit-prototype
// constructor, matching the upstream subclass constructor.
@[heap]
pub struct BooleanObject {
pub:
	object &Object
	value  bool
}

pub fn BooleanObject.create(realm &Realm, value bool) &BooleanObject {
	return BooleanObject.create_with_prototype(realm, value, realm.boolean_prototype_record())
}

pub fn BooleanObject.create_with_prototype(realm &Realm, value bool, prototype ?&Object) &BooleanObject {
	mut object := Object.create(realm, prototype)
	object.class_name = 'Boolean'
	boolean := &BooleanObject{
		object: object
		value: value
	}
	object.boolean_object = boolean
	return boolean
}
