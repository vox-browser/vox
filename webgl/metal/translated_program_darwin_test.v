module metal

import webgl.shader

fn C.vox_metal_direct_compiler_unloaded() int

fn test_translated_v_program_uses_engine_uniform_writes_and_draw_submission() {
 mut target := DrawingBuffer.create(4,4)!
 defer { target.close() }
 vertex := shader.translate('#version 300 es\nvoid main(){gl_Position=vec4(gl_VertexID==1?3.0:-1.0,gl_VertexID==2?3.0:-1.0,0.0,1.0);}',.vertex)!
 fragment := shader.translate('#version 300 es\nprecision highp float;struct Tint{vec3 color;float strength;};uniform Tint tint;out vec4 color;void main(){color=vec4(tint.color*tint.strength,1.0);}',.fragment)!
 mut program := ShaderProgram.from_translation(target,vertex,fragment)!
 defer { program.close() }
 program.uniform_floats('tint.color',[f32(1),0,0])!
 program.uniform_floats('tint.strength',[f32(1)])!
 target.draw(program,[],.triangles,0,3,1)!
 assert C.vox_metal_direct_compiler_unloaded()==1
 pixels := target.read_pixels()!
 for i:=0;i<pixels.len;i+=4 { assert pixels[i..i+4]==[u8(255),0,0,255] }
}

fn test_translated_v_program_captures_vertices_through_existing_engine_api() {
 mut target := DrawingBuffer.create(1,1)!
 defer { target.close() }
 vertex := shader.translate('#version 300 es\nout vec3 value;out mat2 matrix;void main(){value=vec3(float(gl_VertexID),float(gl_InstanceID),7.0);matrix=mat2(1.0,2.0,3.0,4.0);gl_Position=vec4(1.0,2.0,3.0,4.0);}',.vertex)!
 fragment := shader.translate('#version 300 es\nprecision highp float;out vec4 color;void main(){color=vec4(1.0);}',.fragment)!
 mut program := ShaderProgram.from_translation(target,vertex,fragment)!
 defer { program.close() }
 capture := target.capture_vertices(program,[],2,2,2,DrawOptions{})!
 defer { capture.close() }
 assert C.vox_metal_direct_compiler_unloaded()==1
 assert capture.stride==44
 for index in 0..4 {
  offset:=index*capture.stride
  assert unsafe { *(&f32(&capture.bytes[offset])) }==f32(2+index%2)
  assert unsafe { *(&f32(&capture.bytes[offset+4])) }==f32(index/2)
  assert unsafe { *(&f32(&capture.bytes[offset+12])) }==1
  assert unsafe { *(&f32(&capture.bytes[offset+40])) }==4
 }
}

fn test_translated_v_program_supports_external_uniform_block_ranges() {
 mut target:=DrawingBuffer.create(4,4)!
 defer { target.close() }
 vertex:=shader.translate('#version 300 es\nvoid main(){gl_Position=vec4(gl_VertexID==1?3.0:-1.0,gl_VertexID==2?3.0:-1.0,0.0,1.0);}',.vertex)!
 fragment:=shader.translate('#version 300 es\nprecision highp float;layout(std140) uniform Tint{vec4 tint;};out vec4 color;void main(){color=tint;}',.fragment)!
 mut program:=ShaderProgram.from_translation(target,vertex,fragment)!
 defer {program.close()}
 resource:=(program.resources()!).filter(it.kind==1)[0]
 assert resource.name=='Tint' && resource.binding==1
 mut buffer:=GPUBuffer.create(target,272)!
 defer {buffer.close()}
 values:=[f32(1),0,0,1]
 bytes:=unsafe{(&u8(values.data)).vbytes(16)}
 buffer.write(256,bytes)!
 options:=DrawOptions{uniform_blocks:[UniformBlockBinding{stage:.fragment,binding:1,buffer:buffer,offset:256,length:16}]}
 target.draw_with_options(program,[],.triangles,0,3,1,options)!
 pixels:=target.read_pixels()!
 for i:=0;i<pixels.len;i+=4 {assert pixels[i..i+4]==[u8(255),0,0,255]}
 program.uniform_block_bytes(.fragment,1,0,bytes)!
 target.draw(program,[],.triangles,0,3,1)!
 internal:=target.read_pixels()!
 assert internal==pixels
}

