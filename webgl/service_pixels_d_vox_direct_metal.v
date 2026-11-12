module webgl

import webgl.metal
import math

struct MetalServicePixelLayout {
    format metal.TextureFormat
    components int = 4
    integer bool
    signed bool
    floating bool
    packed u32
}

fn metal_service_layout(internal u32) !MetalServicePixelLayout {
    return match internal {
        0x1908,0x8058 { MetalServicePixelLayout{format:.rgba8} }
        0x1907,0x8051,0x8d62 { MetalServicePixelLayout{format:.rgba8,components:3,packed:if internal==0x8d62 { u32(0x8363) } else { u32(0) }} }
        0x8056 { MetalServicePixelLayout{format:.rgba8,packed:0x8033} }
        0x8057 { MetalServicePixelLayout{format:.rgba8,packed:0x8034} }
        0x1906,0x1909 { MetalServicePixelLayout{format:.rgba8,components:1} }
        0x190a { MetalServicePixelLayout{format:.rgba8,components:2} }
        0x8229 { MetalServicePixelLayout{format:.r8,components:1} }
        0x822b { MetalServicePixelLayout{format:.rg8,components:2} }
        0x8c41,0x8c43 { MetalServicePixelLayout{format:.srgba8,components:if internal==0x8c41 { 3 } else { 4 }} }
        0x8f94,0x8f95,0x8f96,0x8f97 { MetalServicePixelLayout{format:if internal==0x8f94 { .r8_snorm } else if internal==0x8f95 { .rg8_snorm } else { .rgba8_snorm },components:int(internal-0x8f94)+1,signed:true} }
        0x822d,0x822f,0x881b,0x881a { MetalServicePixelLayout{format:if internal==0x822d { .r16f } else if internal==0x822f { .rg16f } else { .rgba16f },components:if internal==0x822d { 1 } else if internal==0x822f { 2 } else if internal==0x881b { 3 } else { 4 },floating:true} }
        0x822e,0x8230,0x8815,0x8814 { MetalServicePixelLayout{format:if internal==0x822e { .r32f } else if internal==0x8230 { .rg32f } else { .rgba32f },components:if internal==0x822e { 1 } else if internal==0x8230 { 2 } else if internal==0x8815 { 3 } else { 4 },floating:true} }
        0x8231,0x8237,0x8d8f,0x8d8e { MetalServicePixelLayout{format:if internal==0x8231 { .r8i } else if internal==0x8237 { .rg8i } else { .rgba8i },components:if internal==0x8231 { 1 } else if internal==0x8237 { 2 } else if internal==0x8d8f { 3 } else { 4 },integer:true,signed:true} }
        0x8232,0x8238,0x8d7d,0x8d7c { MetalServicePixelLayout{format:if internal==0x8232 { .r8ui } else if internal==0x8238 { .rg8ui } else { .rgba8ui },components:if internal==0x8232 { 1 } else if internal==0x8238 { 2 } else if internal==0x8d7d { 3 } else { 4 },integer:true} }
        0x8233,0x8239,0x8d89,0x8d88 { MetalServicePixelLayout{format:if internal==0x8233 { .r16i } else if internal==0x8239 { .rg16i } else { .rgba16i },components:if internal==0x8233 { 1 } else if internal==0x8239 { 2 } else if internal==0x8d89 { 3 } else { 4 },integer:true,signed:true} }
        0x8234,0x823a,0x8d77,0x8d76 { MetalServicePixelLayout{format:if internal==0x8234 { .r16ui } else if internal==0x823a { .rg16ui } else { .rgba16ui },components:if internal==0x8234 { 1 } else if internal==0x823a { 2 } else if internal==0x8d77 { 3 } else { 4 },integer:true} }
        0x8235,0x823b,0x8d83,0x8d82 { MetalServicePixelLayout{format:if internal==0x8235 { .r32i } else if internal==0x823b { .rg32i } else { .rgba32i },components:if internal==0x8235 { 1 } else if internal==0x823b { 2 } else if internal==0x8d83 { 3 } else { 4 },integer:true,signed:true} }
        0x8236,0x823c,0x8d71,0x8d70 { MetalServicePixelLayout{format:if internal==0x8236 { .r32ui } else if internal==0x823c { .rg32ui } else { .rgba32ui },components:if internal==0x8236 { 1 } else if internal==0x823c { 2 } else if internal==0x8d71 { 3 } else { 4 },integer:true} }
        0x8059 { MetalServicePixelLayout{format:.rgb10a2,packed:0x8368} }
        0x906f { MetalServicePixelLayout{format:.rgb10a2ui,packed:0x8368,integer:true} }
        0x8c3a { MetalServicePixelLayout{format:.rg11b10f,components:3,packed:0x8c3b,floating:true} }
        0x8c3d { MetalServicePixelLayout{format:.rgb9e5,components:3,packed:0x8c3e,floating:true} }
        0x1902,0x81a5 { MetalServicePixelLayout{format:.depth16,components:1} }
        0x81a6,0x8cac { MetalServicePixelLayout{format:.depth32,components:1,floating:true} }
        0x84f9,0x88f0,0x8cad { MetalServicePixelLayout{format:.depth_stencil,components:2,packed:0x84fa} }
        0x8d48 { MetalServicePixelLayout{format:.stencil8,components:1,integer:true} }
        else { return error('Unknown texture internal format') }
    }
}

