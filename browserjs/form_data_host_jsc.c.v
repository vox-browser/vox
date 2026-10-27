// Copyright (c) 2026, Ladybird contributors
// SPDX-License-Identifier: BSD-2-Clause
// XHR/FormData.{cpp,idl}, FormDataIterator and generated iterable bindings.
@[has_globals]
module browserjs

import dom
import html
import webidl
import xhr

__global form_data_bindings_ = map[voidptr]&FormDataHost{}

pub fn (mut host FormDataHost) install(mut runtime Runtime) ! {
	runtime.require_javascript_value_context()!
	runtime.bind_scripting_environment(host.settings)!
	owner := voidptr(&runtime)
	if previous := form_data_bindings_[owner] {
		if voidptr(previous) == voidptr(&host) { return }
		return error('FormData binding already belongs to another native owner')
	}
	blobs := blob_bindings_[owner] or { return error('FormData requires its native Blob binding') }
	files := file_bindings_[owner] or { return error('FormData requires its native File binding') }
	if blobs.closed || files.closed || voidptr(files.settings) != voidptr(host.settings) {
		return error('FormData requires its relevant-realm File binding')
	}
	host.runtime = &runtime
	host.blobs = blobs
	handle := voidptr(&host)
	mut methods := []voidptr{}
	names := ['append', 'delete', 'get', 'getAll', 'has', 'set', 'keys', 'values', 'entries', 'forEach',
		'next']
	lengths := [2, 1, 1, 1, 1, 2, 0, 0, 0, 1, 0]
	for index, name in names {
		methods << runtime.make_native_value_host_function(name, lengths[index], fn [handle, name] (receiver voidptr, args []voidptr) !voidptr {
			mut host := unsafe { &FormDataHost(handle) }
			return host.operate(name, receiver, args) or { return host.exception(err) }
		})!
	}
	construct := runtime.make_value_host_function(fn [handle] (_ voidptr, args []voidptr) !voidptr {
		mut host := unsafe { &FormDataHost(handle) }
		return host.construct(args) or { return host.exception(err) }
	})!
	factory := runtime.evaluate_host_value(form_data_native_factory)!
	defer { runtime.release_javascript_value(factory) }
	installed := runtime.call_javascript_function(factory, C.JSValueMakeUndefined(runtime.context), [
		host.array(methods)!,
		construct,
		C.JSContextGetGlobalObject(runtime.context),
	])!
	host.prototype = runtime.retain_javascript_value(runtime.binding_property(installed, 'prototype')!)!
	host.iterator_prototype = runtime.retain_javascript_value(runtime.binding_property(installed, 'iteratorPrototype')!)!
	host.iterator_result = runtime.retain_javascript_value(runtime.binding_property(installed, 'iteratorResult')!)!
	form_data_bindings_[owner] = &host
	runtime.add_close_handler(fn [handle, owner] () {
		mut host := unsafe { &FormDataHost(handle) }
		host.close()
		form_data_bindings_.delete(owner)
	})
}

fn (mut host FormDataHost) exception(reason IError) IError {
	if reason is JavaScriptValueException { return reason }
	name := reason.msg().all_before(':')
	if name in ['NotFoundError', 'InvalidStateError'] {
		value := webidl.dom_exception_value(webidl.DOMException.create(name, reason.msg().all_after(':').trim_space()))
		actual := host.runtime.javascript_dom_exception(value) or { return err }
		return host.runtime.actual_javascript_exception(actual)
	}
	return host.runtime.actual_javascript_exception(host.runtime.binding_exception_value(reason))
}

fn (host &FormDataHost) argument(args []voidptr, index int) voidptr {
	if index < args.len { return args[index] }
	return C.JSValueMakeUndefined(host.runtime.context)
}

fn (host &FormDataHost) record(value voidptr) !&xhr.FormData {
	if host.closed { return error('TypeError: FormData binding is closed') }
	return host.by_wrapper[value] or { return error('TypeError: Not an object of type FormData') }
}

fn (mut host FormDataHost) wrap(data &xhr.FormData) !voidptr {
	if host.closed { return error('TypeError: FormData binding is closed') }
	if object := host.wrappers[voidptr(data)] { return object }
	object := C.JSObjectMake(host.runtime.context, unsafe { nil }, unsafe { nil })
	C.JSObjectSetPrototype(host.runtime.context, object, host.prototype)
	host.runtime.retain_javascript_value(object)!
	host.by_wrapper[object] = data
	host.wrappers[voidptr(data)] = object
	return object
}

