#include <assert.h>
#include "../native/include/native_deferred_font_darwin.h"
static int loads;
static void loaded(const char *path) { assert(path && *path); ++loads; }
int main(void) {
    @autoreleasepool {
        VoxDeferredFont font = {0};
        NSString *arial = @"/System/Library/Fonts/Supplemental/Arial.ttf";
        NSString *georgia = @"/System/Library/Fonts/Supplemental/Georgia.ttf";
        native_deferred_font_configure(&font, arial);
        assert(!font.font && !font.attempted && loads == 0);
        CGFontRef first = native_deferred_font_resolve(&font, loaded);
        assert(first && font.attempted && loads == 1);
        assert(native_deferred_font_resolve(&font, loaded) == first && loads == 1);
        native_deferred_font_configure(&font, arial);
        assert(font.attempted && loads == 1);
        native_deferred_font_configure(&font, georgia);
        assert(!font.attempted && loads == 1);
        CGFontRef second = native_deferred_font_resolve(&font, loaded);
        assert(second && loads == 2);
        CFStringRef name = CGFontCopyPostScriptName(second);
        assert(CFStringFind(name, CFSTR("Georgia"), 0).location != kCFNotFound);
        CFRelease(name);
        native_deferred_font_configure(&font, @__FILE__);
        assert(!font.attempted);
        assert(native_deferred_font_resolve(&font, loaded) == second && loads == 2);
        assert(!native_deferred_font_configure_refresh(&font, @"/vox-font-does-not-exist"));
        assert(font.attempted && native_deferred_font_resolve(&font, loaded) == second && loads == 2);
        assert(native_deferred_font_configure_refresh(&font, georgia));
        assert(!font.attempted && font.font == second && loads == 2);
        assert(native_deferred_font_resolve(&font, loaded) && loads == 3);
        assert(native_deferred_font_configure_refresh(&font, georgia));
        assert(!font.attempted);
        assert(native_deferred_font_resolve(&font, loaded) && loads == 4);
        assert(native_deferred_font_resolve(&font, loaded) && loads == 4);
        native_deferred_font_clear(&font);
        assert(!font.font && !font.path && !font.attempted);
        puts("PASS deferred font opening, first-use loading, reuse, explicit same-path refresh, failed-file fallback and cleanup");
    }
}
