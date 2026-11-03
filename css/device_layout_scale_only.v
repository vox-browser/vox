module css

import os

const disable_scale_only_device_layout = os.getenv('VOX_DISABLE_SCALE_ONLY_DEVICE_LAYOUT') != ''
const disable_font_page_projection_reuse = os.getenv('VOX_DISABLE_FONT_PAGE_PROJECTION_REUSE') != ''

fn device_layout_edge_is_scale_only(value &EdgeStyleValue) bool {
	if offset := style_value_from_optional_storage(value.offset_) {
		return device_layout_value_is_scale_only(&offset)
	}
	return true
}

// Absolutizing these containers consumes only the absolute-length scale.
// Keep relative lengths, calculations and unknown value types on the complete
// font/viewport context path. Edge keywords still pass through absolutized(),
// which turns them into their computed percentage offsets.
fn device_layout_value_is_scale_only(value &StyleValue) bool {
	if disable_scale_only_device_layout { return false }
	return match value {
		LengthStyleValue { value.length_.is_absolute() }
		KeywordStyleValue { value.keyword() == .currentcolor || !value.has_color() }
		NumberStyleValue, PercentageStyleValue, IntegerStyleValue, CustomIdentStyleValue,
		StringStyleValue, RepeatStyleStyleValue { true }
		StyleValueList {
			mut independent := true
			for child in value.values_ {
				if !device_layout_value_is_scale_only(&child) {
					independent = false
					break
				}
			}
			independent
		}
		BackgroundSizeStyleValue {
			device_layout_value_is_scale_only(&value.size_x_[0])
				&& device_layout_value_is_scale_only(&value.size_y_[0])
		}
		BorderRadiusStyleValue {
			device_layout_value_is_scale_only(&value.horizontal_radius[0])
				&& device_layout_value_is_scale_only(&value.vertical_radius[0])
		}
		BorderRadiusRectStyleValue {
			device_layout_value_is_scale_only(&value.top_left_[0])
				&& device_layout_value_is_scale_only(&value.top_right_[0])
				&& device_layout_value_is_scale_only(&value.bottom_right_[0])
				&& device_layout_value_is_scale_only(&value.bottom_left_[0])
		}
		EdgeStyleValue { device_layout_edge_is_scale_only(value) }
		PositionStyleValue {
			device_layout_edge_is_scale_only(&value.edge_x_)
				&& device_layout_edge_is_scale_only(&value.edge_y_)
		}
		TextIndentStyleValue { device_layout_value_is_scale_only(&value.length_percentage_[0]) }
		else { false }
	}
}
