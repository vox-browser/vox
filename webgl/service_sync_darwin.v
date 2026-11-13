module webgl

@[heap]
struct MetalServiceFence {
mut:
    deleted bool
}

fn metal_service_fence(condition u32,flags u32) voidptr {
    mut context:=metal_service_current()
    if context==unsafe { nil } { return unsafe { nil } }
    if condition!=sync_gpu_commands_complete { metal_service_error(invalid_enum);return unsafe { nil } }
    if flags!=0 { metal_service_error(invalid_value);return unsafe { nil } }
    // Every Metal submission waits for completion before returning. A fence
    // inserted here therefore already follows completed GPU work.
    fence:=&MetalServiceFence{}
    context.fences[voidptr(fence)]=fence
    return fence
}

fn metal_service_live_fence(handle voidptr) bool {
    context:=metal_service_current()
    if context==unsafe { nil } { return false }
    if fence:=context.fences[handle] { if !fence.deleted { return true } }
    metal_service_error(invalid_value)
    return false
}

fn metal_service_client_wait(handle voidptr,flags u32) u32 {
    if flags & ~u32(sync_flush_commands_bit)!=0 { metal_service_error(invalid_value);return wait_failed }
    if !metal_service_live_fence(handle) { return wait_failed }
    return already_signaled
}

fn metal_service_wait(handle voidptr,flags u32,timeout u64) {
    if flags!=0 || timeout!=~u64(0) { metal_service_error(invalid_value);return }
    metal_service_live_fence(handle)
}

fn metal_service_sync_parameter(handle voidptr,pname u32) i32 {
    if !metal_service_live_fence(handle) { return 0 }
    return match pname {
        0x9112 { i32(0x9116) } // OBJECT_TYPE / SYNC_FENCE
        0x9113 { i32(sync_gpu_commands_complete) }
        0x9114 { i32(signaled) }
        0x9115 { i32(0) }
        else { metal_service_error(invalid_enum);i32(0) }
    }
}
