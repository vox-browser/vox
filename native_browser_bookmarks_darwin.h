#pragma once
#include <Cocoa/Cocoa.h>

typedef void (*VoxBookmarkAction)(void *, int, int);

@interface VoxBookmarkBar : NSView
@property void *owner;
@property VoxBookmarkAction callback;
@property(strong) NSMenu *overflow;
@property CGFloat nextX;
@property(strong) NSMutableDictionary<NSNumber *, NSData *> *iconBytes;
- (void)openBookmark:(id)sender;
- (void)removeBookmark:(id)sender;
- (void)showOverflow:(NSButton *)sender;
@end

@implementation VoxBookmarkBar
- (BOOL)isFlipped { return YES; }
- (void)drawRect:(NSRect)dirty {
	[[NSColor colorWithWhite:.97 alpha:1] setFill]; NSRectFill(self.bounds);
	[[NSColor colorWithWhite:.84 alpha:1] setFill];
	NSRectFill(NSMakeRect(0, self.bounds.size.height - 1, self.bounds.size.width, 1));
}
- (void)openBookmark:(id)sender { self.callback(self.owner, 0, (int)[sender tag]); }
- (void)removeBookmark:(id)sender { self.callback(self.owner, 1, (int)[sender tag]); }
- (void)showOverflow:(NSButton *)sender {
	[self.overflow popUpMenuPositioningItem:nil atLocation:NSMakePoint(0, sender.bounds.size.height) inView:sender];
}
@end

@interface VoxBookmarkButton : NSButton
@property(nonatomic) BOOL hovered;
@end

@implementation VoxBookmarkButton
- (void)updateTrackingAreas {
	[super updateTrackingAreas];
	for (NSTrackingArea *area in self.trackingAreas) [self removeTrackingArea:area];
	[self addTrackingArea:[[NSTrackingArea alloc] initWithRect:self.bounds
		options:NSTrackingMouseEnteredAndExited | NSTrackingActiveInKeyWindow | NSTrackingInVisibleRect
		owner:self userInfo:nil]];
}
- (void)setHovered:(BOOL)hovered { _hovered = hovered; [self setNeedsDisplay:YES]; }
- (void)mouseEntered:(NSEvent *)event { self.hovered = YES; }
- (void)mouseExited:(NSEvent *)event { self.hovered = NO; }
- (void)drawRect:(NSRect)dirty {
	if (self.hovered) {
		NSColor *fill = self.isHighlighted ? [NSColor colorWithWhite:0 alpha:.12] : [NSColor colorWithWhite:0 alpha:.07];
		[fill setFill];
		[[NSBezierPath bezierPathWithRoundedRect:NSInsetRect(self.bounds, .5, .5) xRadius:8 yRadius:8] fill];
	}
	[super drawRect:dirty];
}
@end

static VoxBookmarkBar *vox_bookmark_bar;
static uint64_t vox_bookmark_version;
static NSString *vox_bookmark_error;

static NSImage *native_bookmark_default_icon(void) {
	static NSImage *image;
	if (!image) {
		image = [[NSImage imageWithSystemSymbolName:@"globe" accessibilityDescription:nil] copy];
		image.size = NSMakeSize(16, 16);
	}
	return image;
}

static void native_browser_bookmarks_remove(void) {
	[vox_bookmark_bar removeFromSuperview];
	vox_bookmark_bar = nil;
	vox_bookmark_error = nil;
}

// Return whether the caller needs to replay the entries. Hover/status changes
// leave the native buttons and their keyboard focus intact.
static int native_browser_bookmarks_begin(void *toolbar, void *owner, VoxBookmarkAction callback,
	int visible, double top, double width, uint64_t version, const unsigned char *error, int error_length) {
	if (!visible) { native_browser_bookmarks_remove(); return 0; }
	NSView *parent = (__bridge NSView *)toolbar;
	NSString *message = [[NSString alloc] initWithBytes:error length:error_length encoding:NSUTF8StringEncoding] ?: @"";
	NSRect frame = NSMakeRect(0, top, MAX(0, width), 28);
	if (vox_bookmark_bar.superview == parent && vox_bookmark_bar != nil
		&& vox_bookmark_version == version && NSEqualRects(vox_bookmark_bar.frame, frame)
		&& [vox_bookmark_error isEqualToString:message]) {
		vox_bookmark_bar.owner = owner;
		return 0;
	}
	native_browser_bookmarks_remove();
	vox_bookmark_bar = [[VoxBookmarkBar alloc] initWithFrame:frame];
	vox_bookmark_bar.owner = owner; vox_bookmark_bar.callback = callback;
	vox_bookmark_bar.accessibilityLabel = @"Bookmarks bar";
	vox_bookmark_bar.nextX = 8;
	vox_bookmark_bar.iconBytes = [NSMutableDictionary dictionary];
	vox_bookmark_bar.overflow = [[NSMenu alloc] initWithTitle:@"More bookmarks"];
	vox_bookmark_bar.overflow.autoenablesItems = NO;
	vox_bookmark_version = version; vox_bookmark_error = message;
	[parent addSubview:vox_bookmark_bar];
	return 1;
}