fn metal_service_half_to_float(value u32) f32 {
    sign:=(value&0x8000)<<16
    exponent:=(value>>10)&31
    fraction:=value&1023
    if exponent==0 { return if fraction==0 { math.f32_from_bits(sign) } else { (if sign!=0 { f32(-1) } else { f32(1) })*f32(fraction)/16777216 } }
    return math.f32_from_bits(sign | ((if exponent==31 { u32(255) } else { exponent+112 })<<23) | (fraction<<13))
}

fn metal_service_float_to_half(value f32) u32 {
    bits:=math.f32_bits(value)
    sign:=(bits>>16)&0x8000
    exponent:=int((bits>>23)&255)-127+15
    fraction:=bits&0x7fffff
    if exponent>=31 { return sign|0x7c00|if fraction!=0 && (bits&0x7f800000)==0x7f800000 { u32(0x200) } else { u32(0) } }
    if exponent<=0 {
        if exponent < -10 { return sign }
        shift:=u32(14-exponent)
        mantissa:=fraction|0x800000
        return sign|((mantissa+((u32(1)<<(shift-1))-1)+((mantissa>>shift)&1))>>shift)
    }
    rounded:=fraction+0xfff+((fraction>>13)&1)
    return sign|(u32(exponent)<<10)+(rounded>>13)
}

fn metal_service_read_scalar(bytes []u8,offset int,type_ u32) f64 {
    size:=metal_service_vertex_scalar_size(type_)
    mut bits:=u32(0)
    for j in 0..size { bits|=u32(bytes[offset+j])<<(j*8) }
    return match type_ {
        0x1400 { f64(i8(bits)) } 0x1402 { f64(i16(bits)) } 0x1404 { f64(i32(bits)) }
        0x1406 { f64(math.f32_from_bits(bits)) } 0x140b,0x8d61 { f64(metal_service_half_to_float(bits)) }
        else { f64(bits) }
    }
}

fn metal_service_native_channels(format metal.TextureFormat) int {
    return match format {
        .r8,.r8_snorm,.r16f,.r32f,.r8i,.r8ui,.r16i,.r16ui,.r32i,.r32ui,.depth16,.depth32,.stencil8 { 1 }
        .rg8,.rg8_snorm,.rg16f,.rg32f,.rg8i,.rg8ui,.rg16i,.rg16ui,.rg32i,.rg32ui { 2 }
        else { 4 }
    }
}

fn metal_service_put_scalar(mut output []u8,offset int,size int,value u32) {
    for j in 0..size { output[offset+j]=u8(value>>(j*8)) }
}

