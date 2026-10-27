// Copyright (c) 2018-2026, Ladybird contributors
//
// SPDX-License-Identifier: BSD-2-Clause

// Literal translation of Libraries/LibWeb/HTML/HTMLFormElement.cpp. Native GET
// navigation uses the owning navigable; entity bodies and auxiliary targets
// remain exposed through the typed submission hook.
module html

import dom
import encoding

pub struct SubmitFormOptions {
pub:
	from_submit_binding bool
	user_involvement    UserNavigationInvolvement = .none_
}

pub struct StaticFormValidationResult {
pub:
	result                     bool
	unhandled_invalid_controls []&FormAssociatedElement
}

fn html_form_element_is_listed(element &dom.Element) bool {
	return element.local_name() in ['button', 'fieldset', 'input', 'object', 'output', 'select',
		'textarea']
}

fn html_form_element_is_associated(form &HTMLFormElementModel, element &dom.Element) bool {
	for associated in form.element.associated_elements_ {
		if voidptr(associated) == voidptr(element) {
			return true
		}
	}
	return false
}

fn html_form_element_is_form_control(form &HTMLFormElementModel, element &dom.Element) bool {
	if !html_form_element_is_listed(element) || !html_form_element_is_associated(form, element) {
		return false
	}
	return !(element.local_name() == 'input' && form_element_input_type(element) == 'image')
}

fn html_form_element_root(form &HTMLFormElementModel) &dom.Node {
	return form_model_element(form).as_node().root()
}

// HTMLFormElement::implicitly_submit_form().
pub fn (mut form HTMLFormElementModel) implicitly_submit_form() ! {
	if default_button := form.default_button() {
		if default_button.enabled() {
			click := dom.Event.create('click', dom.EventInit{ bubbles: true, cancelable: true })
			if unsafe { &dom.EventTarget(default_button.element.as_node()) }.dispatch_event(click) {
				form.submit_form(default_button, SubmitFormOptions{
					user_involvement: .activation
				})!
			}
		}
		return
	}
	if form.number_of_fields_blocking_implicit_submission() > 1 {
		return
	}
	form.submit_form(none, SubmitFormOptions{
		user_involvement: .activation
	})!
}

// HTMLFormElement::submit(), the legacy binding which bypasses submit events
// and constraint validation.
pub fn (mut form HTMLFormElementModel) submit() ! {
	form.submit_form(none, SubmitFormOptions{
		from_submit_binding: true
	})!
}

// HTMLFormElement::request_submit().
pub fn (mut form HTMLFormElementModel) request_submit(submitter ?&FormAssociatedElement) ! {
	if control := submitter {
		if !control.is_submit_button() {
			return error('TypeError: the submitter is not a submit button')
		}
		owner := control.form() or {
			return error('NotFoundError: the submitter is not owned by this form element')
		}
		if voidptr(owner) != voidptr(form.element) {
			return error('NotFoundError: the submitter is not owned by this form element')
		}
	}
	form.submit_form(submitter, SubmitFormOptions{})!
}

// HTMLFormElement::add_associated_element()/remove_associated_element().
pub fn (mut form HTMLFormElementModel) add_associated_element(mut control FormAssociatedElement) {
	form.add_control(mut control)
}

pub fn (mut form HTMLFormElementModel) remove_associated_element(control &FormAssociatedElement) {
	form.remove_control(control)
	for name, element in form.past_names_map_.clone() {
		if voidptr(element) == voidptr(control.element) {
			form.past_names_map_.delete(name)
			form.past_names_age_.delete(name)
		}
	}
}

// HTMLFormElement::action_from_form_element(). `none` denotes the form itself.
pub fn (form &HTMLFormElementModel) action_from_form_element(submitter ?&FormAssociatedElement) string {
	if control := submitter {
		if control.is_submit_button() {
			if value := control.element.get_attribute('formaction') {
				return value
			}
		}
	}
	return form_model_element(form).get_attribute('action') or { '' }
}

pub fn (form &HTMLFormElementModel) method_state_from_form_element(submitter ?&FormAssociatedElement) FormMethodState {
	return form.method_state(submitter)
}

pub fn (form &HTMLFormElementModel) encoding_type_state_from_form_element(submitter ?&FormAssociatedElement) FormEncodingType {
	return form.encoding_type(submitter)
}

