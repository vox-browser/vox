#import <Metal/Metal.h>
#include <assert.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

static id<MTLCommandBuffer> expected_commands, expected_upload;
static unsigned joined_reads, standalone_reads, joined_uploads, standalone_uploads;
static bool vox_test_gg_metal_fail_allocation, vox_test_gg_metal_fail_encoder;
static void vox_test_gg_metal_transfer(id<MTLCommandBuffer> commands, bool joined) {
    assert(commands);
    assert(joined == (expected_commands != nil));
    if (joined) { assert(commands == expected_commands); ++joined_reads; }
    else ++standalone_reads;
}
static void vox_test_gg_metal_upload(id<MTLCommandBuffer> commands, bool joined) {
    assert(commands);
    assert(joined == (expected_upload != nil));
    if (joined) { assert(commands == expected_upload); ++joined_uploads; }
    else ++standalone_uploads;
}
#define VOX_TEST_GG_METAL_TRANSFER
#define SOKOL_IMPL
#define SOKOL_METAL
#include VOX_SOKOL_HEADER

static sg_pipeline make_pipeline(void) {
    sg_v_mtl_set_shader_compile_options(2, 3, true);
    sg_shader shader = sg_make_shader(&(sg_shader_desc){
        .vs.source = "#include <metal_stdlib>\nusing namespace metal;\n"
            "vertex float4 main0(uint v [[vertex_id]]) {"
            "float2 p[3]={float2(-1,-1),float2(3,-1),float2(-1,3)};return float4(p[v],0,1);}",
        .vs.entry = "main0",
        .fs.source = "#include <metal_stdlib>\nusing namespace metal;\n"
            "fragment float4 main0(constant float4& color [[buffer(0)]]) {return color;}",
        .fs.entry = "main0",
        .fs.uniform_blocks[0].size = 16,
    });
    sg_v_mtl_set_shader_compile_options(0, 0, false);
    assert(sg_query_shader_state(shader) == SG_RESOURCESTATE_VALID);
    sg_pipeline_desc desc = {
        .shader = shader,
        .colors[0].pixel_format = SG_PIXELFORMAT_BGRA8,
        .depth.pixel_format = SG_PIXELFORMAT_NONE,
        .sample_count = 1,
    };
    bool batched = vox_gg_metal_begin_pipeline_batch();
    sg_pipeline cancelled = sg_make_pipeline(&desc);
    assert(sg_query_pipeline_state(cancelled) ==
        (batched ? SG_RESOURCESTATE_ALLOC : SG_RESOURCESTATE_VALID));
    sg_destroy_pipeline(cancelled);
    sg_pipeline pipeline = sg_make_pipeline(&desc);
    assert(pipeline.id != cancelled.id);
    assert(sg_query_pipeline_state(pipeline) ==
        (batched ? SG_RESOURCESTATE_ALLOC : SG_RESOURCESTATE_VALID));
    // Metal rejects a floating-point fragment output on an integer attachment.
    desc.colors[0].pixel_format = SG_PIXELFORMAT_RGBA8UI;
    sg_pipeline invalid = sg_make_pipeline(&desc);
    if (batched) {
        assert(sg_query_pipeline_state(invalid) == SG_RESOURCESTATE_ALLOC);
        vox_gg_metal_close_pipeline_submissions();
        desc.colors[0].pixel_format = SG_PIXELFORMAT_BGRA8;
        sg_pipeline independent = sg_make_pipeline(&desc);
        assert(sg_query_pipeline_state(independent) == SG_RESOURCESTATE_VALID);
        assert(sg_query_pipeline_state(pipeline) == SG_RESOURCESTATE_ALLOC);
        sg_destroy_pipeline(independent);
        vox_gg_metal_end_pipeline_batch();
    }
    assert(sg_query_pipeline_state(invalid) == SG_RESOURCESTATE_FAILED);
    assert(sg_query_pipeline_state(cancelled) == SG_RESOURCESTATE_INVALID);
    assert(sg_query_pipeline_state(pipeline) == SG_RESOURCESTATE_VALID);
    sg_destroy_pipeline(invalid);
    return pipeline;
}

