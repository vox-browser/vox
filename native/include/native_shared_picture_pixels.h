#pragma once
#include <atomic>
#include <cstdint>
#include <memory>
#include <mutex>
#include <unordered_map>

// Cross-Skia values and C callbacks only. No Skia or C++ object crosses the ABI.
struct VoxSharedPicturePixelsLease {
    uint8_t const* bytes = nullptr;
    size_t size = 0;
    void* owner = nullptr;
    void (*release)(void*) = nullptr;
};
using VoxAcquireSharedPicturePixels = int (*)(uint64_t, VoxSharedPicturePixelsLease*);

// Tokens live for one synchronous picture transaction. A decoder lease keeps
// immutable bytes alive after retirement; leased bytes still count to the cap.
class VoxSharedPicturePixelsRegistry {
    struct Payload {
        std::shared_ptr<void const> owner;
        uint8_t const* bytes;
        size_t size;
        std::shared_ptr<std::atomic<size_t>> live;
        ~Payload() { live->fetch_sub(size, std::memory_order_relaxed); }
    };
    std::mutex mutex_;
    std::unordered_map<uint64_t, std::shared_ptr<Payload>> entries_;
    std::shared_ptr<std::atomic<size_t>> live_ = std::make_shared<std::atomic<size_t>>(0);
    uint64_t next_ = 1;
    size_t byte_limit_, count_limit_;
public:
    explicit VoxSharedPicturePixelsRegistry(size_t bytes = 64 * 1024 * 1024, size_t count = 32)
        : byte_limit_(bytes), count_limit_(count) { }
    uint64_t insert(std::shared_ptr<void const> owner, uint8_t const* bytes, size_t size) {
        if (!owner || !bytes || !size) return 0;
        std::lock_guard lock(mutex_);
        if (!next_ || entries_.size() >= count_limit_ || size > byte_limit_
            || live_->load(std::memory_order_relaxed) > byte_limit_ - size) return 0;
        auto payload = std::make_shared<Payload>();
        payload->owner = std::move(owner); payload->bytes = bytes; payload->size = size; payload->live = live_;
        live_->fetch_add(size, std::memory_order_relaxed);
        auto token = next_++;
        entries_.emplace(token, std::move(payload));
        return token;
    }
    bool acquire(uint64_t token, VoxSharedPicturePixelsLease* out) {
        if (!out) return false;
        std::lock_guard lock(mutex_);
        auto found = entries_.find(token);
        if (found == entries_.end()) return false;
        auto* lease = new std::shared_ptr<Payload>(found->second);
        *out = {(*lease)->bytes, (*lease)->size, lease,
            [](void* owner) { delete static_cast<std::shared_ptr<Payload>*>(owner); }};
        return true;
    }
    void retire(uint64_t token) {
        std::shared_ptr<Payload> retired;
        {
            std::lock_guard lock(mutex_);
            auto found = entries_.find(token);
            if (found == entries_.end()) return;
            retired = std::move(found->second);
            entries_.erase(found);
        }
    }
    size_t live_bytes() const { return live_->load(std::memory_order_relaxed); }
};
