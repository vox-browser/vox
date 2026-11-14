#ifndef VOX_GLES_SHADERS_H
#define VOX_GLES_SHADERS_H
#include <stdbool.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>
/* Shared V validation and WebGL zero initialization retain the ESSL version.
 * Restore the API-visible source after compiling the private driver source. */
extern int32_t vox_v_prepare_essl(char*, int32_t, int32_t, int32_t, char*, int32_t);
static int vox_gles_compile_submission(GLuint shader,const char *source,GLint length) {
    vox_gles_collect_errors();
    glShaderSource(shader,1,&source,&length);
    /* In particular, a failed upload must never compile the original source
     * still stored in the public shader. Keep driver errors in the Vox queue. */
    if(vox_gles_collect_errors())return 0;
    glCompileShader(shader);
    return !vox_gles_collect_errors();
}
static void vox_gles_compile_shader(GLuint shader) {
    if(!glIsShader(shader)){glCompileShader(shader);return;}
    vox_gles_collect_errors();
    GLint length=0,stage=0;glGetShaderiv(shader,GL_SHADER_SOURCE_LENGTH,&length);glGetShaderiv(shader,GL_SHADER_TYPE,&stage);
    if(vox_gles_collect_errors())return;
    if(length<1){glCompileShader(shader);return;}
    char *source=calloc(1,(size_t)length);if(!source){vox_gles_error(GL_OUT_OF_MEMORY);return;}
    GLsizei actual=0;glGetShaderSource(shader,length,&actual,source);
    int version=vox_gles_current?vox_gles_current->webgl_version:3;
    int32_t prepared_length=vox_v_prepare_essl(source,actual,stage==GL_FRAGMENT_SHADER,version,NULL,0);
    char *prepared=NULL;
    if(prepared_length>0 && prepared_length<=4*1024*1024) {
        prepared=calloc(1,(size_t)prepared_length+1);
        if(!prepared){free(source);vox_gles_error(GL_OUT_OF_MEMORY);return;}
        if(vox_v_prepare_essl(source,actual,stage==GL_FRAGMENT_SHADER,version,prepared,prepared_length+1)!=prepared_length) {
            free(prepared);prepared=NULL;
        }
    }
    if(prepared) {
        /* ESSL300 retains its constant-global-initializer restrictions. For
         * ESSL100, WebGL explicitly permits nonconstant global initializers
         * that plain GLES rejects; V checks their original scope and grammar. */
        if(strncmp(prepared,"#version 300 es\n",15)==0) {
            GLuint validation=glCreateShader((GLenum)stage);
            if(!validation){vox_gles_collect_errors();free(prepared);free(source);return;}
            GLint original_compiled=GL_FALSE;
            if(vox_gles_compile_submission(validation,source,actual))
                glGetShaderiv(validation,GL_COMPILE_STATUS,&original_compiled);
            glDeleteShader(validation);
            if(original_compiled!=GL_TRUE){free(prepared);prepared=NULL;}
        }
    }
    if(prepared) {
        vox_gles_compile_submission(shader,prepared,prepared_length);
    } else {
        const char *failure="#error Shader violates WebGL ESSL validation\n";
        vox_gles_compile_submission(shader,failure,(GLint)strlen(failure));
    }
    /* glShaderSource does not recompile: status/log/executable describe the
     * prepared source, while getShaderSource still returns exactly user input. */
    const char *original=source;glShaderSource(shader,1,&original,&actual);
    vox_gles_collect_errors();
    free(prepared);
    free(source);
}
#endif
