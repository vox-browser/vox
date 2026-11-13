module webgl

import webgl.metal

fn metal_service_s3tc(format u32) bool { return format>=0x83f0 && format<=0x83f3 }

// S3TC's little-endian 4x4 blocks are decoded before Metal upload. Keep logical
// compressed formats distinct from the physical RGBA8 storage for validation.
fn metal_service_decode_s3tc(format u32,width int,height int,depth int,source []u8) []u8 {
    mut pixels:=[]u8{len:width*height*depth*4}
    block_size:=if format<=0x83f1 { 8 } else { 16 }
    blocks_x:=(width+3)/4;blocks_y:=(height+3)/4
    for layer in 0..depth { for by in 0..blocks_y { for bx in 0..blocks_x {
        begin:=((layer*blocks_y+by)*blocks_x+bx)*block_size
        color:=begin+block_size-8
        c0:=u32(source[color])|(u32(source[color+1])<<8)
        c1:=u32(source[color+2])|(u32(source[color+3])<<8)
        mut palette:=[4][4]u32{}
        for i,c in [c0,c1] {
            r:=(c>>11)&31;g:=(c>>5)&63;b:=c&31
            palette[i]=[(r<<3)|(r>>2),(g<<2)|(g>>4),(b<<3)|(b>>2),u32(255)]!
        }
        if c0>c1 || format>=0x83f2 {
            for c in 0..3 { palette[2][c]=(2*palette[0][c]+palette[1][c])/3;palette[3][c]=(palette[0][c]+2*palette[1][c])/3 }
            palette[2][3]=255;palette[3][3]=255
        } else {
            for c in 0..3 { palette[2][c]=(palette[0][c]+palette[1][c])/2 }
            palette[2][3]=255;palette[3][3]=if format==0x83f0 { u32(255) } else { u32(0) }
        }
        mut alpha_values:=[8]u32{}
        mut alpha_bits:=u64(0)
        if format==0x83f3 {
            alpha_values[0]=source[begin];alpha_values[1]=source[begin+1]
            if alpha_values[0]>alpha_values[1] {
                for i in 2..8 { alpha_values[i]=(u32(8-i)*alpha_values[0]+u32(i-1)*alpha_values[1])/7 }
            } else {
                for i in 2..6 { alpha_values[i]=(u32(6-i)*alpha_values[0]+u32(i-1)*alpha_values[1])/5 }
                alpha_values[6]=0;alpha_values[7]=255
            }
            for i in 0..6 { alpha_bits|=u64(source[begin+2+i])<<(8*i) }
        }
        for y in 0..4 { for x in 0..4 {
            px:=bx*4+x;py:=by*4+y
            if px>=width || py>=height { continue }
            index:=(source[color+4+y]>>(2*x))&3
            destination:=((layer*height+py)*width+px)*4
            for c in 0..4 { pixels[destination+c]=u8(palette[index][c]) }
            if format==0x83f2 { pixels[destination+3]=((source[begin+(y*4+x)/2]>>((x%2)*4))&15)*17 }
            if format==0x83f3 { pixels[destination+3]=u8(alpha_values[(alpha_bits>>(3*(y*4+x)))&7]) }
        } }
    } } }
    return pixels
}

fn (mut context MetalServiceContext) compressed_texture(target u32,level int,format u32,x int,y int,z int,width int,height int,depth int,border int,capacity int,data voidptr,define bool) {
    normalized:=metal_service_texture_target(target)
    if !context.valid_texture_target(normalized) || target==texture_cube_map || normalized==texture_3d { metal_service_error(invalid_enum);return }
    if !metal_service_s3tc(format) { metal_service_error(invalid_enum);return }
    if level<0 || level>14 || width<0 || height<0 || depth<0 || x<0 || y<0 || z<0 || border!=0 || capacity<0
        || width>(16384>>level) || height>(16384>>level) || depth>2048 || (normalized==texture_cube_map && width!=height && define) { metal_service_error(invalid_value);return }
    mut texture:=context.texture_object(target) or { return }
    key:=metal_service_image_key(target,level)
    if define {
        if texture.immutable { metal_service_error(invalid_operation);return }
        if ((width<<level)%4)!=0 || ((height<<level)%4)!=0 { metal_service_error(invalid_operation);return }
    } else {
        image:=texture.images[key] or { metal_service_error(invalid_operation);return }
        if image.internal!=format { metal_service_error(invalid_operation);return }
        if x>image.width || width>image.width-x || y>image.height || height>image.height-y || z>image.depth || depth>image.depth-z { metal_service_error(invalid_value);return }
        if x%4!=0 || y%4!=0 || (width%4!=0 && width!=image.width) || (height%4!=0 && height!=image.height) { metal_service_error(invalid_operation);return }
    }
    required:=u64((width+3)/4)*u64((height+3)/4)*u64(depth)*u64(if format<=0x83f1 { 8 } else { 16 })
    if required!=u64(capacity) { metal_service_error(invalid_value);return }
    mut source:=[]u8{}
    defer { unsafe { source.free() } }
    if context.buffers[pixel_unpack_buffer]!=0 {
        buffer:=context.bound_buffer(pixel_unpack_buffer) or { return }
        offset:=u64(data)
        if buffer.gpu_buffer==unsafe { nil } || offset>u64(buffer.gpu_buffer.size()) || required>u64(buffer.gpu_buffer.size())-offset { metal_service_error(invalid_operation);return }
        source=buffer.gpu_buffer.read(int(offset),int(required)) or { context.last_failure=err.msg();metal_service_error(invalid_operation);return }
    } else if required>0 {
        if data==unsafe { nil } { metal_service_error(invalid_value);return }
        source=unsafe { (&u8(data)).vbytes(int(required)).clone() }
    }
    bytes:=metal_service_decode_s3tc(format,width,height,depth,source)
    defer { unsafe { bytes.free() } }
    if define {
        mut gpu:=unsafe { &metal.Texture2D(nil) }
        if width>0 && height>0 && depth>0 {
            gpu=metal.Texture2D.create_storage(context.target,metal.TextureStorageOptions{width:width,height:height,depth:depth,kind:if normalized==texture_2d_array { .array_2d } else { .image_2d }}) or { context.last_failure=err.msg();metal_service_error(out_of_memory);return }
            context.write_image_pixels(mut gpu,normalized,0,0,0,width,height,depth,bytes) or { gpu.close();unsafe { free(gpu) };context.last_failure=err.msg();metal_service_error(out_of_memory);return }
        }
        if old:=texture.images[key] { if old.gpu!=unsafe { nil } { old.gpu.close();unsafe { free(old.gpu) } };unsafe { free(old) } }
        texture.images[key]=&MetalServiceTextureImage{width:width,height:height,depth:depth,internal:format,layout:MetalServicePixelLayout{format:.rgba8,components:4},gpu:gpu}
    } else if bytes.len>0 {
        mut image:=texture.images[key] or { return }
        context.write_image_pixels(mut image.gpu,normalized,x,y,z,width,height,depth,bytes) or { context.last_failure=err.msg();metal_service_error(out_of_memory);return }
    }
    texture.invalidate_sampling()
}
