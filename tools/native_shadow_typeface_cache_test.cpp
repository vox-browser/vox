// Run with tools/test_shadow_typeface_cache.py. The runner links the production
// shadow bridge and an uncached control compiled from the same source, or an
// optional original control object from a preserved native archive.
// Usage: TEST FONT_A.ttf FONT_B.ttf TWO_FACE_COLLECTION.ttc EMPTY_WORK_DIRECTORY
#ifdef NDEBUG
#error "This regression test requires assertions"
#endif
#include "shadow_typeface_cache.h"
#include "shadow_raster.h"
#include "include/core/SkFontMgr.h"
#include "include/core/SkFont.h"
#ifdef __APPLE__
#include "include/ports/SkFontMgr_mac_ct.h"
#else
#include "include/ports/SkFontMgr_empty.h"
#endif
#include <algorithm>
#include <barrier>
#include <cassert>
#include <chrono>
#include <cstdio>
#include <filesystem>
#include <fstream>
#include <iterator>
#include <thread>
#include <vector>
#include <fcntl.h>

extern "C" bool vox_skia_shadow_uncached(uint8_t*, int, int, int, VoxShadowCommand const*);
namespace fs = std::filesystem;

static std::vector<uint8_t> read_file(fs::path const& path)
{
    std::ifstream file(path, std::ios::binary);
    assert(file);
    return {std::istreambuf_iterator<char>(file), std::istreambuf_iterator<char>()};
}

static void write_file(fs::path const& path, std::vector<uint8_t> const& bytes)
{
    std::ofstream file(path, std::ios::binary | std::ios::trunc);
    assert(file);
    file.write(reinterpret_cast<char const*>(bytes.data()), bytes.size());
    file.close();
    assert(file);
}

static void restore_mtime(fs::path const& path, struct stat const& before)
{
#ifdef __APPLE__
    timespec times[2] {before.st_atimespec, before.st_mtimespec};
#else
    timespec times[2] {before.st_atim, before.st_mtim};
#endif
    assert(utimensat(AT_FDCWD, path.c_str(), times, 0) == 0);
}

static void compare_pixels(sk_sp<SkFontMgr> const& manager, fs::path const& path, int index)
{
    auto face = manager->makeFromFile(path.c_str(), index);
    assert(face);
    uint16_t glyphs[] {face->unicharToGlyph('A'), face->unicharToGlyph('g'), face->unicharToGlyph('i')};
    assert(std::all_of(std::begin(glyphs), std::end(glyphs), [](uint16_t glyph) { return glyph != 0; }));
    float positions[] {0, 0, 17.5f, 0, 31.25f, 0};
    VoxShadowClip clip {};
    clip.shape.rect[0] = 4; clip.shape.rect[1] = 4;
    clip.shape.rect[2] = 88; clip.shape.rect[3] = 56;
    std::fill(std::begin(clip.shape.radii), std::end(clip.shape.radii), 4.0f);
    clip.transform[0] = clip.transform[3] = 1;
    for (int repeat = 0; repeat < 2; ++repeat) {
        for (float size : {12.0f, 20.0f, 27.5f}) {
            for (float blur : {0.0f, 1.5f, 4.0f}) {
                for (int smoothing : {0, 1, 2, 3}) {
                    for (bool clipped : {false, true}) {
                        VoxShadowCommand command {};
                        command.kind = 2;
                        command.color = 0x90306090;
                        command.blur = blur;
                        command.transform[0] = command.transform[3] = 1;
                        command.transform[4] = .25f;
                        command.transform[5] = .5f;
                        command.font_path = path.c_str();
                        command.face_index = index;
                        command.font_size = size;
                        command.glyph_count = 3;
                        command.glyphs = glyphs;
                        command.positions = positions;
                        command.translation[0] = 12;
                        command.translation[1] = 38;
                        command.font_smoothing = smoothing;
                        command.clips = clipped ? &clip : nullptr;
                        command.clip_count = clipped ? 1 : 0;
                        std::vector<uint8_t> original(96 * 64 * 4), candidate(original.size());
                        assert(vox_skia_shadow_uncached(original.data(), 96, 64, 96 * 4, &command));
                        assert(vox_skia_shadow(candidate.data(), 96, 64, 96 * 4, &command));
                        assert(original == candidate);
                        assert(std::any_of(original.begin(), original.end(), [](uint8_t value) { return value != 0; }));
                    }
                }
            }
        }
    }
}