static void check_shader_compile_failure(void) {
    sg_v_mtl_set_shader_compile_options(2, 3, true);
    sg_shader shader = sg_make_shader(&(sg_shader_desc){
        .vs.source = "#include <metal_stdlib>\nusing namespace metal;\n"
            "vertex float4 main0() { return float4(0); }",
        .vs.entry = "main0",
        .fs.source = "fragment invalid Metal source",
        .fs.entry = "main0",
    });
    sg_v_mtl_set_shader_compile_options(0, 0, false);
    assert(sg_query_shader_state(shader) == SG_RESOURCESTATE_FAILED);
    sg_destroy_shader(shader);
}

static void check_queued_shader_libraries(void) {
    sg_v_mtl_set_shader_compile_options(2, 3, true);
    if (!vox_gg_metal_begin_shader_libraries()) {
        sg_v_mtl_set_shader_compile_options(0, 0, false);
        return;
    }
    const char source[] = "#include <metal_stdlib>\nusing namespace metal;\n"
        "vertex float4 vx() { return float4(0); }\n"
        "fragment float4 fx() { return float4(1); }";
    char temporary[sizeof source];
    memcpy(temporary, source, sizeof source);
    vox_gg_metal_submit_shader_library(temporary);
    memset(temporary, 0, sizeof temporary);
    vox_gg_metal_submit_shader_library(source);
    const char invalid_source[] = "fragment invalid Metal source";
    vox_gg_metal_submit_shader_library(invalid_source);

    sg_v_mtl_set_shader_compile_options(2, 3, false);
    assert(vox_gg_metal_prepared_shader_library(source) == NULL);
    sg_v_mtl_set_shader_compile_options(2, 3, true);
    sg_shader_desc desc = {.vs.source = source, .vs.entry = "vx",
                           .fs.source = source, .fs.entry = "fx"};
    sg_shader paired = sg_make_shader(&desc);
    assert(sg_query_shader_state(paired) == SG_RESOURCESTATE_VALID);
    desc.fs.source = invalid_source;
    sg_shader invalid = sg_make_shader(&desc);
    assert(sg_query_shader_state(invalid) == SG_RESOURCESTATE_FAILED);
    desc.fs.source = NULL;
    desc.fs.entry = NULL;
    sg_shader vertex_only = sg_make_shader(&desc);
    assert(sg_query_shader_state(vertex_only) == SG_RESOURCESTATE_VALID);
    vox_gg_metal_end_shader_libraries();
    sg_v_mtl_set_shader_compile_options(0, 0, false);
    sg_destroy_shader(vertex_only);
    sg_destroy_shader(invalid);
    sg_destroy_shader(paired);
}

static void render(sg_attachments attachments, sg_pipeline pipeline, int frame) {
    sg_begin_pass(&(sg_pass){.attachments = attachments});
    sg_apply_pipeline(pipeline);
    sg_apply_bindings(&(sg_bindings){0});
    const float color[] = { (frame % 17) / 16.f, .25f, .5f, 1.f };
    sg_apply_uniforms(SG_SHADERSTAGE_FS, 0, &(sg_range){.ptr = color, .size = sizeof(color)});
    sg_draw(0, 3, 1);
    sg_end_pass();
}

