// WebGL typed buffer/list overload conversion. Offsets are still expressed in
// source elements until the translated WebGL helpers validate their witness.
module browserjs

import webgl
import x.json2

fn wg_buffer_witness(request map[string]json2.Any, index int, bytes []u8) webgl.WebGLBufferSource {
	states := wg_object(request['bufferStates'] or { json2.Any(map[string]json2.Any{}) }) or { return webgl.WebGLBufferSource{ buffer: bytes, byte_length: bytes.len } }
	state := wg_object(states[index.str()] or { json2.Any(map[string]json2.Any{}) }) or { return webgl.WebGLBufferSource{ buffer: bytes, byte_length: bytes.len } }
	return webgl.WebGLBufferSource{
		buffer:        bytes
		byte_length:   bytes.len
		element_size:  wg_int(state['elementSize'] or { json2.Any(1) })
		detached:      wg_bool(state['detached'] or { json2.Any(false) })
		out_of_bounds: wg_bool(state['outOfBounds'] or { json2.Any(false) })
	}
}

fn wg_normalize_source_spans(mut context webgl.WebGLRenderingContext, method string, original []json2.Any, request map[string]json2.Any) ?[]json2.Any {
	mut args := original.clone()
	if method == 'bufferData' && wg_arg(args, 1) is json2.Null {
		context.set_error(webgl.invalid_value)
		return none
	}
	if method == 'readPixels' && wg_arg(args, 6) is []json2.Any {
		witness := wg_buffer_witness(request, 6, []u8{})
		if witness.detached || witness.out_of_bounds {
			context.set_error(webgl.invalid_operation)
			return none
		}
	}
	if method.starts_with('compressedTex') {
		format_index := match method {
			'compressedTexImage2D', 'compressedTexImage3D' { 2 }
			'compressedTexSubImage2D' { 6 }
			else { 8 }
		}
		if wg_u32(wg_arg(args, format_index)) !in context.enabled_compressed_texture_formats() {
			context.set_error(webgl.invalid_enum)
			return none
		}
	}
	mut index := -1
	mut error_code := webgl.invalid_value
	mut has_length := true
	match method {
		'bufferData' { index = 1 }
		'bufferSubData' { index = 2 }
		'compressedTexImage2D' { index = 6 }
		'compressedTexSubImage2D' { index = 7 }
		'compressedTexImage3D' { index = 7 }
		'compressedTexSubImage3D' { index = 9 }
		'texImage2D', 'texSubImage2D' {
			if args.len >= 9 { index = 8 }
			error_code = webgl.invalid_operation
			has_length = false
		}
		'texImage3D' {
			index = 9
			error_code = webgl.invalid_operation
			has_length = false
		}
		'texSubImage3D' {
			index = 10
			error_code = webgl.invalid_operation
			has_length = false
		}
		else {}
	}
	if index >= 0 && wg_arg(args, index) is []json2.Any {
		value := wg_array(wg_arg(args, index)).map(u8(wg_u32(it)))
		witness := wg_buffer_witness(request, index, value)
		// bufferData/ SubData put the usage or destination before the offset.
		offset_index := if method == 'bufferData' || method == 'bufferSubData' {
			3
		} else {
			index + 1
		}
		offset := if context.version == .webgl2 {
			wg_u64(wg_arg(args, offset_index))
		} else {
			u64(0)
		}
		length := if context.version == .webgl2 && has_length {
			wg_u32(wg_arg(args, offset_index + 1))
		} else {
			u32(0)
		}
		span := webgl.buffer_source_bytes(witness, offset, length) or {
			context.set_error(error_code)
			return none
		}
		args[index] = json2.Any(span.map(json2.Any(int(it))))
		if offset_index < args.len { args[offset_index] = json2.Any(0) }
		if offset_index + 1 < args.len { args[offset_index + 1] = json2.Any(0) }
	}
	is_uniform := method.starts_with('uniform') && method.ends_with('v')
	is_clear := method.starts_with('clearBuffer') && method.ends_with('v')
	if is_uniform || is_clear {
		list_index := if is_clear || method.starts_with('uniformMatrix') { 2 } else { 1 }
		values := wg_array(wg_arg(args, list_index))
		witness := wg_buffer_witness(request, list_index, []u8{})
		offset := if context.version == .webgl2 {
			wg_u64(wg_arg(args, list_index + 1))
		} else {
			u64(0)
		}
		length := if context.version == .webgl2 && !is_clear {
			wg_u32(wg_arg(args, list_index + 2))
		} else {
			u32(0)
		}
		if witness.detached || witness.out_of_bounds {
			// span_from_typed_array returns an empty span for an OOB witness
			// only when both optional source parameters are zero.
			if offset != 0 || length != 0 {
				context.set_error(webgl.invalid_value)
				return none
			}
			args[list_index] = json2.Any([]json2.Any{})
		} else if method.ends_with('uiv') {
			span := context.span_from_uint32_list(values.map(wg_u32(it)), offset, length) or {
				context.set_error(webgl.invalid_value)
				return none
			}
			args[list_index] = json2.Any(span.map(json2.Any(it)))
		} else if method.ends_with('iv') {
			span := context.span_from_int32_list(values.map(wg_int(it)), offset, length) or {
				context.set_error(webgl.invalid_value)
				return none
			}
			args[list_index] = json2.Any(span.map(json2.Any(it)))
		} else {
			span := context.span_from_float32_list(values.map(f32(wg_number(it))), offset, length) or {
				context.set_error(webgl.invalid_value)
				return none
			}
			args[list_index] = json2.Any(span.map(json2.Any(it)))
		}
	}
	return args
}
