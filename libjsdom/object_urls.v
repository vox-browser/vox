// SPDX-License-Identifier: BSD-2-Clause
module libjsdom

import domurl
import fileapi
import html
import libjs
import platform

fn (mut host Host) install_object_urls(mut constructor libjs.Object) {
	attributes := libjs.attribute_writable | libjs.attribute_enumerable | libjs.attribute_configurable
	host.method_attributes(mut constructor, 'createObjectURL', 1, fn [host] (mut vm libjs.VM) !libjs.Value {
		host.require_open(mut vm)!
		if vm.argument_count() < 1 || !vm.argument(0).is_object() { return vm.throw_error(.type_error, 'URL.createObjectURL requires a Blob') }
		blob := host.blobs[voidptr(vm.argument(0).as_object())] or { return vm.throw_error(.type_error, 'URL.createObjectURL requires a Blob') }
		persistent := platform.enter_persistent()
		defer { platform.leave_persistent(persistent) }
		mut owner := unsafe { &Host(host) }
		owner.frame_window(mut vm)!
		// The actual settings record owns the store entry. Its lifetime and
		// partition checks are independent of a JS wrapper or this host map.
		settings := unsafe { &html.EnvironmentSettingsObject(host.document.relevant_settings_object()) }
		value := domurl.DOMURL.create_object_url(fileapi.BlobURLObject.from_blob(blob), settings) or { return vm.throw_error(.internal_error, err.msg()) }
		return libjs.Value.from_string(vm.create_string_from_str(value))
	}, attributes)
	host.method_attributes(mut constructor, 'revokeObjectURL', 1, fn [host] (mut vm libjs.VM) !libjs.Value {
		host.require_open(mut vm)!
		if vm.argument_count() < 1 { return vm.throw_error(.type_error, 'URL.revokeObjectURL requires an argument') }
		value := vm.argument(0).to_primitive_string(mut vm)!.str()
		persistent := platform.enter_persistent()
		defer { platform.leave_persistent(persistent) }
		mut owner := unsafe { &Host(host) }
		owner.frame_window(mut vm)!
		settings := unsafe { &html.EnvironmentSettingsObject(host.document.relevant_settings_object()) }
		domurl.DOMURL.revoke_object_url(value, settings)
		return libjs.js_undefined()
	}, attributes)
}
