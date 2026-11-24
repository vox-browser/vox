module libjs

// Production intrinsic path: preserve receiver validation before locale/options
// effects and construct the retained realm intrinsic, even if Intl is replaced.
fn number_prototype_to_intl_locale_string(mut vm VM) !Value {
	value := this_number_value(mut vm, vm.this_value())!
	constructor := vm.realm().intl_number_format_constructor or { return vm.throw_error(.internal_error, 'Missing Intl.NumberFormat') }
	object := construct(mut vm, Value.from_object(constructor), [vm.argument(0), vm.argument(1)], none)!
	formatter := object.slots.intl_number_format or { return vm.throw_error(.internal_error, 'Missing Intl.NumberFormat slots') }
	return intl_number_parts_string(mut vm, intl_format_number_parts(mut vm, formatter, intl_mathematical_value(mut vm, value)!)!)
}

// Retained dependency-injection surface for the translated upstream adapter.
// Production bindings above use the native formatter and propagate its errors.
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
