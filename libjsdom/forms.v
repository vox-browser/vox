// SPDX-License-Identifier: BSD-2-Clause
module libjsdom

import dom
import html
import libjs
import platform

// The document embedding owns navigation and target selection. Standalone
// users can retain the native model's own hook or install this traced service.
pub interface FormSubmissionHost {
	submit_form(&dom.Element, string, html.FormSubmission) !
}

pub fn (mut host Host) set_form_submission_host(service FormSubmissionHost) {
	if !host.closed { host.form_submission_host = service }
}

fn (host &Host) submit_native_form(mut model html.HTMLFormElementModel, element &dom.Element, submitter ?&html.FormAssociatedElement, direct bool) ! {
	mut owned_hook := ?html.FormSubmissionHook(none)
	if service := host.form_submission_host {
		if !model.has_submission_hook() {
			callback := fn [service, element, submitter] (submission html.FormSubmission) ! {
				// Submit and formdata handlers can change the target before the
				// native algorithm hands off its completed submission.
				target := if control := submitter { control.element.get_attribute('formtarget') or { element.get_attribute_value('target') } } else { element.get_attribute_value('target') }
				service.submit_form(element, target, submission)!
			}
			model.set_submission_hook(callback); owned_hook = callback
		}
	}
	defer {
		if callback := owned_hook { model.set_submission_hook(none); platform.release_closure(voidptr(callback)) }
	}
	if direct { model.submit()! } else { model.request_submit(submitter)! }
}

fn native_form_control(element &dom.Element) &html.FormAssociatedElement {
	return match element.local_name() {
		'input' { html.HTMLInputElementModel.create(unsafe { &dom.HTMLInputElement(element) }).control }
		'button' { html.HTMLButtonElementModel.create(unsafe { &dom.HTMLButtonElement(element) }).control }
		'textarea' { html.HTMLTextAreaElementModel.create(unsafe { &dom.HTMLTextAreaElement(element) }).control }
		'select' { prepare_libjs_select(element).control }
		else { html.FormAssociatedElement.create(element) }
	}
}

fn native_form_encoding(kind html.FormEncodingType) string {
	return match kind { .multipart { 'multipart/form-data' } .plain_text { 'text/plain' } else { 'application/x-www-form-urlencoded' } }
}

fn form_enum_value(value string, allowed []string, fallback string) string {
	// HTML enumerated keywords compare ASCII case-insensitively.
	mut bytes := value.bytes()
	for mut byte in bytes { if byte >= `A` && byte <= `Z` { byte += 32 } }
	normalized := bytes.bytestr()
	return if normalized in allowed { normalized } else { fallback }
}

