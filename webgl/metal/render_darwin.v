module metal

// Slots 0..14 hold reflected uniform buffers; slots 15..30 hold vertex streams.
pub struct VertexStream {
pub:
	buffer &GPUBuffer = unsafe { nil }
	location int
	components int = 4
	offset int
	stride int
	divisor int
}

pub enum Primitive { points lines line_strip triangles triangle_strip }

pub struct TextureBinding {
pub:
	name string
	texture &Texture2D = unsafe { nil }
	array_index u32
}

pub struct DrawOptions {
pub:
	textures []TextureBinding
	color_target &Texture2D = unsafe { nil }
}

struct UniformStorage {
	stage ShaderStage
	binding u32
mut:
	buffer &GPUBuffer
}

fn (mut program ShaderProgram) initialize_uniforms() ! {
	for resource in program.resources()! {
		if resource.kind != 1 { continue }
		if resource.binding >= 15 || resource.byte_size > u64(max_int) { return error('Metal uniform block exceeds supported binding limits') }
		buffer := GPUBuffer.create(program.owner, int(resource.byte_size))!
		program.uniforms << UniformStorage{stage: resource.stage, binding: resource.binding, buffer: buffer}
	}
}

// Reflection supplies std140 offsets, including matrix-column and array padding.
// Updating a name shared by both shader stages writes both stage allocations.
pub fn (mut program ShaderProgram) uniform_floats(name string, values []f32) ! {
	resources := program.resources()!
	fields := resources.filter(it.kind == 100 && it.name == name)
	if fields.len == 0 { return error('Unknown Metal shader uniform ${name}') }
	for field in fields {
		if field.scalar_type != 13 || field.rows < 1 || field.rows > 4 || field.columns < 1 || field.columns > 4
			|| u64(values.len) != u64(field.rows) * field.columns * field.array_length {
			return error('Metal uniform type or length mismatch for ${name}')
		}
	}
	for field in fields {
		for mut storage in program.uniforms {
			if storage.stage != field.stage || storage.binding != field.binding { continue }
			for element in u32(0) .. field.array_length {
				for column in u32(0) .. field.columns {
					base := int((element * field.columns + column) * field.rows)
					bytes := unsafe { (&u8(&values[base])).vbytes(int(field.rows) * 4) }
					offset := int(field.offset) + int(element) * int(field.array_stride) + int(column) * int(field.matrix_stride)
					storage.buffer.write(offset, bytes)!
				}
			}
		}
	}
}

pub fn (mut target DrawingBuffer) draw(program &ShaderProgram, streams []VertexStream, primitive Primitive, first int, count int, instances int) ! {
	target.draw_with_options(program, streams, primitive, first, count, instances, DrawOptions{})!
}

pub fn (mut target DrawingBuffer) draw_with_options(program &ShaderProgram, streams []VertexStream, primitive Primitive, first int, count int, instances int, options DrawOptions) ! {
	if target.handle == unsafe { nil } || program.handle == unsafe { nil } || program.owner.handle != target.handle {
		return error('Metal draw requires a live program from this drawing buffer')
	}
	mut render_target := target.handle
	if options.color_target != unsafe { nil } {
		if options.color_target.handle == unsafe { nil } || options.color_target.owner.handle != target.handle { return error('Metal color target requires a live texture from this drawing buffer') }
		render_target = options.color_target.handle
	}
	if first < 0 || count < 0 || instances < 0 || u64(first) > 0xffffffff || u64(count) > 0xffffffff
		|| u64(instances) > 0xffffffff || u64(first) + u64(count) > 0xffffffff || streams.len > 16 {
		return error('Invalid Metal draw range')
	}
	mut native_streams := []C.VoxMetalVertexStream{cap: streams.len}
	mut used := u32(0)
	for stream in streams {
		if stream.buffer == unsafe { nil } || stream.buffer.handle == unsafe { nil }
			|| stream.buffer.owner.handle != target.handle || stream.location < 0 || stream.location >= 16
			|| stream.components < 1 || stream.components > 4 || stream.offset < 0 || stream.offset % 4 != 0
			|| stream.divisor < 0 || u64(stream.divisor) > 0xffffffff || stream.stride < 0 || stream.stride > 2048 || stream.stride % 4 != 0 {
			return error('Invalid Metal vertex stream')
		}
		mask := u32(1) << stream.location
		if used & mask != 0 { return error('Duplicate Metal vertex stream location') }
		used |= mask
		stride := if stream.stride == 0 { stream.components * 4 } else { stream.stride }
		if stride < stream.components * 4 { return error('Metal vertex stride is too small') }
		if stream.offset > stream.buffer.length { return error('Metal vertex offset outside buffer') }
		if count > 0 && instances > 0 {
			last := if stream.divisor > 0 { u64(instances - 1) / u64(stream.divisor) } else { u64(first) + u64(count) - 1 }
			if last * u64(stride) + u64(stream.components * 4) > u64(stream.buffer.length - stream.offset) { return error('Metal draw reads outside vertex buffer') }
		}
		native_streams << C.VoxMetalVertexStream{buffer: stream.buffer.handle, offset: u64(stream.offset), stride: u64(stride), location: u32(stream.location), components: u32(stream.components), divisor: u32(stream.divisor)}
	}
	mut textures := []C.VoxMetalTextureBinding{}
	for resource in program.resources()! {
		if resource.kind == 3 && resource.stage == .vertex && (resource.location >= 16 || used & (u32(1) << resource.location) == 0) { return error('Missing Metal vertex stream ${resource.name}') }
		if resource.kind == 11 { return error('Separate Metal sampler bindings are not supported') }
		if resource.kind !in [u32(7), 10] { continue }
		for index in u32(0) .. resource.array_length {
			bound := options.textures.filter(it.name == resource.name && it.array_index == index)
			if bound.len != 1 { return error('Missing or duplicate Metal texture binding ${resource.name}[${index}]') }
			texture := bound[0].texture
			if texture == unsafe { nil } || texture.handle == unsafe { nil } || texture.owner.handle != target.handle {
				return error('Metal texture binding requires a live texture from this drawing buffer')
			}
			if texture.handle == render_target { return error('Metal texture feedback loop') }
			if u64(resource.binding) + index >= 128 || (resource.kind == 7 && u64(resource.secondary_binding) + index >= 16) { return error('Metal texture binding exceeds device limits') }
			textures << C.VoxMetalTextureBinding{texture: texture.handle, stage: if resource.stage == .vertex { u32(0) } else { u32(1) }, binding: resource.binding + index, sampler_binding: resource.secondary_binding + index, sampled: if resource.kind == 7 { u32(1) } else { u32(0) }}
		}
	}
	if count == 0 || instances == 0 { return }
	mut bindings := []C.VoxMetalUniformBinding{cap: program.uniforms.len}
	for uniform in program.uniforms {
		bindings << C.VoxMetalUniformBinding{buffer: uniform.buffer.handle, stage: if uniform.stage == .vertex { u32(0) } else { u32(1) }, binding: uniform.binding}
	}
	mut log := []u8{len: 16384}
	if C.vox_metal_draw_textured(render_target, program.handle, native_streams.data, u32(native_streams.len), bindings.data, u32(bindings.len), textures.data, u32(textures.len), u32(primitive), u32(first), u32(count), u32(instances), &char(log.data), u64(log.len)) != 1 {
		message := unsafe { cstring_to_vstring(&char(log.data)).clone() }
		return error(if message.len > 0 { message } else { 'Metal draw failed' })
	}
}
