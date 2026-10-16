// Copyright 2017 The ANGLE Project Authors. All rights reserved.
// Copyright 2013-2026 The Khronos Group Inc.
// SPDX-License-Identifier: BSD-3-Clause AND MIT
// Selected ANGLE/Khronos extension ABI declarations. Linux loads extensions
// through EGL, since Mesa does not export ANGLE entry points directly.
#pragma once

typedef void (GL_APIENTRYP PFNGLBINDVERTEXARRAYOESPROC) (GLuint array);
#define glBindVertexArrayOES ((PFNGLBINDVERTEXARRAYOESPROC)eglGetProcAddress("glBindVertexArrayOES"))

typedef void (GL_APIENTRYP PFNGLDELETEVERTEXARRAYSOESPROC) (GLsizei n, const GLuint *arrays);
#define glDeleteVertexArraysOES ((PFNGLDELETEVERTEXARRAYSOESPROC)eglGetProcAddress("glDeleteVertexArraysOES"))

typedef void (GL_APIENTRYP PFNGLDRAWARRAYSINSTANCEDANGLEPROC) (GLenum mode, GLint first, GLsizei count, GLsizei primcount);
#define glDrawArraysInstancedANGLE ((PFNGLDRAWARRAYSINSTANCEDANGLEPROC)eglGetProcAddress("glDrawArraysInstancedANGLE"))

typedef void (GL_APIENTRYP PFNGLDRAWBUFFERSEXTPROC) (GLsizei n, const GLenum *bufs);
#define glDrawBuffersEXT ((PFNGLDRAWBUFFERSEXTPROC)eglGetProcAddress("glDrawBuffersEXT"))

typedef void (GL_APIENTRYP PFNGLDRAWELEMENTSINSTANCEDANGLEPROC) (GLenum mode, GLsizei count, GLenum type, const void *indices, GLsizei primcount);
#define glDrawElementsInstancedANGLE ((PFNGLDRAWELEMENTSINSTANCEDANGLEPROC)eglGetProcAddress("glDrawElementsInstancedANGLE"))

typedef void (GL_APIENTRYP PFNGLGENVERTEXARRAYSOESPROC) (GLsizei n, GLuint *arrays);
#define glGenVertexArraysOES ((PFNGLGENVERTEXARRAYSOESPROC)eglGetProcAddress("glGenVertexArraysOES"))

typedef void (GL_APIENTRYP PFNGLGETACTIVEUNIFORMBLOCKIVROBUSTANGLEPROC) (GLuint program, GLuint uniformBlockIndex, GLenum pname, GLsizei paramCount, GLsizei *length, GLint *params);
#define glGetActiveUniformBlockivRobustANGLE ((PFNGLGETACTIVEUNIFORMBLOCKIVROBUSTANGLEPROC)eglGetProcAddress("glGetActiveUniformBlockivRobustANGLE"))

typedef void (GL_APIENTRYP PFNGLGETBOOLEANVROBUSTANGLEPROC) (GLenum pname, GLsizei paramCount, GLsizei *length, GLboolean *data);
#define glGetBooleanvRobustANGLE ((PFNGLGETBOOLEANVROBUSTANGLEPROC)eglGetProcAddress("glGetBooleanvRobustANGLE"))

typedef void (GL_APIENTRYP PFNGLGETBUFFERPARAMETERIVROBUSTANGLEPROC) (GLenum target, GLenum pname, GLsizei paramCount, GLsizei *length, GLint *params);
#define glGetBufferParameterivRobustANGLE ((PFNGLGETBUFFERPARAMETERIVROBUSTANGLEPROC)eglGetProcAddress("glGetBufferParameterivRobustANGLE"))

typedef void (GL_APIENTRYP PFNGLGETFLOATVROBUSTANGLEPROC) (GLenum pname, GLsizei paramCount, GLsizei *length, GLfloat *data);
#define glGetFloatvRobustANGLE ((PFNGLGETFLOATVROBUSTANGLEPROC)eglGetProcAddress("glGetFloatvRobustANGLE"))

