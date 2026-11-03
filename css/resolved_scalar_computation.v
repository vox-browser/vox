module css

import dom
import os

const disable_resolved_scalar_computation = os.getenv('VOX_DISABLE_RESOLVED_SCALAR_COMPUTATION') != ''
const resolved_scalar_computation_diagnostics = os.getenv('VOX_RESOLVED_SCALAR_COMPUTATION_DIAGNOSTICS') != ''
__global resolved_scalar_computation_reported bool

// These property algorithms return their absolutized value directly. A typed
// scalar which absolutization leaves unchanged needs no font metrics, query
// container, dependency tracker or replacement wrapper. Keep the allowlist
// explicit so a new property-specific algorithm cannot silently enter it.
fn property_uses_resolved_scalar_directly(id PropertyID) bool {
	return id in [.color, .background_color, .display, .position, .float_, .clear,
		.width, .height, .min_width, .min_height, .max_width, .max_height,
		.block_size, .inline_size, .min_block_size, .min_inline_size, .max_block_size, .max_inline_size,
		.top, .right, .bottom, .left, .inset_block_start, .inset_block_end,
		.inset_inline_start, .inset_inline_end, .margin_top, .margin_right,
		.margin_bottom, .margin_left, .margin_block_start, .margin_block_end,
		.margin_inline_start, .margin_inline_end, .padding_top, .padding_right,
		.padding_bottom, .padding_left, .padding_block_start, .padding_block_end,
		.padding_inline_start, .padding_inline_end, .z_index, .order, .flex_grow,
		.flex_shrink, .overflow_x, .overflow_y, .box_sizing, .visibility,
		.border_top_style, .border_right_style, .border_bottom_style, .border_left_style,
		.border_top_color, .border_right_color, .border_bottom_color, .border_left_color,
		.text_align, .font_family] || (!disable_scalar_font_computation && id in [.font_kerning, .font_optical_sizing,
		.font_variant_alternates, .font_variant_caps, .font_variant_east_asian,
		.font_variant_emoji, .font_variant_ligatures, .font_variant_numeric,
		.font_variant_position, .text_rendering])
}

fn scalar_value_is_already_absolutized(value &StyleValue) bool {
	return match value {
		KeywordStyleValue {
			value.keyword_ !in [.initial, .inherit, .unset, .revert, .revert_layer]
				&& (!value.has_color() || value.keyword_ == .currentcolor)
		}
		LengthStyleValue { value.length_.is_px() }
		ColorStyleValue, NumberStyleValue, IntegerStyleValue, PercentageStyleValue,
		StringStyleValue, CustomIdentStyleValue, DisplayStyleValue { true }
		else { false }
	}
}

fn computed_scalar_value_is_resolved(id PropertyID, value &dom.StyleValue) bool {
	if disable_resolved_scalar_computation || !property_uses_resolved_scalar_directly(id)
		|| value.css_value_handle == unsafe { nil } { return false }
	box := unsafe { &TypedStyleValueBox(value.css_value_handle) }
	if !scalar_value_is_already_absolutized(&box.value)
		&& !(id == .font_family && !disable_scalar_font_computation
			&& resolved_font_family_list(&box.value)) { return false }
	if resolved_scalar_computation_diagnostics && !resolved_scalar_computation_reported {
		resolved_scalar_computation_reported = true
		eprintln('VOX_RESOLVED_SCALAR_COMPUTATION retained typed computed value')
	}
	return true
}
