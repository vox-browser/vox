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
