module metal

fn test_metal_attribute_bindings_and_inactive_interfaces() {
    mut target:=DrawingBuffer.create(4,4)!
    defer { target.close() }
    mut program:=ShaderProgram.compile_with_bindings(target,
        'attribute vec2 position;attribute vec2 unused;uniform float never_used;uniform vec4 colors[2];varying vec4 value;void main(){gl_Position=vec4(position,0.0,1.0)+colors[1];value=colors[0];}',
        'precision mediump float;varying vec4 value;void main(){gl_FragColor=value;}',2,{'position':5})!
    defer { program.close() }
    resources:=program.resources()!
    attributes:=resources.filter(it.kind==3 && it.stage==.vertex)
    assert attributes.len==1 && attributes[0].name=='position' && attributes[0].location==5
    assert !resources.any(it.name=='unused' || it.name=='never_used'), '${resources}'
    uniforms:=resources.filter(it.kind==100)
    assert uniforms.len==1 && uniforms[0].name=='colors' && uniforms[0].array_length==2
}

fn test_metal_explicit_essl_locations_win_over_bindings_and_automatic_inputs_avoid_them() {
    mut target:=DrawingBuffer.create(4,4)!
    defer { target.close() }
    vertex:='#version 300 es\n#define POSITION 3\nlayout(location=POSITION) in vec4 position;in vec4 shade;out vec4 value;void main(){gl_Position=position;value=shade;}'
    fragment:='#version 300 es\nprecision mediump float;in vec4 value;out vec4 color;void main(){color=value;}'
    mut program:=ShaderProgram.compile_with_bindings(target,vertex,fragment,3,{'position':5})!
    resources:=program.resources()!
    assert resources.any(it.kind==3 && it.name=='position' && it.location==3)
    assert resources.any(it.kind==3 && it.name=='shade' && it.location!=3)
    program.close()
    mut rejected:=false
    ShaderProgram.compile_with_bindings(target,vertex,fragment,3,{'shade':3}) or { rejected=true }
    assert rejected
}

fn test_metal_bound_matrix_attributes_reserve_each_column_and_render_exact_pixels() {
    mut target:=DrawingBuffer.create(4,4)!
    defer { target.close() }
    mut program:=ShaderProgram.compile_with_bindings(target,
        '#version 300 es\nin mat4 transform;void main(){gl_Position=transform*vec4(gl_VertexID==1?3.0:-1.0,gl_VertexID==2?3.0:-1.0,0.0,1.0);}',
        '#version 300 es\nprecision mediump float;out vec4 color;void main(){color=vec4(1,0,0,1);}',3,{'transform':4})!
    defer { program.close() }
    matrix:=[f32(1),0,0,0, 0,1,0,0, 0,0,1,0, 0,0,0,1]
    mut buffer:=GPUBuffer.create(target,64)!
    defer { buffer.close() }
    buffer.write(0,unsafe { (&u8(matrix.data)).vbytes(64) })!
    mut streams:=[]VertexStream{}
    for column in 0..4 { streams << VertexStream{buffer:buffer,location:4+column,components:4,offset:column*16,stride:64,constant:true} }
    target.draw(program,streams,.triangles,0,3,1)!
    pixels:=target.read_pixels()!
    for i:=0;i<pixels.len;i+=4 { assert pixels[i..i+4]==[u8(255),0,0,255] }
    mut rejected:=false
    target.draw(program,streams[..3],.triangles,0,3,1) or { rejected=true }
    assert rejected
}
