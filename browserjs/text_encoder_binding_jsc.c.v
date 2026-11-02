@[has_globals]
module browserjs

import encoding
import platform

__global text_encoder_bindings_ = map[voidptr]bool{}

pub fn (mut runtime Runtime) install_text_encoder_binding() ! {
	runtime.require_javascript_value_context()!
	owner := voidptr(&runtime)
	if text_encoder_bindings_[owner] { return }
	persistent := platform.enter_persistent()
	defer { platform.leave_persistent(persistent) }
	encoder := encoding.TextEncoder.create()
	operation := runtime.make_value_host_function(fn [owner, encoder] (_ voidptr, args []voidptr) !voidptr {
		mut runtime := unsafe { &Runtime(owner) }
		return runtime.text_encoder_operation(encoder, args) or {
			if err is JavaScriptValueException { return err }
			return runtime.actual_javascript_exception(runtime.binding_exception_value(err))
		}
	})!
	factory := runtime.evaluate_host_value(text_encoder_binding_factory())!
	defer { runtime.release_javascript_value(factory) }
	global := C.JSContextGetGlobalObject(runtime.context)
	_ = runtime.call_javascript_function(factory, global, [operation, global])!
	text_encoder_bindings_[owner] = true
	runtime.add_close_handler(fn [owner] () { text_encoder_bindings_.delete(owner) })
}

fn (mut runtime Runtime) text_encoder_operation(encoder &encoding.TextEncoder, args []voidptr) !voidptr {
	name := runtime.binding_dom_string(args[0])!
	if name == 'encoding' { return runtime.binding_string(encoder.encoding()) }
	// WebIDL USVString performs ToString exactly once, then replaces isolated
	// surrogates. V's encoder consumes the resulting scalar-value UTF-8 string.
	utf16 := runtime.binding_dom_utf16(args[1])!
	source := utf16.to_well_formed().str()
	if name == 'source' { return runtime.binding_string(source) }
	mut exception := unsafe { nil }
	if name == 'encode' {
		bytes := encoder.encode(source)
		view := C.vox_jsc_JSObjectMakeTypedArray(runtime.context, C.kJSTypedArrayTypeUint8Array, uint(bytes.len), &exception)
		if exception != unsafe { nil } { return runtime.actual_javascript_exception(exception) }
		runtime.retain_javascript_value(view)!
		defer { runtime.release_javascript_value(view) }
		if bytes.len > 0 {
			pointer := C.vox_jsc_JSObjectGetTypedArrayBytesPtr(runtime.context, view, &exception)
			if exception != unsafe { nil } { return runtime.actual_javascript_exception(exception) }
			unsafe { C.memcpy(pointer, bytes.data, uint(bytes.len)) }
		}
		return view
	}
	destination := args[2]
	if C.vox_jsc_JSValueGetTypedArrayType(runtime.context, destination, &exception) != C.kJSTypedArrayTypeUint8Array {
		return error('TypeError: destination must be a Uint8Array')
	}
	if exception != unsafe { nil } { return runtime.actual_javascript_exception(exception) }
	// Query the engine slots after source conversion, which can resize or
	// detach the buffer. Fixed shared buffers are accepted by this IDL operation;
	// the wrapper rejects resizable and growable backing stores after conversion.
	length := C.vox_jsc_JSObjectGetTypedArrayByteLength(runtime.context, destination, &exception)
	if exception != unsafe { nil } { return runtime.actual_javascript_exception(exception) }
	if length > uint(2147483647) {
		return error('RangeError: destination exceeds the native byte span')
	}
	mut result := encoding.TextEncoderEncodeIntoResult{}
	if length > 0 {
		buffer := C.vox_jsc_JSObjectGetTypedArrayBuffer(runtime.context, destination, &exception)
		if exception != unsafe { nil } { return runtime.actual_javascript_exception(exception) }
		offset := C.vox_jsc_JSObjectGetTypedArrayByteOffset(runtime.context, destination, &exception)
		if exception != unsafe { nil } { return runtime.actual_javascript_exception(exception) }
		pointer := C.vox_jsc_JSObjectGetArrayBufferBytesPtr(runtime.context, buffer, &exception)
		if exception != unsafe { nil } { return runtime.actual_javascript_exception(exception) }
		// The C API pointer is temporary: no JavaScriptCore calls occur until
		// the borrowed span has been consumed by the native encoding loop.
		mut bytes := unsafe { (&u8(pointer) + int(offset)).vbytes(int(length)) }
		result = encoder.encode_into(source, mut bytes)
	}
	values := [C.vox_jsc_JSValueMakeNumber(runtime.context, f64(result.read)),
		C.vox_jsc_JSValueMakeNumber(runtime.context, f64(result.written))]
	actual := C.vox_jsc_JSObjectMakeArray(runtime.context, uint(values.len), values.data, &exception)
	if exception != unsafe { nil } { return runtime.actual_javascript_exception(exception) }
	return actual
}
