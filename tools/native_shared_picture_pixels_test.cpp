#include "../native/include/native_shared_picture_pixels.h"
#include <cassert>
#include <vector>
#include <iostream>

int main() {
    VoxSharedPicturePixelsRegistry registry(256, 2);
    auto data = std::make_shared<std::vector<uint8_t>>(128, 71);
    auto token = registry.insert(data, data->data(), data->size());
    assert(token && registry.live_bytes() == 128);
    VoxSharedPicturePixelsLease lease;
    assert(registry.acquire(token, &lease));
    data.reset(); registry.retire(token);
    assert(!registry.acquire(token, nullptr));
    VoxSharedPicturePixelsLease missing;
    assert(!registry.acquire(token, &missing));
    assert(lease.size == 128 && lease.bytes[127] == 71 && registry.live_bytes() == 128);
    auto larger = std::make_shared<std::vector<uint8_t>>(192, 33);
    assert(!registry.insert(larger, larger->data(), larger->size()));
    lease.release(lease.owner); assert(!registry.live_bytes());
    auto newer = registry.insert(larger, larger->data(), larger->size());
    assert(newer && newer != token);
    assert(!registry.acquire(token, &missing));
    VoxSharedPicturePixelsLease retained;
    assert(registry.acquire(newer, &retained));
    registry.retire(newer); assert(registry.live_bytes() == 192);
    retained.release(retained.owner); assert(!registry.live_bytes());
    auto small = std::make_shared<std::vector<uint8_t>>(16, 19);
    auto first = registry.insert(small, small->data(), 16);
    auto second = registry.insert(small, small->data(), 16);
    assert(first && second && first != second);
    assert(!registry.insert(small, small->data(), 16));
    registry.retire(first); registry.retire(second);
    assert(!registry.live_bytes());
    std::cout << "Shared picture pixels retain immutable ownership through token retirement, count live leases, enforce bounds and reject stale tokens\n";
}
