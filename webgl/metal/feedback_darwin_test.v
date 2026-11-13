module metal

fn test_vertex_capture_preserves_nonzero_vertex_ids_instance_order_and_clip_coordinates() {
    mut target:=DrawingBuffer.create(1,1)!
    defer { target.close() }
    mut program:=ShaderProgram.compile(target,'#version 300 es\nout vec3 value;out mat2 matrix;void main(){value=vec3(gl_VertexID,gl_InstanceID,7);matrix=mat2(1,2,3,4);gl_Position=vec4(1,2,3,4);}',
        '#version 300 es\nprecision highp float;out vec4 color;void main(){color=vec4(1);}',3)!
    defer { program.close() }
    capture:=target.capture_vertices(program,[],2,2,2,DrawOptions{})!
    defer { capture.close() }
    assert capture.stride>0
    for field in capture.fields {
        assert field.offset!=~u32(0)
        if field.name=='value' {
            for index in 0..4 {
                offset:=index*capture.stride+int(field.offset)
                values:=unsafe { (&f32(&capture.bytes[offset])) }
                assert unsafe { values[0] }==f32(2+index%2)
                assert unsafe { values[1] }==f32(index/2)
                assert unsafe { values[2] }==7
            }
        }
        if field.name=='matrix' {
            assert field.matrix_stride==8
            for column in 0..2 { for row in 0..2 {
                offset:=int(field.offset)+column*int(field.matrix_stride)+row*4
                assert unsafe { *(&f32(&capture.bytes[offset])) }==f32(1+column*2+row)
            } }
        }
        if field.name=='gl_Position' {
            for c in 0..4 { assert unsafe { *(&f32(&capture.bytes[int(field.offset)+c*4])) }==f32(c+1) }
        }
    }
}
