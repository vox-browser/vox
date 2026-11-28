// SPDX-License-Identifier: BSD-2-Clause
module libjs

import platform

@[heap]
pub struct IntlCollator {
	object &Object
	locale string
	usage string
	collation string = 'default'
	settings IntlCollationSettings
mut:
	bound_compare ?&Object
}

// Only advertise implemented locale data. English inherits the pinned CLDR
// root standard order. Other requested locales negotiate to the supported
// default rather than claiming an unimplemented language-specific tailoring.
const intl_collator_locales = ['en', 'en-GB', 'en-US']

fn intl_collator_available_locale(candidate string) ?string {
	mut locale := candidate
	for {
		if locale in intl_collator_locales { return locale }
		at := locale.last_index('-') or { return none }
		locale = locale[..at]
	}
	return none
}

fn intl_collator_resolve_locale(mut vm VM, requested []string) !(string, IntlLocaleIdentifier) {
	for tag in requested {
		identifier := intl_canonicalize_language_tag(mut vm, utf16_string(tag))!
		if locale := intl_collator_available_locale(identifier.base_name()) { return locale, identifier }
	}
	identifier := intl_canonicalize_language_tag(mut vm, utf16_string(vm.realm().intl_default_locale))!
	return intl_collator_available_locale(identifier.base_name()) or { 'en-US' }, identifier
}

fn intl_collator_this(mut vm VM) !&IntlCollator {
	value := vm.this_value()
	if value.is_object() { if collator := value.as_object().slots.intl_collator { return collator } }
	return vm.throw_error(.type_error, 'Intl.Collator member called on incompatible receiver')
}

fn intl_collator_construct(mut vm VM, new_target &Object) !&Object {
	persistent := platform.enter_persistent()
	defer { platform.leave_persistent(persistent) }
	prototype := get_prototype_from_constructor(mut vm, new_target, fn (realm &Realm) &Object { return realm.intl_collator_prototype or { panic('Missing Intl.Collator prototype') } })!
	requested := intl_canonicalize_locale_list(mut vm, vm.argument(0))!
	options := intl_options_object(mut vm, vm.argument(1))!
	usage := intl_option_text(mut vm, options, 'usage', ['sort', 'search'], 'sort')!
	intl_string_option(mut vm, options, 'localeMatcher', ['lookup', 'best fit'])!
	collation := intl_string_option(mut vm, options, 'collation', [])!
	if !collation.is_undefined() && !intl_type_identifier(intl_ascii(mut vm, collation.as_string().utf16)!) { return vm.throw_error(.range_error, 'Invalid Intl collation') }
	numeric_option := options.get(mut vm, PropertyName.from_str('numeric'))!
	case_option := intl_string_option(mut vm, options, 'caseFirst', ['upper', 'lower', 'false'])!
	data_locale, identifier := intl_collator_resolve_locale(mut vm, requested)!
	mut numeric := false
	mut case_first := 'false'
	mut extensions := map[string]string{}
	if extension := identifier.keywords['kn'] {
		if extension in ['', 'true', 'false'] { numeric = extension != 'false'; extensions['kn'] = extension }
	}
	if extension := identifier.keywords['kf'] {
		if extension in ['upper', 'lower', 'false'] { case_first = extension; extensions['kf'] = extension }
	}
	if !numeric_option.is_undefined() {
		value := numeric_option.to_boolean()
		if value != numeric { extensions.delete('kn') }; numeric = value
	}
	if !case_option.is_undefined() {
		value := case_option.as_string().str()
		if value != case_first { extensions.delete('kf') }; case_first = value
	}
	sensitivity := intl_option_text(mut vm, options, 'sensitivity', ['base', 'accent', 'case', 'variant'], 'variant')!
	punctuation := options.get(mut vm, PropertyName.from_str('ignorePunctuation'))!
	mut resolved := intl_canonicalize_language_tag(mut vm, utf16_string(data_locale))!
	resolved.keywords = extensions
	mut object := Object.create(vm.realm(), prototype)
	object.class_name = 'Intl.Collator'
	object.mut_slots().intl_collator = &IntlCollator{object: object, locale: resolved.tag(), usage: usage, settings: IntlCollationSettings{sensitivity: sensitivity, case_first: case_first, numeric: numeric, ignore_punctuation: !punctuation.is_undefined() && punctuation.to_boolean()}}
	return object
}

