#ifndef VOX_GLES_DRAW_LINUX_H
#define VOX_GLES_DRAW_LINUX_H
/* Robust GLES returns safe values for out-of-range fetches. WebGL additionally
 * requires INVALID_OPERATION; validate active vertex/index streams before draw. */
static int vox_gles_vertex_bytes(GLenum type,GLint count) {
    switch(type) {
    case GL_BYTE:case GL_UNSIGNED_BYTE:return count;
    case GL_SHORT:case GL_UNSIGNED_SHORT:case GL_HALF_FLOAT:return count*2;
    case GL_FLOAT:case GL_INT:case GL_UNSIGNED_INT:return count*4;
    case GL_INT_2_10_10_10_REV:case GL_UNSIGNED_INT_2_10_10_10_REV:return 4;
    default:return 0;
    }
}
static int vox_gles_attribute_fits(GLuint index,uint64_t vertex,int instances) {
    GLint enabled=0;glGetVertexAttribiv(index,GL_VERTEX_ATTRIB_ARRAY_ENABLED,&enabled);if(!enabled)return 1;
    GLint buffer=0,size=0,type=0,stride=0,divisor=0;
    glGetVertexAttribiv(index,GL_VERTEX_ATTRIB_ARRAY_BUFFER_BINDING,&buffer);
    glGetVertexAttribiv(index,GL_VERTEX_ATTRIB_ARRAY_SIZE,&size);glGetVertexAttribiv(index,GL_VERTEX_ATTRIB_ARRAY_TYPE,&type);
    glGetVertexAttribiv(index,GL_VERTEX_ATTRIB_ARRAY_STRIDE,&stride);glGetVertexAttribiv(index,GL_VERTEX_ATTRIB_ARRAY_DIVISOR,&divisor);
    void *pointer=NULL;glGetVertexAttribPointerv(index,GL_VERTEX_ATTRIB_ARRAY_POINTER,&pointer);
    int element=vox_gles_vertex_bytes((GLenum)type,size);
    if(!buffer || element<=0){vox_gles_error(GL_INVALID_OPERATION);return 0;}
    GLint binding=0;glGetIntegerv(GL_COPY_READ_BUFFER_BINDING,&binding);glBindBuffer(GL_COPY_READ_BUFFER,(GLuint)buffer);
    GLint64 bytes=0;glGetBufferParameteri64v(GL_COPY_READ_BUFFER,GL_BUFFER_SIZE,&bytes);glBindBuffer(GL_COPY_READ_BUFFER,(GLuint)binding);
    uint64_t offset=(uintptr_t)pointer,last=divisor?((uint64_t)instances-1)/(unsigned)divisor:vertex;
    uint64_t step=stride?(unsigned)stride:(unsigned)element;
    if(bytes<0 || offset>(uint64_t)bytes || (uint64_t)element>(uint64_t)bytes-offset || last>((uint64_t)bytes-offset-element)/step) {
        vox_gles_error(GL_INVALID_OPERATION);return 0;
    }
    return 1;
}
static int vox_gles_vertices_fit(uint64_t last,int instances) {
    GLint program=0;glGetIntegerv(GL_CURRENT_PROGRAM,&program);
    if(!program){vox_gles_error(GL_INVALID_OPERATION);return 0;}
    GLint count=0,capacity=0;glGetProgramiv((GLuint)program,GL_ACTIVE_ATTRIBUTES,&count);glGetProgramiv((GLuint)program,GL_ACTIVE_ATTRIBUTE_MAX_LENGTH,&capacity);
    if(count<=0)return 1;
    if(capacity<1){vox_gles_error(GL_INVALID_OPERATION);return 0;}
    char *name=malloc((size_t)capacity);if(!name){vox_gles_error(GL_OUT_OF_MEMORY);return 0;}
    for(GLint i=0;i<count;i++) {
        GLenum type=0;GLint length=0;glGetActiveAttrib((GLuint)program,(GLuint)i,capacity,NULL,&length,&type,name);
        GLint location=glGetAttribLocation((GLuint)program,name);if(location<0)continue;
        int columns=type==GL_FLOAT_MAT2 || type==GL_FLOAT_MAT2x3 || type==GL_FLOAT_MAT2x4?2:
            type==GL_FLOAT_MAT3 || type==GL_FLOAT_MAT3x2 || type==GL_FLOAT_MAT3x4?3:
            type==GL_FLOAT_MAT4 || type==GL_FLOAT_MAT4x2 || type==GL_FLOAT_MAT4x3?4:1;
        for(int slot=0;slot<length*columns;slot++)if(!vox_gles_attribute_fits((GLuint)(location+slot),last,instances)){free(name);return 0;}
    }
    free(name);return 1;
}
static int vox_gles_array_draw(GLint first,GLsizei count,GLsizei instances) {
    if(first<0 || count<0 || instances<0){vox_gles_error(GL_INVALID_VALUE);return 0;}
    return !count || !instances || vox_gles_vertices_fit((uint64_t)first+(unsigned)count-1,instances);
}
static int vox_gles_index_draw(GLsizei count,GLenum type,const void *pointer,GLsizei instances) {
    if(count<0 || instances<0){vox_gles_error(GL_INVALID_VALUE);return 0;}
    int size=type==GL_UNSIGNED_BYTE?1:type==GL_UNSIGNED_SHORT?2:type==GL_UNSIGNED_INT?4:0;
    if(!size){vox_gles_error(GL_INVALID_ENUM);return 0;}
    if(!count || !instances)return 1;
    GLint buffer=0;glGetIntegerv(GL_ELEMENT_ARRAY_BUFFER_BINDING,&buffer);
    GLint64 bytes=0;if(buffer)glGetBufferParameteri64v(GL_ELEMENT_ARRAY_BUFFER,GL_BUFFER_SIZE,&bytes);
    uint64_t offset=(uintptr_t)pointer,needed=(uint64_t)count*(unsigned)size;
    if(!buffer || bytes<0 || offset%size || offset>(uint64_t)bytes || needed>(uint64_t)bytes-offset) {vox_gles_error(GL_INVALID_OPERATION);return 0;}
    const unsigned char *indices=glMapBufferRange(GL_ELEMENT_ARRAY_BUFFER,(GLintptr)offset,(GLsizeiptr)needed,GL_MAP_READ_BIT);
    if(!indices)return 0;
    uint64_t last=0;int found=0;
    uint32_t restart=size==1?UINT8_MAX:size==2?UINT16_MAX:UINT32_MAX;
    for(int i=0;i<count;i++) {
        uint32_t index=0;memcpy(&index,indices+(size_t)i*size,(size_t)size);
        if(vox_gles_current && vox_gles_current->webgl_version==3 && index==restart)continue;
        if(index>last)last=index;found=1;
    }
    glUnmapBuffer(GL_ELEMENT_ARRAY_BUFFER);
    return !found || vox_gles_vertices_fit(last,instances);
}
static void vox_gles_draw_arrays(GLenum mode,GLint first,GLsizei count) {if(vox_gles_array_draw(first,count,1))glDrawArrays(mode,first,count);}
static void vox_gles_draw_arrays_instanced(GLenum mode,GLint first,GLsizei count,GLsizei instances) {if(vox_gles_array_draw(first,count,instances))glDrawArraysInstanced(mode,first,count,instances);}
static void vox_gles_draw_elements(GLenum mode,GLsizei count,GLenum type,const void *indices) {if(vox_gles_index_draw(count,type,indices,1))glDrawElements(mode,count,type,indices);}
static void vox_gles_draw_elements_instanced(GLenum mode,GLsizei count,GLenum type,const void *indices,GLsizei instances) {if(vox_gles_index_draw(count,type,indices,instances))glDrawElementsInstanced(mode,count,type,indices,instances);}
static void vox_gles_draw_range_elements(GLenum mode,GLuint start,GLuint end,GLsizei count,GLenum type,const void *indices) {if(vox_gles_index_draw(count,type,indices,1))glDrawRangeElements(mode,start,end,count,type,indices);}
static void vox_gles_bind_buffer(GLenum target,GLuint buffer) {
    if(vox_gles_current && vox_gles_current->webgl_version==2 && target!=GL_ARRAY_BUFFER && target!=GL_ELEMENT_ARRAY_BUFFER) {vox_gles_error(GL_INVALID_ENUM);return;}
    glBindBuffer(target,buffer);
}
#endif
