#include "shader_program_darwin.h"
#include <assert.h>
#include <mach-o/dyld.h>
#include <stdio.h>
static int loaded(char const* library) {
    for(uint32_t i=0;i<_dyld_image_count();++i) if(strstr(_dyld_get_image_name(i),library)) return 1;
    return 0;
}
int main(void) {
    @autoreleasepool {
        assert(!loaded("libglslang"));
        void* target=vox_metal_buffer_create();assert(target);
        assert(!loaded("libglslang"));
        char log[16384];char const* vertex="void main(){gl_Position=vec4(0,0,0,1);}";
        char const* fragment="precision mediump float;void main(){gl_FragColor=vec4(1);}";
        void* program=vox_metal_program_create(target,vertex,strlen(vertex),fragment,strlen(fragment),2,log,sizeof(log));
        if(!program) fprintf(stderr,"%s\n",log);assert(program);
        assert(!loaded("glslang") && !loaded("spirv-cross"));
        assert(!loaded("libEGL") && !loaded("libGLES") && !loaded("libANGLE"));
        vox_metal_program_destroy(program);vox_metal_buffer_destroy(target);
        puts("PASS V compiler has no glslang, SPIRV-Cross or ANGLE runtime dependency");
    }
    return 0;
}
