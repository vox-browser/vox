module metal

fn texture_float_bytes(values []f32) []u8 {
    return unsafe { (&u8(values.data)).vbytes(values.len * 4).clone() }
}

fn test_metal_sampler_texture_quadrants_filtering_wrap_and_ownership() {
    mut target := DrawingBuffer.create(8, 8)!
    defer { target.close() }
    mut vertices := GPUBuffer.create(target, 24)!
    defer { vertices.close() }
    vertices.write(0, texture_float_bytes([f32(-1),-1, 3,-1, -1,3]))!
    mut texture := Texture2D.create(target, 2, 2)!
    defer { texture.close() }
    assert (texture.read_pixels()!) == []u8{len: 16}
    mut program := ShaderProgram.compile(target,
        'attribute vec2 position;varying vec2 uv;void main(){gl_Position=vec4(position,0.0,1.0);uv=(position+1.0)*0.5;}',
        'precision mediump float;varying vec2 uv;uniform sampler2D texture;uniform float scale;void main(){gl_FragColor=texture2D(texture,uv*scale);}', 2)!
    defer { program.close() }
    program.uniform_floats('scale', [f32(1)])!
    resources := program.resources()!
    location := int(resources.filter(it.kind == 3 && it.name == 'position')[0].location)
    streams := [VertexStream{buffer: vertices, location: location, components: 2}]
    options := DrawOptions{textures: [TextureBinding{name: 'texture', texture: texture}]}
    target.draw_with_options(program, streams, .triangles, 0, 3, 1, options)!
    assert (target.read_pixels()!) == []u8{len: 256}
    colors := [[u8(255),0,0,255], [u8(0),255,0,255], [u8(0),0,255,255], [u8(255),255,0,255]]
    mut upload := []u8{}
    for color in colors { upload << color }
    texture.write_pixels(upload)!
    target.draw_with_options(program, streams, .triangles, 0, 3, 1, options)!
    pixels := target.read_pixels()!
    for y in 0..8 { for x in 0..8 {
        offset := (y*8+x)*4
        assert pixels[offset..offset+4] == colors[(y/4)*2+x/4]
    } }
    texture.sampler(SamplerOptions{wrap_s: .repeat, wrap_t: .repeat})!
    program.uniform_floats('scale', [f32(2)])!
    target.draw_with_options(program, streams, .triangles, 0, 3, 1, options)!
    repeated := target.read_pixels()!
    for y in 0..8 { for x in 0..8 {
        offset := (y*8+x)*4
        assert repeated[offset..offset+4] == colors[((y%4)/2)*2+(x%4)/2]
    } }
    mut other := DrawingBuffer.create(8, 8)!
    defer { other.close() }
    mut foreign := Texture2D.create(other, 2, 2)!
    defer { foreign.close() }
    mut rejected := false
    target.draw_with_options(program, streams, .triangles, 0, 3, 1,
        DrawOptions{textures: [TextureBinding{name: 'texture', texture: foreign}]}) or { rejected = true }
    assert rejected
    assert (target.read_pixels()!) == repeated
    rejected = false
    target.draw(program, streams, .triangles, 0, 3, 1) or { rejected = true }
    assert rejected
}

fn test_metal_linear_sampler_interpolates_four_rgba_texels() {
    mut target := DrawingBuffer.create(2, 2)!
    defer { target.close() }
    mut texture := Texture2D.create(target, 2, 2)!
    defer { texture.close() }
    texture.write_pixels([u8(255),0,0,255, 0,255,0,255, 0,0,255,255, 255,255,0,255])!
    texture.sampler(SamplerOptions{min_filter: .linear, mag_filter: .linear})!
    mut program := ShaderProgram.compile(target,
        '#version 300 es\nvoid main(){gl_Position=vec4(gl_VertexID==1?3.0:-1.0,gl_VertexID==2?3.0:-1.0,0.0,1.0);}',
        '#version 300 es\nprecision mediump float;uniform sampler2D image;out vec4 color;void main(){color=texture(image,vec2(0.5));}', 3)!
    defer { program.close() }
    target.draw_with_options(program, [], .triangles, 0, 3, 1,
        DrawOptions{textures: [TextureBinding{name: 'image', texture: texture}]})!
    pixels := target.read_pixels()!
    for i := 0; i < pixels.len; i += 4 { assert pixels[i..i+4] == [u8(128),128,64,255] }
}

fn test_metal_offscreen_color_target_and_feedback_rejection() {
    mut target := DrawingBuffer.create(2, 2)!
    defer { target.close() }
    mut texture := Texture2D.create(target, 2, 2)!
    defer { texture.close() }
    vertex := '#version 300 es\nvoid main(){gl_Position=vec4(gl_VertexID==1?3.0:-1.0,gl_VertexID==2?3.0:-1.0,0.0,1.0);}'
    mut color := ShaderProgram.compile(target, vertex,
        '#version 300 es\nprecision mediump float;out vec4 color;void main(){color=vec4(0.25,0.5,1.0,1.0);}', 3)!
    defer { color.close() }
    target.draw_with_options(color, [], .triangles, 0, 3, 1, DrawOptions{color_target: texture})!
    assert (target.read_pixels()!) == []u8{len: 16}
    expected := [u8(64),128,255,255, 64,128,255,255, 64,128,255,255, 64,128,255,255]
    assert (texture.read_pixels()!) == expected
    mut sampler := ShaderProgram.compile(target, vertex,
        '#version 300 es\nprecision mediump float;uniform sampler2D image;out vec4 color;void main(){color=texture(image,vec2(0.5));}', 3)!
    defer { sampler.close() }
    options := DrawOptions{textures: [TextureBinding{name: 'image', texture: texture}]}
    target.draw_with_options(sampler, [], .triangles, 0, 3, 1, options)!
    assert (target.read_pixels()!) == expected
    mut rejected := false
    target.draw_with_options(sampler, [], .triangles, 0, 3, 1,
        DrawOptions{color_target: texture, textures: options.textures}) or { rejected = true }
    assert rejected
    assert (texture.read_pixels()!) == expected
}
