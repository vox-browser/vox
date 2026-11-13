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

fn test_translated_fragment_builtins_and_legacy_draw_buffers_render_real_targets() {
 mut target:=DrawingBuffer.create(2,2)!
 defer {target.close()}
 vertex:=shader.translate('#version 300 es\nvoid main(){gl_Position=vec4(gl_VertexID==1?3.0:-1.0,gl_VertexID==2?3.0:-1.0,0.0,1.0);}',.vertex)!
 fragment:=shader.translate('#version 300 es\nprecision highp float;out vec4 color;void main(){color=gl_FrontFacing && gl_FragCoord.y<1.0 ? vec4(1.0,0.0,0.0,1.0) : vec4(0.0,0.0,1.0,1.0);}',.fragment)!
 mut program:=ShaderProgram.from_translation(target,vertex,fragment)!
 defer {program.close()}
 target.draw(program,[],.triangles,0,3,1)!
 pixels:=target.read_pixels()!
 assert pixels[..8]==[u8(255),0,0,255,255,0,0,255]
 assert pixels[8..]==[u8(0),0,255,255,0,0,255,255]
 legacy_vertex:=shader.translate('attribute vec2 position;void main(){gl_Position=vec4(position,0.0,1.0);}',.vertex)!
 legacy_fragment:=shader.translate('#extension GL_EXT_draw_buffers : require\nprecision mediump float;void main(){gl_FragData[0]=vec4(1.0,0.0,0.0,1.0);gl_FragData[1]=vec4(0.0,1.0,0.0,1.0);}',.fragment)!
 mut mrt:=ShaderProgram.from_translation(target,legacy_vertex,legacy_fragment)!
 defer {mrt.close()}
 mut first:=Texture2D.create_storage(target,TextureStorageOptions{width:2,height:2})!
 defer {first.close()}
 mut second:=Texture2D.create_storage(target,TextureStorageOptions{width:2,height:2})!
 defer {second.close()}
 mut positions:=GPUBuffer.create(target,24)!
 defer {positions.close()}
 values:=[f32(-1),-1,3,-1,-1,3]
 positions.write(0,unsafe{(&u8(values.data)).vbytes(24)})!
 options:=DrawOptions{colors_configured:true,color_targets:[ColorTargetBinding{index:0,texture:first},ColorTargetBinding{index:1,texture:second}]}
 target.draw_with_options(mrt,[VertexStream{buffer:positions,location:0,components:2}],.triangles,0,3,1,options)!
 a:=first.read_pixels()!;b:=second.read_pixels()!
 for i:=0;i<a.len;i+=4 {assert a[i..i+4]==[u8(255),0,0,255];assert b[i..i+4]==[u8(0),255,0,255]}
}

fn test_translated_fragment_depth_and_discard_affect_existing_render_state() {
 mut target:=DrawingBuffer.create(2,2)!
 defer {target.close()}
 vertex:=shader.translate('#version 300 es\nvoid main(){gl_Position=vec4(gl_VertexID==1?3.0:-1.0,gl_VertexID==2?3.0:-1.0,0.0,1.0);}',.vertex)!
 fragment:=shader.translate('#version 300 es\nprecision highp float;uniform float z;uniform vec4 value;out vec4 color;void main(){gl_FragDepth=z;color=value;}',.fragment)!
 mut program:=ShaderProgram.from_translation(target,vertex,fragment)!
 defer {program.close()}
 mut depth:=DepthStencil.create(target,2,2)!
 defer {depth.close()}
 depth.clear(1,0)!
 options:=DrawOptions{depth_stencil:depth,state:RenderState{depth_test:true}}
 program.uniform_floats('z',[f32(0.75)])!
 program.uniform_floats('value',[f32(1),0,0,1])!
 target.draw_with_options(program,[],.triangles,0,3,1,options)!
 program.uniform_floats('z',[f32(0.25)])!
 program.uniform_floats('value',[f32(0),1,0,1])!
 target.draw_with_options(program,[],.triangles,0,3,1,options)!
 pixels:=target.read_pixels()!
 for i:=0;i<pixels.len;i+=4 {assert pixels[i..i+4]==[u8(0),255,0,255]}
 target.draw(program,[],.triangles,0,3,1)!
 clipped:=shader.translate('#version 300 es\nprecision highp float;out vec4 color;void main(){if(gl_FragCoord.x<1.0)discard;color=vec4(0.0,1.0,0.0,1.0);}',.fragment)!
 mut discard_program:=ShaderProgram.from_translation(target,vertex,clipped)!
 defer {discard_program.close()}
 target.clear(0,0,0,0)!
 target.draw(discard_program,[],.triangles,0,3,1)!
 clipped_pixels:=target.read_pixels()!
 for row in 0..2 {
  assert clipped_pixels[row*8..row*8+4]==[u8(0),0,0,0]
  assert clipped_pixels[row*8+4..row*8+8]==[u8(0),255,0,255]
 }
}

