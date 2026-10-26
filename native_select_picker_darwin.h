#pragma once
#import <Cocoa/Cocoa.h>

@interface VoxSelectPicker : NSMenu
@property(nonatomic) int64_t selectedID;
- (void)selectOption:(NSMenuItem *)sender;
@end

@implementation VoxSelectPicker
- (void)selectOption:(NSMenuItem *)sender {
	if (sender.enabled) self.selectedID = sender.tag;
}
@end

// Own the parsed labels and menu items across AppKit's nested tracking loop.
static int64_t native_browser_select_picker(NSView *view, const unsigned char *bytes,
	int length, double x, double y, double width) {
	if (!view.window || !bytes || length <= 0) return -1;
	@autoreleasepool {
		NSData *data = [NSData dataWithBytes:bytes length:(NSUInteger)length];
		NSArray *items = [NSJSONSerialization JSONObjectWithData:data options:0 error:NULL];
		if (![items isKindOfClass:NSArray.class]) return -1;
		VoxSelectPicker *menu = [[VoxSelectPicker alloc] initWithTitle:@"Select"];
		menu.selectedID = -1;
		menu.autoenablesItems = NO;
		menu.minimumWidth = width;
		for (NSDictionary *entry in items) {
			if ([entry[@"separator"] boolValue]) {
				[menu addItem:NSMenuItem.separatorItem];
				continue;
			}
			BOOL group = [entry[@"group"] boolValue];
			NSMenuItem *item = [[NSMenuItem alloc] initWithTitle:entry[@"label"] ?: @""
				action:group ? NULL : @selector(selectOption:) keyEquivalent:@""];
			item.target = menu;
			item.tag = [entry[@"id"] longLongValue];
			item.enabled = !group && ![entry[@"disabled"] boolValue];
			item.indentationLevel = [entry[@"grouped"] boolValue] ? 1 : 0;
			item.state = [entry[@"selected"] boolValue] ? NSControlStateValueOn : NSControlStateValueOff;
			[menu addItem:item];
#if !__has_feature(objc_arc)
			[item release];
#endif
		}
		NSPoint point = NSMakePoint(x, view.isFlipped ? y : NSMaxY(view.bounds) - y);
		[menu popUpMenuPositioningItem:nil atLocation:point inView:view];
		int64_t selected = menu.selectedID;
#if !__has_feature(objc_arc)
		[menu release];
#endif
		return selected;
	}
}
