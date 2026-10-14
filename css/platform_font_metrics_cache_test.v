module css

import dom
import math
import os
import platform
import time

$if gcboehm ? {
	fn C.GC_gcollect()
}

fn retained_metrics_font_owner() &PlatformFont {
	font := &PlatformFont{
		typeface:   &PlatformTypeface{
			family_name: 'SerenitySans'
		}
		point_size: 12.375
	}
	_ = font.font_for_metrics().pixel_metrics()
	return font
}

fn test_css_metrics_font_handle_survives_collection_at_fractional_size() {
	owner := retained_metrics_font_owner()
	$if gcboehm ? { C.GC_gcollect() }
	font := owner.font_for_metrics()
	assert font == owner.metrics_font_
	assert font == owner.font_for_metrics()
	assert font.point_size == 16.5
	assert font.pixel_metrics() == (platform.Font{
		family:     'SerenitySans'
		point_size: 16.5
	}).pixel_metrics()
	assert font.pixel_metrics().size == 16.5
}

fn test_css_metrics_font_handle_replaces_changed_inputs_and_keeps_old_snapshot() {
	mut typeface := &PlatformTypeface{
		family_name: 'SerenitySans'
	}
	mut font := PlatformFont{
		typeface:   typeface
		point_size: 12
	}
	first := font.font_for_metrics()
	font.point_size = 12.375
	resized := font.font_for_metrics()
	assert resized != first
	assert resized.point_size == 16.5
	assert first.point_size == 16
	font.variations.weight = 700
	bold := font.font_for_metrics()
	assert bold != resized
	assert bold.weight == 700
	assert resized.weight == 400
	typeface.family_name = 'Serif'
	serif := font.font_for_metrics()
	assert serif != bold
	assert serif.family == 'Serif'
	assert bold.family == 'SerenitySans'
	typeface.source_path = '/unused/metrics-source.ttf'
	sourced := font.font_for_metrics()
	assert sourced != serif
	assert sourced.source_path == '/unused/metrics-source.ttf'
	assert serif.source_path == ''
	assert sourced == font.font_for_metrics()
}

fn test_line_height_and_length_metrics_share_the_selected_font_handle() {
	mut style := ComputedProperties.new()
	style.set_property(.font_family, &dom.StyleValue{
		css_text: 'SerenitySans'
	}, .no, .no)
	style.set_property(.font_size, &dom.StyleValue{
		css_text: '16.5px'
	}, .no, .no)
	computer := FontComputer.create()
	selected := style.first_available_computed_font(computer)
	assert selected.metrics_font_ == unsafe { nil }
	line_height := style.line_height()
	handle := selected.metrics_font_
	assert handle != unsafe { nil }
	pixels := handle.pixel_metrics()
	assert line_height == CSSPixels.new(int(math.round_to_even(f64(pixels.ascent))) +
		int(math.round_to_even(f64(pixels.descent))))
	length_metrics := computed_interpolation_font_metrics_for_style(style, computer)
	assert length_metrics.line_height == line_height
	assert length_metrics.x_height == CSSPixels.nearest_value_for(f64(pixels.x_height))
	assert selected.metrics_font_ == handle
	style.set_property(.font_size, &dom.StyleValue{
		css_text: '24px'
	}, .no, .no)
	replacement := style.first_available_computed_font(computer)
	assert replacement != selected
	replacement_line_height := style.line_height()
	assert replacement.metrics_font_ != handle
	assert replacement.metrics_font_.point_size == 24
	assert replacement_line_height != line_height
	assert handle.point_size == 16.5
}

fn test_css_metrics_font_handle_retries_an_unavailable_explicit_source() {
	source := os.real_path(os.join_path(os.dir(os.dir(@FILE)), '..', '3rd', 'ladybird', 'Base',
		'res', 'fonts', 'NotoEmoji.ttf'))
	assert os.is_file(source)
	path := os.join_path(os.temp_dir(),
		'vox-css-late-metrics-${os.getpid()}-${time.sys_mono_now()}.ttf')
	defer { os.rm(path) or {} }
	font := PlatformFont{
		typeface:   &PlatformTypeface{
			family_name: 'DelayedMetricsFixture'
			source_path: path
		}
		point_size: 12.375
	}
	handle := font.font_for_metrics()
	fallback := handle.pixel_metrics()
	os.cp(source, path)!
	assert font.font_for_metrics() == handle
	loaded := font.font_for_metrics().pixel_metrics()
	expected := platform.Font{
		family:      'DelayedMetricsFixture'
		source_path: source
		point_size:  16.5
	}
	assert loaded == expected.pixel_metrics()
	assert loaded != fallback
	os.rm(path)!
	assert font.font_for_metrics().pixel_metrics() == loaded
}
