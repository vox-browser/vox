module libjs

// The untranslated Intl::NumberFormat record and FormatNumeric operation are
// explicit retained dependencies. No replacement formatter is installed.
pub type BigIntNumberFormatConstructorGetter = fn (realm &Realm) &Object

pub type BigIntFormatNumeric = fn (number_format &Object, number Value) Utf16String

pub struct BigIntLocaleDependencies {
pub:
	constructor_getter BigIntNumberFormatConstructorGetter = unsafe { nil }
	format_numeric     BigIntFormatNumeric                 = unsafe { nil }
}

// Runtime/BigIntPrototype.cpp::to_locale_string. Read the arguments, brand
// check, construct the current realm's retained %Intl.NumberFormat% with both
// arguments, then call FormatNumeric with the original BigInt cell.
pub fn bigint_prototype_to_locale_string(mut vm VM, dependencies BigIntLocaleDependencies) !Value {
	realm := vm.realm()
	locales := vm.argument(0)
	options := vm.argument(1)
	bigint := this_bigint_value(mut vm, vm.this_value())!
	constructor := dependencies.constructor_getter(realm)
	number_format := construct(mut vm, Value.from_object(constructor), [locales, options], none)!
	formatted := dependencies.format_numeric(number_format, Value.from_bigint(bigint))
	return Value.from_string(vm.create_string(formatted))
}
