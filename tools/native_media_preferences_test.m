// Platform integration only: the browser must read the same accessibility
// preferences as other native applications without changing those settings.
#include "../native/include/native_media_preferences_darwin.h"
#include <assert.h>

int main(void)
{
    @autoreleasepool {
        assert((native_prefers_reduced_motion() != 0)
            == NSWorkspace.sharedWorkspace.accessibilityDisplayShouldReduceMotion);
        assert((native_prefers_reduced_transparency() != 0)
            == NSWorkspace.sharedWorkspace.accessibilityDisplayShouldReduceTransparency);
    }
    return 0;
}
