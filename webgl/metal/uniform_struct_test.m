#include "shader_program_darwin.h"
#include <assert.h>
#include <mach-o/dyld.h>
#include <stdio.h>
int main(void) {
    @autoreleasepool {
        void* target=vox_metal_buffer_create();assert(target);
        char log[16384];
        char const* vertex="#version 300 es\nvoid main(){gl_Position=vec4(0,0,0,1);}";
        char const* fragment="#version 300 es\nprecision highp float;struct Shade{vec3 tint;float strength;bool enabled;};struct Light{Shade shade;mat2 basis;};uniform Light lights[2];out vec4 color;void main(){color=vec4(lights[0].shade.tint*lights[0].shade.strength+lights[1].shade.tint+vec3(lights[1].basis[0],lights[0].shade.enabled?1:0),1);}";
        VoxMetalShaderProgram* program=vox_metal_program_create(target,vertex,strlen(vertex),fragment,strlen(fragment),3,log,sizeof(log));
        if(!program) fprintf(stderr,"%s\n",log);assert(program);
        int first=0,second=0,matrix=0,boolean=0;
        for(uint64_t i=0;i<vox_metal_program_resource_count(program);++i) {
            VoxMetalShaderResource field;assert(vox_metal_program_resource(program,i,&field));
            if(field.kind!=100) continue;
            if(!strcmp(field.name,"lights[0].shade.tint")) { first=1;assert(field.rows==3 && field.base_type==VOX_SHADER_FLOAT); }
            if(!strcmp(field.name,"lights[1].shade.tint")) second=1;
            if(!strcmp(field.name,"lights[1].basis")) { matrix=1;assert(field.rows==2 && field.columns==2 && field.matrix_stride==16); }
            if(!strcmp(field.name,"lights[0].shade.enabled")) { boolean=1;assert(field.semantic_type==VOX_SHADER_BOOL); }
        }
        assert(first && second && matrix && boolean);
        vox_metal_program_destroy(program);vox_metal_buffer_destroy(target);
        for(uint32_t i=0;i<_dyld_image_count();++i) { char const* name=_dyld_get_image_name(i);assert(!strstr(name,"libEGL") && !strstr(name,"libGLES") && !strstr(name,"libANGLE")); }
        puts("PASS nested struct arrays, matrix stride, boolean semantics and valid Metal padding templates");
    }
    return 0;
}
