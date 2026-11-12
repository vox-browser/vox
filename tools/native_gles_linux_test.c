/* Execute the actual Linux service on distribution EGL/GLES, with CPU canaries. */
#include <assert.h>
#include <stdio.h>
#include <string.h>
#include "../webgl/native_egl.h"
static void pixels_and_bounds(void *context) {
    assert(vox_egl_allocate_surface(context,4,4,1,1));
    vox_egl_clear_drawing_buffer(context);
    unsigned char pixels[64];memset(pixels,0xcc,sizeof(pixels));
    assert(vox_gl_read_pixels(0,0,4,4,GL_RGBA,GL_UNSIGNED_BYTE,sizeof(pixels),pixels)==64);
    for(unsigned i=0;i<64;i++)assert(pixels[i]==0);
    struct { unsigned before; unsigned char pixel[4]; unsigned after; } bounded={0x12345678,{1,2,3,4},0x87654321};
    assert(vox_gl_read_pixels(0,0,4,4,GL_RGBA,GL_UNSIGNED_BYTE,4,bounded.pixel)==0);
    assert(vox_gl_get_error()==GL_INVALID_OPERATION);
    assert(bounded.before==0x12345678 && bounded.after==0x87654321 && bounded.pixel[0]==1);
    glPixelStorei(GL_PACK_ROW_LENGTH,8);glPixelStorei(GL_PACK_SKIP_ROWS,2);
    assert(vox_gl_read_pixels(0,0,1,1,GL_RGBA,GL_UNSIGNED_BYTE,4,bounded.pixel)==0);
    assert(vox_gl_get_error()==GL_INVALID_OPERATION);
    glPixelStorei(GL_PACK_ROW_LENGTH,0);glPixelStorei(GL_PACK_SKIP_ROWS,0);
    GLint small=0x12345678;vox_gles_get_Integerv(GL_VIEWPORT,1,NULL,&small);
    assert(small==0x12345678 && vox_gl_get_error()==GL_INVALID_OPERATION);
    GLint viewport[4];vox_gles_get_Integerv(GL_VIEWPORT,4,NULL,viewport);assert(viewport[2]==4);
    assert(vox_gl_vertex_attrib_parameter(0,GL_CURRENT_VERTEX_ATTRIB)==0);
    assert(vox_gl_get_error()==GL_INVALID_OPERATION);
    vox_gl_read_pixels_to_buffer(0,0,1,1,GL_RGBA,GL_UNSIGNED_BYTE,0);
    assert(vox_gl_get_error()==GL_INVALID_OPERATION);
}
static void initialized_resources(void) {
    GLuint buffer=vox_gl_gen_object(0);vox_gl_bind_buffer(GL_ARRAY_BUFFER,buffer);
    vox_gl_buffer_data(GL_ARRAY_BUFFER,32771,NULL,GL_STATIC_DRAW);
    unsigned char data[32771];memset(data,0xcc,sizeof(data));
    assert(vox_gl_read_buffer_sub_data(GL_ARRAY_BUFFER,0,sizeof(data),data));
    for(unsigned i=0;i<sizeof(data);i++)assert(data[i]==0);
    GLuint texture=vox_gl_gen_object(3);vox_gl_bind_texture(GL_TEXTURE_2D,texture);
    vox_gl_tex_image2d(GL_TEXTURE_2D,0,GL_RGBA8,2,2,0,GL_RGBA,GL_UNSIGNED_BYTE,0,NULL);
    GLuint fbo=vox_gl_gen_object(1);vox_gl_bind_framebuffer(GL_FRAMEBUFFER,fbo);
    vox_gl_framebuffer_texture(GL_FRAMEBUFFER,GL_COLOR_ATTACHMENT0,GL_TEXTURE_2D,texture,0);
    assert(vox_gl_framebuffer_status(GL_FRAMEBUFFER)==GL_FRAMEBUFFER_COMPLETE);
    unsigned char pixels[16];memset(pixels,0xcc,sizeof(pixels));
    assert(vox_gl_read_pixels(0,0,2,2,GL_RGBA,GL_UNSIGNED_BYTE,16,pixels)==16);
    for(unsigned i=0;i<16;i++)assert(pixels[i]==0);
    const unsigned char short_upload[4]={255,0,0,255};
    vox_gl_tex_sub_image2d(GL_TEXTURE_2D,0,0,0,2,2,GL_RGBA,GL_UNSIGNED_BYTE,4,short_upload);
    assert(vox_gl_get_error()==GL_INVALID_OPERATION);
    vox_gl_delete_object(1,fbo);vox_gl_delete_object(3,texture);vox_gl_delete_object(0,buffer);
}
static GLuint shader(GLenum type,const char *source) {
    GLuint result=vox_gl_create_shader(type);vox_gl_shader_source(result,source,(int)strlen(source));vox_gl_compile_shader(result);
    if(!vox_gl_shader_parameter(result,GL_COMPILE_STATUS)){char log[4096];vox_gl_shader_log(result,sizeof(log),log);fprintf(stderr,"%s\n",log);assert(0);}
    return result;
}
static void shader_pixels(void *context,int version) {
    assert(vox_egl_allocate_surface(context,4,4,0,0));vox_egl_clear_drawing_buffer(context);
    GLuint vertex=shader(GL_VERTEX_SHADER,version==2?"attribute vec2 p;void main(){gl_Position=vec4(p,0,1);}":"#version 300 es\nin vec2 p;void main(){gl_Position=vec4(p,0,1);}");
    GLuint fragment=shader(GL_FRAGMENT_SHADER,version==2?"precision mediump float;void main(){gl_FragColor=vec4(1,0,0,1);}":"#version 300 es\nprecision mediump float;out vec4 c;void main(){c=vec4(1,0,0,1);}");
    GLuint program=vox_gl_create_program();vox_gl_attach_shader(program,vertex);vox_gl_attach_shader(program,fragment);vox_gl_bind_attrib_location(program,0,"p");vox_gl_link_program(program);assert(vox_gl_program_parameter(program,GL_LINK_STATUS));vox_gl_use_program(program);
    GLuint vbo=vox_gl_gen_object(0);vox_gl_bind_buffer(GL_ARRAY_BUFFER,vbo);
    float vertices[]={-1,-1,3,-1,-1,3};vox_gl_buffer_data(GL_ARRAY_BUFFER,sizeof(vertices),vertices,GL_STATIC_DRAW);
    vox_gl_vertex_attrib_pointer(0,2,GL_FLOAT,0,0,0);vox_gl_vertex_attrib_enable(0,1);
    vox_gl_draw_arrays(GL_TRIANGLES,0,3);
    if(version==3) {
        GLuint indices=vox_gl_gen_object(0);vox_gl_bind_buffer(GL_ELEMENT_ARRAY_BUFFER,indices);
        const unsigned short values[]={0,1,2,65535};
        vox_gl_buffer_data(GL_ELEMENT_ARRAY_BUFFER,sizeof(values),values,GL_STATIC_DRAW);
        assert(glIsEnabled(GL_PRIMITIVE_RESTART_FIXED_INDEX));
        vox_gl_draw_elements(GL_TRIANGLES,4,GL_UNSIGNED_SHORT,0);
        assert(vox_gl_get_error()==GL_NO_ERROR);
        vox_gl_delete_object(0,indices);
    }
    unsigned char pixels[64];assert(vox_gl_read_pixels(0,0,4,4,GL_RGBA,GL_UNSIGNED_BYTE,64,pixels)==64);
    for(unsigned i=0;i<64;i+=4)assert(pixels[i]==255 && pixels[i+1]==0 && pixels[i+2]==0 && pixels[i+3]==255);
    vox_gl_delete_object(0,vbo);vox_gl_delete_shader(vertex);vox_gl_delete_shader(fragment);vox_gl_delete_program(program);assert(vox_gl_get_error()==GL_NO_ERROR);
}

