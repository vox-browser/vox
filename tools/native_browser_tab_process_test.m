#import <Cocoa/Cocoa.h>
#import <QuartzCore/QuartzCore.h>
#include <unistd.h>
#include <libproc.h>
#include <mach-o/dyld.h>

// Injected into every tab, including children. Drive the actual native tab
// controls and address editor; the test host never edits session state.
static NSView *find_view(NSView *view, NSString *className) {
    if ([view isKindOfClass:NSClassFromString(className)]) return view;
    for (NSView *child in view.subviews) { NSView *found=find_view(child,className); if(found)return found; }
    return nil;
}
static NSView *find_id(NSView *view, NSString *identifier) {
    if ([view.identifier isEqualToString:identifier]) return view;
    for (NSView *child in view.subviews) { NSView *found=find_id(child,identifier); if(found)return found; }
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
        NSView *strip=find_id(window.contentView,@"tab-strip");
        NSTextField *address=find_address(window.contentView);
        NSView *page=find_view(window.contentView,@"MyView2");
        if(!strip || !address || !page)continue;
        NSString *commandPath=[prefix stringByAppendingString:@".command.json"];
        NSDictionary *command=[NSJSONSerialization JSONObjectWithData:[NSData dataWithContentsOfFile:commandPath] ?: [NSData data] options:0 error:nil];
        if(command) {
            [[NSFileManager defaultManager] removeItemAtPath:commandPath error:nil];
            NSString *action=command[@"action"];
            NSInteger index=[command[@"index"] integerValue];
            if([action isEqual:@"new"]) [(NSButton *)find_id(strip,@"tab-new") performClick:nil];
            else if([action isEqual:@"select"]) {
                NSView *tab=find_id(strip,[NSString stringWithFormat:@"tab-%ld",(long)index]);
                // Exercise the same UI2 accessibility action as keyboard/assistive input.
                [tab accessibilityPerformPress];
            }
            else if([action isEqual:@"close"]) [(NSButton *)find_id(strip,[NSString stringWithFormat:@"tab-close:%ld",(long)index]) performClick:nil];
            else if([action isEqual:@"navigate"]) {
                address.stringValue=command[@"url"];
                [NSApp sendAction:address.action to:address.target from:address];
            } else if([action isEqual:@"window-close"]) [window performClose:nil];
            else if([action isEqual:@"reopen"]) {
                // Send the same reopen Apple event as LaunchServices, addressed
                // to this hidden process even if other Vox groups are running.
                NSAppleEventDescriptor *event = [NSAppleEventDescriptor
                    appleEventWithEventClass:kCoreEventClass eventID:kAEReopenApplication
                    targetDescriptor:[NSAppleEventDescriptor descriptorWithProcessIdentifier:getpid()]
                    returnID:kAutoGenerateReturnID transactionID:kAnyTransactionID];
                NSError *error = nil;
                [event sendEventWithOptions:NSAppleEventSendNoReply timeout:1 error:&error];
                if (error) { fprintf(stderr, "reopen Apple event failed: %s\n", error.description.UTF8String); abort(); }
            }
            else if([action isEqual:@"minimize"]) [window miniaturize:nil];
        }
        NSRect frame=window.frame;
        BOOL painted=page.layer.contents != nil;
        char executable[PROC_PIDPATHINFO_MAXSIZE] = {0};
        proc_pidpath(getpid(), executable, sizeof executable);
        const char *firstImage = _dyld_get_image_name(0);
        NSDictionary *report=@{@"pid":@(getpid()), @"visible":@(window.visible && window.alphaValue>0),
            @"active":@(NSApp.active), @"minimized":@(window.miniaturized),
            @"policy":@(NSApp.activationPolicy),
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
