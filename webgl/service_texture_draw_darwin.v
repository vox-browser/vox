module webgl

import webgl.metal

fn metal_service_wrap(value f32) metal.TextureWrap {
    return if value==0x2901 { .repeat } else if value==0x8370 { .mirror_repeat } else { .clamp }
}

fn (sampling &MetalServiceSampling) native_options() metal.SamplerOptions {
    p:=sampling.parameters
    min:=int(p[texture_min_filter])
    return metal.SamplerOptions{
        min_filter:if min in [0x2601,0x2701,0x2703] { .linear } else { .nearest }
        mag_filter:if p[texture_mag_filter]==0x2601 { .linear } else { .nearest }
        mip_filter:if min in [0x2700,0x2701] { .nearest } else if min in [0x2702,0x2703] { .linear } else { .none }
        wrap_s:metal_service_wrap(p[texture_wrap_s])
        wrap_t:metal_service_wrap(p[texture_wrap_t])
        wrap_r:metal_service_wrap(p[texture_wrap_r])
        min_lod:p[texture_min_lod]
        max_lod:p[texture_max_lod]
        compare:p[texture_compare_mode]==0x884e
        compare_func:metal_service_compare(f64(p[texture_compare_func]))
        anisotropy:if p[0x84fe]>16 { 16 } else { int(p[0x84fe]) }
    }
}

fn (mut context MetalServiceContext) black_texture(target u32,scalar u32) !&metal.Texture2D {
    key:=(u64(target)<<32)|scalar
    if texture:=context.black_textures[key] { return texture }
    kind:=if target==texture_cube_map { metal.TextureKind.cube } else if target==texture_3d { metal.TextureKind.volume_3d } else if target==texture_2d_array { metal.TextureKind.array_2d } else { metal.TextureKind.image_2d }
    format:=if scalar==7 { metal.TextureFormat.rgba32i } else if scalar==8 { metal.TextureFormat.rgba32ui } else if scalar==14 {metal.TextureFormat.depth32} else { metal.TextureFormat.rgba8 }
    mut texture:=metal.Texture2D.create_storage(context.target,metal.TextureStorageOptions{width:1,height:1,kind:kind,format:format})!
    mut bytes:=[]u8{len:format.pixel_size()}
    defer { unsafe { bytes.free() } }
    if scalar in [u32(7),8] { bytes[12]=1 } else if scalar!=14 { bytes[3]=255 }
    for slice in 0..if target==texture_cube_map { 6 } else { 1 } { texture.write_region(0,slice,metal.TextureRegion{width:1,height:1},bytes)! }
    context.black_textures[key]=texture
    return texture
}

fn (mut context MetalServiceContext) sampled_texture(mut texture MetalServiceTexture,sampling &MetalServiceSampling,scalar u32,depth bool) !&metal.Texture2D {
    fallback:=if depth {u32(14)} else {scalar}
    base:=texture.images[u32(texture.base_level)] or { return context.black_texture(texture.target,fallback) }
    if base.gpu==unsafe { nil } || texture.max_level<texture.base_level { return context.black_texture(texture.target,fallback) }
    if (base.layout.integer && ((scalar==7)!=base.layout.signed || scalar !in [u32(7),8])) || (!base.layout.integer && scalar in [u32(7),8]) { metal_service_error(invalid_operation);return error('Sampler scalar type does not match texture') }
    if base.layout.integer && (sampling.parameters[texture_mag_filter]!=0x2600 || sampling.parameters[texture_min_filter] !in [f32(0x2600),0x2700]) { return context.black_texture(texture.target,fallback) }
    if context.version==2 && ((base.width&(base.width-1))!=0 || (base.height&(base.height-1))!=0)
        && (sampling.parameters[texture_wrap_s]!=0x812f || sampling.parameters[texture_wrap_t]!=0x812f || sampling.parameters[texture_min_filter] !in [f32(0x2600),0x2601]) { return context.black_texture(texture.target,fallback) }
    mut levels:=1
    if sampling.parameters[texture_min_filter]>=0x2700 {
        mut extent:=if base.width>base.height { base.width } else { base.height }
        if texture.target==texture_3d && base.depth>extent { extent=base.depth }
        for extent>1 && texture.base_level+levels<=texture.max_level { extent>>=1;levels++ }
    }
    for level in 0..levels {
        for face in 0..if texture.target==texture_cube_map { 6 } else { 1 } {
            image:=texture.images[u32(texture.base_level+level)|(u32(face)<<8)] or { return context.black_texture(texture.target,fallback) }
            if image.gpu==unsafe { nil } || image.width!=max_dimension(base.width>>level) || image.height!=max_dimension(base.height>>level)
                || image.depth!=(if texture.target==texture_3d { max_dimension(base.depth>>level) } else { base.depth }) || image.internal!=base.internal { return context.black_texture(texture.target,fallback) }
        }
    }
    if texture.target==texture_2d && levels==1 { return base.gpu }
    if cached:=texture.sampled[levels] { return cached }
    mut output:=metal.Texture2D.create_storage(context.target,metal.TextureStorageOptions{width:base.width,height:base.height,depth:base.depth,levels:levels,format:base.layout.format,
        kind:if texture.target==texture_cube_map { .cube } else if texture.target==texture_3d { .volume_3d } else if texture.target==texture_2d_array { .array_2d } else { .image_2d }})!
    for level in 0..levels {
        for face in 0..if texture.target==texture_cube_map { 6 } else { 1 } {
            image:=texture.images[u32(texture.base_level+level)|(u32(face)<<8)] or { continue }
            if texture.target==texture_2d_array {
                for layer in 0..image.depth { output.copy_from(image.gpu,0,layer,metal.TextureRegion{width:image.width,height:image.height},level,layer,0,0,0)! }
            } else { output.copy_from(image.gpu,0,0,metal.TextureRegion{width:image.width,height:image.height,depth:if texture.target==texture_3d { image.depth } else { 1 }},level,face,0,0,0)! }
        }
    }
    texture.sampled[levels]=output
    return output
}

