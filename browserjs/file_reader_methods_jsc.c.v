// SPDX-License-Identifier: BSD-2-Clause
// Shared generated-binding operations for FileReader and FileReaderSync.
module browserjs

import fileapi
import webidl

fn (mut runtime Runtime) file_reader_exception(exception IError) IError {
	if exception is JavaScriptValueException { return exception }
	value := webidl.exception_value(exception)
	if value.dom_exception_ != none {
		actual := runtime.javascript_dom_exception(value) or { return err }
		return runtime.actual_javascript_exception(actual)
	}
	return runtime.actual_javascript_exception(runtime.binding_exception_value(exception))
}

fn (mut runtime Runtime) file_reader_result_value(result fileapi.FileReaderResult) !voidptr {
	match result.kind {
		.null_ { return C.vox_jsc_JSValueMakeNull(runtime.context) }
		.string_ {
			text := result.string_utf16_record() or { return error('Missing FileReader UTF16 result') }
			return runtime.binding_utf16_string(text)
		}
		.bytes {
			value := runtime.actual_webidl_value(runtime.source_array_buffer(result.bytes)!)!
			// The native call boundary roots its return; callers that cache a
			// FileReader result acquire their own persistent root.
			runtime.release_javascript_value(value)
			return value
		}
	}
}

const file_reader_methods_factory = r'(function(prototype,operate){
 "use strict";
 const define=Object.defineProperty,T=TypeError;
 function read(name,receiver,args){if(args.length<1)throw new T(name+" needs a Blob");return operate(name,receiver,args[0],args[1])}
 const methods={
  readAsArrayBuffer(blob){return read("readAsArrayBuffer",this,arguments)},
  readAsBinaryString(blob){return read("readAsBinaryString",this,arguments)},
  readAsText(blob){return read("readAsText",this,arguments)},
  readAsDataURL(blob){return read("readAsDataURL",this,arguments)}
 };
 for(const name of Object.keys(methods))define(prototype,name,{value:methods[name],writable:true,enumerable:true,configurable:true});
})'
