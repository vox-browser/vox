#include "render_darwin.h"
#include <assert.h>
#include <mach-o/dyld.h>
#include <stdio.h>

int main(void)
{
    @autoreleasepool {
        void* target=vox_metal_buffer_create();
        assert(target && vox_metal_buffer_resize(target,2,2));
        void* texture=vox_metal_texture_create(target,2,2);
        assert(texture);
        uint8_t upload[]={255,0,0,255, 0,255,0,255, 0,0,255,255, 255,255,0,255};
        assert(vox_metal_buffer_transfer(texture,upload,sizeof(upload),1));
        assert(vox_metal_texture_sampler(texture,1,1,0,0));
        char log[16384];
        char const* vertex="#version 300 es\nvoid main(){gl_Position=vec4(gl_VertexID==1?3.:-1.,gl_VertexID==2?3.:-1.,0.,1.);}";
        char const* fragment="#version 300 es\nprecision mediump float;uniform sampler2D image;out vec4 color;void main(){color=texture(image,vec2(.5));}";
        void* program=vox_metal_program_create(target,vertex,(int)strlen(vertex),fragment,(int)strlen(fragment),3,log,sizeof(log));
        assert(program);
        VoxMetalTextureBinding binding={texture,1,UINT32_MAX,UINT32_MAX,1};
        for(uint64_t i=0;i<vox_metal_program_resource_count(program);++i){
            VoxMetalShaderResource resource;
            assert(vox_metal_program_resource(program,i,&resource));
            if(resource.kind==7){binding.binding=resource.binding;binding.sampler_binding=resource.secondary_binding;}
        }
        assert(binding.binding<128 && binding.sampler_binding<16);
        assert(vox_metal_draw_textured(target,program,NULL,0,NULL,0,&binding,1,MTLPrimitiveTypeTriangle,0,3,1,log,sizeof(log)));
        uint8_t pixels[16];
        assert(vox_metal_buffer_transfer(target,pixels,sizeof(pixels),0));
        uint8_t expected[]={128,128,64,255};
        for(int i=0;i<16;i+=4)assert(!memcmp(pixels+i,expected,4));
        assert(!vox_metal_draw_textured(texture,program,NULL,0,NULL,0,&binding,1,MTLPrimitiveTypeTriangle,0,3,1,log,sizeof(log)));
        void* volume=vox_metal_texture_storage(target,2,2,2,3,2,0,4,1);
        assert(volume);
        uint8_t volume_bytes[32]={0};
        assert(vox_metal_texture_region(volume,0,0,0,0,0,2,2,2,4,volume_bytes,sizeof(volume_bytes),0));
        for(unsigned i=0;i<sizeof(volume_bytes);++i) assert(volume_bytes[i]==0);
        void* view=vox_metal_texture_attachment(volume,0,1);
        assert(view && vox_metal_buffer_clear(view,1,0,1,1));
        assert(vox_metal_texture_region(volume,0,0,0,0,1,2,2,1,4,volume_bytes,16,0));
        for(int i=0;i<16;i+=4) assert(!memcmp(volume_bytes+i,(uint8_t[]){255,0,255,255},4));
        vox_metal_texture_destroy(view);
        vox_metal_texture_destroy(volume);
        for(unsigned format=35;format<=38;++format) {
            void* depth=vox_metal_texture_storage(target,2,2,1,0,1,format,format==35?2:format==36?4:format==37?8:1,1);
            assert(depth);vox_metal_texture_destroy(depth);
        }
        vox_metal_program_destroy(program);
        vox_metal_texture_destroy(texture);
        vox_metal_texture_destroy(NULL);
        vox_metal_buffer_destroy(target);
        for(uint32_t i=0;i<_dyld_image_count();++i){
            char const* name=_dyld_get_image_name(i);
            assert(!strstr(name,"libEGL") && !strstr(name,"libGLES") && !strstr(name,"libANGLE"));
        }
        puts("PASS sampled private textures, initialized transfers, linear filtering, feedback rejection; no ANGLE loaded");
    }
}
