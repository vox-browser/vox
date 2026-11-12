module webgl

import webgl.metal

@[heap]
struct MetalServiceTextureImage {
    width int
    height int
    depth int = 1
    internal u32
    layout MetalServicePixelLayout
mut:
    gpu &metal.Texture2D = unsafe { nil }
}

@[heap]
struct MetalServiceTexture {
mut:
    target u32
    sampling MetalServiceSampling
    images map[u32]&MetalServiceTextureImage
    immutable bool
    immutable_levels int
    base_level int
    max_level int = 1000
    sampled map[int]&metal.Texture2D
}

fn metal_service_texture_target(target u32) u32 {
    return if target>=0x8515 && target<=0x851a { texture_cube_map } else { target }
}

fn metal_service_image_key(target u32,level int) u32 {
    return u32(level)|(if target>=0x8515 && target<=0x851a { (target-0x8515)<<8 } else { u32(0) })
}

fn (context &MetalServiceContext) valid_texture_target(target u32) bool {
    return target in [texture_2d,texture_cube_map] || (context.version==3 && target in [texture_3d,texture_2d_array])
}

fn (context &MetalServiceContext) texture_key(target u32) u64 {
    unit:=u64(context.parameters[active_texture][0])-texture0
    return (unit<<32)|target
}

fn (mut context MetalServiceContext) texture_object(target u32) !&MetalServiceTexture {
    normalized:=metal_service_texture_target(target)
    if !context.valid_texture_target(normalized) { metal_service_error(invalid_enum);return error('Invalid texture target') }
    name:=context.textures[context.texture_key(normalized)]
    object:=context.objects[name] or { metal_service_error(invalid_operation);return error('No texture is bound') }
    if object.texture==unsafe { nil } { metal_service_error(invalid_operation);return error('Texture is not initialized') }
    return object.texture
}

fn (mut texture MetalServiceTexture) invalidate_sampling() {
    for _,mut sampled in texture.sampled { sampled.close();unsafe { free(sampled) } }
    texture.sampled.clear()
}

fn (mut texture MetalServiceTexture) close() {
    texture.invalidate_sampling()
    for _,image in texture.images {
        if image.gpu!=unsafe { nil } { image.gpu.close();unsafe { free(image.gpu) } }
        unsafe { free(image) }
    }
    unsafe { texture.images.free();texture.sampled.free();texture.sampling.parameters.free() }
}

fn (mut context MetalServiceContext) bind_texture(target u32,name u32) {
    if !context.valid_texture_target(target) { metal_service_error(invalid_enum);return }
    if name!=0 {
        mut object:=context.objects[name] or { metal_service_error(invalid_operation);return }
        if object.kind!=3 || object.deleted { metal_service_error(invalid_operation);return }
        if object.texture!=unsafe { nil } && object.texture.target!=target { metal_service_error(invalid_operation);return }
        if object.texture==unsafe { nil } { object.texture=&MetalServiceTexture{target:target,sampling:metal_service_default_sampling()} }
        object.created=true
    }
    context.textures[context.texture_key(target)]=name
}

fn (mut context MetalServiceContext) texture_parameter(target u32,pname u32,value f32,set bool) f32 {
    mut texture:=context.texture_object(target) or { return 0 }
    if target!=metal_service_texture_target(target) { metal_service_error(invalid_enum);return 0 }
    if pname in [u32(0x813c),0x813d] {
        if context.version!=3 { metal_service_error(invalid_enum);return 0 }
        if set {
            if value<0 || value>2147483647 { metal_service_error(invalid_value);return 0 }
            if pname==0x813c { texture.base_level=int(value) } else { texture.max_level=int(value) }
            texture.invalidate_sampling()
        }
        return f32(if pname==0x813c { texture.base_level } else { texture.max_level })
    }
    if !set && pname==0x912f { return f32(texture.immutable) }
    if !set && pname==0x82df { return f32(texture.immutable_levels) }
    if context.version==2 && pname !in [texture_min_filter,texture_mag_filter,texture_wrap_s,texture_wrap_t,u32(0x84fe)] { metal_service_error(invalid_enum);return 0 }
    if set { texture.sampling.set(pname,value);return 0 }
    if value_:=texture.sampling.parameters[pname] { return value_ }
    metal_service_error(invalid_enum)
    return 0
}

