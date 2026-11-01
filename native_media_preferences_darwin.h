#include <AppKit/AppKit.h>

int native_prefers_reduced_transparency(void)
{
    return NSWorkspace.sharedWorkspace.accessibilityDisplayShouldReduceTransparency;
}
