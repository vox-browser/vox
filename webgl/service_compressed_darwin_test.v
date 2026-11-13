module webgl

fn test_s3tc_color_interpolation_transparency_and_both_alpha_encodings() {
    // All four BC1 selectors, repeated on each row; endpoint 0 is red.
    opaque:=metal_service_decode_s3tc(0x83f0,4,4,1,[u8(0),248,224,7,228,228,228,228])
    assert opaque[..16]==[u8(255),0,0,255,0,255,0,255,170,85,0,255,85,170,0,255]
    transparent:=metal_service_decode_s3tc(0x83f1,2,1,1,[u8(0),0,255,255,15,0,0,0])
    assert transparent==[u8(0),0,0,0,0,0,0,0]
    // BC2 always uses four-color interpolation even with reversed endpoints.
    explicit_alpha:=metal_service_decode_s3tc(0x83f2,2,1,1,[u8(240),0,0,0,0,0,0,0,0,0,255,255,14,0,0,0])
    assert explicit_alpha==[u8(85),85,85,0,170,170,170,255]
    // BC3 alpha selectors 2, 3, 6, 7 exercise each interpolation branch.
    alpha7:=metal_service_decode_s3tc(0x83f3,4,1,1,[u8(255),0,154,15,0,0,0,0,0,248,0,0,0,0,0,0])
    assert [alpha7[3],alpha7[7],alpha7[11],alpha7[15]]==[u8(218),182,72,36]
    alpha5:=metal_service_decode_s3tc(0x83f3,4,1,1,[u8(0),255,154,15,0,0,0,0,0,248,0,0,0,0,0,0])
    assert [alpha5[3],alpha5[7],alpha5[11],alpha5[15]]==[u8(51),102,0,255]
}

fn test_compressed_storage_block_validation_and_pixel_unpack_buffer_ranges() {
    mut context:=WebGLRenderingContext.new(.webgl2,WebGLContextAttributes{},[])
    defer { context.native.set_lost() }
    context.get_extension('WEBGL_compressed_texture_s3tc',false) or { panic('S3TC') }
    texture:=context.create_texture();context.bind_texture(texture_2d,texture)
    context.tex_storage2d(texture_2d,3,0x83f1,4,4)
    assert context.get_error()==no_error
    context.compressed_tex_sub_image2d(texture_2d,2,0,0,1,1,0x83f1,[u8(0),248,0,0,0,0,0,0])
    assert context.get_error()==no_error
    context.compressed_tex_sub_image2d(texture_2d,0,1,0,3,4,0x83f1,[u8(0),248,0,0,0,0,0,0])
    assert context.get_error()==invalid_operation
    context.compressed_tex_image2d(texture_2d,0,0x83f1,4,4,0,[u8(0),248,0,0,0,0,0,0])
    assert context.get_error()==invalid_operation
    buffer:=context.create_buffer();context.bind_buffer(pixel_unpack_buffer,buffer)
    context.buffer_data(pixel_unpack_buffer,[u8(99),0,248,0,0,0,0,0,0],0x88e4)
    context.native.make_current()
    C.vox_gl_compressed_tex_sub_image2d(texture_2d,0,0,0,4,4,0x83f1,8,voidptr(1))
    assert context.get_error()==no_error
    C.vox_gl_compressed_tex_sub_image2d(texture_2d,0,0,0,4,4,0x83f1,8,voidptr(2))
    assert context.get_error()==invalid_operation
    assert metal_service_current().unsupported.len==0
}
