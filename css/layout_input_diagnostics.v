module css

import os
import platform

const layout_input_diagnostics = os.getenv('VOX_LAYOUT_INPUT_DIAGNOSTICS') != ''

__global layout_input_diagnostic_count int
__global layout_font_page_diagnostic_count int

fn report_layout_font_page_diagnostic(computer &StyleComputer, source &ComputedPropertyPage, index int) {
	if !layout_input_diagnostics || layout_font_page_diagnostic_count >= 40 { return }
	font_page := (int(PropertyID.font_size) - int(first_longhand_property_id())) / computed_property_page_size
	if index != font_page && index != 10 { return }
	layout_font_page_diagnostic_count++
	mut candidates := []string{}
	ids := computed_interpolation_longhand_property_ids()
	for slot, value in source.values {
		if value == unsafe { nil } || value.css_value_handle == unsafe { nil } { continue }
		box := unsafe { &TypedStyleValueBox(value.css_value_handle) }
		property := ids[index * computed_property_page_size + slot]
		if device_layout_value_needs_projection(property, &box.value) {
			candidates << '${property}:${box.value.type_name()}:${value.css_text}:scale_only=${device_layout_value_is_scale_only(&box.value)}'
		}
	}
	eprintln('VOX_FONT_PAGE_SOURCE index=${index} page=${u64(voidptr(source))} generation=${source.device_layout_generation_} retainable=${computer.can_retain_device_layout_page(source)} candidates=${candidates.join(",")}')
}

fn report_layout_input_diagnostic(style &ComputedProperties) {
	if !layout_input_diagnostics || layout_input_diagnostic_count >= 400 { return }
	layout_input_diagnostic_count++
	mut noninitial := []string{}
	mut pages := []string{}
	mut key := u64(14695981039346656037)
	for index, page in style.property_store_.pages {
		pages << u64(voidptr(page)).str()
		key = (key ^ u64(voidptr(page))) * 1099511628211
		for slot, value in page.values {
			if value == unsafe { nil } || computed_initial_property_store == unsafe { nil }
				|| voidptr(value) == voidptr(computed_initial_property_store.pages[index].values[slot]) { continue }
			kind := if value.css_value_handle == unsafe { nil } { 'untyped' } else {
				box := unsafe { &TypedStyleValueBox(value.css_value_handle) }
				box.value.type_name()
			}
			noninitial << '${index}:${slot}:${kind}'
		}
	}
	fonts := style.cached_computed_font_list_ or { unsafe { &FontCascadeList(nil) } }
	eprintln('VOX_LAYOUT_INPUT key=${key} fonts=${u64(voidptr(fonts))} line_override=${style.line_height_ != none} variations=${style.font_variation_storage_ != unsafe { nil }} samples=${platform.transient_arena_entered()} pages=${pages.join(',')} inputs=${noninitial.join(',')}')
}
