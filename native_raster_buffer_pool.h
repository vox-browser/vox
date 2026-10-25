#pragma once
#include <array>
#include <chrono>
#include <cstdint>
#include <memory>
#include <mutex>
#include <new>

// Only detached, provider-released allocations may be reused. Purging advances
// the generation so a delayed image cannot refill an explicitly emptied pool.
class VoxRasterBufferPool {
public:
    struct Buffer {
        std::unique_ptr<uint32_t[]> pixels;
        size_t capacity = 0;
        uint64_t generation = 0;
    };
    explicit VoxRasterBufferPool(size_t limit = 8 * 1024 * 1024) : limit_(limit) { }
    std::unique_ptr<Buffer> acquire(size_t count) {
        uint64_t generation;
        {
            std::lock_guard lock(mutex_);
            last_use_ = std::chrono::steady_clock::now();
            generation = generation_;
            size_t best = slots_.size();
            for (size_t i = 0; i < slots_.size(); ++i)
                if (slots_[i] && slots_[i]->capacity >= count
                    && (best == slots_.size() || slots_[i]->capacity < slots_[best]->capacity)) best = i;
            if (best != slots_.size()) {
                auto result = std::move(slots_[best]);
                cached_ -= result->capacity;
                return result;
            }
        }
        auto result = std::make_unique<Buffer>();
        result->pixels.reset(new (std::nothrow) uint32_t[count]);
        if (!result->pixels) return nullptr;
        result->capacity = count; result->generation = generation;
        return result;
    }
    void release(std::unique_ptr<Buffer> buffer) {
        if (!buffer) return;
        std::lock_guard lock(mutex_);
        if (buffer->generation != generation_ || buffer->capacity > limit_ - cached_) return;
        for (auto& slot : slots_) if (!slot) {
            cached_ += buffer->capacity; slot = std::move(buffer); return;
        }
    }
    void clear(bool only_if_idle = false) {
        std::array<std::unique_ptr<Buffer>, 8> retired;
        {
            std::lock_guard lock(mutex_);
            if (only_if_idle && std::chrono::steady_clock::now() - last_use_ < std::chrono::seconds(2)) return;
            retired = std::move(slots_); cached_ = 0; ++generation_;
        }
    }
    size_t cached_pixels() {
        std::lock_guard lock(mutex_); return cached_;
    }
private:
    std::mutex mutex_;
    std::array<std::unique_ptr<Buffer>, 8> slots_;
    size_t limit_, cached_ = 0;
    uint64_t generation_ = 0;
    std::chrono::steady_clock::time_point last_use_;
};
