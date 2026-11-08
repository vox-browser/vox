#include "../native/include/native_video_image_resource.h"
#include <assert.h>
#include <stdio.h>

int main(void) {
    assert(!native_video_image_resource_identity(0,1,0));
    assert(!native_video_image_resource_identity(1,0,0));
    uint64_t initial=native_video_image_resource_identity(1,1,0);
    assert(initial && initial >> 63);
    assert(native_video_image_resource_identity(1,1,0)==initial);
    uint64_t rewritten=native_video_image_resource_identity(1,1,1);
    assert(rewritten && rewritten!=initial);
    uint64_t replaced=native_video_image_resource_identity(1,2,0);
    assert(replaced && replaced!=initial && replaced!=rewritten);
    assert(native_video_image_resource_identity(1,1,0)!=initial);
    for(uint64_t source=2;source<132;++source)
        assert(native_video_image_resource_identity(source,1,0));
    assert(native_video_image_resource_identity(1,1,0)!=initial);
    native_video_image_resource_clock=UINT64_MAX>>1;
    assert(!native_video_image_resource_identity(1,2,3));
    assert(!native_video_image_resource_identity(200,1,0));
    puts("Video texture identities: stable frame, rewrite, replacement, bounded eviction and exhaustion passed");
}
