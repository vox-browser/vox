module platform

@[typedef]
struct C.hb_ot_var_axis_info_t {
	axis_index    u32
	tag           u32
	name_id       u32
	flags         u32
	min_value     f32
	default_value f32
	max_value     f32
	reserved      u32
}

fn C.hb_ot_var_find_axis_info(face voidptr, tag u32, info &C.hb_ot_var_axis_info_t) int

fn (font &Font) source_variations() []FontVariationAxis {
	if font.source_path == '' || font.requested_variations.len == 0 { return [] }
	if font.variations_resolved_ { return font.resolved_variations_ }
	face := document_harfbuzz_face(font) or { return [] }
	persistent := enter_persistent()
	defer { leave_persistent(persistent) }
	mut axes := []FontVariationAxis{}
	for requested in font.requested_variations {
		mut info := C.hb_ot_var_axis_info_t{}
		if C.hb_ot_var_find_axis_info(face, requested.tag, &info) == 0 { continue }
		value := if requested.value < info.min_value {
			info.min_value
		} else if requested.value > info.max_value {
			info.max_value
		} else {
			requested.value
		}
		axes << FontVariationAxis{ tag: requested.tag, value: value }
	}
	mut mutable_font := unsafe { &Font(font) }
	mutable_font.resolved_variations_ = axes
	mutable_font.variations_resolved_ = true
	return axes
}
