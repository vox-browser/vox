module webgl

import webgl.metal

fn (mut context MetalServiceContext) copy_texture(target u32,level int,internal u32,x_offset int,y_offset int,x int,y int,width int,height int,border int,define bool) {
    if target!=texture_2d && (target<0x8515 || target>0x851a) { metal_service_error(invalid_enum);return }
    if width<0 || height<0 || width>16384 || height>16384 || level<0 || level>14 || border!=0 { metal_service_error(invalid_value);return }
    mut texture:=context.texture_object(target) or { return }
    layout:=if define { metal_service_layout(internal) or { metal_service_error(invalid_enum);return } } else {
        image:=texture.images[metal_service_image_key(target,level)] or { metal_service_error(invalid_operation);return }
        image.layout
    }
    if layout.integer || layout.format in [.depth16,.depth32,.depth_stencil,.stencil8] { metal_service_error(invalid_operation);return }
    pixels,source_width,source_height:=context.read_color_pixels() or { context.last_failure=err.msg();return }
    defer { unsafe { pixels.free() } }
    source_format:=if layout.components==1 { red } else if layout.components==2 { rg } else if layout.components==3 { rgb } else { rgba }
    mut bytes:=[]u8{len:width*height*layout.components}
    defer { unsafe { bytes.free() } }
    for row in 0..height { for column in 0..width {
        sx:=x+column;sy:=y+row
        if sx<0 || sy<0 || sx>=source_width || sy>=source_height { continue }
        for component in 0..layout.components { bytes[(row*width+column)*layout.components+component]=pixels[(sy*source_width+sx)*4+component] }
    } }
    names:=[unpack_alignment,unpack_row_length,unpack_skip_rows,unpack_skip_pixels,unpack_image_height,unpack_skip_images]
    mut saved:=map[u32][]f64{}
    for name in names { saved[name]=context.parameters[name];context.parameters[name]=[f64(if name==unpack_alignment { 1 } else { 0 })] }
    original_buffer:=context.buffers[pixel_unpack_buffer];context.buffers[pixel_unpack_buffer]=0
    defer {
        for name,value in saved { current:=context.parameters[name];unsafe { current.free() };context.parameters[name]=value }
        unsafe { saved.free();names.free() };context.buffers[pixel_unpack_buffer]=original_buffer
    }
    if define { context.define_texture_image(target,level,internal,width,height,1,border,source_format,unsigned_byte,bytes.len,bytes.data) }
    else { context.sub_texture_image(target,level,x_offset,y_offset,0,width,height,1,source_format,unsigned_byte,bytes.len,bytes.data) }
}

fn (mut context MetalServiceContext) generate_mipmap(target u32) {
    if !context.valid_texture_target(target) { metal_service_error(invalid_enum);return }
    mut texture:=context.texture_object(target) or { return }
    base:=texture.images[u32(texture.base_level)] or { metal_service_error(invalid_operation);return }
    if base.gpu==unsafe { nil } || base.layout.integer || base.layout.format in [.depth16,.depth32,.depth_stencil,.stencil8] { metal_service_error(invalid_operation);return }
    if context.version==2 && ((base.width&(base.width-1))!=0 || (base.height&(base.height-1))!=0) { metal_service_error(invalid_operation);return }
    mut levels:=1;mut extent:=if base.width>base.height { base.width } else { base.height }
    if target==texture_3d && base.depth>extent { extent=base.depth }
    for extent>1 && texture.base_level+levels<=texture.max_level && (!texture.immutable || texture.base_level+levels<texture.immutable_levels) { extent>>=1;levels++ }
    mut generated:=metal.Texture2D.create_storage(context.target,metal.TextureStorageOptions{width:base.width,height:base.height,depth:base.depth,levels:levels,format:base.layout.format,
        kind:if target==texture_cube_map { .cube } else if target==texture_3d { .volume_3d } else if target==texture_2d_array { .array_2d } else { .image_2d }}) or { context.last_failure=err.msg();metal_service_error(out_of_memory);return }
    defer { generated.close();unsafe { free(generated) } }
    for face in 0..if target==texture_cube_map { 6 } else { 1 } {
        image:=texture.images[u32(texture.base_level)|(u32(face)<<8)] or { metal_service_error(invalid_operation);return }
        if image.gpu==unsafe { nil } || image.width!=base.width || image.height!=base.height || image.internal!=base.internal { metal_service_error(invalid_operation);return }
        if target==texture_2d_array { for layer in 0..base.depth { generated.copy_from(image.gpu,0,layer,metal.TextureRegion{width:base.width,height:base.height},0,layer,0,0,0) or { context.last_failure=err.msg();metal_service_error(invalid_operation);return } } }
        else { generated.copy_from(image.gpu,0,0,metal.TextureRegion{width:base.width,height:base.height,depth:if target==texture_3d { base.depth } else { 1 }},0,face,0,0,0) or { context.last_failure=err.msg();metal_service_error(invalid_operation);return } }
    }
    generated.generate_mipmaps() or { context.last_failure=err.msg();metal_service_error(invalid_operation);return }
    for level in 1..levels {
        w:=max_dimension(base.width>>level);h:=max_dimension(base.height>>level);d:=if target==texture_3d { max_dimension(base.depth>>level) } else { base.depth }
        for face in 0..if target==texture_cube_map { 6 } else { 1 } {
            mut gpu:=metal.Texture2D.create_storage(context.target,metal.TextureStorageOptions{width:w,height:h,depth:d,format:base.layout.format,kind:if target==texture_3d { .volume_3d } else if target==texture_2d_array { .array_2d } else { .image_2d }}) or { context.last_failure=err.msg();metal_service_error(out_of_memory);return }
            if target==texture_2d_array { for layer in 0..d { gpu.copy_from(generated,level,layer,metal.TextureRegion{width:w,height:h},0,layer,0,0,0) or { gpu.close();context.last_failure=err.msg();metal_service_error(invalid_operation);return } } }
            else { gpu.copy_from(generated,level,face,metal.TextureRegion{width:w,height:h,depth:if target==texture_3d { d } else { 1 }},0,0,0,0,0) or { gpu.close();context.last_failure=err.msg();metal_service_error(invalid_operation);return } }
            key:=u32(texture.base_level+level)|(u32(face)<<8)
            if old:=texture.images[key] { if old.gpu!=unsafe { nil } { old.gpu.close();unsafe { free(old.gpu) } };unsafe { free(old) } }
            texture.images[key]=&MetalServiceTextureImage{width:w,height:h,depth:d,internal:base.internal,layout:base.layout,gpu:gpu}
        }
    }
    texture.invalidate_sampling()
}
