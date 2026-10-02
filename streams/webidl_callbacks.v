// Copyright (c) 2026, Ladybird contributors
// SPDX-License-Identifier: BSD-2-Clause

// Streams/BindingsGlue.h callback contracts and the source WebIDL dictionary
// callback types. The platform value retains the actual controller address;
// the native WebIDL Promise keeps its callback realm and pending reactions.
module streams

import webidl

fn stream_webidl_callback(callback webidl.CallbackType, realm StreamRealm, returns_promise webidl.OperationReturnsPromise) webidl.CallbackType {
	return webidl.CallbackType{
		callback: callback.callback
		operation_returns_promise: returns_promise
		promise_context: callback.promise_context or { realm.promise_context() }
	}
}

fn stream_controller_callback_value(controller voidptr, interface_name string) webidl.Value {
	return webidl.Value{
		kind: .platform_object
		opaque_id: u64(controller)
		platform_interfaces: [interface_name]
	}
}

// Primitive/sequence/buffer conversions at the existing typed Stream Value
// boundary. Arbitrary JavaScript objects require the JS engine's value wrapper.
fn stream_value_to_webidl(value Value) webidl.Value {
	return match value.kind {
		.undefined { webidl.undefined_value() }
		.null_ { webidl.null_value() }
		.boolean { webidl.boolean_value(value.boolean) }
		.number { webidl.number_value(value.number) }
		.string_ { webidl.string_value(value.text) }
		.bytes {
			view := webidl.BufferSource.view(.uint8_array, value.bytes_, 0, u32(value.bytes_.len)) or { panic(err) }
			webidl.buffer_source_value(view)
		}
		.array {
			mut items := []webidl.Value{cap: value.items.len}
			for item in value.items { items << stream_value_to_webidl(item) }
			webidl.sequence_value(items)
		}
		.runtime_value { value.runtime_value_ or { panic('Missing native JavaScript Stream value') } }
	}
}

fn stream_value_from_webidl(value webidl.Value) Value {
	return match value.kind {
		.undefined { undefined_value() }
		.null_ { null_value() }
		.boolean { bool_value(value.boolean_value) }
		.number { number_value(value.number_value) }
		.string_ { string_value(value.string_value) }
		else { runtime_value(value) }
	}
}