// HTMLFormElement::elements().
pub fn (mut form HTMLFormElementModel) elements() &HTMLFormControlsCollection {
	if collection := form.elements_ {
		return collection
	}
	root := html_form_element_root(&form)
	collection := HTMLFormControlsCollection.create(unsafe { &dom.ParentNode(root) }, .descendants, fn [form] (element &dom.Element) bool {
		return html_form_element_is_form_control(form, element)
	})
	form.elements_ = collection
	return collection
}

// HTMLFormElement::statically_validate_constraints().
pub fn (form &HTMLFormElementModel) statically_validate_constraints() StaticFormValidationResult {
	mut invalid_controls := []&FormAssociatedElement{}
	for control in form.get_submittable_elements() {
		if !control.is_candidate_for_constraint_validation() || control.satisfies_its_constraints() {
			continue
		}
		invalid_controls << control
	}
	if invalid_controls.len == 0 {
		return StaticFormValidationResult{ result: true }
	}
	mut unhandled := []&FormAssociatedElement{}
	for control in invalid_controls {
		event := dom.Event.create('invalid', dom.EventInit{ cancelable: true })
		if unsafe { &dom.EventTarget(control.element.as_node()) }.dispatch_event(event) {
			unhandled << control
		}
	}
	return StaticFormValidationResult{
		result: false
		unhandled_invalid_controls: unhandled
	}
}

// HTMLFormElement::interactively_validate_constraints(). The platform's
// validation bubble is outside LibWeb; focus state still follows the algorithm.
pub fn (form &HTMLFormElementModel) interactively_validate_constraints() bool {
	result := form.statically_validate_constraints()
	if result.result {
		return true
	}
	if result.unhandled_invalid_controls.len > 0 {
		control := result.unhandled_invalid_controls[0]
		mut document := control.element.document()
		document.set_focused_area(control.element.as_node())
	}
	return false
}

pub fn (form &HTMLFormElementModel) report_validity() bool {
	return form.interactively_validate_constraints()
}

pub fn (form &HTMLFormElementModel) get_submittable_elements() []&FormAssociatedElement {
	materialize_form_associated_controls(form, html_form_element_root(form))
	mut controls := []&FormAssociatedElement{}
	// Upstream owns one concrete FormAssociatedElement per DOM element. The V
	// wrappers are separate records, so resolve the same associated DOM identity
	// before filtering, rather than limiting membership to registered wrappers.
	for element in form.element.associated_elements_.clone() {
		control := form_associated_record_for_entry(form, element)
		if control.is_submittable() {
			controls << control
		}
	}
	for i := 1; i < controls.len; i++ {
		mut j := i
		for j > 0 && controls[j].element.as_node().is_preceding(controls[j - 1].element.as_node()) {
			controls[j], controls[j - 1] = controls[j - 1], controls[j]
			j--
		}
	}
	return controls
}

// Concrete control owners are lazy in the V browser. Discover the form's
// untouched controls before taking the submission snapshot, including controls
// outside the form which use its ID, without entering another shadow tree.
fn materialize_form_associated_controls(form &HTMLFormElementModel, node &dom.Node) {
	if element := node.as_element() {
		if element.is_html_element() && html_form_element_is_listed(element)
			&& !html_form_element_is_associated(form, element) {
			owner := if element.has_attribute('form') && element.is_connected() {
				form_element_find_form_by_id(node.root(), element.get_attribute_value('form'))
			} else if ancestor := form_element_nearest_ancestor(element, 'form') {
				?&dom.HTMLFormElement(unsafe { &dom.HTMLFormElement(ancestor) })
			} else {
				?&dom.HTMLFormElement(none)
			}
			if owner_form := owner {
				if voidptr(owner_form) == voidptr(form.element) {
					_ = form_associated_record_for_entry(form, element)
				}
			}
		}
	}
	for child in node.children {
		materialize_form_associated_controls(form, child)
	}
}

fn form_associated_record_for_entry(form &HTMLFormElementModel, element &dom.Element) &FormAssociatedElement {
	for control in form.controls_ {
		if voidptr(control.element) == voidptr(element) {
			return control
		}
	}
	if element.is_form_associated_custom_element() {
		target := unsafe { &dom.HTMLElement(element) }
		if target.attached_internals_handle() != unsafe { nil } {
			return unsafe { &ElementInternals(target.attached_internals_handle()) }.control
		}
	}
	mut control := match element.local_name() {
		'input' { HTMLInputElementModel.create(unsafe { &dom.HTMLInputElement(element) }).control }
		'textarea' {
			HTMLTextAreaElementModel.create(unsafe { &dom.HTMLTextAreaElement(element) }).control
		}
		'select' {
			HTMLSelectElementModel.create(unsafe { &dom.HTMLSelectElement(element) }).control
		}
		'button' {
			HTMLButtonElementModel.create(unsafe { &dom.HTMLButtonElement(element) }).control
		}
		else {
			if element.is_form_associated_custom_element() {
				FormAssociatedElement.create_custom(element)
			} else { FormAssociatedElement.create(element) }
		}
	}
	// Membership in the DOM form's associated list is the authoritative owner
	// when a previously lazy concrete wrapper is materialized here.
	control.set_form(form.element)
	return control
}

