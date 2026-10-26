module html

import dom

// Menu-list controls use the Chromium theme; list boxes keep their own layout.
pub fn html_select_element_uses_chromium_menu_list(element &dom.Element) bool {
	return element.is_html_element() && element.local_name() == 'select'
		&& element.document().font_rendering_policy() == .chromium
		&& !element.has_attribute('multiple') && element.get_attribute_value('size').int() <= 1
}

// Blink derives popup padding from the native scrollbar-arrow width. macOS
// supplies 11 CSS pixels; platforms without that metric use its 15px fallback.
pub fn chromium_menu_list_arrow_padding() int {
	$if macos { return 11 }
	return 15
}

fn chromium_select_label_style() string {
	end := 1 + chromium_menu_list_arrow_padding()
	return 'flex:1;min-width:0;overflow:clip;text-overflow:inherit;margin-inline-start:4px;margin-inline-end:${end}px;padding-block:1px;'
}
