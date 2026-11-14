#ifndef VOX_GLES_SHADERS_H
#define VOX_GLES_SHADERS_H
#include <stdbool.h>
#include <stdint.h>
/* Shared V preprocessor and WebGL version/loop validation. GLES performs its
 * own ESSL syntax/type checking on the original source after this boundary. */
extern int32_t vox_v_validate_essl(char*, int32_t, int32_t, int32_t);
static void vox_gles_compile_shader(GLuint shader) {
    if(!glIsShader(shader)){glCompileShader(shader);return;}
    GLint length=0,stage=0;glGetShaderiv(shader,GL_SHADER_SOURCE_LENGTH,&length);glGetShaderiv(shader,GL_SHADER_TYPE,&stage);
    if(length<1){glCompileShader(shader);return;}
    char *source=calloc(1,(size_t)length);if(!source){vox_gles_error(GL_OUT_OF_MEMORY);return;}
    GLsizei actual=0;glGetShaderSource(shader,length,&actual,source);
    int accepted=vox_v_validate_essl(source,actual,stage==GL_FRAGMENT_SHADER,
        vox_gles_current?vox_gles_current->webgl_version:3);
    if(accepted)glCompileShader(shader);
    else {
        const char *failure="#error Shader violates WebGL ESSL validation\n";
        glShaderSource(shader,1,&failure,NULL);glCompileShader(shader);
        const char *original=source;glShaderSource(shader,1,&original,&actual);
    }
    free(source);
}
#endif
