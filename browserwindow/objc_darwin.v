module browserwindow

import macos

#flag darwin -framework Cocoa
#include <CoreFoundation/CoreFoundation.h>
#include <objc/runtime.h>
#include <objc/message.h>
#include <dlfcn.h>

// The generated C is compiled as Objective-C with ARC (sokol requires it).
// Runtime functions whose prototypes use Class or id are therefore called
// through function pointers with C parameter types, as objc_msgSend is.
fn C.objc_msgSend()
fn C.objc_lookUpClass()
fn C.class_getInstanceMethod()
fn C.class_getSuperclass()
fn C.class_getMethodImplementation()
fn C.class_addMethod()
fn C.class_replaceMethod()
fn C.method_getImplementation()
fn C.method_setImplementation()
fn C.method_getTypeEncoding()
fn C.objc_storeWeak()
fn C.objc_loadWeak()
fn C.dispatch_async_f(queue voidptr, context voidptr, work voidptr)
fn C.dlsym(handle voidptr, name &char) voidptr
fn C.CFRunLoopRunInMode(mode voidptr, seconds f64, return_after_source_handled bool) i32

type LookUpClassFn = fn (name &char) voidptr

type ClassSelectorFn = fn (cls voidptr, name voidptr) voidptr

type ClassFn = fn (cls voidptr) voidptr

type AddMethodFn = fn (cls voidptr, name voidptr, imp voidptr, types &char) bool

type ReplaceMethodFn = fn (cls voidptr, name voidptr, imp voidptr, types &char) voidptr

type MethodFn = fn (method voidptr) voidptr

type SetImplementationFn = fn (method voidptr, imp voidptr) voidptr

type TypeEncodingFn = fn (method voidptr) &char

type StoreWeakFn = fn (location &voidptr, obj voidptr) voidptr

type LoadWeakFn = fn (location &voidptr) voidptr

type DispatchAsyncFn = fn (queue voidptr, context voidptr, work fn (voidptr))

fn lookup_class(name string) voidptr {
	f := unsafe { LookUpClassFn(voidptr(C.objc_lookUpClass)) }
	return f(&char(name.str))
}

fn class_instance_method(cls voidptr, name macos.Sel) voidptr {
	f := unsafe { ClassSelectorFn(voidptr(C.class_getInstanceMethod)) }
	return f(cls, name)
}

fn class_method_implementation(cls voidptr, name macos.Sel) voidptr {
	f := unsafe { ClassSelectorFn(voidptr(C.class_getMethodImplementation)) }
	return f(cls, name)
}

fn class_superclass(cls voidptr) voidptr {
	f := unsafe { ClassFn(voidptr(C.class_getSuperclass)) }
	return f(cls)
}

fn class_add_method(cls voidptr, name macos.Sel, imp voidptr, types &char) bool {
	f := unsafe { AddMethodFn(voidptr(C.class_addMethod)) }
	return f(cls, name, imp, types)
}

fn class_replace_method(cls voidptr, name macos.Sel, imp voidptr, types &char) voidptr {
	f := unsafe { ReplaceMethodFn(voidptr(C.class_replaceMethod)) }
	return f(cls, name, imp, types)
}

fn method_implementation(method voidptr) voidptr {
	f := unsafe { MethodFn(voidptr(C.method_getImplementation)) }
	return f(method)
}

fn method_set_implementation(method voidptr, imp voidptr) voidptr {
	f := unsafe { SetImplementationFn(voidptr(C.method_setImplementation)) }
	return f(method, imp)
}

fn method_type_encoding(method voidptr) &char {
	f := unsafe { TypeEncodingFn(voidptr(C.method_getTypeEncoding)) }
	return f(method)
}

// store_weak and load_weak manage a zeroing weak reference in `slot`, which
// must stay at a fixed address until it is cleared with store_weak(nil).
fn store_weak(slot &voidptr, obj voidptr) {
	f := unsafe { StoreWeakFn(voidptr(C.objc_storeWeak)) }
	f(slot, obj)
}

// load_weak returns the referenced object (autoreleased), or nil.
fn load_weak(slot &voidptr) macos.Id {
	f := unsafe { LoadWeakFn(voidptr(C.objc_loadWeak)) }
	return macos.Id(f(slot))
}

// dispatch_to_main_queue runs `work` on the next turn of the main queue.
fn dispatch_to_main_queue(work fn (voidptr)) {
	f := unsafe { DispatchAsyncFn(voidptr(C.dispatch_async_f)) }
	f(C.dlsym(rtld_default(), c'_dispatch_main_q'), unsafe { nil }, work)
}

// AppKit and Foundation values used by this module.
const ns_window_style_titled = u64(1)
const ns_window_style_closable = u64(1) << 1
const ns_window_style_miniaturizable = u64(1) << 2
const ns_window_style_resizable = u64(1) << 3
const ns_window_style_fullscreen = u64(1) << 14
const ns_window_style_full_size_content_view = u64(1) << 15
const ns_window_collection_fullscreen_primary = u64(1) << 7
const ns_window_title_hidden = i64(1)
const ns_titlebar_separator_none = i64(1)
const ns_not_found = u64(0x7fffffffffffffff)
const ns_event_mask_any = ~u64(0)

