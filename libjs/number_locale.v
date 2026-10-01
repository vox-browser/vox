module libjs

// Retained %Intl.NumberFormat% and Intl::format_numeric dependencies. The Intl
// record remains untranslated; no host formatter or replacement global is used.
pub type NumberFormatConstructorGetter = fn (realm &Realm) &Object

pub type NumberFormatNumeric = fn (number_format &Object, number Value) Utf16String

pub struct NumberLocaleDependencies {
pub:
	constructor_getter NumberFormatConstructorGetter = unsafe { nil }
	format_numeric     NumberFormatNumeric           = unsafe { nil }
}

// Runtime/NumberPrototype.cpp::to_locale_string. Preserve the numeric payload
// (including negative zero), both constructor arguments, and returned UTF-16.
pub fn number_prototype_to_locale_string(mut vm VM, dependencies NumberLocaleDependencies) !Value {
	realm := vm.realm()
	locales := vm.argument(0)
	options := vm.argument(1)
	number := this_number_value(mut vm, vm.this_value())!
	constructor := dependencies.constructor_getter(realm)
	formatter := construct(mut vm, Value.from_object(constructor), [locales, options], none)!
	return Value.from_string(vm.create_string(dependencies.format_numeric(formatter, number)))
}
