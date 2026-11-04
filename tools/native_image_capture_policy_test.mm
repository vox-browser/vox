#include "../native_image_capture_policy_darwin.h"
#include <cassert>
#include <cstdio>

int main(int argc, char **argv) {
    @autoreleasepool {
        assert(argc == 2);
        NSData *bytes = [NSData dataWithContentsOfFile:[NSString stringWithUTF8String:argv[1]]];
        NSBitmapImageRep *image = [[NSBitmapImageRep alloc] initWithData:bytes];
        assert(image && [[image valueForProperty:NSImageFrameCount] integerValue] == 2);
        auto red = [&] {
            NSColor *color = [[image colorAtX:0 y:0] colorUsingColorSpace:NSColorSpace.sRGBColorSpace];
            return color.redComponent > .99 && color.blueComponent < .01;
        };
        [image setProperty:NSImageCurrentFrame withValue:@1];
        assert([[image valueForProperty:NSImageCurrentFrame] integerValue] == 1);
        assert(vox_apply_image_capture_policy(image, "none", true) && red());
        assert([[image valueForProperty:NSImageCurrentFrame] integerValue] == 0);
        assert(vox_apply_image_capture_policy(image, nullptr, true));
        assert([[image valueForProperty:NSImageCurrentFrame] integerValue] == 1);
        assert(!vox_apply_image_capture_policy(image, nullptr, false));
        assert([[image valueForProperty:NSImageCurrentFrame] integerValue] == 1);
        assert(vox_apply_image_capture_policy(image, "none", false) && red());
        assert([[image valueForProperty:NSImageCurrentFrame] integerValue] == 0);
        std::puts("PASS: first-frame policy selects original GIF pixels and preserves the legacy checkpoint");
    }
}
