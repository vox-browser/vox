// Copyright (c) 2018-2026, Ladybird contributors
// SPDX-License-Identifier: BSD-2-Clause
// HTMLInputElement.cpp::files/set_files and generated nullable FileList input.
module browserjs

import dom
import fileapi
import html


// The caller supplies the actual strongly typed input implementation. Public
// HTMLInputElement receiver/prototype bindings are a separate prerequisite.
pub fn (mut runtime Runtime) javascript_input_files(input &dom.HTMLInputElement) !voidptr {
	runtime.require_javascript_value_context()!
	mut model := html.HTMLInputElementModel.create(input)
	list := model.file_list() or { return C.vox_jsc_JSValueMakeNull(runtime.context) }
	return runtime.javascript_file_list(list)
}

pub fn (mut runtime Runtime) set_javascript_input_files(input &dom.HTMLInputElement, value voidptr) ! {
	runtime.require_javascript_value_context()!
	// Pinned to_idl_value.py::nullable_to_idl_value maps null/undefined to
	// null; all other values require the actual FileList implementation.
	mut list := ?&fileapi.FileList(none)
	if !C.JSValueIsNull(runtime.context, value) && !C.JSValueIsUndefined(runtime.context, value) {
		list = runtime.native_file_list(value) or {
			return runtime.actual_javascript_exception(runtime.binding_exception_value(err))
		}
	}
	mut model := html.HTMLInputElementModel.create(input)
	model.set_file_list(list)
}
