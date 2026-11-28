module libjs

import platform

// Runtime/BigIntObject.{h,cpp}. The retained BigInt cell is the source's GC
// edge; the intrinsic prototype is supplied by the embedding dependency.
@[heap]
pub struct BigIntObject {
pub:
	object &Object
	bigint &BigInt
}

pub fn BigIntObject.create(realm &Realm, bigint &BigInt, prototype &Object) &BigIntObject {
	persistent := platform.enter_persistent()
	defer { platform.leave_persistent(persistent) }
	mut object := Object.create(realm, prototype)
	object.class_name = 'BigIntObject'
	wrapper := &BigIntObject{
		object: object
		bigint: bigint
	}
	object.mut_slots().bigint_object = wrapper
	return wrapper
}
