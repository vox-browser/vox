@[has_globals]
module browserjs

import encoding
import platform

@[heap]
struct TextDecoderBinding {
	buffer_copy voidptr
mut:
	decoders map[voidptr]&encoding.TextDecoder
}

__global text_decoder_bindings_ = map[voidptr]&TextDecoderBinding{}

pub fn (mut runtime Runtime) install_text_decoder_binding() ! {
	runtime.require_javascript_value_context()!
	owner := voidptr(&runtime)
	if owner in text_decoder_bindings_ { return }
	persistent := platform.enter_persistent()
	defer { platform.leave_persistent(persistent) }
	intrinsics := runtime.evaluate_host_value(crypto_buffer_source_intrinsics)!
	defer { runtime.release_javascript_value(intrinsics) }
	mut binding := &TextDecoderBinding{
		buffer_copy: runtime.retain_javascript_value(runtime.binding_property(intrinsics, 'copy')!)!
	}
	operation := runtime.make_value_host_function(fn [owner, mut binding] (_ voidptr, args []voidptr) !voidptr {
		mut runtime := unsafe { &Runtime(owner) }
		// Both the owner registry and pending decoder bytes survive script calls.
		persistent := platform.enter_persistent()
		defer { platform.leave_persistent(persistent) }
		return runtime.text_decoder_operation(mut binding, args) or {
			if err is JavaScriptValueException { return err }
			return runtime.actual_javascript_exception(runtime.binding_exception_value(err))
		}
	})!
	factory := runtime.evaluate_host_value(text_decoder_binding_factory())!
	defer { runtime.release_javascript_value(factory) }
	global := C.JSContextGetGlobalObject(runtime.context)
	_ = runtime.call_javascript_function(factory, global, [operation, intrinsics, global])!
	text_decoder_bindings_[owner] = binding
	runtime.add_close_handler(fn [owner, mut binding] () {
		binding.decoders = {}
		text_decoder_bindings_.delete(owner)
	})
}

fn (mut runtime Runtime) text_decoder_operation(mut binding TextDecoderBinding, args []voidptr) !voidptr {
	name := runtime.binding_dom_string(args[0])!
	receiver := args[1]
	if name == 'construct' {
		decoder := encoding.TextDecoder.construct(runtime.binding_dom_string(args[2])!, encoding.TextDecoderOptions{
			fatal:      C.JSValueToBoolean(runtime.context, args[3])
			ignore_bom: C.JSValueToBoolean(runtime.context, args[4])
		})!
		binding.decoders[receiver] = decoder
		runtime.retain_javascript_value(receiver)!
		return C.vox_jsc_JSValueMakeUndefined(runtime.context)
	}
	decoder := binding.decoders[receiver] or { return error('TypeError: Illegal TextDecoder receiver') }
	match name {
		'encoding' { return runtime.binding_string(decoder.encoding()) }
		'fatal' { return C.vox_jsc_JSValueMakeBoolean(runtime.context, decoder.fatal()) }
		'ignoreBOM' { return C.vox_jsc_JSValueMakeBoolean(runtime.context, decoder.ignore_bom()) }
		else {}
	}
	mut bytes := []u8{}
	if !C.JSValueIsUndefined(runtime.context, args[2]) {
		// Copy after options conversion, which may mutate or detach the input.
		// Captured engine accessors ignore author buffer/offset/length properties.
		view := runtime.call_javascript_function(binding.buffer_copy, C.vox_jsc_JSValueMakeUndefined(runtime.context), [args[2]])!
		runtime.retain_javascript_value(view)!
		defer { runtime.release_javascript_value(view) }
		mut exception := unsafe { nil }
		length := C.vox_jsc_JSObjectGetTypedArrayByteLength(runtime.context, view, &exception)
		if exception != unsafe { nil } { return runtime.actual_javascript_exception(exception) }
		if length > uint(2147483647) {
			return error('RangeError: input exceeds the native byte span')
		}
		bytes = []u8{len: int(length)}
		if length > 0 {
			pointer := C.vox_jsc_JSObjectGetTypedArrayBytesPtr(runtime.context, view, &exception)
			if exception != unsafe { nil } { return runtime.actual_javascript_exception(exception) }
			// Borrowed C API pointers are consumed without intervening JSC calls.
			unsafe { C.memcpy(bytes.data, pointer, length) }
		}
	}
	decoded := decoder.decode(bytes, encoding.TextDecodeOptions{ stream: C.JSValueToBoolean(runtime.context, args[3]) })!
	return runtime.binding_string(decoded)
}
