module webgl

fn metal_service_parameter_shape(pname u32,version int) i32 {
    match pname {
        0x84e0,0xd55,0x80ca,0x80c8,0x883d,0x8009,0x80cb,0x80c9,0xd54,0xb45,0xd56,0xb74,0xb46,0x8192,0xd53,0x8b9b,0x8b9a,0x8b4d,0x851c,0x8dfd,0x84e8,0x8872,0xd33,0x8dfc,0x8869,0x8b4c,0x8dfb,0xd05,0xd52,0x80a8,0x80a9,0x8801,0x8800,0x8802,0x8803,0x8ca3,0x8ca4,0x8ca5,0xd57,0xb91,0xb94,0xb92,0xb95,0xb96,0xb97,0xb93,0xb98,0xd50,0xcf5,0x8b8b,0x8cdf,0x8824 { return 11 }
        0x846e,0x846d,0xb70 { return 22 }
        0xbe2,0xb44,0xb71,0xb72,0xbd0,0x8037,0x809e,0x80a0,0x80ab,0xc11,0xb90 { return 31 }
        0x8005,0xc22 { return 24 }
        0xc23 { return 34 }
        0xb73,0xb21,0x8038,0x2a00,0x80aa,0x84ff { return 21 }
        0xd3a { return 12 }
        0x1f01,0x8b8c,0x1f00,0x1f02 { return 51 }
        0xc10,0xba2 { return 14 }
        0x8e25,0x8d57,0x8073,0x88ff,0x8b4a,0x8a2f,0x8a34,0x8a2b,0x9125,0x8b49,0x8a2e,0x8a2d,0x8b4b,0x80e9,0x80e8,0x8c8a,0x8c8b,0x8c80,0x8904,0x8905,0x9122,0xd02,0xd03,0xd04,0x806e,0xcf2,0x806d,0xcf4,0xcf3 { return if version == 3 { 11 } else { 0 } }
        0x8a30,0x8a31,0x8a33,0x8d6b,0x9111 { return if version == 3 { 41 } else { 0 } }
        0x84fd { return if version == 3 { 21 } else { 0 } }
        0x8e24,0x8e23,0x8c89 { return if version == 3 { 31 } else { 0 } }
        else { return 0 }
    }
}

