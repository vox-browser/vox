/* Native GLES boundary for Linux. No ANGLE headers or entry points.
 * Every CPU transfer/query is checked before the driver can touch its pointer. */
#ifndef VOX_GLES_ADAPTER_LINUX_H
#define VOX_GLES_ADAPTER_LINUX_H
#include <limits.h>
#include <stddef.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "../platform/native_state.h"
#include <dlfcn.h>

typedef struct {
    EGLDisplay display; EGLContext context;
    GLenum errors[8]; unsigned error_count;
    int webgl_version;
    void (GL_APIENTRYP texture_level_parameter)(GLenum,GLint,GLenum,GLint*);
    char *extensions;
} VoxGLESState;
VOX_NATIVE_STATE __thread VoxGLESState *vox_gles_current;
/* WebGL and the portable GLX window share a thread, not GL state. Rebind the
 * selected GLES context for each service call and restore the caller on exit.
 * Headless callers keep their GLES context current between calls. */
/* Sokol declares its own GLX types. Keep the window ABI opaque here rather
 * than including glx.h into its generated C translation unit. libGL is linked
 * by the service, so POSIX dlsym resolves the standard GLX dispatch functions. */
typedef struct {
    int initialized;
    void *(*context)(void), *(*display)(void);
    unsigned long (*drawable)(void), (*read_drawable)(void);
    int (*make_current)(void*,unsigned long,unsigned long,void*);
} VoxGLESGLX;
VOX_NATIVE_STATE __thread VoxGLESGLX vox_gles_glx;
static void vox_gles_prepare_glx(void) {
    /* Sokol may load libGL after an earlier headless WebGL call. Retry a
     * missing dispatch table instead of caching that pre-window result. */
    if(vox_gles_glx.initialized && vox_gles_glx.context)return;
    vox_gles_glx.initialized=1;
    vox_gles_glx.context=(void*(*)(void))dlsym(RTLD_DEFAULT,"glXGetCurrentContext");
    vox_gles_glx.display=(void*(*)(void))dlsym(RTLD_DEFAULT,"glXGetCurrentDisplay");
    vox_gles_glx.drawable=(unsigned long(*)(void))dlsym(RTLD_DEFAULT,"glXGetCurrentDrawable");
    vox_gles_glx.read_drawable=(unsigned long(*)(void))dlsym(RTLD_DEFAULT,"glXGetCurrentReadDrawable");
    vox_gles_glx.make_current=(int(*)(void*,unsigned long,unsigned long,void*))dlsym(RTLD_DEFAULT,"glXMakeContextCurrent");
}
typedef struct { void *display,*context; unsigned long draw,read; } VoxGLESCall;
static VoxGLESCall vox_gles_begin_call(void) {
    vox_gles_prepare_glx();
    VoxGLESCall call={0};
    if(vox_gles_glx.context && vox_gles_glx.display && vox_gles_glx.drawable && vox_gles_glx.read_drawable && vox_gles_glx.make_current)
        call.context=vox_gles_glx.context();
    if(call.context) {
        call.display=vox_gles_glx.display();call.draw=vox_gles_glx.drawable();call.read=vox_gles_glx.read_drawable();
        vox_gles_glx.make_current(call.display,0,0,NULL);
    }
    if(vox_gles_current && eglGetCurrentContext()!=vox_gles_current->context)
        eglMakeCurrent(vox_gles_current->display,EGL_NO_SURFACE,EGL_NO_SURFACE,vox_gles_current->context);
    return call;
}
static void vox_gles_end_call(VoxGLESCall *call) {
    if(!call->context)return;
    EGLDisplay display=eglGetCurrentDisplay();
    if(display!=EGL_NO_DISPLAY)eglMakeCurrent(display,EGL_NO_SURFACE,EGL_NO_SURFACE,EGL_NO_CONTEXT);
    vox_gles_glx.make_current(call->display,call->draw,call->read,call->context);
}
#define VOX_GLES_CALL VoxGLESCall vox_gles_call __attribute__((cleanup(vox_gles_end_call)))=vox_gles_begin_call()
static void vox_gles_queue(GLenum error) {
    if (!vox_gles_current || error == GL_NO_ERROR) return;
    for (unsigned i=0;i<vox_gles_current->error_count;i++)
        if (vox_gles_current->errors[i]==error) return;
    if (vox_gles_current->error_count<8)
        vox_gles_current->errors[vox_gles_current->error_count++]=error;
}
static int vox_gles_collect_errors(void) {
    GLenum error; int found=0;
    while ((error=glGetError())!=GL_NO_ERROR) { vox_gles_queue(error); found=1; }
    return found;
}
static void vox_gles_error(GLenum error) { vox_gles_collect_errors(); vox_gles_queue(error); }
static GLenum vox_gles_get_error(void) {
    if (!vox_gles_current) return glGetError();
    vox_gles_collect_errors();
    if (!vox_gles_current->error_count) return GL_NO_ERROR;
    GLenum result=vox_gles_current->errors[0];
    memmove(vox_gles_current->errors,vox_gles_current->errors+1,--vox_gles_current->error_count*sizeof(GLenum));
    return result;
}
static int vox_gles_has_extension(const char *list,const char *extension) {
    size_t length=strlen(extension);
    for (const char *at=list;at && (at=strstr(at,extension));at+=length)
        if ((at==list || at[-1]==' ') && (!at[length] || at[length]==' ')) return 1;
    return 0;
}
static const GLubyte *vox_gles_string(GLenum name) {
    if (name==0x93a8) return (const GLubyte*)""; /* ANGLE's requestable-extension list. */
    if (name!=GL_EXTENSIONS || !vox_gles_current) return glGetString(name);
    if (!vox_gles_current->extensions) {
        const char *actual=(const char*)glGetString(GL_EXTENSIONS);
        if (!actual) return NULL;
        const char *aliases=" GL_ANGLE_instanced_arrays GL_OES_vertex_array_object GL_EXT_draw_buffers GL_EXT_blend_minmax GL_OES_element_index_uint GL_OES_standard_derivatives";
        const char *dxt=vox_gles_has_extension(actual,"GL_EXT_texture_compression_s3tc") ? " GL_ANGLE_texture_compression_dxt3 GL_ANGLE_texture_compression_dxt5" : "";
        size_t length=strlen(actual)+strlen(aliases)+strlen(dxt)+1;
        vox_gles_current->extensions=malloc(length);
        if (!vox_gles_current->extensions) { vox_gles_error(GL_OUT_OF_MEMORY);return NULL; }
        snprintf(vox_gles_current->extensions,length,"%s%s%s",actual,aliases,dxt);
    }
    return (const GLubyte*)vox_gles_current->extensions;
}
static int vox_gles_query_count(GLenum pname) {
    switch (pname) {
    case GL_VIEWPORT: case GL_SCISSOR_BOX: case GL_COLOR_WRITEMASK:
    case GL_COLOR_CLEAR_VALUE: case GL_BLEND_COLOR: return 4;
    case GL_MAX_VIEWPORT_DIMS: case GL_ALIASED_LINE_WIDTH_RANGE:
    case GL_ALIASED_POINT_SIZE_RANGE: case GL_DEPTH_RANGE: return 2;
    case GL_COMPRESSED_TEXTURE_FORMATS: { GLint n=0;glGetIntegerv(GL_NUM_COMPRESSED_TEXTURE_FORMATS,&n);return n; }
    case GL_SHADER_BINARY_FORMATS: { GLint n=0;glGetIntegerv(GL_NUM_SHADER_BINARY_FORMATS,&n);return n; }
    case GL_PROGRAM_BINARY_FORMATS: { GLint n=0;glGetIntegerv(GL_NUM_PROGRAM_BINARY_FORMATS,&n);return n; }
    default:return 1;
    }
}
static int vox_gles_capacity(GLsizei capacity,int count,void *data,GLsizei *length) {
    if (length) *length=0;
    if (capacity<0) { vox_gles_error(GL_INVALID_VALUE);return 0; }
    if (count<0 || count>capacity || (count && !data)) { vox_gles_error(GL_INVALID_OPERATION);return 0; }
    if (length) *length=count;
    return 1;
}
static void vox_gles_get_Integerv(GLenum pname,GLsizei capacity,GLsizei *length,GLint *data) { if(vox_gles_capacity(capacity,vox_gles_query_count(pname),data,length)) glGetIntegerv(pname,data); }
static void vox_gles_get_Floatv(GLenum pname,GLsizei capacity,GLsizei *length,GLfloat *data) { if(vox_gles_capacity(capacity,vox_gles_query_count(pname),data,length)) glGetFloatv(pname,data); }
static void vox_gles_get_Booleanv(GLenum pname,GLsizei capacity,GLsizei *length,GLboolean *data) { if(vox_gles_capacity(capacity,vox_gles_query_count(pname),data,length)) glGetBooleanv(pname,data); }
static void vox_gles_get_Integer64v(GLenum pname,GLsizei capacity,GLsizei *length,GLint64 *data) { if(vox_gles_capacity(capacity,vox_gles_query_count(pname),data,length)) glGetInteger64v(pname,data); }
static void vox_gles_get_BufferParameteriv(GLenum target,GLenum pname,GLsizei capacity,GLsizei *length,GLint *data) { if(vox_gles_capacity(capacity,1,data,length)) glGetBufferParameteriv(target,pname,data); }
static void vox_gles_get_RenderbufferParameteriv(GLenum target,GLenum pname,GLsizei capacity,GLsizei *length,GLint *data) { if(vox_gles_capacity(capacity,1,data,length)) glGetRenderbufferParameteriv(target,pname,data); }
static void vox_gles_get_Shaderiv(GLuint object,GLenum pname,GLsizei capacity,GLsizei *length,GLint *data) { if(vox_gles_capacity(capacity,1,data,length)) glGetShaderiv(object,pname,data); }
static void vox_gles_get_Programiv(GLuint object,GLenum pname,GLsizei capacity,GLsizei *length,GLint *data) { if(vox_gles_capacity(capacity,pname==0x8267?3:1,data,length)) glGetProgramiv(object,pname,data); }
static void vox_gles_get_QueryObjectuiv(GLuint object,GLenum pname,GLsizei capacity,GLsizei *length,GLuint *data) { if(vox_gles_capacity(capacity,1,data,length)) glGetQueryObjectuiv(object,pname,data); }
static void vox_gles_get_SamplerParameterfv(GLuint object,GLenum pname,GLsizei capacity,GLsizei *length,GLfloat *data) { if(vox_gles_capacity(capacity,pname==0x1004?4:1,data,length)) glGetSamplerParameterfv(object,pname,data); }
static void vox_gles_get_TexParameterfv(GLenum target,GLenum pname,GLsizei capacity,GLsizei *length,GLfloat *data) { if(vox_gles_capacity(capacity,pname==0x1004 || pname==0x8b9d?4:1,data,length)) glGetTexParameterfv(target,pname,data); }
static void vox_gles_get_TexParameteriv(GLenum target,GLenum pname,GLsizei capacity,GLsizei *length,GLint *data) { if(vox_gles_capacity(capacity,pname==0x1004 || pname==0x8b9d?4:1,data,length)) glGetTexParameteriv(target,pname,data); }
static void vox_gles_get_VertexAttribfv(GLuint object,GLenum pname,GLsizei capacity,GLsizei *length,GLfloat *data) { if(vox_gles_capacity(capacity,pname==GL_CURRENT_VERTEX_ATTRIB?4:1,data,length)) glGetVertexAttribfv(object,pname,data); }
static void vox_gles_get_VertexAttribiv(GLuint object,GLenum pname,GLsizei capacity,GLsizei *length,GLint *data) { if(vox_gles_capacity(capacity,pname==GL_CURRENT_VERTEX_ATTRIB?4:1,data,length)) glGetVertexAttribiv(object,pname,data); }
static void vox_gles_get_VertexAttribPointerv(GLuint object,GLenum pname,GLsizei capacity,GLsizei *length,void* *data) { if(vox_gles_capacity(capacity,1,data,length)) glGetVertexAttribPointerv(object,pname,data); }
static void vox_gles_get_ActiveUniformBlockiv(GLuint program,GLuint index,GLenum pname,GLsizei capacity,GLsizei *length,GLint *data) {
    GLint count=1;
    if(pname==GL_UNIFORM_BLOCK_ACTIVE_UNIFORM_INDICES) glGetActiveUniformBlockiv(program,index,GL_UNIFORM_BLOCK_ACTIVE_UNIFORMS,&count);
    if(vox_gles_capacity(capacity,count,data,length)) glGetActiveUniformBlockiv(program,index,pname,data);
}
static void vox_gles_get_Internalformativ(GLenum target,GLenum format,GLenum pname,GLsizei capacity,GLsizei *length,GLint *data) {
    if(vox_gles_capacity(capacity,capacity,data,length)) glGetInternalformativ(target,format,pname,capacity,data);
}
static int vox_gles_pixel_size(GLenum format,GLenum type) {
    int channels;
    switch(format) {
    case GL_ALPHA:case GL_LUMINANCE:case GL_RED:case GL_RED_INTEGER:case GL_DEPTH_COMPONENT:channels=1;break;
    case GL_LUMINANCE_ALPHA:case GL_RG:case GL_RG_INTEGER:channels=2;break;
    case GL_RGB:case GL_RGB_INTEGER:channels=3;break;
    case GL_RGBA:case GL_RGBA_INTEGER:channels=4;break;
    case GL_DEPTH_STENCIL:channels=1;break;
    default:vox_gles_error(GL_INVALID_ENUM);return 0;
    }
    switch(type) {
    case GL_BYTE:case GL_UNSIGNED_BYTE:return channels;
    case GL_SHORT:case GL_UNSIGNED_SHORT:case GL_HALF_FLOAT:case 0x8d61:return channels*2;
    case GL_INT:case GL_UNSIGNED_INT:case GL_FLOAT:return channels*4;
    case GL_UNSIGNED_SHORT_4_4_4_4:case GL_UNSIGNED_SHORT_5_5_5_1:case GL_UNSIGNED_SHORT_5_6_5:return 2;
    case GL_UNSIGNED_INT_2_10_10_10_REV:case GL_UNSIGNED_INT_10F_11F_11F_REV:
    case GL_UNSIGNED_INT_5_9_9_9_REV:case GL_UNSIGNED_INT_24_8:return 4;
    case GL_FLOAT_32_UNSIGNED_INT_24_8_REV:return 8;
    default:vox_gles_error(GL_INVALID_ENUM);return 0;
    }
}
/* GLsizei dimensions are signed 32-bit. Reject overflow before multiplying. */
static int vox_gles_mul(uint64_t a,uint64_t b,uint64_t *out) {
    if (b && a>INT64_MAX/b) { vox_gles_error(GL_INVALID_OPERATION);return 0; }
    *out=a*b;return 1;
}
static int vox_gles_pixel_span(int width,int height,int depth,GLenum format,GLenum type,int pack,int volume,uint64_t *span) {
    *span=0;
    if(width<0 || height<0 || depth<0) {vox_gles_error(GL_INVALID_VALUE);return 0;}
    int size=vox_gles_pixel_size(format,type);if(!size)return 0;
    if(!width || !height || !depth)return 1;
    GLint alignment=4,row_length=0,skip_rows=0,skip_pixels=0,image_height=0,skip_images=0;
    glGetIntegerv(pack?GL_PACK_ALIGNMENT:GL_UNPACK_ALIGNMENT,&alignment);
    glGetIntegerv(pack?GL_PACK_ROW_LENGTH:GL_UNPACK_ROW_LENGTH,&row_length);
    glGetIntegerv(pack?GL_PACK_SKIP_ROWS:GL_UNPACK_SKIP_ROWS,&skip_rows);
    glGetIntegerv(pack?GL_PACK_SKIP_PIXELS:GL_UNPACK_SKIP_PIXELS,&skip_pixels);
    if(volume){glGetIntegerv(GL_UNPACK_IMAGE_HEIGHT,&image_height);glGetIntegerv(GL_UNPACK_SKIP_IMAGES,&skip_images);}
    if(alignment<=0 || row_length<0 || skip_rows<0 || skip_pixels<0 || image_height<0 || skip_images<0) {vox_gles_error(GL_INVALID_OPERATION);return 0;}
    uint64_t row=(uint64_t)(row_length?row_length:width)*size;
    row=(row+(unsigned)alignment-1)&~((uint64_t)alignment-1);
    uint64_t images,prefix,tail;
    if(!vox_gles_mul(row,(uint64_t)(image_height?image_height:height),&images)
       || !vox_gles_mul(images,(uint64_t)skip_images+depth-1,&prefix)
       || !vox_gles_mul(row,(uint64_t)skip_rows+height-1,&tail))return 0;
    uint64_t end=(uint64_t)skip_pixels*size+(uint64_t)width*size;
    if(prefix>INT64_MAX-tail || prefix+tail>INT64_MAX-end){vox_gles_error(GL_INVALID_OPERATION);return 0;}
    *span=prefix+tail+end;return 1;
}
static int vox_gles_transfer_fits(GLsizei capacity,const void *data,uint64_t span,int pack) {
    if(capacity<0){vox_gles_error(GL_INVALID_VALUE);return 0;}
    GLint buffer=0;glGetIntegerv(pack?GL_PIXEL_PACK_BUFFER_BINDING:GL_PIXEL_UNPACK_BUFFER_BINDING,&buffer);
    if(buffer) {
        GLint64 bytes=0;glGetBufferParameteri64v(pack?GL_PIXEL_PACK_BUFFER:GL_PIXEL_UNPACK_BUFFER,GL_BUFFER_SIZE,&bytes);
        uint64_t offset=(uintptr_t)data;
        if(bytes<0 || offset>(uint64_t)bytes || span>(uint64_t)bytes-offset){vox_gles_error(GL_INVALID_OPERATION);return 0;}
    } else if(span>(uint64_t)capacity || (span && !data)) {vox_gles_error(GL_INVALID_OPERATION);return 0;}
    return 1;
}
static void vox_gles_read_pixels(GLint x,GLint y,GLsizei width,GLsizei height,GLenum format,GLenum type,GLsizei capacity,GLsizei *length,GLsizei *columns,GLsizei *rows,void *data) {
    if(length)*length=0;if(columns)*columns=0;if(rows)*rows=0;
    uint64_t span;
    if(!vox_gles_pixel_span(width,height,1,format,type,1,0,&span) || !vox_gles_transfer_fits(capacity,data,span,1))return;
    vox_gles_collect_errors();glReadPixels(x,y,width,height,format,type,data);
    if(vox_gles_collect_errors())return;
    if(length)*length=(GLsizei)(span>INT_MAX?INT_MAX:span);
    if(columns)*columns=width;if(rows)*rows=height;
}
/* Zero texture rows with client unpack state isolated, including PBO bindings. */
static int vox_gles_zero_texture(GLenum target,GLint level,int width,int height,int depth,GLenum format,GLenum type,int volume) {
    int size=vox_gles_pixel_size(format,type);if(!size)return 0;
    if(width<=0 || height<=0 || depth<=0)return 1;
    if((uint64_t)width*size>SIZE_MAX){vox_gles_error(GL_OUT_OF_MEMORY);return 0;}
    void *row=calloc((size_t)width,(size_t)size);if(!row){vox_gles_error(GL_OUT_OF_MEMORY);return 0;}
    GLenum names[]={GL_UNPACK_ALIGNMENT,GL_UNPACK_ROW_LENGTH,GL_UNPACK_SKIP_PIXELS,GL_UNPACK_SKIP_ROWS,GL_UNPACK_IMAGE_HEIGHT,GL_UNPACK_SKIP_IMAGES};
    GLint saved[6],buffer=0;glGetIntegerv(GL_PIXEL_UNPACK_BUFFER_BINDING,&buffer);glBindBuffer(GL_PIXEL_UNPACK_BUFFER,0);
    for(int i=0;i<6;i++){glGetIntegerv(names[i],&saved[i]);glPixelStorei(names[i],i==0?1:0);}
    for(int z=0;z<depth;z++)for(int y=0;y<height;y++) {
        if(volume)glTexSubImage3D(target,level,0,y,z,width,1,1,format,type,row);
        else glTexSubImage2D(target,level,0,y,width,1,format,type,row);
    }
    for(int i=0;i<6;i++)glPixelStorei(names[i],saved[i]);
    glBindBuffer(GL_PIXEL_UNPACK_BUFFER,buffer);free(row);return 1;
}
static void vox_gles_tex_image2d(GLenum target,GLint level,GLint internal,GLsizei width,GLsizei height,GLint border,GLenum format,GLenum type,GLsizei capacity,const void *data) {
    if(capacity<0){vox_gles_error(GL_INVALID_VALUE);return;}
    GLint pbo=0;glGetIntegerv(GL_PIXEL_UNPACK_BUFFER_BINDING,&pbo);
    if(data || pbo){uint64_t span;if(!vox_gles_pixel_span(width,height,1,format,type,0,0,&span) || !vox_gles_transfer_fits(capacity,data,span,0))return;}
    vox_gles_collect_errors();glTexImage2D(target,level,internal,width,height,border,format,type,data);
    if(!vox_gles_collect_errors() && !data && !pbo)vox_gles_zero_texture(target,level,width,height,1,format,type,0);
}
/* On GLES3.1+ query real storage before checking client capacity, preserving
 * INVALID_VALUE for out-of-level uploads even when the client is also short. */