pub fn (mut form HTMLFormElementModel) rel_list() &dom.DOMTokenList {
	if list := form.rel_list_ {
		return list
	}
	list := dom.DOMTokenList.create(form_model_element(&form), 'rel')
	form.rel_list_ = list
	return list
}

pub fn (mut form HTMLFormElementModel) set_method(method string) {
	mut element := form_model_element(&form)
	element.set_attribute_value('method', method)
}

// The action IDL getter resolves the reflected value against the document URL.
pub fn (form &HTMLFormElementModel) action() string {
	element := form_model_element(form)
	attribute := element.get_attribute('action') or { return element.document().url_string() }
	if attribute == '' {
		return element.document().url_string()
	}
	return dom.dom_url_parse(attribute, element.document().base_url(), 'UTF-8') or {
		return ''
	}.serialize()
}

pub fn (mut form HTMLFormElementModel) set_action(value string) {
	mut element := form_model_element(&form)
	element.set_attribute_value('action', value)
}

pub fn (mut form HTMLFormElementModel) attribute_changed(name string, value ?string) {
	if name == 'rel' {
		if existing_list := form.rel_list_ {
			mut list := unsafe { &dom.DOMTokenList(existing_list) }
			list.associated_attribute_changed(value or { '' })
		}
	}
}

// HTMLFormElement::pick_an_encoding().
pub fn (form &HTMLFormElementModel) pick_an_encoding() string {
	element := form_model_element(form)
	if input := element.get_attribute('accept-charset') {
		for label in input.fields() {
			if candidate := encoding.get_an_encoding(label) {
				return candidate
			}
		}
		return 'UTF-8'
	}
	encoding_name := encoding.get_an_encoding(element.document().encoding_or_default()) or {
		'UTF-8'
	}
	// The Encoding Standard's output-encoding operation maps replacement and
	// both UTF-16 encodings to UTF-8.
	return if encoding_name in ['replacement', 'UTF-16BE', 'UTF-16LE'] {
		'UTF-8'
	} else {
		encoding_name
	}
}

fn form_entry_string_value(value FormDataEntryValue) string {
	return match value {
		FormDataFile { value.name }
		string { value }
	}
}

fn html_form_name_value_pairs(entries []FormDataEntry) []FormDataEntry {
	mut pairs := []FormDataEntry{}
	for entry in entries {
		pairs << create_form_data_string_entry(normalize_line_breaks(entry.name), normalize_line_breaks(form_entry_string_value(entry.value)))
	}
	return pairs
}

fn html_form_url_encode(entries []FormDataEntry) string {
	mut fields := []string{}
	for entry in html_form_name_value_pairs(entries) {
		fields << '${form_url_encode_component(entry.name)}=${form_url_encode_component(form_entry_string_value(entry.value))}'
	}
	return fields.join('&')
}

fn html_form_plain_text_encode(entries []FormDataEntry) string {
	mut output := ''
	for entry in html_form_name_value_pairs(entries) {
		output += '${entry.name}=${form_entry_string_value(entry.value)}\r\n'
	}
	return output
}

fn html_form_percent_encode_path(value string) string {
	mut output := ''
	for byte in value.bytes() {
		if (byte >= `a` && byte <= `z`) || (byte >= `A` && byte <= `Z`) || (byte >= `0` && byte <= `9`) || byte in [
			`-`,
			`_`,
			`.`,
			`~`,
			`!`,
			`$`,
			`&`,
			`'`,
			`(`,
			`)`,
			`*`,
			`+`,
			`,`,
			`;`,
			`=`,
			`:`,
			`@`,
		] {
			output += byte.ascii_str()
		} else {
			output += '%${byte.hex().to_upper()}'
		}
	}
	return output
}

pub fn (mut form HTMLFormElementModel) mutate_action_url(parsed_action dom.URL, entry_list []FormDataEntry, _ string, user_involvement UserNavigationInvolvement) ! {
	url := parsed_action.with_query(html_form_url_encode(entry_list))
	form.plan_to_navigate_to(FormSubmission{
		url: url
		method: .get
		encoding: .url_encoded
		entries: entry_list
		referrer_policy: if form.rel_list().contains('noreferrer') { 'no-referrer' } else { '' }
		user_involvement: user_involvement
	})!
}