typedef void (GL_APIENTRYP PFNGLGETINTEGER64VROBUSTANGLEPROC) (GLenum pname, GLsizei paramCount, GLsizei *length, GLint64 *data);
#define glGetInteger64vRobustANGLE ((PFNGLGETINTEGER64VROBUSTANGLEPROC)eglGetProcAddress("glGetInteger64vRobustANGLE"))

typedef void (GL_APIENTRYP PFNGLGETINTEGERVROBUSTANGLEPROC) (GLenum pname, GLsizei paramCount, GLsizei *length, GLint *data);
#define glGetIntegervRobustANGLE ((PFNGLGETINTEGERVROBUSTANGLEPROC)eglGetProcAddress("glGetIntegervRobustANGLE"))

typedef void (GL_APIENTRYP PFNGLGETINTERNALFORMATIVROBUSTANGLEPROC) (GLenum target, GLenum internalformat, GLenum pname, GLsizei paramCount, GLsizei *length, GLint *params);
#define glGetInternalformativRobustANGLE ((PFNGLGETINTERNALFORMATIVROBUSTANGLEPROC)eglGetProcAddress("glGetInternalformativRobustANGLE"))

typedef void (GL_APIENTRYP PFNGLGETPROGRAMIVROBUSTANGLEPROC) (GLuint program, GLenum pname, GLsizei paramCount, GLsizei *length, GLint *params);
#define glGetProgramivRobustANGLE ((PFNGLGETPROGRAMIVROBUSTANGLEPROC)eglGetProcAddress("glGetProgramivRobustANGLE"))

typedef void (GL_APIENTRYP PFNGLGETQUERYOBJECTUIVROBUSTANGLEPROC) (GLuint id, GLenum pname, GLsizei paramCount, GLsizei *length, GLuint *params);
#define glGetQueryObjectuivRobustANGLE ((PFNGLGETQUERYOBJECTUIVROBUSTANGLEPROC)eglGetProcAddress("glGetQueryObjectuivRobustANGLE"))

typedef void (GL_APIENTRYP PFNGLGETRENDERBUFFERPARAMETERIVROBUSTANGLEPROC) (GLenum target, GLenum pname, GLsizei paramCount, GLsizei *length, GLint *params);
#define glGetRenderbufferParameterivRobustANGLE ((PFNGLGETRENDERBUFFERPARAMETERIVROBUSTANGLEPROC)eglGetProcAddress("glGetRenderbufferParameterivRobustANGLE"))

typedef void (GL_APIENTRYP PFNGLGETSAMPLERPARAMETERFVROBUSTANGLEPROC) (GLuint sampler, GLenum pname, GLsizei paramCount, GLsizei *length, GLfloat *params);
#define glGetSamplerParameterfvRobustANGLE ((PFNGLGETSAMPLERPARAMETERFVROBUSTANGLEPROC)eglGetProcAddress("glGetSamplerParameterfvRobustANGLE"))

typedef void (GL_APIENTRYP PFNGLGETSHADERIVROBUSTANGLEPROC) (GLuint shader, GLenum pname, GLsizei paramCount, GLsizei *length, GLint *params);
#define glGetShaderivRobustANGLE ((PFNGLGETSHADERIVROBUSTANGLEPROC)eglGetProcAddress("glGetShaderivRobustANGLE"))

typedef void (GL_APIENTRYP PFNGLGETTEXPARAMETERFVROBUSTANGLEPROC) (GLenum target, GLenum pname, GLsizei paramCount, GLsizei *length, GLfloat *params);
#define glGetTexParameterfvRobustANGLE ((PFNGLGETTEXPARAMETERFVROBUSTANGLEPROC)eglGetProcAddress("glGetTexParameterfvRobustANGLE"))