fn test_translated_program_drops_unused_attribute_and_uniform_bindings() {
 mut target:=DrawingBuffer.create(2,2)!
 defer {target.close()}
 vertex:=shader.translate_with_bindings('#version 300 es\nin vec2 position;in vec4 unused;uniform float never_used;void main(){gl_Position=vec4(position,0.0,1.0);}',.vertex,{'position':5})!
 fragment:=shader.translate('#version 300 es\nprecision highp float;uniform sampler2D unusedImage;out vec4 color;void main(){color=vec4(1.0,0.0,0.0,1.0);}',.fragment)!
 mut program:=ShaderProgram.from_translation(target,vertex,fragment)!
 defer {program.close()}
 resources:=program.resources()!
 assert resources.len==1 && resources[0].name=='position'
 mut positions:=GPUBuffer.create(target,24)!
 defer {positions.close()}
 values:=[f32(-1),-1,3,-1,-1,3]
 positions.write(0,unsafe{(&u8(values.data)).vbytes(24)})!
 target.draw(program,[VertexStream{buffer:positions,location:5,components:2}],.triangles,0,3,1)!
 pixels:=target.read_pixels()!
 for i:=0;i<pixels.len;i+=4 {assert pixels[i..i+4]==[u8(255),0,0,255]}
}

fn test_named_row_major_block_arrays_decode_independent_gpu_buffers() {
 mut target:=DrawingBuffer.create(1,1)!
 defer {target.close()}
 mut program:=ShaderProgram.compile(target,
  '#version 300 es\nvoid main(){gl_Position=vec4(gl_VertexID==1?3.0:-1.0,gl_VertexID==2?3.0:-1.0,0,1);}',
  '#version 300 es\nprecision highp float;layout(row_major,std140) uniform State{mat2x3 basis;vec4 tint;} data[2];out vec4 color;void main(){color=data[1].basis[1][2]==6.0?data[0].tint:vec4(0,1,0,1);}',3)!
 defer {program.close()}
 mut first:=[]f32{len:16};first[12]=1;first[15]=1
 second:=[f32(1),2,0,0,3,4,0,0,5,6,0,0,0,1,0,1]
 program.uniform_block_bytes(.fragment,1,0,unsafe{(&u8(first.data)).vbytes(64)})!
 program.uniform_block_bytes(.fragment,2,0,unsafe{(&u8(second.data)).vbytes(64)})!
 resources:=program.resources()!
 assert resources.any(it.kind==100 && it.name=='State[1].basis' && it.row_major && it.offset==0)
 target.draw(program,[],.triangles,0,3,1)!
 assert (target.read_pixels()!)==[u8(255),0,0,255]
}

fn test_sampler_array_bindings_select_independent_real_textures() {
 mut target:=DrawingBuffer.create(1,1)!
 defer {target.close()}
 mut red:=Texture2D.create(target,1,1)!
 defer {red.close()}
 red.write_pixels([u8(255),0,0,255])!
 mut green:=Texture2D.create(target,1,1)!
 defer {green.close()}
 green.write_pixels([u8(0),255,0,255])!
 mut program:=ShaderProgram.compile(target,
 '#version 300 es\nvoid main(){gl_Position=vec4(gl_VertexID==1?3.0:-1.0,gl_VertexID==2?3.0:-1.0,0,1);}',
 '#version 300 es\nprecision highp float;uniform sampler2D images[2];out vec4 color;void main(){color=texture(images[1],vec2(0.5));}',3)!
 defer {program.close()}
 target.draw_with_options(program,[],.triangles,0,3,1,DrawOptions{textures:[TextureBinding{name:'images',array_index:0,texture:red},TextureBinding{name:'images',array_index:1,texture:green}]})!
 assert (target.read_pixels()!)==[u8(0),255,0,255]
}

fn test_shadow_sampler_compares_actual_gpu_depth_values() {
 mut target:=DrawingBuffer.create(1,1)!
 defer {target.close()}
 mut image:=Texture2D.create_storage(target,TextureStorageOptions{width:1,height:1,format:.depth32})!
 defer {image.close()}
 value:=[f32(0.75)]
 image.write_region(0,0,TextureRegion{width:1,height:1},unsafe{(&u8(value.data)).vbytes(4)})!
 mut sampler:=Sampler.create(target,SamplerOptions{compare:true,compare_func:.less_equal})!
 defer {sampler.close()}
 mut program:=ShaderProgram.compile(target,
 '#version 300 es\nvoid main(){gl_Position=vec4(gl_VertexID==1?3.0:-1.0,gl_VertexID==2?3.0:-1.0,0,1);}',
 '#version 300 es\nprecision highp float;precision highp sampler2DShadow;uniform sampler2DShadow image;out vec4 color;void main(){color=vec4(texture(image,vec3(0.5,0.5,0.5)),0,0,1);}',3)!
 defer {program.close()}
 target.draw_with_options(program,[],.triangles,0,3,1,DrawOptions{textures:[TextureBinding{name:'image',texture:image,sampler:sampler}]})!
 assert (target.read_pixels()!)==[u8(255),0,0,255]
 value2:=[f32(0.25)]
 image.write_region(0,0,TextureRegion{width:1,height:1},unsafe{(&u8(value2.data)).vbytes(4)})!
 target.draw_with_options(program,[],.triangles,0,3,1,DrawOptions{textures:[TextureBinding{name:'image',texture:image,sampler:sampler}]})!
 assert (target.read_pixels()!)==[u8(0),0,0,255]
}

fn test_pruned_helpers_still_receive_full_native_type_validation() {
 mut target:=DrawingBuffer.create(1,1)!
 defer {target.close()}
 mut rejected:=false
 ShaderProgram.compile(target,
 '#version 300 es\nfloat unused(float x){return x%2.0;}void main(){gl_Position=vec4(0,0,0,1);}',
 '#version 300 es\nprecision highp float;out vec4 color;void main(){color=vec4(1.0);}',3) or {rejected=true}
 assert rejected
}
