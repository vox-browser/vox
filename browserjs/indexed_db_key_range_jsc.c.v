module browserjs

import indexeddb

fn (mut runtime Runtime) indexed_db_construct_key_range(mut binding IndexedDBBinding, method string, args []voidptr) !voidptr {
	lower := runtime.indexed_db_key(args[2])!
	range := match method {
		'only' { indexeddb.IDBKeyRange.only(lower)! }
		'lowerBound' {
			indexeddb.IDBKeyRange.lower_bound(lower, C.JSValueToBoolean(runtime.context, runtime.ui_event_argument(args, 3)))!
		}
		'upperBound' {
			indexeddb.IDBKeyRange.upper_bound(lower, C.JSValueToBoolean(runtime.context, runtime.ui_event_argument(args, 3)))!
		}
		'bound' {
			upper := runtime.indexed_db_key(args[3])!
			indexeddb.IDBKeyRange.bound(lower, upper,
				C.JSValueToBoolean(runtime.context, runtime.ui_event_argument(args, 4)),
				C.JSValueToBoolean(runtime.context, runtime.ui_event_argument(args, 5)))!
		}
		else { return runtime.event_binding_type_error('Illegal IDBKeyRange operation') }
	}
	object := runtime.retain_javascript_value(C.JSObjectMake(runtime.context, unsafe { nil }, unsafe { nil }))!
	C.JSObjectSetPrototype(runtime.context, object, binding.key_range_prototype)
	binding.key_ranges[object] = range
	return object
}

fn (mut runtime Runtime) indexed_db_range_operation(range indexeddb.IDBKeyRange, method string, args []voidptr) !voidptr {
	if method == 'brand' {
		if runtime.indexed_db_dom_string(args[2])! != 'IDBKeyRange' {
			return runtime.event_binding_type_error('Illegal IndexedDB receiver')
		}
		return C.vox_jsc_JSValueMakeUndefined(runtime.context)
	}
	if method == 'lowerOpen' {
		return C.vox_jsc_JSValueMakeBoolean(runtime.context, range.lower_open)
	}
	if method == 'upperOpen' {
		return C.vox_jsc_JSValueMakeBoolean(runtime.context, range.upper_open)
	}
	if method in ['lower', 'upper'] {
		key := if method == 'lower' { range.lower } else { range.upper }
		if actual := key { return runtime.indexed_db_output(indexeddb.key_to_value(actual)!) }
		return C.vox_jsc_JSValueMakeUndefined(runtime.context)
	}
	if method == 'includes' {
		return C.vox_jsc_JSValueMakeBoolean(runtime.context, range.includes(runtime.indexed_db_key(args[2])!)!)
	}
	return runtime.event_binding_type_error('Illegal IDBKeyRange operation')
}

fn (mut runtime Runtime) indexed_db_query_range(binding &IndexedDBBinding, value voidptr, null_disallowed bool) !indexeddb.IDBKeyRange {
	if C.JSValueIsUndefined(runtime.context, value) || C.JSValueIsNull(runtime.context, value) {
		if null_disallowed { return error('DataError: query requires a key or key range') }
		return indexeddb.IDBKeyRange.unbounded()
	}
	if range := binding.key_ranges[value] { return range }
	return indexeddb.IDBKeyRange.only(runtime.indexed_db_key(value)!)
}
