#include "../native_skia_text_darwin.cpp"
#include <mach/mach.h>
#include <cassert>
#include <cstdio>
#include <cstring>

static uint64_t footprint() {
    task_vm_info_data_t info{};
    mach_msg_type_number_t count = TASK_VM_INFO_COUNT;
    assert(task_info(mach_task_self(), TASK_VM_INFO, (task_info_t)&info, &count) == KERN_SUCCESS);
    return info.phys_footprint;
}

int main(int argc, char** argv) { @autoreleasepool {
    bool control = argc > 1 && std::strcmp(argv[1], "--control") == 0;
    assert(shared_picture_draw()); // Resolve the unchanged GPU backend before measuring.
    auto space = CGColorSpaceCreateWithName(kCGColorSpaceSRGB);
    auto canvas = native_acquire_opacity_canvas(3456, 2106, space);
    assert(canvas.context);
    ladybird_v_skia_begin_deferred_layer_frame(1);
    ladybird_v_skia_set_deferred_layer_destination(canvas.context, control ? 1 : 2);
    ladybird_v_skia_set_chromium_painting(1);
    ladybird_v_skia_set_shared_recording(0, 1728, 1053);
    ladybird_v_skia_set_raster_layer(0.125, 0.25, 0);
    ladybird_v_skia_set_raster_layer_size(1728, 1053);
    ladybird_v_skia_set_layer_shared_recording(1);
    uint64_t before = footprint();
    assert(shared_recording_canvas(canvas.context));
    uint64_t after = footprint();
    assert(s_shared_root_recording && s_shared_root_recording->backdrop.empty());
    assert(s_shared_root_recording->origin_x == .125f && s_shared_root_recording->origin_y == .25f);
    std::printf("Empty compositor prefix footprint growth: %lld bytes\n", (long long)(after - before));
    std::fflush(stdout);
    assert(after < before + 4 * 1024 * 1024);
    s_shared_root_recording.reset();

    // A legacy/speculative registration must not erase an established owner.
    ladybird_v_skia_set_deferred_layer_destination(canvas.context, 1);
    assert(s_mapped_opacity_destinations.contains(canvas.context));
    ladybird_v_skia_set_deferred_layer_destination(canvas.context, 0);
    assert(!s_mapped_opacity_destinations.contains(canvas.context));
    ladybird_v_skia_set_deferred_layer_destination(canvas.context, 1);
    assert(!s_mapped_opacity_destinations.contains(canvas.context));
    ladybird_v_skia_set_deferred_layer_destination(canvas.context, 2);
    assert(ladybird_v_skia_finish_deferred_layer_frame());
    assert(s_mapped_opacity_destinations.empty());

    // Real prefix pixels retain the original complete backdrop and pixel grid.
    ladybird_v_skia_begin_deferred_layer_frame(1);
    ladybird_v_skia_set_deferred_layer_destination(canvas.context, 2);
    canvas.pixels[17 * 3456 * 4 + 31 * 4] = 19;
    canvas.pixels[17 * 3456 * 4 + 31 * 4 + 3] = 255;
    assert(shared_recording_canvas(canvas.context));
    auto* group = s_shared_root_recording.get();
    assert(group && group->backdrop.size() == size_t(3456) * 2106);
    assert(group->backdrop[17 * 3456 + 31] == 0xff130000);
    assert(group->backdrop[0] == 0);
    s_shared_root_recording.reset();
    ladybird_v_skia_set_deferred_layer_destination(canvas.context, 0);
    assert(ladybird_v_skia_finish_deferred_layer_frame());
    native_release_opacity_canvas(canvas, 0, 0, 3456, 2106);
    native_discard_opacity_canvas_pool();
    CGColorSpaceRelease(space);
    std::puts("Owned empty prefixes, fractional origins, real backdrop pixels, legacy registration and frame cleanup pass");
} }
