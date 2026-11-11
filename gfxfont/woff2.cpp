// Copyright (c) 2024, Andreas Kling <andreas@ladybird.org>
// SPDX-License-Identifier: BSD-2-Clause
// LibGfx/Font/WOFF2/Loader.cpp: WOFF2ByteBufferOut and convert_to_ttf.
// std::vector and malloc project the source ByteBuffer/AnonymousBuffer ABI.
#include "woff2.h"
#include <woff2/decode.h>
#include <cstdlib>
#include <cstring>
#include <limits>
#include <new>
#include <stdexcept>
#include <vector>

static constexpr size_t MAX_OUTPUT_SIZE = 30 * 1024 * 1024;

class WOFF2ByteBufferOut final : public woff2::WOFF2Out {
public:
    explicit WOFF2ByteBufferOut(std::vector<uint8_t>& buffer) : m_buffer(buffer) { }
    bool Write(void const* data, size_t size) override
    {
        if (size > MAX_OUTPUT_SIZE - m_buffer.size())
            return false;
        try {
            auto bytes = static_cast<uint8_t const*>(data);
            m_buffer.insert(m_buffer.end(), bytes, bytes + size);
        } catch (std::exception const&) { return false; }
        return true;
    }
    bool Write(void const* data, size_t offset, size_t n) override
    {
        if (n > std::numeric_limits<size_t>::max() - offset)
            return false;
        if (offset + n > MAX_OUTPUT_SIZE)
            return false;
        if (offset + n > m_buffer.size()) {
            try { m_buffer.resize(offset + n); }
            catch (std::exception const&) { return false; }
        }
        if (n > 0)
            memcpy(m_buffer.data() + offset, data, n);
        return true;
    }
    size_t Size() override { return m_buffer.size(); }
private:
    std::vector<uint8_t>& m_buffer;
};

extern "C" uint8_t* vox_woff2_convert_to_ttf(uint8_t const* bytes, size_t size, size_t* output_size)
{
    std::vector<uint8_t> ttf_buffer;
    WOFF2ByteBufferOut output { ttf_buffer };
    if (!woff2::ConvertWOFF2ToTTF(bytes, size, &output))
        return nullptr;
    auto anonymous_buffer = static_cast<uint8_t*>(malloc(ttf_buffer.empty() ? 1 : ttf_buffer.size()));
    if (!anonymous_buffer)
        return nullptr;
    if (!ttf_buffer.empty())
        memcpy(anonymous_buffer, ttf_buffer.data(), ttf_buffer.size());
    *output_size = ttf_buffer.size();
    return anonymous_buffer;
}
extern "C" void vox_woff2_free(void* data) { free(data); }
