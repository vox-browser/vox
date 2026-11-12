#include "render_darwin.h"
#include <assert.h>
#include <stdio.h>
int main(void) {
    @autoreleasepool {
        void* target=vox_metal_buffer_create();assert(target && vox_metal_buffer_resize(target,1,1));
        char log[16384];
        char const* vertex="#version 300 es\nout float doubled;void main(){doubled=float(gl_VertexID+1)*2.;gl_Position=vec4(1,2,3,4);}";
        char const* fragment="#version 300 es\nprecision highp float;out vec4 color;void main(){color=vec4(1);}";
        VoxMetalShaderProgram* program=vox_metal_program_create(target,vertex,strlen(vertex),fragment,strlen(fragment),3,log,sizeof(log));
        if(!program) fprintf(stderr,"%s\n",log);assert(program);
        if(!vox_metal_program_feedback(program,log,sizeof(log))) { fprintf(stderr,"%s\n%s\n",log,program->translated->feedback_msl);return 1; }
        VoxMetalRenderState state=vox_metal_default_render_state(target);state.feedback=1;
        int ok=vox_metal_draw_configured(target,program,NULL,0,NULL,0,NULL,0,&state,NULL,0,0,0,1,2,1,log,sizeof(log));
        if(!ok) fprintf(stderr,"%s\n",log);assert(ok);
        printf("stride=%llu\n",(unsigned long long)program->feedback_stride);
        void* output=vox_metal_gpu_buffer_create(target,program->feedback_stride*2);assert(output);state.feedback_buffer=output;
        ok=vox_metal_draw_configured(target,program,NULL,0,NULL,0,NULL,0,&state,NULL,0,0,0,1,2,1,log,sizeof(log));
        if(!ok) fprintf(stderr,"%s\n",log);assert(ok);
        uint8_t bytes[1024];assert(program->feedback_stride*2<=sizeof(bytes));
        assert(vox_metal_gpu_buffer_transfer(output,0,program->feedback_stride*2,bytes,0));
        for(size_t i=0;i<program->translated->feedback_count;++i) {
            VoxMetalFeedbackField* field=program->translated->feedback_fields+i;
            printf("%s -> %s offset=%u\n",field->name,field->metal_name,field->offset);
            assert(field->offset!=UINT32_MAX);
            if(!strcmp(field->name,"doubled")) { assert(*(float*)(bytes+field->offset)==4);assert(*(float*)(bytes+program->feedback_stride+field->offset)==6); }
            if(!strcmp(field->name,"gl_Position")) { float expected[4]={1,2,3,4};assert(!memcmp(bytes+field->offset,expected,sizeof(expected))); }
        }
        vox_metal_gpu_buffer_destroy(output);vox_metal_program_destroy(program);vox_metal_buffer_destroy(target);
        puts("PASS actual Metal vertex output capture and reflected layout");
    }
}
