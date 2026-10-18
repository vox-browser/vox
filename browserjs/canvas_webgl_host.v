// Copyright (c) 2026, Ladybird contributors
// SPDX-License-Identifier: BSD-2-Clause
// Synchronous host conversion/dispatch for the upstream WebGL IDL operations.
// All shader, raster, resource, validation and error logic remains in webgl/.
module browserjs

import css
import dom
import html
import webgl
import webidl
import x.json2
import math

@[heap]
pub struct CanvasWebGLHost {
mut:
	document            &dom.Document = unsafe { nil }
	elements            map[string]&dom.Element
	contexts            map[string]&webgl.WebGLRenderingContext
	resource_kinds      map[string]string
	logical_objects     map[string]string
	platform_objects    map[voidptr]string
	next_handle         int
	buffers             map[string]&webgl.WebGLBuffer
	framebuffers        map[string]&webgl.WebGLFramebuffer
	renderbuffers       map[string]&webgl.WebGLRenderbuffer
	textures            map[string]&webgl.WebGLTexture
	shaders             map[string]&webgl.WebGLShader
	programs            map[string]&webgl.WebGLProgram
	queries             map[string]&webgl.WebGLQuery
	samplers            map[string]&webgl.WebGLSampler
	syncs               map[string]&webgl.WebGLSync
	transform_feedbacks map[string]&webgl.WebGLTransformFeedback
	vertex_arrays       map[string]&webgl.WebGLVertexArrayObject
	vertex_arrays_oes   map[string]&webgl.WebGLVertexArrayObjectOES
	uniform_locations   map[string]&webgl.WebGLUniformLocation
}

pub fn CanvasWebGLHost.create(document &dom.Document) &CanvasWebGLHost {
	mut host := &CanvasWebGLHost{ document: document }
	root := unsafe { &dom.Node(document) }
	for index, element in css.query_selector_all(root, '*') {
		host.elements['__element_${index}'] = element
	}
	return host
}

// Compact DOM replay must adopt the exact canvas that owns native GL content.
pub fn (host &CanvasWebGLHost) elements_for_binding() map[string]&dom.Element {
	return host.elements.clone()
}

pub fn (mut host CanvasWebGLHost) install(mut runtime Runtime) ! {
	runtime.define_host_function('__ladybirdWebGL', fn [mut host, mut runtime] (input string) !string {
		for key, element in runtime.canvas_elements_for_binding() { host.elements[key] = element }
		return host.call(input)
	})!
	runtime.add_canvas_element_provider_with_identity_lookup(fn [mut host] () map[string]&dom.Element {
		return host.elements_for_binding()
	}, fn [mut host] (key string) ?&dom.Element {
		if key !in host.elements { return none }
		return unsafe { host.elements[key] }
	}, fn [host] (element &dom.Element) []string {
		return native_canvas_element_identity_keys(host.elements, element)
	})
	$if darwin || linux {
		host.install_xr(mut runtime)!
	}
}

fn wg_object(value json2.Any) !map[string]json2.Any {
	if value is map[string]json2.Any { return value }
	return error('TypeError: expected an object')
}

fn wg_arg(args []json2.Any, index int) json2.Any {
	return if index < args.len { args[index] } else { json2.Any(json2.Null{}) }
}

fn wg_value(value json2.Any) webidl.Value {
	return match value {
		bool { webidl.boolean_value(value) }
		string { webidl.string_value(value) }
		int { webidl.number_value(f64(value)) }
		i32 { webidl.number_value(f64(value)) }
		i64 { webidl.number_value(f64(value)) }
		u32 { webidl.number_value(f64(value)) }
		u64 { webidl.number_value(f64(value)) }
		f32 { webidl.number_value(f64(value)) }
		f64 { webidl.number_value(value) }
		map[string]json2.Any { webidl.object_value(map[string]webidl.Value{}) }
		[]json2.Any { webidl.sequence_value([]webidl.Value{}) }
		else { webidl.null_value() }
	}
}

fn wg_number(value json2.Any) f64 {
	return webidl.value_to_number(wg_value(value)) or { math.nan() }
}

fn wg_integer(value json2.Any, bits int, signed bool) f64 {
	return webidl.convert_to_int(wg_value(value), bits, signed, .no, .no) or { 0 }
}

fn wg_u32(value json2.Any) u32 { return u32(wg_integer(value, 32, false)) }

fn wg_int(value json2.Any) int { return int(wg_integer(value, 32, true)) }

fn wg_i64(value json2.Any) i64 { return i64(wg_integer(value, 64, true)) }

fn wg_u64(value json2.Any) u64 { return u64(wg_integer(value, 64, false)) }

fn wg_string(value json2.Any) string { return webidl.to_string(wg_value(value)) or { '' } }

fn wg_bool(value json2.Any) bool {
	return match value {
		bool { value }
		string { value.len > 0 }
		int, i32, i64, u32, u64, f32, f64 {
			number := wg_number(value)
			number != 0 && !math.is_nan(number)
		}
		json2.Null { false }
		else { true }
	}
}

fn wg_array(value json2.Any) []json2.Any {
	return if value is []json2.Any { value } else { []json2.Any{} }
}

fn wg_handle(value json2.Any) string {
	if value is map[string]json2.Any { return wg_string(value['handle'] or { json2.Any('') }) }
	return ''
}

fn wg_dom_value(value json2.Any) dom.JSValue {
	v := wg_value(value)
	return match v.kind {
		.boolean { dom.js_bool(v.boolean_value) }
		.number { dom.js_number(v.number_value) }
		.string_ { dom.js_string(v.string_value) }
		.object, .sequence { dom.JSValue{ kind: .object } }
		else { dom.js_null() }
	}
}

fn wg_options(value json2.Any) ?map[string]dom.JSValue {
	if value is map[string]json2.Any {
		mut result := map[string]dom.JSValue{}
		for name, member in value { result[name] = wg_dom_value(member) }
		return result
	}
	return none
}

fn wg_attributes(value webgl.WebGLContextAttributes) json2.Any {
	power := match value.power_preference {
		.default_ { 'default' }
		.high_performance { 'high-performance' }
		.low_power { 'low-power' }
	}
	return json2.Any({
		'alpha':                        json2.Any(value.alpha)
		'antialias':                    json2.Any(value.antialias)
		'depth':                        json2.Any(value.depth)
		'desynchronized':               json2.Any(value.desynchronized)
		'failIfMajorPerformanceCaveat': json2.Any(value.fail_if_major_performance_caveat)
		'powerPreference':              json2.Any(power)
		'premultipliedAlpha':           json2.Any(value.premultiplied_alpha)
		'preserveDrawingBuffer':        json2.Any(value.preserve_drawing_buffer)
		'stencil':                      json2.Any(value.stencil)
		'xrCompatible':                 json2.Any(value.xr_compatible)
	})
}

fn (host &CanvasWebGLHost) validate_resource(value json2.Any, kind string, nullable bool) ! {
	handle := wg_handle(value)
	if handle == '' && nullable && value is json2.Null { return }
	actual := host.resource_kinds[handle] or { return error('TypeError: expected WebGL ${kind}') }
	if actual != kind { return error('TypeError: expected WebGL ${kind}') }
}

fn (mut host CanvasWebGLHost) register(context &webgl.WebGLRenderingContext, kind string, object ?&webgl.WebGLObject) string {
	host.next_handle++
	handle := host.next_handle.str()
	host.resource_kinds[handle] = kind
	if value := object {
		// Wrapper identity follows the actual retained platform object, including
		// invalidated objects that remain in the source's traced binding slots.
		host.platform_objects[voidptr(value)] = handle
		if _ := value.handle(context.identity(), context.context_generation()) {
			host.logical_objects['${context.identity()}/${value.bookkeeping_id()}'] = handle
		}
	}
	return handle
}

fn (host &CanvasWebGLHost) resource_reply(handle string) json2.Any {
	return json2.Any({
		'handle': json2.Any(handle)
		'kind':   json2.Any(host.resource_kinds[handle] or { '' })
	})
}

// JSON has no representation for non-finite numbers or negative zero. Keep the
// source numeric value across this compatibility transport; JavaScript performs
// primitive numeric conversion when decoding the tag.
fn wg_reply_number(value f64) json2.Any {
	if math.is_nan(value) || math.is_inf(value, 0) || (value == 0 && math.signbit(value)) {
		text := if value == 0 { '-0' } else { webidl.to_string(webidl.number_value(value)) or { panic(err) } }
		return json2.Any({'webglNumber': json2.Any(text)})
	}
	return json2.Any(value)
}

