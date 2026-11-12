module webgl

fn (mut context MetalServiceContext) read_pixels(x int,y int,width int,height int,format u32,type_ u32,capacity int,output voidptr) int {
    if width<0 || height<0 || capacity<0 { metal_service_error(invalid_value); return 0 }
    if format!=rgba || type_!=unsigned_byte { metal_service_error(invalid_enum); return 0 }
    if context.buffer_binding(0x88eb)!=0 { metal_service_error(invalid_operation); return 0 }
    if !context.surface { metal_service_error(invalid_framebuffer_operation); return 0 }
    if width==0 || height==0 { return 0 }
    alignment:=u64(context.parameters[pack_alignment][0])
    row_length:=int(context.parameters[0xd02][0])
    skip_rows:=u64(context.parameters[0xd03][0])
    skip_pixels:=u64(context.parameters[0xd04][0])
    row:=u64(if row_length>0 { row_length } else { width })*4
    pitch:=(row+alignment-1)/alignment*alignment
    start:=skip_rows*pitch+skip_pixels*4
    if u64(height-1)>0 && pitch>(~u64(0)-start)/u64(height-1) { metal_service_error(invalid_operation); return 0 }
    body:=start+u64(height-1)*pitch
    if u64(width)>((~u64(0))-body)/4 { metal_service_error(invalid_operation); return 0 }
    required:=body+u64(width)*4
    if required>u64(capacity) || output==unsafe { nil } { metal_service_error(invalid_operation); return 0 }
    pixels:=context.target.read_pixels() or { context.last_failure=err.msg();metal_service_error(out_of_memory);return 0 }
    defer { unsafe { pixels.free() } }
    for destination_y in 0..height {
        for destination_x in 0..width {
            sx:=x+destination_x;sy:=y+destination_y
            offset:=start+u64(destination_y)*pitch+u64(destination_x)*4
            unsafe {
                destination:=&u8(output)+offset
                if sx>=0 && sy>=0 && sx<context.width && sy<context.height { vmemcpy(destination,&u8(pixels.data)+(sy*context.width+sx)*4,4) }
                else { vmemset(destination,0,4) }
            }
        }
    }
    return int(required)
}