fn (mut context MetalServiceContext) define_texture_image(target u32,level int,internal u32,width int,height int,depth int,border int,format u32,type_ u32,capacity int,data voidptr) {
    normalized:=metal_service_texture_target(target)
    if !context.valid_texture_target(normalized) || target==texture_cube_map { metal_service_error(invalid_enum);return }
    if level<0 || level>14 || width<0 || height<0 || depth<0 || width>(16384>>level) || height>(16384>>level)
        || (normalized==texture_cube_map && width!=height) || border!=0 || (normalized==texture_3d && (width>(2048>>level) || height>(2048>>level) || depth>(2048>>level)))
        || (normalized==texture_2d_array && depth>2048) { metal_service_error(invalid_value);return }
    mut texture:=context.texture_object(target) or { return }
    if texture.immutable { metal_service_error(invalid_operation);return }
    mut layout:=metal_service_layout(internal) or { metal_service_error(invalid_value);return }
    if internal in [rgba,rgb,alpha,luminance,luminance_alpha] && type_ in [gl_float,half_float,u32(0x8d61)] {
        layout=MetalServicePixelLayout{...layout,format:if type_==gl_float { .rgba32f } else { .rgba16f },floating:true}
    }
    bytes:=context.unpack_pixels(layout,width,height,depth,format,type_,capacity,data,true) or { context.last_failure=err.msg();return }
    defer { unsafe { bytes.free() } }
    mut gpu:=unsafe { &metal.Texture2D(nil) }
    if width>0 && height>0 && depth>0 {
        gpu=metal.Texture2D.create_storage(context.target,metal.TextureStorageOptions{width:width,height:height,depth:depth,kind:if normalized==texture_3d { .volume_3d } else if normalized==texture_2d_array { .array_2d } else { .image_2d },format:layout.format}) or { context.last_failure=err.msg();metal_service_error(out_of_memory);return }
        if bytes.len>0 { context.write_image_pixels(mut gpu,normalized,0,0,0,width,height,depth,bytes) or { gpu.close();unsafe { free(gpu) };context.last_failure=err.msg();metal_service_error(out_of_memory);return } }
    }
    key:=metal_service_image_key(target,level)
    if old:=texture.images[key] { if old.gpu!=unsafe { nil } { old.gpu.close();unsafe { free(old.gpu) } };unsafe { free(old) } }
    texture.images[key]=&MetalServiceTextureImage{width:width,height:height,depth:depth,internal:internal,layout:layout,gpu:gpu}
    texture.invalidate_sampling()
}

fn (context &MetalServiceContext) write_image_pixels(mut gpu metal.Texture2D,target u32,x int,y int,z int,width int,height int,depth int,bytes []u8) ! {
    if target==texture_2d_array {
        stride:=width*height*gpu_format_size(gpu)
        for layer in 0..depth { gpu.write_region(0,z+layer,metal.TextureRegion{x:x,y:y,width:width,height:height},bytes[layer*stride..(layer+1)*stride])! }
    } else { gpu.write_region(0,0,metal.TextureRegion{x:x,y:y,z:z,width:width,height:height,depth:depth},bytes)! }
}

fn gpu_format_size(gpu &metal.Texture2D) int { return gpu.pixel_size() }

fn (mut context MetalServiceContext) sub_texture_image(target u32,level int,x int,y int,z int,width int,height int,depth int,format u32,type_ u32,capacity int,data voidptr) {
    if target==texture_cube_map { metal_service_error(invalid_enum);return }
    mut texture:=context.texture_object(target) or { return }
    if level<0 || level>14 || x<0 || y<0 || z<0 || width<0 || height<0 || depth<0 { metal_service_error(invalid_value);return }
    mut image:=texture.images[metal_service_image_key(target,level)] or { metal_service_error(invalid_operation);return }
    if x>image.width || width>image.width-x || y>image.height || height>image.height-y || z>image.depth || depth>image.depth-z { metal_service_error(invalid_value);return }
    bytes:=context.unpack_pixels(image.layout,width,height,depth,format,type_,capacity,data,false) or { context.last_failure=err.msg();return }
    defer { unsafe { bytes.free() } }
    if width==0 || height==0 || depth==0 { return }
    if image.gpu==unsafe { nil } { metal_service_error(invalid_operation);return }
    context.write_image_pixels(mut image.gpu,texture.target,x,y,z,width,height,depth,bytes) or { context.last_failure=err.msg();metal_service_error(out_of_memory);return }
    texture.invalidate_sampling()
}

fn (mut context MetalServiceContext) texture_storage(target u32,levels int,internal u32,width int,height int,depth int) {
    if !context.valid_texture_target(target) { metal_service_error(invalid_enum);return }
    if levels<1 || width<1 || height<1 || depth<1 || levels>15 || (target==texture_cube_map && width!=height) { metal_service_error(invalid_value);return }
    mut largest:=if width>height { width } else { height }
    if target==texture_3d && depth>largest { largest=depth }
    if largest>>(levels-1)==0 { metal_service_error(invalid_operation);return }
    layout:=metal_service_layout(internal) or { metal_service_error(invalid_enum);return }
    if internal in [rgba,rgb,alpha,luminance,luminance_alpha,red,rg,depth_component,u32(0x84f9)] { metal_service_error(invalid_enum);return }
    mut texture:=context.texture_object(target) or { return }
    if texture.immutable { metal_service_error(invalid_operation);return }
    mut images:=map[u32]&MetalServiceTextureImage{}
    for level in 0..levels {
        w:=if width>>level>0 { width>>level } else { 1 };h:=if height>>level>0 { height>>level } else { 1 };d:=if target==texture_3d { if depth>>level>0 { depth>>level } else { 1 } } else { depth }
        for face in 0..if target==texture_cube_map { 6 } else { 1 } {
            gpu:=metal.Texture2D.create_storage(context.target,metal.TextureStorageOptions{width:w,height:h,depth:d,kind:if target==texture_3d { .volume_3d } else if target==texture_2d_array { .array_2d } else { .image_2d },format:layout.format}) or {
                for _,image in images { image.gpu.close();unsafe { free(image.gpu);free(image) } };unsafe { images.free() }
                context.last_failure=err.msg();metal_service_error(out_of_memory);return
            }
            images[u32(level)|(u32(face)<<8)]=&MetalServiceTextureImage{width:w,height:h,depth:d,internal:internal,layout:layout,gpu:gpu}
        }
    }
    for _,image in texture.images { if image.gpu!=unsafe { nil } { image.gpu.close();unsafe { free(image.gpu) } };unsafe { free(image) } }
    unsafe { texture.images.free() }
    texture.images=images;texture.immutable=true;texture.immutable_levels=levels;texture.invalidate_sampling()
}
