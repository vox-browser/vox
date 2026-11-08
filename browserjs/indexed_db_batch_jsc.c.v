module browserjs

import indexeddb
import webidl

fn indexed_db_retrieval_kind(method string) indexeddb.IDBRetrievalKind {
	return match method {
		'getAllKeys' { .keys }
		'getAllRecords' { .records }
		else { .values }
	}
}

fn (mut runtime Runtime) indexed_db_batch_count(value voidptr) !u32 {
	// An absent count and zero both mean no limit in IndexedDB retrieval.
	if C.JSValueIsUndefined(runtime.context, value) { return 0 }
	mut exception := unsafe { nil }
	number := C.vox_jsc_JSValueToNumber(runtime.context, value, &exception)
	if exception != unsafe { nil } { return runtime.actual_javascript_exception(exception) }
	return u32(webidl.convert_to_int(webidl.number_value(number), 32, false, .yes, .no)!)
}

fn (runtime &Runtime) indexed_db_batch_direction(value voidptr) !indexeddb.IDBCursorDirection {
	if C.JSValueIsUndefined(runtime.context, value) { return .next }
	return match runtime.indexed_db_dom_string(value)! {
		'next' { .next }
		'nextunique' { .nextunique }
		'prev' { .prev }
		'prevunique' { .prevunique }
		else { return runtime.event_binding_type_error('Invalid IndexedDB retrieval direction') }
	}
}

fn (runtime &Runtime) indexed_db_batch_property(value voidptr, name string) !voidptr {
	mut exception := unsafe { nil }
	object := C.vox_jsc_JSValueToObject(runtime.context, value, &exception)
	if exception != unsafe { nil } { return runtime.actual_javascript_exception(exception) }
	return runtime.binding_property(object, name)
}

fn (mut runtime Runtime) indexed_db_batch_options(binding &IndexedDBBinding, entry &IndexedDBBindingEntry, method string, args []voidptr) !indexeddb.IDBGetAllOptions {
	input := runtime.ui_event_argument(args, 2)
	mut query := input
	mut count := u32(0)
	mut direction := indexeddb.IDBCursorDirection.next
	if method == 'getAllRecords' {
		// Dictionary conversion happens before checking the native source.
		count = runtime.indexed_db_batch_count(runtime.ui_event_dictionary_member(input, 'count')!)!
		direction = runtime.indexed_db_batch_direction(runtime.ui_event_dictionary_member(input, 'direction')!)!
		query = runtime.ui_event_dictionary_member(input, 'query')!
	} else {
		count = runtime.indexed_db_batch_count(runtime.ui_event_argument(args, 3))!
	}
	if entry.kind == .object_store {
		entry.store.require_cursor_source()!
	} else {
		entry.index.require_cursor_source()!
	}
	if method != 'getAllRecords' && !runtime.indexed_db_potential_query(binding, input)! {
		// The legacy any argument is inspected by the retrieval algorithm,
		// after source validation. The dictionary's count overrides argument 2.
		query = runtime.indexed_db_batch_property(input, 'query')!
		range := runtime.indexed_db_query_range(binding, query, false)!
		count = runtime.indexed_db_batch_count(runtime.indexed_db_batch_property(input, 'count')!)!
		direction = runtime.indexed_db_batch_direction(runtime.indexed_db_batch_property(input, 'direction')!)!
		return indexeddb.IDBGetAllOptions{ range: range, count: count, direction: direction }
	}
	return indexeddb.IDBGetAllOptions{
		range:     runtime.indexed_db_query_range(binding, query, false)!
		count:     count
		direction: direction
	}
}

fn (runtime &Runtime) indexed_db_potential_query(binding &IndexedDBBinding, value voidptr) !bool {
	if C.JSValueIsNull(runtime.context, value) || C.JSValueIsUndefined(runtime.context, value)
		|| C.JSValueIsNumber(runtime.context, value) || C.JSValueIsString(runtime.context, value)
		|| C.JSValueIsArray(runtime.context, value) || value in binding.key_ranges {
		return true
	}
	if !C.JSValueIsObject(runtime.context, value) { return false }
	tag := int(binding.clone.number(binding.clone.engine('classify', [value])!)!)
	return tag in [11, 22, 23]
}

struct IndexedDBRecordBinding {
	record indexeddb.IDBRecord
	value  voidptr
}

fn (mut runtime Runtime) indexed_db_records(mut binding IndexedDBBinding, records []indexeddb.IDBRecord) !voidptr {
	mut wrappers := []voidptr{cap: records.len}
	for record in records {
		object := runtime.retain_javascript_value(C.JSObjectMake(runtime.context, unsafe { nil }, unsafe { nil }))!
		C.JSObjectSetPrototype(runtime.context, object, binding.record_prototype)
		binding.records[object] = IndexedDBRecordBinding{ record: record, value: runtime.indexed_db_output(record.value)! }
		wrappers << object
	}
	mut exception := unsafe { nil }
	array := C.vox_jsc_JSObjectMakeArray(runtime.context, uint(wrappers.len), wrappers.data, &exception)
	if exception != unsafe { nil } { return runtime.actual_javascript_exception(exception) }
	return array
}

fn (mut runtime Runtime) indexed_db_record_operation(record IndexedDBRecordBinding, method string, args []voidptr) !voidptr {
	if method == 'brand' {
		if runtime.indexed_db_dom_string(args[2])! != 'IDBRecord' {
			return runtime.event_binding_type_error('Illegal IDBRecord receiver')
		}
		return C.vox_jsc_JSValueMakeUndefined(runtime.context)
	}
	if method == 'key' {
		return runtime.indexed_db_output(indexeddb.key_to_value(record.record.key)!)
	}
	if method == 'primaryKey' {
		return runtime.indexed_db_output(indexeddb.key_to_value(record.record.primary_key)!)
	}
	if method == 'value' { return record.value }
	return runtime.event_binding_type_error('Illegal IDBRecord operation')
}