fn (mut host Host) install_forms() ! {
	mut prototype := host.html_element_prototypes['HTMLFormElement'] or { return error('Missing form prototype') }
	host.install_control_reflection(mut prototype, 'form', {'acceptCharset':'accept-charset', 'name':'name', 'target':'target', 'rel':'rel'}, {'noValidate':'novalidate'})
	for name in ['action', 'method', 'enctype', 'encoding', 'autocomplete'] {
		host.accessor(mut prototype, name, fn [host, name] (mut vm libjs.VM) !libjs.Value {
			element := host.form_control_receiver(mut vm, 'form')!
			persistent := platform.enter_persistent(); defer { platform.leave_persistent(persistent) }
			model := html.HTMLFormElementModel.create(unsafe { &dom.HTMLFormElement(element) })
			text := match name {
				'action' { model.action() }
				'method' { model.method_state(none).str() }
				'enctype', 'encoding' { native_form_encoding(model.encoding_type(none)) }
				else { form_enum_value(element.get_attribute_value('autocomplete'), ['on', 'off'], 'on') }
			}
			return libjs.Value.from_string(vm.create_string_from_str(text))
		}, fn [host, name] (mut vm libjs.VM) !libjs.Value {
			mut element := unsafe { &dom.Element(host.form_control_receiver(mut vm, 'form')!) }
			persistent := platform.enter_persistent(); defer { platform.leave_persistent(persistent) }
			text := if name == 'action' { query_usv(mut vm, vm.argument(0))! } else { vm.argument(0).to_primitive_string(mut vm)!.str() }
			if name == 'action' {
				mut model := html.HTMLFormElementModel.create(unsafe { &dom.HTMLFormElement(element) })
				model.set_action(text)
			} else { element.set_attribute_value(if name == 'encoding' { 'enctype' } else { name }, text) }
			mut owner := unsafe { &Host(host) }; owner.finish_form_mutation()
			return libjs.js_undefined()
		})
	}
	host.accessor(mut prototype, 'length', fn [host] (mut vm libjs.VM) !libjs.Value {
		element := host.form_control_receiver(mut vm, 'form')!
		persistent := platform.enter_persistent(); defer { platform.leave_persistent(persistent) }
		mut model := html.HTMLFormElementModel.create(unsafe { &dom.HTMLFormElement(element) })
		return libjs.Value.from_f64(f64(model.elements().length()))
	}, unsafe { nil })
	host.accessor(mut prototype, 'relList', fn [host] (mut vm libjs.VM) !libjs.Value {
		element := host.form_control_receiver(mut vm, 'form')!
		persistent := platform.enter_persistent(); defer { platform.leave_persistent(persistent) }
		mut model := html.HTMLFormElementModel.create(unsafe { &dom.HTMLFormElement(element) })
		mut owner := unsafe { &Host(host) }; return owner.wrap_token_list(model.rel_list())
	}, fn [host] (mut vm libjs.VM) !libjs.Value {
		_ := host.form_control_receiver(mut vm, 'form')!
		persistent := platform.enter_persistent(); defer { platform.leave_persistent(persistent) }
		// PutForwards performs ordinary property access, including an author
		// replacement of relList or its value setter, before DOMString coercion.
		forward := vm.this_value().as_object().get(mut vm, libjs.PropertyName.from_str('relList'))!
		if !forward.is_object() { return vm.throw_error(.type_error, 'Form relList must be an object') }
		mut target := forward.as_object()
		target.set(mut vm, libjs.PropertyName.from_str('value'), vm.argument(0), .yes)!
		mut owner := unsafe { &Host(host) }; owner.finish_form_mutation()
		return libjs.js_undefined()
	})
	for name in ['submit', 'requestSubmit', 'reset', 'checkValidity', 'reportValidity'] {
		host.method_attributes(mut prototype, name, 0, fn [host, name] (mut vm libjs.VM) !libjs.Value {
			element := host.form_control_receiver(mut vm, 'form')!
			persistent := platform.enter_persistent(); defer { platform.leave_persistent(persistent) }
			mut owner := unsafe { &Host(host) }
			mut model := html.HTMLFormElementModel.create(unsafe { &dom.HTMLFormElement(element) })
			if name == 'checkValidity' { return libjs.Value.from_bool(model.check_validity()) }
			if name == 'reportValidity' {
				valid := model.report_validity(); owner.changed()
				return libjs.Value.from_bool(valid)
			}
			if name == 'requestSubmit' {
				mut submitter := ?&html.FormAssociatedElement(none)
				if !vm.argument(0).is_nullish() {
					button := host.form_data_element(mut vm, vm.argument(0), false)!
					if button.local_name() !in ['input', 'button'] { return vm.throw_error(.type_error, 'The submitter is not a submit button') }
					submitter = native_form_control(button)
				}
				host.submit_native_form(mut model, element, submitter, false) or { return owner.dom_error(mut vm, err) }
			} else if name == 'reset' {
				_ := model.get_submittable_elements()
				model.reset()
			} else { host.submit_native_form(mut model, element, none, true) or { return owner.dom_error(mut vm, err) } }
			owner.finish_form_mutation(); return libjs.js_undefined()
		}, libjs.attribute_writable | libjs.attribute_enumerable | libjs.attribute_configurable)
	}
	for tag, interface_name in {'input':'HTMLInputElement', 'button':'HTMLButtonElement'} {
		mut target := host.html_element_prototypes[interface_name] or { return error('Missing submitter prototype') }
		host.install_control_reflection(mut target, tag, {'formTarget':'formtarget'}, {'formNoValidate':'formnovalidate'})
		for name in ['formAction', 'formMethod', 'formEnctype'] {
			host.accessor(mut target, name, fn [host, tag, name] (mut vm libjs.VM) !libjs.Value {
				element := host.form_control_receiver(mut vm, tag)!
				persistent := platform.enter_persistent(); defer { platform.leave_persistent(persistent) }
				text := if name == 'formAction' { native_form_control(element).form_action() }
					else if !element.has_attribute(if name == 'formMethod' { 'formmethod' } else { 'formenctype' }) { '' }
					else if name == 'formMethod' { form_enum_value(element.get_attribute_value('formmethod'), ['get','post','dialog'], 'get') }
					else { form_enum_value(element.get_attribute_value('formenctype'), ['application/x-www-form-urlencoded','multipart/form-data','text/plain'], 'application/x-www-form-urlencoded') }
				return libjs.Value.from_string(vm.create_string_from_str(text))
			}, fn [host, tag, name] (mut vm libjs.VM) !libjs.Value {
				mut element := unsafe { &dom.Element(host.form_control_receiver(mut vm, tag)!) }
				persistent := platform.enter_persistent(); defer { platform.leave_persistent(persistent) }
				text := if name == 'formAction' { query_usv(mut vm, vm.argument(0))! } else { vm.argument(0).to_primitive_string(mut vm)!.str() }
				element.set_attribute_value(match name { 'formAction' { 'formaction' } 'formMethod' { 'formmethod' } else { 'formenctype' } }, text)
				mut owner := unsafe { &Host(host) }; owner.finish_form_mutation()
				return libjs.js_undefined()
			})
		}
	}
	host.install_submit_events()!
}
