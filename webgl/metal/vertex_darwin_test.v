module metal

fn vertex_bytes(values []f32) []u8 { return unsafe { (&u8(values.data)).vbytes(values.len*4).clone() } }
fn vertex_assert_color(mut target DrawingBuffer, expected []u8) ! {
    pixels:=target.read_pixels()!
    for i:=0;i<pixels.len;i+=4 { assert pixels[i..i+4]==expected }
}

fn test_metal_normalized_byte_stream_with_unaligned_buffer_base_and_constant_attribute() {
    mut target:=DrawingBuffer.create(4,4)!
    defer { target.close() }
    mut program:=ShaderProgram.compile(target,
        '#version 300 es\nin vec4 shade;out vec4 value;void main(){value=shade;gl_Position=vec4(gl_VertexID==1?3.0:-1.0,gl_VertexID==2?3.0:-1.0,0.0,1.0);}',
        '#version 300 es\nprecision mediump float;in vec4 value;out vec4 color;void main(){color=value;}',3)!
    defer { program.close() }
    location:=int((program.resources()!).filter(it.kind==3 && it.name=='shade')[0].location)
    mut bytes:=GPUBuffer.create(target,5)!
    defer { bytes.close() }
    bytes.write(0,[u8(0),255,64,128,255])!
    target.draw(program,[VertexStream{buffer:bytes,location:location,components:4,format:.uint8,offset:1,normalized:true,constant:true}],.triangles,0,3,1)!
    vertex_assert_color(mut target,[u8(255),64,128,255])!
    mut color:=GPUBuffer.create(target,16)!
    defer { color.close() }
    color.write(0,vertex_bytes([f32(0),1,0,1]))!
    target.draw(program,[VertexStream{buffer:color,location:location,components:4,constant:true}],.triangles,0,3,1)!
    vertex_assert_color(mut target,[u8(0),255,0,255])!
}

fn test_metal_integer_vertex_fetch_and_type_rejection() {
    mut target:=DrawingBuffer.create(4,4)!
    defer { target.close() }
    mut program:=ShaderProgram.compile(target,
        '#version 300 es\nin uvec4 shade;flat out uvec4 value;void main(){value=shade;gl_Position=vec4(gl_VertexID==1?3.0:-1.0,gl_VertexID==2?3.0:-1.0,0.0,1.0);}',
        '#version 300 es\nprecision mediump float;flat in uvec4 value;out vec4 color;void main(){color=vec4(value)/255.0;}',3)!
    defer { program.close() }
    location:=int((program.resources()!).filter(it.kind==3 && it.name=='shade')[0].location)
    mut bytes:=GPUBuffer.create(target,4)!
    defer { bytes.close() }
    bytes.write(0,[u8(255),64,128,255])!
    target.draw(program,[VertexStream{buffer:bytes,location:location,components:4,format:.uint8,integer:true,constant:true}],.triangles,0,3,1)!
    vertex_assert_color(mut target,[u8(255),64,128,255])!
    mut rejected:=false
    target.draw(program,[VertexStream{buffer:bytes,location:location,components:4,format:.uint8,constant:true}],.triangles,0,3,1) or { rejected=true }
    assert rejected
}

fn test_metal_half_vertices_and_missing_vec4_components_default_to_zero_one() {
    mut target:=DrawingBuffer.create(4,4)!
    defer { target.close() }
    mut program:=ShaderProgram.compile(target,
        '#version 300 es\nin vec4 position;void main(){gl_Position=position;}',
        '#version 300 es\nprecision mediump float;out vec4 color;void main(){color=vec4(1,0,0,1);}',3)!
    defer { program.close() }
    location:=int((program.resources()!).filter(it.kind==3 && it.name=='position')[0].location)
    mut vertices:=GPUBuffer.create(target,12)!
    defer { vertices.close() }
    vertices.write(0,[u8(0),188,0,188, 0,66,0,188, 0,188,0,66])!
    target.draw(program,[VertexStream{buffer:vertices,location:location,components:2,format:.float16}],.triangles,0,3,1)!
    vertex_assert_color(mut target,[u8(255),0,0,255])!
}