static void immutable_and_renderbuffer_initialization(void) {
    GLuint texture=vox_gl_gen_object(3),fbo=vox_gl_gen_object(1);
    vox_gl_bind_texture(GL_TEXTURE_2D,texture);vox_gl_tex_storage2d(GL_TEXTURE_2D,3,GL_RGBA8,4,4);
    vox_gl_bind_framebuffer(GL_FRAMEBUFFER,fbo);
    for(int level=0;level<3;level++) {
        int size=4>>level;vox_gl_framebuffer_texture(GL_FRAMEBUFFER,GL_COLOR_ATTACHMENT0,GL_TEXTURE_2D,texture,level);
        unsigned char pixels[64];memset(pixels,0xcc,sizeof(pixels));
        assert(vox_gl_read_pixels(0,0,size,size,GL_RGBA,GL_UNSIGNED_BYTE,sizeof(pixels),pixels)==size*size*4);
        for(int i=0;i<size*size*4;i++)assert(pixels[i]==0);
    }
    vox_gl_tex_sub_image2d(GL_TEXTURE_2D,0,0,0,5,5,GL_RGBA,GL_UNSIGNED_BYTE,0,NULL);
    assert(vox_gl_get_error()==GL_INVALID_VALUE);
    GLuint array=vox_gl_gen_object(3);vox_gl_bind_texture(GL_TEXTURE_2D_ARRAY,array);
    vox_gl_tex_storage3d(GL_TEXTURE_2D_ARRAY,2,GL_RGBA8,2,2,3);
    vox_gl_framebuffer_texture_layer(GL_FRAMEBUFFER,GL_COLOR_ATTACHMENT0,array,1,2);
    unsigned char pixel[4]={1,2,3,4};assert(vox_gl_read_pixels(0,0,1,1,GL_RGBA,GL_UNSIGNED_BYTE,4,pixel)==4);
    assert(!pixel[0]&&!pixel[1]&&!pixel[2]&&!pixel[3]);
    GLuint renderbuffer=vox_gl_gen_object(2);vox_gl_bind_renderbuffer(GL_RENDERBUFFER,renderbuffer);
    glColorMask(0,0,0,0);glEnable(GL_SCISSOR_TEST);glScissor(0,0,0,0);
    vox_gl_renderbuffer_storage(GL_RENDERBUFFER,GL_RGBA8,2,2);
    GLboolean mask[4];glGetBooleanv(GL_COLOR_WRITEMASK,mask);assert(!mask[0]&&!mask[1]&&!mask[2]&&!mask[3]);assert(glIsEnabled(GL_SCISSOR_TEST));
    vox_gl_framebuffer_renderbuffer(GL_FRAMEBUFFER,GL_COLOR_ATTACHMENT0,GL_RENDERBUFFER,renderbuffer);
    unsigned char pixels[16];memset(pixels,0xcc,sizeof(pixels));assert(vox_gl_read_pixels(0,0,2,2,GL_RGBA,GL_UNSIGNED_BYTE,16,pixels)==16);
    for(int i=0;i<16;i++)assert(!pixels[i]);
    glDisable(GL_SCISSOR_TEST);glColorMask(1,1,1,1);
    vox_gl_delete_object(1,fbo);vox_gl_delete_object(2,renderbuffer);vox_gl_delete_object(3,array);vox_gl_delete_object(3,texture);assert(vox_gl_get_error()==GL_NO_ERROR);
}
static void pbo_transfer_bounds(void) {
    GLuint buffer=vox_gl_gen_object(0);vox_gl_bind_buffer(GL_PIXEL_UNPACK_BUFFER,buffer);
    unsigned char red[16]={255,0,0,255,255,0,0,255,255,0,0,255,255,0,0,255};vox_gl_buffer_data(GL_PIXEL_UNPACK_BUFFER,16,red,GL_STATIC_DRAW);
    GLuint texture=vox_gl_gen_object(3);vox_gl_bind_texture(GL_TEXTURE_2D,texture);
    vox_gl_tex_image2d(GL_TEXTURE_2D,0,GL_RGBA8,2,2,0,GL_RGBA,GL_UNSIGNED_BYTE,0,NULL);
    assert(vox_gl_get_error()==GL_NO_ERROR);
    vox_gl_tex_sub_image2d(GL_TEXTURE_2D,0,0,0,2,2,GL_RGBA,GL_UNSIGNED_BYTE,0,(void*)4);
    assert(vox_gl_get_error()==GL_INVALID_OPERATION);vox_gl_bind_buffer(GL_PIXEL_UNPACK_BUFFER,0);
    GLuint fbo=vox_gl_gen_object(1);vox_gl_bind_framebuffer(GL_FRAMEBUFFER,fbo);vox_gl_framebuffer_texture(GL_FRAMEBUFFER,GL_COLOR_ATTACHMENT0,GL_TEXTURE_2D,texture,0);
    unsigned char pixels[16];assert(vox_gl_read_pixels(0,0,2,2,GL_RGBA,GL_UNSIGNED_BYTE,16,pixels)==16);assert(!memcmp(pixels,red,16));
    vox_gl_bind_buffer(GL_PIXEL_PACK_BUFFER,buffer);vox_gl_buffer_data(GL_PIXEL_PACK_BUFFER,4,NULL,GL_STREAM_READ);
    assert(vox_gl_read_pixels(0,0,2,2,GL_RGBA,GL_UNSIGNED_BYTE,0,NULL)==0);assert(vox_gl_get_error()==GL_INVALID_OPERATION);
    vox_gl_buffer_data(GL_PIXEL_PACK_BUFFER,16,NULL,GL_STREAM_READ);
    assert(vox_gl_read_pixels(0,0,2,2,GL_RGBA,GL_UNSIGNED_BYTE,0,NULL)==16);
    assert(vox_gl_read_buffer_sub_data(GL_PIXEL_PACK_BUFFER,0,16,pixels));assert(!memcmp(pixels,red,16));
    vox_gl_bind_buffer(GL_PIXEL_PACK_BUFFER,0);vox_gl_delete_object(0,buffer);vox_gl_delete_object(1,fbo);vox_gl_delete_object(3,texture);assert(vox_gl_get_error()==GL_NO_ERROR);
}
static void shader_validation_rejects_dynamic_webgl1_loops(void) {
    const char *original="uniform int n;void main(){for(int i=0;i<n;i++){}gl_Position=vec4(0.0);}";
    GLuint shader=vox_gl_create_shader(GL_VERTEX_SHADER);vox_gl_shader_source(shader,original,(int)strlen(original));vox_gl_compile_shader(shader);
    assert(!vox_gl_shader_parameter(shader,GL_COMPILE_STATUS));
    char source[256];vox_gl_get_shader_source(shader,sizeof(source),source);assert(!strcmp(source,original));
    vox_gl_delete_shader(shader);assert(vox_gl_get_error()==GL_NO_ERROR);
}

