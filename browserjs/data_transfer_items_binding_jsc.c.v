// HTML/DataTransferItem{,List}.{idl,h,cpp} and generated platform-object bindings.
module browserjs

import html
import libjs
import webidl


@[heap]
struct DataTransferItemsBinding {
mut:
	items             map[voidptr]&html.DataTransferItem
	item_wrappers     map[voidptr]voidptr
	lists             map[voidptr]&html.DataTransferItemList
	list_wrappers     map[voidptr]voidptr
	item_prototype    voidptr
	list_prototype    voidptr
	wrap_item         voidptr
	wrap_list         voidptr
	install_function  voidptr
	item_constructor  voidptr
	list_constructor  voidptr
	not_callable_message voidptr
	string_callbacks map[u64]&DataTransferStringCallbackRecord
}

@[heap]
struct DataTransferStringCallbackRecord {
	function voidptr
mut:
	task_id u64
}

fn (mut runtime Runtime) install_data_transfer_items_identity() ! {
	mut binding := runtime.event_binding()!
	if binding.data_transfer_item_binding != unsafe { nil } { return }
	owner := voidptr(&runtime)
	operate := runtime.make_value_host_function(fn [owner] (_ voidptr, args []voidptr) !voidptr {
		mut runtime := unsafe { &Runtime(owner) }
		operation := runtime.binding_dom_string(runtime.ui_event_argument(args, 0))!
		if operation == 'arrayIndex' {
			key := libjs.PropertyName.from_utf16(runtime.native_utf16_string(runtime.ui_event_argument(args, 1))!)
			if !key.is_number() { return C.vox_jsc_JSValueMakeUndefined(runtime.context) }
			return C.vox_jsc_JSValueMakeNumber(runtime.context, f64(key.number))
		}
		list := runtime.native_data_transfer_item_list(runtime.ui_event_argument(args, 1))!
		index := u32(webidl.convert_to_int(runtime.webidl_value(runtime.ui_event_argument(args, 2))!,
			32, false, .no, .no)!)
		item := list.item(uint(index)) or { return C.vox_jsc_JSValueMakeUndefined(runtime.context) }
		return runtime.javascript_data_transfer_item(item)
	})!
	factory := runtime.evaluate_host_value(data_transfer_items_identity_factory())!
	defer { runtime.release_javascript_value(factory) }
	identity := runtime.call_javascript_function(factory, C.vox_jsc_JSValueMakeUndefined(runtime.context), [operate])!
	// Retain the private object while reading its members across engine calls.
	runtime.retain_javascript_value(identity)!
	defer { runtime.release_javascript_value(identity) }
	binding.data_transfer_item_binding = &DataTransferItemsBinding{
		item_prototype: runtime.retain_javascript_value(runtime.binding_property(identity, 'itemPrototype')!)!
		list_prototype: runtime.retain_javascript_value(runtime.binding_property(identity, 'listPrototype')!)!
		wrap_item: runtime.retain_javascript_value(runtime.binding_property(identity, 'wrapItem')!)!
		wrap_list: runtime.retain_javascript_value(runtime.binding_property(identity, 'wrapList')!)!
		install_function: runtime.retain_javascript_value(runtime.binding_property(identity, 'install')!)!
		not_callable_message: runtime.retain_javascript_value(runtime.binding_property(identity, 'notCallableMessage')!)!
	}
}

fn (mut runtime Runtime) install_data_transfer_items_binding() ! {
	runtime.install_data_transfer_items_identity()!
	runtime.install_file_system_entry_binding()!
	mut binding := runtime.event_binding()!.data_transfer_item_binding
	if binding.item_constructor != unsafe { nil } { return }
	owner := voidptr(&runtime)
	mut functions := []voidptr{}
	for operation in ['kind', 'type', 'getAsFile', 'getAsString', 'webkitGetAsEntry', 'length', 'add', 'remove', 'clear'] {
		name := if operation in ['kind', 'type', 'length'] { 'get ' + operation } else { operation }
		length := if operation in ['getAsString', 'add', 'remove'] { 1 } else { 0 }
		functions << runtime.make_native_value_host_function(name, length, fn [owner, operation] (receiver voidptr, args []voidptr) !voidptr {
			mut runtime := unsafe { &Runtime(owner) }
			return runtime.data_transfer_items_binding_call(operation, receiver, args)
		})!
	}
	mut call_arguments := [C.JSContextGetGlobalObject(runtime.context)]
	call_arguments << functions
	constructors := runtime.call_javascript_function(binding.install_function, C.vox_jsc_JSValueMakeUndefined(runtime.context), call_arguments)!
	runtime.retain_javascript_value(constructors)!
	defer { runtime.release_javascript_value(constructors) }
	binding.item_constructor = runtime.retain_javascript_value(runtime.binding_property(constructors, 'DataTransferItem')!)!
	binding.list_constructor = runtime.retain_javascript_value(runtime.binding_property(constructors, 'DataTransferItemList')!)!
}

