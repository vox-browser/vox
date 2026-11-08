#ifndef VOX_NATIVE_DRAWABLES_TEST_DARWIN_H
#define VOX_NATIVE_DRAWABLES_TEST_DARWIN_H

static void native_configure_browser_drawable_tree(NSView *view);

// No window or Metal device is needed to verify the native-only resource policy.
@interface VoxNativeDrawableTestView : NSObject
@property(nonatomic, copy) NSArray *children;
@end
@implementation VoxNativeDrawableTestView
- (NSArray *)subviews { return self.children ?: @[]; }
@end

@interface VoxNativeDrawableTestMetalView : VoxNativeDrawableTestView
@property(nonatomic) BOOL paused;
@property(nonatomic) BOOL enableSetNeedsDisplay;
@property(nonatomic) NSUInteger sampleCount;
@property(nonatomic) NSUInteger depthStencilPixelFormat;
@property(nonatomic) NSUInteger releases;
@end
@implementation VoxNativeDrawableTestMetalView
- (void)releaseDrawables { self.releases++; }
@end

static int native_test_unused_metal_drawable_configuration(void) {
	@autoreleasepool {
		VoxNativeDrawableTestView *root = [[VoxNativeDrawableTestView alloc] init];
		VoxNativeDrawableTestMetalView *metal = [[VoxNativeDrawableTestMetalView alloc] init];
		VoxNativeDrawableTestView *cocoa = [[VoxNativeDrawableTestView alloc] init];
		metal.paused = NO;
		metal.enableSetNeedsDisplay = YES;
		metal.sampleCount = 4;
		metal.depthStencilPixelFormat = 260;
		root.children = @[metal];
		metal.children = @[cocoa];
		native_configure_browser_drawable_tree((NSView *)root);
		int result = 0;
		if (metal.paused && !metal.enableSetNeedsDisplay) result |= 1;
		if (metal.sampleCount == 1 && metal.depthStencilPixelFormat == 0) result |= 2;
		if (metal.releases == 1) result |= 4;
		if (root.children.firstObject == metal && metal.children.firstObject == cocoa)
			result |= 8;
		// Reapplying does not remove Cocoa children or create a drawable/device.
		native_configure_browser_drawable_tree((NSView *)root);
		native_configure_browser_drawable_tree(nil);
		if (metal.releases == 2 && metal.paused && metal.sampleCount == 1) result |= 16;
#if !__has_feature(objc_arc)
		[cocoa release];
		[metal release];
		[root release];
#endif
		return result;
	}
}
#endif
