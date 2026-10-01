module libjs

// Number, BigInt and String prototypes are still untranslated. These getters
// replace their Intrinsics members without creating substitute builtin objects.
// Boolean and Symbol use the existing current-realm intrinsic records.
pub struct PrimitiveObjectPrototypes {
pub:
	number IntrinsicPrototypeGetter = unsafe { nil }
	bigint IntrinsicPrototypeGetter = unsafe { nil }
	string IntrinsicPrototypeGetter = unsafe { nil }
}

// ValueInlines.h::to_object and Value.cpp::to_object_slow (ToObject).
pub fn (value Value) to_object_with_prototypes(mut vm VM, prototypes PrimitiveObjectPrototypes) !&Object {
	if value.is_object() { return value.as_object() }
	realm := vm.realm()
	assert !value.is_special_empty_value()
	if value.is_number() {
		assert prototypes.number != unsafe { nil }
		return NumberObject.create(realm, value.number, prototypes.number(realm)).object
	}
	return match value.tag {
		.undefined, .null { vm.throw_error_type(.type_error, .to_object_null_or_undefined) }
		.boolean { BooleanObject.create(realm, value.as_bool()).object }
		.string {
			assert prototypes.string != unsafe { nil }
			StringObject.create(realm, value.as_string(), prototypes.string(realm)).object
		}
		.symbol { SymbolObject.create(realm, value.as_symbol()).object }
		.bigint {
			assert prototypes.bigint != unsafe { nil }
			BigIntObject.create(realm, value.as_bigint(), prototypes.bigint(realm)).object
		}
		else { panic('ToObject received an internal value') }
	}
}