fn (mut host CanvasWebGLHost) parameter(context &webgl.WebGLRenderingContext, value webgl.WebGLParameterValue) json2.Any {
	if texture := value.texture {
		if handle := host.platform_objects[voidptr(&texture.object)] {
			return host.resource_reply(handle)
		}
		handle := host.register(context, 'texture', &texture.object)
		host.textures[handle] = texture
		return host.resource_reply(handle)
	}
	if framebuffer := value.framebuffer {
		if handle := host.platform_objects[voidptr(&framebuffer.object)] {
			return host.resource_reply(handle)
		}
		handle := host.register(context, 'framebuffer', &framebuffer.object)
		host.framebuffers[handle] = framebuffer
		return host.resource_reply(handle)
	}
	if buffer := value.buffer {
		if handle := host.platform_objects[voidptr(&buffer.object)] {
			return host.resource_reply(handle)
		}
		handle := host.register(context, 'buffer', &buffer.object)
		host.buffers[handle] = buffer
		return host.resource_reply(handle)
	}
	if renderbuffer := value.renderbuffer {
		if handle := host.platform_objects[voidptr(&renderbuffer.object)] {
			return host.resource_reply(handle)
		}
		handle := host.register(context, 'renderbuffer', &renderbuffer.object)
		host.renderbuffers[handle] = renderbuffer
		return host.resource_reply(handle)
	}
	if sampler := value.sampler {
		handle := host.register(context, 'sampler', &sampler.object)
		host.samplers[handle] = sampler
		return host.resource_reply(handle)
	}
	if query := value.query {
		if handle := host.platform_objects[voidptr(&query.object)] {
			return host.resource_reply(handle)
		}
		handle := host.register(context, 'query', &query.object)
		host.queries[handle] = query
		return host.resource_reply(handle)
	}
	if shader := value.shader {
		if handle := host.platform_objects[voidptr(&shader.object)] {
			return host.resource_reply(handle)
		}
		handle := host.register(context, 'shader', &shader.object)
		host.shaders[handle] = shader
		return host.resource_reply(handle)
	}
	if program := value.program {
		if handle := host.platform_objects[voidptr(&program.object)] {
			return host.resource_reply(handle)
		}
		handle := host.register(context, 'program', &program.object)
		host.programs[handle] = program
		return host.resource_reply(handle)
	}
	if array := value.vertex_array {
		if handle := host.platform_objects[voidptr(&array.object)] {
			return host.resource_reply(handle)
		}
		handle := host.register(context, 'vertex_array', &array.object)
		host.vertex_arrays[handle] = array
		return host.resource_reply(handle)
	}
	if array := value.vertex_array_oes {
		if handle := host.platform_objects[voidptr(&array.object)] {
			return host.resource_reply(handle)
		}
		handle := host.register(context, 'vertex_array_oes', &array.object)
		host.vertex_arrays_oes[handle] = array
		return host.resource_reply(handle)
	}
	return match value.kind {
		.none { json2.Any(json2.Null{}) }
		.undefined_ { json2.Any({'webglUndefined': json2.Any(true)}) }
		.integer { json2.Any(value.integer) }
		.number { wg_reply_number(value.number) }
		.boolean { json2.Any(value.boolean) }
		.string_ { json2.Any(value.text) }
		.integers { json2.Any(value.integers.map(json2.Any(it))) }
		.numbers { json2.Any(value.numbers.map(wg_reply_number(it))) }
		.booleans { json2.Any(value.booleans.map(json2.Any(it))) }
		.object {
			if handle := host.logical_objects['${context.identity()}/${value.object}'] {
				host.resource_reply(handle)
			} else {
				json2.Any(json2.Null{})
			}
		}
	}
}

pub fn (mut host CanvasWebGLHost) call(input string) !string {
	request := wg_object(json2.decode[json2.Any](input)!)!
	result := host.dispatch(request) or {
		message := err.msg()
		name := if message.contains(':') { message.all_before(':') } else { 'TypeError' }
		return json2.encode(json2.Any({
			'error': json2.Any({
				'name':    json2.Any(name)
				'message': json2.Any(message)
			})
		}))
	}
	return json2.encode(result)
}

