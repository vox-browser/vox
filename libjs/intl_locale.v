// SPDX-License-Identifier: BSD-2-Clause
module libjs

import platform

@[heap]
pub struct IntlLocaleObject {
pub:
	object &Object
	identifier IntlLocaleIdentifier
}

fn intl_string_option(mut vm VM, options &Object, name string, allowed []string) !Value {
	value := options.get(mut vm, PropertyName.from_str(name))!
	if value.is_undefined() { return value }
	text := value.to_primitive_string(mut vm)!
	if allowed.len > 0 && text.str() !in allowed { return vm.throw_error(.range_error, 'Invalid Intl option ' + name) }
	return Value.from_string(text)
}

fn intl_options_object(mut vm VM, value Value) !&Object {
	if value.is_undefined() { return Object.create(vm.realm(), none) }
	return value.to_object_with_prototypes(mut vm, realm_primitive_prototypes())
}

fn intl_locale_identifier_value(mut vm VM, value Value) !IntlLocaleIdentifier {
	if value.is_object() {
		if locale := value.as_object().slots.intl_locale { return locale.identifier }
	} else if !value.is_string() { return vm.throw_error(.type_error, 'Locale identifier must be a string or object') }
	return intl_canonicalize_language_tag(mut vm, value.to_primitive_string(mut vm)!.utf16)
}

fn intl_canonicalize_locale_list(mut vm VM, value Value) ![]string {
	if value.is_undefined() { return []string{} }
	if value.is_string() || (value.is_object() && value.as_object().slots.intl_locale != none) {
		return [intl_locale_identifier_value(mut vm, value)!.tag()]
	}
	object := value.to_object_with_prototypes(mut vm, realm_primitive_prototypes())!
	length := length_of_array_like(mut vm, object)!
	mut result := []string{}
	mut seen := map[string]bool{}
	for index := u64(0); index < length; index++ {
		vm.consume_execution_budget()!
		key := array_index_key(index)
		if !object.has_property_checked(mut vm, key)! { continue }
		tag := intl_locale_identifier_value(mut vm, object.get(mut vm, key)!)!.tag()
		if !seen[tag] { seen[tag] = true; result << tag }
	}
	return result
}

fn intl_string_array(mut vm VM, strings []string) !Value {
	mut values := []Value{cap: strings.len}
	for text in strings { values << Value.from_string(vm.create_string_from_str(text)) }
	return Value.from_object(ArrayObject.create_from(mut vm, vm.realm(), values, vm.realm().array_prototype_record())!.object)
}

fn intl_locale_create(mut vm VM, identifier IntlLocaleIdentifier, prototype &Object) &Object {
	mut object := Object.create(vm.realm(), prototype)
	object.class_name = 'Intl.Locale'
	object.mut_slots().intl_locale = &IntlLocaleObject{object: object, identifier: identifier}
	return object
}

fn intl_locale_this(mut vm VM) !&IntlLocaleObject {
	value := vm.this_value()
	if value.is_object() { if locale := value.as_object().slots.intl_locale { return locale } }
	return vm.throw_error(.type_error, 'Intl.Locale member called on incompatible receiver')
}

