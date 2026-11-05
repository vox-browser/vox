// Copyright (c) 2026, Ladybird contributors
// SPDX-License-Identifier: BSD-2-Clause
// DOMURL.{cpp,idl} and the pinned libweb_bindings constructor, argument,
// attribute, stringifier and static-operation generators.
@[has_globals]
module browserjs

import domurl
import fileapi
import html
import libjs


__global url_bindings_ = map[voidptr]&URLHost{}

pub fn (mut host URLHost) install(mut runtime Runtime) ! {
	runtime.require_javascript_value_context()!
	runtime.bind_scripting_environment(host.settings)!
	owner := voidptr(&runtime)
	if previous := url_bindings_[owner] {
		if voidptr(previous) == voidptr(&host) { return }
		return error('URL binding already belongs to another native owner')
	}
	queries := runtime.url_search_params_host() or {
		return error('URL binding requires its actual relevant-realm URLSearchParams host')
	}
	if queries.closed || voidptr(queries.settings) != voidptr(host.settings) {
		return error('URL binding requires its owning relevant-realm URLSearchParams host')
	}
	host.runtime = &runtime
	host.to_dom_string = runtime.evaluate_host_value(r'(function(value){return `${value}`})')!
	handle := voidptr(&host)
	names := ['href', 'origin', 'protocol', 'username', 'password', 'host', 'hostname', 'port',
		'pathname', 'search', 'searchParams', 'hash']
	mut accessors := []voidptr{}
	for name in names {
		accessors << runtime.make_native_value_host_function('get ${name}', 0, fn [handle, name] (receiver voidptr, _ []voidptr) !voidptr {
			mut host := unsafe { &URLHost(handle) }
			return host.get(name, receiver) or { return host.exception(err) }
		})!
		if name in ['origin', 'searchParams'] {
			accessors << C.vox_jsc_JSValueMakeUndefined(runtime.context)
		} else {
			accessors << runtime.make_native_value_host_function('set ${name}', 1, fn [handle, name] (receiver voidptr, args []voidptr) !voidptr {
				mut host := unsafe { &URLHost(handle) }
				return host.set(name, receiver, host.argument(args, 0)) or {
					return host.exception(err)
				}
			})!
		}
	}
	mut methods := []voidptr{}
	for name in ['toString', 'toJSON', 'parse', 'canParse', 'createObjectURL', 'revokeObjectURL'] {
		length := if name in ['toString', 'toJSON'] { 0 } else { 1 }
		methods << runtime.make_native_value_host_function(name, length, fn [handle, name] (receiver voidptr, args []voidptr) !voidptr {
			mut host := unsafe { &URLHost(handle) }
			return host.operate(name, receiver, args) or { return host.exception(err) }
		})!
	}
	construct := runtime.make_value_host_function(fn [handle] (_ voidptr, args []voidptr) !voidptr {
		mut host := unsafe { &URLHost(handle) }
		return host.construct(args) or { return host.exception(err) }
	})!
	factory := runtime.evaluate_host_value(url_native_factory)!
	defer { runtime.release_javascript_value(factory) }
	installed := runtime.call_javascript_function(factory, C.vox_jsc_JSValueMakeUndefined(runtime.context), [
		host.array(accessors)!,
		host.array(methods)!,
		construct,
		C.JSContextGetGlobalObject(runtime.context),
		C.vox_jsc_JSValueMakeBoolean(runtime.context, host.settings.fetch_request_client_is_window()),
	])!
	host.prototype = runtime.retain_javascript_value(runtime.binding_property(installed,
		'prototype')!)!
	host.constructor = runtime.retain_javascript_value(runtime.binding_property(installed,
		'constructor')!)!
	url_bindings_[owner] = &host
	runtime.add_close_handler(fn [handle, owner] () {
		mut host := unsafe { &URLHost(handle) }
		host.close()
		url_bindings_.delete(owner)
	})
}

fn (host &URLHost) exception(reason IError) IError {
	return host.runtime.actual_javascript_exception(host.runtime.binding_exception_value(reason))
}

