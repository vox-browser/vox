#pragma once

#include <algorithm>
#include <cfenv>
#include <condition_variable>
#include <cstdio>
#include <cstdlib>
#include <exception>
#include <memory>
#include <mutex>
#include <thread>
#include <type_traits>
#include <vector>

// Only independent CPU pixel ranges belong here. CGContext, Skia recorders,
// caches and GPU submission retain their existing owner thread and ordering.
namespace vox_raster {
inline thread_local bool inside_parallel_range = false;

class ParallelRanges {
public:
    explicit ParallelRanges(unsigned capacity = std::thread::hardware_concurrency())
    {
        capacity = std::max(1u, capacity);
        try {
            m_workers.reserve(capacity - 1);
        } catch (std::bad_alloc const&) {
            return;
        }
        for (unsigned lane = 1; lane < capacity; ++lane) {
            try {
                auto slot = std::make_unique<Worker>();
                slot->thread = std::thread([this, lane, slot = slot.get()] { worker(lane, *slot); });
                m_workers.push_back(std::move(slot));
            } catch (std::system_error const&) {
                break; // Resource pressure reduces concurrency, never loses pixels.
            } catch (std::bad_alloc const&) {
                break;
            }
        }
    }

    ~ParallelRanges()
    {
        {
            std::lock_guard lock(m_state);
            m_stopping = true;
        }
        for (auto& worker : m_workers) worker->ready.notify_one();
        for (auto& worker : m_workers) worker->thread.join();
    }

    size_t capacity() const { return m_workers.size() + 1; }

    template<typename Function>
    void run(size_t count, size_t minimum_per_lane, Function&& function, char const* label = "pixels",
        size_t maximum_lanes = 0)
    {
        auto lanes = std::min(capacity(), count / std::max(size_t(1), minimum_per_lane));
        if (maximum_lanes) lanes = std::min(lanes, maximum_lanes);
        // Interactive frames share memory bandwidth with GPU submissions and
        // video decoding. Keep surplus workers asleep in this diagnostic arm;
        // range ownership, rounding and the completion barrier stay unchanged.
        if (std::getenv("VOX_LIMIT_PARALLEL_RASTER_LANES")) lanes = std::min(lanes, size_t(4));
        auto disabled = std::getenv("VOX_DISABLE_PARALLEL_RASTER");
        if (lanes < 2 || inside_parallel_range || (disabled && *disabled)) {
            if (count) function(0, count);
            return;
        }
        // A second frame producer waits here rather than sharing scratch data
        // or creating another CPU-sized pool. Nested callbacks stay serial.
        std::lock_guard submission(m_submission);
        auto invoke = [](void* context, size_t begin, size_t end) {
            (*static_cast<std::remove_reference_t<Function>*>(context))(begin, end);
        };
        {
            std::lock_guard lock(m_state);
            m_context = const_cast<void*>(static_cast<void const*>(&function));
            m_invoke = invoke;
            m_count = count;
            m_lanes = lanes;
            m_completed = 0;
            m_exception = nullptr;
            m_rounding = std::fegetround();
            ++m_generation;
        }
        // Keep unused workers asleep. Waking every core for a two-lane copy
        // makes narrow damage more expensive than its original serial loop.
        for (size_t lane = 1; lane < lanes; ++lane) m_workers[lane - 1]->ready.notify_one();
        execute(0);
        std::exception_ptr failure;
        {
            std::unique_lock lock(m_state);
            m_finished.wait(lock, [&] { return m_completed == m_lanes - 1; });
            failure = m_exception;
            m_context = nullptr;
        }
        if (std::getenv("VOX_PARALLEL_RASTER_DIAGNOSTICS"))
            std::fprintf(stderr, "VOX_PARALLEL_RASTER kind=%s units=%zu lanes=%zu capacity=%zu\n",
                label, count, lanes, capacity());
        if (failure) std::rethrow_exception(failure);
    }

private:
    struct Worker {
        std::condition_variable ready;
        std::thread thread;
    };

    void execute(size_t lane)
    {
        auto previous_rounding = std::fegetround();
        std::fesetround(m_rounding);
        inside_parallel_range = true;
        try {
            // Quotient/remainder partitioning also avoids count * lane overflow.
            auto chunk = m_count / m_lanes, extra = m_count % m_lanes;
            auto begin = chunk * lane + std::min(lane, extra);
            m_invoke(m_context, begin, begin + chunk + (lane < extra));
        } catch (...) {
            std::lock_guard lock(m_state);
            if (!m_exception) m_exception = std::current_exception();
        }
        inside_parallel_range = false;
        std::fesetround(previous_rounding);
    }

    void worker(size_t lane, Worker& slot)
    {
        size_t generation = 0;
        std::unique_lock lock(m_state);
        for (;;) {
            slot.ready.wait(lock, [&] { return m_stopping || m_generation != generation; });
            if (m_stopping) return;
            generation = m_generation;
            if (lane >= m_lanes) continue;
            lock.unlock();
            execute(lane);
            lock.lock();
            ++m_completed;
            m_finished.notify_one();
        }
    }

    std::vector<std::unique_ptr<Worker>> m_workers;
    std::mutex m_submission, m_state;
    std::condition_variable m_finished;
    size_t m_count = 0, m_lanes = 0, m_completed = 0, m_generation = 0;
    bool m_stopping = false;
    int m_rounding = FE_TONEAREST;
    void* m_context = nullptr;
    void (*m_invoke)(void*, size_t, size_t) = nullptr;
    std::exception_ptr m_exception;
};

// Range-size sweeps on Retina-sized buffers show that tiny SIMD copies finish
// before sleeping workers can wake. Give each participant at least 2 MiB of
// pixels; larger images can still recruit every available logical CPU.
inline constexpr size_t minimum_pixels_per_lane = 512 * 1024;

inline ParallelRanges& shared_pool()
{
    static ParallelRanges pool;
    return pool;
}

inline bool disabled()
{
    auto value = std::getenv("VOX_DISABLE_PARALLEL_RASTER");
    return value && *value;
}

template<typename Function>
inline void parallel_pixels(size_t count, Function&& function, char const* label)
{
    // Do not start workers, inspect environment, or acquire a lock for glyphs
    // and narrow scroll strips. The caller participates in every large job.
    if (count < 2 * minimum_pixels_per_lane || inside_parallel_range || disabled()) {
        if (count) function(0, count);
        return;
    }
    shared_pool().run(count, minimum_pixels_per_lane, function, label);
}

template<typename Function>
inline void parallel_rows(size_t width, size_t height, Function&& function, char const* label,
    size_t maximum_lanes = 0)
{
    // Dispatch pixel-sized ranges but assign whole rows to each participant.
    // Width is nonzero at all raster callers; accept empty buffers as a no-op.
    if (!width || !height) return;
    if (height < 2 || width < (2 * minimum_pixels_per_lane + height - 1) / height
        || inside_parallel_range || disabled()) {
        function(0, height);
        return;
    }
    shared_pool().run(height, std::max(size_t(1), (minimum_pixels_per_lane + width - 1) / width),
        function, label, maximum_lanes);
}
}
