// Copyright (c) 2026, Ladybird contributors
// SPDX-License-Identifier: BSD-2-Clause
// InterfaceObject.cpp prototypes and native PlatformObject identity adapted to
// actual JSC objects. JSClass API objects override ordinary @@toStringTag lookup,
// so native record branding uses the exact engine object identity instead.
module browserjs


fn (mut runtime Runtime) make_native_stream_wrapper(record voidptr) !voidptr {
	runtime.require_javascript_value_context()!
	object := C.JSObjectMake(runtime.context, unsafe { nil }, unsafe { nil })
	runtime.retain_javascript_value(object)!
	runtime.native_stream_wrapper_records_[object] = record
	return object
}

fn (runtime &Runtime) native_stream_wrapper_record(value voidptr) voidptr {
	return runtime.native_stream_wrapper_records_[value] or { unsafe { nil } }
}
