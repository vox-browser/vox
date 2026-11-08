// Platform integration only: Vox opts out of macOS Writing Tools before AppKit
// finishes launching, so neither the Edit menu nor the first text input context
// loads the Writing Tools UI framework. Run once normally and once with
// VOX_ENABLE_WRITING_TOOLS=1 to check that AppKit's own behavior still loads it.
#include "../native/include/native_writing_tools_darwin.h"
#include <assert.h>
#include <mach-o/dyld.h>
#include <objc/message.h>
#include <stdio.h>

static int writing_tools_menu_items(NSMenu *menu)
{
    int count = 0;
    for (NSMenuItem *item in menu.itemArray)
        if ([item.identifier containsString:@"WritingTools"]) ++count;
    return count;
}

static int writing_tools_ui_loaded(void)
{
    for (uint32_t i = 0; i < _dyld_image_count(); ++i)
        if (strstr(_dyld_get_image_name(i), "/WritingToolsUI.framework/")) return 1;
    return 0;
}

int main(void)
{
    @autoreleasepool {
        char const *keep = getenv("VOX_ENABLE_WRITING_TOOLS");
        int kept = keep && *keep && strcmp(keep, "0") != 0;
        Class coordinator = objc_getClass("NSWritingToolsCoordinator");
        int replaced = native_disable_writing_tools();
        if (!coordinator) {
            assert(replaced == 0);
            printf("SKIP: this macOS has no NSWritingToolsCoordinator\n");
            return 0;
        }
        assert(replaced == (kept ? 0 : 3));
        // The replacement is idempotent; a second call installs the same answers.
        if (!kept) assert(native_disable_writing_tools() == 3);
        assert(!writing_tools_ui_loaded());

        // The launch steps that load the framework: Edit menu customization in
        // finishLaunching, then the first text input context in updateWindows.
        NSApplication *application = [NSApplication sharedApplication];
        NSMenu *main_menu = [[NSMenu alloc] initWithTitle:@""];
        NSMenuItem *edit_item = [[NSMenuItem alloc] initWithTitle:@"Edit" action:nil keyEquivalent:@""];
        NSMenu *edit = [[NSMenu alloc] initWithTitle:@"Edit"];
        [edit addItemWithTitle:@"Copy" action:@selector(copy:) keyEquivalent:@"c"];
        [edit addItemWithTitle:@"Paste" action:@selector(paste:) keyEquivalent:@"v"];
        edit_item.submenu = edit;
        [main_menu addItem:edit_item];
        application.mainMenu = main_menu;
        [application finishLaunching];
        [application updateWindows];
        (void)[NSTextInputContext class];

        BOOL available = ((BOOL(*)(id, SEL))objc_msgSend)(coordinator, sel_registerName("isWritingToolsAvailable"));
        if (kept) {
            if (!available) {
                printf("SKIP: Writing Tools are unavailable on this system\n");
                return 0;
            }
            assert(writing_tools_ui_loaded());
            assert(writing_tools_menu_items(edit) > 0);
            printf("PASS: AppKit loads Writing Tools when Vox keeps them\n");
        } else {
            assert(!available);
            id observer = ((id(*)(id, SEL, id))objc_msgSend)(coordinator,
                sel_registerName("addObserverForEnhancedSiriAvailabilityDidChangeUsingBlock:"), ^(NSNotification *note) { (void)note; });
            assert(observer == nil);
            assert(!writing_tools_ui_loaded());
            assert(writing_tools_menu_items(edit) == 0);
            printf("PASS: Writing Tools stay unloaded through launch and text input setup\n");
        }
    }
    return 0;
}
