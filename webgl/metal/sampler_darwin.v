module metal

#include "@DIR/sampler_darwin.h"
@[typedef]
struct C.VoxMetalSamplerOptions {
    min_filter u32
    mag_filter u32
    mip_filter u32
    wrap_s u32
    wrap_t u32
    wrap_r u32
    compare u32
    compare_func u32
    anisotropy u32
    min_lod f32
    max_lod f32
}
fn C.vox_metal_sampler_create(voidptr,&C.VoxMetalSamplerOptions) voidptr
fn C.vox_metal_sampler_destroy(voidptr)

pub enum MipFilter { none nearest linear }

@[heap]
pub struct Sampler {
mut:
    handle voidptr
    owner &DrawingBuffer
}

pub fn Sampler.create(owner &DrawingBuffer,options SamplerOptions) !&Sampler {
    if owner.handle==unsafe { nil } || options.min_lod!=options.min_lod || options.max_lod!=options.max_lod || options.anisotropy<1 || options.anisotropy>16 { return error('Invalid Metal sampler options or owner') }
    native:=C.VoxMetalSamplerOptions{min_filter:u32(options.min_filter),mag_filter:u32(options.mag_filter),mip_filter:u32(options.mip_filter),wrap_s:u32(options.wrap_s),wrap_t:u32(options.wrap_t),wrap_r:u32(options.wrap_r),compare:u32(options.compare),compare_func:u32(options.compare_func),anisotropy:u32(options.anisotropy),min_lod:options.min_lod,max_lod:options.max_lod}
    handle:=C.vox_metal_sampler_create(owner.handle,&native)
    if handle==unsafe { nil } { return error('Metal sampler creation failed') }
    return &Sampler{handle:handle,owner:owner}
}

pub fn (mut sampler Sampler) close() {
    C.vox_metal_sampler_destroy(sampler.handle)
    sampler.handle=unsafe { nil }
}
