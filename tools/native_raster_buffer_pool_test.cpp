#include "../native/include/native_raster_buffer_pool.h"
#include <cassert>
#include <thread>
#include <iostream>
int main() {
    VoxRasterBufferPool pool(32);
    auto a = pool.acquire(16); auto* pixels = a->pixels.get();
    auto live = pool.acquire(16); assert(live->pixels.get() != pixels);
    pool.release(std::move(a)); assert(pool.cached_pixels() == 16);
    auto b = pool.acquire(8); assert(b->pixels.get() == pixels && pool.cached_pixels() == 0);
    pool.clear(); pool.release(std::move(live)); pool.release(std::move(b));
    assert(pool.cached_pixels() == 0);
    auto too_large = pool.acquire(33); pool.release(std::move(too_large)); assert(pool.cached_pixels() == 0);
    auto c = pool.acquire(24); auto d = pool.acquire(16);
    pool.release(std::move(c)); pool.release(std::move(d)); assert(pool.cached_pixels() == 24);
    pool.clear(true); assert(pool.cached_pixels() == 24);
    pool.clear(); assert(pool.cached_pixels() == 0);
    std::array<std::unique_ptr<VoxRasterBufferPool::Buffer>, 9> allocations;
    for (auto& buffer : allocations) buffer = pool.acquire(1);
    for (auto& buffer : allocations) pool.release(std::move(buffer)); assert(pool.cached_pixels() == 8);
    pool.clear();
    std::thread worker([&] { for (int i = 0; i < 1000; ++i) { auto x = pool.acquire(7); x->pixels[6] = i; pool.release(std::move(x)); } });
    for (int i = 0; i < 1000; ++i) { auto x = pool.acquire(9); x->pixels[8] = i; pool.release(std::move(x)); }
    worker.join(); assert(pool.cached_pixels() <= 32);
    pool.clear();
    uint32_t* leased_pixels;
    {
        auto lease = pool.lease(16);
        leased_pixels = lease->pixels.get();
        assert(!lease->reused);
        lease->pixels[15] = 0x12345678;
        auto other = pool.lease(16);
        assert(other->pixels.get() != leased_pixels);
        auto moved = std::move(lease);
        assert(!lease && moved->pixels.get() == leased_pixels);
        // Simulate a readback batch returning early: both leases must return.
    }
    assert(pool.cached_pixels() == 32);
    {
        auto lease = pool.lease(16);
        assert(lease->reused);
        pool.clear();
        // A lease that survives purge cannot repopulate the retired generation.
    }
    assert(pool.cached_pixels() == 0);
    {
        auto oversized = pool.lease(33);
        assert(oversized && oversized->capacity == 33);
    }
    assert(pool.cached_pixels() == 0);
    VoxRasterBufferPool disabled(0);
    { auto lease = disabled.lease(16); assert(lease && !lease->reused); }
    assert(disabled.cached_pixels() == 0);
    pool.clear(); std::cout << "Raster pool ownership, generation, bounds and concurrent release passed\n";
}