static void exercise(id<MTLDevice> device, bool retained) {
    sg_setup(&(sg_desc){
        .mtl_use_command_buffer_with_retained_references = retained,
        .environment = {
            .defaults = {.color_format = SG_PIXELFORMAT_BGRA8, .depth_format = SG_PIXELFORMAT_NONE, .sample_count = 1},
            .metal.device = (__bridge const void*)device,
        },
    });
    assert(sg_isvalid());
    check_shader_compile_failure();
    check_queued_shader_libraries();
    sg_pipeline pipeline = make_pipeline();
    const int width = 37, height = 29, pitch = (width + 5) * 4;
    sg_image image = sg_make_image(&(sg_image_desc){
        .render_target = true, .width = width, .height = height,
        .pixel_format = SG_PIXELFORMAT_BGRA8, .sample_count = 1,
    });
    sg_attachments attachments = sg_make_attachments(&(sg_attachments_desc){.colors[0].image = image});
    assert(sg_query_attachments_state(attachments) == SG_RESOURCESTATE_VALID);
    uint8_t expected[pitch * height], actual[pitch * height];
    // More iterations than the frame semaphore and uniform-ring capacities:
    // readback must free each borrowed slot even without sg_commit().
    for (int frame = 0; frame < 64; ++frame) {
        memset(expected, 0xa7, sizeof(expected)); memset(actual, 0xa7, sizeof(actual));
        setenv("VOX_GG_SEPARATE_READBACK", "1", 1);
        render(attachments, pipeline, frame);
        assert(sg_v_read_image(image, 1, 2, width - 3, height - 4, expected, pitch));
        unsetenv("VOX_GG_SEPARATE_READBACK");
        render(attachments, pipeline, frame);
        assert(_sg.mtl.cur_ub_offset > 0);
        expected_commands = _sg.mtl.cmd_buffer;
        assert(expected_commands);
        unsigned before = joined_reads;
        assert(!sg_v_read_image(image, INT_MAX, 0, 1, 1, actual, pitch));
        for (size_t i = 0; i < sizeof(actual); ++i) assert(actual[i] == 0xa7);
        assert(_sg.mtl.cmd_buffer == expected_commands && joined_reads == before);
        if (frame == 0) {
            vox_test_gg_metal_fail_allocation = true;
            assert(!sg_v_read_image(image, 1, 2, width - 3, height - 4, actual, pitch));
            vox_test_gg_metal_fail_allocation = false;
            vox_test_gg_metal_fail_encoder = true;
            assert(!sg_v_read_image(image, 1, 2, width - 3, height - 4, actual, pitch));
            vox_test_gg_metal_fail_encoder = false;
            assert(_sg.mtl.cmd_buffer == expected_commands && _sg.mtl.cur_ub_offset > 0);
            for (size_t i = 0; i < sizeof(actual); ++i) assert(actual[i] == 0xa7);
        }
        assert(sg_v_read_image(image, 1, 2, width - 3, height - 4, actual, pitch));
        assert(joined_reads == before + 1 && _sg.mtl.cmd_buffer == nil && _sg.mtl.cur_ub_offset == 0);
        assert(memcmp(expected, actual, sizeof(actual)) == 0);
        // A second read has no pending rendering and must still copy correctly.
        expected_commands = nil;
        memset(actual, 0xa7, sizeof(actual));
        assert(sg_v_read_image(image, 1, 2, width - 3, height - 4, actual, pitch));
        assert(memcmp(expected, actual, sizeof(actual)) == 0);
        if (frame % 4 == 0) sg_commit();
    }
    // Uploads return without waiting but keep program order. An upload after
    // pending rendering joins its command buffer and replaces the rendering;
    // rendering after a standalone upload covers it. The caller may reuse its
    // buffer as soon as the upload returns.
    uint8_t pattern[pitch * height], uploaded[pitch * height], rendered[pitch * height];
    for (int frame = 0; frame < 16; ++frame) {
        for (size_t i = 0; i < sizeof(pattern); ++i) pattern[i] = (uint8_t)(i * 31 + frame);
        memcpy(uploaded, pattern, sizeof(pattern));
        setenv("VOX_GG_SEPARATE_TRANSFERS", "1", 1);
        render(attachments, pipeline, frame + 3);
        memset(rendered, 0xa7, sizeof(rendered));
        assert(sg_v_read_image(image, 0, 0, width, height, rendered, pitch));
        unsetenv("VOX_GG_SEPARATE_TRANSFERS");
        render(attachments, pipeline, frame);
        expected_upload = _sg.mtl.cmd_buffer;
        assert(expected_upload && _sg.mtl.cur_ub_offset > 0);
        unsigned before = joined_uploads;
        if (frame == 0) {
            vox_test_gg_metal_fail_allocation = true;
            assert(!sg_v_write_image(image, 0, 0, width, height, pattern, pitch));
            vox_test_gg_metal_fail_allocation = false;
            vox_test_gg_metal_fail_encoder = true;
            assert(!sg_v_write_image(image, 0, 0, width, height, pattern, pitch));
            vox_test_gg_metal_fail_encoder = false;
            assert(joined_uploads == before && _sg.mtl.cmd_buffer == expected_upload);
        }
        assert(sg_v_write_image(image, 0, 0, width, height, pattern, pitch));
        assert(joined_uploads == before + 1 && _sg.mtl.cmd_buffer == expected_upload);
        assert(_sg.mtl.cur_ub_offset > 0);
        memset(pattern, 0x11, sizeof(pattern));
        expected_upload = nil;
        expected_commands = _sg.mtl.cmd_buffer;
        memset(actual, 0xa7, sizeof(actual));
        assert(sg_v_read_image(image, 0, 0, width, height, actual, pitch));
        assert(_sg.mtl.cmd_buffer == nil && _sg.mtl.cur_ub_offset == 0);
        for (int row = 0; row < height; ++row)
            assert(memcmp(actual + row * pitch, uploaded + row * pitch, width * 4) == 0);
        memcpy(pattern, uploaded, sizeof(pattern));
        before = standalone_uploads;
        assert(sg_v_write_image(image, 0, 0, width, height, pattern, pitch));
        assert(standalone_uploads == before + 1 && _sg.mtl.cmd_buffer == nil);
        memset(pattern, 0x22, sizeof(pattern));
        render(attachments, pipeline, frame + 3);
        expected_commands = _sg.mtl.cmd_buffer;
        memset(actual, 0xa7, sizeof(actual));
        assert(sg_v_read_image(image, 0, 0, width, height, actual, pitch));
        assert(memcmp(actual, rendered, sizeof(actual)) == 0);
        expected_commands = nil;
        // A standalone upload with no rendering is observed by the next read.
        assert(sg_v_write_image(image, 0, 0, width, height, uploaded, pitch));
        memset(actual, 0xa7, sizeof(actual));
        assert(sg_v_read_image(image, 0, 0, width, height, actual, pitch));
        for (int row = 0; row < height; ++row)
            assert(memcmp(actual + row * pitch, uploaded + row * pitch, width * 4) == 0);
        if (frame % 4 == 0) sg_commit();
    }
    // Upload ownership, active-encoder rejection and subsequent render order.
    memset(actual, 0x80, sizeof(actual));
    assert(sg_v_write_image(image, 0, 0, width, height, actual, pitch));
    memset(expected, 0xa7, sizeof(expected));
    assert(sg_v_read_image(image, 0, 0, width, height, expected, pitch));
    for (int row = 0; row < height; ++row) for (int byte = 0; byte < pitch; ++byte)
        assert(expected[row * pitch + byte] == (byte < width * 4 ? 0x80 : 0xa7));
    sg_begin_pass(&(sg_pass){.attachments = attachments});
    assert(!sg_v_read_image(image, 0, 0, width, height, expected, pitch));
    sg_end_pass();
    expected_commands = _sg.mtl.cmd_buffer;
    assert(sg_v_read_image(image, 0, 0, width, height, expected, pitch));
    expected_commands = nil;
    sg_commit(); sg_shutdown();
}

