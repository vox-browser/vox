module webgl

import webgl.metal
import math

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
    if offset<0 { metal_service_error(invalid_value);return }
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

fn (mut context MetalServiceContext) materialize_vertex(attribute MetalServiceVertexAttribute,source &metal.GPUBuffer,last u64,location int,stride int,element_size int) !metal.VertexStream {
    entries:=last+1
    size:=u64(attribute.size)*4
    if entries>0x7fffffff/size { metal_service_error(out_of_memory);return error('Expanded vertex data exceeds buffer allocation limit') }
    bytes:=source.read(int(attribute.offset),int(last*u64(stride)+u64(element_size)))!
    defer { unsafe { bytes.free() } }
    mut output:=[]u8{len:int(entries*size)}
    defer { unsafe { output.free() } }
    packed:=attribute.type_ in [u32(0x8d9f),0x8368]
    signed:=attribute.type_ in [u32(0x1400),0x1402,0x1404,0x8d9f]
    for vertex in u64(0)..entries {
        input:=int(vertex)*stride
        for component in 0..attribute.size {
            mut value:=f64(0)
            if packed {
                bits:=u32(metal_service_read_scalar(bytes,input,unsigned_int))
                width:=if component==3 { 2 } else { 10 }
                raw:=(bits>>(component*10))&((u32(1)<<width)-1)
                value=if signed { f64(i32(raw<<(32-width))>>(32-width)) } else { f64(raw) }
                if attribute.normalized { value/=f64((u32(1)<<(width-if signed { 1 } else { 0 })) - 1) }
            } else {
                value=metal_service_read_scalar(bytes,input+component*metal_service_vertex_scalar_size(attribute.type_),attribute.type_)
                if attribute.normalized {
                    value/=match attribute.type_ { 0x1400 { f64(127) } 0x1401 { f64(255) } 0x1402 { f64(32767) } 0x1403 { f64(65535) } 0x1404 { f64(2147483647) } 0x1405 { f64(4294967295) } else { f64(1) } }
                }
            }
            if attribute.normalized && signed && value < -1 { value = -1 }
            encoded:=if attribute.integer { u32(i64(value)) } else { math.f32_bits(f32(value)) }
            metal_service_put_scalar(mut output,int(vertex*size)+component*4,4,encoded)
        }
    }
    mut gpu:=metal.GPUBuffer.create(context.target,output.len)!
    gpu.write(0,output) or { gpu.close();unsafe { free(gpu) };return err }
    return metal.VertexStream{buffer:gpu,location:location,components:attribute.size,stride:attribute.size*4,divisor:int(attribute.divisor),integer:attribute.integer,format:if attribute.integer { if signed { .int32 } else { .uint32 } } else { .float32 }}
}
