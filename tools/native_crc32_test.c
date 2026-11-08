#include "../native/include/native_crc32.h"
#include <assert.h>
#include <stdio.h>

int main(void)
{
    unsigned char bytes[8192+64];
    uint32_t seed = 0x67d92a51;
    for (size_t i = 0; i < sizeof(bytes); ++i) { seed = seed*1664525u+1013904223u; bytes[i] = seed >> 24; }
    unsigned cases = 0;
    assert(vox_crc32(0,NULL,0) == crc32(0,NULL,0));
    assert(vox_crc32(123,NULL,41) == crc32(123,NULL,41));
    assert(vox_crc32(0,(Bytef const*)"123456789",9) == 0xcbf43926u);
    for (unsigned offset = 0; offset < 32; ++offset) {
        for (unsigned length = 0; length <= 8192; ++length) {
            uLong initial = (length&1) ? 0x9bf4172du : 0;
            assert(vox_crc32(initial,bytes+offset,length) == crc32(initial,bytes+offset,length));
            ++cases;
        }
        uLong crc = 0;
        for (unsigned position = 0; position < 8192; position += 64) {
            crc = vox_crc32(crc,bytes+offset+position,64);
            assert(crc == crc32(0,bytes+offset,position+64));
        }
    }
    setenv("VOX_DISABLE_HARDWARE_SNAPSHOT_CRC","1",1);
    assert(vox_crc32(0,bytes,8192) == crc32(0,bytes,8192));
    puts("PASS exact IEEE checksums, unaligned tails, incremental updates and fallback");
    printf("CRC cases: %u\n",cases);
}