fn metal_service_default_parameters() map[u32][]f64 {
    return {
        u32(0x84e0): [f64(33984)] // ACTIVE_TEXTURE
        u32(0x8005): [f64(0),f64(0),f64(0),f64(0)] // BLEND_COLOR
        u32(0xc22): [f64(0),f64(0),f64(0),f64(0)] // COLOR_CLEAR_VALUE
        u32(0xc23): [f64(1),f64(1),f64(1),f64(1)] // COLOR_WRITEMASK
        u32(0x80ca): [f64(0)] // BLEND_DST_ALPHA
        u32(0x80c8): [f64(0)] // BLEND_DST_RGB
        u32(0x80cb): [f64(1)] // BLEND_SRC_ALPHA
        u32(0x80c9): [f64(1)] // BLEND_SRC_RGB
        u32(0x883d): [f64(32774)] // BLEND_EQUATION_ALPHA
        u32(0x8009): [f64(32774)] // BLEND_EQUATION_RGB
        u32(0xb45): [f64(1029)] // CULL_FACE_MODE
        u32(0xb46): [f64(2305)] // FRONT_FACE
        u32(0xb74): [f64(513)] // DEPTH_FUNC
        u32(0xb70): [f64(0),f64(1)] // DEPTH_RANGE
        u32(0xb73): [f64(1)] // DEPTH_CLEAR_VALUE
        u32(0xb72): [f64(1)] // DEPTH_WRITEMASK
        u32(0x8192): [f64(4352)] // GENERATE_MIPMAP_HINT
        u32(0x8b8b): [f64(4352)] // FRAGMENT_SHADER_DERIVATIVE_HINT
        u32(0xb21): [f64(1)] // LINE_WIDTH
        u32(0x8038): [f64(0)] // POLYGON_OFFSET_FACTOR
        u32(0x2a00): [f64(0)] // POLYGON_OFFSET_UNITS
        u32(0x80aa): [f64(1)] // SAMPLE_COVERAGE_VALUE
        u32(0x80ab): [f64(0)] // SAMPLE_COVERAGE_INVERT
        u32(0xb91): [f64(0)] // STENCIL_CLEAR_VALUE
        u32(0xb92): [f64(519)] // STENCIL_FUNC
        u32(0x8800): [f64(519)] // STENCIL_BACK_FUNC
        u32(0xb97): [f64(0)] // STENCIL_REF
        u32(0x8ca3): [f64(0)] // STENCIL_BACK_REF
        u32(0xb93): [f64(-1)] // STENCIL_VALUE_MASK
        u32(0x8ca4): [f64(-1)] // STENCIL_BACK_VALUE_MASK
        u32(0xb98): [f64(-1)] // STENCIL_WRITEMASK
        u32(0x8ca5): [f64(-1)] // STENCIL_BACK_WRITEMASK
        u32(0xb94): [f64(7680)] // STENCIL_FAIL
        u32(0xb95): [f64(7680)] // STENCIL_PASS_DEPTH_FAIL
        u32(0xb96): [f64(7680)] // STENCIL_PASS_DEPTH_PASS
        u32(0x8801): [f64(7680)] // STENCIL_BACK_FAIL
        u32(0x8802): [f64(7680)] // STENCIL_BACK_PASS_DEPTH_FAIL
        u32(0x8803): [f64(7680)] // STENCIL_BACK_PASS_DEPTH_PASS
        u32(0xd05): [f64(4)] // PACK_ALIGNMENT
        u32(0xcf5): [f64(4)] // UNPACK_ALIGNMENT
        u32(0xd02): [f64(0)] // PACK_ROW_LENGTH
        u32(0xd03): [f64(0)] // PACK_SKIP_ROWS
        u32(0xd04): [f64(0)] // PACK_SKIP_PIXELS
        u32(0xcf2): [f64(0)] // UNPACK_ROW_LENGTH
        u32(0x806e): [f64(0)] // UNPACK_IMAGE_HEIGHT
        u32(0xcf3): [f64(0)] // UNPACK_SKIP_ROWS
        u32(0xcf4): [f64(0)] // UNPACK_SKIP_PIXELS
        u32(0x806d): [f64(0)] // UNPACK_SKIP_IMAGES
        u32(0xd33): [f64(16384)] // MAX_TEXTURE_SIZE
        u32(0x851c): [f64(16384)] // MAX_CUBE_MAP_TEXTURE_SIZE
        u32(0x84e8): [f64(16384)] // MAX_RENDERBUFFER_SIZE
        u32(0xd3a): [f64(16384),f64(16384)] // MAX_VIEWPORT_DIMS
        u32(0x8073): [f64(2048)] // MAX_3D_TEXTURE_SIZE
        u32(0x88ff): [f64(2048)] // MAX_ARRAY_TEXTURE_LAYERS
        u32(0x8869): [f64(16)] // MAX_VERTEX_ATTRIBS
        u32(0x8872): [f64(16)] // MAX_TEXTURE_IMAGE_UNITS
        u32(0x8b4c): [f64(16)] // MAX_VERTEX_TEXTURE_IMAGE_UNITS
        u32(0x8b4d): [f64(32)] // MAX_COMBINED_TEXTURE_IMAGE_UNITS
        u32(0x8dfb): [f64(1024)] // MAX_VERTEX_UNIFORM_VECTORS
        u32(0x8dfd): [f64(1024)] // MAX_FRAGMENT_UNIFORM_VECTORS
        u32(0x8b4a): [f64(4096)] // MAX_VERTEX_UNIFORM_COMPONENTS
        u32(0x8b49): [f64(4096)] // MAX_FRAGMENT_UNIFORM_COMPONENTS
        u32(0x8dfc): [f64(16)] // MAX_VARYING_VECTORS
        u32(0x8b4b): [f64(64)] // MAX_VARYING_COMPONENTS
        u32(0x9122): [f64(64)] // MAX_VERTEX_OUTPUT_COMPONENTS
        u32(0x9125): [f64(64)] // MAX_FRAGMENT_INPUT_COMPONENTS
        u32(0x8a30): [f64(65536)] // MAX_UNIFORM_BLOCK_SIZE
        u32(0x8a2f): [f64(30)] // MAX_UNIFORM_BUFFER_BINDINGS
        u32(0x8a34): [f64(256)] // UNIFORM_BUFFER_OFFSET_ALIGNMENT
        u32(0x8a2b): [f64(12)] // MAX_VERTEX_UNIFORM_BLOCKS
        u32(0x8a2d): [f64(12)] // MAX_FRAGMENT_UNIFORM_BLOCKS
        u32(0x8a2e): [f64(24)] // MAX_COMBINED_UNIFORM_BLOCKS
        u32(0x8a31): [f64(200704)] // MAX_COMBINED_VERTEX_UNIFORM_COMPONENTS
        u32(0x8a33): [f64(200704)] // MAX_COMBINED_FRAGMENT_UNIFORM_COMPONENTS
        u32(0xd52): [f64(8)] // RED_BITS
        u32(0xd53): [f64(8)] // GREEN_BITS
        u32(0xd54): [f64(8)] // BLUE_BITS
        u32(0xd55): [f64(8)] // ALPHA_BITS
        u32(0xd50): [f64(4)] // SUBPIXEL_BITS
        u32(0x80a8): [f64(0)] // SAMPLE_BUFFERS
        u32(0x80a9): [f64(0)] // SAMPLES
        u32(0x8d57): [f64(1)] // MAX_SAMPLES
        u32(0x8cdf): [f64(8)] // MAX_COLOR_ATTACHMENTS
        u32(0x8824): [f64(8)] // MAX_DRAW_BUFFERS
        u32(0x846e): [f64(1),f64(1)] // ALIASED_LINE_WIDTH_RANGE
        u32(0x846d): [f64(1),f64(511)] // ALIASED_POINT_SIZE_RANGE
        u32(0x8b9b): [f64(6408)] // IMPLEMENTATION_COLOR_READ_FORMAT
        u32(0x8b9a): [f64(5121)] // IMPLEMENTATION_COLOR_READ_TYPE
        u32(0x80e9): [f64(2147483647)] // MAX_ELEMENTS_INDICES
        u32(0x80e8): [f64(2147483647)] // MAX_ELEMENTS_VERTICES
        u32(0x8d6b): [f64(4294967294)] // MAX_ELEMENT_INDEX
        u32(0x8904): [f64(-8)] // MIN_PROGRAM_TEXEL_OFFSET
        u32(0x8905): [f64(7)] // MAX_PROGRAM_TEXEL_OFFSET
        u32(0x84fd): [f64(16)] // MAX_TEXTURE_LOD_BIAS
        u32(0x8c8a): [f64(64)] // MAX_TRANSFORM_FEEDBACK_INTERLEAVED_COMPONENTS
        u32(0x8c8b): [f64(4)] // MAX_TRANSFORM_FEEDBACK_SEPARATE_ATTRIBS
        u32(0x8c80): [f64(4)] // MAX_TRANSFORM_FEEDBACK_SEPARATE_COMPONENTS
        u32(0x9111): [f64(0)] // MAX_SERVER_WAIT_TIMEOUT
        u32(0x84ff): [f64(16)] // MAX_TEXTURE_MAX_ANISOTROPY_EXT
    }
}