fn intl_locale_construct(mut vm VM, new_target &Object) !&Object {
	persistent := platform.enter_persistent()
	defer { platform.leave_persistent(persistent) }
	prototype := get_prototype_from_constructor(mut vm, new_target, fn (realm &Realm) &Object { return realm.intl_locale_prototype or { panic('Missing Intl.Locale prototype') } })!
	mut id := intl_locale_identifier_value(mut vm, vm.argument(0))!
	options := intl_options_object(mut vm, vm.argument(1))!
	for name in ['language', 'script', 'region', 'variants'] {
		value := intl_string_option(mut vm, options, name, [])!
		if value.is_undefined() { continue }
		text := intl_ascii(mut vm, value.as_string().utf16)!
		match name {
			'language' { if !intl_language_subtag(text) { return vm.throw_error(.range_error, 'Invalid Intl.Locale language') }; id.language = text.to_lower() }
			'script' { if text.len != 4 || !intl_alpha(text) { return vm.throw_error(.range_error, 'Invalid Intl.Locale script') }; lower := text.to_lower(); id.script = lower[..1].to_upper() + lower[1..] }
			'region' { if !intl_region_subtag(text) { return vm.throw_error(.range_error, 'Invalid Intl.Locale region') }; id.region = text.to_upper() }
			else {
				mut seen := map[string]bool{}
				mut variants := []string{}
				for part in text.to_lower().split('-') {
					if !intl_variant_subtag(part) || seen[part] { return vm.throw_error(.range_error, 'Invalid Intl.Locale variants') }
					seen[part] = true; variants << part
				}
				id.variants = variants
			}
		}
	}
	id = intl_canonical_base(mut vm, id)!
	mut keywords := id.keywords.clone()
	for name in ['calendar', 'collation', 'firstDayOfWeek', 'hourCycle', 'caseFirst', 'numeric', 'numberingSystem'] {
		key := match name { 'calendar' { 'ca' } 'collation' { 'co' } 'firstDayOfWeek' { 'fw' } 'hourCycle' { 'hc' } 'caseFirst' { 'kf' } 'numeric' { 'kn' } else { 'nu' } }
		if name == 'numeric' {
			value := options.get(mut vm, PropertyName.from_str(name))!
			if !value.is_undefined() { keywords[key] = if value.to_boolean() { '' } else { 'false' } }
			continue
		}
		allowed := match name { 'hourCycle' { ['h11', 'h12', 'h23', 'h24'] } 'caseFirst' { ['upper', 'lower', 'false'] } else { []string{} } }
		value := intl_string_option(mut vm, options, name, allowed)!
		if value.is_undefined() { continue }
		mut text := intl_ascii(mut vm, value.as_string().utf16)!.to_lower()
		if name == 'firstDayOfWeek' {
			if text in ['1','2','3','4','5','6','7'] { text = ['mon','tue','wed','thu','fri','sat','sun'][text.int() - 1] }
			if text !in ['mon','tue','wed','thu','fri','sat','sun'] { return vm.throw_error(.range_error, 'Invalid Intl.Locale firstDayOfWeek') }
		} else if !intl_type_identifier(text) { return vm.throw_error(.range_error, 'Invalid Intl.Locale ' + name) }
		keywords[key] = text
	}
	id.keywords = keywords
	id = intl_canonicalize_language_tag(mut vm, utf16_string(id.tag()))!
	return intl_locale_create(mut vm, id, prototype)
}

fn intl_maximize_identifier(mut vm VM, original IntlLocaleIdentifier) !IntlLocaleIdentifier {
	persistent := platform.enter_persistent()
	defer { platform.leave_persistent(persistent) }
	core := intl_core_data(mut vm)!
	mut id := original
	script := if id.script == 'Zzzz' { '' } else { id.script }
	region := if id.region == 'ZZ' { '' } else { id.region }
	mut searches := []string{}
	if script != '' && region != '' { searches << id.language + '-' + script + '-' + region }
	if script != '' { searches << id.language + '-' + script }
	if region != '' { searches << id.language + '-' + region }
	searches << id.language
	if script != '' { searches << 'und-' + script }
	if region != '' { searches << 'und-' + region }
	searches << 'und'
	for search in searches {
		if value := core.likely_subtags[search] {
			base, _ := intl_parse_base(mut vm, value.split('-'))!
			if id.language == 'und' { id.language = base.language }
			if script == '' { id.script = base.script }
			if region == '' { id.region = base.region }
			return id
		}
	}
	return id
}

fn intl_locale_minimize(mut vm VM, original IntlLocaleIdentifier) !IntlLocaleIdentifier {
	persistent := platform.enter_persistent()
	defer { platform.leave_persistent(persistent) }
	maximum := intl_maximize_identifier(mut vm, original)!
	mut trials := [IntlLocaleIdentifier{language: maximum.language}, IntlLocaleIdentifier{language: maximum.language, region: maximum.region}, IntlLocaleIdentifier{language: maximum.language, script: maximum.script}]
	for trial in trials {
		expanded := intl_maximize_identifier(mut vm, trial)!
		if expanded.language == maximum.language && expanded.script == maximum.script && expanded.region == maximum.region {
			mut result := original; result.language = trial.language; result.script = trial.script; result.region = trial.region
			return result
		}
	}
	return original
}

fn intl_locale_property(mut vm VM, name string) !Value {
	id := intl_locale_this(mut vm)!.identifier
	if name == 'baseName' { return Value.from_string(vm.create_string_from_str(id.base_name())) }
	if name == 'language' { return Value.from_string(vm.create_string_from_str(id.language)) }
	if name == 'script' { return if id.script != '' { Value.from_string(vm.create_string_from_str(id.script)) } else { js_undefined() } }
	if name == 'region' { return if id.region != '' { Value.from_string(vm.create_string_from_str(id.region)) } else { js_undefined() } }
	if name == 'variants' { return if id.variants.len > 0 { Value.from_string(vm.create_string_from_str(id.variants.join('-'))) } else { js_undefined() } }
	key := match name { 'calendar' { 'ca' } 'collation' { 'co' } 'firstDayOfWeek' { 'fw' } 'hourCycle' { 'hc' } 'caseFirst' { 'kf' } 'numeric' { 'kn' } else { 'nu' } }
	if name == 'numeric' { return Value.from_bool(key in id.keywords && id.keywords[key] != 'false') }
	if value := id.keywords[key] { return Value.from_string(vm.create_string_from_str(if value == '' { 'true' } else { value })) }
	return js_undefined()
}

