module metal

fn metal_float_bytes(values []f32) []u8 {
    return unsafe { (&u8(values.data)).vbytes(values.len * 4).clone() }
}

fn test_metal_buffer_initialization_subranges_and_closed_lifetime() {
    mut target := DrawingBuffer.create(8, 8)!
    defer { target.close() }
    mut buffer := GPUBuffer.create(target, 16)!
    assert (buffer.read(0, 16)!) == []u8{len: 16}
    buffer.write(4, [u8(1), 2, 3, 4])!
    assert (buffer.read(2, 8)!) == [u8(0), 0, 1, 2, 3, 4, 0, 0]
    mut rejected := false
    buffer.write(15, [u8(8), 9]) or { rejected = true }
    assert rejected
    assert (buffer.read(4, 4)!) == [u8(1), 2, 3, 4]
    buffer.close()
    buffer.close()
    rejected = false
    buffer.read(0, 0) or { rejected = true }
    assert rejected
}

fn test_metal_draw_essl_vertex_stream_and_padded_matrix_uniform_pixels() {
    mut target := DrawingBuffer.create(8, 8)!
    defer { target.close() }
    mut vertices := GPUBuffer.create(target, 24)!
    defer { vertices.close() }
    vertices.write(0, metal_float_bytes([f32(-1), -1, 3, -1, -1, 3]))!
    mut program := ShaderProgram.compile(target,
        'attribute vec2 position;uniform mat4 transform;void main(){gl_Position=transform*vec4(position,0.0,1.0);}',
        'precision mediump float;uniform vec3 color;uniform float alpha;void main(){gl_FragColor=vec4(color,alpha);}', 2)!
    defer { program.close() }
    program.uniform_floats('transform', [f32(1),0,0,0, 0,1,0,0, 0,0,1,0, 0,0,0,1])!
    program.uniform_floats('color', [f32(1), 0.25, 0.5])!
    program.uniform_floats('alpha', [f32(1)])!
    resources := program.resources()!
    location := int(resources.filter(it.kind == 3 && it.name == 'position')[0].location)
    streams := [VertexStream{buffer: vertices, location: location, components: 2}]
    target.draw(program, streams, .triangles, 0, 3, 1)!
    pixels := target.read_pixels()!
    for i := 0; i < pixels.len; i += 4 { assert pixels[i..i+4] == [u8(255),64,128,255] }
    mut rejected := false
    target.draw(program, streams, .triangles, 0, 4, 1) or { rejected = true }
    assert rejected
    assert (target.read_pixels()!) == pixels
}

fn test_metal_gl_coordinates_and_instanced_vertex_streams() {
    mut target := DrawingBuffer.create(8, 8)!
    defer { target.close() }
    mut vertices := GPUBuffer.create(target, 32)!
    defer { vertices.close() }
    vertices.write(0, metal_float_bytes([f32(-1),-1, 0,-1, -1,1, 0,1]))!
    mut shifts := GPUBuffer.create(target, 16)!
    defer { shifts.close() }
    shifts.write(0, metal_float_bytes([f32(0),0, 1,0]))!
    mut program := ShaderProgram.compile(target,
        'attribute vec2 position;attribute vec2 shift;void main(){gl_Position=vec4(position+shift,0.0,1.0);}',
        'precision mediump float;void main(){gl_FragColor=gl_FragCoord.y<4.0?vec4(1,0,0,1):vec4(0,0,1,1);}', 2)!
    defer { program.close() }
    resources := program.resources()!
    position := int(resources.filter(it.kind == 3 && it.name == 'position')[0].location)
    shift := int(resources.filter(it.kind == 3 && it.name == 'shift')[0].location)
    target.draw(program, [VertexStream{buffer: vertices, location: position, components: 2},
        VertexStream{buffer: shifts, location: shift, components: 2, divisor: 1}], .triangle_strip, 0, 4, 2)!
    pixels := target.read_pixels()!
    for y in 0..8 { for x in 0..8 {
        offset := (y*8+x)*4
        assert pixels[offset..offset+4] == if y<4 { [u8(255),0,0,255] } else { [u8(0),0,255,255] }
    } }
}
