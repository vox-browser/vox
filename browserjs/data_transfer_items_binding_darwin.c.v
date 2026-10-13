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
			if !key.is_number() { return C.JSValueMakeUndefined(runtime.context) }
			return C.JSValueMakeNumber(runtime.context, f64(key.number))
		}
		list := runtime.native_data_transfer_item_list(runtime.ui_event_argument(args, 1))!
		index := u32(webidl.convert_to_int(runtime.webidl_value(runtime.ui_event_argument(args, 2))!,
			32, false, .no, .no)!)
		item := list.item(usize(index)) or { return C.JSValueMakeUndefined(runtime.context) }
		return runtime.javascript_data_transfer_item(item)
	})!
	factory := runtime.evaluate_host_value(data_transfer_items_identity_factory())!
	defer { runtime.release_javascript_value(factory) }
	identity := runtime.call_javascript_function(factory, C.JSValueMakeUndefined(runtime.context), [operate])!
	// Retain the private object while reading its members across engine calls.
	runtime.retain_javascript_value(identity)!
	defer { runtime.release_javascript_value(identity) }
	binding.data_transfer_item_binding = &DataTransferItemsBinding{
		item_prototype: runtime.retain_javascript_value(runtime.binding_property(identity, 'itemPrototype')!)!
		list_prototype: runtime.retain_javascript_value(runtime.binding_property(identity, 'listPrototype')!)!
		wrap_item: runtime.retain_javascript_value(runtime.binding_property(identity, 'wrapItem')!)!
		wrap_list: runtime.retain_javascript_value(runtime.binding_property(identity, 'wrapList')!)!
		install_function: runtime.retain_javascript_value(runtime.binding_property(identity, 'install')!)!
	}
}

fn (mut runtime Runtime) install_data_transfer_items_binding() ! {
	runtime.install_data_transfer_items_identity()!
	mut binding := runtime.event_binding()!.data_transfer_item_binding
	if binding.item_constructor != unsafe { nil } { return }
	owner := voidptr(&runtime)
	mut functions := []voidptr{}
	for operation in ['kind', 'type', 'getAsFile', 'length', 'add', 'remove', 'clear'] {
		name := if operation in ['kind', 'type', 'length'] { 'get ' + operation } else { operation }
		length := if operation in ['add', 'remove'] { 1 } else { 0 }
		functions << runtime.make_native_value_host_function(name, length, fn [owner, operation] (receiver voidptr, args []voidptr) !voidptr {
			mut runtime := unsafe { &Runtime(owner) }
			return runtime.data_transfer_items_binding_call(operation, receiver, args)
		})!
	}
	mut arguments := [C.JSContextGetGlobalObject(runtime.context)]
	arguments << functions
	constructors := runtime.call_javascript_function(binding.install_function, C.JSValueMakeUndefined(runtime.context), arguments)!
	runtime.retain_javascript_value(constructors)!
	defer { runtime.release_javascript_value(constructors) }
	binding.item_constructor = runtime.retain_javascript_value(runtime.binding_property(constructors, 'DataTransferItem')!)!
	binding.list_constructor = runtime.retain_javascript_value(runtime.binding_property(constructors, 'DataTransferItemList')!)!
}

fn (mut runtime Runtime) data_transfer_items_binding_call(operation string, receiver voidptr, args []voidptr) !voidptr {
	if operation in ['kind', 'type', 'getAsFile'] {
		item := runtime.native_data_transfer_item(receiver)!
		return match operation {
			'kind' { runtime.binding_string(item.kind()) }
			'type' { runtime.binding_utf16_string(item.type_utf16())! }
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
		'length' { return C.JSValueMakeNumber(runtime.context, f64(u32(list.length()))) }
		'add' {
			// Generated effective overload sets choose File for one argument and
			// DOMString, DOMString for two or more, regardless of the first value.
			if args.len == 1 {
				file := runtime.native_file(args[0]) or {
					return runtime.event_binding_type_error('Not an object of type File')
				}
				item := list.add_file_record(file) or { return C.JSValueMakeNull(runtime.context) }
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
			item := result.item or { return C.JSValueMakeNull(runtime.context) }
			return runtime.javascript_data_transfer_item(item)
		}
		'remove' {
			if args.len < 1 { return runtime.event_binding_type_error('remove() requires one argument') }
			index := u32(webidl.convert_to_int(runtime.webidl_value(args[0])!, 32, false, .no, .no)!)
			list.remove(usize(index)) or {
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
	return C.JSValueMakeUndefined(runtime.context)
}

pub fn (mut runtime Runtime) javascript_data_transfer_item_list(list &html.DataTransferItemList) !voidptr {
	runtime.require_javascript_value_context()!
	if list == unsafe { nil } { return runtime.event_binding_type_error('Missing native DataTransferItemList record') }
	runtime.install_data_transfer_items_identity()!
	mut binding := runtime.event_binding()!.data_transfer_item_binding
	if wrapper := binding.list_wrappers[voidptr(list)] { return wrapper }
	wrapper := runtime.retain_javascript_value(runtime.call_javascript_function(binding.wrap_list,
		C.JSValueMakeUndefined(runtime.context), [])!)!
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
		C.JSValueMakeUndefined(runtime.context), [])!)!
	binding.items[wrapper] = item
	binding.item_wrappers[voidptr(item)] = wrapper
	return wrapper
}

pub fn (runtime &Runtime) native_data_transfer_item(wrapper voidptr) !&html.DataTransferItem {
	binding := runtime.event_binding()!.data_transfer_item_binding
	if binding == unsafe { nil } { return runtime.event_binding_type_error('Not an object of type DataTransferItem') }
	return binding.items[wrapper] or { return runtime.event_binding_type_error('Not an object of type DataTransferItem') }
}
