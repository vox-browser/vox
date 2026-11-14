module webgl

fn metal_service_upload_uniform(location i32, rows int, columns int, count int, kind u32, data voidptr, transpose bool) {
    mut context:=metal_service_current()
    if context==unsafe { nil } { return }
    if count<0 || transpose { metal_service_error(invalid_value); return }
    if context.current_program==0 { metal_service_error(invalid_operation); return }
    mut program:=context.object(context.current_program,10) or { return }
    if location == -1 { return }
    if location<0 || int(location)>=program.locations.len || program.program==unsafe { nil } { metal_service_error(invalid_operation); return }
    entry:=program.locations[int(location)]
    mut info:=&program.uniforms[entry.uniform]
    if rows!=int(info.resource.rows) || columns!=int(info.resource.columns) { metal_service_error(invalid_operation); return }
    sampler:=info.resource.kind==7
    boolean:=info.type_ in [u32(0x8b56),0x8b57,0x8b58,0x8b59]
    if (sampler && kind!=7) || (!sampler && !boolean && kind!=info.resource.scalar_type) { metal_service_error(invalid_operation); return }
    if count>1 && info.size==1 && info.resource.array_stride==0 { metal_service_error(invalid_operation); return }
    length:=if count>info.size-entry.element { info.size-entry.element } else { count }
    if length==0 { return }
    if data==unsafe { nil } { metal_service_error(invalid_value); return }
    stride:=rows*columns*4
    mut values:=if sampler { info.values.clone() } else { program.program.uniform_values(info.lookup) or { metal_service_error(invalid_operation); return } }
    defer { unsafe { values.free() } }
    unsafe { vmemcpy(&u8(values.data)+entry.element*stride,data,length*stride) }
    if sampler {
        unsafe { info.values.free() }
        info.values=values.clone()
    } else if boolean {
        mut booleans:=[]bool{len:values.len/4}
        defer { unsafe { booleans.free() } }
        for i in 0..booleans.len {
            booleans[i]=unsafe { if kind==13 { (&f32(values.data))[i]!=0 } else { (&u32(values.data))[i]!=0 } }
        }
        program.program.uniform_bools(info.lookup,booleans) or { metal_service_error(invalid_operation) }
    } else if kind==13 {
        mut floats:=[]f32{len:values.len/4}
        defer { unsafe { floats.free() } }
        unsafe { vmemcpy(floats.data,values.data,values.len) }
        program.program.uniform_floats(info.lookup,floats) or { metal_service_error(invalid_operation) }
    } else if kind==7 {
        mut integers:=[]i32{len:values.len/4}
        defer { unsafe { integers.free() } }
        unsafe { vmemcpy(integers.data,values.data,values.len) }
        program.program.uniform_ints(info.lookup,integers) or { metal_service_error(invalid_operation) }
    } else if kind==8 {
        mut integers:=[]u32{len:values.len/4}
        defer { unsafe { integers.free() } }
        unsafe { vmemcpy(integers.data,values.data,values.len) }
        program.program.uniform_uints(info.lookup,integers) or { metal_service_error(invalid_operation) }
    }
}

fn metal_service_uniform_numbers(name u32,location i32) ![]f64 {
    context:=metal_service_current()
    if context==unsafe { nil } { return error('No context') }
    program:=context.linked_program(name)!
    if location<0 || int(location)>=program.locations.len { metal_service_error(invalid_operation); return error('Invalid uniform location') }
    entry:=program.locations[int(location)]
    info:=program.uniforms[entry.uniform]
    sampler:=info.resource.kind==7
    bytes:=if sampler { info.values.clone() } else { program.program.uniform_values(info.lookup)! }
    defer { unsafe { bytes.free() } }
    count:=int(info.resource.rows*info.resource.columns)
    start:=entry.element*count
    mut result:=[]f64{len:count}
    for i in 0..count {
        result[i]=unsafe {
            if info.resource.scalar_type==13 { f64((&f32(bytes.data))[start+i]) }
            else if info.resource.scalar_type==7 || sampler { f64((&i32(bytes.data))[start+i]) }
            else { f64((&u32(bytes.data))[start+i]) }
        }
    }
    return result
}
