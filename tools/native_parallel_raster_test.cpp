#include "../native_parallel_pixels.h"
#include "../native_opacity_group_darwin.h"
#include <atomic>
#include <cassert>
#include <chrono>
#include <set>
#include <stdexcept>
#include <string>

static void check_workers(vox_raster::ParallelRanges& pool)
{
    std::mutex mutex;
    std::condition_variable ready;
    std::set<std::thread::id> threads;
    pool.run(pool.capacity() * 13 + 7, 1, [&](size_t begin, size_t end) {
        assert(end > begin);
        std::unique_lock lock(mutex);
        threads.insert(std::this_thread::get_id());
        ready.notify_all();
        // Every configured lane must actually enter the job simultaneously.
        ready.wait(lock, [&] { return threads.size() == pool.capacity(); });
    });
    assert(threads.size() == pool.capacity());
    std::printf("worker participation: %zu distinct threads, %u logical CPUs\n",
        threads.size(), std::thread::hardware_concurrency());
}

static void check_scheduler()
{
    vox_raster::ParallelRanges pool(4), single(1);
    check_workers(pool);
    check_workers(vox_raster::shared_pool());
    for (size_t count = 0; count < 110; ++count) {
        std::vector<unsigned> visits(count);
        pool.run(count, 3, [&](size_t begin, size_t end) {
            for (auto i = begin; i < end; ++i) ++visits[i];
            // Nested work must not wait on its own parent's submission lock.
            bool nested_parallel_job = vox_raster::inside_parallel_range;
            pool.run(7, 1, [&](size_t a, size_t b) {
                if (nested_parallel_job) assert(a == 0 && b == 7);
            });
        });
        for (auto value : visits) assert(value == 1);
    }
    single.run(12, 1, [](size_t a, size_t b) { assert(a == 0 && b == 12); });
    std::atomic<unsigned> completed {0};
    try {
        pool.run(16, 1, [&](size_t a, size_t) {
            ++completed;
            if (a) throw std::runtime_error("worker failure");
        });
        assert(false);
    } catch (std::runtime_error const&) { }
    assert(completed == pool.capacity());
    check_workers(pool); // Exception handling must leave the pool reusable.

    std::vector<std::thread> producers;
    for (int p = 0; p < 4; ++p) producers.emplace_back([&] {
        for (int trial = 0; trial < 40; ++trial) {
            std::vector<unsigned> values(1003);
            pool.run(values.size(), 1, [&](size_t begin, size_t end) {
                for (auto i = begin; i < end; ++i) values[i] = unsigned(i + 1);
            });
            for (size_t i = 0; i < values.size(); ++i) assert(values[i] == i + 1);
        }
    });
    for (auto& producer : producers) producer.join();

    for (auto mode : {FE_TONEAREST, FE_DOWNWARD, FE_UPWARD, FE_TOWARDZERO}) {
        assert(std::fesetround(mode) == 0);
        pool.run(100, 1, [=](size_t, size_t) { assert(std::fegetround() == mode); });
        assert(std::fegetround() == mode);
    }
    std::fesetround(FE_TONEAREST);
    setenv("VOX_DISABLE_PARALLEL_RASTER", "1", 1);
    pool.run(1000, 1, [](size_t a, size_t b) { assert(a == 0 && b == 1000); });
    unsetenv("VOX_DISABLE_PARALLEL_RASTER");
}

static std::vector<uint8_t> pattern(size_t bytes)
{
    std::vector<uint8_t> result(bytes);
    uint32_t state = 18437;
    for (auto& value : result) {
        state = state * 1664525u + 1013904223u;
        value = uint8_t(state >> 24);
    }
    return result;
}

static void check_pixels()
{
    for (size_t count : {0u, 1u, 3u, 4u, 5u, 131071u, 131072u, 3145731u, 10485763u}) {
        auto source = pattern(count * 4 + 9), expected = source;
        for (size_t i = 0; i < count; ++i) std::swap(expected[3 + i * 4], expected[5 + i * 4]);
        auto actual = source;
        vox_swap_red_blue_pixels(actual.data() + 3, actual.data() + 3, count);
        assert(actual == expected); // Includes both unaligned ends and in-place aliasing.
        auto output = source;
        vox_swap_red_blue_pixels(output.data() + 3, source.data() + 3, count);
        assert(output == expected);
    }
    size_t width = 2051, height = 1541, pitch = width * 4 + 29;
    auto source = pattern(pitch * height);
    for (int covered : {0, 1, 2}) {
        size_t left = 17, right = covered == 2 ? width / 2 : width - 23;
        size_t top = covered ? 5 : 0, bottom = covered == 2 ? height / 2 : covered ? height - 7 : 0;
        std::vector<uint8_t> output(width * height * 4, 0xcd), expected = output;
        for (size_t y = 0; y < height; ++y) for (size_t x = 0; x < width; ++x) {
            if (y >= top && y < bottom && x >= left && x < right) continue;
            for (size_t channel = 0; channel < 4; ++channel)
                expected[(y * width + x) * 4 + channel] = source[y * pitch + x * 4
                    + (channel == 0 ? 2 : channel == 2 ? 0 : channel)];
        }
        vox_copy_backdrop_pixels(output.data(), source.data(), pitch, width, height, left, top, right, bottom);
        assert(output == expected); // Padding and skipped opaque core remain untouched.
    }
}