static int vox_gles_sub_image_bounds(GLenum target,int level,int x,int y,int z,int width,int height,int depth,int volume) {
    if(level<0 || x<0 || y<0 || z<0 || width<0 || height<0 || depth<0) {vox_gles_error(GL_INVALID_VALUE);return 0;}
    if(!vox_gles_current || !vox_gles_current->texture_level_parameter)return 1;
    if(volume ? target!=GL_TEXTURE_3D && target!=GL_TEXTURE_2D_ARRAY :
       target!=GL_TEXTURE_2D && (target<GL_TEXTURE_CUBE_MAP_POSITIVE_X || target>GL_TEXTURE_CUBE_MAP_NEGATIVE_Z)) {
        vox_gles_error(GL_INVALID_ENUM);return 0;
    }
    GLint w=0,h=0,d=1;vox_gles_collect_errors();
    vox_gles_current->texture_level_parameter(target,level,0x1000,&w);
    vox_gles_current->texture_level_parameter(target,level,0x1001,&h);
    if(volume)vox_gles_current->texture_level_parameter(target,level,0x8071,&d);
    if(vox_gles_collect_errors())return 0;
    if(w<=0 || h<=0 || d<=0)return 1;
    if(x>w || width>w-x || y>h || height>h-y || z>d || depth>d-z) {vox_gles_error(GL_INVALID_VALUE);return 0;}
    return 1;
}
static void vox_gles_tex_sub_image2d(GLenum target,GLint level,GLint x,GLint y,GLsizei width,GLsizei height,GLenum format,GLenum type,GLsizei capacity,const void *data) {
    if(!vox_gles_sub_image_bounds(target,level,x,y,0,width,height,1,0))return;
    uint64_t span;if(!vox_gles_pixel_span(width,height,1,format,type,0,0,&span) || !vox_gles_transfer_fits(capacity,data,span,0))return;
    glTexSubImage2D(target,level,x,y,width,height,format,type,data);
}
static void vox_gles_tex_image3d(GLenum target,GLint level,GLint internal,GLsizei width,GLsizei height,GLsizei depth,GLint border,GLenum format,GLenum type,GLsizei capacity,const void *data) {
    if(capacity<0){vox_gles_error(GL_INVALID_VALUE);return;}
    GLint pbo=0;glGetIntegerv(GL_PIXEL_UNPACK_BUFFER_BINDING,&pbo);
    if(data || pbo){uint64_t span;if(!vox_gles_pixel_span(width,height,depth,format,type,0,1,&span) || !vox_gles_transfer_fits(capacity,data,span,0))return;}
    vox_gles_collect_errors();glTexImage3D(target,level,internal,width,height,depth,border,format,type,data);
    if(!vox_gles_collect_errors() && !data && !pbo)vox_gles_zero_texture(target,level,width,height,depth,format,type,1);
}
static void vox_gles_tex_sub_image3d(GLenum target,GLint level,GLint x,GLint y,GLint z,GLsizei width,GLsizei height,GLsizei depth,GLenum format,GLenum type,GLsizei capacity,const void *data) {
    if(!vox_gles_sub_image_bounds(target,level,x,y,z,width,height,depth,1))return;
    uint64_t span;if(!vox_gles_pixel_span(width,height,depth,format,type,0,1,&span) || !vox_gles_transfer_fits(capacity,data,span,0))return;
    glTexSubImage3D(target,level,x,y,z,width,height,depth,format,type,data);
}
static void vox_gles_buffer_data(GLenum target,GLsizeiptr size,const void *data,GLenum usage) {
    vox_gles_collect_errors();glBufferData(target,size,data,usage);
    if(vox_gles_collect_errors() || data || size<=0)return;
    const unsigned char zero[16384]={0};
    for(GLsizeiptr at=0;at<size;) {GLsizeiptr count=size-at;if(count>(GLsizeiptr)sizeof(zero))count=sizeof(zero);glBufferSubData(target,at,count,zero);at+=count;}
}
#include "gles_storage_linux.h"
#include "gles_draw_linux.h"
#define glDrawArrays vox_gles_draw_arrays
#define glDrawArraysInstanced vox_gles_draw_arrays_instanced
#define glDrawElements vox_gles_draw_elements
#define glDrawElementsInstanced vox_gles_draw_elements_instanced
#define glDrawRangeElements vox_gles_draw_range_elements
#define glBindBuffer vox_gles_bind_buffer
#include "gles_shaders_linux.h"
#define glCompileShader vox_gles_compile_shader
#define glTexStorage2D vox_gles_tex_storage2d
#define glTexStorage3D vox_gles_tex_storage3d
#define glRenderbufferStorage vox_gles_renderbuffer_storage
#define glRenderbufferStorageMultisample vox_gles_renderbuffer_storage_multisample
#define glGetIntegervRobustANGLE vox_gles_get_Integerv
#define glGetFloatvRobustANGLE vox_gles_get_Floatv
#define glGetBooleanvRobustANGLE vox_gles_get_Booleanv
#define glGetInteger64vRobustANGLE vox_gles_get_Integer64v
#define glGetBufferParameterivRobustANGLE vox_gles_get_BufferParameteriv
#define glGetRenderbufferParameterivRobustANGLE vox_gles_get_RenderbufferParameteriv
#define glGetShaderivRobustANGLE vox_gles_get_Shaderiv
#define glGetProgramivRobustANGLE vox_gles_get_Programiv
#define glGetQueryObjectuivRobustANGLE vox_gles_get_QueryObjectuiv
#define glGetSamplerParameterfvRobustANGLE vox_gles_get_SamplerParameterfv
#define glGetTexParameterfvRobustANGLE vox_gles_get_TexParameterfv
#define glGetTexParameterivRobustANGLE vox_gles_get_TexParameteriv
#define glGetVertexAttribfvRobustANGLE vox_gles_get_VertexAttribfv
#define glGetVertexAttribivRobustANGLE vox_gles_get_VertexAttribiv
#define glGetVertexAttribPointervRobustANGLE vox_gles_get_VertexAttribPointerv
#define glGetActiveUniformBlockivRobustANGLE vox_gles_get_ActiveUniformBlockiv
#define glGetInternalformativRobustANGLE vox_gles_get_Internalformativ
#define glGetError vox_gles_get_error
#define glGetString vox_gles_string
#define glReadPixelsRobustANGLE vox_gles_read_pixels
#define glTexImage2DRobustANGLE vox_gles_tex_image2d
#define glTexSubImage2DRobustANGLE vox_gles_tex_sub_image2d
#define glTexImage3DRobustANGLE vox_gles_tex_image3d
#define glTexSubImage3DRobustANGLE vox_gles_tex_sub_image3d
#define glBufferData vox_gles_buffer_data
#define glRequestExtensionANGLE(name) ((void)(name))
#define glGenVertexArraysOES glGenVertexArrays
#define glDeleteVertexArraysOES glDeleteVertexArrays
#define glBindVertexArrayOES glBindVertexArray
#define glIsVertexArrayOES glIsVertexArray
#define glVertexAttribDivisorANGLE glVertexAttribDivisor
#define glDrawArraysInstancedANGLE glDrawArraysInstanced
#define glDrawElementsInstancedANGLE glDrawElementsInstanced
#define glDrawBuffersEXT glDrawBuffers
#endif
