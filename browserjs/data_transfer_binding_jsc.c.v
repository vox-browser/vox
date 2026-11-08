// HTML/DataTransfer.{idl,h,cpp}: native strings, effects and file snapshots.
module browserjs

import html
import libjs


struct DataTransferTypesArray {
	revision u64
	value    voidptr
}

fn (mut runtime Runtime) install_data_transfer_binding() ! {
	mut binding := runtime.event_binding()!
	if binding.data_transfer_constructor != unsafe { nil } { return }
	runtime.install_data_transfer_identity()!
	runtime.install_data_transfer_items_binding()!
	owner := voidptr(&runtime)
	mut functions := []voidptr{}
	for operation in ['construct', 'getDrop', 'setDrop', 'getEffect', 'setEffect', 'getTypes', 'getFiles',
		'getItems', 'getData', 'setData', 'clearData'] {
		name := match operation {
			'construct' { 'DataTransfer' }
			'getDrop' { 'get dropEffect' }
			'setDrop' { 'set dropEffect' }
			'getEffect' { 'get effectAllowed' }
			'setEffect' { 'set effectAllowed' }
			'getTypes' { 'get types' }
			'getFiles' { 'get files' }
			'getItems' { 'get items' }
			else { operation }
		}

		length := if operation == 'setData' {
			2
		} else if operation in ['getData', 'setDrop', 'setEffect'] {
			1
		} else {
			0
		}
		functions << runtime.make_native_value_host_function(name, length, fn [owner, operation] (receiver voidptr, args []voidptr) !voidptr {
			mut runtime := unsafe { &Runtime(owner) }
			return runtime.data_transfer_binding_call(operation, receiver, args)
		})!
	}
	// Retain the intrinsic before author code can replace the public property.
	binding.data_transfer_freeze_array = runtime.evaluate_host_value('Object.freeze')!
	factory := runtime.evaluate_host_value(data_transfer_bootstrap())!
	defer { runtime.release_javascript_value(factory) }
	mut call_arguments := [binding.data_transfer_prototype, C.JSContextGetGlobalObject(runtime.context)]
	call_arguments << functions
	binding.data_transfer_constructor = runtime.retain_javascript_value(runtime.call_javascript_function(factory,
		C.vox_jsc_JSValueMakeUndefined(runtime.context), call_arguments)!)!
}

fn (mut runtime Runtime) data_transfer_types_array(transfer &html.DataTransfer) !voidptr {
	mut binding := runtime.event_binding()!
	key := voidptr(transfer)
	revision := transfer.types_revision()
	if cached := binding.data_transfer_types_arrays[key] {
		if cached.revision == revision { return cached.value }
	}
	mut values := []voidptr{}
	defer {
		for value in values {
			runtime.release_javascript_value(value)
		}
	}
	for text in transfer.types_utf16() {
		values << runtime.retain_javascript_value(runtime.binding_utf16_string(text)!)!
	}
	mut exception := unsafe { nil }
	array := C.vox_jsc_JSObjectMakeArray(runtime.context, uint(values.len), values.data, &exception)
	if exception != unsafe { nil } { return runtime.actual_javascript_exception(exception) }
	runtime.retain_javascript_value(array)!
	runtime.call_javascript_function(binding.data_transfer_freeze_array,
		C.vox_jsc_JSValueMakeUndefined(runtime.context), [array]) or {
		runtime.release_javascript_value(array)
		return err
	}
	if cached := binding.data_transfer_types_arrays[key] {
		runtime.release_javascript_value(cached.value)
	}
	binding.data_transfer_types_arrays[key] = DataTransferTypesArray{
		revision: revision
		value:    array
	}
	return array
}

fn (mut runtime Runtime) data_transfer_binding_call(operation string, receiver voidptr, args []voidptr) !voidptr {
	if operation == 'construct' {
		runtime.bind_data_transfer(receiver, html.DataTransfer.construct_impl())!
		return C.vox_jsc_JSValueMakeUndefined(runtime.context)
	}
	// Generated bindings require the native receiver before arity/conversion,
	// even when a store is protected, read-only or already disassociated.
	mut transfer := runtime.native_data_transfer(receiver)!
	match operation {
		'getDrop' {
			return runtime.binding_string(transfer.drop_effect())
		}
		'getEffect' {
			return runtime.binding_string(transfer.effect_allowed())
		}
		'getTypes' {
			return runtime.data_transfer_types_array(transfer)
		}
		'getFiles' {
			return runtime.javascript_file_list(transfer.live_file_list())
		}
		'getItems' {
			return runtime.javascript_data_transfer_item_list(transfer.items())
		}
		'setDrop', 'setEffect' {
			value := runtime.binding_dom_utf16(runtime.ui_event_argument(args, 0))!
			if operation == 'setDrop' {
				transfer.set_drop_effect(value.str())
			} else {
				transfer.set_effect_allowed(value.str())
			}
		}
		'getData' {
			if args.len < 1 {
				return runtime.event_binding_type_error('getData() requires one argument')
			}
			format := runtime.binding_dom_utf16(args[0])!
			return runtime.binding_utf16_string(transfer.get_data_utf16(format))
		}
		'setData' {
			if args.len < 2 {
				return runtime.event_binding_type_error('setData() requires two arguments')
			}
			format := runtime.binding_dom_utf16(args[0])!
			data := runtime.binding_dom_utf16(args[1])!
			transfer.set_data_utf16(format, data)
		}
		'clearData' {
			mut format := ?libjs.Utf16String(none)
			if args.len > 0 && !C.JSValueIsUndefined(runtime.context, args[0]) {
				format = runtime.binding_dom_utf16(args[0])!
			}
			transfer.clear_data_utf16(format)
		}
		else {
			return runtime.event_binding_type_error('Unknown DataTransfer operation')
		}
	}

	return C.vox_jsc_JSValueMakeUndefined(runtime.context)
}
