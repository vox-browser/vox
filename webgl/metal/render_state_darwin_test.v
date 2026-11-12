module metal

fn state_program(target &DrawingBuffer) !&ShaderProgram {
    return ShaderProgram.compile(target,
        '#version 300 es\nuniform float z;void main(){gl_Position=vec4(gl_VertexID==1?3.0:-1.0,gl_VertexID==2?3.0:-1.0,z,1.0);}',
        '#version 300 es\nprecision mediump float;uniform vec4 value;out vec4 color;void main(){color=value;}',3)
}

fn state_assert_color(mut target DrawingBuffer, color []u8) ! {
    pixels := target.read_pixels()!
    for i:=0;i<pixels.len;i+=4 { assert pixels[i..i+4] == color }
}

fn test_metal_viewport_scissor_color_mask_and_separate_blending() {
    mut target := DrawingBuffer.create(4,4)!
    defer { target.close() }
    mut program := state_program(target)!
    defer { program.close() }
    target.clear(0,0.5,0,1)!
    program.uniform_floats('value',[f32(1),0,1,0])!
    target.draw_with_options(program,[],.triangles,0,3,1,DrawOptions{state:RenderState{color_mask:5,scissor:ScissorRect{x:-1,y:1,width:3,height:2}}})!
    pixels:=target.read_pixels()!
    for y in 0..4 { for x in 0..4 {
        offset:=(y*4+x)*4
        assert pixels[offset..offset+4] == if x<2 && y>=1 && y<3 { [u8(255),128,255,255] } else { [u8(0),128,0,255] }
    } }
    target.clear(0,0,1,1)!
    program.uniform_floats('value',[f32(1),0,0,0.5])!
    target.draw_with_options(program,[],.triangles,0,3,1,DrawOptions{state:RenderState{blend:true,source_rgb:.source_alpha,destination_rgb:.one_minus_source_alpha,source_alpha:.one,destination_alpha:.one_minus_source_alpha}})!
    state_assert_color(mut target,[u8(128),0,128,255])!
    target.clear(0,0,0,0)!
    program.uniform_floats('value',[f32(1),1,1,1])!
    target.draw_with_options(program,[],.triangles,0,3,1,DrawOptions{state:RenderState{viewport:Viewport{x:2,y:0,width:2,height:4}}})!
    viewport_pixels:=target.read_pixels()!
    for y in 0..4 { for x in 0..4 {
        offset:=(y*4+x)*4
        assert viewport_pixels[offset..offset+4] == if x>=2 { [u8(255),255,255,255] } else { [u8(0),0,0,0] }
    } }
}

fn test_metal_initialized_depth_comparison_and_depth_write_mask() {
    mut target := DrawingBuffer.create(4,4)!
    defer { target.close() }
    mut depth:=DepthStencil.create(target,4,4)!
    defer { depth.close() }
    mut program:=state_program(target)!
    defer { program.close() }
    options:=DrawOptions{depth_stencil:depth,state:RenderState{depth_test:true}}
    program.uniform_floats('value',[f32(1),0,0,1])!
    target.draw_with_options(program,[],.triangles,0,3,1,options)!
    program.uniform_floats('z',[f32(0.5)])!
    program.uniform_floats('value',[f32(0),0,1,1])!
    target.draw_with_options(program,[],.triangles,0,3,1,options)!
    state_assert_color(mut target,[u8(255),0,0,255])!
    program.uniform_floats('z',[f32(-0.5)])!
    program.uniform_floats('value',[f32(0),1,0,1])!
    target.draw_with_options(program,[],.triangles,0,3,1,options)!
    state_assert_color(mut target,[u8(0),255,0,255])!
    depth.clear(1,0)!
    program.uniform_floats('z',[f32(-0.8)])!
    target.draw_with_options(program,[],.triangles,0,3,1,DrawOptions{depth_stencil:depth,state:RenderState{depth_test:true,depth_write:false}})!
    program.uniform_floats('z',[f32(0.8)])!
    program.uniform_floats('value',[f32(0),0,1,1])!
    target.draw_with_options(program,[],.triangles,0,3,1,options)!
    state_assert_color(mut target,[u8(0),0,255,255])!
}

fn test_metal_front_face_culling_and_distinct_stencil_faces() {
    mut target:=DrawingBuffer.create(4,4)!
    defer { target.close() }
    vertex:='#version 300 es\nvoid main(){gl_Position=vec4(gl_VertexID==1?3.0:-1.0,gl_VertexID==2?3.0:-1.0,0.0,1.0);}'
    mut face:=ShaderProgram.compile(target,vertex,
        '#version 300 es\nprecision mediump float;out vec4 color;void main(){color=gl_FrontFacing?vec4(1,0,0,1):vec4(0,0,1,1);}',3)!
    defer { face.close() }
    target.draw_with_options(face,[],.triangles,0,3,1,DrawOptions{state:RenderState{cull:.back}})!
    state_assert_color(mut target,[u8(255),0,0,255])!
    target.clear(0,0,0,0)!
    target.draw_with_options(face,[],.triangles,0,3,1,DrawOptions{state:RenderState{cull:.front}})!
    state_assert_color(mut target,[u8(0),0,0,0])!
    mut depth:=DepthStencil.create(target,4,4)!
    defer { depth.close() }
    target.draw_with_options(face,[],.triangles,0,3,1,DrawOptions{depth_stencil:depth,state:RenderState{color_mask:0,stencil_test:true,
        front_stencil:StencilFace{reference:3,pass:.replace},back_stencil:StencilFace{reference:5,pass:.replace}}})!
    target.draw_with_options(face,[],.triangles,0,3,1,DrawOptions{depth_stencil:depth,state:RenderState{stencil_test:true,
        front_stencil:StencilFace{compare:.equal,reference:3,write_mask:0},back_stencil:StencilFace{compare:.never}}})!
    state_assert_color(mut target,[u8(255),0,0,255])!
}
