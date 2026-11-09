// SPDX-License-Identifier: BSD-2-Clause
// FileReader.idl wrappers retain the actual owning Window/Worker reader.
@[has_globals]
module browserjs

import dom
import fileapi
import html
import platform
import webidl

@[heap]
struct FileReaderBinding {
	settings &html.EnvironmentSettingsObject
mut:
	readers map[voidptr]&FileReaderRecord
	closed  bool
}

@[heap]
struct FileReaderRecord {
	reader &fileapi.FileReader
mut:
	result      voidptr
	error_value voidptr
}

__global file_reader_bindings_ = map[voidptr]&FileReaderBinding{}

pub fn (mut runtime Runtime) install_file_reader_binding() ! {
	runtime.require_javascript_value_context()!
	owner := voidptr(&runtime)
	if owner in file_reader_bindings_ { return }
	settings := runtime.scripting_settings_ or { return error('FileReader requires its owning settings') }
	_ := settings.window_or_worker_global_scope()!
	if owner !in blob_bindings_ { return error('FileReader requires its native Blob binding') }
	runtime.install_event_target_binding()!
	persistent := platform.enter_persistent()
	defer { platform.leave_persistent(persistent) }
	mut binding := &FileReaderBinding{ settings: settings }
	operate := runtime.make_value_host_function(fn [owner, mut binding] (_ voidptr, args []voidptr) !voidptr {
		mut runtime := unsafe { &Runtime(owner) }
		return runtime.file_reader_operation(mut binding, args) or { return runtime.file_reader_exception(err) }
	})!
	factory := runtime.evaluate_host_value(file_reader_factory)!
	defer { runtime.release_javascript_value(factory) }
	methods := runtime.evaluate_host_value(file_reader_methods_factory)!
	defer { runtime.release_javascript_value(methods) }
	runtime.call_javascript_function(factory, C.vox_jsc_JSValueMakeUndefined(runtime.context), [
		operate,
		methods,
	])!
	file_reader_bindings_[owner] = binding
	runtime.add_close_handler(fn [owner, mut binding] () {
		binding.closed = true
		// EventTarget's close handler has already disabled native callbacks.
		// Abort also removes affiliated tasks before their realm is released.
		for _, record in binding.readers {
			mut reader := record.reader
			reader.abort()
		}
		binding.readers = {}
		file_reader_bindings_.delete(owner)
	})
}

fn (mut runtime Runtime) clear_file_reader_result(mut record FileReaderRecord) {
	if record.result != unsafe { nil } {
		runtime.release_javascript_value(record.result)
		record.result = unsafe { nil }
	}
}

fn (mut runtime Runtime) file_reader_operation(mut binding FileReaderBinding, args []voidptr) !voidptr {
	if binding.closed { return error('FileReader binding is closed') }
	name := runtime.binding_dom_string(args[0])!
	if name == 'construct' {
		reader := binding.settings.create_file_reader()!
		wrapper := runtime.javascript_event_target(unsafe { &dom.EventTarget(reader) }, args[1])!
		binding.readers[wrapper] = &FileReaderRecord{ reader: reader }
		return wrapper
	}
	mut record := binding.readers[args[1]] or { return runtime.event_binding_type_error('Illegal FileReader receiver') }
	mut reader := record.reader
	match name {
		'readyState' {
			return C.vox_jsc_JSValueMakeNumber(runtime.context, f64(reader.ready_state()))
		}
		'result' {
			if record.result != unsafe { nil } { return record.result }
			result := reader.result()
			value := runtime.file_reader_result_value(result)!
			if result.kind == .bytes { record.result = runtime.retain_javascript_value(value)! }
			return value
		}
		'error' {
			if record.error_value != unsafe { nil } { return record.error_value }
			if message := reader.error() {
				value := webidl.dom_exception_value_for_record(webidl.DOMException.create_record('NotReadableError', message))
				record.error_value = runtime.retain_javascript_value(runtime.javascript_dom_exception(value)!)!
				return record.error_value
			}
			return C.vox_jsc_JSValueMakeNull(runtime.context)
		}
		'getHandler' {
			return runtime.javascript_event_handler(unsafe { &dom.EventTarget(reader) }, runtime.binding_dom_string(args[2])!)
		}
		'setHandler' {
			runtime.set_javascript_event_handler(unsafe { &dom.EventTarget(reader) }, runtime.binding_dom_string(args[2])!, args[3])!
		}
		'abort' {
			// Abort callbacks can synchronously start the next operation.
			runtime.clear_file_reader_result(mut record)
			reader.abort()
		}
		else {
			blob := runtime.native_blob(args[2])!
			mut encoding_name := ?string(none)
			if name == 'readAsText' && !C.JSValueIsUndefined(runtime.context, args[3]) {
				encoding_name = runtime.binding_dom_string(args[3])!
			}
			match name {
				'readAsArrayBuffer' { reader.read_as_array_buffer(blob)! }
				'readAsBinaryString' { reader.read_as_binary_string(blob)! }
				'readAsText' { reader.read_as_text(blob, encoding_name)! }
				'readAsDataURL' { reader.read_as_data_url(blob)! }
				else { return error('TypeError: Unknown FileReader operation') }
			}
			// Failed conversions and InvalidStateError preserve the prior result.
			runtime.clear_file_reader_result(mut record)
			if record.error_value != unsafe { nil } {
				runtime.release_javascript_value(record.error_value)
				record.error_value = unsafe { nil }
			}
		}
	}
	return C.vox_jsc_JSValueMakeUndefined(runtime.context)
}

const file_reader_factory = r'(function(operate,methods){
 "use strict";
 const define=Object.defineProperty,T=TypeError,prototype=Object.create(EventTarget.prototype);
 const FileReader=new Proxy(function FileReader(){throw new T("FileReader constructor requires new")},{construct(target,args,newTarget){let selected=newTarget.prototype;if(selected===null||(typeof selected!=="object"&&typeof selected!=="function"))selected=prototype;return operate("construct",selected)}});
 Object.setPrototypeOf(FileReader,EventTarget);
 define(FileReader,"prototype",{value:prototype,writable:false});
 define(prototype,"constructor",{value:FileReader,writable:true,configurable:true});
 define(prototype,Symbol.toStringTag,{value:"FileReader",configurable:true});
 methods(prototype,operate);
 define(prototype,"abort",{value:({abort(){return operate("abort",this)}}).abort,writable:true,enumerable:true,configurable:true});
 const attributes={get readyState(){return operate("readyState",this)},get result(){return operate("result",this)},get error(){return operate("error",this)}};
 for(const name of ["readyState","result","error"])define(prototype,name,Object.getOwnPropertyDescriptor(attributes,name));
 for(const name of ["loadstart","progress","load","abort","error","loadend"]){const key="on"+name;define(prototype,key,Object.getOwnPropertyDescriptor({get [key](){return operate("getHandler",this,name)},set [key](value){operate("setHandler",this,name,value)}},key))}
 for(const [name,value] of [["EMPTY",0],["LOADING",1],["DONE",2]])for(const target of [FileReader,prototype])define(target,name,{value,enumerable:true});
 define(globalThis,"FileReader",{value:FileReader,writable:true,configurable:true});
})'
