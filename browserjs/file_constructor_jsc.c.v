// Copyright (c) 2022-2024, Kenneth Myhra <kennethmyhra@serenityos.org>
// SPDX-License-Identifier: BSD-2-Clause
// Pinned File.idl, File.cpp and generated FileConstructor/FilePropertyBag.
module browserjs

import fileapi
import webidl


pub fn (mut host FileHost) install_constructor() ! {
	if host.closed || host.runtime == unsafe { nil } {
		return error('File native record owner is unavailable')
	}
	if host.constructor != unsafe { nil } { return }
	if host.blobs.constructor == unsafe { nil } {
		return error('File constructor requires its actual parent Blob constructor')
	}
	mut runtime := unsafe { &Runtime(host.runtime) }
	handle := voidptr(&host)
	construct := runtime.make_value_host_function(fn [handle] (_ voidptr, args []voidptr) !voidptr {
		mut host := unsafe { &FileHost(handle) }
		return host.construct_file(args) or {
			return host.runtime.actual_javascript_exception(host.runtime.binding_exception_value(err))
		}
	})!
	installer := runtime.evaluate_host_value(file_native_constructor_factory)!
	defer { runtime.release_javascript_value(installer) }
	host.constructor = runtime.retain_javascript_value(runtime.call_javascript_function(installer, C.vox_jsc_JSValueMakeUndefined(runtime.context), [
		host.prototype,
		construct,
		C.JSContextGetGlobalObject(runtime.context),
	])!)!
	// Generated FileConstructor::initialize chooses the actual Blob constructor.
	C.JSObjectSetPrototype(runtime.context, host.constructor, host.blobs.constructor)
}

fn (mut host FileHost) property_bag(value voidptr) !fileapi.FilePropertyBag {
	context := host.runtime.context
	object := C.JSValueIsObject(context, value)
	if !object && !C.JSValueIsNull(context, value) && !C.JSValueIsUndefined(context, value) {
		return error('TypeError: Not an object of type FilePropertyBag')
	}
	// The generator converts inherited dictionaries first: endings, type,
	// then the derived optional lastModified, rather than sorting the union.
	base := host.blobs.property_bag(value)!
	mut options := fileapi.FilePropertyBag{ BlobPropertyBag: base }
	if object {
		last_modified := host.runtime.binding_property(value, 'lastModified')!
		if !C.JSValueIsUndefined(context, last_modified) {
			original := host.runtime.webidl_value(last_modified)!
			options.last_modified = i64(webidl.convert_to_int(original, 64, true, .no, .no)!)
		}
	}
	return options
}

fn (mut host FileHost) construct_file(args []voidptr) !voidptr {
	if host.closed { return error('TypeError: File binding is closed') }
	sequence := host.runtime.call_javascript_function(host.blobs.parts_sequence, C.vox_jsc_JSValueMakeUndefined(host.runtime.context), [
		host.argument(args, 1),
	])!
	host.runtime.retain_javascript_value(sequence)!
	defer { host.runtime.release_javascript_value(sequence) }
	name := host.blobs.dom_string(host.argument(args, 2))!.to_well_formed()
	options := host.property_bag(host.argument(args, 3))!
	// Source File::create processes the retained parts only after all generated
	// conversions, including filename and inherited/derived option getters.
	parts := host.blobs.converted_parts(sequence)!
	file := fileapi.File.construct_impl(parts, name.str(), options)
	object := host.wrap(file)!
	C.JSObjectSetPrototype(host.runtime.context, object, host.argument(args, 0))
	return object
}

const file_native_constructor_factory = r'(function(prototype,construct,global){
 "use strict";
 const define=Object.defineProperty,T=TypeError,P=Proxy;
 const File=new P(function File(fileBits,fileName){throw new T("File constructor must be called with \u0027new\u0027")},{construct(target,args,newTarget){let selected=newTarget.prototype;if(selected===null||(typeof selected!=="object"&&typeof selected!=="function"))selected=prototype;if(args.length<2)throw new T("File() needs 2 arguments");return construct(selected,args[0],args[1],args[2])}});
 define(File,"prototype",{value:prototype,writable:false});
 define(prototype,"constructor",{value:File,writable:true,configurable:true});
 define(global,"File",{value:File,writable:true,configurable:true});
 return File;
})'
