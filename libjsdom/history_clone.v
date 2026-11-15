// SPDX-License-Identifier: BSD-2-Clause
module libjsdom

import dom
import html
import libjs
import webidl

// Engine projection for History's storage clone. This slice supports primitive
// values, ordinary objects and arrays; unsupported internal-slot/platform
// families fail explicitly rather than silently losing their data.
struct HistoryClone {
	host &Host
mut:
	input map[voidptr]&dom.JSValue
	output map[voidptr]libjs.Value
}

fn (host &Host) history_platform_object(object &libjs.Object) bool {
	key := voidptr(object)
	return key == voidptr(host.realm.global_object_record()) || key == voidptr(host.history_object)
		|| key == voidptr(host.navigator_object) || key in host.nodes || key in host.events
		|| key in host.event_targets || key in host.style_elements || key in host.registries
		|| key in host.abort_controllers || key in host.abort_signals || key in host.dom_exceptions
		|| key in host.headers || key in host.headers_iterators || key in host.queries || key in host.query_iterators
		|| key in host.fetch_requests || key in host.fetch_responses || key in host.mutation_observers
		|| key in host.mutation_records || key in host.media_queries || key in host.read_only_rects
		|| key in host.intersection_observers || key in host.intersection_entries
		|| key in host.resize_observers || key in host.resize_entries || key in host.resize_sizes
}

fn (mut clone HistoryClone) project(mut vm libjs.VM, value libjs.Value, depth int) !dom.JSValue {
	vm.consume_execution_budget()!
	match value.tag {
		.undefined { return dom.js_undefined() }
		.null { return dom.js_null() }
		.boolean { return dom.js_bool(value.as_bool()) }
		.int32, .double { return dom.js_number(value.number) }
		.string { return dom.js_utf16_string(value.as_string().utf16) }
		.bigint { return dom.js_webidl_value(webidl.bigint_value_for_record(value.as_bigint())) }
		.object {}
		else { return error('DataCloneError: unsupported History state value') }
	}
	mut object := value.as_object()
	identity := voidptr(object)
	if previous := clone.input[identity] { return *previous }
	if depth >= 128 { return error('DataCloneError: History state nesting limit exceeded') }
	if clone.host.history_platform_object(object) || object.callable != none || object.constructor != none
		|| object.host_properties != none || object.is_arguments_object
		|| object.regexp_object != none || object.regexp_string_iterator != none || object.keyed_collection != none || object.keyed_iterator != none
		|| object.intl_list_format != none || object.intl_date_time_format != none || object.intl_locale != none || object.proxy_object != none || object.weak_map != none || object.weak_set != none || object.weak_ref != none || object.boolean_object != none
		|| object.date_object != none || object.number_object != none || object.bigint_object != none
		|| object.symbol_object != none || object.string_object != none || object.string_iterator != none
		|| object.array_iterator != none || object.property_name_iterator != none || object.iterator_record != none
		|| object.promise_record != none || object.generator_execution != none || object.array_buffer != none || object.data_view != none
		|| object.typed_array != none || object.error_data != none
		|| (object.array_object == none && object.class_name != 'Object') {
		return error('DataCloneError: unsupported History state object')
	}
	mut native := html.StructuredObject.create(if object.array_object != none { .array } else { .object })
	if array := object.array_object { native.array_length = array.length }
	result := dom.js_structured_object(voidptr(native))
	clone.input[identity] = &result
	// Snapshot enumerable own string keys before invoking any author getter.
	mut keys := []libjs.PropertyName{}
	for key in object.own_property_keys() {
		vm.consume_execution_budget()!
		if key.is_symbol() { continue }
		descriptor := object.internal_get_own_property(key) or { continue }
		if descriptor.enumerable or { false } { keys << key }
	}
	for key in keys {
		vm.consume_execution_budget()!
		if !object.has_own_property(key) { continue }
		item := object.get(mut vm, key)!
		projected := clone.project(mut vm, item, depth + 1)!
		text := if key.is_number() { libjs.utf16_string(key.number.str()) } else { key.as_string() }
		native.properties << html.StructuredProperty{key: text.str(), key_utf16_: text, value: &projected}
	}
	return result
}

fn (mut clone HistoryClone) reconstruct(mut vm libjs.VM, value dom.JSValue, depth int) !libjs.Value {
	vm.consume_execution_budget()!
	match value.kind {
		.undefined { return libjs.js_undefined() }
		.null_ { return libjs.js_null() }
		.boolean { return libjs.Value.from_bool(value.boolean_data) }
		.number { return libjs.Value.from_f64(value.number_data) }
		.string { return libjs.Value.from_string(vm.create_string(value.string_utf16_ or { libjs.utf16_string(value.string_data) })) }
		.runtime_value {
			actual := value.as_webidl_value()!
			if actual.kind == .bigint {
				return libjs.Value.from_bigint(actual.bigint_record_ or { return error('DataCloneError: missing stored BigInt') })
			}
			return error('DataCloneError: unsupported stored History primitive')
		}
		.object {}
	}
	native := html.structured_object_from_value(value)!
	if previous := clone.output[voidptr(native)] { return previous }
	if depth >= 128 { return error('DataCloneError: History state nesting limit exceeded') }
	if native.kind !in [.object, .array] { return error('DataCloneError: unsupported stored History object') }
	mut object := if native.kind == .array {
		libjs.ArrayObject.create(mut vm, clone.host.realm, u64(native.array_length or { 0 }), clone.host.realm.array_prototype_record())!.object
	} else { libjs.Object.create(clone.host.realm, clone.host.realm.object_prototype) }
	result := libjs.Value.from_object(object)
	clone.output[voidptr(native)] = result
	for property in native.properties {
		vm.consume_execution_budget()!
		item := clone.reconstruct(mut vm, *property.value, depth + 1)!
		object.create_data_property_or_throw(mut vm, libjs.PropertyName.from_utf16(property.key_utf16_ or { libjs.utf16_string(property.key) }), item)!
	}
	return result
}
