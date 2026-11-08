#import <Cocoa/Cocoa.h>
#import <CoreImage/CoreImage.h>
#include <assert.h>
#include <malloc/malloc.h>
#include <stdint.h>
#include "../native/include/native_layer_presentation_darwin.h"

static unsigned graphics_releases;
static unsigned managed_deliveries;
static unsigned idle_checks;
static unsigned pending_idle_checks;
static unsigned pressure_reliefs;
static unsigned filter_reclaims;
static unsigned filter_clears;
static unsigned expected_filter_clears;
static unsigned created_probes;
static unsigned destroyed_probes;
static void *expected_owner;
static CIContext *native_css_filter_ci_context;

@interface MemoryCleanupProbe : NSObject
@end
@implementation MemoryCleanupProbe
- (void)dealloc { destroyed_probes++; }
@end

static void create_autoreleased_cleanup_probe(void) {
    unsigned previous_destructions = destroyed_probes;
    __autoreleasing MemoryCleanupProbe *probe = [MemoryCleanupProbe new];
    created_probes++;
    assert(probe != nil);
    assert(destroyed_probes == previous_destructions);
}

void ladybird_v_skia_release_unused_graphics_memory(void) {
    assert([NSThread isMainThread]);
    assert(!native_layer_document_work_active && !native_layer_presenting);
    graphics_releases++;
    if (native_css_filter_ci_context != nil) expected_filter_clears++;
    create_autoreleased_cleanup_probe();
}

int ladybird_v_skia_release_idle_graphics_memory(void) {
    assert([NSThread isMainThread]);
    assert(!native_layer_document_work_active && !native_layer_presenting);
    idle_checks++;
    create_autoreleased_cleanup_probe();
    if (!pending_idle_checks) return 0;
    pending_idle_checks--;
    return 1;
}

static size_t test_malloc_zone_pressure_relief(malloc_zone_t *zone, size_t goal) {
    assert(zone == NULL && goal == 0);
    assert([NSThread isMainThread]);
    assert(!native_layer_document_work_active && !native_layer_presenting);
    assert(created_probes == destroyed_probes);
    assert(filter_reclaims == expected_filter_clears);
    assert(filter_clears == expected_filter_clears);
    pressure_reliefs++;
    assert(pressure_reliefs == graphics_releases + idle_checks);
    return 0; // Lack of allocator headroom must not stop GPU retirement polls.
}

// The driver extracts these function bodies verbatim from the production host.
#define malloc_zone_pressure_relief test_malloc_zone_pressure_relief
#include VOX_NATIVE_MEMORY_FRAGMENT
#undef malloc_zone_pressure_relief

@interface MemoryTestContext : NSObject
@property unsigned reclaims;
@property unsigned clears;
@end
@implementation MemoryTestContext
- (void)reclaimResources {
    self.reclaims++;
    filter_reclaims++;
    create_autoreleased_cleanup_probe();
}
- (void)clearCaches {
    self.clears++;
    filter_clears++;
    create_autoreleased_cleanup_probe();
}
@end

static void pump(double seconds) {
    CFAbsoluteTime end = CFAbsoluteTimeGetCurrent() + seconds;
    do {
        CFRunLoopRunInMode(kCFRunLoopDefaultMode, 0.002, true);
    } while (CFAbsoluteTimeGetCurrent() < end);
}

static void managed_cleanup(void *owner) {
    assert([NSThread isMainThread]);
    assert(owner == expected_owner);
    assert(!native_layer_document_work_active && !native_layer_presenting);
    managed_deliveries++;
}

int main(void) {
    @autoreleasepool {
        int owner;
        expected_owner = &owner;
        native_dispatch_browser_memory_cleanup(expected_owner, NULL);
        native_dispatch_browser_memory_cleanup(expected_owner, managed_cleanup);
        assert(managed_deliveries == 0); // Delivery must leave the paint stack.
        pump(0.03);
        assert(managed_deliveries == 1);

        native_layer_document_work_active = YES;
        native_dispatch_browser_memory_cleanup(expected_owner, managed_cleanup);
        pump(0.03);
        assert(managed_deliveries == 1);
        native_layer_document_work_active = NO;
        native_layer_presenting = YES;
        pump(0.03);
        assert(managed_deliveries == 1);
        native_layer_presenting = NO;
        pump(0.03);
        assert(managed_deliveries == 2);
        assert(pressure_reliefs == 0);

        // A final frame must retire a context even when the first check is
        // earlier than its idle threshold and no more frames are requested.
        pending_idle_checks = 2;
        native_schedule_idle_graphics_cleanup();
        native_schedule_idle_graphics_cleanup();
        pump(1.10);
        assert(idle_checks == 1);
        assert(pressure_reliefs == 1);
        pump(1.10);
        assert(idle_checks == 2);
        assert(pressure_reliefs == 2);
        pump(1.10);
        assert(idle_checks == 3);
        assert(pressure_reliefs == 3);
        pump(1.10);
        assert(idle_checks == 3); // No permanent polling after retirement.
        assert(pressure_reliefs == 3);

        native_layer_document_work_active = YES;
        native_schedule_idle_graphics_cleanup();
        pump(1.10);
        assert(idle_checks == 3);
        assert(pressure_reliefs == 3);
        native_layer_document_work_active = NO;
        native_layer_presenting = YES;
        pump(0.03);
        assert(idle_checks == 3 && pressure_reliefs == 3);
        native_layer_presenting = NO;
        pump(0.10);
        assert(idle_checks == 4);
        assert(pressure_reliefs == 4);

        native_schedule_static_graphics_cleanup();
        pump(0.05);
        native_schedule_static_graphics_cleanup();
        pump(0.22);
        assert(graphics_releases == 0); // First deadline was superseded.
        assert(pressure_reliefs == 4);
        pump(0.12);
        assert(graphics_releases == 1);
        assert(pressure_reliefs == 5);
        assert(native_css_filter_ci_context == nil); // Never creates a renderer.

        MemoryTestContext *context = [MemoryTestContext new];
        native_css_filter_ci_context = (CIContext *)context;
        native_layer_document_work_active = YES;
        native_schedule_static_graphics_cleanup();
        pump(0.30);
        assert(graphics_releases == 1 && context.reclaims == 0);
        assert(pressure_reliefs == 5);
        // A second frame supersedes even a cleanup waiting for document work.
        native_schedule_static_graphics_cleanup();
        native_layer_document_work_active = NO;
        pump(0.04);
        assert(graphics_releases == 1);
        assert(pressure_reliefs == 5);
        pump(0.30);
        assert(graphics_releases == 2);
        assert(context.reclaims == 1 && context.clears == 1);
        assert(pressure_reliefs == 6);

        dispatch_group_t group = dispatch_group_create();
        dispatch_group_async(group, dispatch_get_global_queue(QOS_CLASS_DEFAULT, 0), ^{
            assert(![NSThread isMainThread]);
            native_release_unused_graphics_memory();
        });
        dispatch_group_wait(group, DISPATCH_TIME_FOREVER);
        assert(graphics_releases == 2);
        assert(context.reclaims == 1 && context.clears == 1);
        assert(pressure_reliefs == 6);
        assert(created_probes == 8 && destroyed_probes == 8);
        native_css_filter_ci_context = nil;
        puts("Native idle cleanup: deferred delivery, busy guards, coalescing, lazy renderer, cache reclamation, autorelease drain, pressure relief and owner thread passed.");
    }
    return 0;
}
