module webgl

fn shader_limits_program(mut context WebGLRenderingContext, source string) &WebGLProgram {
 mut vertex:=context.create_shader(vertex_shader) or {panic('vertex')}
 mut fragment:=context.create_shader(fragment_shader) or {panic('fragment')}
 context.shader_source(mut vertex,'#version 300 es\nvoid main(){gl_Position=vec4(gl_VertexID==1?3.0:-1.0,gl_VertexID==2?3.0:-1.0,0,1);}')
 context.shader_source(mut fragment,source)
 context.compile_shader(mut vertex);context.compile_shader(mut fragment)
 assert context.get_shader_parameter(vertex,compile_status).boolean,context.get_shader_info_log(vertex) or {''}
 assert context.get_shader_parameter(fragment,compile_status).boolean,context.get_shader_info_log(fragment) or {''}
 mut program:=context.create_program()
 context.attach_shader(mut program,vertex);context.attach_shader(mut program,fragment);context.link_program(mut program)
 assert context.get_program_parameter(program,link_status).boolean,context.get_program_info_log(program) or {''}
 context.use_program(program)
 return program
}

fn test_service_sampler_array_locations_and_units_reach_distinct_gpu_images() {
 mut context:=WebGLRenderingContext.new(.webgl2,WebGLContextAttributes{},[])
 defer {context.native.set_lost()}
 context.set_size(1,1)
 mut program:=shader_limits_program(mut context,'#version 300 es\nprecision highp float;uniform sampler2D images[2];out vec4 color;void main(){color=texture(images[1],vec2(0.5));}')
 location:=context.get_uniform_location(mut program,'images') or {panic('sampler array')}
 context.uniform1iv(location,[0,1])
 for i in 0..2 {
  context.active_texture(u32(0x84c0+i))
  texture:=context.create_texture();context.bind_texture(texture_2d,texture)
  context.tex_parameteri(texture_2d,texture_min_filter,0x2600)
  context.tex_parameteri(texture_2d,texture_mag_filter,0x2600)
  context.tex_image2d(texture_2d,0,int(rgba),1,1,0,rgba,unsigned_byte,if i==0 {[u8(255),0,0,255]} else {[u8(0),255,0,255]})
 }
 context.draw_arrays(4,0,3)
 assert context.get_error()==no_error,metal_service_current().last_failure
 assert context.read_pixels(0,0,1,1,rgba,unsigned_byte)==[u8(0),255,0,255]
}

fn test_service_row_major_block_array_queries_and_bindings_reach_gpu() {
 mut context:=WebGLRenderingContext.new(.webgl2,WebGLContextAttributes{},[])
 defer {context.native.set_lost()}
 context.set_size(1,1)
 program:=shader_limits_program(mut context,'#version 300 es\nprecision highp float;layout(row_major,std140) uniform State{mat2x3 basis;vec4 tint;} data[2];out vec4 color;void main(){color=data[1].basis[1][2]==6.0?data[0].tint:vec4(0,1,0,1);}')
 indices:=context.get_uniform_indices(program,['State[0].basis','State[0].tint','State[1].basis'])
 assert indices.all(it!=~u32(0))
 assert context.get_active_uniforms(program,indices,uniform_is_row_major).booleans==[true,false,true]
 assert context.get_active_uniforms(program,indices,uniform_offset).integers==[i64(0),48,0]
 for i in 0..2 {
  block:=context.get_uniform_block_index(program,'State[${i}]')
  assert block!=~u32(0)
  context.uniform_block_binding(program,block,u32(i))
 }
 buffer:=context.create_buffer();context.bind_buffer(uniform_buffer,buffer)
 context.buffer_data_size(uniform_buffer,512,0x88e8)
 mut first:=[]f32{len:16};first[12]=1;first[15]=1
 second:=[f32(1),2,0,0,3,4,0,0,5,6,0,0,0,1,0,1]
 context.buffer_sub_data(uniform_buffer,0,unsafe{(&u8(first.data)).vbytes(64).clone()})
 context.buffer_sub_data(uniform_buffer,256,unsafe{(&u8(second.data)).vbytes(64).clone()})
 context.bind_buffer_range(uniform_buffer,0,buffer,0,64)
 context.bind_buffer_range(uniform_buffer,1,buffer,256,64)
 context.draw_arrays(4,0,3)
 assert context.get_error()==no_error,metal_service_current().last_failure
 assert context.read_pixels(0,0,1,1,rgba,unsigned_byte)==[u8(255),0,0,255]
}