int main(int argc, char** argv)
{
    assert(argc == 5);
#ifdef __APPLE__
    auto manager = SkFontMgr_New_CoreText(nullptr);
#else
    auto manager = SkFontMgr_New_Custom_Empty();
#endif
    assert(manager);
    fs::path font_a = argv[1], font_b = argv[2], collection = argv[3], work = argv[4];
    assert(fs::is_directory(work) && fs::is_empty(work));
    auto a = read_file(font_a), b = read_file(font_b);
    auto size = std::max(a.size(), b.size());
    a.resize(size); b.resize(size); // SFNT permits trailing padding; identical file sizes.
    auto path = work / "mutable.ttf";
    write_file(path, a);
    int loads = 0;
    auto load = [&](char const* file, int index) {
        ++loads;
        return manager->makeFromFile(file, index);
    };
    VoxShadowTypefaceCache cache(2, std::max<uint64_t>(size * 4, fs::file_size(collection) * 2));
    std::string owned_key = path.string();
    auto first = cache.get(owned_key.c_str(), 0, load);
    assert(first && loads == 1 && cache.entry_count() == 1);
    owned_key.assign("caller string overwritten");
    assert(cache.get(path.c_str(), 0, load)->uniqueID() == first->uniqueID() && loads == 1);
    assert(cache.retained_font_bytes() == size);

    // In-place replacement: same inode, length and restored mtime. ctime changes.
    struct stat before, after;
    assert(stat(path.c_str(), &before) == 0);
    std::this_thread::sleep_for(std::chrono::milliseconds(2));
    write_file(path, b);
    restore_mtime(path, before);
    assert(stat(path.c_str(), &after) == 0 && before.st_ino == after.st_ino && before.st_size == after.st_size);
    auto replacement = cache.get(path.c_str(), 0, load);
    assert(replacement && replacement->uniqueID() != first->uniqueID() && loads == 2);
    compare_pixels(manager, path, 0);

    // Atomic replacement with identical size/mtime must use the new inode.
    auto temporary = work / "new.ttf";
    write_file(temporary, a);
    restore_mtime(temporary, before);
    fs::rename(temporary, path);
    auto renamed = cache.get(path.c_str(), 0, load);
    assert(renamed && renamed->uniqueID() != replacement->uniqueID() && loads == 3);
    compare_pixels(manager, path, 0);

    fs::remove(path);
    assert(!cache.get(path.c_str(), 0, load) && cache.entry_count() == 0);
    write_file(path, {1, 2, 3, 4});
    assert(!cache.get(path.c_str(), 0, load) && cache.entry_count() == 0);
    write_file(path, a);
    auto recreated = cache.get(path.c_str(), 0, load);
    assert(recreated && cache.entry_count() == 1); // Neither failure is cached.

    // Exact LRU: touching A protects it when C displaces B.
    cache.clear(); loads = 0;
    auto path_b = work / "b.ttf", path_c = work / "c.ttf";
    write_file(path_b, b); write_file(path_c, a);
    auto fa = cache.get(path.c_str(), 0, load);
    auto fb = cache.get(path_b.c_str(), 0, load);
    assert(fa && fb && loads == 2);
    assert(cache.get(path.c_str(), 0, load)->uniqueID() == fa->uniqueID());
    assert(cache.get(path_c.c_str(), 0, load));
    assert(cache.entry_count() == 2 && loads == 3);
    assert(cache.get(path.c_str(), 0, load)->uniqueID() == fa->uniqueID() && loads == 3);
    assert(cache.get(path_b.c_str(), 0, load)->uniqueID() != fb->uniqueID() && loads == 4);
    assert(fb->uniqueID() != 0); // Caller ownership survives eviction.

    // Collection index participates in identity; sizes/smoothing do not.
    cache.clear(); loads = 0;
    auto f0 = cache.get(collection.c_str(), 0, load);
    auto f1 = cache.get(collection.c_str(), 1, load);
    assert(f0 && f1 && f0->uniqueID() != f1->uniqueID() && loads == 2);
    assert(cache.get(collection.c_str(), 0, load)->uniqueID() == f0->uniqueID() && loads == 2);
    assert(!cache.get(collection.c_str(), 9999, load));
    assert(cache.get(collection.c_str(), 0, load)->uniqueID() == f0->uniqueID());

    VoxShadowTypefaceCache tiny(2, 1), disabled(0, size * 4);
    assert(tiny.get(path.c_str(), 0, load) && tiny.entry_count() == 0);
    assert(disabled.get(path.c_str(), 0, load) && disabled.entry_count() == 0);

    // The byte budget also evicts existing entries even with spare entry slots.
    VoxShadowTypefaceCache budget(8, size + size / 2);
    auto budget_a = budget.get(path.c_str(), 0, load);
    assert(budget_a && budget.get(path_b.c_str(), 0, load));
    assert(budget.entry_count() == 1 && budget.retained_font_bytes() == size);
    assert(budget.get(path.c_str(), 0, load)->uniqueID() != budget_a->uniqueID());

    // Changing a file during the loader call must not publish the old identity.
    VoxShadowTypefaceCache racing;
    auto race = racing.get(path.c_str(), 0, [&](char const* file, int index) {
        auto result = manager->makeFromFile(file, index);
        write_file(temporary, b);
        fs::rename(temporary, path);
        return result;
    });
    assert(race && racing.entry_count() == 0);

    compare_pixels(manager, font_a, 0);
    compare_pixels(manager, font_b, 0);
    compare_pixels(manager, collection, 0);
    compare_pixels(manager, collection, 1);

    // Both threads enter the real shadow bridge concurrently with separate
    // buffers; each must preserve pixels while its thread-local cache warms.
    std::barrier start(2);
    std::thread first_thread([&] { start.arrive_and_wait(); compare_pixels(manager, font_a, 0); });
    std::thread second_thread([&] { start.arrive_and_wait(); compare_pixels(manager, font_b, 0); });
    first_thread.join();
    second_thread.join();
    std::puts("PASS: typeface reuse, identity/invalidation, LRU/budgets, ownership, TTC indices and 1152 exact shadow RGBA comparisons (including two-thread replay)");
}
