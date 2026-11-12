module metal

fn test_metal_same_texture_can_use_distinct_sampler_objects_in_one_draw() {
    mut target:=DrawingBuffer.create(1,1)!
    defer { target.close() }
    mut texture:=Texture2D.create(target,2,2)!
    defer { texture.close() }
    texture.write_pixels([u8(255),0,0,255,0,255,0,255,0,0,255,255,255,255,255,255])!
    mut nearest:=Sampler.create(target,SamplerOptions{})!
    defer { nearest.close() }
    mut linear:=Sampler.create(target,SamplerOptions{min_filter:.linear,mag_filter:.linear})!
    defer { linear.close() }
    mut program:=ShaderProgram.compile(target,'#version 300 es\nvoid main(){gl_Position=vec4(gl_VertexID==1?3.0:-1.0,gl_VertexID==2?3.0:-1.0,0,1);}',
        '#version 300 es\nprecision highp float;uniform sampler2D firstImage;uniform sampler2D secondImage;out vec4 color;void main(){color=vec4(texture(firstImage,vec2(0.5)).r,texture(secondImage,vec2(0.5)).g,0,1);}',3)!
    defer { program.close() }
    target.draw_with_options(program,[],.triangles,0,3,1,DrawOptions{textures:[TextureBinding{name:'firstImage',texture:texture,sampler:nearest},TextureBinding{name:'secondImage',texture:texture,sampler:linear}]})!
    assert (target.read_pixels()!)==[u8(255),128,0,255]
}

fn test_metal_sampler_lod_clamps_and_default_texture_sampler_select_mip_levels() {
    mut target:=DrawingBuffer.create(1,1)!
    defer { target.close() }
    mut texture:=Texture2D.create_storage(target,TextureStorageOptions{width:2,height:2,levels:2})!
    defer { texture.close() }
    texture.write_region(0,0,TextureRegion{width:2,height:2},[u8(255),0,0,255,255,0,0,255,255,0,0,255,255,0,0,255])!
    texture.write_region(1,0,TextureRegion{width:1,height:1},[u8(0),255,0,255])!
    texture.sampler(SamplerOptions{mip_filter:.nearest,min_lod:1,max_lod:1})!
    mut program:=ShaderProgram.compile(target,'#version 300 es\nvoid main(){gl_Position=vec4(gl_VertexID==1?3.0:-1.0,gl_VertexID==2?3.0:-1.0,0,1);}',
        '#version 300 es\nprecision highp float;uniform sampler2D image;out vec4 color;void main(){color=texture(image,vec2(0.5));}',3)!
    defer { program.close() }
    target.draw_with_options(program,[],.triangles,0,3,1,DrawOptions{textures:[TextureBinding{name:'image',texture:texture}]})!
    assert (target.read_pixels()!)==[u8(0),255,0,255]
}