fn intl_collator_supported_locales(mut vm VM) !Value {
	requested := intl_canonicalize_locale_list(mut vm, vm.argument(0))!
	options := intl_options_object(mut vm, vm.argument(1))!
	intl_string_option(mut vm, options, 'localeMatcher', ['lookup', 'best fit'])!
	mut supported := []string{}
	for tag in requested {
		identifier := intl_canonicalize_language_tag(mut vm, utf16_string(tag))!
		if intl_collator_available_locale(identifier.base_name()) != none { supported << tag }
	}
	return intl_string_array(mut vm, supported)
}

fn intl_collator_resolved_options(mut vm VM) !Value {
	collator := intl_collator_this(mut vm)!
	mut object := Object.create(vm.realm(), vm.realm().object_prototype)
	entries := {'locale': Value.from_string(vm.create_string_from_str(collator.locale)), 'usage': Value.from_string(vm.create_string_from_str(collator.usage)), 'sensitivity': Value.from_string(vm.create_string_from_str(collator.settings.sensitivity)), 'ignorePunctuation': Value.from_bool(collator.settings.ignore_punctuation), 'collation': Value.from_string(vm.create_string_from_str(collator.collation)), 'numeric': Value.from_bool(collator.settings.numeric), 'caseFirst': Value.from_string(vm.create_string_from_str(collator.settings.case_first))}
	for name in ['locale', 'usage', 'sensitivity', 'ignorePunctuation', 'collation', 'numeric', 'caseFirst'] { object.create_data_property_or_throw(mut vm, PropertyName.from_str(name), entries[name] or { return vm.throw_error(.internal_error, 'Missing Collator resolved option') })! }
	return Value.from_object(object)
}

fn initialize_intl_collator(mut vm VM, mut realm Realm) {
	mut prototype := Object.create(realm, realm.object_prototype)
	realm.intl_collator_prototype = prototype
	mut constructor := NativeFunction.create_constructor(mut vm, realm, realm.function_prototype, fn (mut vm VM) !Value {
		constructor := vm.realm().intl_collator_constructor or { panic('Missing Intl.Collator') }
		return Value.from_object(construct(mut vm, Value.from_object(constructor), [vm.argument(0), vm.argument(1)], none)!)
	}, intl_collator_construct, 0, PropertyName.from_str('Collator')).object
	realm.intl_collator_constructor = constructor
	constructor.define_direct_property(PropertyName.from_str('prototype'), Value.from_object(prototype), 0)
	prototype.define_direct_property(PropertyName.from_str('constructor'), Value.from_object(constructor), attribute_writable | attribute_configurable)
	prototype.define_direct_property(PropertyName.from_symbol(vm.well_known_symbol_to_string_tag()), Value.from_string(vm.create_string_from_str('Intl.Collator')), attribute_configurable)
	prototype.define_native_accessor(mut vm, realm, PropertyName.from_str('compare'), intl_collator_compare_getter, unsafe { nil }, attribute_configurable, realm.function_prototype)
	install_intrinsic_method(mut vm, realm, mut constructor, 'supportedLocalesOf', 1, intl_collator_supported_locales)
	install_intrinsic_method(mut vm, realm, mut prototype, 'resolvedOptions', 0, intl_collator_resolved_options)
	mut namespace := realm.intl_object or { panic('Missing Intl namespace') }
	namespace.define_direct_property(PropertyName.from_str('Collator'), Value.from_object(constructor), attribute_writable | attribute_configurable)
}
