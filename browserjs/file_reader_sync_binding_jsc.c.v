// SPDX-License-Identifier: BSD-2-Clause
// FileReaderSync.idl exposure and genuine owning-realm native reader records.
@[has_globals]
module browserjs

import fileapi
import platform

@[heap]
struct FileReaderSyncBinding {
mut:
	readers map[voidptr]&FileReaderSyncRecord
	closed  bool
}

@[heap]
struct FileReaderSyncRecord {
	host   &FileReaderSyncBinding
	reader &fileapi.FileReaderSync
}

__global file_reader_sync_bindings_ = map[voidptr]&FileReaderSyncBinding{}

pub fn (mut runtime Runtime) install_file_reader_sync_binding() ! {
	runtime.require_javascript_value_context()!
	owner := voidptr(&runtime)
	if owner in file_reader_sync_bindings_ { return }
	if owner !in worker_global_bindings_ {
		return error('FileReaderSync requires a dedicated or shared worker global')
	}
	if owner !in blob_bindings_ { return error('FileReaderSync requires its native Blob binding') }
	persistent := platform.enter_persistent()
	defer { platform.leave_persistent(persistent) }
	mut binding := &FileReaderSyncBinding{}
	operate := runtime.make_value_host_function(fn [owner, mut binding] (_ voidptr, args []voidptr) !voidptr {
		mut runtime := unsafe { &Runtime(owner) }
		return runtime.file_reader_sync_operation(mut binding, args) or { return runtime.file_reader_exception(err) }
	})!
	factory := runtime.evaluate_host_value(file_reader_sync_factory)!
	defer { runtime.release_javascript_value(factory) }
	methods := runtime.evaluate_host_value(file_reader_methods_factory)!
	defer { runtime.release_javascript_value(methods) }
	runtime.call_javascript_function(factory, C.vox_jsc_JSValueMakeUndefined(runtime.context), [
		operate,
		methods,
	])!
	file_reader_sync_bindings_[owner] = binding
	runtime.add_close_handler(fn [owner, mut binding] () {
		binding.closed = true
		binding.readers = {}
		file_reader_sync_bindings_.delete(owner)
	})
}

fn (mut runtime Runtime) file_reader_sync_operation(mut binding FileReaderSyncBinding, args []voidptr) !voidptr {
	if binding.closed { return error('FileReaderSync binding is closed') }
	name := runtime.binding_dom_string(args[0])!
	if name == 'construct' {
		record := &FileReaderSyncRecord{ host: binding, reader: fileapi.FileReaderSync.create() }
		wrapper := runtime.make_native_stream_wrapper(record)!
		C.JSObjectSetPrototype(runtime.context, wrapper, args[1])
		binding.readers[wrapper] = record
		return wrapper
	}
	record := binding.readers[args[1]] or { return runtime.event_binding_type_error('Illegal FileReaderSync receiver') }
	blob := runtime.native_blob(args[2])!
	mut encoding_name := ?string(none)
	if name == 'readAsText' && !C.JSValueIsUndefined(runtime.context, args[3]) {
		encoding_name = runtime.binding_dom_string(args[3])!
	}
	type_ := match name {
		'readAsArrayBuffer' { fileapi.FileReaderType.array_buffer }
		'readAsBinaryString' { fileapi.FileReaderType.binary_string }
		'readAsText' { fileapi.FileReaderType.text }
		'readAsDataURL' { fileapi.FileReaderType.data_url }
		else { return error('TypeError: Unknown FileReaderSync operation') }
	}
	result := record.reader.read_as(blob, type_, encoding_name)!
	return runtime.file_reader_result_value(result)
}

const file_reader_sync_factory = r'(function(operate,methods){
 "use strict";
 const define=Object.defineProperty,T=TypeError,prototype={};
 const FileReaderSync=new Proxy(function FileReaderSync(){throw new T("FileReaderSync constructor requires new")},{construct(target,args,newTarget){let selected=newTarget.prototype;if(selected===null||(typeof selected!=="object"&&typeof selected!=="function"))selected=prototype;return operate("construct",selected)}});
 define(FileReaderSync,"prototype",{value:prototype,writable:false});
 define(prototype,"constructor",{value:FileReaderSync,writable:true,configurable:true});
 define(prototype,Symbol.toStringTag,{value:"FileReaderSync",configurable:true});
 methods(prototype,operate);
 define(globalThis,"FileReaderSync",{value:FileReaderSync,writable:true,configurable:true});
})'
