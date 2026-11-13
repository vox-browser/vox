#include "shader_program_darwin.h"
#include <assert.h>
#include <mach-o/dyld.h>
#include <stdio.h>

int main(void)
{
    @autoreleasepool {
        void* target = vox_metal_buffer_create();
        assert(target && vox_metal_buffer_resize(target, 8, 8));
        char log[16384];
        char const* vertex = "attribute vec2 position;attribute vec4 inactive;uniform float never_used;uniform mat4 transform;varying vec2 uv;void main(){gl_Position=transform*vec4(position,0.,1.);uv=position;}";
        char const* fragment = "precision mediump float;uniform sampler2D texture;varying vec2 uv;void main(){gl_FragColor=texture2D(texture,uv);}";
        VoxMetalAttributeBinding binding = {"position",5};
        void* program = vox_metal_program_create_bound(target, vertex, (int)strlen(vertex), fragment, (int)strlen(fragment), 2, &binding, 1, log, sizeof(log));
        if (!program) fprintf(stderr, "%s\n", log);
        assert(program);
        assert(strstr(vox_metal_program_source(program, 0), "vertex"));
        assert(strstr(vox_metal_program_source(program, 1), "fragment"));
        int matrix = 0, sampler = 0, position = 0;
        for (uint64_t i = 0; i < vox_metal_program_resource_count(program); ++i) {
            VoxMetalShaderResource resource;
            assert(vox_metal_program_resource(program, i, &resource));
            assert(strcmp(resource.name,"inactive") && strcmp(resource.name,"never_used"));
            if (!strcmp(resource.name, "transform")) matrix = resource.kind == 100 && resource.matrix_stride == 16 && resource.columns == 4;
            if (!strcmp(resource.name, "texture")) sampler = resource.kind == 7;
            if (!strcmp(resource.name, "position")) position = resource.kind == 3 && resource.rows == 2 && resource.location == 5;
        }
        assert(matrix && sampler && position);
        vox_metal_program_destroy(program);
        char const* invalid = "precision mediump float;varying vec3 uv;void main(){gl_FragColor=vec4(uv,1.);}";
        assert(!vox_metal_program_create(target, vertex, (int)strlen(vertex), invalid, (int)strlen(invalid), 2, log, sizeof(log)));
        assert(log[0]);
        vox_metal_program_destroy(NULL);
        vox_metal_buffer_destroy(target);
        for (uint32_t i = 0; i < _dyld_image_count(); ++i) {
            char const* image = _dyld_get_image_name(i);
            assert(!strstr(image, "libEGL") && !strstr(image, "libGLES") && !strstr(image, "libANGLE"));
        }
        puts("PASS ESSL linking, Metal functions, uniform/matrix/sampler reflection; no ANGLE loaded");
    }
    return 0;
}
