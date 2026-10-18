#pragma once
#include <Cocoa/Cocoa.h>

typedef void (*VoxAddressShortcut)(void *, int);
static id vox_address_key_monitor;

static void native_address_bar_remove_shortcuts(void) {
	if (vox_address_key_monitor != nil) {
		[NSEvent removeMonitor:vox_address_key_monitor];
		vox_address_key_monitor = nil;
	}
}

static NSEvent *native_address_bar_filter_key(NSTextField *field, void *owner,
	VoxAddressShortcut callback, NSEvent *event) {
	NSTextField *control = field;
	if (control == nil || event.window != control.window) return event;
	BOOL editing = control.currentEditor != nil
		&& control.window.firstResponder == control.currentEditor;
	NSEventModifierFlags mods = event.modifierFlags & NSEventModifierFlagDeviceIndependentFlagsMask;
	if (event.keyCode == 2 && (mods & NSEventModifierFlagCommand)
		&& !(mods & (NSEventModifierFlagControl | NSEventModifierFlagOption | NSEventModifierFlagShift))) {
		if (!event.isARepeat) callback(owner, 3); // Cmd+D, including while editing the address.
		return nil;
	}
	if (!(mods & NSEventModifierFlagOption)) {
		if ((mods & NSEventModifierFlagControl) && event.keyCode == 48) {
			callback(owner, (mods & NSEventModifierFlagShift) ? 7 : 6); return nil;
		}
		if ((mods & NSEventModifierFlagCommand) && (mods & NSEventModifierFlagShift)) {
			if (event.keyCode == 33) { callback(owner, 7); return nil; }
			if (event.keyCode == 30) { callback(owner, 6); return nil; }
		}
		if ((mods & NSEventModifierFlagCommand) && !(mods & NSEventModifierFlagShift)) {
			if (event.keyCode == 17) { callback(owner, 4); return nil; }
			if (event.keyCode == 13) { callback(owner, 5); return nil; }
			int numberKeys[] = {18, 19, 20, 21, 23, 22, 26, 28};
			for (int i = 0; i < 8; ++i) {
				if (event.keyCode == numberKeys[i]) { callback(owner, 9+i); return nil; }
			}
			if (event.keyCode == 25) { callback(owner, 8); return nil; }
		}
	}
	BOOL command = (mods & (NSEventModifierFlagCommand | NSEventModifierFlagControl)) != 0;
	if (command && !(mods & (NSEventModifierFlagOption | NSEventModifierFlagShift))) {
		if (event.keyCode == 37) { callback(owner, 0); return nil; } // Cmd+L
		if (event.keyCode == 15) { callback(owner, 1); return nil; } // Cmd+R
	}
	if (editing && event.keyCode == 53) { callback(owner, 2); return nil; }
	// Sokol's default menu has no Edit actions. Route standard shortcuts
	// through the native field editor so selection, clipboard and undo work.
	if (editing && (mods & NSEventModifierFlagCommand)
		&& !(mods & (NSEventModifierFlagControl | NSEventModifierFlagOption))) {
		SEL action = NULL;
		switch (event.keyCode) {
		case 0: action = @selector(selectAll:); break;
		case 6: action = (mods & NSEventModifierFlagShift) ? @selector(redo:) : @selector(undo:); break;
		case 7: action = @selector(cut:); break;
		case 8: action = @selector(copy:); break;
		case 9: action = @selector(paste:); break;
		}
		if (action && [control.currentEditor tryToPerform:action with:nil]) return nil;
	}
	return event;
}

static void native_address_bar_install_shortcuts(void *field_pointer,
	void *owner, VoxAddressShortcut callback) {
	native_address_bar_remove_shortcuts();
	__weak NSTextField *field = (__bridge NSTextField *)field_pointer;
	vox_address_key_monitor = [NSEvent addLocalMonitorForEventsMatchingMask:NSEventMaskKeyDown
		handler:^NSEvent *(NSEvent *event) {
			return native_address_bar_filter_key(field, owner, callback, event);
		}];
}
