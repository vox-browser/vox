module metal

fn uniform_float_bytes(values []f32) []u8 { return unsafe { (&u8(values.data)).vbytes(values.len*4).clone() } }
fn uniform_assert_color(mut target DrawingBuffer, expected []u8) ! {
    pixels:=target.read_pixels()!
    for i:=0;i<pixels.len;i+=4 { assert pixels[i..i+4]==expected }
}

fn test_metal_padded_matrix_and_vector_array_uniform_roundtrip() {
    mut target:=DrawingBuffer.create(4,4)!
    defer { target.close() }
    mut program:=ShaderProgram.compile(target,
        '#version 300 es\nuniform mat3 transform;void main(){vec3 p=transform*vec3(gl_VertexID==1?3.0:-1.0,gl_VertexID==2?3.0:-1.0,1.0);gl_Position=vec4(p.xy,0.0,p.z);}',
        '#version 300 es\nprecision mediump float;uniform vec3 colors[2];out vec4 color;void main(){color=vec4(colors[0]*0.25+colors[1]*0.75,1.0);}',3)!
    defer { program.close() }
    assert (program.uniform_values('colors')!) == []u8{len:24}
    matrix:=[f32(1),0,0, 0,1,0, 0,0,1]
    colors:=[f32(1),0,0, 0,0,1]
    program.uniform_floats('transform',matrix)!
    program.uniform_floats('colors',colors)!
    assert (program.uniform_values('transform')!)==uniform_float_bytes(matrix)
    assert (program.uniform_values('colors')!)==uniform_float_bytes(colors)
    target.draw(program,[],.triangles,0,3,1)!
    uniform_assert_color(mut target,[u8(64),0,191,255])!
}

fn test_metal_signed_unsigned_and_boolean_uniforms_use_32_bit_storage() {
    mut target:=DrawingBuffer.create(4,4)!
    defer { target.close() }
    mut program:=ShaderProgram.compile(target,
        '#version 300 es\nvoid main(){gl_Position=vec4(gl_VertexID==1?3.0:-1.0,gl_VertexID==2?3.0:-1.0,0.0,1.0);}',
        '#version 300 es\nprecision mediump float;uniform ivec2 signed_values;uniform uvec2 unsigned_values;uniform bool enabled;out vec4 color;void main(){color=vec4(enabled?float(signed_values.x+int(unsigned_values.y))/255.0:0.0,0.0,0.0,1.0);}',3)!
    defer { program.close() }
    signed:=[i32(-1),9]
    unsigned:=[u32(7),256]
    program.uniform_ints('signed_values',signed)!
    program.uniform_uints('unsigned_values',unsigned)!
    program.uniform_bools('enabled',[true])!
    assert (program.uniform_values('signed_values')!)==unsafe { (&u8(signed.data)).vbytes(signed.len*4).clone() }
    target.draw(program,[],.triangles,0,3,1)!
    uniform_assert_color(mut target,[u8(255),0,0,255])!
    program.uniform_bools('enabled',[false])!
    target.draw(program,[],.triangles,0,3,1)!
    uniform_assert_color(mut target,[u8(0),0,0,255])!
    mut rejected:=false
    program.uniform_floats('signed_values',[f32(1),2]) or { rejected=true }
    assert rejected
    assert (program.uniform_values('signed_values')!)==unsafe { (&u8(signed.data)).vbytes(signed.len*4).clone() }
}

fn test_metal_external_uniform_buffer_ranges_and_internal_block_writes() {
    mut target:=DrawingBuffer.create(4,4)!
    defer { target.close() }
    mut program:=ShaderProgram.compile(target,
        '#version 300 es\nvoid main(){gl_Position=vec4(gl_VertexID==1?3.0:-1.0,gl_VertexID==2?3.0:-1.0,0.0,1.0);}',
        '#version 300 es\nprecision mediump float;layout(std140) uniform Tint {vec4 tint;};out vec4 color;void main(){color=tint;}',3)!
    defer { program.close() }
    block:=(program.resources()!).filter(it.kind==1 && it.stage==.fragment)[0]
    mut buffer:=GPUBuffer.create(target,272)!
    defer { buffer.close() }
    buffer.write(256,uniform_float_bytes([f32(0.25),0.5,1,1]))!
    options:=DrawOptions{uniform_blocks:[UniformBlockBinding{stage:.fragment,binding:block.binding,buffer:buffer,offset:256,length:16}]}
    target.draw_with_options(program,[],.triangles,0,3,1,options)!
    uniform_assert_color(mut target,[u8(64),128,255,255])!
    mut rejected:=false
    target.draw_with_options(program,[],.triangles,0,3,1,DrawOptions{uniform_blocks:[UniformBlockBinding{stage:.fragment,binding:block.binding,buffer:buffer,offset:257}]}) or { rejected=true }
    assert rejected
    program.uniform_block_bytes(.fragment,block.binding,0,uniform_float_bytes([f32(1),0,0,1]))!
    target.draw(program,[],.triangles,0,3,1)!
    uniform_assert_color(mut target,[u8(255),0,0,255])!
}
