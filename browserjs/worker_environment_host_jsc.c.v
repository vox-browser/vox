// SPDX-License-Identifier: BSD-2-Clause
// HTML/Worker{Navigator,Location,GlobalScope}.idl native binding adaptation.
@[has_globals]
module browserjs

import platform

__global worker_environment_bindings_ = map[voidptr]&WorkerEnvironmentHost{}

pub fn (mut host WorkerEnvironmentHost) install(mut runtime Runtime) ! {
	persistent := platform.enter_persistent()
	defer { platform.leave_persistent(persistent) }
	runtime.require_javascript_value_context()!
	runtime.bind_scripting_environment(host.settings)!
	owner := voidptr(&runtime)
	if existing := worker_environment_bindings_[owner] {
		if voidptr(existing) == voidptr(&host) { return }
		return error('Worker environment binding already belongs to this runtime')
	}
	host.runtime = &runtime
	handle := voidptr(&host)
	operation := runtime.make_value_host_function(fn [handle] (_ voidptr, args []voidptr) !voidptr {
		mut host := unsafe { &WorkerEnvironmentHost(handle) }
		return host.operate(args) or {
			host.runtime.actual_javascript_exception(host.runtime.binding_exception_value(err))
		}
	})!
	installer := runtime.evaluate_host_value(worker_environment_bootstrap)!
	defer { runtime.release_javascript_value(installer) }
	global := C.JSContextGetGlobalObject(runtime.context)
	runtime.call_javascript_function(installer, global, [operation, global,
		C.vox_jsc_JSValueMakeBoolean(runtime.context, host.settings.is_secure_context())])!
	register_runtime_binding(mut worker_environment_bindings_, owner, &host)
	runtime.add_close_handler(fn [handle, owner] () {
		mut host := unsafe { &WorkerEnvironmentHost(handle) }
		host.close()
		unregister_runtime_binding(mut worker_environment_bindings_, owner)
	})
}

fn (host &WorkerEnvironmentHost) operate(args []voidptr) !voidptr {
	if host.closed { return error('Worker environment binding is closed') }
	if args.len == 0 { return error('Missing worker environment operation') }
	name := host.runtime.binding_dom_string(args[0])!
	navigator := host.scope.navigator()
	location := host.scope.location()
	match name {
		'language' { return host.runtime.binding_string(navigator.language()) }
		'languages' {
			values := navigator.languages().map(host.runtime.binding_string(it))
			mut exception := unsafe { nil }
			array := C.vox_jsc_JSObjectMakeArray(host.runtime.context, uint(values.len), values.data, &exception)
			if exception != unsafe { nil } {
				return host.runtime.actual_javascript_exception(exception)
			}
			return array
		}
		'appCodeName' { return host.runtime.binding_string(navigator.app_code_name()) }
		'appName' { return host.runtime.binding_string(navigator.app_name()) }
		'appVersion' { return host.runtime.binding_string(navigator.app_version()) }
		'platform' { return host.runtime.binding_string(navigator.platform()) }
		'product' { return host.runtime.binding_string(navigator.product()) }
		'userAgent' { return host.runtime.binding_string(navigator.user_agent()) }
		'onLine' { return C.vox_jsc_JSValueMakeBoolean(host.runtime.context, navigator.on_line()) }
		'hardwareConcurrency' {
			return C.vox_jsc_JSValueMakeNumber(host.runtime.context, f64(navigator.hardware_concurrency()))
		}
		'deviceMemory' {
			return C.vox_jsc_JSValueMakeNumber(host.runtime.context, navigator.device_memory()!)
		}
		'href' { return host.runtime.binding_string(location.href()) }
		'origin' { return host.runtime.binding_string(location.origin()) }
		'protocol' { return host.runtime.binding_string(location.protocol()) }
		'host' { return host.runtime.binding_string(location.host()) }
		'hostname' { return host.runtime.binding_string(location.hostname()) }
		'port' { return host.runtime.binding_string(location.port()) }
		'pathname' { return host.runtime.binding_string(location.pathname()) }
		'search' { return host.runtime.binding_string(location.search()) }
		'hash' { return host.runtime.binding_string(location.hash()) }
		else { return error('Unknown worker environment operation') }
	}
}

const worker_environment_bootstrap = r'(function(operate,global,secure){
 const define=Object.defineProperty,descriptor=Object.getOwnPropertyDescriptor,freeze=Object.freeze,TypeError=global.TypeError;
 function WorkerNavigator(){throw new TypeError("Illegal constructor")}
 function WorkerLocation(){throw new TypeError("Illegal constructor")}
 const navigator=Object.create(WorkerNavigator.prototype),location=Object.create(WorkerLocation.prototype);
 function attributes(constructor,object,names){
  for(const name of names){
   const get=descriptor({get [name](){if(this!==object)throw new TypeError("Illegal "+constructor.name+" receiver");const value=operate(name);return name==="languages"?freeze(value):value}},name).get;
   define(constructor.prototype,name,{get,enumerable:true,configurable:true});
  }
 }
 const names=["language","languages","appCodeName","appName","appVersion","platform","product","userAgent","onLine","hardwareConcurrency"];
 if(secure)names.push("deviceMemory");
 attributes(WorkerNavigator,navigator,names);
 attributes(WorkerLocation,location,["href","origin","protocol","host","hostname","port","pathname","search","hash"]);
 const toString=({toString(){if(this!==location)throw new TypeError("Illegal WorkerLocation receiver");return operate("href")}}).toString;
 define(WorkerLocation.prototype,"toString",{value:toString,writable:true,enumerable:true,configurable:true});
 for(const constructor of [WorkerNavigator,WorkerLocation]){
  define(constructor.prototype,Symbol.toStringTag,{value:constructor.name,configurable:true});
  define(constructor,"prototype",{writable:false});
  define(global,constructor.name,{value:constructor,writable:true,configurable:true});
 }
 for(const [name,object] of [["navigator",navigator],["location",location]]){
  const get=descriptor({get [name](){if(this!==global&&this!==undefined&&this!==null)throw new TypeError("Illegal WorkerGlobalScope receiver");return object}},name).get;
  define(global,name,{get,enumerable:true,configurable:true});
 }
})'