pub fn (mut form HTMLFormElementModel) submit_as_entity_body(parsed_action dom.URL, entry_list []FormDataEntry, encoding_type FormEncodingType, _ string, user_involvement UserNavigationInvolvement) ! {
	mut body := []u8{}
	mut content_type := ''
	match encoding_type {
		.url_encoded {
			body = html_form_url_encode(entry_list).bytes()
			content_type = 'application/x-www-form-urlencoded'
		}
		.multipart {
			serialized := serialize_to_multipart_form_data(entry_list)
			body = serialized.serialized_data.clone()
			content_type = 'multipart/form-data; boundary=${serialized.boundary}'
		}
		.plain_text {
			body = html_form_plain_text_encode(entry_list).bytes()
			content_type = 'text/plain'
		}
	}
	form.plan_to_navigate_to(FormSubmission{
		url: parsed_action
		method: .post
		encoding: encoding_type
		entries: entry_list
		body: body
		content_type: content_type
		referrer_policy: if form.rel_list().contains('noreferrer') { 'no-referrer' } else { '' }
		user_involvement: user_involvement
	})!
}

pub fn (mut form HTMLFormElementModel) get_action_url(parsed_action dom.URL, entry_list []FormDataEntry, user_involvement UserNavigationInvolvement) ! {
	form.plan_to_navigate_to(FormSubmission{
		url: parsed_action
		method: .get
		encoding: .url_encoded
		entries: entry_list
		referrer_policy: if form.rel_list().contains('noreferrer') { 'no-referrer' } else { '' }
		user_involvement: user_involvement
	})!
}

pub fn (mut form HTMLFormElementModel) mail_with_headers(parsed_action dom.URL, entry_list []FormDataEntry, _ string, user_involvement UserNavigationInvolvement) ! {
	headers := html_form_url_encode(entry_list).replace('+', '%20')
	form.get_action_url(parsed_action.with_query(headers), entry_list, user_involvement)!
}

pub fn (mut form HTMLFormElementModel) mail_as_body(parsed_action dom.URL, entry_list []FormDataEntry, encoding_type FormEncodingType, _ string, user_involvement UserNavigationInvolvement) ! {
	body := if encoding_type == .plain_text {
		html_form_percent_encode_path(html_form_plain_text_encode(entry_list))
	} else {
		html_form_url_encode(entry_list)
	}
	old_query := parsed_action.query() or { '' }
	separator := if old_query == '' { '' } else { '&' }
	form.get_action_url(parsed_action.with_query('${old_query}${separator}body=${body}'), entry_list, user_involvement)!
}

// HTMLFormElement::plan_to_navigate_to(). The host hook can consume the typed
// submission; otherwise use the navigable's URL handoff for GET navigation.
pub fn (mut form HTMLFormElementModel) plan_to_navigate_to(submission FormSubmission) ! {
	form.last_submission_ = submission
	if hook := form.submission_hook_ {
		hook(submission)!
		return
	}
	// The compact browser's navigable already owns the native URL handoff.
	// Entity-body and auxiliary-target submissions retain their typed host hook.
	if submission.method != .get {
		return
	}
	element := form_model_element(&form)
	if ascii_lowercase_string(element.get_attribute_value('target')) !in ['', '_self'] {
		return
	}
	document := element.document()
	navigable := document.navigable() or { return }
	if navigable.html_model_handle_ == unsafe { nil }
		|| navigable.navigate_callback_ == unsafe { nil } {
		return
	}
	involvement := match submission.user_involvement {
		.browser_ui { dom.UserNavigationInvolvement.browser_ui }
		.activation { dom.UserNavigationInvolvement.activation }
		.none_ { dom.UserNavigationInvolvement.none }
	}
	navigable.navigate(submission.url, document, submission.referrer_policy, involvement)!
}

pub fn (mut form HTMLFormElementModel) item_value(index uint) ?&dom.Element {
	return form.elements().item(int(index))
}

pub fn (form &HTMLFormElementModel) is_supported_property_name(name string) bool {
	// This is the allocation-free membership form of supported_property_names().
	for candidate in form.element.associated_elements_ {
		if !html_form_element_is_form_control(form, candidate) && candidate.local_name() != 'img' {
			continue
		}
		if id := candidate.id() {
			if id == name {
				return true
			}
		}
		if candidate_name := candidate.get_attribute('name') {
			if candidate_name == name {
				return true
			}
		}
	}
	return name in form.past_names_map_
}