fn (mut context MetalServiceContext) unpack_pixels(layout MetalServicePixelLayout,width int,height int,depth int,format u32,type_ u32,capacity int,data voidptr,allow_null bool) ![]u8 {
    components:=component_count_for_format(format) or { metal_service_error(invalid_enum);return error('Invalid pixel format') }
    pixel_size:=bytes_per_pixel(format,type_) or { metal_service_error(invalid_enum);return error('Invalid pixel type') }
    packed16:=type_ in [unsigned_short_5_6_5,unsigned_short_4_4_4_4,unsigned_short_5_5_5_1]
    packed32:=type_ in [unsigned_int_2_10_10_10_rev,unsigned_int_10f_11f_11f_rev,unsigned_int_5_9_9_9_rev,unsigned_int_24_8]
    if (type_==unsigned_short_5_6_5 && format!=rgb) || (type_ in [unsigned_short_4_4_4_4,unsigned_short_5_5_5_1,unsigned_int_2_10_10_10_rev] && format !in [rgba,rgba_integer])
        || (layout.integer!=(format in [red_integer,rg_integer,rgb_integer,rgba_integer])) { metal_service_error(invalid_operation);return error('Pixel format/type mismatch') }
    if int(components)!=layout.components && format !in [alpha,luminance,luminance_alpha] { metal_service_error(invalid_operation);return error('Pixel components do not match storage') }
    if layout.integer && type_ !in [gl_byte,unsigned_byte,gl_short,unsigned_short,gl_int,unsigned_int,unsigned_int_2_10_10_10_rev] { metal_service_error(invalid_operation);return error('Integer texture requires integer pixels') }
    if layout.packed!=0 && layout.packed!=type_ && !(layout.packed in [u32(0x8033),0x8034,0x8363] && type_==unsigned_byte) && !(layout.packed==unsigned_int_24_8 && type_==float_32_unsigned_int_24_8_rev) { metal_service_error(invalid_operation);return error('Packed texture type mismatch') }
    // A null image allocation has no source span: GLES ignores pixel-unpack
    // row/skip state while still validating the image format and type above.
    if allow_null && data==unsafe { nil } && context.buffer_binding(pixel_unpack_buffer)==0 {
        return []u8{len:width*height*depth*layout.format.pixel_size()}
    }
    alignment:=u64(context.parameters[unpack_alignment][0])
    row_length:=u64(context.parameters[unpack_row_length][0])
    skip_rows:=u64(context.parameters[unpack_skip_rows][0]);skip_pixels:=u64(context.parameters[unpack_skip_pixels][0])
    image_height:=u64(context.parameters[unpack_image_height][0]);skip_images:=u64(context.parameters[unpack_skip_images][0])
    row_pixels:=if row_length==0 { u64(width) } else { row_length }
    rows:=if image_height==0 { u64(height) } else { image_height }
    if skip_pixels+u64(width)>row_pixels { metal_service_error(invalid_operation);return error('Unpack row is too short') }
    pitch:=checked_mul_u64(row_pixels,pixel_size) or { metal_service_error(invalid_operation);return error('Unpack overflow') }
    padded:=checked_add_u64(pitch,alignment-1) or { metal_service_error(invalid_operation);return error('Unpack overflow') }
    row_stride:=padded/alignment*alignment
    image_stride:=checked_mul_u64(rows,row_stride) or { metal_service_error(invalid_operation);return error('Unpack overflow') }
    start_a:=checked_mul_u64(skip_images,image_stride) or { metal_service_error(invalid_operation);return error('Unpack overflow') }
    start_b:=checked_mul_u64(skip_rows,row_stride) or { metal_service_error(invalid_operation);return error('Unpack overflow') }
    start_c:=checked_mul_u64(skip_pixels,pixel_size) or { metal_service_error(invalid_operation);return error('Unpack overflow') }
    start:=checked_add_u64(checked_add_u64(start_a,start_b) or { metal_service_error(invalid_operation);return error('Unpack overflow') },start_c) or { metal_service_error(invalid_operation);return error('Unpack overflow') }
    mut required:=u64(0)
    if width>0 && height>0 && depth>0 {
        tail_a:=checked_mul_u64(u64(depth-1),image_stride) or { metal_service_error(invalid_operation);return error('Unpack overflow') }
        tail_b:=checked_mul_u64(u64(height-1),row_stride) or { metal_service_error(invalid_operation);return error('Unpack overflow') }
        tail_c:=u64(width)*pixel_size
        required=checked_add_u64(checked_add_u64(checked_add_u64(start,tail_a) or { metal_service_error(invalid_operation);return error('Unpack overflow') },tail_b) or { metal_service_error(invalid_operation);return error('Unpack overflow') },tail_c) or { metal_service_error(invalid_operation);return error('Unpack overflow') }
    }
    mut source:=[]u8{}
    defer { unsafe { source.free() } }
    unpack_buffer:=context.buffer_binding(pixel_unpack_buffer)
    if unpack_buffer!=0 {
        object:=context.bound_buffer(pixel_unpack_buffer)!
        offset:=u64(data)
        if object.gpu_buffer==unsafe { nil } || offset>u64(object.gpu_buffer.size()) || required>u64(object.gpu_buffer.size())-offset || offset%u64(if packed16 { 2 } else if packed32 || type_==float_32_unsigned_int_24_8_rev { 4 } else { metal_service_vertex_scalar_size(type_) })!=0 { metal_service_error(invalid_operation);return error('Pixel unpack buffer range is invalid') }
        source=object.gpu_buffer.read(int(offset),int(required))!
    } else if data!=unsafe { nil } {
        if capacity<0 || required>u64(capacity) { metal_service_error(invalid_operation);return error('Pixel source is too short') }
        source=unsafe { (&u8(data)).vbytes(int(required)).clone() }
    } else if !allow_null && required>0 { metal_service_error(invalid_value);return error('Null pixel subimage') }
    native_components:=metal_service_native_channels(layout.format)
    native_size:=layout.format.pixel_size()
    scalar_size:=native_size/native_components
    mut result:=[]u8{len:width*height*depth*native_size}
    if source.len==0 { return result }
    for layer in 0..depth { for y in 0..height { for x in 0..width {
        input:=int(start+u64(layer)*image_stride+u64(y)*row_stride+u64(x)*pixel_size)
        destination:=((layer*height+y)*width+x)*native_size
        if layout.format==.depth_stencil {
            if type_==unsigned_int_24_8 {
                bits:=u32(source[input])|(u32(source[input+1])<<8)|(u32(source[input+2])<<16)|(u32(source[input+3])<<24)
                metal_service_put_scalar(mut result,destination,4,math.f32_bits(f32(bits>>8)/16777215))
                metal_service_put_scalar(mut result,destination+4,4,bits&255)
            } else {
                for j in 0..4 { result[destination+j]=source[input+j] }
                result[destination+4]=source[input+4]
            }
            continue
        }
        if packed32 && layout.packed==type_ { for j in 0..4 { result[destination+j]=source[input+j] };continue }
        mut values:=[f64(0),0,0,1]!
        if packed16 {
            bits:=u32(source[input])|(u32(source[input+1])<<8)
            if type_==unsigned_short_5_6_5 { values=[f64((bits>>11)&31)/31,f64((bits>>5)&63)/63,f64(bits&31)/31,1]! }
            else if type_==unsigned_short_4_4_4_4 { values=[f64((bits>>12)&15)/15,f64((bits>>8)&15)/15,f64((bits>>4)&15)/15,f64(bits&15)/15]! }
            else { values=[f64((bits>>11)&31)/31,f64((bits>>6)&31)/31,f64((bits>>1)&31)/31,f64(bits&1)]! }
        } else {
            input_scalar:=metal_service_vertex_scalar_size(type_)
            for component in 0..int(components) {
                mut value:=metal_service_read_scalar(source,input+component*input_scalar,type_)
                if !layout.integer && (!layout.floating || layout.format in [.depth16,.depth32]) && type_ in [unsigned_byte,unsigned_short,unsigned_int] { value/=if type_==unsigned_byte { f64(255) } else if type_==unsigned_short { f64(65535) } else { f64(4294967295) } }
                if !layout.integer && layout.signed && type_ in [gl_byte,gl_short,gl_int] { value/=if type_==gl_byte { f64(127) } else if type_==gl_short { f64(32767) } else { f64(2147483647) };if value < -1 { value = -1 } }
                values[component]=value
            }
            if format==alpha { values=[f64(0),0,0,values[0]]! }
            if format==luminance { values=[values[0],values[0],values[0],f64(1)]! }
            if format==luminance_alpha { values=[values[0],values[0],values[0],values[1]]! }
        }
        for component in 0..native_components {
            value:=values[component]
            encoded:=if layout.floating { if scalar_size==2 { metal_service_float_to_half(f32(value)) } else { math.f32_bits(f32(value)) } }
                else if layout.integer { u32(i64(value)) }
                else if layout.signed { u32(i32(value*127)) }
                else { u32(if value<0 || value!=value { f64(0) } else if value>1 { f64(1) } else { value }*f64(if scalar_size==2 { 65535 } else { 255 })+0.5) }
            metal_service_put_scalar(mut result,destination+component*scalar_size,scalar_size,encoded)
        }
    } } }
    return result
}
