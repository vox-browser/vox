#include "render_darwin.h"
#include <assert.h>
#include <stdio.h>

int main(void)
{
    @autoreleasepool {
        void* target=vox_metal_buffer_create();
        assert(target && vox_metal_buffer_resize(target,4,4));
        void* bytes=vox_metal_gpu_buffer_create(target,5);
        uint8_t data[]={0,255,64,128,255};
        assert(bytes && vox_metal_gpu_buffer_transfer(bytes,0,5,data,1));
        char log[16384];
        char const* vertex="#version 300 es\nin vec4 shade;out vec4 value;void main(){value=shade;gl_Position=vec4(gl_VertexID==1?3.:-1.,gl_VertexID==2?3.:-1.,0.,1.);}";
        char const* fragment="#version 300 es\nprecision mediump float;in vec4 value;out vec4 color;void main(){color=value;}";
        void* program=vox_metal_program_create(target,vertex,(int)strlen(vertex),fragment,(int)strlen(fragment),3,log,sizeof(log));
        assert(program);
        uint32_t location=UINT32_MAX;
        for(uint64_t i=0;i<vox_metal_program_resource_count(program);++i){
            VoxMetalShaderResource resource;
            assert(vox_metal_program_resource(program,i,&resource));
            if(resource.kind==3 && !strcmp(resource.name,"shade"))location=resource.location;
        }
        assert(location<16);
        VoxMetalVertexStream stream={.buffer=bytes,.offset=1,.stride=4,.location=location,.components=4,.format=1,.normalized=1,.constant=1};
        assert(vox_metal_draw(target,program,&stream,1,NULL,0,MTLPrimitiveTypeTriangle,0,3,1,log,sizeof(log)));
        uint8_t pixels[64];assert(vox_metal_buffer_transfer(target,pixels,sizeof(pixels),0));
        for(int i=0;i<64;i+=4)assert(!memcmp(pixels+i,data+1,4));
        vox_metal_program_destroy(program);vox_metal_gpu_buffer_destroy(bytes);vox_metal_buffer_destroy(target);
        puts("PASS normalized byte attributes, unaligned stream base and constant vertex fetch on Metal");
    }
}