fn (host &URLHost) argument(args []voidptr, index int) voidptr {
	if index < args.len { return args[index] }
	return C.vox_jsc_JSValueMakeUndefined(host.runtime.context)
}

fn (host &URLHost) record(value voidptr) !&URLHostRecord {
	if host.closed { return error('TypeError: URL binding is closed') }
	record := host.by_wrapper[value] or { return error('TypeError: Not an object of type URL') }
	if voidptr(record.host) != voidptr(host) { return error('TypeError: Not an object of type URL') }
	return record
}

fn (mut host URLHost) wrap(url &domurl.DOMURL) !voidptr {
	if host.closed { return error('TypeError: URL binding is closed') }
	native := voidptr(url)
	if record := host.records[native] { return record.object }
	mut record := &URLHostRecord{
		host: host
		url:  url
	}
	object := C.JSObjectMake(host.runtime.context, unsafe { nil }, unsafe { nil })
	C.JSObjectSetPrototype(host.runtime.context, object, host.prototype)
	record.object = host.runtime.retain_javascript_value(object)!
	host.records[native] = record
	host.by_wrapper[object] = record
	return object
}

pub fn (mut runtime Runtime) javascript_url(url &domurl.DOMURL) !voidptr {
	mut host := url_bindings_[voidptr(&runtime)] or { return error('URL binding is unavailable') }
	return host.wrap(url)
}

pub fn (runtime &Runtime) native_url(value voidptr) !&domurl.DOMURL {
	host := url_bindings_[voidptr(runtime)] or { return error('URL binding is unavailable') }
	return host.record(value)!.url
}

fn (host &URLHost) dom_string(value voidptr) !libjs.Utf16String {
	return host.runtime.url_binding_dom_string(host.to_dom_string, value)
}

fn (host &URLHost) usv_string(value voidptr) !string {
	return host.dom_string(value)!.to_well_formed_utf8()
}

fn (mut host URLHost) string_value(text string) !voidptr {
	return host.runtime.javascript_utf16_string(libjs.utf16_string(text))
}

fn (mut host URLHost) array(values []voidptr) !voidptr {
	mut exception := unsafe { nil }
	actual := C.vox_jsc_JSObjectMakeArray(host.runtime.context, uint(values.len), values.data, &exception)
	if exception != unsafe { nil } { return host.runtime.actual_javascript_exception(exception) }
	return host.runtime.retain_javascript_value(actual)
}

struct URLHostInput {
	input string
	base  ?string
}

fn (host &URLHost) input(args []voidptr, offset int) !URLHostInput {
	input := host.usv_string(host.argument(args, offset))!
	mut base := ?string(none)
	if !C.JSValueIsUndefined(host.runtime.context, host.argument(args, offset + 1)) {
		base = host.usv_string(host.argument(args, offset + 1))!
	}
	return URLHostInput{
		input: input
		base:  base
	}
}

fn (mut host URLHost) construct(args []voidptr) !voidptr {
	mut exception := unsafe { nil }
	count := C.vox_jsc_JSValueToNumber(host.runtime.context, host.argument(args, 3), &exception)
	if exception != unsafe { nil } { return host.runtime.actual_javascript_exception(exception) }
	if count < 1 { return error('TypeError: URL requires at least 1 argument') }
	converted := host.input(args, 1)!
	record := host.parser.parse(converted.input, converted.base) or {
		return error('TypeError: Invalid URL')
	}
	url := domurl.DOMURL.create(record)
	object := host.wrap(url)!
	C.JSObjectSetPrototype(host.runtime.context, object, host.argument(args, 0))
	return object
}

fn (mut host URLHost) get(name string, receiver voidptr) !voidptr {
	url := host.record(receiver)!.url
	if name == 'searchParams' {
		return host.runtime.javascript_url_search_params(url.search_params())
	}
	value := match name {
		'href' { url.href() }
		'origin' { url.origin() }
		'protocol' { url.protocol() }
		'username' { url.username() }
		'password' { url.password() }
		'host' { url.host() }
		'hostname' { url.hostname() }
		'port' { url.port() }
		'pathname' { url.pathname() }
		'search' { url.search() }
		'hash' { url.hash() }
		else { return error('TypeError: Unknown URL attribute') }
	}

	return host.string_value(value)
}

