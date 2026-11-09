module http

import strings

#include "@DIR/vox_receive_buffer.h"

fn C.vox_http_receive_buffer_resize(voidptr, u64) &u8
fn C.vox_http_receive_buffer_free(voidptr)

struct VoxHTTPReceiveBuffer {
mut:
    data &u8 = unsafe { nil }
    len int
    cap int
}

@[unsafe]
fn (mut buffer VoxHTTPReceiveBuffer) write_ptr(bytes &u8, count int) {
    if count <= 0 || bytes == unsafe { nil } { return }
    needed := buffer.len + count
    if needed < buffer.len || needed < count { panic('HTTP response buffer size overflow') }
    if needed > buffer.cap {
        mut capacity := if buffer.cap > 0 { buffer.cap } else { 4096 }
        for capacity < needed {
            next := capacity + capacity
            if next <= capacity { capacity = needed; break }
            capacity = next
        }
        resized := C.vox_http_receive_buffer_resize(buffer.data, u64(capacity))
        if resized == unsafe { nil } { panic('Cannot allocate HTTP response buffer') }
        buffer.data = resized
        buffer.cap = capacity
    }
    unsafe { vmemcpy(buffer.data + buffer.len, bytes, count) }
    buffer.len = needed
}

fn (mut buffer VoxHTTPReceiveBuffer) write(bytes []u8) !int {
    unsafe { buffer.write_ptr(bytes.data, bytes.len) }
    return bytes.len
}

fn (mut buffer VoxHTTPReceiveBuffer) publish(mut content strings.Builder) {
    // One allocation with the final length also avoids power-of-two slack in
    // the durable response. Preserve a caller's already sufficient capacity.
    if content.cap < buffer.len {
        content = strings.new_builder(buffer.len)
    } else {
        content.clear()
    }
    unsafe { content.write_ptr(buffer.data, buffer.len) }
    C.vox_http_receive_buffer_free(buffer.data)
    buffer.data = unsafe { nil }
    buffer.len = 0
    buffer.cap = 0
}
