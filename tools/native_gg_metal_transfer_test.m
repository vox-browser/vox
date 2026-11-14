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
    assert(sg_query_shader_state(shader) == SG_RESOURCESTATE_VALID);
    sg_pipeline pipeline = sg_make_pipeline(&(sg_pipeline_desc){
        .shader = shader,
        .colors[0].pixel_format = SG_PIXELFORMAT_BGRA8,
        .depth.pixel_format = SG_PIXELFORMAT_NONE,
        .sample_count = 1,
    });
    assert(sg_query_pipeline_state(pipeline) == SG_RESOURCESTATE_VALID);
    return pipeline;
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

int main(void) { @autoreleasepool {
    id<MTLDevice> device = MTLCreateSystemDefaultDevice(); assert(device);
    exercise(device, false); exercise(device, true);
    assert(joined_reads == 194 && standalone_reads == 162);
    assert(joined_uploads == 32 && standalone_uploads == 66);
    printf("GG Metal transfers: 128 exact pending-uniform cases, 194 joined / 162 standalone reads, 32 joined / 66 standalone uploads; upload order, buffer reuse, padding, invalid views, active passes, failures and frame-slot reuse pass\n");
} }
