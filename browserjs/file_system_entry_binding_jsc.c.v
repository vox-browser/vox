// EntriesAPI/FileSystemEntry.{idl,h,cpp}: owner-local native entries.
module browserjs

import entriesapi


@[heap]
struct FileSystemEntryBinding {
mut:
	entries      map[voidptr]&entriesapi.FileSystemEntry
	wrappers     map[voidptr]voidptr
	prototype    voidptr
	wrap         voidptr
	install      voidptr
	constructor  voidptr
}

fn (mut runtime Runtime) install_file_system_entry_identity() ! {
	mut binding := runtime.event_binding()!
	if binding.file_system_entry_binding != unsafe { nil } { return }
	factory := runtime.evaluate_host_value(file_system_entry_identity_factory())!
	defer { runtime.release_javascript_value(factory) }
	// Runtime captures the intrinsic errors at context creation, so a late
	// Window upgrade cannot route illegal construction through author globals.
	identity := runtime.call_javascript_function(factory, C.JSValueMakeUndefined(runtime.context),
		[runtime.value_error_intrinsic_])!
	runtime.retain_javascript_value(identity)!
	defer { runtime.release_javascript_value(identity) }
	binding.file_system_entry_binding = &FileSystemEntryBinding{
		prototype: runtime.retain_javascript_value(runtime.binding_property(identity, 'prototype')!)!
		wrap:      runtime.retain_javascript_value(runtime.binding_property(identity, 'wrap')!)!
		install:   runtime.retain_javascript_value(runtime.binding_property(identity, 'install')!)!
	}
}

fn (mut runtime Runtime) install_file_system_entry_binding() ! {
	runtime.install_file_system_entry_identity()!
	mut binding := runtime.event_binding()!.file_system_entry_binding
	if binding.constructor != unsafe { nil } { return }
	owner := voidptr(&runtime)
	mut call_arguments := [C.JSContextGetGlobalObject(runtime.context)]
	for property in ['isFile', 'isDirectory', 'name'] {
		call_arguments << runtime.make_native_value_host_function('get ' + property, 0,
			fn [owner, property] (receiver voidptr, _ []voidptr) !voidptr {
				mut runtime := unsafe { &Runtime(owner) }
				entry := runtime.native_file_system_entry(receiver)!
				return match property {
					'isFile' { C.JSValueMakeBoolean(runtime.context, entry.is_file()) }
					'isDirectory' { C.JSValueMakeBoolean(runtime.context, entry.is_directory()) }
					else { runtime.binding_utf16_string(entry.name_utf16())! }
				}
			})!
	}
	binding.constructor = runtime.retain_javascript_value(runtime.call_javascript_function(
		binding.install, C.JSValueMakeUndefined(runtime.context), call_arguments)!)!
}

pub fn (mut runtime Runtime) javascript_file_system_entry(entry &entriesapi.FileSystemEntry) !voidptr {
	runtime.require_javascript_value_context()!
	if entry == unsafe { nil } { return runtime.event_binding_type_error('Missing native FileSystemEntry record') }
	runtime.install_file_system_entry_identity()!
	mut binding := runtime.event_binding()!.file_system_entry_binding
	if wrapper := binding.wrappers[voidptr(entry)] { return wrapper }
	wrapper := runtime.retain_javascript_value(runtime.call_javascript_function(binding.wrap,
		C.JSValueMakeUndefined(runtime.context), [])!)!
	binding.entries[wrapper] = entry
	binding.wrappers[voidptr(entry)] = wrapper
	return wrapper
}

pub fn (runtime &Runtime) native_file_system_entry(wrapper voidptr) !&entriesapi.FileSystemEntry {
	// Direct embedding calls after close must not construct errors in a dead
	// engine context. Script calls use the retained intrinsic TypeError.
	if runtime.closed { return error('TypeError: FileSystemEntry binding is closed') }
	runtime.require_javascript_value_context()!
	if binding := event_target_bindings_[voidptr(runtime)] {
		if binding.file_system_entry_binding != unsafe { nil } {
			return binding.file_system_entry_binding.entries[wrapper] or {
				return runtime.event_binding_type_error('Not an object of type FileSystemEntry')
			}
		}
	}
	return runtime.event_binding_type_error('Not an object of type FileSystemEntry')
}
