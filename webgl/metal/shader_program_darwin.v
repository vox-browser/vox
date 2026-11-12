module metal

pub enum ShaderStage { vertex fragment }

pub struct ShaderResource {
pub:
	name string
	stage ShaderStage
	kind u32
	location u32
	binding u32
	secondary_binding u32
	offset u32
	array_stride u32
	matrix_stride u32
	scalar_type u32
	rows u32
	columns u32
	array_length u32
	byte_size u64
}

@[heap]
pub struct ShaderProgram {
mut:
	handle voidptr
	owner &DrawingBuffer
	uniforms []UniformStorage
}

// context_version is the GLES context version: 2 for WebGL1, 3 for WebGL2.
// The two original ESSL stages are linked before their independent MSL lowering.
pub fn ShaderProgram.compile(owner &DrawingBuffer, vertex string, fragment string, context_version int) !&ShaderProgram {
	return ShaderProgram.compile_with_bindings(owner,vertex,fragment,context_version,map[string]int{})
}

pub fn ShaderProgram.compile_with_bindings(owner &DrawingBuffer, vertex string, fragment string, context_version int, attribute_bindings map[string]int) !&ShaderProgram {
	if owner.handle == unsafe { nil } { return error('Metal drawing buffer is closed') }
	if context_version !in [2, 3] { return error('Invalid Metal WebGL context version') }
	if vertex.len > 0x7fffffff || fragment.len > 0x7fffffff { return error('Shader source too large') }
	mut log := []u8{len: 16384}
	mut bindings := []C.VoxMetalAttributeBinding{cap:attribute_bindings.len}
	for name,location in attribute_bindings {
		if location < 0 || location >= 16 || name.starts_with('gl_') { return error('Invalid Metal attribute binding') }
		bindings << C.VoxMetalAttributeBinding{name:name.str,location:u32(location)}
	}
	handle := C.vox_metal_program_create_bound(owner.handle, vertex.str, i32(vertex.len), fragment.str,
		i32(fragment.len), i32(context_version), bindings.data, u64(bindings.len), &char(log.data), u64(log.len))
	if handle == unsafe { nil } {
		message := unsafe { cstring_to_vstring(&char(log.data)).clone() }
		return error(if message.len > 0 { message } else { 'Metal shader allocation failed' })
	}
	mut program := &ShaderProgram{handle: handle, owner: owner}
	program.initialize_uniforms() or {
		program.close()
		return err
	}
	return program
}

pub fn (program &ShaderProgram) source(stage ShaderStage) !string {
	if program.handle == unsafe { nil } { return error('Metal shader program is closed') }
	value := C.vox_metal_program_source(program.handle, if stage == .vertex { i32(0) } else { i32(1) })
	if value == unsafe { nil } { return error('Metal shader source unavailable') }
	return unsafe { cstring_to_vstring(value).clone() }
}

pub fn (program &ShaderProgram) resources() ![]ShaderResource {
	if program.handle == unsafe { nil } { return error('Metal shader program is closed') }
	count := C.vox_metal_program_resource_count(program.handle)
	if count > u64(max_int) { return error('Metal shader reflection too large') }
	mut result := []ShaderResource{cap: int(count)}
	for index in u64(0) .. count {
		mut value := C.VoxMetalShaderResource{}
		if C.vox_metal_program_resource(program.handle, index, &value) != 1 { return error('Metal shader reflection unavailable') }
		result << ShaderResource{
			name: unsafe { cstring_to_vstring(value.name).clone() }
			stage: if value.stage == 0 { .vertex } else { .fragment }
			kind: value.kind
			location: value.location
			binding: value.binding
			secondary_binding: value.secondary_binding
			offset: value.offset
			array_stride: value.array_stride
			matrix_stride: value.matrix_stride
			scalar_type: value.base_type
			rows: value.rows
			columns: value.columns
			array_length: value.array_length
			byte_size: value.byte_size
		}
	}
	return result
}

pub fn (mut program ShaderProgram) close() {
	for mut uniform in program.uniforms {
		uniform.buffer.close()
		unsafe { free(uniform.buffer) }
	}
	unsafe { program.uniforms.free() }
	C.vox_metal_program_destroy(program.handle)
	program.handle = unsafe { nil }
}