static void check_composites()
{
    size_t width = 1027, height = 1537;
    auto source = pattern(width * height * 4), backdrop = pattern((width + 11) * height * 4);
    for (size_t i = 0; i < source.size(); i += 4)
        for (size_t c = 0; c < 3; ++c) source[i + c] %= unsigned(source[i + 3]) + 1;
    // Row and pixel partitions have different SIMD tails. Both must preserve
    // the original per-row result for all supported caller rounding modes.
    for (auto mode : {FE_TONEAREST, FE_DOWNWARD, FE_UPWARD, FE_TOWARDZERO}) {
        std::fesetround(mode);
        for (float opacity : {0.0f, 0.37f, 1.0f}) {
            auto expected = source, actual = source;
            for (size_t row = 0; row < height; ++row)
                native_composite_opacity_pixels(expected.data() + row * width * 4,
                    backdrop.data() + row * (width + 11) * 4, expected.data() + row * width * 4, width, opacity);
            vox_raster::parallel_rows(width, height, [&](size_t begin, size_t end) {
                for (auto row = begin; row < end; ++row)
                    native_composite_opacity_pixels(actual.data() + row * width * 4,
                        backdrop.data() + row * (width + 11) * 4, actual.data() + row * width * 4, width, opacity);
            }, "test-strided-composite");
            assert(actual == expected);
            assert(std::fegetround() == mode);
            actual = source;
            expected = source;
            for (size_t row = 0; row < height; ++row)
                native_composite_opacity_pixels(expected.data() + row * width * 4,
                    backdrop.data() + row * width * 4, expected.data() + row * width * 4, width, opacity);
            vox_raster::parallel_pixels(width * height, [&](size_t begin, size_t end) {
                native_composite_opacity_pixels(actual.data() + begin * 4,
                    backdrop.data() + begin * 4, actual.data() + begin * 4, end - begin, opacity);
            }, "test-prefix-composite");
            assert(actual == expected);
        }
    }
    std::fesetround(FE_TONEAREST);
}

static void benchmark()
{
    for (size_t count : {131072u, 322088u, 786432u, 1048576u, 1713840u, 2097152u, 3145728u, 8388608u}) {
        auto source = pattern(count * 4), output = source;
        for (int trial = 0; trial < 6; ++trial) for (bool parallel : {false, true}) {
            if (parallel) unsetenv("VOX_DISABLE_PARALLEL_RASTER");
            else setenv("VOX_DISABLE_PARALLEL_RASTER", "1", 1);
            auto started = std::chrono::steady_clock::now();
            for (int frame = 0; frame < 100; ++frame)
                vox_swap_red_blue_pixels(output.data(), source.data(), count);
            auto ms = std::chrono::duration<double, std::milli>(std::chrono::steady_clock::now() - started).count() / 100;
            assert(output[0] == source[2]);
            std::printf("channel-swap trial=%d parallel=%d pixels=%zu ms=%.6f\n", trial, parallel, count, ms);
        }
    }
    unsetenv("VOX_DISABLE_PARALLEL_RASTER");
}

static void tune_ranges()
{
    auto& pool = vox_raster::shared_pool();
    for (size_t count : {322088u, 1048576u, 1713840u, 3145728u, 8388608u}) {
        auto source = pattern(count * 4), output = source;
        for (int trial = 0; trial < 4; ++trial)
            for (size_t grain : {size_t(64 * 1024), size_t(256 * 1024), size_t(512 * 1024), size_t(1024 * 1024), count + 1}) {
                auto started = std::chrono::steady_clock::now();
                for (int frame = 0; frame < 100; ++frame)
                    pool.run(count, grain, [&](size_t begin, size_t end) {
                        vox_swap_red_blue_serial(output.data() + begin * 4, source.data() + begin * 4, end - begin);
                    });
                auto ms = std::chrono::duration<double, std::milli>(std::chrono::steady_clock::now() - started).count() / 100;
                assert(output[0] == source[2]);
                std::printf("range-tune trial=%d grain=%zu pixels=%zu ms=%.6f\n", trial, grain, count, ms);
            }
    }
}

int main(int argc, char** argv)
{
    unsetenv("VOX_DISABLE_PARALLEL_RASTER");
    check_scheduler();
    check_pixels();
    check_composites();
    std::puts("parallel raster scheduling, pixels and compositing: PASS");
    if (argc > 1 && std::string(argv[1]) == "--benchmark") benchmark();
    if (argc > 1 && std::string(argv[1]) == "--tune") tune_ranges();
}