pub fn (mut runtime Runtime) javascript_form_data(data &xhr.FormData) !voidptr {
	mut host := form_data_bindings_[voidptr(&runtime)] or { return error('FormData binding is unavailable') }
	return host.wrap(data)
}

pub fn (runtime &Runtime) native_form_data(value voidptr) !&xhr.FormData {
	host := form_data_bindings_[voidptr(runtime)] or { return error('FormData binding is unavailable') }
	return host.record(value)
}

fn (host &FormDataHost) usv_string(value voidptr) !string {
	return host.blobs.dom_string(value)!.to_well_formed().str()
}

fn (mut host FormDataHost) array(values []voidptr) !voidptr {
	mut exception := unsafe { nil }
	array := C.JSObjectMakeArray(host.runtime.context, uint(values.len), values.data, &exception)
	if exception != unsafe { nil } { return host.runtime.actual_javascript_exception(exception) }
	return host.runtime.retain_javascript_value(array)
}

fn (mut host FormDataHost) value(value xhr.FormDataEntryValue) !voidptr {
	return match value {
		string { host.runtime.binding_string(value) }
		xhr.FormDataFile { host.runtime.javascript_file(value.file) }
	}
}

fn (host &FormDataHost) element(value voidptr) !&dom.Element {
	target := host.runtime.native_event_target(value) or { return error('TypeError: Not an HTMLElement') }
	if target.data.kind != .node { return error('TypeError: Not an HTMLElement') }
	element := unsafe { &dom.Node(target) }.as_element() or { return error('TypeError: Not an HTMLElement') }
	if !element.is_html_element() { return error('TypeError: Not an HTMLElement') }
	return element
}

fn (mut host FormDataHost) construct(args []voidptr) !voidptr {
	if host.closed { return error('TypeError: FormData binding is closed') }
	form_value := host.argument(args, 1)
	mut form := ?&dom.Element(none)
	if !C.JSValueIsUndefined(host.runtime.context, form_value) {
		element := host.element(form_value)!
		if element.local_name() != 'form' { return error('TypeError: Not an HTMLFormElement') }
		form = element
	}
	submitter_value := host.argument(args, 2)
	mut submitter := ?&dom.Element(none)
	if !C.JSValueIsUndefined(host.runtime.context, submitter_value) && !C.JSValueIsNull(host.runtime.context, submitter_value) {
		submitter = host.element(submitter_value)!
	}
	mut data := xhr.FormData.create()
	if element := form {
		if synchronize := host.before_construct { synchronize(host.runtime)! }
		model := html.HTMLFormElementModel.create(unsafe { &dom.HTMLFormElement(element) })
		mut control := ?&html.FormAssociatedElement(none)
		if button := submitter {
			control = match button.local_name() {
				'button' {
					html.HTMLButtonElementModel.create(unsafe { &dom.HTMLButtonElement(button) }).control
				}
				'input' {
					html.HTMLInputElementModel.create(unsafe { &dom.HTMLInputElement(button) }).control
				}
				else { html.FormAssociatedElement.create(button) }
			}
		}
		data = xhr.FormData.create_from_form(model, control)!
	}
	object := host.wrap(data)!
	C.JSObjectSetPrototype(host.runtime.context, object, host.argument(args, 0))
	return object
}

fn (mut host FormDataHost) iterator(data &xhr.FormData, kind xhr.IteratorKind) !voidptr {
	object := C.JSObjectMake(host.runtime.context, unsafe { nil }, unsafe { nil })
	C.JSObjectSetPrototype(host.runtime.context, object, host.iterator_prototype)
	host.runtime.retain_javascript_value(object)!
	host.iterators[object] = &FormDataIteratorHostRecord{ kind: kind, iterator: data.iterator(kind) }
	return object
}

fn (mut host FormDataHost) next(receiver voidptr) !voidptr {
	if host.closed { return error('TypeError: FormData binding is closed') }
	mut record := host.iterators[receiver] or { return error('TypeError: Not a FormData iterator') }
	step := record.iterator.next()
	mut value := C.JSValueMakeUndefined(host.runtime.context)
	if !step.done {
		value = match record.kind {
			.key { host.runtime.binding_string(step.key) }
			.value { host.value(step.value)! }
			.key_value {
				host.array([host.runtime.binding_string(step.key), host.value(step.value)!])!
			}
		}
	}
	return host.runtime.call_javascript_function(host.iterator_result, C.JSValueMakeUndefined(host.runtime.context), [
		value,
		C.JSValueMakeBoolean(host.runtime.context, step.done),
	])
}

