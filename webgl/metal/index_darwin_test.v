module metal

fn index_float_bytes(values []f32) []u8 { return unsafe { (&u8(values.data)).vbytes(values.len*4).clone() } }

fn index_program(target &DrawingBuffer) !&ShaderProgram {
    return ShaderProgram.compile(target,
        'attribute vec2 position;void main(){gl_Position=vec4(position,0.0,1.0);}',
        'precision mediump float;void main(){gl_FragColor=vec4(0.25,0.5,1.0,1.0);}',2)
}

fn index_assert_pixels(mut target DrawingBuffer) ! {
    pixels:=target.read_pixels()!
    for i:=0;i<pixels.len;i+=4 { assert pixels[i..i+4]==[u8(64),128,255,255] }
}

fn test_metal_byte_indexed_quad_and_actual_vertex_range_validation() {
    mut target:=DrawingBuffer.create(8,8)!
    defer { target.close() }
    mut program:=index_program(target)!
    defer { program.close() }
    mut vertices:=GPUBuffer.create(target,32)!
    defer { vertices.close() }
    vertices.write(0,index_float_bytes([f32(-1),-1, 1,-1, -1,1, 1,1]))!
    mut indices:=GPUBuffer.create(target,6)!
    defer { indices.close() }
    indices.write(0,[u8(0),1,2,2,1,3])!
    location:=int((program.resources()!).filter(it.kind==3 && it.name=='position')[0].location)
    streams:=[VertexStream{buffer:vertices,location:location,components:2}]
    options:=DrawOptions{indices:IndexBinding{buffer:indices,format:.u8}}
    target.draw_with_options(program,streams,.triangles,0,6,1,options)!
    index_assert_pixels(mut target)!
    mut rejected:=false
    target.draw_with_options(program,streams,.triangles,0,7,1,options) or { rejected=true }
    assert rejected
    indices.write(5,[u8(4)])!
    rejected=false
    target.draw_with_options(program,streams,.triangles,0,6,1,options) or { rejected=true }
    assert rejected
    index_assert_pixels(mut target)!
}

fn test_metal_webgl1_ushort_maximum_is_a_vertex_and_not_restart() {
    mut target:=DrawingBuffer.create(8,8)!
    defer { target.close() }
    mut program:=index_program(target)!
    defer { program.close() }
    mut vertices:=GPUBuffer.create(target,65536*8)!
    defer { vertices.close() }
    vertices.write(65533*8,index_float_bytes([f32(-1),-1, 3,-1, -1,3]))!
    mut indices:=GPUBuffer.create(target,6)!
    defer { indices.close() }
    indices.write(0,[u8(253),255,254,255,255,255])!
    location:=int((program.resources()!).filter(it.kind==3 && it.name=='position')[0].location)
    target.draw_with_options(program,[VertexStream{buffer:vertices,location:location,components:2}],.triangles,0,3,1,
        DrawOptions{indices:IndexBinding{buffer:indices,format:.u16}})!
    index_assert_pixels(mut target)!
}

fn test_metal_webgl2_fixed_restart_in_byte_and_ushort_triangle_strips() {
    mut target:=DrawingBuffer.create(8,8)!
    defer { target.close() }
    mut program:=index_program(target)!
    defer { program.close() }
    mut vertices:=GPUBuffer.create(target,32)!
    defer { vertices.close() }
    vertices.write(0,index_float_bytes([f32(-1),-1,1,-1,-1,1,1,1]))!
    location:=int((program.resources()!).filter(it.kind==3 && it.name=='position')[0].location)
    for format in [IndexFormat.u8,.u16] {
        bytes:=if format==.u8 { [u8(0),1,2,255,2,1,3] } else { [u8(0),0,1,0,2,0,255,255,2,0,1,0,3,0] }
        mut indices:=GPUBuffer.create(target,bytes.len)!
        indices.write(0,bytes)!
        target.clear(0,0,0,0)!
        target.draw_with_options(program,[VertexStream{buffer:vertices,location:location,components:2}],.triangle_strip,0,7,1,
            DrawOptions{indices:IndexBinding{buffer:indices,format:format,restart:true}})!
        index_assert_pixels(mut target)!
        indices.close()
    }
}