fn (mut host CanvasWebGLHost) dispatch(request map[string]json2.Any) !json2.Any {
	method := wg_string(request['method'] or { json2.Any('') })
	key := wg_string(request['key'] or { json2.Any('') })
	original_args := wg_array(request['args'] or { json2.Any([]json2.Any{}) })
	if method == 'getContext' {
		element := host.elements[key] or {
			if !key.starts_with('__created_') { return json2.Any(json2.Null{}) }
			mut document := unsafe { &dom.Document(host.document) }
			created := document.create_element_ns('http://www.w3.org/1999/xhtml', 'canvas')!
			host.elements[key] = created
			created
		}
		if element.local_name() != 'canvas' { return json2.Any(json2.Null{}) }
		mut canvas := unsafe { &dom.HTMLCanvasElement(element) }
		if width := request['width'] {
			if html.html_canvas_element_width(canvas) != wg_u32(width) {
				html.html_canvas_element_set_width(mut canvas, wg_u32(width))!
			}
		}
		if height := request['height'] {
			if html.html_canvas_element_height(canvas) != wg_u32(height) {
				html.html_canvas_element_set_height(mut canvas, wg_u32(height))!
			}
		}
		kind := wg_string(request['kind'] or { json2.Any('') })
		result := html.html_canvas_element_get_rendering_context(canvas, kind, wg_options(request['options'] or { json2.Any(json2.Null{}) }))!
		context := result.webgl_context or { return json2.Any(json2.Null{}) }
		host.contexts[key] = context
		return json2.Any({
			'kind':                json2.Any(kind)
			'version':             json2.Any(if context.version == .webgl2 { 2 } else { 1 })
			'drawingBufferWidth':  json2.Any(context.drawing_buffer_width())
			'drawingBufferHeight': json2.Any(context.drawing_buffer_height())
			'attributes':          wg_attributes(context.attributes)
		})
	}
	mut context := host.contexts[key] or { return error('TypeError: canvas has no WebGL context') }
	// Resize the owning DOM canvas before executing commands after JS IDL setters.
	if element := host.elements[key] {
		mut canvas := unsafe { &dom.HTMLCanvasElement(element) }
		if width := request['width'] {
			if html.html_canvas_element_width(canvas) != wg_u32(width) {
				html.html_canvas_element_set_width(mut canvas, wg_u32(width))!
			}
		}
		if height := request['height'] {
			if html.html_canvas_element_height(canvas) != wg_u32(height) {
				html.html_canvas_element_set_height(mut canvas, wg_u32(height))!
			}
		}
	}
	if method.starts_with('uniform') && method.ends_with('v') {
		host.validate_resource(wg_arg(original_args, 0), 'uniform_location', true)!
		if !context.validate_uniform_upload_location(host.uniform_locations[wg_handle(wg_arg(original_args, 0))] or { none }) {
			return json2.Any(json2.Null{})
		}
	}
	// Source upload bodies select the context before nullable data or
	// buffer-witness validation can set an error and return.
	if method in ['bufferData', 'bufferSubData', 'texImage2D', 'texSubImage2D', 'texImage3D', 'texSubImage3D']
		|| method.starts_with('compressedTex')
		|| (method == 'readPixels' && (context.version == .webgl1 || wg_arg(original_args, 6) !is json2.Null)) {
		context.native.make_current()
	}
	args := wg_normalize_source_spans(mut context, method, original_args, request) or { return json2.Any(json2.Null{}) }
	match method {
		'__getObjectLabel' {
			object := host.label_object(wg_arg(args, 0))!
			return json2.Any(object.label())
		}
		'__setObjectLabel' {
			mut object := host.label_object(wg_arg(args, 0))!
			object.set_label(wg_string(wg_arg(args, 1)))
		}
		'resize' { return json2.Any(json2.Null{}) }
		'drawingBufferWidth' { return json2.Any(context.drawing_buffer_width()) }
		'drawingBufferHeight' { return json2.Any(context.drawing_buffer_height()) }
		'getContextAttributes' {
			if value := context.get_context_attributes() { return wg_attributes(value) }
			return json2.Any(json2.Null{})
		}
		'getSupportedExtensions' {
			return json2.Any(context.get_supported_extensions(false).map(json2.Any(it)))
		}
		'getExtension' {
			if value := context.get_extension(wg_string(wg_arg(args, 0)), false) {
				return json2.Any({
					'name': json2.Any(value.name)
					'kind': json2.Any('extension')
					'empty': json2.Any(value.creates_empty_object)
				})
			}
			return json2.Any(json2.Null{})
		}
		'vertexAttribDivisorANGLE' {
			extension := context.get_extension('ANGLE_instanced_arrays', false) or { return error('TypeError: unavailable ANGLE_instanced_arrays') }
			extension.vertex_attrib_divisor_angle(mut context, wg_u32(wg_arg(args, 0)), wg_u32(wg_arg(args, 1)))
		}
		'drawArraysInstancedANGLE' {
			extension := context.get_extension('ANGLE_instanced_arrays', false) or { return error('TypeError: unavailable ANGLE_instanced_arrays') }
			extension.draw_arrays_instanced_angle(mut context, wg_u32(wg_arg(args, 0)), wg_int(wg_arg(args, 1)), wg_int(wg_arg(args, 2)), wg_int(wg_arg(args, 3)))
		}
		'drawElementsInstancedANGLE' {
			extension := context.get_extension('ANGLE_instanced_arrays', false) or { return error('TypeError: unavailable ANGLE_instanced_arrays') }
			extension.draw_elements_instanced_angle(mut context, wg_u32(wg_arg(args, 0)), wg_int(wg_arg(args, 1)), wg_u32(wg_arg(args, 2)), wg_i64(wg_arg(args, 3)), wg_int(wg_arg(args, 4)))
		}
		'drawBuffersWEBGL' {
			extension := context.get_extension('WEBGL_draw_buffers', false) or { return error('TypeError: unavailable WEBGL_draw_buffers') }
			extension.draw_buffers_webgl(mut context, wg_array(wg_arg(args, 0)).map(wg_u32(it)))
		}
		'bufferData' {
			value := wg_arg(args, 1)
			if value is []json2.Any {
				context.buffer_data(wg_u32(wg_arg(args, 0)), value.map(u8(wg_u32(it))), wg_u32(wg_arg(args, 2)))
			} else {
				context.buffer_data_size(wg_u32(wg_arg(args, 0)), wg_i64(value), wg_u32(wg_arg(args, 2)))
			}
		}
		'getBufferSubData' {
			mut bytes := wg_array(wg_arg(args, 2)).map(u8(wg_u32(it)))
			context.get_buffer_sub_data_into(wg_u32(wg_arg(args, 0)), wg_i64(wg_arg(args, 1)), mut bytes, wg_u64(wg_arg(args, 3)), wg_u32(wg_arg(args, 4)), u64(wg_buffer_witness(request, 2, bytes).element_size))
			return json2.Any(bytes.map(json2.Any(int(it))))
		}
		'getError' {
			return json2.Any(context.get_error())
		}
		'isContextLost' {
			return json2.Any(context.is_context_lost())
		}
		'createBuffer' {
			value := context.create_buffer()
			{
				handle := host.register(context, 'buffer', &value.object)
				host.buffers[handle] = value
				return host.resource_reply(handle)
			}
		}
		'createFramebuffer' {
			value := context.create_framebuffer()
			{
				handle := host.register(context, 'framebuffer', &value.object)
				host.framebuffers[handle] = value
				return host.resource_reply(handle)
			}
		}
		'createRenderbuffer' {
			value := context.create_renderbuffer()
			{
				handle := host.register(context, 'renderbuffer', &value.object)
				host.renderbuffers[handle] = value
				return host.resource_reply(handle)
			}
		}
		'createTexture' {
			value := context.create_texture()
			{
				handle := host.register(context, 'texture', &value.object)
				host.textures[handle] = value
				return host.resource_reply(handle)
			}
		}
		'createShader' {
			if value := context.create_shader(wg_u32(wg_arg(args, 0))) {
				handle := host.register(context, 'shader', &value.object)
				host.shaders[handle] = value
				return host.resource_reply(handle)
			}
			return json2.Any(json2.Null{})
		}
		'createProgram' {
			value := context.create_program()
			{
				handle := host.register(context, 'program', &value.object)
				host.programs[handle] = value
				return host.resource_reply(handle)
			}
		}
		'bindBuffer' {
			host.validate_resource(wg_arg(args, 1), 'buffer', true)!
			context.bind_buffer(wg_u32(wg_arg(args, 0)), host.buffers[wg_handle(wg_arg(args, 1))] or { none })
		}
		'bufferSubData' {
			context.buffer_sub_data(wg_u32(wg_arg(args, 0)), wg_i64(wg_arg(args, 1)), wg_array(wg_arg(args, 2)).map(u8(wg_u32(it))))
		}
		'deleteBuffer' {
			host.validate_resource(wg_arg(args, 0), 'buffer', true)!
			context.delete_buffer(host.buffers[wg_handle(wg_arg(args, 0))] or { none })
		}
		'isBuffer' {
			host.validate_resource(wg_arg(args, 0), 'buffer', true)!
			return json2.Any(context.is_buffer(host.buffers[wg_handle(wg_arg(args, 0))] or { none }))
		}
		'shaderSource' {
			host.validate_resource(wg_arg(args, 0), 'shader', false)!
			mut argument_0 := host.shaders[wg_handle(wg_arg(args, 0))] or { return error('TypeError: expected shader') }
			context.shader_source(mut argument_0, wg_string(wg_arg(args, 1)))
		}
		'compileShader' {
			host.validate_resource(wg_arg(args, 0), 'shader', false)!
			mut argument_0 := host.shaders[wg_handle(wg_arg(args, 0))] or { return error('TypeError: expected shader') }
			context.compile_shader(mut argument_0)
		}
		'getShaderSource' {
			host.validate_resource(wg_arg(args, 0), 'shader', false)!
			if value := context.get_shader_source(host.shaders[wg_handle(wg_arg(args, 0))] or { return error('TypeError: expected shader') }) {
				return json2.Any(value)
			}
			return json2.Any(json2.Null{})
		}
		'getShaderInfoLog' {
			host.validate_resource(wg_arg(args, 0), 'shader', false)!
			if value := context.get_shader_info_log(host.shaders[wg_handle(wg_arg(args, 0))] or { return error('TypeError: expected shader') }) {
				return json2.Any(value)
			}
			return json2.Any(json2.Null{})
		}
		'attachShader' {
			host.validate_resource(wg_arg(args, 0), 'program', false)!
			mut argument_0 := host.programs[wg_handle(wg_arg(args, 0))] or { return error('TypeError: expected program') }
			host.validate_resource(wg_arg(args, 1), 'shader', false)!
			context.attach_shader(mut argument_0, host.shaders[wg_handle(wg_arg(args, 1))] or { return error('TypeError: expected shader') })
		}
		'detachShader' {
			host.validate_resource(wg_arg(args, 0), 'program', false)!
			mut argument_0 := host.programs[wg_handle(wg_arg(args, 0))] or { return error('TypeError: expected program') }
			host.validate_resource(wg_arg(args, 1), 'shader', false)!
			context.detach_shader(mut argument_0, host.shaders[wg_handle(wg_arg(args, 1))] or { return error('TypeError: expected shader') })
		}
		'linkProgram' {
			host.validate_resource(wg_arg(args, 0), 'program', false)!
			mut argument_0 := host.programs[wg_handle(wg_arg(args, 0))] or { return error('TypeError: expected program') }
			context.link_program(mut argument_0)
		}
		'useProgram' {
			host.validate_resource(wg_arg(args, 0), 'program', true)!
			context.use_program(host.programs[wg_handle(wg_arg(args, 0))] or { none })
		}
		'validateProgram' {
			host.validate_resource(wg_arg(args, 0), 'program', false)!
			mut argument_0 := host.programs[wg_handle(wg_arg(args, 0))] or { return error('TypeError: expected program') }
			context.validate_program(mut argument_0)
		}
		'getUniformLocation' {
			host.validate_resource(wg_arg(args, 0), 'program', false)!
			mut argument_0 := host.programs[wg_handle(wg_arg(args, 0))] or { return error('TypeError: expected program') }
			if value := context.get_uniform_location(mut argument_0, wg_string(wg_arg(args, 1))) {
				handle := host.register(context, 'uniform_location', none)
				host.uniform_locations[handle] = value
				return host.resource_reply(handle)
			}
			return json2.Any(json2.Null{})
		}
		'pixelStorei' {
			context.pixel_storei(wg_u32(wg_arg(args, 0)), wg_int(wg_arg(args, 1)))
		}
		'enable' {
			context.enable(wg_u32(wg_arg(args, 0)))
		}
		'disable' {
			context.disable(wg_u32(wg_arg(args, 0)))
		}
		'isEnabled' {
			return json2.Any(context.is_enabled(wg_u32(wg_arg(args, 0))))
		}
		'enableVertexAttribArray' {
			context.enable_vertex_attrib_array(wg_u32(wg_arg(args, 0)))
		}
		'disableVertexAttribArray' {
			context.disable_vertex_attrib_array(wg_u32(wg_arg(args, 0)))
		}
		'clearColor' {
			context.clear_color(f32(wg_number(wg_arg(args, 0))), f32(wg_number(wg_arg(args, 1))), f32(wg_number(wg_arg(args, 2))), f32(wg_number(wg_arg(args, 3))))
		}
		'clearDepth' {
			context.clear_depth(f32(wg_number(wg_arg(args, 0))))
		}
		'clearStencil' {
			context.clear_stencil(wg_int(wg_arg(args, 0)))
		}
		'colorMask' {
			context.color_mask(wg_bool(wg_arg(args, 0)), wg_bool(wg_arg(args, 1)), wg_bool(wg_arg(args, 2)), wg_bool(wg_arg(args, 3)))
		}
		'depthMask' {
			context.depth_mask(wg_bool(wg_arg(args, 0)))
		}
		'clear' {
			context.clear(wg_u32(wg_arg(args, 0)))
		}
		'viewport' {
			context.viewport(wg_int(wg_arg(args, 0)), wg_int(wg_arg(args, 1)), wg_int(wg_arg(args, 2)), wg_int(wg_arg(args, 3)))
		}
		'scissor' {
			context.scissor(wg_int(wg_arg(args, 0)), wg_int(wg_arg(args, 1)), wg_int(wg_arg(args, 2)), wg_int(wg_arg(args, 3)))
		}
		'drawArrays' {
			context.draw_arrays(wg_u32(wg_arg(args, 0)), wg_int(wg_arg(args, 1)), wg_int(wg_arg(args, 2)))
		}
		'drawElements' {
			context.draw_elements(wg_u32(wg_arg(args, 0)), wg_int(wg_arg(args, 1)), wg_u32(wg_arg(args, 2)), wg_i64(wg_arg(args, 3)))
		}
		'copyBufferSubData' {
			context.copy_buffer_sub_data(wg_u32(wg_arg(args, 0)), wg_u32(wg_arg(args, 1)), wg_i64(wg_arg(args, 2)), wg_i64(wg_arg(args, 3)), wg_i64(wg_arg(args, 4)))
		}
		'createQuery' {
			value := context.create_query()
			{
				handle := host.register(context, 'query', &value.object)
				host.queries[handle] = value
				return host.resource_reply(handle)
			}
		}
		'beginQuery' {
			host.validate_resource(wg_arg(args, 1), 'query', false)!
			mut argument_1 := host.queries[wg_handle(wg_arg(args, 1))] or { return error('TypeError: expected query') }
			context.begin_query(wg_u32(wg_arg(args, 0)), mut argument_1)
		}
		'endQuery' {
			context.end_query(wg_u32(wg_arg(args, 0)))
		}
		'getQuery' {
			if value := context.get_query(wg_u32(wg_arg(args, 0)), wg_u32(wg_arg(args, 1))) {
				return host.parameter(context, webgl.WebGLParameterValue{query: value})
			}
			return json2.Any(json2.Null{})
		}
		'getQueryParameter' {
			host.validate_resource(wg_arg(args, 0), 'query', false)!
			if value := context.get_query_parameter(host.queries[wg_handle(wg_arg(args, 0))] or { return error('TypeError: expected query') }, wg_u32(wg_arg(args, 1))) {
				return json2.Any(value)
			}
			return json2.Any(json2.Null{})
		}
		'deleteQuery' {
			host.validate_resource(wg_arg(args, 0), 'query', true)!
			mut argument_0 := ?&webgl.WebGLQuery(none)
			if value := host.queries[wg_handle(wg_arg(args, 0))] { argument_0 = value }
			context.delete_query(mut argument_0)
		}
		'createSampler' {
			value := context.create_sampler()
			{
				handle := host.register(context, 'sampler', &value.object)
				host.samplers[handle] = value
				return host.resource_reply(handle)
			}
		}
		'bindSampler' {
			host.validate_resource(wg_arg(args, 1), 'sampler', true)!
			context.bind_sampler(wg_u32(wg_arg(args, 0)), host.samplers[wg_handle(wg_arg(args, 1))] or { none })
		}
		'samplerParameteri' {
			host.validate_resource(wg_arg(args, 0), 'sampler', false)!
			mut argument_0 := host.samplers[wg_handle(wg_arg(args, 0))] or { return error('TypeError: expected sampler') }
			context.sampler_parameteri(mut argument_0, wg_u32(wg_arg(args, 1)), wg_int(wg_arg(args, 2)))
		}
		'samplerParameterf' {
			host.validate_resource(wg_arg(args, 0), 'sampler', false)!
			mut argument_0 := host.samplers[wg_handle(wg_arg(args, 0))] or { return error('TypeError: expected sampler') }
			context.sampler_parameterf(mut argument_0, wg_u32(wg_arg(args, 1)), f32(wg_number(wg_arg(args, 2))))
		}
		'deleteSampler' {
			host.validate_resource(wg_arg(args, 0), 'sampler', true)!
			mut argument_0 := ?&webgl.WebGLSampler(none)
			if value := host.samplers[wg_handle(wg_arg(args, 0))] { argument_0 = value }
			context.delete_sampler(mut argument_0)
		}
		'fenceSync' {
			if value := context.fence_sync(wg_u32(wg_arg(args, 0)), wg_u32(wg_arg(args, 1))) {
				handle := host.register(context, 'sync', &value.object)
				host.syncs[handle] = value
				return host.resource_reply(handle)
			}
			return json2.Any(json2.Null{})
		}
		'clientWaitSync' {
			host.validate_resource(wg_arg(args, 0), 'sync', false)!
			mut argument_0 := host.syncs[wg_handle(wg_arg(args, 0))] or { return error('TypeError: expected sync') }
			return json2.Any(context.client_wait_sync(mut argument_0, wg_u32(wg_arg(args, 1)), wg_u64(wg_arg(args, 2))))
		}
		'waitSync' {
			host.validate_resource(wg_arg(args, 0), 'sync', false)!
			mut argument_0 := host.syncs[wg_handle(wg_arg(args, 0))] or { return error('TypeError: expected sync') }
			context.wait_sync(mut argument_0, wg_u32(wg_arg(args, 1)), wg_u64(wg_arg(args, 2)))
		}
		'deleteSync' {
			host.validate_resource(wg_arg(args, 0), 'sync', true)!
			mut argument_0 := ?&webgl.WebGLSync(none)
			if value := host.syncs[wg_handle(wg_arg(args, 0))] { argument_0 = value }
			context.delete_sync(mut argument_0)
		}
		'createTransformFeedback' {
			value := context.create_transform_feedback()
			{
				handle := host.register(context, 'transform_feedback', &value.object)
				host.transform_feedbacks[handle] = value
				return host.resource_reply(handle)
			}
		}
		'bindTransformFeedback' {
			host.validate_resource(wg_arg(args, 1), 'transform_feedback', true)!
			context.bind_transform_feedback(wg_u32(wg_arg(args, 0)), host.transform_feedbacks[wg_handle(wg_arg(args, 1))] or { none })
		}
		'beginTransformFeedback' {
			context.begin_transform_feedback(wg_u32(wg_arg(args, 0)))
		}
		'endTransformFeedback' {
			context.end_transform_feedback()
		}
		'pauseTransformFeedback' {
			context.pause_transform_feedback()
		}
		'resumeTransformFeedback' {
			context.resume_transform_feedback()
		}
		'createVertexArray' {
			value := context.create_vertex_array()
			{
				handle := host.register(context, 'vertex_array', &value.object)
				host.vertex_arrays[handle] = value
				return host.resource_reply(handle)
			}
		}
		'bindVertexArray' {
			host.validate_resource(wg_arg(args, 0), 'vertex_array', true)!
			context.bind_vertex_array(host.vertex_arrays[wg_handle(wg_arg(args, 0))] or { none })
		}
		'isVertexArray' {
			host.validate_resource(wg_arg(args, 0), 'vertex_array', true)!
			return json2.Any(context.is_vertex_array(host.vertex_arrays[wg_handle(wg_arg(args, 0))] or { none }))
		}
		'deleteVertexArray' {
			host.validate_resource(wg_arg(args, 0), 'vertex_array', true)!
			mut argument_0 := ?&webgl.WebGLVertexArrayObject(none)
			if value := host.vertex_arrays[wg_handle(wg_arg(args, 0))] { argument_0 = value }
			context.delete_vertex_array(mut argument_0)
		}
		'createVertexArrayOES' {
			value := context.create_vertex_array_oes()
			{
				handle := host.register(context, 'vertex_array_oes', &value.object)
				host.vertex_arrays_oes[handle] = value
				return host.resource_reply(handle)
			}
		}
		'bindVertexArrayOES' {
			host.validate_resource(wg_arg(args, 0), 'vertex_array_oes', true)!
			context.bind_vertex_array_oes(host.vertex_arrays_oes[wg_handle(wg_arg(args, 0))] or { none })
		}
		'isVertexArrayOES' {
			host.validate_resource(wg_arg(args, 0), 'vertex_array_oes', true)!
			return json2.Any(context.is_vertex_array_oes(host.vertex_arrays_oes[wg_handle(wg_arg(args, 0))] or { none }))
		}
		'deleteVertexArrayOES' {
			host.validate_resource(wg_arg(args, 0), 'vertex_array_oes', true)!
			context.delete_vertex_array_oes(host.vertex_arrays_oes[wg_handle(wg_arg(args, 0))] or { none })
		}
		'compressedTexImage3D' {
			context.compressed_tex_image3d(wg_u32(wg_arg(args, 0)), wg_int(wg_arg(args, 1)), wg_u32(wg_arg(args, 2)), wg_int(wg_arg(args, 3)), wg_int(wg_arg(args, 4)), wg_int(wg_arg(args, 5)), wg_int(wg_arg(args, 6)), wg_array(wg_arg(args, 7)).map(u8(wg_u32(it))), wg_u64(wg_arg(args, 8)), wg_u32(wg_arg(args, 9)))
		}
		'drawArraysInstanced' {
			context.draw_arrays_instanced(wg_u32(wg_arg(args, 0)), wg_int(wg_arg(args, 1)), wg_int(wg_arg(args, 2)), wg_int(wg_arg(args, 3)))
		}
		'drawElementsInstanced' {
			context.draw_elements_instanced(wg_u32(wg_arg(args, 0)), wg_int(wg_arg(args, 1)), wg_u32(wg_arg(args, 2)), wg_i64(wg_arg(args, 3)), wg_int(wg_arg(args, 4)))
		}
		'activeTexture' {
			context.active_texture(wg_u32(wg_arg(args, 0)))
		}
		'bindAttribLocation' {
			host.validate_resource(wg_arg(args, 0), 'program', false)!
			context.bind_attrib_location(host.programs[wg_handle(wg_arg(args, 0))] or { return error('TypeError: expected program') }, wg_u32(wg_arg(args, 1)), wg_string(wg_arg(args, 2)))
		}
		'bindFramebuffer' {
			host.validate_resource(wg_arg(args, 1), 'framebuffer', true)!
			context.bind_framebuffer(wg_u32(wg_arg(args, 0)), host.framebuffers[wg_handle(wg_arg(args, 1))] or { none })
		}
		'bindRenderbuffer' {
			host.validate_resource(wg_arg(args, 1), 'renderbuffer', true)!
			context.bind_renderbuffer(wg_u32(wg_arg(args, 0)), host.renderbuffers[wg_handle(wg_arg(args, 1))] or { none })
		}
		'bindTexture' {
			host.validate_resource(wg_arg(args, 1), 'texture', true)!
			context.bind_texture(wg_u32(wg_arg(args, 0)), host.textures[wg_handle(wg_arg(args, 1))] or { none })
		}
		'blendColor' {
			context.blend_color(f32(wg_number(wg_arg(args, 0))), f32(wg_number(wg_arg(args, 1))), f32(wg_number(wg_arg(args, 2))), f32(wg_number(wg_arg(args, 3))))
		}
		'blendEquation' {
			context.blend_equation(wg_u32(wg_arg(args, 0)))
		}
		'blendEquationSeparate' {
			context.blend_equation_separate(wg_u32(wg_arg(args, 0)), wg_u32(wg_arg(args, 1)))
		}
		'blendFunc' {
			context.blend_func(wg_u32(wg_arg(args, 0)), wg_u32(wg_arg(args, 1)))
		}
		'blendFuncSeparate' {
			context.blend_func_separate(wg_u32(wg_arg(args, 0)), wg_u32(wg_arg(args, 1)), wg_u32(wg_arg(args, 2)), wg_u32(wg_arg(args, 3)))
		}
		'checkFramebufferStatus' {
			return json2.Any(context.check_framebuffer_status(wg_u32(wg_arg(args, 0))))
		}
		'copyTexImage2D' {
			context.copy_tex_image2d(wg_u32(wg_arg(args, 0)), wg_int(wg_arg(args, 1)), wg_u32(wg_arg(args, 2)), wg_int(wg_arg(args, 3)), wg_int(wg_arg(args, 4)), wg_int(wg_arg(args, 5)), wg_int(wg_arg(args, 6)), wg_int(wg_arg(args, 7)))
		}
		'copyTexSubImage2D' {
			context.copy_tex_sub_image2d(wg_u32(wg_arg(args, 0)), wg_int(wg_arg(args, 1)), wg_int(wg_arg(args, 2)), wg_int(wg_arg(args, 3)), wg_int(wg_arg(args, 4)), wg_int(wg_arg(args, 5)), wg_int(wg_arg(args, 6)), wg_int(wg_arg(args, 7)))
		}
		'cullFace' {
			context.cull_face(wg_u32(wg_arg(args, 0)))
		}
		'deleteFramebuffer' {
			host.validate_resource(wg_arg(args, 0), 'framebuffer', true)!
			context.delete_framebuffer(host.framebuffers[wg_handle(wg_arg(args, 0))] or { none })
		}
		'deleteRenderbuffer' {
			host.validate_resource(wg_arg(args, 0), 'renderbuffer', true)!
			context.delete_renderbuffer(host.renderbuffers[wg_handle(wg_arg(args, 0))] or { none })
		}
		'deleteTexture' {
			host.validate_resource(wg_arg(args, 0), 'texture', true)!
			context.delete_texture(host.textures[wg_handle(wg_arg(args, 0))] or { none })
		}
		'deleteShader' {
			host.validate_resource(wg_arg(args, 0), 'shader', true)!
			context.delete_shader(host.shaders[wg_handle(wg_arg(args, 0))] or { none })
		}
		'deleteProgram' {
			host.validate_resource(wg_arg(args, 0), 'program', true)!
			context.delete_program(host.programs[wg_handle(wg_arg(args, 0))] or { none })
		}
		'depthFunc' {
			context.depth_func(wg_u32(wg_arg(args, 0)))
		}
		'depthRange' {
			context.depth_range(f32(wg_number(wg_arg(args, 0))), f32(wg_number(wg_arg(args, 1))))
		}
		'finish' {
			context.finish()
		}
		'flush' {
			context.flush()
		}
		'frontFace' {
			context.front_face(wg_u32(wg_arg(args, 0)))
		}
		'generateMipmap' {
			context.generate_mipmap(wg_u32(wg_arg(args, 0)))
		}
		'hint' {
			context.hint(wg_u32(wg_arg(args, 0)), wg_u32(wg_arg(args, 1)))
		}
		'framebufferRenderbuffer' {
			host.validate_resource(wg_arg(args, 3), 'renderbuffer', true)!
			context.framebuffer_renderbuffer(wg_u32(wg_arg(args, 0)), wg_u32(wg_arg(args, 1)), wg_u32(wg_arg(args, 2)), host.renderbuffers[wg_handle(wg_arg(args, 3))] or { none })
		}
		'framebufferTexture2D' {
			host.validate_resource(wg_arg(args, 3), 'texture', true)!
			context.framebuffer_texture2d(wg_u32(wg_arg(args, 0)), wg_u32(wg_arg(args, 1)), wg_u32(wg_arg(args, 2)), host.textures[wg_handle(wg_arg(args, 3))] or { none }, wg_int(wg_arg(args, 4)))
		}
		'getFramebufferAttachmentParameter' {
			return host.parameter(context, context.get_framebuffer_attachment_parameter(wg_u32(wg_arg(args, 0)), wg_u32(wg_arg(args, 1)), wg_u32(wg_arg(args, 2))))
		}
		'getAttachedShaders' {
			host.validate_resource(wg_arg(args, 0), 'program', false)!
			values := context.get_attached_shaders(host.programs[wg_handle(wg_arg(args, 0))] or { return error('TypeError: expected program') }) or { return json2.Any(json2.Null{}) }
			mut result := []json2.Any{}
			for value in values { result << host.parameter(context, webgl.WebGLParameterValue{shader: value}) }
			return json2.Any(result)
		}
		'getProgramInfoLog' {
			host.validate_resource(wg_arg(args, 0), 'program', false)!
			if value := context.get_program_info_log(host.programs[wg_handle(wg_arg(args, 0))] or { return error('TypeError: expected program') }) {
				return json2.Any(value)
			}
			return json2.Any(json2.Null{})
		}
		'getProgramParameter' {
			host.validate_resource(wg_arg(args, 0), 'program', false)!
			return host.parameter(context, context.get_program_parameter(host.programs[wg_handle(wg_arg(args, 0))] or { return error('TypeError: expected program') }, wg_u32(wg_arg(args, 1))))
		}
		'getShaderParameter' {
			host.validate_resource(wg_arg(args, 0), 'shader', false)!
			return host.parameter(context, context.get_shader_parameter(host.shaders[wg_handle(wg_arg(args, 0))] or { return error('TypeError: expected shader') }, wg_u32(wg_arg(args, 1))))
		}
		'getShaderPrecisionFormat' {
			value := context.get_shader_precision_format(wg_u32(wg_arg(args, 0)), wg_u32(wg_arg(args, 1)))
			return json2.Any({
				'rangeMin':  json2.Any(value.range_min)
				'rangeMax':  json2.Any(value.range_max)
				'precision': json2.Any(value.precision)
			})
		}
		'getBufferParameter' {
			return host.parameter(context, context.get_buffer_parameter(wg_u32(wg_arg(args, 0)), wg_u32(wg_arg(args, 1))))
		}
		'getParameter' {
			return host.parameter(context, context.get_parameter(wg_u32(wg_arg(args, 0))))
		}
		'getRenderbufferParameter' {
			return host.parameter(context, context.get_renderbuffer_parameter(wg_u32(wg_arg(args, 0)), wg_u32(wg_arg(args, 1))))
		}
		'getTexParameter' {
			return host.parameter(context, context.get_tex_parameter(wg_u32(wg_arg(args, 0)), wg_u32(wg_arg(args, 1))))
		}
		'getUniform' {
			host.validate_resource(wg_arg(args, 0), 'program', false)!
			host.validate_resource(wg_arg(args, 1), 'uniform_location', false)!
			return host.parameter(context, context.get_uniform(host.programs[wg_handle(wg_arg(args, 0))] or { return error('TypeError: expected program') }, host.uniform_locations[wg_handle(wg_arg(args, 1))] or { none }))
		}
		'getActiveAttrib' {
			host.validate_resource(wg_arg(args, 0), 'program', false)!
			if value := context.get_active_attrib(host.programs[wg_handle(wg_arg(args, 0))] or { return error('TypeError: expected program') }, wg_u32(wg_arg(args, 1))) {
				return json2.Any({
					'name': json2.Any(value.name)
					'type': json2.Any(value.type_)
					'size': json2.Any(value.size)
				})
			}
			return json2.Any(json2.Null{})
		}
		'getActiveUniform' {
			host.validate_resource(wg_arg(args, 0), 'program', false)!
			if value := context.get_active_uniform(host.programs[wg_handle(wg_arg(args, 0))] or { return error('TypeError: expected program') }, wg_u32(wg_arg(args, 1))) {
				return json2.Any({
					'name': json2.Any(value.name)
					'type': json2.Any(value.type_)
					'size': json2.Any(value.size)
				})
			}
			return json2.Any(json2.Null{})
		}
		'getAttribLocation' {
			host.validate_resource(wg_arg(args, 0), 'program', false)!
			return json2.Any(context.get_attrib_location(host.programs[wg_handle(wg_arg(args, 0))] or { return error('TypeError: expected program') }, wg_string(wg_arg(args, 1))))
		}
		'getVertexAttrib' {
			return host.parameter(context, context.get_vertex_attrib(wg_u32(wg_arg(args, 0)), wg_u32(wg_arg(args, 1))))
		}
		'getVertexAttribOffset' {
			return json2.Any(context.get_vertex_attrib_offset(wg_u32(wg_arg(args, 0)), wg_u32(wg_arg(args, 1))))
		}
		'isFramebuffer' {
			host.validate_resource(wg_arg(args, 0), 'framebuffer', true)!
			return json2.Any(context.is_framebuffer(host.framebuffers[wg_handle(wg_arg(args, 0))] or { none }))
		}
		'isRenderbuffer' {
			host.validate_resource(wg_arg(args, 0), 'renderbuffer', true)!
			return json2.Any(context.is_renderbuffer(host.renderbuffers[wg_handle(wg_arg(args, 0))] or { none }))
		}
		'isTexture' {
			host.validate_resource(wg_arg(args, 0), 'texture', true)!
			return json2.Any(context.is_texture(host.textures[wg_handle(wg_arg(args, 0))] or { none }))
		}
		'isShader' {
			host.validate_resource(wg_arg(args, 0), 'shader', true)!
			// Keep the nullable call explicit: the compatibility compiler otherwise
			// propagates inline map `none` as this enclosing Result's error.
			shader := host.shaders[wg_handle(wg_arg(args, 0))] or {
				return json2.Any(context.is_shader(none))
			}
			return json2.Any(context.is_shader(shader))
		}
		'isProgram' {
			host.validate_resource(wg_arg(args, 0), 'program', true)!
			// Preserve the actual nullable Source call without inline map-option
			// propagation into this host Result under the compatibility compiler.
			program := host.programs[wg_handle(wg_arg(args, 0))] or {
				return json2.Any(context.is_program(none))
			}
			return json2.Any(context.is_program(program))
		}
		'lineWidth' {
			context.line_width(f32(wg_number(wg_arg(args, 0))))
		}
		'polygonOffset' {
			context.polygon_offset(f32(wg_number(wg_arg(args, 0))), f32(wg_number(wg_arg(args, 1))))
		}
		'renderbufferStorage' {
			context.renderbuffer_storage(wg_u32(wg_arg(args, 0)), wg_u32(wg_arg(args, 1)), wg_int(wg_arg(args, 2)), wg_int(wg_arg(args, 3)))
		}
		'sampleCoverage' {
			context.sample_coverage(f32(wg_number(wg_arg(args, 0))), wg_bool(wg_arg(args, 1)))
		}
		'stencilFunc' {
			context.stencil_func(wg_u32(wg_arg(args, 0)), wg_int(wg_arg(args, 1)), wg_u32(wg_arg(args, 2)))
		}
		'stencilFuncSeparate' {
			context.stencil_func_separate(wg_u32(wg_arg(args, 0)), wg_u32(wg_arg(args, 1)), wg_int(wg_arg(args, 2)), wg_u32(wg_arg(args, 3)))
		}
		'stencilMask' {
			context.stencil_mask(wg_u32(wg_arg(args, 0)))
		}
		'stencilMaskSeparate' {
			context.stencil_mask_separate(wg_u32(wg_arg(args, 0)), wg_u32(wg_arg(args, 1)))
		}
		'stencilOp' {
			context.stencil_op(wg_u32(wg_arg(args, 0)), wg_u32(wg_arg(args, 1)), wg_u32(wg_arg(args, 2)))
		}
		'stencilOpSeparate' {
			context.stencil_op_separate(wg_u32(wg_arg(args, 0)), wg_u32(wg_arg(args, 1)), wg_u32(wg_arg(args, 2)), wg_u32(wg_arg(args, 3)))
		}
		'texParameteri' {
			context.tex_parameteri(wg_u32(wg_arg(args, 0)), wg_u32(wg_arg(args, 1)), wg_int(wg_arg(args, 2)))
		}
		'texParameterf' {
			context.tex_parameterf(wg_u32(wg_arg(args, 0)), wg_u32(wg_arg(args, 1)), f32(wg_number(wg_arg(args, 2))))
		}
		'uniform1f' {
			host.validate_resource(wg_arg(args, 0), 'uniform_location', true)!
			context.uniform1f(host.uniform_locations[wg_handle(wg_arg(args, 0))] or { none }, f32(wg_number(wg_arg(args, 1))))
		}
		'uniform2f' {
			host.validate_resource(wg_arg(args, 0), 'uniform_location', true)!
			context.uniform2f(host.uniform_locations[wg_handle(wg_arg(args, 0))] or { none }, f32(wg_number(wg_arg(args, 1))), f32(wg_number(wg_arg(args, 2))))
		}
		'uniform3f' {
			host.validate_resource(wg_arg(args, 0), 'uniform_location', true)!
			context.uniform3f(host.uniform_locations[wg_handle(wg_arg(args, 0))] or { none }, f32(wg_number(wg_arg(args, 1))), f32(wg_number(wg_arg(args, 2))), f32(wg_number(wg_arg(args, 3))))
		}
		'uniform4f' {
			host.validate_resource(wg_arg(args, 0), 'uniform_location', true)!
			context.uniform4f(host.uniform_locations[wg_handle(wg_arg(args, 0))] or { none }, f32(wg_number(wg_arg(args, 1))), f32(wg_number(wg_arg(args, 2))), f32(wg_number(wg_arg(args, 3))), f32(wg_number(wg_arg(args, 4))))
		}
		'uniform1i' {
			host.validate_resource(wg_arg(args, 0), 'uniform_location', true)!
			context.uniform1i(host.uniform_locations[wg_handle(wg_arg(args, 0))] or { none }, wg_int(wg_arg(args, 1)))
		}
		'uniform2i' {
			host.validate_resource(wg_arg(args, 0), 'uniform_location', true)!
			context.uniform2i(host.uniform_locations[wg_handle(wg_arg(args, 0))] or { none }, wg_int(wg_arg(args, 1)), wg_int(wg_arg(args, 2)))
		}
		'uniform3i' {
			host.validate_resource(wg_arg(args, 0), 'uniform_location', true)!
			context.uniform3i(host.uniform_locations[wg_handle(wg_arg(args, 0))] or { none }, wg_int(wg_arg(args, 1)), wg_int(wg_arg(args, 2)), wg_int(wg_arg(args, 3)))
		}
		'uniform4i' {
			host.validate_resource(wg_arg(args, 0), 'uniform_location', true)!
			context.uniform4i(host.uniform_locations[wg_handle(wg_arg(args, 0))] or { none }, wg_int(wg_arg(args, 1)), wg_int(wg_arg(args, 2)), wg_int(wg_arg(args, 3)), wg_int(wg_arg(args, 4)))
		}
		'vertexAttrib1f' {
			context.vertex_attrib1f(wg_u32(wg_arg(args, 0)), f32(wg_number(wg_arg(args, 1))))
		}
		'vertexAttrib2f' {
			context.vertex_attrib2f(wg_u32(wg_arg(args, 0)), f32(wg_number(wg_arg(args, 1))), f32(wg_number(wg_arg(args, 2))))
		}
		'vertexAttrib3f' {
			context.vertex_attrib3f(wg_u32(wg_arg(args, 0)), f32(wg_number(wg_arg(args, 1))), f32(wg_number(wg_arg(args, 2))), f32(wg_number(wg_arg(args, 3))))
		}
		'vertexAttrib4f' {
			context.vertex_attrib4f(wg_u32(wg_arg(args, 0)), f32(wg_number(wg_arg(args, 1))), f32(wg_number(wg_arg(args, 2))), f32(wg_number(wg_arg(args, 3))), f32(wg_number(wg_arg(args, 4))))
		}
		'vertexAttrib1fv' {
			context.vertex_attrib1fv(wg_u32(wg_arg(args, 0)), wg_array(wg_arg(args, 1)).map(f32(wg_number(it))))
		}
		'vertexAttrib2fv' {
			context.vertex_attrib2fv(wg_u32(wg_arg(args, 0)), wg_array(wg_arg(args, 1)).map(f32(wg_number(it))))
		}
		'vertexAttrib3fv' {
			context.vertex_attrib3fv(wg_u32(wg_arg(args, 0)), wg_array(wg_arg(args, 1)).map(f32(wg_number(it))))
		}
		'vertexAttrib4fv' {
			context.vertex_attrib4fv(wg_u32(wg_arg(args, 0)), wg_array(wg_arg(args, 1)).map(f32(wg_number(it))))
		}
		'vertexAttribPointer' {
			context.vertex_attrib_pointer(wg_u32(wg_arg(args, 0)), wg_int(wg_arg(args, 1)), wg_u32(wg_arg(args, 2)), wg_bool(wg_arg(args, 3)), wg_int(wg_arg(args, 4)), wg_i64(wg_arg(args, 5)))
		}
		'compressedTexImage2D' {
			context.compressed_tex_image2d(wg_u32(wg_arg(args, 0)), wg_int(wg_arg(args, 1)), wg_u32(wg_arg(args, 2)), wg_int(wg_arg(args, 3)), wg_int(wg_arg(args, 4)), wg_int(wg_arg(args, 5)), wg_array(wg_arg(args, 6)).map(u8(wg_u32(it))))
		}
		'compressedTexSubImage2D' {
			context.compressed_tex_sub_image2d(wg_u32(wg_arg(args, 0)), wg_int(wg_arg(args, 1)), wg_int(wg_arg(args, 2)), wg_int(wg_arg(args, 3)), wg_int(wg_arg(args, 4)), wg_int(wg_arg(args, 5)), wg_u32(wg_arg(args, 6)), wg_array(wg_arg(args, 7)).map(u8(wg_u32(it))))
		}
		'texImage2D' {
			if args.len == 6 {
				context.tex_image2d_source(wg_u32(wg_arg(args, 0)), wg_int(wg_arg(args, 1)), wg_int(wg_arg(args, 2)), wg_u32(wg_arg(args, 3)), wg_u32(wg_arg(args, 4)), host.texture_source(wg_arg(args, 5))!, none, 0)!
			} else if wg_arg(args, 8) is map[string]json2.Any {
				context.tex_image2d_source(wg_u32(wg_arg(args, 0)), wg_int(wg_arg(args, 1)), wg_int(wg_arg(args, 2)), wg_u32(wg_arg(args, 6)), wg_u32(wg_arg(args, 7)), host.texture_source(wg_arg(args, 8))!, webgl.WebGLIntSize{ width: wg_int(wg_arg(args, 3)), height: wg_int(wg_arg(args, 4)) }, wg_int(wg_arg(args, 5)))!
			} else if wg_arg(args, 8) is json2.Null {
				context.tex_image2d_null(wg_u32(wg_arg(args, 0)), wg_int(wg_arg(args, 1)), wg_int(wg_arg(args, 2)), wg_int(wg_arg(args, 3)), wg_int(wg_arg(args, 4)), wg_int(wg_arg(args, 5)), wg_u32(wg_arg(args, 6)), wg_u32(wg_arg(args, 7)))
			} else {
				context.tex_image2d(wg_u32(wg_arg(args, 0)), wg_int(wg_arg(args, 1)), wg_u32(wg_arg(args, 2)), wg_int(wg_arg(args, 3)), wg_int(wg_arg(args, 4)), wg_int(wg_arg(args, 5)), wg_u32(wg_arg(args, 6)), wg_u32(wg_arg(args, 7)), wg_array(wg_arg(args, 8)).map(u8(wg_u32(it))))
			}
		}
		'texSubImage2D' {
			if args.len == 7 {
				context.tex_sub_image2d_source(wg_u32(wg_arg(args, 0)), wg_int(wg_arg(args, 1)), wg_int(wg_arg(args, 2)), wg_int(wg_arg(args, 3)), wg_u32(wg_arg(args, 4)), wg_u32(wg_arg(args, 5)), host.texture_source(wg_arg(args, 6))!, none)!
			} else if wg_arg(args, 8) is map[string]json2.Any {
				context.tex_sub_image2d_source(wg_u32(wg_arg(args, 0)), wg_int(wg_arg(args, 1)), wg_int(wg_arg(args, 2)), wg_int(wg_arg(args, 3)), wg_u32(wg_arg(args, 6)), wg_u32(wg_arg(args, 7)), host.texture_source(wg_arg(args, 8))!, webgl.WebGLIntSize{ width: wg_int(wg_arg(args, 4)), height: wg_int(wg_arg(args, 5)) })!
			} else if wg_arg(args, 8) is json2.Null {
				context.tex_sub_image2d_null(wg_u32(wg_arg(args, 0)), wg_int(wg_arg(args, 1)), wg_int(wg_arg(args, 2)), wg_int(wg_arg(args, 3)), wg_int(wg_arg(args, 4)), wg_int(wg_arg(args, 5)), wg_u32(wg_arg(args, 6)), wg_u32(wg_arg(args, 7)))
			} else {
				context.tex_sub_image2d(wg_u32(wg_arg(args, 0)), wg_int(wg_arg(args, 1)), wg_int(wg_arg(args, 2)), wg_int(wg_arg(args, 3)), wg_int(wg_arg(args, 4)), wg_int(wg_arg(args, 5)), wg_u32(wg_arg(args, 6)), wg_u32(wg_arg(args, 7)), wg_array(wg_arg(args, 8)).map(u8(wg_u32(it))))
			}
		}
		'readPixels' {
			if wg_arg(args, 6) !is []json2.Any && wg_arg(args, 6) !is json2.Null {
				context.read_pixels_into_pixel_pack_buffer(wg_int(wg_arg(args, 0)), wg_int(wg_arg(args, 1)), wg_int(wg_arg(args, 2)), wg_int(wg_arg(args, 3)), wg_u32(wg_arg(args, 4)), wg_u32(wg_arg(args, 5)), wg_i64(wg_arg(args, 6)))
				return json2.Any(json2.Null{})
			}
			if wg_arg(args, 6) is json2.Null {
				context.read_pixels_null()
				return json2.Any(json2.Null{})
			}
			mut pixels := wg_array(wg_arg(args, 6)).map(u8(wg_u32(it)))
			context.read_pixels_into(wg_int(wg_arg(args, 0)), wg_int(wg_arg(args, 1)), wg_int(wg_arg(args, 2)), wg_int(wg_arg(args, 3)), wg_u32(wg_arg(args, 4)), wg_u32(wg_arg(args, 5)), mut pixels, wg_u64(wg_arg(args, 7)), wg_u64(request['elementSize'] or { json2.Any(1) }))
			return json2.Any(pixels.map(json2.Any(int(it))))
		}
		'uniform1fv' {
			host.validate_resource(wg_arg(args, 0), 'uniform_location', true)!
			context.uniform1fv(host.uniform_locations[wg_handle(wg_arg(args, 0))] or { none }, wg_array(wg_arg(args, 1)).map(f32(wg_number(it))))
		}
		'uniform2fv' {
			host.validate_resource(wg_arg(args, 0), 'uniform_location', true)!
			context.uniform2fv(host.uniform_locations[wg_handle(wg_arg(args, 0))] or { none }, wg_array(wg_arg(args, 1)).map(f32(wg_number(it))))
		}
		'uniform3fv' {
			host.validate_resource(wg_arg(args, 0), 'uniform_location', true)!
			context.uniform3fv(host.uniform_locations[wg_handle(wg_arg(args, 0))] or { none }, wg_array(wg_arg(args, 1)).map(f32(wg_number(it))))
		}
		'uniform4fv' {
			host.validate_resource(wg_arg(args, 0), 'uniform_location', true)!
			context.uniform4fv(host.uniform_locations[wg_handle(wg_arg(args, 0))] or { none }, wg_array(wg_arg(args, 1)).map(f32(wg_number(it))))
		}
		'uniform1iv' {
			host.validate_resource(wg_arg(args, 0), 'uniform_location', true)!
			context.uniform1iv(host.uniform_locations[wg_handle(wg_arg(args, 0))] or { none }, wg_array(wg_arg(args, 1)).map(wg_int(it)))
		}
		'uniform2iv' {
			host.validate_resource(wg_arg(args, 0), 'uniform_location', true)!
			context.uniform2iv(host.uniform_locations[wg_handle(wg_arg(args, 0))] or { none }, wg_array(wg_arg(args, 1)).map(wg_int(it)))
		}
		'uniform3iv' {
			host.validate_resource(wg_arg(args, 0), 'uniform_location', true)!
			context.uniform3iv(host.uniform_locations[wg_handle(wg_arg(args, 0))] or { none }, wg_array(wg_arg(args, 1)).map(wg_int(it)))
		}
		'uniform4iv' {
			host.validate_resource(wg_arg(args, 0), 'uniform_location', true)!
			context.uniform4iv(host.uniform_locations[wg_handle(wg_arg(args, 0))] or { none }, wg_array(wg_arg(args, 1)).map(wg_int(it)))
		}
		'uniformMatrix2fv' {
			host.validate_resource(wg_arg(args, 0), 'uniform_location', true)!
			context.uniform_matrix2fv(host.uniform_locations[wg_handle(wg_arg(args, 0))] or { none }, wg_bool(wg_arg(args, 1)), wg_array(wg_arg(args, 2)).map(f32(wg_number(it))))
		}
		'uniformMatrix3fv' {
			host.validate_resource(wg_arg(args, 0), 'uniform_location', true)!
			context.uniform_matrix3fv(host.uniform_locations[wg_handle(wg_arg(args, 0))] or { none }, wg_bool(wg_arg(args, 1)), wg_array(wg_arg(args, 2)).map(f32(wg_number(it))))
		}
		'uniformMatrix4fv' {
			host.validate_resource(wg_arg(args, 0), 'uniform_location', true)!
			context.uniform_matrix4fv(host.uniform_locations[wg_handle(wg_arg(args, 0))] or { none }, wg_bool(wg_arg(args, 1)), wg_array(wg_arg(args, 2)).map(f32(wg_number(it))))
		}
		'bindBufferBase' {
			host.validate_resource(wg_arg(args, 2), 'buffer', true)!
			context.bind_buffer_base(wg_u32(wg_arg(args, 0)), wg_u32(wg_arg(args, 1)), host.buffers[wg_handle(wg_arg(args, 2))] or { none })
		}
		'bindBufferRange' {
			host.validate_resource(wg_arg(args, 2), 'buffer', true)!
			context.bind_buffer_range(wg_u32(wg_arg(args, 0)), wg_u32(wg_arg(args, 1)), host.buffers[wg_handle(wg_arg(args, 2))] or { none }, wg_i64(wg_arg(args, 3)), wg_i64(wg_arg(args, 4)))
		}
		'blitFramebuffer' {
			context.blit_framebuffer(wg_int(wg_arg(args, 0)), wg_int(wg_arg(args, 1)), wg_int(wg_arg(args, 2)), wg_int(wg_arg(args, 3)), wg_int(wg_arg(args, 4)), wg_int(wg_arg(args, 5)), wg_int(wg_arg(args, 6)), wg_int(wg_arg(args, 7)), wg_u32(wg_arg(args, 8)), wg_u32(wg_arg(args, 9)))
		}
		'clearBufferfv' {
			context.clear_bufferfv(wg_u32(wg_arg(args, 0)), wg_int(wg_arg(args, 1)), wg_array(wg_arg(args, 2)).map(f32(wg_number(it))))
		}
		'clearBufferiv' {
			context.clear_bufferiv(wg_u32(wg_arg(args, 0)), wg_int(wg_arg(args, 1)), wg_array(wg_arg(args, 2)).map(wg_int(it)))
		}
		'clearBufferuiv' {
			context.clear_bufferuiv(wg_u32(wg_arg(args, 0)), wg_int(wg_arg(args, 1)), wg_array(wg_arg(args, 2)).map(wg_u32(it)))
		}
		'clearBufferfi' {
			context.clear_bufferfi(wg_u32(wg_arg(args, 0)), wg_int(wg_arg(args, 1)), f32(wg_number(wg_arg(args, 2))), wg_int(wg_arg(args, 3)))
		}
		'compressedTexSubImage3D' {
			context.compressed_tex_sub_image3d(wg_u32(wg_arg(args, 0)), wg_int(wg_arg(args, 1)), wg_int(wg_arg(args, 2)), wg_int(wg_arg(args, 3)), wg_int(wg_arg(args, 4)), wg_int(wg_arg(args, 5)), wg_int(wg_arg(args, 6)), wg_int(wg_arg(args, 7)), wg_u32(wg_arg(args, 8)), wg_array(wg_arg(args, 9)).map(u8(wg_u32(it))), wg_u64(wg_arg(args, 10)), wg_u32(wg_arg(args, 11)))
		}
		'deleteTransformFeedback' {
			host.validate_resource(wg_arg(args, 0), 'transform_feedback', true)!
			context.delete_transform_feedback(host.transform_feedbacks[wg_handle(wg_arg(args, 0))] or { none })
		}
		'drawBuffers' {
			context.draw_buffers(wg_array(wg_arg(args, 0)).map(wg_u32(it)))
		}
		'drawRangeElements' {
			context.draw_range_elements(wg_u32(wg_arg(args, 0)), wg_u32(wg_arg(args, 1)), wg_u32(wg_arg(args, 2)), wg_int(wg_arg(args, 3)), wg_u32(wg_arg(args, 4)), wg_i64(wg_arg(args, 5)))
		}
		'framebufferTextureLayer' {
			host.validate_resource(wg_arg(args, 2), 'texture', true)!
			context.framebuffer_texture_layer(wg_u32(wg_arg(args, 0)), wg_u32(wg_arg(args, 1)), host.textures[wg_handle(wg_arg(args, 2))] or { none }, wg_int(wg_arg(args, 3)), wg_int(wg_arg(args, 4)))
		}
		'getInternalformatParameter' {
			return host.parameter(context, context.get_internalformat_parameter(wg_u32(wg_arg(args, 0)), wg_u32(wg_arg(args, 1)), wg_u32(wg_arg(args, 2))))
		}
		'getSyncParameter' {
			host.validate_resource(wg_arg(args, 0), 'sync', false)!
			return host.parameter(context, context.get_sync_parameter(host.syncs[wg_handle(wg_arg(args, 0))] or { return error('TypeError: expected sync') }, wg_u32(wg_arg(args, 1))))
		}
		'getUniformIndices' {
			host.validate_resource(wg_arg(args, 0), 'program', false)!
			if indices := context.get_uniform_indices_nullable(host.programs[wg_handle(wg_arg(args, 0))] or { return error('TypeError: expected program') }, wg_array(wg_arg(args, 1)).map(wg_string(it))) {
				return json2.Any(indices.map(json2.Any(it)))
			}
			return json2.Any(json2.Null{})
		}
		'getActiveUniforms' {
			host.validate_resource(wg_arg(args, 0), 'program', false)!
			return host.parameter(context, context.get_active_uniforms(host.programs[wg_handle(wg_arg(args, 0))] or { return error('TypeError: expected program') }, wg_array(wg_arg(args, 1)).map(wg_u32(it)), wg_u32(wg_arg(args, 2))))
		}
		'getUniformBlockIndex' {
			host.validate_resource(wg_arg(args, 0), 'program', false)!
			return json2.Any(context.get_uniform_block_index(host.programs[wg_handle(wg_arg(args, 0))] or { return error('TypeError: expected program') }, wg_string(wg_arg(args, 1))))
		}
		'getActiveUniformBlockParameter' {
			host.validate_resource(wg_arg(args, 0), 'program', false)!
			return host.parameter(context, context.get_active_uniform_block_parameter(host.programs[wg_handle(wg_arg(args, 0))] or { return error('TypeError: expected program') }, wg_u32(wg_arg(args, 1)), wg_u32(wg_arg(args, 2))))
		}
		'getActiveUniformBlockName' {
			host.validate_resource(wg_arg(args, 0), 'program', false)!
			if value := context.get_active_uniform_block_name(host.programs[wg_handle(wg_arg(args, 0))] or { return error('TypeError: expected program') }, wg_u32(wg_arg(args, 1))) {
				return json2.Any(value)
			}
			return json2.Any(json2.Null{})
		}
		'invalidateFramebuffer' {
			context.invalidate_framebuffer(wg_u32(wg_arg(args, 0)), wg_array(wg_arg(args, 1)).map(wg_u32(it)))
		}
		'invalidateSubFramebuffer' {
			context.invalidate_sub_framebuffer(wg_u32(wg_arg(args, 0)), wg_array(wg_arg(args, 1)).map(wg_u32(it)), wg_int(wg_arg(args, 2)), wg_int(wg_arg(args, 3)), wg_int(wg_arg(args, 4)), wg_int(wg_arg(args, 5)))
		}
		'readBuffer' {
			context.read_buffer(wg_u32(wg_arg(args, 0)))
		}
		'renderbufferStorageMultisample' {
			context.renderbuffer_storage_multisample(wg_u32(wg_arg(args, 0)), wg_int(wg_arg(args, 1)), wg_u32(wg_arg(args, 2)), wg_int(wg_arg(args, 3)), wg_int(wg_arg(args, 4)))
		}
		'texStorage2D' {
			context.tex_storage2d(wg_u32(wg_arg(args, 0)), wg_int(wg_arg(args, 1)), wg_u32(wg_arg(args, 2)), wg_int(wg_arg(args, 3)), wg_int(wg_arg(args, 4)))
		}
		'texStorage3D' {
			context.tex_storage3d(wg_u32(wg_arg(args, 0)), wg_int(wg_arg(args, 1)), wg_u32(wg_arg(args, 2)), wg_int(wg_arg(args, 3)), wg_int(wg_arg(args, 4)), wg_int(wg_arg(args, 5)))
		}
		'texImage3D' {
			if wg_arg(args, 9) is map[string]json2.Any {
				context.tex_image3d_source(wg_u32(wg_arg(args, 0)), wg_int(wg_arg(args, 1)), wg_int(wg_arg(args, 2)), wg_int(wg_arg(args, 5)), wg_u32(wg_arg(args, 7)), wg_u32(wg_arg(args, 8)), host.texture_source(wg_arg(args, 9))!, webgl.WebGLIntSize{ width: wg_int(wg_arg(args, 3)), height: wg_int(wg_arg(args, 4)) }, wg_int(wg_arg(args, 6)))!
			} else if wg_arg(args, 9) is json2.Null {
				context.tex_image3d_null(wg_u32(wg_arg(args, 0)), wg_int(wg_arg(args, 1)), wg_int(wg_arg(args, 2)), wg_int(wg_arg(args, 3)), wg_int(wg_arg(args, 4)), wg_int(wg_arg(args, 5)), wg_int(wg_arg(args, 6)), wg_u32(wg_arg(args, 7)), wg_u32(wg_arg(args, 8)))
			} else {
				context.tex_image3d(wg_u32(wg_arg(args, 0)), wg_int(wg_arg(args, 1)), wg_u32(wg_arg(args, 2)), wg_int(wg_arg(args, 3)), wg_int(wg_arg(args, 4)), wg_int(wg_arg(args, 5)), wg_int(wg_arg(args, 6)), wg_u32(wg_arg(args, 7)), wg_u32(wg_arg(args, 8)), wg_array(wg_arg(args, 9)).map(u8(wg_u32(it))))
			}
		}
		'texSubImage3D' {
			if wg_arg(args, 10) is map[string]json2.Any {
				context.tex_sub_image3d_source(wg_u32(wg_arg(args, 0)), wg_int(wg_arg(args, 1)), wg_int(wg_arg(args, 2)), wg_int(wg_arg(args, 3)), wg_int(wg_arg(args, 4)), wg_int(wg_arg(args, 7)), wg_u32(wg_arg(args, 8)), wg_u32(wg_arg(args, 9)), host.texture_source(wg_arg(args, 10))!, webgl.WebGLIntSize{ width: wg_int(wg_arg(args, 5)), height: wg_int(wg_arg(args, 6)) })!
			} else if wg_arg(args, 10) is json2.Null {
				context.tex_sub_image3d_null(wg_u32(wg_arg(args, 0)), wg_int(wg_arg(args, 1)), wg_int(wg_arg(args, 2)), wg_int(wg_arg(args, 3)), wg_int(wg_arg(args, 4)), wg_int(wg_arg(args, 5)), wg_int(wg_arg(args, 6)), wg_int(wg_arg(args, 7)), wg_u32(wg_arg(args, 8)), wg_u32(wg_arg(args, 9)))
			} else {
				context.tex_sub_image3d(wg_u32(wg_arg(args, 0)), wg_int(wg_arg(args, 1)), wg_int(wg_arg(args, 2)), wg_int(wg_arg(args, 3)), wg_int(wg_arg(args, 4)), wg_int(wg_arg(args, 5)), wg_int(wg_arg(args, 6)), wg_int(wg_arg(args, 7)), wg_u32(wg_arg(args, 8)), wg_u32(wg_arg(args, 9)), wg_array(wg_arg(args, 10)).map(u8(wg_u32(it))))
			}
		}
		'transformFeedbackVaryings' {
			host.validate_resource(wg_arg(args, 0), 'program', false)!
			context.transform_feedback_varyings(host.programs[wg_handle(wg_arg(args, 0))] or { return error('TypeError: expected program') }, wg_array(wg_arg(args, 1)).map(wg_string(it)), wg_u32(wg_arg(args, 2)))
		}
		'uniformBlockBinding' {
			host.validate_resource(wg_arg(args, 0), 'program', false)!
			context.uniform_block_binding(host.programs[wg_handle(wg_arg(args, 0))] or { return error('TypeError: expected program') }, wg_u32(wg_arg(args, 1)), wg_u32(wg_arg(args, 2)))
		}
		'uniform1ui' {
			host.validate_resource(wg_arg(args, 0), 'uniform_location', true)!
			context.uniform1ui(host.uniform_locations[wg_handle(wg_arg(args, 0))] or { none }, wg_u32(wg_arg(args, 1)))
		}
		'uniform2ui' {
			host.validate_resource(wg_arg(args, 0), 'uniform_location', true)!
			context.uniform2ui(host.uniform_locations[wg_handle(wg_arg(args, 0))] or { none }, wg_u32(wg_arg(args, 1)), wg_u32(wg_arg(args, 2)))
		}
		'uniform3ui' {
			host.validate_resource(wg_arg(args, 0), 'uniform_location', true)!
			context.uniform3ui(host.uniform_locations[wg_handle(wg_arg(args, 0))] or { none }, wg_u32(wg_arg(args, 1)), wg_u32(wg_arg(args, 2)), wg_u32(wg_arg(args, 3)))
		}
		'uniform4ui' {
			host.validate_resource(wg_arg(args, 0), 'uniform_location', true)!
			context.uniform4ui(host.uniform_locations[wg_handle(wg_arg(args, 0))] or { none }, wg_u32(wg_arg(args, 1)), wg_u32(wg_arg(args, 2)), wg_u32(wg_arg(args, 3)), wg_u32(wg_arg(args, 4)))
		}
		'uniform1uiv' {
			host.validate_resource(wg_arg(args, 0), 'uniform_location', true)!
			context.uniform1uiv(host.uniform_locations[wg_handle(wg_arg(args, 0))] or { none }, wg_array(wg_arg(args, 1)).map(wg_u32(it)))
		}
		'uniform2uiv' {
			host.validate_resource(wg_arg(args, 0), 'uniform_location', true)!
			context.uniform2uiv(host.uniform_locations[wg_handle(wg_arg(args, 0))] or { none }, wg_array(wg_arg(args, 1)).map(wg_u32(it)))
		}
		'uniform3uiv' {
			host.validate_resource(wg_arg(args, 0), 'uniform_location', true)!
			context.uniform3uiv(host.uniform_locations[wg_handle(wg_arg(args, 0))] or { none }, wg_array(wg_arg(args, 1)).map(wg_u32(it)))
		}
		'uniform4uiv' {
			host.validate_resource(wg_arg(args, 0), 'uniform_location', true)!
			context.uniform4uiv(host.uniform_locations[wg_handle(wg_arg(args, 0))] or { none }, wg_array(wg_arg(args, 1)).map(wg_u32(it)))
		}
		'uniformMatrix3x2fv' {
			host.validate_resource(wg_arg(args, 0), 'uniform_location', true)!
			context.uniform_matrix3x2fv(host.uniform_locations[wg_handle(wg_arg(args, 0))] or { none }, wg_bool(wg_arg(args, 1)), wg_array(wg_arg(args, 2)).map(f32(wg_number(it))))
		}
		'uniformMatrix4x2fv' {
			host.validate_resource(wg_arg(args, 0), 'uniform_location', true)!
			context.uniform_matrix4x2fv(host.uniform_locations[wg_handle(wg_arg(args, 0))] or { none }, wg_bool(wg_arg(args, 1)), wg_array(wg_arg(args, 2)).map(f32(wg_number(it))))
		}
		'uniformMatrix2x3fv' {
			host.validate_resource(wg_arg(args, 0), 'uniform_location', true)!
			context.uniform_matrix2x3fv(host.uniform_locations[wg_handle(wg_arg(args, 0))] or { none }, wg_bool(wg_arg(args, 1)), wg_array(wg_arg(args, 2)).map(f32(wg_number(it))))
		}
		'uniformMatrix4x3fv' {
			host.validate_resource(wg_arg(args, 0), 'uniform_location', true)!
			context.uniform_matrix4x3fv(host.uniform_locations[wg_handle(wg_arg(args, 0))] or { none }, wg_bool(wg_arg(args, 1)), wg_array(wg_arg(args, 2)).map(f32(wg_number(it))))
		}
		'uniformMatrix2x4fv' {
			host.validate_resource(wg_arg(args, 0), 'uniform_location', true)!
			context.uniform_matrix2x4fv(host.uniform_locations[wg_handle(wg_arg(args, 0))] or { none }, wg_bool(wg_arg(args, 1)), wg_array(wg_arg(args, 2)).map(f32(wg_number(it))))
		}
		'uniformMatrix3x4fv' {
			host.validate_resource(wg_arg(args, 0), 'uniform_location', true)!
			context.uniform_matrix3x4fv(host.uniform_locations[wg_handle(wg_arg(args, 0))] or { none }, wg_bool(wg_arg(args, 1)), wg_array(wg_arg(args, 2)).map(f32(wg_number(it))))
		}
		'vertexAttribI4i' {
			context.vertex_attrib_i4i(wg_u32(wg_arg(args, 0)), wg_int(wg_arg(args, 1)), wg_int(wg_arg(args, 2)), wg_int(wg_arg(args, 3)), wg_int(wg_arg(args, 4)))
		}
		'vertexAttribI4iv' {
			context.vertex_attrib_i4iv(wg_u32(wg_arg(args, 0)), wg_array(wg_arg(args, 1)).map(wg_int(it)))
		}
		'vertexAttribI4ui' {
			context.vertex_attrib_i4ui(wg_u32(wg_arg(args, 0)), wg_u32(wg_arg(args, 1)), wg_u32(wg_arg(args, 2)), wg_u32(wg_arg(args, 3)), wg_u32(wg_arg(args, 4)))
		}
		'vertexAttribI4uiv' {
			context.vertex_attrib_i4uiv(wg_u32(wg_arg(args, 0)), wg_array(wg_arg(args, 1)).map(wg_u32(it)))
		}
		'vertexAttribIPointer' {
			context.vertex_attrib_i_pointer(wg_u32(wg_arg(args, 0)), wg_int(wg_arg(args, 1)), wg_u32(wg_arg(args, 2)), wg_int(wg_arg(args, 3)), wg_i64(wg_arg(args, 4)))
		}
		'vertexAttribDivisor' {
			context.vertex_attrib_divisor(wg_u32(wg_arg(args, 0)), wg_u32(wg_arg(args, 1)))
		}
		else { return error('TypeError: unknown WebGL method ${method}') }
	}
	return json2.Any(json2.Null{})
}
