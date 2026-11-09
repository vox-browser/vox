
    // Callbacks and transport reads run in their ordinary allocation owner.
    // Only response bytes use reclaimable growth; publish once, including the
    // partial bytes on an error, before releasing that private buffer.
    mut received := VoxHTTPReceiveBuffer{}
    unsafe { received.write_ptr(content.data, content.len) }
    defer { received.publish(mut content) }