static void exercise_large_transfer(id<MTLDevice> device, int padding) {
    sg_setup(&(sg_desc){.environment.metal.device = (__bridge const void*)device});
    assert(sg_isvalid());
    const int width = 2051, height = 1537, row_bytes = width * 4, pitch = row_bytes + padding;
    const size_t size = (size_t)pitch * height;
    sg_image image = sg_make_image(&(sg_image_desc){
        .render_target = true, .width = width, .height = height,
        .pixel_format = SG_PIXELFORMAT_BGRA8, .sample_count = 1,
    });
    assert(sg_query_image_state(image) == SG_RESOURCESTATE_VALID);
    uint8_t *input = malloc(size), *output = malloc(size);
    assert(input && output);
    for (size_t i = 0; i < size; ++i) input[i] = (uint8_t)(i * 31 + i / pitch);
    memset(output, 0xa7, size);
    assert(sg_v_write_image(image, 0, 0, width, height, input, pitch));
    memset(input, 0x11, size);
    assert(sg_v_read_image(image, 0, 0, width, height, output, pitch));
    assert(!objc_getAssociatedObject(_sg.mtl.cmd_queue, &vox_gg_metal_readback_buffer_key));
    for (int y = 0; y < height; ++y) {
        size_t start = (size_t)y * pitch;
        for (int x = 0; x < row_bytes; ++x)
            assert(output[start + x] == (uint8_t)((start + x) * 31 + y));
        for (int x = row_bytes; x < pitch; ++x)
            assert(output[start + x] == 0xa7);
    }
    free(output);
    free(input);
    sg_shutdown();
}