fn (mut runtime Runtime) data_transfer_items_binding_call(operation string, receiver voidptr, args []voidptr) !voidptr {
	if operation in ['kind', 'type', 'getAsFile', 'getAsString', 'webkitGetAsEntry'] {
		item := runtime.native_data_transfer_item(receiver)!
		if operation == 'getAsString' {
			if args.len == 0 { return runtime.event_binding_type_error('getAsString() needs one argument') }
			function := args[0]
			if C.JSValueIsNull(runtime.context, function) || C.JSValueIsUndefined(runtime.context, function) {
				return C.vox_jsc_JSValueMakeUndefined(runtime.context)
			}
			if !C.JSValueIsObject(runtime.context, function) || !C.JSObjectIsFunction(runtime.context, function) {
				binding := runtime.event_binding()!.data_transfer_item_binding
				// JSC's public ABI has no side-effect-free native class-name query.
				// Primitive diagnostics retain their raw units; objects use Object.
				message := runtime.call_javascript_function(binding.not_callable_message,
					C.vox_jsc_JSValueMakeUndefined(runtime.context), [function])!
				actual := runtime.call_engine_function(runtime.value_error_intrinsic_, [runtime.binding_string('TypeError'), message])!
				return runtime.actual_javascript_exception(actual)
			}
			data := item.string_data_utf16() or { return C.vox_jsc_JSValueMakeUndefined(runtime.context) }
			runtime.queue_data_transfer_string_callback(function, data)!
			return C.vox_jsc_JSValueMakeUndefined(runtime.context)
		}
		return match operation {
			'kind' { runtime.binding_string(item.kind()) }
			'type' { runtime.binding_utf16_string(item.type_utf16())! }
			'webkitGetAsEntry' {
				entry := item.webkit_get_as_entry() or { return C.vox_jsc_JSValueMakeNull(runtime.context) }
				runtime.javascript_file_system_entry(entry)!
			}
			else { runtime.javascript_data_transfer_item_file(item)! }
		}
	}
	// The generated overload arbiter runs before the selected function's brand.
	if operation == 'add' && args.len == 0 {
		return runtime.event_binding_type_error('Overload resolution failed')
	}
	// Selected operations brand before conversion and the implementation's gate.
	mut list := runtime.native_data_transfer_item_list(receiver)!
	match operation {
		'length' { return C.vox_jsc_JSValueMakeNumber(runtime.context, f64(u32(list.length()))) }
		'add' {
			// Generated effective overload sets choose File for one argument and
			// DOMString, DOMString for two or more, regardless of the first value.
			if args.len == 1 {
				file := runtime.native_file(args[0]) or {
					return runtime.event_binding_type_error('Not an object of type File')
				}
				item := list.add_file_record(file) or { return C.vox_jsc_JSValueMakeNull(runtime.context) }
				return runtime.javascript_data_transfer_item(item)
			}
			data := runtime.binding_dom_utf16(args[0])!
			type_string := runtime.binding_dom_utf16(args[1])!
			result := list.add_string_utf16(data, type_string) or {
				if err.msg().starts_with('NotSupportedError: ') {
					message := libjs.utf16_string_from_utf8_without_validation(err.msg().all_after('NotSupportedError: '))
					exception := webidl.DOMException.create_utf16_record(libjs.utf16_string('NotSupportedError'), message)
					actual := runtime.javascript_dom_exception(webidl.dom_exception_value_for_record(exception))!
					return runtime.actual_javascript_exception(actual)
				}
				return err
			}
			item := result.item or { return C.vox_jsc_JSValueMakeNull(runtime.context) }
			return runtime.javascript_data_transfer_item(item)
		}
		'remove' {
			if args.len < 1 { return runtime.event_binding_type_error('remove() requires one argument') }
			index := u32(webidl.convert_to_int(runtime.webidl_value(args[0])!, 32, false, .no, .no)!)
			list.remove(uint(index)) or {
				if err.msg().starts_with('InvalidStateError: ') {
					actual := runtime.javascript_dom_exception(webidl.dom_exception_value(webidl.DOMException.create('InvalidStateError',
						err.msg().all_after('InvalidStateError: '))))!
					return runtime.actual_javascript_exception(actual)
				}
				return err
			}
		}
		'clear' { list.clear() }
		else { return runtime.event_binding_type_error('Unknown DataTransferItemList operation') }
	}
	return C.vox_jsc_JSValueMakeUndefined(runtime.context)
}

