#ifndef VOX_GLES_STORAGE_LINUX_H
#define VOX_GLES_STORAGE_LINUX_H
/* Sized GLES storage accepted by this boundary must have a defined initializer. */
static int vox_gles_storage_format(GLenum internal,GLenum *format,GLenum *type) {
    *type=GL_UNSIGNED_BYTE;
    switch(internal) {
    case 0x822a:*format=GL_RED;*type=GL_UNSIGNED_SHORT;return 1;
    case 0x822c:*format=GL_RG;*type=GL_UNSIGNED_SHORT;return 1;
    case 0x8054:*format=GL_RGB;*type=GL_UNSIGNED_SHORT;return 1;
    case 0x805b:*format=GL_RGBA;*type=GL_UNSIGNED_SHORT;return 1;
    case 0x8f98:*format=GL_RED;*type=GL_SHORT;return 1;
    case 0x8f99:*format=GL_RG;*type=GL_SHORT;return 1;
    case 0x8f9a:*format=GL_RGB;*type=GL_SHORT;return 1;
    case 0x8f9b:*format=GL_RGBA;*type=GL_SHORT;return 1;
    case GL_R8:*format=GL_RED;return 1;
    case GL_RG8:*format=GL_RG;return 1;
    case GL_RGB8:case GL_SRGB8:*format=GL_RGB;return 1;
    case GL_RGBA8:case GL_SRGB8_ALPHA8:*format=GL_RGBA;return 1;
    case GL_R8_SNORM:*format=GL_RED;*type=GL_BYTE;return 1;
    case GL_RG8_SNORM:*format=GL_RG;*type=GL_BYTE;return 1;
    case GL_RGB8_SNORM:*format=GL_RGB;*type=GL_BYTE;return 1;
    case GL_RGBA8_SNORM:*format=GL_RGBA;*type=GL_BYTE;return 1;
    case GL_R16F:case GL_R32F:*format=GL_RED;*type=GL_FLOAT;return 1;
    case GL_RG16F:case GL_RG32F:*format=GL_RG;*type=GL_FLOAT;return 1;
    case GL_RGB16F:case GL_RGB32F:case GL_R11F_G11F_B10F:case GL_RGB9_E5:*format=GL_RGB;*type=GL_FLOAT;return 1;
    case GL_RGBA16F:case GL_RGBA32F:*format=GL_RGBA;*type=GL_FLOAT;return 1;
    case GL_RGB565:*format=GL_RGB;*type=GL_UNSIGNED_SHORT_5_6_5;return 1;
    case GL_RGBA4:*format=GL_RGBA;*type=GL_UNSIGNED_SHORT_4_4_4_4;return 1;
    case GL_RGB5_A1:*format=GL_RGBA;*type=GL_UNSIGNED_SHORT_5_5_5_1;return 1;
    case GL_RGB10_A2:*format=GL_RGBA;*type=GL_UNSIGNED_INT_2_10_10_10_REV;return 1;
    case GL_RGB10_A2UI:*format=GL_RGBA_INTEGER;*type=GL_UNSIGNED_INT_2_10_10_10_REV;return 1;
    case GL_DEPTH_COMPONENT16:*format=GL_DEPTH_COMPONENT;*type=GL_UNSIGNED_SHORT;return 1;
    case GL_DEPTH_COMPONENT24:*format=GL_DEPTH_COMPONENT;*type=GL_UNSIGNED_INT;return 1;
    case GL_DEPTH_COMPONENT32F:*format=GL_DEPTH_COMPONENT;*type=GL_FLOAT;return 1;
    case GL_DEPTH24_STENCIL8:*format=GL_DEPTH_STENCIL;*type=GL_UNSIGNED_INT_24_8;return 1;
    case GL_DEPTH32F_STENCIL8:*format=GL_DEPTH_STENCIL;*type=GL_FLOAT_32_UNSIGNED_INT_24_8_REV;return 1;
    case GL_R8I:*format=GL_RED_INTEGER;*type=GL_BYTE;return 1;
    case GL_R8UI:*format=GL_RED_INTEGER;*type=GL_UNSIGNED_BYTE;return 1;
    case GL_R16I:*format=GL_RED_INTEGER;*type=GL_SHORT;return 1;
    case GL_R16UI:*format=GL_RED_INTEGER;*type=GL_UNSIGNED_SHORT;return 1;
    case GL_R32I:*format=GL_RED_INTEGER;*type=GL_INT;return 1;
    case GL_R32UI:*format=GL_RED_INTEGER;*type=GL_UNSIGNED_INT;return 1;
    case GL_RG8I:*format=GL_RG_INTEGER;*type=GL_BYTE;return 1;
    case GL_RG8UI:*format=GL_RG_INTEGER;*type=GL_UNSIGNED_BYTE;return 1;
    case GL_RG16I:*format=GL_RG_INTEGER;*type=GL_SHORT;return 1;
    case GL_RG16UI:*format=GL_RG_INTEGER;*type=GL_UNSIGNED_SHORT;return 1;
    case GL_RG32I:*format=GL_RG_INTEGER;*type=GL_INT;return 1;
    case GL_RG32UI:*format=GL_RG_INTEGER;*type=GL_UNSIGNED_INT;return 1;
    case GL_RGB8I:*format=GL_RGB_INTEGER;*type=GL_BYTE;return 1;
    case GL_RGB8UI:*format=GL_RGB_INTEGER;*type=GL_UNSIGNED_BYTE;return 1;
    case GL_RGB16I:*format=GL_RGB_INTEGER;*type=GL_SHORT;return 1;
    case GL_RGB16UI:*format=GL_RGB_INTEGER;*type=GL_UNSIGNED_SHORT;return 1;
    case GL_RGB32I:*format=GL_RGB_INTEGER;*type=GL_INT;return 1;
    case GL_RGB32UI:*format=GL_RGB_INTEGER;*type=GL_UNSIGNED_INT;return 1;
    case GL_RGBA8I:*format=GL_RGBA_INTEGER;*type=GL_BYTE;return 1;
    case GL_RGBA8UI:*format=GL_RGBA_INTEGER;*type=GL_UNSIGNED_BYTE;return 1;
    case GL_RGBA16I:*format=GL_RGBA_INTEGER;*type=GL_SHORT;return 1;
    case GL_RGBA16UI:*format=GL_RGBA_INTEGER;*type=GL_UNSIGNED_SHORT;return 1;
    case GL_RGBA32I:*format=GL_RGBA_INTEGER;*type=GL_INT;return 1;
    case GL_RGBA32UI:*format=GL_RGBA_INTEGER;*type=GL_UNSIGNED_INT;return 1;
    default:return 0;
    }
}
static int vox_gles_compressed_block(GLenum format,int *width,int *height,int *bytes) {
    *width=*height=4;*bytes=16;
    switch(format) {
    case 0x83f0:case 0x83f1:case 0x8c4c:case 0x8c4d: /* BC1 */
    case 0x8dbb:case 0x8dbc: /* RGTC1 */
    case 0x9270:case 0x9271:case 0x9274:case 0x9275:case 0x9276:case 0x9277:*bytes=8;return 1;
    case 0x83f2:case 0x83f3:case 0x8c4e:case 0x8c4f: /* BC2/3 */
    case 0x8dbd:case 0x8dbe: /* RGTC2 */
    case 0x9272:case 0x9273:case 0x9278:case 0x9279: /* EAC/ETC2 */
    case 0x8e8c:case 0x8e8d:case 0x8e8e:case 0x8e8f:return 1; /* BPTC */
    default:break;
    }
    unsigned index=format>=0x93d0 && format<=0x93dd?format-0x93d0:format-0x93b0;
    if(index<14) {
        const int dimensions[14][2]={{4,4},{5,4},{5,5},{6,5},{6,6},{8,5},{8,6},{8,8},{10,5},{10,6},{10,8},{10,10},{12,10},{12,12}};
        *width=dimensions[index][0];*height=dimensions[index][1];return 1;
    }
    return 0;
}
static int vox_gles_zero_compressed(GLenum target,int level,GLenum internal,int width,int height,int depth,int volume) {
    int bw,bh,bytes;if(!vox_gles_compressed_block(internal,&bw,&bh,&bytes))return 0;
    size_t size=((size_t)width+bw-1)/bw*bytes;
    void *row=calloc(1,size?size:1);if(!row){vox_gles_error(GL_OUT_OF_MEMORY);return 0;}
    GLint buffer=0;glGetIntegerv(GL_PIXEL_UNPACK_BUFFER_BINDING,&buffer);glBindBuffer(GL_PIXEL_UNPACK_BUFFER,0);
    for(int z=0;z<depth;z++)for(int y=0;y<height;y+=bh) {
        int rows=height-y<bh?height-y:bh;
        if(volume)glCompressedTexSubImage3D(target,level,0,y,z,width,rows,1,internal,(GLsizei)size,row);
        else glCompressedTexSubImage2D(target,level,0,y,width,rows,internal,(GLsizei)size,row);
    }
    glBindBuffer(GL_PIXEL_UNPACK_BUFFER,buffer);free(row);return 1;
}
static void vox_gles_tex_storage(GLenum target,int levels,GLenum internal,int width,int height,int depth,int volume) {
    GLenum format=0,type=0;int bw,bh,bytes;
    int compressed=vox_gles_compressed_block(internal,&bw,&bh,&bytes);
    if(!compressed && !vox_gles_storage_format(internal,&format,&type)) {vox_gles_error(GL_INVALID_ENUM);return;}
    vox_gles_collect_errors();
    if(volume)glTexStorage3D(target,levels,internal,width,height,depth);
    else glTexStorage2D(target,levels,internal,width,height);
    if(vox_gles_collect_errors())return;
    for(int level=0;level<levels;level++) {
        int faces=target==GL_TEXTURE_CUBE_MAP?6:1;
        for(int face=0;face<faces;face++) {
            GLenum image=faces==6?GL_TEXTURE_CUBE_MAP_POSITIVE_X+face:target;
            if(compressed)vox_gles_zero_compressed(image,level,internal,width,height,depth,volume);
            else vox_gles_zero_texture(image,level,width,height,depth,format,type,volume);
        }
        width=width>1?width/2:1;height=height>1?height/2:1;
        if(target==GL_TEXTURE_3D)depth=depth>1?depth/2:1;
    }
}
static void vox_gles_tex_storage2d(GLenum target,int levels,GLenum internal,int width,int height) {vox_gles_tex_storage(target,levels,internal,width,height,1,0);}
static void vox_gles_tex_storage3d(GLenum target,int levels,GLenum internal,int width,int height,int depth) {vox_gles_tex_storage(target,levels,internal,width,height,depth,1);}
static void vox_gles_initialize_renderbuffer(GLenum internal) {
    GLint object=0;glGetIntegerv(GL_RENDERBUFFER_BINDING,&object);if(!object)return;
    int depth=internal==GL_DEPTH_COMPONENT16 || internal==GL_DEPTH_COMPONENT24 || internal==GL_DEPTH_COMPONENT32F;
    int stencil=internal==GL_STENCIL_INDEX8;
    if(internal==GL_DEPTH24_STENCIL8 || internal==GL_DEPTH32F_STENCIL8)depth=stencil=1;
    GLint framebuffer=0;glGetIntegerv(GL_DRAW_FRAMEBUFFER_BINDING,&framebuffer);
    GLuint temporary;glGenFramebuffers(1,&temporary);glBindFramebuffer(GL_DRAW_FRAMEBUFFER,temporary);
    GLenum attachment=depth&&stencil?GL_DEPTH_STENCIL_ATTACHMENT:depth?GL_DEPTH_ATTACHMENT:stencil?GL_STENCIL_ATTACHMENT:GL_COLOR_ATTACHMENT0;
    glFramebufferRenderbuffer(GL_DRAW_FRAMEBUFFER,attachment,GL_RENDERBUFFER,object);
    if(depth || stencil){GLenum none=GL_NONE;glDrawBuffers(1,&none);}
    if(glCheckFramebufferStatus(GL_DRAW_FRAMEBUFFER)==GL_FRAMEBUFFER_COMPLETE) {
        GLboolean scissor=glIsEnabled(GL_SCISSOR_TEST),mask[4],depth_mask;
        GLint front,back;glGetBooleanv(GL_COLOR_WRITEMASK,mask);glGetBooleanv(GL_DEPTH_WRITEMASK,&depth_mask);
        glGetIntegerv(GL_STENCIL_WRITEMASK,&front);glGetIntegerv(GL_STENCIL_BACK_WRITEMASK,&back);
        glDisable(GL_SCISSOR_TEST);glColorMask(1,1,1,1);glDepthMask(1);glStencilMaskSeparate(GL_FRONT,~0u);glStencilMaskSeparate(GL_BACK,~0u);
        GLfloat zero[4]={0};GLint signed_zero[4]={0};GLuint unsigned_zero[4]={0};
        if(depth && stencil)glClearBufferfi(GL_DEPTH_STENCIL,0,0,0);
        else if(depth)glClearBufferfv(GL_DEPTH,0,zero);
        else if(stencil)glClearBufferiv(GL_STENCIL,0,signed_zero);
        else {
            GLenum format,type;vox_gles_storage_format(internal,&format,&type);
            int integer=format==GL_RED_INTEGER || format==GL_RG_INTEGER || format==GL_RGB_INTEGER || format==GL_RGBA_INTEGER;
            if(integer && (type==GL_BYTE || type==GL_SHORT || type==GL_INT))glClearBufferiv(GL_COLOR,0,signed_zero);
            else if(integer)glClearBufferuiv(GL_COLOR,0,unsigned_zero);
            else glClearBufferfv(GL_COLOR,0,zero);
        }
        if(scissor)glEnable(GL_SCISSOR_TEST);
        glColorMask(mask[0],mask[1],mask[2],mask[3]);glDepthMask(depth_mask);
        glStencilMaskSeparate(GL_FRONT,(GLuint)front);glStencilMaskSeparate(GL_BACK,(GLuint)back);
    }
    glBindFramebuffer(GL_DRAW_FRAMEBUFFER,(GLuint)framebuffer);glDeleteFramebuffers(1,&temporary);
}
static void vox_gles_renderbuffer_storage(GLenum target,GLenum internal,int width,int height) {
    GLenum format,type;
    if(internal!=GL_STENCIL_INDEX8 && !vox_gles_storage_format(internal,&format,&type)){vox_gles_error(GL_INVALID_ENUM);return;}
    vox_gles_collect_errors();glRenderbufferStorage(target,internal,width,height);
    if(!vox_gles_collect_errors())vox_gles_initialize_renderbuffer(internal);
}
static void vox_gles_renderbuffer_storage_multisample(GLenum target,int samples,GLenum internal,int width,int height) {
    GLenum format,type;
    if(internal!=GL_STENCIL_INDEX8 && !vox_gles_storage_format(internal,&format,&type)){vox_gles_error(GL_INVALID_ENUM);return;}
    vox_gles_collect_errors();glRenderbufferStorageMultisample(target,samples,internal,width,height);
    if(!vox_gles_collect_errors())vox_gles_initialize_renderbuffer(internal);
}
#endif
