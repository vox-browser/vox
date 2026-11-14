// Included inside Sokol's Metal transfer implementation by prepare_gg_metal.py.
// Keep the synchronous public contract: the caller owns readable pixels when
// a read returns, and may reuse its upload buffer when a write returns.
// Pending rendering and its readback share one command buffer, and an upload
// is encoded without waiting: a GG path or shape draw (upload backdrop, draw,
// read back) then blocks on the GPU once instead of four times.
// VOX_GG_SEPARATE_TRANSFERS=1 restores Sokol's transfers;
// VOX_GG_SEPARATE_READBACK=1 and VOX_GG_SEPARATE_UPLOAD=1 restore one side.
#include <dlfcn.h>

// The last standalone upload. Its status is checked by the next read.
static id<MTLCommandBuffer> vox_gg_metal_standalone_upload;

static bool vox_gg_metal_upload(_sg_image_t* img, int x, int y, int width, int height,
    const void* pixels, int pitch) {
    if (nil != _sg.mtl.cmd_encoder) return false;
    @autoreleasepool {
        id<MTLTexture> texture = _sg_mtl_id(img->mtl.tex[img->cmn.active_slot]);
        const NSUInteger row_bytes = (NSUInteger)(width * _sg_pixelformat_bytesize(img->cmn.pixel_format));
        const NSUInteger total = row_bytes * (NSUInteger)height;
#ifdef VOX_TEST_GG_METAL_TRANSFER
        if (vox_test_gg_metal_fail_allocation) return false;
#endif
        id<MTLBuffer> staging = [_sg.mtl.device newBufferWithLength:total
            options:MTLResourceStorageModeShared];
        if (nil == staging) return false;
        uint8_t* staged = (uint8_t*)staging.contents;
        for (int row = 0; row < height; ++row)
            memcpy(staged + (size_t)row * row_bytes,
                (const uint8_t*)pixels + (size_t)row * (size_t)pitch, row_bytes);
        // Rendering already encoded in the enqueued frame buffer precedes the
        // upload, and later passes append to the same buffer after it. Without
        // pending rendering, a standalone buffer is committed before the next
        // frame buffer is enqueued, so it also runs first.
        id<MTLCommandBuffer> commands = _sg.mtl.cmd_buffer;
        bool joined = nil != commands;
        if (!joined) commands = [_sg.mtl.cmd_queue commandBuffer];
#ifdef VOX_TEST_GG_METAL_TRANSFER
        if (vox_test_gg_metal_fail_encoder) { _SG_OBJC_RELEASE(staging); return false; }
#endif
        id<MTLBlitCommandEncoder> blit = [commands blitCommandEncoder];
        if (nil == blit) { _SG_OBJC_RELEASE(staging); return false; }
        [blit copyFromBuffer:staging sourceOffset:0 sourceBytesPerRow:row_bytes
            sourceBytesPerImage:total sourceSize:MTLSizeMake((NSUInteger)width, (NSUInteger)height, 1)
            toTexture:texture destinationSlice:0 destinationLevel:0
            destinationOrigin:MTLOriginMake((NSUInteger)x, (NSUInteger)y, 0)];
        [blit endEncoding];
        // A frame buffer with unretained references does not keep the staging
        // buffer alive; the completion handler does.
        id<MTLBuffer> retained = staging;
        [commands addCompletedHandler:^(id<MTLCommandBuffer> finished) {
            (void)finished;
            (void)retained;
        }];
#ifdef VOX_TEST_GG_METAL_TRANSFER
        vox_test_gg_metal_upload(commands, joined);
#endif
        if (!joined) {
            [commands commit];
            if (nil != vox_gg_metal_standalone_upload) _SG_OBJC_RELEASE(vox_gg_metal_standalone_upload);
            vox_gg_metal_standalone_upload = commands;
            _SG_OBJC_RETAIN(vox_gg_metal_standalone_upload);
        }
        _SG_OBJC_RELEASE(staging);
        return true;
    }
}

// Reports a failed standalone upload to the read that observes it.
static bool vox_gg_metal_complete_upload(void) {
    if (nil == vox_gg_metal_standalone_upload) return true;
    [vox_gg_metal_standalone_upload waitUntilCompleted];
    bool ok = vox_gg_metal_standalone_upload.status == MTLCommandBufferStatusCompleted;
    _SG_OBJC_RELEASE(vox_gg_metal_standalone_upload);
    return ok;
}
static void vox_gg_metal_readback_diagnostic(bool joined) {
    static unsigned reported;
    if (!getenv("VOX_GG_READBACK_DIAGNOSTICS") || reported >= 128) return;
    typedef double (*Clock)(void);
    static Clock clock;
    static bool resolved;
    if (!resolved) {
        clock = (Clock)dlsym(RTLD_DEFAULT, "vox_precise_scroll_diagnostic_time");
        resolved = true;
    }
    double time = clock ? clock() : -1;
    if (clock && time < 0) return;
    ++reported;
    fprintf(stderr, "VOX_GG_READBACK joined=%d t_us=%.3f\n", (int)joined, time);
}

_SOKOL_PRIVATE bool _sg_v_mtl_transfer(_sg_image_t* img, int x, int y,
    int width, int height, void* pixels, int pitch, bool write) {
    // Keep the original transfers available for matched comparisons.
    bool separate = getenv("VOX_GG_SEPARATE_TRANSFERS") != NULL;
    if (write) {
        if (separate || getenv("VOX_GG_SEPARATE_UPLOAD"))
            return _sg_v_mtl_transfer_separate(img, x, y, width, height, pixels, pitch, true);
        return vox_gg_metal_upload(img, x, y, width, height, pixels, pitch);
    }
    if (separate || getenv("VOX_GG_SEPARATE_READBACK")) {
        return vox_gg_metal_complete_upload()
            && _sg_v_mtl_transfer_separate(img, x, y, width, height, pixels, pitch, false);
    }
    if (nil != _sg.mtl.cmd_encoder) return false;
    @autoreleasepool {
        id<MTLTexture> texture = _sg_mtl_id(img->mtl.tex[img->cmn.active_slot]);
        const NSUInteger row_bytes = (NSUInteger)(width * _sg_pixelformat_bytesize(img->cmn.pixel_format));
        const NSUInteger total = row_bytes * (NSUInteger)height;
#ifdef VOX_TEST_GG_METAL_TRANSFER
        if (vox_test_gg_metal_fail_allocation) return false;
#endif
        id<MTLBuffer> staging = [_sg.mtl.device newBufferWithLength:total
            options:MTLResourceStorageModeShared];
        if (nil == staging) return false;
        // begin_pass enqueues this buffer before rendering. A second buffer
        // cannot run ahead of it; append the copy after the last render pass.
        id<MTLCommandBuffer> commands = _sg.mtl.cmd_buffer;
        bool joined = nil != commands;
        if (!joined) commands = [_sg.mtl.cmd_queue commandBuffer];
#ifdef VOX_TEST_GG_METAL_TRANSFER
        if (vox_test_gg_metal_fail_encoder) { _SG_OBJC_RELEASE(staging); return false; }
#endif
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
        ok = vox_gg_metal_complete_upload() && ok;
        if (ok) {
            const uint8_t* source = (const uint8_t*)staging.contents;
            for (int row = 0; row < height; ++row)
                memcpy((uint8_t*)pixels + (size_t)row * (size_t)pitch,
                    source + (size_t)row * row_bytes, row_bytes);
            vox_gg_metal_readback_diagnostic(joined);
        }
        _SG_OBJC_RELEASE(staging);
        return ok;
    }
}
