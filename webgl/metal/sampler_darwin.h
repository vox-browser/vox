#ifndef VOX_METAL_SAMPLER_H
#define VOX_METAL_SAMPLER_H
#include "drawing_buffer_darwin.h"
typedef struct { uint32_t min_filter,mag_filter,mip_filter,wrap_s,wrap_t,wrap_r,compare,compare_func,anisotropy;float min_lod,max_lod; } VoxMetalSamplerOptions;
typedef struct { CFTypeRef device,state; } VoxMetalSampler;
static void vox_metal_sampler_destroy(void* handle)
{
    VoxMetalSampler* sampler=handle;
    if (!sampler) return;
    CFRelease(sampler->device);CFRelease(sampler->state);free(sampler);
}
static void* vox_metal_sampler_create(void* owner,VoxMetalSamplerOptions const* options)
{
    VoxMetalDrawingBuffer* target=owner;
    if (!target || !options || options->min_filter>1 || options->mag_filter>1 || options->mip_filter>2
        || options->wrap_s>2 || options->wrap_t>2 || options->wrap_r>2 || options->compare_func>7 || !options->anisotropy || options->anisotropy>16) return NULL;
    @autoreleasepool {
        MTLSamplerDescriptor* descriptor=[[MTLSamplerDescriptor alloc] init];
        descriptor.minFilter=options->min_filter?MTLSamplerMinMagFilterLinear:MTLSamplerMinMagFilterNearest;
        descriptor.magFilter=options->mag_filter?MTLSamplerMinMagFilterLinear:MTLSamplerMinMagFilterNearest;
        descriptor.mipFilter=(MTLSamplerMipFilter)options->mip_filter;
        MTLSamplerAddressMode wrap[]={MTLSamplerAddressModeClampToEdge,MTLSamplerAddressModeRepeat,MTLSamplerAddressModeMirrorRepeat};
        descriptor.sAddressMode=wrap[options->wrap_s];descriptor.tAddressMode=wrap[options->wrap_t];descriptor.rAddressMode=wrap[options->wrap_r];
        descriptor.lodMinClamp=MAX(0,options->min_lod);descriptor.lodMaxClamp=MAX(descriptor.lodMinClamp,options->max_lod);
        descriptor.maxAnisotropy=options->anisotropy;
        descriptor.compareFunction=options->compare?(MTLCompareFunction)options->compare_func:MTLCompareFunctionNever;
        id<MTLSamplerState> state=[(__bridge id<MTLDevice>)target->device newSamplerStateWithDescriptor:descriptor];
        vox_metal_drop_owned(descriptor);
        VoxMetalSampler* result=state?calloc(1,sizeof(*result)):NULL;
        if (result) { result->device=CFRetain(target->device);result->state=CFRetain((__bridge CFTypeRef)state); }
        vox_metal_drop_owned(state);
        return result;
    }
}
#endif