fn (mut host URLHost) set(name string, receiver voidptr, value voidptr) !voidptr {
	mut url := host.record(receiver)!.url
	input := host.usv_string(value)!
	match name {
		'href' { url.set_href(input)! }
		'protocol' { url.set_protocol(input) }
		'username' { url.set_username(input) }
		'password' { url.set_password(input) }
		'host' { url.set_host(input) }
		'hostname' { url.set_hostname(input) }
		'port' { url.set_port(input) }
		'pathname' { url.set_pathname(input) }
		'search' { url.set_search(input) }
		'hash' { url.set_hash(input) }
		else { return error('TypeError: Unknown URL attribute') }
	}

	return C.vox_jsc_JSValueMakeUndefined(host.runtime.context)
}

fn (mut host URLHost) operate(name string, receiver voidptr, args []voidptr) !voidptr {
	if name in ['toString', 'toJSON'] { return host.string_value(host.record(receiver)!.url.href()) }
	if args.len < 1 { return error('TypeError: ${name} requires at least 1 argument') }
	if name == 'createObjectURL' {
		// File wrappers retain their actual Blob base in the same native table.
		if blob := host.runtime.native_blob(args[0]) {
			return host.string_value(html.create_object_url(fileapi.BlobURLObject.from_blob(blob))!)
		}
		if source := host.runtime.native_media_source(args[0]) {
			return host.string_value(html.create_object_url(source.blob_url_object(''))!)
		}
		return error('TypeError: No union types matched')
	}
	if name == 'revokeObjectURL' {
		// Unlike the URL components, this argument is DOMString, not USVString.
		html.revoke_object_url(host.dom_string(args[0])!.str())
		return C.vox_jsc_JSValueMakeUndefined(host.runtime.context)
	}
	converted := host.input(args, 0)!
	if name == 'canParse' {
		return C.vox_jsc_JSValueMakeBoolean(host.runtime.context,
			host.parser.parse(converted.input, converted.base) != none)
	}
	if parsed := host.parser.parse(converted.input, converted.base) {
		return host.wrap(domurl.DOMURL.create(parsed))
	}
	return C.vox_jsc_JSValueMakeNull(host.runtime.context)
}

const url_native_factory = r'(function(accessors,methods,construct,global,isWindow){
 "use strict";
 const define=Object.defineProperty,create=Object.create,T=TypeError,P=Proxy;
 const prototype=create(Object.prototype),names=["href","origin","protocol","username","password","host","hostname","port","pathname","search","searchParams","hash"];
 for(let i=0;i<names.length;i++)define(prototype,names[i],{get:accessors[i*2],set:accessors[i*2+1],enumerable:true,configurable:true});
 for(let i=0;i<2;i++)define(prototype,["toString","toJSON"][i],{value:methods[i],writable:true,enumerable:true,configurable:true});
 define(prototype,Symbol.toStringTag,{value:"URL",configurable:true});
 const URL=new P(function URL(url){throw new T("URL constructor must be called with \u0027new\u0027")},{construct(target,args,newTarget){let selected=newTarget.prototype;if(selected===null||(typeof selected!=="object"&&typeof selected!=="function"))selected=prototype;return construct(selected,args[0],args[1],args.length)}});
 define(URL,"prototype",{value:prototype,writable:false});
 define(prototype,"constructor",{value:URL,writable:true,configurable:true});
 for(let i=0;i<4;i++)define(URL,["parse","canParse","createObjectURL","revokeObjectURL"][i],{value:methods[i+2],writable:true,enumerable:true,configurable:true});
 define(global,"URL",{value:URL,writable:true,configurable:true});
 if(isWindow)define(global,"webkitURL",{value:URL,writable:true,configurable:true});
 return {prototype,constructor:URL};
})'