fn max_dimension(value int) int { return if value>0 { value } else { 1 } }

struct MetalServiceTextureBindings {
mut:
    bindings []metal.TextureBinding
    samplers []&metal.Sampler
}

fn (mut bindings MetalServiceTextureBindings) close() {
    for mut sampler in bindings.samplers { sampler.close();unsafe { free(sampler) } }
    unsafe { bindings.bindings.free();bindings.samplers.free() }
}

fn (mut context MetalServiceContext) texture_bindings(program &MetalServiceObject) !MetalServiceTextureBindings {
    mut result:=MetalServiceTextureBindings{}
    mut unit_types:=map[int]u32{}
    defer { unsafe { unit_types.free() } }
    for info in program.uniforms {
        if info.resource.kind!=7 { continue }
        target:=if info.resource.image_dimension==3 { texture_cube_map } else if info.resource.image_dimension==2 { texture_3d } else if info.resource.image_arrayed { texture_2d_array } else { texture_2d }
        for element in 0..info.size {
            unit:=int(unsafe { (&i32(info.values.data))[element] })
            if unit<0 || unit>=32 { result.close();metal_service_error(invalid_operation);return error('Sampler unit is outside limits') }
            if previous:=unit_types[unit] { if previous!=info.type_ { result.close();metal_service_error(invalid_operation);return error('Conflicting sampler types on one texture unit') } }
            unit_types[unit]=info.type_
            name:=context.textures[(u64(unit)<<32)|target]
            mut texture:=unsafe { &MetalServiceTexture(nil) }
            mut sampling:=metal_service_default_sampling()
            mut own_sampling:=true
            if object:=context.objects[name] { texture=object.texture;if texture!=unsafe { nil } { unsafe { sampling.parameters.free() };sampling=texture.sampling;own_sampling=false } }
            sampler_name:=context.samplers[unit]
            if sampler_name!=0 {
                object:=context.sampler_object(sampler_name) or { result.close();return err }
                if own_sampling { unsafe { sampling.parameters.free() } }
                sampling=*object.sampling;own_sampling=false
            }
            mut gpu:=unsafe { &metal.Texture2D(nil) }
            if texture==unsafe { nil } { gpu=context.black_texture(target,if info.resource.image_depth {u32(14)} else {info.resource.image_scalar_type})! }
            else {
                if context.draw_framebuffer>=16 {
                    fbo:=context.bound_framebuffer(framebuffer)!
                    for _,attachment in fbo.attachments { if attachment.kind==3 && attachment.object==name { result.close();metal_service_error(invalid_operation);return error('Framebuffer texture feedback loop') } }
                }
                gpu=context.sampled_texture(mut texture,&sampling,info.resource.image_scalar_type,info.resource.image_depth) or { result.close();return err }
            }
            depth_texture:=gpu.pixel_format() in [.depth16,.depth32,.depth_stencil]
            mut native_options:=sampling.native_options()
            if info.resource.image_depth && texture==unsafe{nil} {native_options=metal.SamplerOptions{...native_options,compare:true,compare_func:.never}}
            if (info.resource.image_depth && (!depth_texture || !native_options.compare)) || (!info.resource.image_depth && depth_texture && native_options.compare) {if own_sampling {unsafe{sampling.parameters.free()}};result.close();metal_service_error(invalid_operation);return error('Texture comparison mode does not match shader sampler')}
            sampler:=metal.Sampler.create(context.target,native_options) or { if own_sampling { unsafe { sampling.parameters.free() } };result.close();return err }
            if own_sampling { unsafe { sampling.parameters.free() } }
            result.samplers<<sampler
            result.bindings<<metal.TextureBinding{name:info.lookup,texture:gpu,sampler:sampler,array_index:u32(element)}
        }
    }
    return result
}

fn (mut context MetalServiceContext) invalidate_draw_textures() {
    if context.draw_framebuffer<16 { return }
    fbo:=context.bound_framebuffer(framebuffer) or { return }
    for _,attachment in fbo.attachments {
        if attachment.kind!=3 { continue }
        if mut object:=context.objects[attachment.object] { if object.texture!=unsafe { nil } { object.texture.invalidate_sampling() } }
    }
}
