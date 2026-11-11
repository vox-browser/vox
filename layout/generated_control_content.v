module layout

import dom

// Internal control children do not make a replaced host accept author
// ::before/::after content. Appearance:none checkboxes and radio buttons are
// ordinary CSS boxes and retain their generated content.
fn control_allows_generated_content(box &Node, element &dom.Element) bool {
	if box.is_replaced_box() { return false }
	if element.is_html_element() && element.local_name() == 'input' {
		return element.get_attribute_value('type').to_lower() in ['checkbox', 'radio']
			&& box.computed_values().appearance() == .none_
	}
	return true
}