fn (mut context MetalServiceContext) parameter(pname u32) ![]f64 {
    match pname {
        0x8069 { return [f64(context.textures[context.texture_key(texture_2d)])] }
        0x8514 { return [f64(context.textures[context.texture_key(texture_cube_map)])] }
        0x806a { return [f64(context.textures[context.texture_key(texture_3d)])] }
        0x8c1d { return [f64(context.textures[context.texture_key(texture_2d_array)])] }
        0x8919 { return [f64(context.samplers[int(context.parameters[active_texture][0])-int(texture0)])] }
        0x8b8d { return [f64(context.current_program)] }
        0x0ba2 { return [context.viewport.x,context.viewport.y,context.viewport.width,context.viewport.height] }
        0x0c10 { return [f64(context.scissor.x),f64(context.scissor.y),f64(context.scissor.width),f64(context.scissor.height)] }
        0x0d56 { return [f64(if context.has_depth { 32 } else { 0 })] }
        0x0d57 { return [f64(if context.has_stencil { 8 } else { 0 })] }
        0x8894 { return [f64(context.buffer_binding(array_buffer))] }
        0x8895 { return [f64(context.buffer_binding(element_array_buffer))] }
        0x8f36 { return [f64(context.buffer_binding(0x8f36))] }
        0x8f37 { return [f64(context.buffer_binding(0x8f37))] }
        0x88ed { return [f64(context.buffer_binding(0x88eb))] }
        0x88ef { return [f64(context.buffer_binding(0x88ec))] }
        0x8a28 { return [f64(context.buffer_binding(0x8a11))] }
        0x8c8f { return [f64(context.buffer_binding(0x8c8e))] }
        0x85b5 { return [f64(context.vertex_array)] }
        0x8ca6 { return [f64(context.draw_framebuffer)] }
        0x8caa { return [f64(context.read_framebuffer)] }
        0x8ca7 { return [f64(context.renderbuffer)] }
        0x8e25 { return [f64(context.current_feedback)] }
        0x8e23 { return [f64(context.feedback().paused)] }
        0x8e24 { return [f64(context.feedback().active)] }
        else {}
    }
    if context.valid_capability(pname) { return [f64(context.enabled[pname])] }
    if value := context.parameters[pname] { return value.clone() }
    metal_service_error(invalid_enum)
    return error('Unknown Metal parameter')
}

fn (context &MetalServiceContext) valid_capability(cap u32) bool {
    return cap in [blend,cull_face,depth_test,dither,polygon_offset_fill,sample_alpha_to_coverage,sample_coverage,scissor_test,stencil_test]
        || (context.version == 3 && cap == 0x8c89)
}

fn metal_service_unit(value f32) f32 {
    return if value != value || value < 0 { f32(0) } else if value > 1 { f32(1) } else { value }
}

fn (mut context MetalServiceContext) set_parameter(pname u32,values []f64) {
    if old := context.parameters[pname] { unsafe { old.free() } }
    context.parameters[pname] = values
}

fn metal_service_valid_blend_factor(value u32,source bool) bool {
    return value in [u32(0),1,0x300,0x301,0x302,0x303,0x304,0x305,0x306,0x307,0x8001,0x8002,0x8003,0x8004] || (source && value==0x308)
}
