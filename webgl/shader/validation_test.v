module shader

fn test_native_gles_validation_uses_v_context_and_loop_rules() {
    source := 'uniform int n;void main(){for(int i=0;i<n;i++){}gl_Position=vec4(1.0);}'
    assert validate_native(source.str, i32(source.len), 0, 2) == 0
    es300 := '#version 300 es\n' + source
    assert validate_native(es300.str, i32(es300.len), 0, 3) == 1
    assert validate_native(es300.str, i32(es300.len), 0, 2) == 0
    assert validate_native(unsafe { nil }, 0, 0, 3) == 0
    assert validate_native(source.str, -1, 0, 3) == 0
    assert validate_native(source.str, i32(source.len), 0, 4) == 0
    assert validate_native(c'void main(){}', 13, 0, 2) == 1
}
