// SPDX-License-Identifier: BSD-2-Clause
// Navigator.{idl,cpp}, NavigatorID and NavigatorLanguage source getters.
@[has_globals]
module browserjs


__global navigator_host_bindings_ = map[voidptr]&NavigatorHost{}

pub fn (mut host NavigatorHost) install(mut runtime Runtime) ! {
	runtime.require_javascript_value_context()!
	runtime.bind_scripting_environment(host.settings)!
	owner := voidptr(&runtime)
	if existing := navigator_host_bindings_[owner] {
		if voidptr(existing.navigator) == voidptr(host.navigator) { return }
		return error('Navigator binding already belongs to another Window')
	}
	host.runtime = &runtime
	handle := voidptr(&host)
	operation := runtime.make_value_host_function(fn [handle] (_ voidptr, args []voidptr) !voidptr {
		mut host := unsafe { &NavigatorHost(handle) }
		return host.operate(args) or {
			host.runtime.actual_javascript_exception(host.runtime.binding_exception_value(err))
		}
	})!
	installer := runtime.evaluate_host_value(navigator_host_bootstrap)!
	defer { runtime.release_javascript_value(installer) }
	global := C.JSContextGetGlobalObject(runtime.context)
	runtime.call_javascript_function(installer, global, [operation, global])!
	register_runtime_binding(mut navigator_host_bindings_, owner, &host)
	runtime.add_close_handler(fn [handle, owner] () {
		mut host := unsafe { &NavigatorHost(handle) }
		host.close()
		unregister_runtime_binding(mut navigator_host_bindings_, owner)
	})
}

fn (host &NavigatorHost) operate(args []voidptr) !voidptr {
	if host.closed { return error('Navigator binding is closed') }
	if args.len == 0 { return error('Missing Navigator operation') }
	name := host.runtime.binding_dom_string(args[0])!
	navigator := host.navigator
	match name {
		'language' {
			return host.runtime.binding_string(navigator.language())
		}
		'languages' {
			values := navigator.languages().map(host.runtime.binding_string(it))
			mut exception := unsafe { nil }
			array := C.vox_jsc_JSObjectMakeArray(host.runtime.context, uint(values.len), values.data,
				&exception)
			if exception != unsafe { nil } {
				return host.runtime.actual_javascript_exception(exception)
			}
			return array
		}
		'appCodeName' {
			return host.runtime.binding_string(navigator.app_code_name())
		}
		'appName' {
			return host.runtime.binding_string(navigator.app_name())
		}
		'appVersion' {
			return host.runtime.binding_string(navigator.app_version())
		}
		'platform' {
			return host.runtime.binding_string(navigator.platform())
		}
		'product' {
			return host.runtime.binding_string(navigator.product())
		}
		'productSub' {
			return host.runtime.binding_string(navigator.product_sub())
		}
		'userAgent' {
			return host.runtime.binding_string(navigator.user_agent())
		}
		'vendor' {
			return host.runtime.binding_string(navigator.vendor())
		}
		'vendorSub' {
			return host.runtime.binding_string(navigator.vendor_sub())
		}
		'onLine' {
			return C.vox_jsc_JSValueMakeBoolean(host.runtime.context, navigator.on_line())
		}
		'cookieEnabled' {
			return C.vox_jsc_JSValueMakeBoolean(host.runtime.context, navigator.cookie_enabled())
		}
		'webdriver' {
			return C.vox_jsc_JSValueMakeBoolean(host.runtime.context, navigator.webdriver())
		}
		'pdfViewerEnabled' {
			return C.vox_jsc_JSValueMakeBoolean(host.runtime.context, navigator.pdf_viewer_enabled())
		}
		'hardwareConcurrency' {
			return C.vox_jsc_JSValueMakeNumber(host.runtime.context, f64(navigator.hardware_concurrency()))
		}
		'javaEnabled' {
			return C.vox_jsc_JSValueMakeBoolean(host.runtime.context, navigator.java_enabled())
		}
		else {
			return error('Unknown Navigator operation')
		}
	}
}

const navigator_host_bootstrap = r'(function(operate,global){
 const define=Object.defineProperty,descriptor=Object.getOwnPropertyDescriptor,freeze=Object.freeze,TypeError=global.TypeError;
 function Navigator(){throw new TypeError("Illegal constructor")}
 const navigator=Object.create(Navigator.prototype);
 function check(value){if(value!==navigator)throw new TypeError("Not an object of type Navigator")}
 for(const name of ["language","languages","appCodeName","appName","appVersion","platform","product","productSub","userAgent","vendor","vendorSub","onLine","cookieEnabled","webdriver","pdfViewerEnabled","hardwareConcurrency"]){
  const get=descriptor({get [name](){check(this);const value=operate(name);return name==="languages"?freeze(value):value}},name).get;
  define(Navigator.prototype,name,{get,enumerable:true,configurable:true});
 }
 const javaEnabled=({javaEnabled(){check(this);return operate("javaEnabled")}}).javaEnabled;
 define(Navigator.prototype,"javaEnabled",{value:javaEnabled,writable:true,enumerable:true,configurable:true});
 define(Navigator.prototype,Symbol.toStringTag,{value:"Navigator",configurable:true});
 define(Navigator,"prototype",{writable:false});
 define(global,"Navigator",{value:Navigator,writable:true,configurable:true});
 for(const name of ["navigator","clientInformation"]){
  const get=descriptor({get [name](){if(this!==global&&this!==undefined&&this!==null)throw new TypeError("Not an object of type Window");return navigator}},name).get;
  const property={get,enumerable:true,configurable:true};
  if(name==="clientInformation")property.set=descriptor({set [name](value){if(this!==global&&this!==undefined&&this!==null)throw new TypeError("Not an object of type Window");define(global,name,{value,writable:true,enumerable:true,configurable:true})}},name).set;
  define(global,name,property);
 }
})'