fn rtld_default() voidptr {
	return unsafe { voidptr(i64(-2)) }
}

// Message signatures that the macos module has no typed sender for.
type MsgVoidRectBool = fn (macos.Id, macos.Sel, macos.Rect, bool)

type MsgIdU64IdIdBool = fn (macos.Id, macos.Sel, u64, macos.Id, macos.Id, bool) macos.Id

type MsgVoidU64F64F64Id = fn (macos.Id, macos.Sel, u64, f64, f64, macos.Id)

type MsgIdPtrU64 = fn (macos.Id, macos.Sel, voidptr, u64) macos.Id

type MsgIdIdU64Ptr = fn (macos.Id, macos.Sel, macos.Id, u64, voidptr) macos.Id

type MsgIdBool = fn (macos.Id, macos.Sel, bool) macos.Id

@[inline]
fn objc_msg_send() voidptr {
	return voidptr(C.objc_msgSend)
}

fn msg_void_rect_bool(obj macos.Id, selector string, rect macos.Rect, value bool) {
	send := unsafe { MsgVoidRectBool(objc_msg_send()) }
	send(obj, macos.sel(selector), rect, value)
}

fn msg_id_u64_id_id_bool(obj macos.Id, selector string, a0 u64, a1 macos.Id, a2 macos.Id, a3 bool) macos.Id {
	send := unsafe { MsgIdU64IdIdBool(objc_msg_send()) }
	return send(obj, macos.sel(selector), a0, a1, a2, a3)
}

fn msg_void_u64_f64_f64_id(obj macos.Id, selector string, a0 u64, a1 f64, a2 f64, a3 macos.Id) {
	send := unsafe { MsgVoidU64F64F64Id(objc_msg_send()) }
	send(obj, macos.sel(selector), a0, a1, a2, a3)
}

fn msg_id_ptr_u64(obj macos.Id, selector string, a0 voidptr, a1 u64) macos.Id {
	send := unsafe { MsgIdPtrU64(objc_msg_send()) }
	return send(obj, macos.sel(selector), a0, a1)
}

fn msg_id_id_u64_ptr(obj macos.Id, selector string, a0 macos.Id, a1 u64, a2 voidptr) macos.Id {
	send := unsafe { MsgIdIdU64Ptr(objc_msg_send()) }
	return send(obj, macos.sel(selector), a0, a1, a2)
}

fn msg_id_bool(obj macos.Id, selector string, a0 bool) macos.Id {
	send := unsafe { MsgIdBool(objc_msg_send()) }
	return send(obj, macos.sel(selector), a0)
}

@[inline]
fn is_nil(obj voidptr) bool {
	return obj == unsafe { nil }
}

@[inline]
fn nil_id() macos.Id {
	return macos.Id(unsafe { nil })
}

// ns_app reads AppKit's NSApp global. Unlike +sharedApplication it does not
// create an application object when none exists yet.
fn ns_app() macos.Id {
	slot := C.dlsym(rtld_default(), c'NSApp')
	if is_nil(slot) {
		return nil_id()
	}
	return unsafe { *&macos.Id(slot) }
}

// framework_string reads an exported NSString constant such as a
// notification name, falling back to its documented value.
fn framework_string(name string) macos.Id {
	slot := C.dlsym(rtld_default(), &char(name.str))
	if !is_nil(slot) {
		value := unsafe { *&macos.Id(slot) }
		if !is_nil(value) {
			return value
		}
	}
	return macos.nsstring(name)
}

fn key_or_main_window() macos.Id {
	app := ns_app()
	window := macos.msg_id(app, 'keyWindow')
	return if is_nil(window) { macos.msg_id(app, 'mainWindow') } else { window }
}

fn frame_of(rect macos.Rect) Frame {
	return Frame{
		x:      rect.x
		y:      rect.y
		width:  rect.width
		height: rect.height
	}
}

fn rect_of(frame Frame) macos.Rect {
	return macos.rect(frame.x, frame.y, frame.width, frame.height)
}

struct RuntimeMethod {
	selector       string
	implementation voidptr
	types          string
}

// runtime_class returns the named NSObject subclass, registering it with the
// given instance methods the first time.
fn runtime_class(name string, methods []RuntimeMethod) macos.Id {
	existing := lookup_class(name)
	if !is_nil(existing) {
		return macos.Id(existing)
	}
	cls := macos.allocate_class_pair(macos.get_class('NSObject'), name)
	for method in methods {
		macos.add_method(cls, method.selector, method.implementation, method.types)
	}
	macos.register_class_pair(cls)
	return cls
}

// A block literal following the Apple block ABI. Blocks built here are marked
// global, so AppKit's Block_copy and Block_release leave them in place; their
// owner keeps the V allocation alive for as long as AppKit may call them.
const block_is_global = u32(1) << 28
const block_has_signature = u32(1) << 30

struct BlockDescriptor {
	reserved  u64
	size      u64
	signature &char
}

fn global_block_isa() voidptr {
	return C.dlsym(rtld_default(), c'_NSConcreteGlobalBlock')
}

fn global_block_flags() i32 {
	return i32(block_is_global | block_has_signature)
}