enum FormSupportedNameSource {
	id
	name
	past
}

struct FormSupportedName {
	name    string
	element &dom.Element
	source  FormSupportedNameSource
	age     u64
}

fn form_supported_name_less_than(left FormSupportedName, right FormSupportedName) bool {
	if voidptr(left.element) != voidptr(right.element) {
		return left.element.as_node().is_preceding(right.element.as_node())
	}
	if left.source != right.source {
		return int(left.source) < int(right.source)
	}
	return left.age < right.age
}

fn sort_form_supported_names(mut names []FormSupportedName) {
	for i := 1; i < names.len; i++ {
		mut j := i
		for j > 0 && form_supported_name_less_than(names[j], names[j - 1]) {
			names[j], names[j - 1] = names[j - 1], names[j]
			j--
		}
	}
}

fn (mut form HTMLFormElementModel) remember_past_name(name string, element &dom.Element) {
	existing_is_same := if existing := form.past_names_map_[name] {
		voidptr(existing) == voidptr(element)
	} else {
		false
	}
	if !existing_is_same {
		form.past_names_age_[name] = form.next_past_name_age_
		form.next_past_name_age_++
	}
	form.past_names_map_[name] = element
}

pub fn (form &HTMLFormElementModel) supported_property_names() []string {
	mut sourced_names := []FormSupportedName{}
	for element in form.element.associated_elements_ {
		if !html_form_element_is_form_control(form, element) && element.local_name() != 'img' {
			continue
		}
		if id := element.id() {
			sourced_names << FormSupportedName{
				name: id
				element: element
				source: .id
			}
		}
		if name := element.get_attribute('name') {
			sourced_names << FormSupportedName{
				name: name
				element: element
				source: .name
			}
		}
	}
	for name, element in form.past_names_map_ {
		sourced_names << FormSupportedName{
			name: name
			element: element
			source: .past
			age: form.past_names_age_[name]
		}
	}
	sort_form_supported_names(mut sourced_names)

	mut names := []string{}
	for entry in sourced_names {
		if entry.name != '' && entry.name !in names {
			names << entry.name
		}
	}
	return names
}

pub fn (mut form HTMLFormElementModel) named_item_value(name string) HTMLFormControlsNamedItem {
	if name == '' {
		return HTMLFormControlsCollectionEmpty{}
	}
	result := form.elements().named_item_or_radio_node_list(name)
	if result !is HTMLFormControlsCollectionEmpty {
		if result is HTMLFormControlsCollectionElement {
			form.remember_past_name(name, result.element)
		}
		return result
	}
	root := html_form_element_root(&form)
	images := RadioNodeList.create(root, .descendants, fn [form, name] (node &dom.Node) bool {
		element := node.as_element() or { return false }
		return element.local_name() == 'img' && html_form_element_is_associated(form, element) && (element.id() or { '' } == name || element.get_attribute('name') or { '' } == name)
	})
	if images.length() > 1 {
		return HTMLFormControlsCollectionRadioNodeList{ list: images }
	}
	if images.length() == 1 {
		node := images.item(0) or { return HTMLFormControlsCollectionEmpty{} }
		element := node.as_element() or { return HTMLFormControlsCollectionEmpty{} }
		form.remember_past_name(name, element)
		return HTMLFormControlsCollectionElement{ element: element }
	}
	if element := form.past_names_map_[name] {
		return HTMLFormControlsCollectionElement{ element: element }
	}
	return HTMLFormControlsCollectionEmpty{}
}

pub fn (form &HTMLFormElementModel) default_button() ?&FormAssociatedElement {
	for control in form.get_submittable_elements() {
		owner := control.form() or { continue }
		if voidptr(owner) == voidptr(form.element) && control.is_submit_button() {
			return control
		}
	}
	return none
}

pub fn (form &HTMLFormElementModel) number_of_fields_blocking_implicit_submission() uint {
	mut count := 0
	for control in form.get_submittable_elements() {
		if control.element.local_name() != 'input' {
			continue
		}
		owner := control.form() or { continue }
		if voidptr(owner) != voidptr(form.element) {
			continue
		}
		if form_element_input_type(control.element) in ['text', 'search', 'tel', 'url', 'email',
			'password', 'date', 'month', 'week', 'time', 'datetime-local', 'number'] {
			count++
		}
	}
	return uint(count)
}
