#ifndef VOX_GLES_SHADERS_H
#define VOX_GLES_SHADERS_H
#include <stdbool.h>
#include "essl_desktop_translation.h"
/* Validate WebGL's ESSL version/loop subset, then compile the unchanged ESSL
 * on GLES. A failed validation must also fail the real driver's link step. */
static void vox_gles_compile_shader(GLuint shader) {
    if(!glIsShader(shader)){glCompileShader(shader);return;}
    GLint length=0,stage=0;glGetShaderiv(shader,GL_SHADER_SOURCE_LENGTH,&length);glGetShaderiv(shader,GL_SHADER_TYPE,&stage);
    if(length<1){glCompileShader(shader);return;}
    char *source=calloc(1,(size_t)length);if(!source){vox_gles_error(GL_OUT_OF_MEMORY);return;}
    GLsizei actual=0;glGetShaderSource(shader,length,&actual,source);
    vox_essl_prepare();
    if(!vox_essl_initialized){free(source);vox_gles_error(GL_OUT_OF_MEMORY);return;}
    glslang_resource_t resources=*glslang_default_resource();
    glGetIntegerv(GL_MAX_VERTEX_ATTRIBS,&resources.max_vertex_attribs);
    glGetIntegerv(GL_MAX_VERTEX_UNIFORM_VECTORS,&resources.max_vertex_uniform_vectors);
    glGetIntegerv(GL_MAX_FRAGMENT_UNIFORM_VECTORS,&resources.max_fragment_uniform_vectors);
    glGetIntegerv(GL_MAX_VARYING_VECTORS,&resources.max_varying_vectors);
    glGetIntegerv(GL_MAX_DRAW_BUFFERS,&resources.max_draw_buffers);
    glGetIntegerv(GL_MAX_TEXTURE_IMAGE_UNITS,&resources.max_texture_image_units);
    glGetIntegerv(GL_MAX_VERTEX_TEXTURE_IMAGE_UNITS,&resources.max_vertex_texture_image_units);
    glGetIntegerv(GL_MAX_COMBINED_TEXTURE_IMAGE_UNITS,&resources.max_combined_texture_image_units);
    char *validated=vox_glsl_desktop_source_with_resources(source,actual,stage==GL_FRAGMENT_SHADER,vox_gles_current?vox_gles_current->webgl_version:3,&resources);
    static const char failure_prefix[]="#version 410 core\n#error";
    int accepted=validated && strncmp(validated,failure_prefix,sizeof(failure_prefix)-1)!=0;
    free(validated);
    if(accepted)glCompileShader(shader);
    else {
        const char *failure="#error Shader violates WebGL ESSL validation\n";
        glShaderSource(shader,1,&failure,NULL);glCompileShader(shader);
        const char *original=source;glShaderSource(shader,1,&original,&actual);
    }
    free(source);
}
#endif