typedef void (GL_APIENTRYP PFNGLGETTEXPARAMETERIVROBUSTANGLEPROC) (GLenum target, GLenum pname, GLsizei paramCount, GLsizei *length, GLint *params);
#define glGetTexParameterivRobustANGLE ((PFNGLGETTEXPARAMETERIVROBUSTANGLEPROC)eglGetProcAddress("glGetTexParameterivRobustANGLE"))

typedef void (GL_APIENTRYP PFNGLGETVERTEXATTRIBPOINTERVROBUSTANGLEPROC) (GLuint index, GLenum pname, GLsizei paramCount, GLsizei *length, void **pointer);
#define glGetVertexAttribPointervRobustANGLE ((PFNGLGETVERTEXATTRIBPOINTERVROBUSTANGLEPROC)eglGetProcAddress("glGetVertexAttribPointervRobustANGLE"))

typedef void (GL_APIENTRYP PFNGLGETVERTEXATTRIBFVROBUSTANGLEPROC) (GLuint index, GLenum pname, GLsizei paramCount, GLsizei *length, GLfloat *params);
#define glGetVertexAttribfvRobustANGLE ((PFNGLGETVERTEXATTRIBFVROBUSTANGLEPROC)eglGetProcAddress("glGetVertexAttribfvRobustANGLE"))

typedef void (GL_APIENTRYP PFNGLGETVERTEXATTRIBIVROBUSTANGLEPROC) (GLuint index, GLenum pname, GLsizei paramCount, GLsizei *length, GLint *params);
#define glGetVertexAttribivRobustANGLE ((PFNGLGETVERTEXATTRIBIVROBUSTANGLEPROC)eglGetProcAddress("glGetVertexAttribivRobustANGLE"))

typedef GLboolean (GL_APIENTRYP PFNGLISVERTEXARRAYOESPROC) (GLuint array);
#define glIsVertexArrayOES ((PFNGLISVERTEXARRAYOESPROC)eglGetProcAddress("glIsVertexArrayOES"))

typedef void (GL_APIENTRYP PFNGLREADPIXELSROBUSTANGLEPROC) (GLint x, GLint y, GLsizei width, GLsizei height, GLenum format, GLenum type, GLsizei bufSize, GLsizei *length, GLsizei *columns, GLsizei *rows, void *pixels);
#define glReadPixelsRobustANGLE ((PFNGLREADPIXELSROBUSTANGLEPROC)eglGetProcAddress("glReadPixelsRobustANGLE"))

typedef void (GL_APIENTRYP PFNGLREQUESTEXTENSIONANGLEPROC) (const GLchar *name);
#define glRequestExtensionANGLE ((PFNGLREQUESTEXTENSIONANGLEPROC)eglGetProcAddress("glRequestExtensionANGLE"))

typedef void (GL_APIENTRYP PFNGLTEXIMAGE2DROBUSTANGLEPROC) (GLenum target, GLint level, GLint internalformat, GLsizei width, GLsizei height, GLint border, GLenum format, GLenum type, GLsizei bufSize, const void *pixels);
#define glTexImage2DRobustANGLE ((PFNGLTEXIMAGE2DROBUSTANGLEPROC)eglGetProcAddress("glTexImage2DRobustANGLE"))

typedef void (GL_APIENTRYP PFNGLTEXIMAGE3DROBUSTANGLEPROC) (GLenum target, GLint level, GLint internalformat, GLsizei width, GLsizei height, GLsizei depth, GLint border, GLenum format, GLenum type, GLsizei bufSize, const void *pixels);
#define glTexImage3DRobustANGLE ((PFNGLTEXIMAGE3DROBUSTANGLEPROC)eglGetProcAddress("glTexImage3DRobustANGLE"))

