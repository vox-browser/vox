"""Keep HTTP/1 receive-buffer growth outside V's non-freeing preallocator."""

import re


def patch_receive_buffer(source):
    signature = ('fn (req &Request) receive_all_data_from_cb_in_builder('
                 'mut content strings.Builder, con voidptr, '
                 'receive_chunk_cb FnReceiveChunk) !ReceivedResponseInfo')
    if 'mut received := VoxHTTPReceiveBuffer{}' in source:
        return source
    pattern = re.compile(re.escape(signature) + r'\s*\{.*?^\}', re.M | re.S)
    match = pattern.search(source)
    if match is None:
        raise RuntimeError('Unsupported HTTP receive-buffer implementation')
    function = match[0]
    replacements = {'content.write_ptr(': (2, 'received.write_ptr('),
                    'content.write(': (1, 'received.write('),
                    'content.len': (1, 'received.len')}
    for old, (expected, new) in replacements.items():
        if function.count(old) != expected:
            raise RuntimeError('Unsupported HTTP receive-buffer write: ' + old)
        function = function.replace(old, new)
    body = function[function.index('{') + 1:]
    if re.search(r'\bcontent\s*\.', body):
        raise RuntimeError('Unsupported HTTP receive-buffer access')
    entry = function.index('{') + 1
    function = function[:entry] + '''
    // Callbacks and transport reads run in their ordinary allocation owner.
    // Only response bytes use reclaimable growth; publish once, including the
    // partial bytes on an error, before releasing that private buffer.
    mut received := VoxHTTPReceiveBuffer{}
    unsafe { received.write_ptr(content.data, content.len) }
    defer { received.publish(mut content) }
''' + function[entry:]
    return source[:match.start()] + function + source[match.end():]


def receive_buffer_helper():
    return r'''module http

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
'''