fn initialize_intl_intrinsics(mut vm VM, mut realm Realm) {
	mut namespace := Object.create(realm, realm.object_prototype)
	realm.intl_object = namespace
	namespace.define_direct_property(PropertyName.from_symbol(vm.well_known_symbol_to_string_tag()), Value.from_string(vm.create_string_from_str('Intl')), attribute_configurable)
	install_intrinsic_method(mut vm, realm, mut namespace, 'getCanonicalLocales', 1, fn (mut vm VM) !Value { return intl_string_array(mut vm, intl_canonicalize_locale_list(mut vm, vm.argument(0))!) })
	mut prototype := Object.create(realm, realm.object_prototype)
	realm.intl_locale_prototype = prototype
	mut constructor := NativeFunction.create_constructor(mut vm, realm, realm.function_prototype, fn (mut vm VM) !Value { return vm.throw_error(.type_error, 'Intl.Locale constructor requires new') }, intl_locale_construct, 1, PropertyName.from_str('Locale')).object
	realm.intl_locale_constructor = constructor
	constructor.define_direct_property(PropertyName.from_str('prototype'), Value.from_object(prototype), 0)
	prototype.define_direct_property(PropertyName.from_str('constructor'), Value.from_object(constructor), attribute_writable | attribute_configurable)
	prototype.define_direct_property(PropertyName.from_symbol(vm.well_known_symbol_to_string_tag()), Value.from_string(vm.create_string_from_str('Intl.Locale')), attribute_configurable)
	install_intrinsic_method(mut vm, realm, mut prototype, 'toString', 0, fn (mut vm VM) !Value { return Value.from_string(vm.create_string_from_str(intl_locale_this(mut vm)!.identifier.tag())) })
	for name in ['maximize', 'minimize'] {
		install_intrinsic_method(mut vm, realm, mut prototype, name, 0, fn [name] (mut vm VM) !Value {
			id := intl_locale_this(mut vm)!.identifier
			result := if name == 'maximize' { intl_maximize_identifier(mut vm, id)! } else { intl_locale_minimize(mut vm, id)! }
			return Value.from_object(intl_locale_create(mut vm, result, vm.realm().intl_locale_prototype or { panic('Missing Intl.Locale prototype') }))
		})
	}
	for name in ['baseName', 'language', 'script', 'region', 'variants', 'calendar', 'collation', 'firstDayOfWeek', 'hourCycle', 'caseFirst', 'numeric', 'numberingSystem'] {
		prototype.define_native_accessor(mut vm, realm, PropertyName.from_str(name), fn [name] (mut vm VM) !Value { return intl_locale_property(mut vm, name) }, unsafe { nil }, attribute_configurable, realm.function_prototype)
	}
	namespace.define_direct_property(PropertyName.from_str('Locale'), Value.from_object(constructor), attribute_writable | attribute_configurable)
}

fn intl_best_available_locale(core &IntlCoreData, candidate string) ?string {
	mut locale := candidate
	for {
		if locale in core.locale_spans { return locale }
		at := locale.last_index('-') or { return none }
		locale = locale[..at]
	}
	return none
}

fn intl_supported_locales(mut vm VM, locales Value, options Value) !Value {
	requested := intl_canonicalize_locale_list(mut vm, locales)!
	object := intl_options_object(mut vm, options)!
	intl_string_option(mut vm, object, 'localeMatcher', ['lookup', 'best fit'])!
	core := intl_core_data(mut vm)!
	mut supported := []string{}
	for locale in requested {
		id := intl_canonicalize_language_tag(mut vm, utf16_string(locale))!
		if intl_best_available_locale(core, id.base_name()) != none { supported << locale }
	}
	return intl_string_array(mut vm, supported)
}

fn intl_resolve_locale(mut vm VM, requested []string) !(string, IntlLocaleIdentifier) {
	core := intl_core_data(mut vm)!
	for tag in requested {
		id := intl_canonicalize_language_tag(mut vm, utf16_string(tag))!
		if available := intl_best_available_locale(core, id.base_name()) { return available, id }
	}
	default_id := intl_canonicalize_language_tag(mut vm, utf16_string(vm.realm().intl_default_locale))!
	return intl_best_available_locale(core, default_id.base_name()) or { 'en-US' }, default_id
}
