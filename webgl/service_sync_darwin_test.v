module webgl

fn C.vox_metal_service_no_angle() i32

fn test_direct_metal_native_fences_reject_foreign_deleted_and_reused_handles() {
    mut first:=WebGLRenderingContext.new(.webgl2,WebGLContextAttributes{},[])
    defer { first.native.set_lost() }
    first.native.make_current()
    fence:=C.vox_gl_fence_sync(sync_gpu_commands_complete,0)
    assert fence!=unsafe { nil }
    assert C.vox_gl_client_wait_sync(fence,0,0)==already_signaled
    mut second:=WebGLRenderingContext.new(.webgl2,WebGLContextAttributes{},[])
    defer { second.native.set_lost() }
    second.native.make_current()
    assert C.vox_gl_client_wait_sync(fence,0,0)==wait_failed
    assert second.get_error()==invalid_value
    first.native.make_current()
    C.vox_gl_delete_sync(fence)
    for _ in 0..16 {
        current:=C.vox_gl_fence_sync(sync_gpu_commands_complete,0)
        assert current!=fence
        C.vox_gl_delete_sync(current)
    }
    assert C.vox_gl_client_wait_sync(fence,0,0)==wait_failed
    assert first.get_error()==invalid_value
    assert C.vox_metal_service_no_angle()==1
}
