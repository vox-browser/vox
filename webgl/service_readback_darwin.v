module webgl

fn (mut context MetalServiceContext) read_pixels(x int,y int,width int,height int,format u32,type_ u32,capacity int,output voidptr) int {
    if width<0 || height<0 || capacity<0 { metal_service_error(invalid_value); return 0 }
    if format !in [rgba,rgba_integer] || type_ !in [unsigned_byte,gl_float,gl_int,unsigned_int] { metal_service_error(invalid_enum);return 0 }
    pixel_size:=if type_==unsigned_byte { u64(4) } else { u64(16) }
    if context.buffer_binding(0x88eb)!=0 { metal_service_error(invalid_operation); return 0 }
    if context.framebuffer_status(if context.version==3 { read_framebuffer } else { framebuffer })!=0x8cd5 { metal_service_error(invalid_framebuffer_operation);return 0 }
    if width==0 || height==0 { return 0 }
    alignment:=u64(context.parameters[pack_alignment][0])
    row_length:=int(context.parameters[0xd02][0])
    skip_rows:=u64(context.parameters[0xd03][0])
    skip_pixels:=u64(context.parameters[0xd04][0])
    row:=u64(if row_length>0 { row_length } else { width })*pixel_size
    pitch:=(row+alignment-1)/alignment*alignment
    row_start:=checked_mul_u64(skip_rows,pitch) or { metal_service_error(invalid_operation);return 0 }
    pixel_start:=checked_mul_u64(skip_pixels,pixel_size) or { metal_service_error(invalid_operation);return 0 }
    start:=checked_add_u64(row_start,pixel_start) or { metal_service_error(invalid_operation);return 0 }
    if u64(height-1)>0 && pitch>(~u64(0)-start)/u64(height-1) { metal_service_error(invalid_operation); return 0 }
    body:=start+u64(height-1)*pitch
    if u64(width)>((~u64(0))-body)/pixel_size { metal_service_error(invalid_operation); return 0 }
    required:=body+u64(width)*pixel_size
    if required>u64(capacity) || output==unsafe { nil } { metal_service_error(invalid_operation); return 0 }
    pixels,source_width,source_height,_:=context.read_color_data(format,type_) or { context.last_failure=err.msg();return 0 }
    defer { unsafe { pixels.free() } }
    for destination_y in 0..height {
        for destination_x in 0..width {
            sx:=x+destination_x;sy:=y+destination_y
            offset:=start+u64(destination_y)*pitch+u64(destination_x)*pixel_size
            unsafe {
                destination:=&u8(output)+offset
                if sx>=0 && sy>=0 && sx<source_width && sy<source_height { vmemcpy(destination,&u8(pixels.data)+(sy*source_width+sx)*int(pixel_size),int(pixel_size)) }
                else { vmemset(destination,0,int(pixel_size)) }
            }
        }
    }
    return int(required)
}
