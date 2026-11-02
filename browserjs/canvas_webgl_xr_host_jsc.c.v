// Copyright (c) 2024-2025, Aliaksandr Kalenik <kalenik.aliaksandr@gmail.com>
// Copyright (c) 2024-2025, Luke Wilde <luke@ladybird.org>
// SPDX-License-Identifier: BSD-2-Clause
module browserjs

import html
import webidl


// Generated Promise-returning receiver checks and the actual owning HTML XR
// operation cross this value host function without serialized Promise records.
fn (mut host CanvasWebGLHost) install_xr(mut runtime Runtime) ! {
	mut pointer := host.document.relevant_settings_object()
	if pointer == unsafe { nil } {
		_ := html.WindowModel.create_top_level(host.document, none, '')!
		pointer = host.document.relevant_settings_object()
	}
	settings := unsafe { &html.EnvironmentSettingsObject(pointer) }
	runtime.bind_scripting_environment(settings)!
	runtime.install_dom_exception_binding()!
	host_handle := voidptr(&host)
	owner_handle := voidptr(&runtime)
	runtime.define_value_host_function('__ladybirdWebGLMakeXRCompatible', fn [host_handle, owner_handle, settings] (_ voidptr, args []voidptr) !voidptr {
		mut host := unsafe { &CanvasWebGLHost(host_handle) }
		mut owner := unsafe { &Runtime(owner_handle) }
		mut native := &webidl.Promise(unsafe { nil })
		if args.len > 1 {
			// The generated impl_from exception is the original engine value.
			native = webidl.create_rejected_promise_for(settings.stream_promise_context(), owner.webidl_value(args[1])!)
		} else {
			if args.len == 0 { return error('Missing internal WebGL XR receiver') }
			key := owner.binding_dom_string(args[0])!
			context := host.contexts[key] or { return error('Missing native WebGL XR context') }
			native = html.make_webgl_xr_compatible(context, settings)
		}
		return owner.javascript_webidl_promise(native, fn [owner_handle] (value webidl.Value) !voidptr {
			mut owner := unsafe { &Runtime(owner_handle) }
			if value.kind == .runtime_value { return owner.actual_webidl_value(value) }
			if value.kind == .undefined { return C.vox_jsc_JSValueMakeUndefined(owner.context) }
			if _ := value.dom_exception_ { return owner.javascript_dom_exception(value) }
			return error('Value is outside the WebGL XR Promise binding')
		})
	})!
}
