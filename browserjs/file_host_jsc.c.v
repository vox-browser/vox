// Copyright (c) 2022-2024, Kenneth Myhra <kennethmyhra@serenityos.org>
// SPDX-License-Identifier: BSD-2-Clause
// File.{h,idl} and generated FileWrapper/FilePrototype: actual File : Blob.
@[has_globals]
module browserjs

import fileapi


__global file_bindings_ = map[voidptr]&FileHost{}

pub fn (mut host FileHost) install(mut runtime Runtime) ! {
	runtime.require_javascript_value_context()!
	runtime.bind_scripting_environment(host.settings)!
	owner := voidptr(&runtime)
	if previous := file_bindings_[owner] {
		if voidptr(previous) == voidptr(&host) { return }
		return error('File binding already belongs to another native owner')
	}
	blobs := blob_bindings_[owner] or { return error('File binding requires its actual relevant-realm Blob host') }
	if blobs.closed || voidptr(blobs.settings) != voidptr(host.settings) {
		return error('File binding requires its owning relevant-realm Blob host')
	}
	host.runtime = &runtime
	host.blobs = blobs
	handle := voidptr(&host)
	operate := runtime.make_value_host_function(fn [handle] (_ voidptr, args []voidptr) !voidptr {
		mut host := unsafe { &FileHost(handle) }
		return host.operate(args) or {
			return host.runtime.actual_javascript_exception(host.runtime.binding_exception_value(err))
		}
	})!
	installer := runtime.evaluate_host_value(file_native_prototype_factory)!
	defer { runtime.release_javascript_value(installer) }
	host.prototype = runtime.retain_javascript_value(runtime.call_javascript_function(installer, C.vox_jsc_JSValueMakeUndefined(runtime.context), [
		blobs.prototype,
		operate,
	])!)!
	register_runtime_binding(mut file_bindings_, owner, &host)
	runtime.add_close_handler(fn [handle, owner] () {
		mut host := unsafe { &FileHost(handle) }
		host.close()
		unregister_runtime_binding(mut file_bindings_, owner)
	})
}

fn (host &FileHost) argument(args []voidptr, index int) voidptr {
	if index < args.len { return args[index] }
	return C.vox_jsc_JSValueMakeUndefined(host.runtime.context)
}

fn (host &FileHost) record(value voidptr) !&FileHostRecord {
	if host.closed { return error('TypeError: File binding is closed') }
	record := host.by_wrapper[value] or { return error('TypeError: Not an object of type File') }
	if voidptr(record.host) != voidptr(host) {
		return error('TypeError: Not an object of type File')
	}
	return record
}

fn (mut host FileHost) wrap(file &fileapi.File) !voidptr {
	if host.closed { return error('File binding is closed') }
	native := voidptr(file)
	if record := host.records[native] { return record.object }
	// FileWrapper inherits BlobWrapper and wraps the exact same base record.
	object := host.blobs.wrap(&file.Blob)!
	C.JSObjectSetPrototype(host.runtime.context, object, host.prototype)
	record := &FileHostRecord{ host: host, file: file, object: object }
	host.records[native] = record
	host.by_wrapper[object] = record
	return object
}

fn (mut host FileHost) operate(args []voidptr) !voidptr {
	name := host.runtime.binding_dom_string(host.argument(args, 0))!
	file := host.record(host.argument(args, 1))!.file
	match name {
		'name' { return host.runtime.javascript_utf16_string(file.name_utf16()) }
		'lastModified' {
			return C.vox_jsc_JSValueMakeNumber(host.runtime.context, f64(file.last_modified()))
		}
		else { return error('TypeError: Unknown File operation') }
	}
}

pub fn (mut runtime Runtime) javascript_file(file &fileapi.File) !voidptr {
	mut host := file_bindings_[voidptr(&runtime)] or { return error('File binding is unavailable') }
	return host.wrap(file)
}

pub fn (runtime &Runtime) native_file(value voidptr) !&fileapi.File {
	host := file_bindings_[voidptr(runtime)] or { return error('File binding is unavailable') }
	return host.record(value)!.file
}

const file_native_prototype_factory = r'(function(blobPrototype,operate){
 const define=Object.defineProperty,create=Object.create,get=Object.getOwnPropertyDescriptor;
 const prototype=create(blobPrototype);
 for(const name of ["name","lastModified"]){const getter=get({get [name](){return operate(name,this)}},name).get;define(prototype,name,{get:getter,enumerable:true,configurable:true})}
 define(prototype,Symbol.toStringTag,{value:"File",configurable:true});
 return prototype;
})'
