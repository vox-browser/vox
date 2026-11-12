module webgl

struct MetalServiceSampling {
mut:
    parameters map[u32]f32
}

fn metal_service_default_sampling() MetalServiceSampling {
    return MetalServiceSampling{parameters:{
        texture_min_filter:f32(0x2702)
        texture_mag_filter:f32(0x2601)
        texture_wrap_s:f32(0x2901)
        texture_wrap_t:f32(0x2901)
        texture_wrap_r:f32(0x2901)
        texture_min_lod:f32(-1000)
        texture_max_lod:f32(1000)
        texture_compare_mode:f32(0)
        texture_compare_func:f32(0x203)
        u32(0x84fe):f32(1)
    }}
}

fn (mut sampling MetalServiceSampling) set(pname u32,value f32) bool {
    if pname !in sampling.parameters { metal_service_error(invalid_enum);return false }
    valid:=match pname {
        texture_min_filter { value in [f32(0x2600),0x2601,0x2700,0x2701,0x2702,0x2703] }
        texture_mag_filter { value in [f32(0x2600),0x2601] }
        texture_wrap_s,texture_wrap_t,texture_wrap_r { value in [f32(0x812f),0x2901,0x8370] }
        texture_compare_mode { value in [f32(0),0x884e] }
        texture_compare_func { value>=0x200 && value<=0x207 && value==f32(int(value)) }
        u32(0x84fe) { value>=1 }
        else { value==value }
    }
    if !valid { metal_service_error(if pname==0x84fe { invalid_value } else { invalid_enum });return false }
    sampling.parameters[pname]=value
    return true
}

fn (mut context MetalServiceContext) sampler_object(name u32) !&MetalServiceObject {
    mut object:=context.object(name,5)!
    if object.deleted { metal_service_error(invalid_operation);return error('Deleted sampler') }
    if object.sampling==unsafe { nil } { object.sampling=&MetalServiceSampling{...metal_service_default_sampling()} }
    return object
}

fn metal_service_sampler_set(name u32,pname u32,value f32) {
    mut context:=metal_service_current()
    if context==unsafe { nil } { return }
    mut object:=context.sampler_object(name) or { return }
    object.sampling.set(pname,value)
}
