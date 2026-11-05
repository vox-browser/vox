#include <AppKit/AppKit.h>
#include <objc/runtime.h>
#include <stdlib.h>
#include <string.h>

// AppKit registers the application with UIIntelligence during launch so Apple
// Intelligence can read its on-screen content. Vox opts out of that integration
// by default. Install before NSApplication launches; VOX_ENABLE_UI_INTELLIGENCE=1
// preserves AppKit's registration. This is independent of the Writing Tools and
// window/tab Spotlight indexing opt-outs.
static void native_ui_intelligence_skip_registration(id self, SEL selector)
{
    (void)self;
    (void)selector;
}

int native_disable_ui_intelligence(void)
{
    char const *keep = getenv("VOX_ENABLE_UI_INTELLIGENCE");
    if (keep && *keep && strcmp(keep, "0") != 0) return 0;
    Class application = objc_getClass("NSApplication");
    if (!application) return 0;
    Method registration = class_getInstanceMethod(application,
        sel_registerName("_registerApplicationWithUIIntelligence"));
    if (!registration || method_getNumberOfArguments(registration) != 2) return 0;
    // This private hook may disappear or change on another macOS release.
    // Only replace the known void, no-argument instance method.
    char return_type[8] = {0};
    method_getReturnType(registration, return_type, sizeof(return_type));
    if (strcmp(return_type, "v") != 0) return 0;
    method_setImplementation(registration, (IMP)native_ui_intelligence_skip_registration);
    return 1;
}
