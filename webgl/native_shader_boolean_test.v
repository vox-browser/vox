module webgl

fn test_boolean_uniforms_keep_gl_types_and_normalize_signed_and_float_uploads() {
    mut context:=WebGLRenderingContext.new(.webgl2,WebGLContextAttributes{},[])
    context.set_size(1,1)
    mut vertex:=context.create_shader(vertex_shader) or { panic('vertex') }
    mut fragment:=context.create_shader(fragment_shader) or { panic('fragment') }
    context.shader_source(mut vertex,'#version 300 es\nuniform highp uint raw;void main(){gl_Position=vec4(gl_VertexID==1?3.0:-1.0,gl_VertexID==2?3.0:-1.0,0,1);gl_Position.x+=float(raw)*0.0001;}')
    context.shader_source(mut fragment,'#version 300 es\nprecision highp float;\n#define FLAG bool\nuniform FLAG enabled;uniform bvec3 channels;uniform highp uint raw;out vec4 color;void main(){bool raw=false;color=enabled?vec4(vec3(channels),1):vec4(0);}')
    // raw is inactive here; a local bool must not affect an active uint in a
    // different scope or stage with the same spelling.
    context.compile_shader(mut vertex);context.compile_shader(mut fragment)
    mut program:=context.create_program();context.attach_shader(mut program,vertex);context.attach_shader(mut program,fragment);context.link_program(mut program)
    assert context.get_program_parameter(program,link_status).boolean,context.get_program_info_log(program) or { '' }
    context.use_program(program)
    mut reflected:=map[string]u32{}
    for index in 0..int(context.get_program_parameter(program,active_uniforms).integer) {
        info:=context.get_active_uniform(program,u32(index)) or { panic('uniform') };reflected[info.name()]=info.type_()
    }
    assert reflected['enabled']==0x8b56
    assert reflected['channels']==0x8b58
    assert reflected['raw']==unsigned_int
    enabled:=context.get_uniform_location(mut program,'enabled') or { panic('enabled') }
    channels:=context.get_uniform_location(mut program,'channels') or { panic('channels') }
    context.uniform1i(enabled,-7);context.uniform3fv(channels,[f32(0),-2,3])
    assert context.get_error()==no_error
    mut actual:=[i32(0),0,0]!
    C.vox_gl_get_uniform_ints(program.object.native_handle_,i32(channels.handle_),&actual[0])
    assert actual==[i32(0),1,1]!
    context.draw_arrays(4,0,3)
    assert context.read_pixels(0,0,1,1,rgba,unsigned_byte)==[u8(0),255,255,255]
    assert context.get_error()==no_error
}

fn test_boolean_uniform_block_members_preserve_semantic_types_after_storage_lowering() {
    mut context:=WebGLRenderingContext.new(.webgl2,WebGLContextAttributes{},[])
    mut vertex:=context.create_shader(vertex_shader) or { panic('vertex') }
    mut fragment:=context.create_shader(fragment_shader) or { panic('fragment') }
    context.shader_source(mut vertex,'#version 300 es\nlayout(std140) uniform Flags {bool visible;bvec2 flags;highp uint raw;};void main(){gl_Position=vec4(visible?1:0,vec2(flags),float(raw));}')
    context.shader_source(mut fragment,'#version 300 es\nprecision highp float;out vec4 color;void main(){color=vec4(1);}')
    context.compile_shader(mut vertex);context.compile_shader(mut fragment)
    mut program:=context.create_program();context.attach_shader(mut program,vertex);context.attach_shader(mut program,fragment);context.link_program(mut program)
    assert context.get_program_parameter(program,link_status).boolean
    indices:=context.get_uniform_indices_nullable(program,['visible','flags','raw']) or { panic('indices') }
    assert context.get_active_uniforms(program,indices,uniform_type).integers==[i64(0x8b56),0x8b57,0x1405]
    assert context.get_error()==no_error
}
