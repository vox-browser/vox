#include "render_darwin.h"
#include <assert.h>
#include <mach-o/dyld.h>
#include <stdio.h>

int main(void)
{
    @autoreleasepool {
        void* target = vox_metal_buffer_create();
        assert(target && vox_metal_buffer_resize(target, 8, 8));
        void* vertices = vox_metal_gpu_buffer_create(target, 24);
        float positions[] = {-1,-1, 3,-1, -1,3};
        uint8_t zeros[24]; memset(zeros, 0xff, sizeof(zeros));
        assert(vertices && vox_metal_gpu_buffer_transfer(vertices, 0, 24, zeros, 0));
        for (int i=0; i<24; ++i) assert(zeros[i] == 0);
        assert(!vox_metal_gpu_buffer_transfer(vertices, UINT64_MAX, 1, positions, 1));
        assert(!vox_metal_gpu_buffer_transfer(vertices, 23, 2, positions, 1));
        assert(vox_metal_gpu_buffer_transfer(vertices, 0, sizeof(positions), positions, 1));
        char log[16384];
        char const* vertex = "attribute vec2 position;void main(){gl_Position=vec4(position,0.,1.);}";
        char const* fragment = "precision mediump float;void main(){gl_FragColor=gl_FragCoord.y<4.?vec4(1,0,0,1):vec4(0,0,1,1);}";
        void* program = vox_metal_program_create(target, vertex, (int)strlen(vertex), fragment, (int)strlen(fragment), 2, log, sizeof(log));
        assert(program);
        uint32_t location=UINT32_MAX;
        for (uint64_t i=0; i<vox_metal_program_resource_count(program); ++i) {
            VoxMetalShaderResource resource;
            assert(vox_metal_program_resource(program, i, &resource));
            if (resource.kind==3 && !strcmp(resource.name,"position")) location=resource.location;
        }
        assert(location<16);
        VoxMetalVertexStream stream={vertices,0,8,location,2,0};
        assert(vox_metal_draw(target, program, &stream, 1, NULL, 0, MTLPrimitiveTypeTriangle, 0, 3, 1, log, sizeof(log)));
        uint8_t pixels[256];
        assert(vox_metal_buffer_transfer(target,pixels,sizeof(pixels),0));
        for (int y=0;y<8;++y) for(int x=0;x<8;++x) {
            uint8_t expected[]={y<4?255:0,0,y<4?0:255,255};
            assert(!memcmp(pixels+(y*8+x)*4,expected,4));
        }
        vox_metal_program_destroy(program);
        vox_metal_gpu_buffer_destroy(vertices);
        vox_metal_gpu_buffer_destroy(NULL);
        vox_metal_buffer_destroy(target);
        for (uint32_t i=0;i<_dyld_image_count();++i) {
            char const* name=_dyld_get_image_name(i);
            assert(!strstr(name,"libEGL") && !strstr(name,"libGLES") && !strstr(name,"libANGLE"));
        }
        puts("PASS initialized buffers, bounded updates, actual Metal vertex pipeline and asymmetric GL-coordinate pixels; no ANGLE loaded");
    }
}
