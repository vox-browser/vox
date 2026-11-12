#include "render_darwin.h"
#include <assert.h>
#include <stdio.h>

int main(void)
{
    @autoreleasepool {
        void* target=vox_metal_buffer_create();
        assert(target && vox_metal_buffer_resize(target,4,4));
        void* depth=vox_metal_depth_stencil_create(target,4,4);
        assert(depth);
        char log[16384];
        char const* vertex="#version 300 es\nvoid main(){gl_Position=vec4(gl_VertexID==1?3.:-1.,gl_VertexID==2?3.:-1.,0.,1.);}";
        char const* fragment="#version 300 es\nprecision mediump float;out vec4 color;void main(){color=gl_FrontFacing?vec4(1,0,0,1):vec4(0,0,1,1);}";
        void* program=vox_metal_program_create(target,vertex,(int)strlen(vertex),fragment,(int)strlen(fragment),3,log,sizeof(log));
        assert(program);
        VoxMetalRenderState state=vox_metal_default_render_state(target);
        state.depth_stencil=depth;state.depth_test=1;state.stencil_test=1;state.cull=MTLCullModeBack;
        state.front.pass=state.back.pass=MTLStencilOperationReplace;
        state.front.reference=3;state.back.reference=5;
        assert(vox_metal_draw_configured(target,program,NULL,0,NULL,0,NULL,0,&state,NULL,0,0,MTLPrimitiveTypeTriangle,0,3,1,log,sizeof(log)));
        uint8_t pixels[64];
        assert(vox_metal_buffer_transfer(target,pixels,sizeof(pixels),0));
        uint8_t red[]={255,0,0,255};
        for(int i=0;i<64;i+=4)assert(!memcmp(pixels+i,red,4));
        assert(vox_metal_buffer_clear(target,0,0,0,0));
        state.depth_compare=MTLCompareFunctionAlways;
        state.front.compare=MTLCompareFunctionEqual;state.front.write_mask=0;
        state.back.compare=MTLCompareFunctionNever;
        assert(vox_metal_draw_configured(target,program,NULL,0,NULL,0,NULL,0,&state,NULL,0,0,MTLPrimitiveTypeTriangle,0,3,1,log,sizeof(log)));
        assert(vox_metal_buffer_transfer(target,pixels,sizeof(pixels),0));
        for(int i=0;i<64;i+=4)assert(!memcmp(pixels+i,red,4));
        assert(vox_metal_depth_stencil_clear(depth,1,0));
        assert(vox_metal_buffer_clear(target,0,0,0,0));
        assert(vox_metal_draw_configured(target,program,NULL,0,NULL,0,NULL,0,&state,NULL,0,0,MTLPrimitiveTypeTriangle,0,3,1,log,sizeof(log)));
        assert(vox_metal_buffer_transfer(target,pixels,sizeof(pixels),0));
        for(int i=0;i<64;++i)assert(pixels[i]==0);
        vox_metal_program_destroy(program);vox_metal_depth_stencil_destroy(depth);vox_metal_depth_stencil_destroy(NULL);vox_metal_buffer_destroy(target);
        puts("PASS initialized depth/stencil attachments, GL front-facing/culling and separate stencil state on Metal");
    }
}
