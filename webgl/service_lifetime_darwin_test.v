module webgl

import webgl.metal

fn test_deleting_a_buffer_preserves_unrelated_gpu_resources_and_context_maps() {
    mut context:=WebGLRenderingContext.new(.webgl2,WebGLContextAttributes{},[])
    defer { context.native.set_lost() }
    mut sync:=context.fence_sync(sync_gpu_commands_complete,0) or { panic('fence') }
    texture:=context.create_texture();context.bind_texture(texture_2d,texture)
    uniform:=context.create_buffer();context.bind_buffer(uniform_buffer,uniform)
    context.buffer_data_size(uniform_buffer,16,0x88e4)
    context.bind_buffer_base(uniform_buffer,2,uniform)
    mut service:=metal_service_current()
    mut black:=metal.Texture2D.create(service.target,1,1)!
    black.write_pixels([u8(1),2,3,255])!
    service.black_textures[1]=black
    garbage:=context.create_buffer();context.bind_buffer(array_buffer,garbage)
    context.buffer_data_size(array_buffer,8,0x88e4)
    context.delete_buffer(garbage)
    assert context.get_sync_parameter(sync,sync_status).integer==signaled
    assert context.client_wait_sync(mut sync,0,0)==already_signaled
    assert service.textures[service.texture_key(texture_2d)]==texture.object.native_handle_
    assert service.indexed_buffers[(u64(uniform_buffer)<<32)|2].buffer==uniform.object.native_handle_
    assert service.black_textures[1].read_pixels()! ==[u8(1),2,3,255]
    // A subsequent allocation/deletion must remain valid too (GC none exposes
    // freed-map reuse rather than leaving the first deletion as a false pass).
    another:=context.create_buffer();context.bind_buffer(array_buffer,another)
    context.buffer_data_size(array_buffer,8,0x88e4);context.delete_buffer(another)
    assert context.get_sync_parameter(sync,sync_status).integer==signaled
    assert context.get_error()==no_error
}
