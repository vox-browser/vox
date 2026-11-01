#include "../native_graphite_bridge.h"
#include <Foundation/Foundation.h>
#include <mach/mach.h>
#include <algorithm>
#include <cassert>
#include <cstdio>
#include <dlfcn.h>
#include <vector>
#include <unistd.h>

static uint64_t footprint()
{
    task_vm_info_data_t info {};
    mach_msg_type_number_t count = TASK_VM_INFO_COUNT;
    assert(task_info(mach_task_self(), TASK_VM_INFO, reinterpret_cast<task_info_t>(&info), &count) == KERN_SUCCESS);
    return info.phys_footprint;
}

int main(int argc, char** argv)
{
    assert(argc == 2);
    void* library = dlopen(argv[1], RTLD_NOW | RTLD_LOCAL);
    assert(library);
    auto draw = reinterpret_cast<decltype(&vox_graphite_draw_shape_pixels)>(dlsym(library, "vox_graphite_draw_shape_pixels"));
    auto finish = reinterpret_cast<decltype(&vox_graphite_finish_frame)>(dlsym(library, "vox_graphite_finish_frame"));
    auto clear = reinterpret_cast<decltype(&vox_graphite_release_unused_graphics_memory)>(dlsym(library, "vox_graphite_release_unused_graphics_memory"));
    assert(draw && finish && clear);
    constexpr int width = 544, height = 256, frames = 4000;
    std::vector<uint8_t> pixels(width * height * 4);
    VoxGraphiteShape shape {};
    shape.matrix[0] = shape.matrix[4] = shape.matrix[8] = 1;
    shape.rect[0] = 30.25f; shape.rect[1] = 40.75f;
    shape.rect[2] = 470; shape.rect[3] = 160;
    std::fill(shape.rect + 4, shape.rect + 12, 17.f);
    shape.alpha = 207; shape.fill = shape.anti_alias = 1;
    std::vector<uint64_t> middle, last;
    uint64_t peak = 0;
    for (int frame = 0; frame < frames; ++frame) {
        @autoreleasepool {
            for (int pass = 0; pass < 6; ++pass) {
                std::fill(pixels.begin(), pixels.end(), 255);
                // Unique geometry forces six real GPU readbacks per frame.
                shape.matrix[2] = frame * .00003125f + pass * .125f;
                shape.red = uint8_t(frame + pass); shape.green = 37; shape.blue = 83;
                shape.force_msaa = pass % 2;
                assert(draw(pixels.data(), width, height, width * 4, 1, &shape));
            }
            finish();
        }
        uint64_t bytes = footprint(); peak = std::max(peak, bytes);
        if (frame >= 1500 && frame < 2000) middle.push_back(bytes);
        if (frame >= 3500) last.push_back(bytes);
        if (frame % 50 == 0) std::printf("MEMORY frame=%d footprint=%llu\n", frame, (unsigned long long)bytes);
    }
    std::sort(middle.begin(), middle.end()); std::sort(last.begin(), last.end());
    uint64_t earlier = middle[middle.size() / 2], final = last[last.size() / 2];
    @autoreleasepool { clear(); }
    uint64_t idle = footprint();
    uint64_t immediate_idle = idle;
    // The Metal driver retires completed allocations asynchronously.
    for (int poll = 0; poll < 20 && idle >= 128ull * 1024 * 1024; ++poll) {
        usleep(100000);
        idle = footprint();
    }
    std::printf("RESULT frames=%d readbacks=%d peak=%llu middle_median=%llu final_median=%llu immediate_idle=%llu idle=%llu\n",
        frames, frames * 6, (unsigned long long)peak, (unsigned long long)earlier,
        (unsigned long long)final, (unsigned long long)immediate_idle, (unsigned long long)idle);
    assert(peak < 512ull * 1024 * 1024);
    assert(final <= earlier + 64ull * 1024 * 1024);
    assert(idle < 128ull * 1024 * 1024);
}
