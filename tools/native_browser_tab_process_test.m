#import <Cocoa/Cocoa.h>
#import <QuartzCore/QuartzCore.h>
#include <unistd.h>
#include <libproc.h>
#include <mach-o/dyld.h>

// Injected into every tab, including children. Drive the actual native tab
// controls and address editor; the test host never edits session state.
@interface NSView (VoxProcessTabTest)
- (void)newTab:(NSButton *)sender;
- (void)selectTab:(NSButton *)sender;
- (void)closeTab:(NSButton *)sender;
@end
static NSView *find_view(NSView *view, NSString *className) {
    if ([view isKindOfClass:NSClassFromString(className)]) return view;
    for (NSView *child in view.subviews) { NSView *found=find_view(child,className); if(found)return found; }
    return nil;
}
static NSTextField *find_address(NSView *view) {
    if ([view isKindOfClass:NSTextField.class] && [(NSTextField *)view isEditable]) return (NSTextField *)view;
    for(NSView *child in view.subviews){ NSTextField *found=find_address(child); if(found)return found; }
    return nil;
}
static void poll(void) {
    NSString *directory = @(getenv("VOX_TAB_PROBE_DIR"));
    NSString *prefix = [directory stringByAppendingPathComponent:@(getpid()).stringValue];
    for (NSWindow *window in NSApp.windows) {
        NSView *strip=find_view(window.contentView,@"VoxBrowserTabStrip");
        NSTextField *address=find_address(window.contentView);
        NSView *page=find_view(window.contentView,@"MyView2");
        if(!strip || !address || !page)continue;
        NSString *commandPath=[prefix stringByAppendingString:@".command.json"];
        NSDictionary *command=[NSJSONSerialization JSONObjectWithData:[NSData dataWithContentsOfFile:commandPath] ?: [NSData data] options:0 error:nil];
        if(command) {
            [[NSFileManager defaultManager] removeItemAtPath:commandPath error:nil];
            NSString *action=command[@"action"];
            NSButton *button=[NSButton new]; button.tag=[command[@"index"] integerValue];
            if([action isEqual:@"new"]) [strip newTab:button];
            else if([action isEqual:@"select"]) [strip selectTab:button];
            else if([action isEqual:@"close"]) [strip closeTab:button];
            else if([action isEqual:@"navigate"]) {
                address.stringValue=command[@"url"];
                [NSApp sendAction:address.action to:address.target from:address];
            } else if([action isEqual:@"window-close"]) [window performClose:nil];
        }
        NSRect frame=window.frame;
        BOOL painted=page.layer.contents != nil;
        char executable[PROC_PIDPATHINFO_MAXSIZE] = {0};
        proc_pidpath(getpid(), executable, sizeof executable);
        const char *firstImage = _dyld_get_image_name(0);
        NSDictionary *report=@{@"pid":@(getpid()), @"visible":@(window.visible && window.alphaValue>0),
            @"title":window.title ?: @"", @"address":address.stringValue ?: @"", @"painted":@(painted),
            @"executable":@(executable), @"first_image":firstImage ? @(firstImage) : @"",
            @"frame":@[@(frame.origin.x),@(frame.origin.y),@(frame.size.width),@(frame.size.height)]};
        NSData *data=[NSJSONSerialization dataWithJSONObject:report options:0 error:nil];
        [data writeToFile:[prefix stringByAppendingString:@".json"] atomically:YES];
        break;
    }
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW,50*NSEC_PER_MSEC),dispatch_get_main_queue(),^{poll();});
}
__attribute__((constructor)) static void install(void) {
    if(!getenv("VOX_TAB_PROBE_DIR"))return;
    dispatch_async(dispatch_get_main_queue(),^{poll();});
}