fn (mut runtime Runtime) queue_data_transfer_string_callback(function voidptr, data libjs.Utf16String) ! {
	owner := voidptr(&runtime)
	mut binding := runtime.event_binding()!.data_transfer_item_binding
	callback := runtime.webidl_callback(function, fn [owner] (value webidl.Value) !voidptr {
		mut runtime := unsafe { &Runtime(owner) }
		return match value.kind {
			.undefined { C.vox_jsc_JSValueMakeUndefined(runtime.context) }
			.string_ { runtime.binding_utf16_string(value.string_utf16())! }
			else { return error('Unexpected FunctionStringCallback argument') }
		}
	})!
	mut record := &DataTransferStringCallbackRecord{ function: function }
	record.task_id = html.queue_a_task(.unspecified, none, none, fn [owner, binding, record, callback, data] () {
		mut runtime := unsafe { &Runtime(owner) }
		if runtime.closed { return }
		defer {
			mut retained := unsafe { &DataTransferItemsBinding(binding) }
			retained.string_callbacks.delete(record.task_id)
			runtime.release_javascript_value(record.function)
		}
		// Source discards both the callback's return and abrupt completion.
		result := webidl.invoke_callback(callback, none, [webidl.string_utf16_value(data)]) or {
			value := webidl.exception_value(err)
			if actual := value.runtime_value_ { runtime.release_javascript_value(actual.value) }
			return
		}
		if actual := result.runtime_value_ { runtime.release_javascript_value(actual.value) }
	})
	binding.string_callbacks[record.task_id] = record
}

pub fn (mut runtime Runtime) javascript_data_transfer_item_list(list &html.DataTransferItemList) !voidptr {
	runtime.require_javascript_value_context()!
	if list == unsafe { nil } { return runtime.event_binding_type_error('Missing native DataTransferItemList record') }
	runtime.install_data_transfer_items_identity()!
	mut binding := runtime.event_binding()!.data_transfer_item_binding
	if wrapper := binding.list_wrappers[voidptr(list)] { return wrapper }
	wrapper := runtime.retain_javascript_value(runtime.call_javascript_function(binding.wrap_list,
		C.vox_jsc_JSValueMakeUndefined(runtime.context), [])!)!
	binding.lists[wrapper] = list
	binding.list_wrappers[voidptr(list)] = wrapper
	return wrapper
}

pub fn (runtime &Runtime) native_data_transfer_item_list(wrapper voidptr) !&html.DataTransferItemList {
	binding := runtime.event_binding()!.data_transfer_item_binding
	if binding == unsafe { nil } { return runtime.event_binding_type_error('Not an object of type DataTransferItemList') }
	return binding.lists[wrapper] or { return runtime.event_binding_type_error('Not an object of type DataTransferItemList') }
}

pub fn (mut runtime Runtime) javascript_data_transfer_item(item &html.DataTransferItem) !voidptr {
	runtime.require_javascript_value_context()!
	if item == unsafe { nil } { return runtime.event_binding_type_error('Missing native DataTransferItem record') }
	runtime.install_data_transfer_items_identity()!
	mut binding := runtime.event_binding()!.data_transfer_item_binding
	if wrapper := binding.item_wrappers[voidptr(item)] { return wrapper }
	wrapper := runtime.retain_javascript_value(runtime.call_javascript_function(binding.wrap_item,
		C.vox_jsc_JSValueMakeUndefined(runtime.context), [])!)!
	binding.items[wrapper] = item
	binding.item_wrappers[voidptr(item)] = wrapper
	return wrapper
}

pub fn (runtime &Runtime) native_data_transfer_item(wrapper voidptr) !&html.DataTransferItem {
	binding := runtime.event_binding()!.data_transfer_item_binding
	if binding == unsafe { nil } { return runtime.event_binding_type_error('Not an object of type DataTransferItem') }
	return binding.items[wrapper] or { return runtime.event_binding_type_error('Not an object of type DataTransferItem') }
}
