module dom

pub fn (element &Element) cryptographic_nonce() string {
	if element.is_html_element() { return unsafe { &HTMLElement(element) }.cryptographic_nonce() }
	if element.is_svg_element() && element.binding_data_ != unsafe { nil } { return element.binding_data_.cryptographic_nonce }
	return ''
}

pub fn (mut element Element) set_cryptographic_nonce(value string) {
	if element.is_html_element() {
		mut html_element := unsafe { &HTMLElement(&element) }
		html_element.set_cryptographic_nonce(value)
	} else if element.is_svg_element() && element.cryptographic_nonce() != value {
		mut state := element.copy_binding_data()
		state.cryptographic_nonce = value
		element.binding_data_ = state
	}
}

fn (mut element Element) hide_cryptographic_nonce_if_needed() {
	if !(element.is_html_element() || element.is_svg_element()) || !element.as_node().is_browsing_context_connected()
		|| !element.has_attribute('nonce') { return }
	if !element.document().policy_container().csp_list.any(it.source == .header) { return }
	value := element.cryptographic_nonce()
	element.set_attribute_value('nonce', '')
	element.set_cryptographic_nonce(value)
}