static void exercise_readback_buffer(id<MTLDevice> device) {
    sg_setup(&(sg_desc){.environment.metal.device = (__bridge const void*)device});
    assert(sg_isvalid());
    const int width = 35, height = 19, pitch = width * 4;
    sg_image image = sg_make_image(&(sg_image_desc){
        .render_target = true, .width = width, .height = height,
        .pixel_format = SG_PIXELFORMAT_BGRA8, .sample_count = 1,
    });
    assert(sg_query_image_state(image) == SG_RESOURCESTATE_VALID);
    uint8_t pixels[pitch * height];
    id<MTLCommandQueue> queue = _sg.mtl.cmd_queue;
    assert(!objc_getAssociatedObject(queue, &vox_gg_metal_readback_buffer_key));
    assert(sg_v_read_image(image, 0, 0, width / 2, height, pixels, pitch));
    id<MTLBuffer> small = objc_getAssociatedObject(queue, &vox_gg_metal_readback_buffer_key);
    assert(small && small.length >= (width / 2) * 4 * height);
    assert(sg_v_read_image(image, 0, 0, width, height, pixels, pitch));
    id<MTLBuffer> large = objc_getAssociatedObject(queue, &vox_gg_metal_readback_buffer_key);
    assert(large && large != small && large.length >= sizeof(pixels));
    assert(sg_v_read_image(image, 2, 3, width - 2, height - 3, pixels, pitch));
    assert(objc_getAssociatedObject(queue, &vox_gg_metal_readback_buffer_key) == large);
    setenv("VOX_GG_FRESH_READBACK_BUFFER", "1", 1);
    assert(sg_v_read_image(image, 0, 0, width, height, pixels, pitch));
    unsetenv("VOX_GG_FRESH_READBACK_BUFFER");
    assert(objc_getAssociatedObject(queue, &vox_gg_metal_readback_buffer_key) == large);
    sg_shutdown();
}

int main(void) { @autoreleasepool {
    id<MTLDevice> device = MTLCreateSystemDefaultDevice(); assert(device);
    exercise(device, false); exercise(device, true);
    assert(joined_reads == 194 && standalone_reads == 162);
    assert(joined_uploads == 32 && standalone_uploads == 66);
    printf("GG Metal transfers: 128 exact pending-uniform cases, 194 joined / 162 standalone reads, 32 joined / 66 standalone uploads; upload order, buffer reuse, padding, invalid views, active passes, failures and frame-slot reuse pass\n");
    exercise_large_transfer(device, 0);
    exercise_large_transfer(device, 28);
    puts("Large packed and padded uploads and readbacks match byte for byte");
    exercise_readback_buffer(device);
    puts("Readback buffers grow, reuse capacity, and stay with their command queue");
} }
