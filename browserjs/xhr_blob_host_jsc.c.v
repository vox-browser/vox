// Copyright (c) 2022-2024, Kenneth Myhra <kennethmyhra@serenityos.org>
// SPDX-License-Identifier: BSD-2-Clause
// XMLHttpRequest.cpp::response()/send(): wrap and unwrap the actual Blob record.
module browserjs

import fileapi

fn (mut host XMLHttpRequestHost) install_native_blob_transport(mut runtime Runtime) ! {
	handle := voidptr(&host)
	owner := voidptr(&runtime)
	runtime.define_value_host_function('__ladybirdXHRBlob', fn [handle, owner] (_ voidptr, args []voidptr) !voidptr {
		mut host := unsafe { &XMLHttpRequestHost(handle) }
		mut runtime := unsafe { &Runtime(owner) }
		if host.closed { return error('InvalidStateError: XMLHttpRequest global has closed') }
		if args.len < 2 { return error('Missing internal XMLHttpRequest Blob arguments') }
		action := runtime.binding_dom_string(args[0])!
		mut exception := unsafe { nil }
		key := int(C.vox_jsc_JSValueToNumber(runtime.context, args[1], &exception))
		if exception != unsafe { nil } { return runtime.actual_javascript_exception(exception) }
		record := host.requests[key] or { return error('InvalidStateError: unknown XMLHttpRequest') }
		mut request := record.request
		if action == 'response' {
			response := request.response()
			blob := response.blob or { return C.vox_jsc_JSValueMakeNull(runtime.context) }
			return runtime.javascript_blob(blob)
		}
		if action == 'send' && args.len == 3 {
			if data := runtime.native_form_data(args[2]) {
				serialized := serialize_native_form_data(data)
				request.send_blob(fileapi.Blob.create(serialized.serialized_data,
					'multipart/form-data; boundary=${serialized.boundary}'))!
				return C.vox_jsc_JSValueMakeBoolean(runtime.context, true)
			}
			blob := runtime.native_blob(args[2]) or { return C.vox_jsc_JSValueMakeBoolean(runtime.context, false) }
			request.send_blob(blob)!
			return C.vox_jsc_JSValueMakeBoolean(runtime.context, true)
		}
		return error('Unknown internal XMLHttpRequest Blob operation')
	})!
}
