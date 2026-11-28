// SPDX-License-Identifier: BSD-2-Clause
module libjs

import platform

// StringPrototype.cpp::locale_compare: both string conversions precede locale
// and option effects. The retained intrinsic cannot be replaced by an author
// assignment to Intl.Collator. Only the no-options path caches the collator.
pub fn string_prototype_locale_compare(mut vm VM) !Value {
	left := string_primitive_from(mut vm)!
	right := vm.argument(0).to_primitive_string(mut vm)!
	locales := vm.argument(1)
	options := vm.argument(2)
	mut realm := unsafe { &Realm(vm.realm()) }
	default_options := locales.is_undefined() && options.is_undefined()
	if default_options && left.utf16 == right.utf16 { return Value.from_i32(0) }
	if default_options && realm.intl_default_collator_locale == realm.intl_default_locale {
		if collator := realm.intl_default_collator { return Value.from_i32(i32(intl_collation_compare(mut vm, left.utf16, right.utf16, collator.settings)!)) }
	}
	constructor := realm.intl_collator_constructor or { return vm.throw_error(.internal_error, 'Missing Intl.Collator') }
	object := construct(mut vm, Value.from_object(constructor), [locales, options], none)!
	collator := object.slots.intl_collator or { return vm.throw_error(.internal_error, 'Missing Intl.Collator slots') }
	if default_options {
		persistent := platform.enter_persistent()
		defer { platform.leave_persistent(persistent) }
		realm.intl_default_collator = collator
		realm.intl_default_collator_locale = realm.intl_default_locale.clone()
	}
	return Value.from_i32(i32(intl_collation_compare(mut vm, left.utf16, right.utf16, collator.settings)!))
}
