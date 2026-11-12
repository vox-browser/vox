module webgl

struct MetalServiceCurrentAttribute {
mut:
    kind u32 = 13
    floats [4]f32
    signed [4]i32
    unsigned [4]u32
}

fn (context &MetalServiceContext) valid_vertex(index u32) bool {
    if index>=16 { metal_service_error(invalid_value); return false }
    return true
}

fn metal_service_vertex_scalar_size(type_ u32) int {
    return match type_ { 0x1400,0x1401 { 1 } 0x1402,0x1403,0x140b,0x8d61 { 2 } 0x1404,0x1405,0x1406,0x8d9f,0x8368 { 4 } else { 0 } }
}

fn (mut context MetalServiceContext) set_vertex_pointer(index u32,size int,type_ u32,normalized bool,stride int,offset i64,integer bool) {
    if !context.valid_vertex(index) { return }
    allowed:=if integer { context.version==3 && type_ in [u32(0x1400),0x1401,0x1402,0x1403,0x1404,0x1405] }
        else { type_ in [u32(0x1400),0x1401,0x1402,0x1403,0x1406] || (context.version==3 && type_ in [u32(0x1404),0x1405,0x140b,0x8d9f,0x8368]) }
    if !allowed { metal_service_error(invalid_enum); return }
    if size<1 || size>4 || stride<0 || stride>255 { metal_service_error(invalid_value); return }
    scalar:=metal_service_vertex_scalar_size(type_)
    if (type_ in [u32(0x8d9f),0x8368] && size!=4) || offset%i64(scalar)!=0 || stride%scalar!=0 { metal_service_error(invalid_operation); return }
    buffer:=context.buffer_binding(array_buffer)
    if buffer==0 && offset!=0 { metal_service_error(invalid_operation); return }
    mut vao:=context.vao()
    mut attribute:=&vao.attributes[int(index)]
    attribute.buffer=buffer;attribute.size=size;attribute.type_=type_
    attribute.normalized=normalized && !integer;attribute.integer=integer;attribute.stride=stride;attribute.offset=offset
    context.collect_buffers()
}

fn (mut context MetalServiceContext) set_vertex_floats(index u32,values [4]f32) {
    if !context.valid_vertex(index) { return }
    context.current_attributes[int(index)].kind=13
    context.current_attributes[int(index)].floats=values
}

fn (context &MetalServiceContext) current_vertex_numbers(index u32) ![4]f64 {
    if !context.valid_vertex(index) { return error('Invalid attribute') }
    value:=context.current_attributes[int(index)]
    mut result:=[f64(0),0,0,0]!
    for i in 0..4 { result[i]=if value.kind==7 { f64(value.signed[i]) } else if value.kind==8 { f64(value.unsigned[i]) } else { f64(value.floats[i]) } }
    return result
}
