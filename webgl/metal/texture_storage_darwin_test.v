module metal

fn storage_draw_sample(mut target DrawingBuffer,texture &Texture2D,fragment string) ! {
    mut program:=ShaderProgram.compile(target,
        '#version 300 es\nvoid main(){gl_Position=vec4(gl_VertexID==1?3.0:-1.0,gl_VertexID==2?3.0:-1.0,0.0,1.0);}',fragment,3)!
    defer { program.close() }
    target.draw_with_options(program,[],.triangles,0,3,1,DrawOptions{textures:[TextureBinding{name:'image',texture:texture}]})!
}

fn test_metal_volume_array_and_cube_storage_preserve_regions_and_sampler_dimensions() {
    mut target:=DrawingBuffer.create(1,1)!
    defer { target.close() }
    mut volume:=Texture2D.create_storage(target,TextureStorageOptions{width:2,height:2,depth:2,kind:.volume_3d})!
    defer { volume.close() }
    region:=TextureRegion{width:2,height:2,depth:2}
    assert (volume.read_region(0,0,region)!)==[]u8{len:32}
    mut bytes:=[]u8{}
    for _ in 0..4 { bytes<<[u8(255),0,0,255] }
    for _ in 0..4 { bytes<<[u8(0),255,0,255] }
    volume.write_region(0,0,region,bytes)!
    storage_draw_sample(mut target,volume,'#version 300 es\nprecision highp float;precision highp sampler3D;uniform sampler3D image;out vec4 color;void main(){color=texture(image,vec3(0.5,0.5,0.75));}')!
    assert (target.read_pixels()!)==[u8(0),255,0,255]
    mut array:=Texture2D.create_storage(target,TextureStorageOptions{width:1,height:1,depth:2,kind:.array_2d})!
    defer { array.close() }
    array.write_region(0,1,TextureRegion{width:1,height:1},[u8(0),0,255,255])!
    storage_draw_sample(mut target,array,'#version 300 es\nprecision highp float;precision highp sampler2DArray;uniform sampler2DArray image;out vec4 color;void main(){color=texture(image,vec3(0.5,0.5,1.0));}')!
    assert (target.read_pixels()!)==[u8(0),0,255,255]
    assert (array.read_region(0,0,TextureRegion{width:1,height:1})!)==[u8(0),0,0,0]
    mut cube:=Texture2D.create_storage(target,TextureStorageOptions{width:2,height:2,levels:2,kind:.cube})!
    defer { cube.close() }
    cube.write_region(0,0,TextureRegion{width:2,height:2},bytes[..16])!
    cube.generate_mipmaps()!
    assert (cube.read_region(1,0,TextureRegion{width:1,height:1})!)==[u8(255),0,0,255]
    storage_draw_sample(mut target,cube,'#version 300 es\nprecision highp float;uniform samplerCube image;out vec4 color;void main(){color=texture(image,vec3(1.0,0.0,0.0));}')!
    assert (target.read_pixels()!)==[u8(255),0,0,255]
}

fn test_metal_attachment_views_render_to_selected_mip_array_and_volume_slices() {
    mut target:=DrawingBuffer.create(2,2)!
    defer { target.close() }
    mut program:=ShaderProgram.compile(target,'#version 300 es\nvoid main(){gl_Position=vec4(gl_VertexID==1?3.0:-1.0,gl_VertexID==2?3.0:-1.0,0,1);}',
        '#version 300 es\nprecision highp float;out vec4 color;void main(){color=vec4(1,0,1,1);}',3)!
    defer { program.close() }
    for kind in [TextureKind.volume_3d,.array_2d,.cube] {
        mut texture:=Texture2D.create_storage(target,TextureStorageOptions{width:2,height:2,depth:if kind==.cube { 1 } else { 2 },kind:kind,levels:2})!
        defer { texture.close() }
        mut view:=texture.attachment(0,1)!
        defer { view.close() }
        target.draw_with_options(program,[],.triangles,0,3,1,DrawOptions{color_target:view})!
        expected:=[u8(255),0,255,255,255,0,255,255,255,0,255,255,255,0,255,255]
        actual:=texture.read_region(0,if kind==.volume_3d { 0 } else { 1 },TextureRegion{z:if kind==.volume_3d { 1 } else { 0 },width:2,height:2})!
        assert actual==expected
        assert (texture.read_region(0,0,TextureRegion{width:2,height:2})!)==[]u8{len:16}
        mut mip:=texture.attachment(1,0)!
        defer { mip.close() }
        target.draw_with_options(program,[],.triangles,0,3,1,DrawOptions{color_target:mip})!
        assert (mip.read_pixels()!)==[u8(255),0,255,255]
    }
}