fn direct_storage_sample(mut target DrawingBuffer, texture &Texture2D, source string) ! {
 vertex:=shader.translate('#version 300 es\nvoid main(){gl_Position=vec4(gl_VertexID==1?3.0:-1.0,gl_VertexID==2?3.0:-1.0,0.0,1.0);}',.vertex)!
 fragment:=shader.translate(source,.fragment)!
 mut program:=ShaderProgram.from_translation(target,vertex,fragment)!
 defer {program.close()}
 target.draw_with_options(program,[],.triangles,0,3,1,DrawOptions{textures:[TextureBinding{name:'image',texture:texture}]})!
}

fn test_translated_volume_array_and_integer_textures_use_existing_storage() {
 mut target:=DrawingBuffer.create(1,1)!
 defer {target.close()}
 mut volume:=Texture2D.create_storage(target,TextureStorageOptions{width:1,height:1,depth:2,kind:.volume_3d})!
 defer {volume.close()}
 volume.write_region(0,0,TextureRegion{width:1,height:1,depth:2},[u8(255),0,0,255,0,255,0,255])!
 direct_storage_sample(mut target,volume,'#version 300 es\nprecision highp float;precision highp sampler3D;uniform sampler3D image;out vec4 color;void main(){color=texture(image,vec3(0.5,0.5,0.75));}')!
 assert (target.read_pixels()!)==[u8(0),255,0,255]
 mut array:=Texture2D.create_storage(target,TextureStorageOptions{width:1,height:1,depth:2,kind:.array_2d})!
 defer {array.close()}
 array.write_region(0,1,TextureRegion{width:1,height:1},[u8(0),0,255,255])!
 direct_storage_sample(mut target,array,'#version 300 es\nprecision highp float;precision highp sampler2DArray;uniform sampler2DArray image;out vec4 color;void main(){color=texture(image,vec3(0.5,0.5,1.0));}')!
 assert (target.read_pixels()!)==[u8(0),0,255,255]
 mut integers:=Texture2D.create_storage(target,TextureStorageOptions{width:1,height:1,format:.rgba32i})!
 defer {integers.close()}
 signed:=[i32(-2_000_000_001),2_000_000_001,-7,9]
 integers.write_region(0,0,TextureRegion{width:1,height:1},unsafe{(&u8(signed.data)).vbytes(16)})!
 direct_storage_sample(mut target,integers,'#version 300 es\nprecision highp float;precision highp isampler2D;uniform isampler2D image;out vec4 color;void main(){color=all(equal(texture(image,vec2(0.5)),ivec4(-2000000001,2000000001,-7,9)))?vec4(1.0,0.0,0.0,1.0):vec4(0.0,1.0,0.0,1.0);}')!
 assert (target.read_pixels()!)==[u8(255),0,0,255]
}

fn test_translated_unsigned_texture_retains_values_above_signed_range() {
 mut target:=DrawingBuffer.create(1,1)!
 defer {target.close()}
 mut image:=Texture2D.create_storage(target,TextureStorageOptions{width:1,height:1,format:.rgba32ui})!
 defer {image.close()}
 values:=[u32(4000000001),7,9,4294967295]
 image.write_region(0,0,TextureRegion{width:1,height:1},unsafe{(&u8(values.data)).vbytes(16)})!
 direct_storage_sample(mut target,image,'#version 300 es\nprecision highp float;precision highp usampler2D;uniform usampler2D image;out vec4 color;void main(){color=all(equal(texture(image,vec2(0.5)),uvec4(4000000001u,7u,9u,4294967295u)))?vec4(1.0,0.0,0.0,1.0):vec4(0.0,1.0,0.0,1.0);}')!
 assert (target.read_pixels()!)==[u8(255),0,0,255]
}
