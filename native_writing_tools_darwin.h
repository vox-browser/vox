#include <AppKit/AppKit.h>
#include <objc/runtime.h>
#include <stdlib.h>
#include <string.h>

// Vox does not offer macOS Writing Tools. AppKit otherwise loads their UI
// frameworks (several hundred images) on every launch: once to decide whether
// the Edit menu gets a Writing Tools item, and again when the first text input
// context starts observing Siri availability. Both class methods already
// answer NO and nil on systems without Writing Tools; answer that way here.
// Install before NSApplication finishes launching. VOX_ENABLE_WRITING_TOOLS=1
// keeps AppKit's behavior. Returns a bit per replaced method.
static BOOL native_writing_tools_unavailable(id self, SEL selector)
{
    (void)self;
    (void)selector;
    return NO;
}

static id native_writing_tools_no_observer(id self, SEL selector, id block)
{
    (void)self;
    (void)selector;
    (void)block;
    return nil;
}

int native_disable_writing_tools(void)
{
    char const *keep = getenv("VOX_ENABLE_WRITING_TOOLS");
    if (keep && *keep && strcmp(keep, "0") != 0) return 0;
    Class coordinator = objc_getClass("NSWritingToolsCoordinator");
    if (!coordinator) return 0;
    Method available = class_getClassMethod(coordinator, sel_registerName("isWritingToolsAvailable"));
    Method observe = class_getClassMethod(coordinator,
        sel_registerName("addObserverForEnhancedSiriAvailabilityDidChangeUsingBlock:"));
    int replaced = 0;
    if (available) {
        method_setImplementation(available, (IMP)native_writing_tools_unavailable);
        replaced |= 1;
    }
    if (observe) {
        method_setImplementation(observe, (IMP)native_writing_tools_no_observer);
        replaced |= 2;
    }
    return replaced;
}
