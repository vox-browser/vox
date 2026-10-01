module libjs

// Runtime/BigIntObject.{h,cpp}. The retained BigInt cell is the source's GC
// edge; the intrinsic prototype is supplied by the embedding dependency.
@[heap]
pub struct BigIntObject {
pub:
	object &Object
	bigint &BigInt
}

pub fn BigIntObject.create(realm &Realm, bigint &BigInt, prototype &Object) &BigIntObject {
	mut object := Object.create(realm, prototype)
	object.class_name = 'BigIntObject'
	wrapper := &BigIntObject{
		object: object
		bigint: bigint
	}
	object.bigint_object = wrapper
	return wrapper
}
