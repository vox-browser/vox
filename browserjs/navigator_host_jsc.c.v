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
	host.freeze = runtime.evaluate_host_value('Object.freeze')!
	mut arguments := [C.JSContextGetGlobalObject(runtime.context)]
	for name in navigator_attribute_names {
		arguments << runtime.make_native_value_host_function('get ' + name, 0,
			fn [owner, name] (receiver voidptr, _ []voidptr) !voidptr {
				runtime := unsafe { &Runtime(owner) }
				mut actual := runtime.native_navigator_host(receiver)!
				return actual.operate(name)
			})!
	}
	arguments << runtime.make_native_value_host_function('javaEnabled', 0,
		fn [owner] (receiver voidptr, _ []voidptr) !voidptr {
			runtime := unsafe { &Runtime(owner) }
			mut actual := runtime.native_navigator_host(receiver)!
			return actual.operate('javaEnabled')
		})!
	for name in ['navigator', 'clientInformation'] {
		arguments << runtime.make_native_value_host_function('get ' + name, 0,
			fn [owner] (receiver voidptr, _ []voidptr) !voidptr {
				runtime := unsafe { &Runtime(owner) }
				actual := runtime.navigator_host_for_window(receiver)!
				return actual.wrapper
			})!
	}
	replace := runtime.evaluate_host_value('(function(global,value){Object.defineProperty(global,"clientInformation",{value,writable:true,enumerable:true,configurable:true})})')!
	arguments << runtime.make_native_value_host_function('set clientInformation', 1,
		fn [owner, replace] (receiver voidptr, values []voidptr) !voidptr {
			runtime := unsafe { &Runtime(owner) }
			_ = runtime.navigator_host_for_window(receiver)!
			value := if values.len == 0 {
				C.vox_jsc_JSValueMakeUndefined(runtime.context)
			} else {
				values[0]
			}
			return runtime.call_javascript_function(replace, C.vox_jsc_JSValueMakeUndefined(runtime.context), [
				receiver,
				value,
			])
		})!
	installer := runtime.evaluate_host_value(navigator_host_bootstrap)!
	defer { runtime.release_javascript_value(installer) }
	host.wrapper = runtime.retain_javascript_value(runtime.call_javascript_function(installer,
		C.JSContextGetGlobalObject(runtime.context), arguments)!)!
	register_runtime_binding(mut navigator_host_bindings_, owner, &host)
	runtime.add_close_handler(fn [handle, owner] () {
		mut host := unsafe { &NavigatorHost(handle) }
		host.close()
		unregister_runtime_binding(mut navigator_host_bindings_, owner)
	})
}

fn (mut host NavigatorHost) operate(name string) !voidptr {
	if host.closed { return error('Navigator binding is closed') }
	navigator := host.navigator
	match name {
		'language' {
			return host.runtime.binding_string(navigator.language())
		}
		'languages' {
			languages := navigator.languages()
			if host.frozen_languages != unsafe { nil } && languages == host.cached_languages {
				return host.frozen_languages
			}
			values := languages.map(host.runtime.binding_string(it))
			mut exception := unsafe { nil }
			array := C.vox_jsc_JSObjectMakeArray(host.runtime.context, uint(values.len), values.data, &exception)
			if exception != unsafe { nil } {
				return host.runtime.actual_javascript_exception(exception)
			}
			host.runtime.call_javascript_function(host.freeze, C.vox_jsc_JSValueMakeUndefined(host.runtime.context), [array])!
			mut runtime := host.runtime
			previous := host.frozen_languages
			host.frozen_languages = runtime.retain_javascript_value(array)!
			host.cached_languages = languages.clone()
			if previous != unsafe { nil } { runtime.release_javascript_value(previous) }
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

// Native getters accept Navigator instances from any live same-agent realm,
// without reading author-controlled properties or accepting Proxy receivers.
fn (runtime &Runtime) native_navigator_host(receiver voidptr) !&NavigatorHost {
	for _, host in navigator_host_bindings_ {
		if !host.closed && host.wrapper == receiver { return host }
	}
	return runtime.event_binding_type_error('Not an object of type Navigator')
}

fn (runtime &Runtime) navigator_host_for_window(receiver voidptr) !&NavigatorHost {
	for _, host in navigator_host_bindings_ {
		if !host.closed && C.JSContextGetGlobalObject(host.runtime.context) == receiver {
			return host
		}
	}
	return runtime.event_binding_type_error('Not an object of type Window')
}

const navigator_attribute_names = ['language', 'languages', 'appCodeName', 'appName', 'appVersion',
	'platform', 'product', 'productSub', 'userAgent', 'vendor', 'vendorSub', 'onLine', 'cookieEnabled',
	'webdriver', 'pdfViewerEnabled', 'hardwareConcurrency']

const navigator_host_bootstrap = r'(function(global){
 const define=Object.defineProperty,TypeError=global.TypeError;
 function Navigator(){throw new TypeError("Illegal constructor")}
 const navigator=Object.create(Navigator.prototype),args=arguments;
 const names=["language","languages","appCodeName","appName","appVersion","platform","product","productSub","userAgent","vendor","vendorSub","onLine","cookieEnabled","webdriver","pdfViewerEnabled","hardwareConcurrency"];
 let index=1;
 for(const name of names)define(Navigator.prototype,name,{get:args[index++],enumerable:true,configurable:true});
 define(Navigator.prototype,"javaEnabled",{value:args[index++],writable:true,enumerable:true,configurable:true});
 define(Navigator.prototype,Symbol.toStringTag,{value:"Navigator",configurable:true});
 define(Navigator,"prototype",{writable:false});
 define(global,"Navigator",{value:Navigator,writable:true,configurable:true});
 define(global,"navigator",{get:args[index++],enumerable:true,configurable:true});
 define(global,"clientInformation",{get:args[index++],set:args[index++],enumerable:true,configurable:true});
 return navigator;
})'