fn test_metal_integer_and_float_texture_storage_preserves_physical_values() {
    mut target:=DrawingBuffer.create(1,1)!
    defer { target.close() }
    mut integers:=Texture2D.create_storage(target,TextureStorageOptions{width:1,height:1,format:.rgba32i})!
    defer { integers.close() }
    signed:=[i32(-2_000_000_001),2_000_000_001,-7,9]
    bytes:=unsafe { (&u8(signed.data)).vbytes(16) }
    integers.write_region(0,0,TextureRegion{width:1,height:1},bytes)!
    assert (integers.read_region(0,0,TextureRegion{width:1,height:1})!)==bytes
    storage_draw_sample(mut target,integers,'#version 300 es\nprecision highp float;precision highp isampler2D;uniform isampler2D image;out vec4 color;void main(){ivec4 value=texture(image,vec2(0.5));color=all(equal(value,ivec4(-2000000001,2000000001,-7,9)))?vec4(1,0,0,1):vec4(0,1,0,1);}')!
    assert (target.read_pixels()!)==[u8(255),0,0,255]
    mut floats:=Texture2D.create_storage(target,TextureStorageOptions{width:1,height:1,format:.rgba32f})!
    defer { floats.close() }
    values:=[f32(0.25),0.5,0.75,1]
    floats.write_region(0,0,TextureRegion{width:1,height:1},unsafe { (&u8(values.data)).vbytes(16) })!
    storage_draw_sample(mut target,floats,'#version 300 es\nprecision highp float;uniform sampler2D image;out vec4 color;void main(){color=texture(image,vec2(0.5));}')!
    assert (target.read_pixels()!)==[u8(64),128,191,255]
}

fn test_metal_depth_storage_initialization_and_real_sample_count_allocations() {
    mut target:=DrawingBuffer.create(2,2)!
    defer { target.close() }
    for format in [TextureFormat.depth16,.depth32,.depth_stencil,.stencil8] {
        mut texture:=Texture2D.create_storage(target,TextureStorageOptions{width:2,height:2,format:format})!
        texture.close()
    }
    for samples in target.sample_counts() {
        mut texture:=Texture2D.create_storage(target,TextureStorageOptions{width:2,height:2,samples:samples})!
        texture.close()
    }
}

fn test_metal_combined_depth_stencil_transfers_preserve_each_aspect() {
    mut target:=DrawingBuffer.create(2,2)!
    defer { target.close() }
    mut texture:=Texture2D.create_storage(target,TextureStorageOptions{width:2,height:2,format:.depth_stencil})!
    defer { texture.close() }
    region:=TextureRegion{width:2,height:2}
    assert (texture.read_region(0,0,region)!)==[]u8{len:32}
    values:=[u32(0x3f000000),17,0x3f800000,255,0x00000000,0,0x3e800000,37]
    bytes:=unsafe { (&u8(values.data)).vbytes(32) }
    texture.write_region(0,0,region,bytes)!
    assert (texture.read_region(0,0,region)!)==bytes
}

fn test_metal_multisample_color_depth_and_stencil_resolve_completed_gpu_results() {
    mut target:=DrawingBuffer.create(2,2)!
    defer { target.close() }
    mut samples:=1
    for count in target.sample_counts() { if count>1 { samples=count;break } }
    assert samples>1
    mut color:=Texture2D.create_storage(target,TextureStorageOptions{width:2,height:2,samples:samples})!
    defer { color.close() }
    mut depth_texture:=Texture2D.create_storage(target,TextureStorageOptions{width:2,height:2,samples:samples,format:.depth_stencil})!
    defer { depth_texture.close() }
    mut depth:=DepthStencil.from_attachments(target,depth_texture,depth_texture)!
    defer { depth.close() }
    mut program:=ShaderProgram.compile(target,'#version 300 es\nvoid main(){gl_Position=vec4(gl_VertexID==1?3.0:-1.0,gl_VertexID==2?3.0:-1.0,0,1);}',
        '#version 300 es\nprecision highp float;out vec4 color;void main(){color=vec4(1,0.5,0,1);}',3)!
    defer { program.close() }
    target.draw_with_options(program,[],.triangles,0,3,1,DrawOptions{color_target:color,depth_stencil:depth,state:RenderState{depth_test:true,depth_compare:.always,stencil_test:true,
        front_stencil:StencilFace{pass:.replace,reference:37},back_stencil:StencilFace{pass:.replace,reference:37}}})!
    mut resolved_color:=color.resolved_copy()!
    defer { resolved_color.close() }
    expected:=[u8(255),128,0,255,255,128,0,255,255,128,0,255,255,128,0,255]
    assert (resolved_color.read_pixels()!)==expected
    mut resolved_depth:=depth_texture.resolved_copy()!
    defer { resolved_depth.close() }
    bytes:=resolved_depth.read_region(0,0,TextureRegion{width:2,height:2})!
    for offset:=0;offset<bytes.len;offset+=8 { assert bytes[offset..offset+8]==[u8(0),0,0,63,37,0,0,0] }
}
