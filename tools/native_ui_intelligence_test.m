// Run in fresh processes with VOX_ENABLE_UI_INTELLIGENCE unset, empty, 0 and 1.
// Exercise AppKit launch itself: the opt-out must suppress registration, while
// the override must leave the original registration reachable and invoke it.
#include "../native_ui_intelligence_darwin.h"
#include "../native_writing_tools_darwin.h"
#include <assert.h>
#include <stdio.h>

static IMP original_registration;
static unsigned registration_calls;

static void observe_registration(id self, SEL selector)
{
    ++registration_calls;
    ((void (*)(id, SEL))original_registration)(self, selector);
}

int main(void)
{
    @autoreleasepool {
        char const *keep = getenv("VOX_ENABLE_UI_INTELLIGENCE");
        int kept = keep && *keep && strcmp(keep, "0") != 0;
        Method registration = class_getInstanceMethod([NSApplication class],
            sel_registerName("_registerApplicationWithUIIntelligence"));
        if (!registration) {
            assert(native_disable_ui_intelligence() == 0);
            printf("SKIP: this macOS has no UIIntelligence registration hook\n");
            return 0;
        }
        assert(method_getNumberOfArguments(registration) == 2);
        char return_type[8] = {0};
        method_getReturnType(registration, return_type, sizeof(return_type));
        assert(strcmp(return_type, "v") == 0);
        original_registration = method_setImplementation(registration, (IMP)observe_registration);
        assert(native_disable_ui_intelligence() == (kept ? 0 : 1));
        IMP installed = method_getImplementation(registration);
        assert(installed == (kept ? (IMP)observe_registration
                                 : (IMP)native_ui_intelligence_skip_registration));
        assert(native_disable_ui_intelligence() == (kept ? 0 : 1));
        assert(method_getImplementation(registration) == installed);

        // Keep the separate Writing Tools policy out of this startup check.
        native_disable_writing_tools();
        NSApplication *application = [NSApplication sharedApplication];
        __block BOOL finished_launching = NO;
        id observer = [[NSNotificationCenter defaultCenter]
            addObserverForName:NSApplicationDidFinishLaunchingNotification
            object:application queue:nil usingBlock:^(NSNotification *note) {
                (void)note;
                finished_launching = YES;
                // Stop after run() enters its event loop, as Sokol does.
                dispatch_async(dispatch_get_main_queue(), ^{
                    [application stop:nil];
                    [application postEvent:[NSEvent otherEventWithType:NSEventTypeApplicationDefined
                        location:NSZeroPoint modifierFlags:0 timestamp:0 windowNumber:0
                        context:nil subtype:0 data1:0 data2:0] atStart:NO];
                });
            }];
        [application run];
        [application updateWindows];
        assert(finished_launching);
        [[NSNotificationCenter defaultCenter] removeObserver:observer];
        assert(kept ? registration_calls > 0 : registration_calls == 0);
        printf("PASS: AppKit launch %s UIIntelligence registration (%u original calls)\n",
            kept ? "preserves" : "skips", registration_calls);
    }
    return 0;
}