static void native_browser_bookmarks_item(int index, const unsigned char *title_bytes, int title_length,
	const unsigned char *url_bytes, int url_length) {
	VoxBookmarkBar *bar = vox_bookmark_bar;
	if (vox_bookmark_error.length > 0) return;
	NSString *title = [[NSString alloc] initWithBytes:title_bytes length:title_length encoding:NSUTF8StringEncoding] ?: @"";
	NSString *url = [[NSString alloc] initWithBytes:url_bytes length:url_length encoding:NSUTF8StringEncoding] ?: @"";
	NSFont *font = [NSFont systemFontOfSize:12];
	CGFloat width = MIN(180, MAX(66, ceil([title sizeWithAttributes:@{NSFontAttributeName:font}].width) + 40));
	NSMenuItem *remove = [[NSMenuItem alloc] initWithTitle:@"Remove bookmark" action:@selector(removeBookmark:) keyEquivalent:@""];
	remove.target = bar; remove.tag = index;
	NSMenu *context = [[NSMenu alloc] initWithTitle:title]; context.autoenablesItems = NO;
	[context addItem:remove];
	if (bar.overflow.numberOfItems == 0 && bar.nextX + width <= bar.bounds.size.width - 34) {
		NSButton *button = [[VoxBookmarkButton alloc] initWithFrame:NSMakeRect(bar.nextX, 2, width, 23)];
		button.title = title; button.font = font; button.bordered = NO;
		button.image = native_bookmark_default_icon();
		button.imagePosition = NSImageLeft;
		button.imageScaling = NSImageScaleProportionallyDown;
		button.imageHugsTitle = YES;
		button.alignment = NSTextAlignmentLeft;
		button.lineBreakMode = NSLineBreakByTruncatingTail;
		button.target = bar; button.action = @selector(openBookmark:); button.tag = index;
		button.toolTip = [NSString stringWithFormat:@"%@\n%@", title, url];
		button.accessibilityLabel = title; button.menu = context;
		[bar addSubview:button]; bar.nextX += width + 4;
	} else {
		NSMenuItem *item = [[NSMenuItem alloc] initWithTitle:title action:@selector(openBookmark:) keyEquivalent:@""];
		item.target = bar; item.tag = index; item.toolTip = url;
		item.image = native_bookmark_default_icon();
		// A submenu keeps removal available for entries beyond the visible row.
		NSMenu *submenu = [[NSMenu alloc] initWithTitle:title]; submenu.autoenablesItems = NO;
		NSMenuItem *open = [[NSMenuItem alloc] initWithTitle:@"Open bookmark" action:@selector(openBookmark:) keyEquivalent:@""];
		open.target = bar; open.tag = index;
		open.image = item.image;
		[submenu addItem:open]; [submenu addItem:[NSMenuItem separatorItem]];
		[context removeItem:remove]; [submenu addItem:remove]; item.submenu = submenu;
		[bar.overflow addItem:item];
	}
}

// Update only an icon when an asynchronous response completes. Keep buttons,
// focus, menus and callback indices stable across ordinary chrome refreshes.
static void native_browser_bookmark_icon(int index, const unsigned char *bytes, int length) {
	VoxBookmarkBar *bar = vox_bookmark_bar;
	if (!bar) return;
	NSNumber *key = @(index);
	NSData *encoded = bytes && length > 0 ? [NSData dataWithBytes:bytes length:length] : nil;
	NSData *previous = bar.iconBytes[key];
	if ((!encoded && !previous) || [encoded isEqualToData:previous]) return;
	NSImage *image = encoded ? [[NSImage alloc] initWithData:encoded] : nil;
	if (image) image.size = NSMakeSize(16, 16);
	else image = native_bookmark_default_icon();
	if (encoded) bar.iconBytes[key] = encoded;
	else [bar.iconBytes removeObjectForKey:key];
	for (NSView *view in bar.subviews) {
		if ([view isKindOfClass:NSButton.class] && ((NSButton *)view).tag == index
			&& ((NSButton *)view).action == @selector(openBookmark:)) ((NSButton *)view).image = image;
	}
	for (NSMenuItem *item in bar.overflow.itemArray) {
		if (item.tag != index) continue;
		item.image = image;
		for (NSMenuItem *action in item.submenu.itemArray)
			if (action.action == @selector(openBookmark:)) action.image = image;
	}
}

static void native_browser_bookmarks_end(int count) {
	VoxBookmarkBar *bar = vox_bookmark_bar;
	if (count == 0 || vox_bookmark_error.length > 0) {
		NSTextField *hint = [NSTextField labelWithString:vox_bookmark_error.length > 0
			? vox_bookmark_error : @"Save your favorite pages here with ⌘D"];
		hint.font = [NSFont systemFontOfSize:12]; hint.textColor = NSColor.secondaryLabelColor;
		hint.frame = NSMakeRect(12, 5, MAX(0, bar.bounds.size.width - 24), 18);
		hint.lineBreakMode = NSLineBreakByTruncatingTail;
		[bar addSubview:hint];
	}
	if (bar.overflow.numberOfItems > 0) {
		NSButton *more = [[VoxBookmarkButton alloc] initWithFrame:NSMakeRect(MAX(0, bar.bounds.size.width - 30), 2, 24, 23)];
		more.title = @"»"; more.bordered = NO; more.font = [NSFont systemFontOfSize:15];
		more.target = bar; more.action = @selector(showOverflow:);
		more.accessibilityLabel = @"More bookmarks"; more.toolTip = @"More bookmarks";
		[bar addSubview:more];
	}
}
