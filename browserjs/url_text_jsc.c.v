module browserjs

import os
import platform
import sync.stdatomic

const retain_href_url_objects = os.getenv('VOX_RETAIN_HREF_URL_OBJECTS') != ''
// Diagnostic control: reproduce the worker failure without changing the
// document's URL serialization path in paired production-browser checks.
const retain_worker_url_text_binding = os.getenv('VOX_RETAIN_WORKER_URL_TEXT_BINDING') != ''
const href_text_cache_diagnostics = os.getenv('VOX_HREF_TEXT_CACHE_DIAGNOSTICS') != ''
const href_url_text_diagnostics = os.getenv('VOX_HREF_URL_TEXT_DIAGNOSTICS') != ''

__global href_url_text_reported stdatomic.AtomicVal[bool]

// This internal scalar transport borrows primitive strings and returns copied
// text. It shares the existing parser, never creating a DOMURL or JS wrapper.
fn (mut runtime Runtime) install_url_text_binding(native_getter voidptr) ! {
	runtime.require_javascript_value_context()!
	host := url_bindings_[voidptr(&runtime)] or { return error('URL binding is unavailable') }
	if host.closed { return error('URL binding is closed') }
	handle := voidptr(host)
	runtime.define_value_host_function('__ladybirdSerializeURLText', fn [handle] (_ voidptr, args []voidptr) !voidptr {
		mut host := unsafe { &URLHost(handle) }
		context := host.runtime.context
		if host.closed || args.len != 2 || !C.JSValueIsString(context, args[0]) || !C.JSValueIsString(context, args[1]) {
			return C.vox_jsc_JSValueMakeNull(context)
		}
		work := platform.begin_thread_scratch('serialized href URL')
		defer { work.finish() }
		input := host.usv_string(args[0]) or { return C.vox_jsc_JSValueMakeNull(context) }
		base := host.usv_string(args[1]) or { return C.vox_jsc_JSValueMakeNull(context) }
		parsed := host.parser.parse(input, base) or { return C.vox_jsc_JSValueMakeNull(context) }
		result := host.string_value(parsed.serialize(false)) or { return C.vox_jsc_JSValueMakeNull(context) }
		if href_url_text_diagnostics && href_url_text_reported.compare_and_swap(false, true) {
			eprintln('Vox href URL text: serialized without constructing a URL object')
		}
		return result
	})!
	function := runtime.binding_property(C.JSContextGetGlobalObject(runtime.context), '__ladybirdSerializeURLText')!
	// Authenticate against the actual native constructor and its original getter,
	// including embedders that replace either before the document bootstrap.
	report_cache_hit := if href_text_cache_diagnostics {
		runtime.make_value_host_function(fn (_ voidptr, _ []voidptr) !voidptr {
			eprintln('Vox href text cache: reused primitive input/base result')
			return unsafe { nil }
		})!
	} else {
		C.vox_jsc_JSValueMakeUndefined(runtime.context)
	}
	factory := runtime.evaluate_host_value(r'(function(fn,constructor,prototype,getter,report){Object.defineProperties(fn,{nativeConstructor:{value:constructor},nativePrototype:{value:prototype},nativeHrefGetter:{value:getter}});if(typeof report==="function")Object.defineProperty(fn,"reportCacheHit",{value:report});})')!
	defer { runtime.release_javascript_value(factory) }
	_ = runtime.call_javascript_function(factory, C.vox_jsc_JSValueMakeUndefined(runtime.context), [
		function,
		host.constructor,
		host.prototype,
		native_getter,
		report_cache_hit,
	])!
}
