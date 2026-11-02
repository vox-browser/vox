// Copyright (c) 2022, the SerenityOS developers.
// SPDX-License-Identifier: BSD-2-Clause
// Generated FileListConstructor and Bindings/InterfaceObject.cpp::call.
module browserjs


pub fn (mut host FileListHost) install_constructor() ! {
	if host.closed || host.runtime == unsafe { nil } {
		return error('FileList native record owner is unavailable')
	}
	if host.constructor != unsafe { nil } { return }
	mut runtime := unsafe { &Runtime(host.runtime) }
	installer := runtime.evaluate_host_value(file_list_native_constructor_factory)!
	defer { runtime.release_javascript_value(installer) }
	host.constructor = runtime.retain_javascript_value(runtime.call_javascript_function(installer, C.vox_jsc_JSValueMakeUndefined(runtime.context), [
		host.prototype,
		C.JSContextGetGlobalObject(runtime.context),
	])!)!
}

// The Source interface is an actual constructor object whose [[Construct]]
// immediately throws. It does not inspect newTarget.prototype or arguments.
const file_list_native_constructor_factory = r'(function(prototype,global){
 "use strict";
 const define=Object.defineProperty,T=TypeError,P=Proxy;
 const FileList=new P(function FileList(){throw new T("FileList constructor must be called with \u0027new\u0027")},{construct(){throw new T("FileList is not a constructor")}});
 define(FileList,"prototype",{value:prototype,writable:false});
 define(prototype,"constructor",{value:FileList,writable:true,configurable:true});
 define(global,"FileList",{value:FileList,writable:true,configurable:true});
 return FileList;
})'
