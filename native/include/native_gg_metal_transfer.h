// Included inside Sokol's Metal transfer implementation by prepare_gg_metal.py.
// Keep the synchronous public contract: the caller owns readable pixels when
// this returns. Pending rendering and its readback share one command buffer.
_SOKOL_PRIVATE bool _sg_v_mtl_transfer(_sg_image_t* img, int x, int y,
    int width, int height, void* pixels, int pitch, bool write) {
    // Keep writes and the old reader available for matched comparisons.
    if (write || getenv("VOX_GG_SEPARATE_READBACK")) {
        return _sg_v_mtl_transfer_separate(img, x, y, width, height, pixels, pitch, write);
    }
    if (nil != _sg.mtl.cmd_encoder) return false;
    @autoreleasepool {
        id<MTLTexture> texture = _sg_mtl_id(img->mtl.tex[img->cmn.active_slot]);
        const NSUInteger row_bytes = (NSUInteger)(width * _sg_pixelformat_bytesize(img->cmn.pixel_format));
        const NSUInteger total = row_bytes * (NSUInteger)height;
        id<MTLBuffer> staging = [_sg.mtl.device newBufferWithLength:total
            options:MTLResourceStorageModeShared];
        if (nil == staging) return false;
        // begin_pass enqueues this buffer before rendering. A second buffer
        // cannot run ahead of it; append the copy after the last render pass.
        id<MTLCommandBuffer> commands = _sg.mtl.cmd_buffer;
        bool joined = nil != commands;
        if (!joined) commands = [_sg.mtl.cmd_queue commandBuffer];
        id<MTLBlitCommandEncoder> blit = [commands blitCommandEncoder];
        if (nil == blit) { _SG_OBJC_RELEASE(staging); return false; }
        [blit copyFromTexture:texture sourceSlice:0 sourceLevel:0
            sourceOrigin:MTLOriginMake((NSUInteger)x, (NSUInteger)y, 0)
            sourceSize:MTLSizeMake((NSUInteger)width, (NSUInteger)height, 1)
            toBuffer:staging destinationOffset:0 destinationBytesPerRow:row_bytes
            destinationBytesPerImage:total];
        [blit endEncoding];
        if (joined) _sg.mtl.cmd_buffer = nil;
#ifdef VOX_TEST_GG_METAL_TRANSFER
        vox_test_gg_metal_transfer(commands, joined);
#endif
        [commands commit];
        [commands waitUntilCompleted];
        // The uniform buffer can only be reused after all its readers finish.
        // Preserve begin_pass's completion handler and frame semaphore balance.
        if (joined) _sg.mtl.cur_ub_offset = 0;
        bool ok = commands.status == MTLCommandBufferStatusCompleted;
        if (ok) {
            const uint8_t* source = (const uint8_t*)staging.contents;
            for (int row = 0; row < height; ++row)
                memcpy((uint8_t*)pixels + (size_t)row * (size_t)pitch,
                    source + (size_t)row * row_bytes, row_bytes);
        }
        _SG_OBJC_RELEASE(staging);
        return ok;
    }
}