typedef void (GL_APIENTRYP PFNGLTEXSUBIMAGE2DROBUSTANGLEPROC) (GLenum target, GLint level, GLint xoffset, GLint yoffset, GLsizei width, GLsizei height, GLenum format, GLenum type, GLsizei bufSize, const void *pixels);
#define glTexSubImage2DRobustANGLE ((PFNGLTEXSUBIMAGE2DROBUSTANGLEPROC)eglGetProcAddress("glTexSubImage2DRobustANGLE"))

typedef void (GL_APIENTRYP PFNGLTEXSUBIMAGE3DROBUSTANGLEPROC) (GLenum target, GLint level, GLint xoffset, GLint yoffset, GLint zoffset, GLsizei width, GLsizei height, GLsizei depth, GLenum format, GLenum type, GLsizei bufSize, const void *pixels);
#define glTexSubImage3DRobustANGLE ((PFNGLTEXSUBIMAGE3DROBUSTANGLEPROC)eglGetProcAddress("glTexSubImage3DRobustANGLE"))

typedef void (GL_APIENTRYP PFNGLVERTEXATTRIBDIVISORANGLEPROC) (GLuint index, GLuint divisor);
#define glVertexAttribDivisorANGLE ((PFNGLVERTEXATTRIBDIVISORANGLEPROC)eglGetProcAddress("glVertexAttribDivisorANGLE"))

static int vox_angle_procedures_available(void) {
    return eglGetProcAddress("glBindVertexArrayOES") != NULL
        && eglGetProcAddress("glDeleteVertexArraysOES") != NULL
        && eglGetProcAddress("glDrawArraysInstancedANGLE") != NULL
        && eglGetProcAddress("glDrawBuffersEXT") != NULL
        && eglGetProcAddress("glDrawElementsInstancedANGLE") != NULL
        && eglGetProcAddress("glGenVertexArraysOES") != NULL
        && eglGetProcAddress("glGetActiveUniformBlockivRobustANGLE") != NULL
        && eglGetProcAddress("glGetBooleanvRobustANGLE") != NULL
        && eglGetProcAddress("glGetBufferParameterivRobustANGLE") != NULL
        && eglGetProcAddress("glGetFloatvRobustANGLE") != NULL
        && eglGetProcAddress("glGetInteger64vRobustANGLE") != NULL
        && eglGetProcAddress("glGetIntegervRobustANGLE") != NULL
        && eglGetProcAddress("glGetInternalformativRobustANGLE") != NULL
        && eglGetProcAddress("glGetProgramivRobustANGLE") != NULL
        && eglGetProcAddress("glGetQueryObjectuivRobustANGLE") != NULL
        && eglGetProcAddress("glGetRenderbufferParameterivRobustANGLE") != NULL
        && eglGetProcAddress("glGetSamplerParameterfvRobustANGLE") != NULL
        && eglGetProcAddress("glGetShaderivRobustANGLE") != NULL
        && eglGetProcAddress("glGetTexParameterfvRobustANGLE") != NULL
        && eglGetProcAddress("glGetTexParameterivRobustANGLE") != NULL
        && eglGetProcAddress("glGetVertexAttribPointervRobustANGLE") != NULL
        && eglGetProcAddress("glGetVertexAttribfvRobustANGLE") != NULL
        && eglGetProcAddress("glGetVertexAttribivRobustANGLE") != NULL
        && eglGetProcAddress("glIsVertexArrayOES") != NULL
        && eglGetProcAddress("glReadPixelsRobustANGLE") != NULL
        && eglGetProcAddress("glRequestExtensionANGLE") != NULL
        && eglGetProcAddress("glTexImage2DRobustANGLE") != NULL
        && eglGetProcAddress("glTexImage3DRobustANGLE") != NULL
        && eglGetProcAddress("glTexSubImage2DRobustANGLE") != NULL
        && eglGetProcAddress("glTexSubImage3DRobustANGLE") != NULL
        && eglGetProcAddress("glVertexAttribDivisorANGLE") != NULL;
}