fn (mut host FormDataHost) operate(name string, receiver voidptr, args []voidptr) !voidptr {
	if name == 'next' { return host.next(receiver) }
	mut data := host.record(receiver)!
	required := if name in ['append', 'set'] {
		2
	} else if name in ['keys', 'values', 'entries'] {
		0
	} else {
		1
	}
	if args.len < required {
		return error('TypeError: FormData.${name}() needs ${required} arguments')
	}
	if name == 'keys' { return host.iterator(data, .key) }
	if name == 'values' { return host.iterator(data, .value) }
	if name == 'entries' { return host.iterator(data, .key_value) }
	if name == 'forEach' {
		callback := args[0]
		if !C.JSValueIsObject(host.runtime.context, callback) || !C.JSObjectIsFunction(host.runtime.context, callback) {
			return error('TypeError: FormData callback is not a function')
		}
		mut index := 0
		for index < data.entries.len {
			entry := data.entries[index]
			host.runtime.call_javascript_function(callback, host.argument(args, 1), [
				host.value(entry.value)!,
				host.runtime.binding_string(entry.name),
				receiver,
			])!
			index++
		}
		return C.JSValueMakeUndefined(host.runtime.context)
	}
	// The three-argument overload selects Blob before converting either string.
	if name in ['append', 'set'] && args.len > 2 {
		_ := host.runtime.native_blob(args[1]) or { return error('TypeError: FormData value is not a Blob') }
	}
	key := host.usv_string(args[0])!
	if name in ['append', 'set'] {
		value := args[1]
		if blob := host.runtime.native_blob(value) {
			mut filename := ?string(none)
			if args.len > 2 && !C.JSValueIsUndefined(host.runtime.context, args[2]) {
				filename = host.usv_string(args[2])!
			}
			if file := host.runtime.native_file(value) {
				if name == 'append' {
					data.append_file(key, file, filename)
				} else {
					data.set_file(key, file, filename)
				}
			} else {
				if name == 'append' {
					data.append_blob(key, blob, filename)
				} else {
					data.set_blob(key, blob, filename)
				}
			}
		} else {
			if args.len > 2 { return error('TypeError: FormData value is not a Blob') }
			text := host.usv_string(value)!
			if name == 'append' { data.append(key, text) } else { data.set(key, text) }
		}
	} else if name == 'delete' {
		data.delete(key)
	} else if name == 'has' {
		return C.JSValueMakeBoolean(host.runtime.context, data.has(key))
	} else if name == 'get' {
		if value := data.get(key) { return host.value(value) }
		return C.JSValueMakeNull(host.runtime.context)
	} else if name == 'getAll' {
		mut values := []voidptr{}
		for value in data.get_all(key) { values << host.value(value)! }
		return host.array(values)
	}
	return C.JSValueMakeUndefined(host.runtime.context)
}

const form_data_native_factory = r'(function(methods,construct,global){
 "use strict";
 const define=Object.defineProperty,create=Object.create,getProto=Object.getPrototypeOf,T=TypeError,P=Proxy;
 const iterator=Symbol.iterator,tag=Symbol.toStringTag;
 const prototype=create(Object.prototype),iteratorPrototype=create(getProto(getProto([][iterator]())));
 const names=["append","delete","get","getAll","has","set","keys","values","entries","forEach"];
 for(let i=0;i<names.length;i++)define(prototype,names[i],{value:methods[i],writable:true,enumerable:true,configurable:true});
 define(prototype,iterator,{value:methods[8],writable:true,configurable:true});
 define(prototype,tag,{value:"FormData",configurable:true});
 define(iteratorPrototype,"next",{value:methods[10],writable:true,enumerable:true,configurable:true});
 define(iteratorPrototype,tag,{value:"FormData Iterator",configurable:true});
 const FormData=new P(function FormData(){throw new T("FormData constructor must be called with new")},{construct(target,args,newTarget){let selected=newTarget.prototype;if(selected===null||(typeof selected!=="object"&&typeof selected!=="function"))selected=prototype;return construct(selected,args[0],args[1])}});
 define(FormData,"prototype",{value:prototype,writable:false});
 define(prototype,"constructor",{value:FormData,writable:true,configurable:true});
 define(global,"FormData",{value:FormData,writable:true,configurable:true});
 return {prototype,iteratorPrototype,iteratorResult(value,done){return {value,done}}};
})'