int main(void) {
    for(int version=2;version<=3;version++) {
        void *context=vox_egl_create(version);assert(context);
        printf("WebGL%d: %s / %s\n",version-1,vox_gl_string(GL_VENDOR),vox_gl_string(GL_RENDERER));
        assert(!strstr(vox_gl_string(GL_RENDERER),"ANGLE"));
        assert(strstr(vox_gl_string(GL_EXTENSIONS),"GL_ANGLE_instanced_arrays"));
        assert(!*vox_gl_string(0x93a8));assert(vox_gl_get_error()==GL_NO_ERROR);
        GLint flags=0;glGetIntegerv(0x821e,&flags);assert(flags&4);
        pixels_and_bounds(context);initialized_resources();immutable_and_renderbuffer_initialization();if(version==3)pbo_transfer_bounds();shader_pixels(context,version);
        if(version==2)shader_validation_rejects_dynamic_webgl1_loops();
        void *other=vox_egl_create(3);assert(other);GLint small=7;vox_gles_get_Integerv(GL_VIEWPORT,0,NULL,&small);
        assert(vox_egl_make_current(context));assert(vox_gl_get_error()==GL_NO_ERROR);
        assert(vox_egl_make_current(other));assert(vox_gl_get_error()==GL_INVALID_OPERATION);vox_egl_destroy(other);assert(vox_egl_make_current(context));
        vox_egl_destroy(context);
    }
    FILE *maps=fopen("/proc/self/maps","r");assert(maps);
    char line[4096];int mesa=0;
    while(fgets(line,sizeof(line),maps)) {
        assert(!strstr(line,"libEGL_angle") && !strstr(line,"libGLESv2_angle") && !strstr(line,"libANGLE"));
        if(strstr(line,"libEGL_mesa"))mesa=1;
    }
    fclose(maps);assert(mesa);
    puts("Native Linux GLES context, shader, initialization and bounded transfer checks passed");
}
