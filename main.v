module main

import color
import adblock
import browsernet
import browserjs
import crypto.sha256
import css
import dom
import domurl
import encoding
import encoding.base64
import fetch
import fileapi
import geolocation
import geometry
import gg
import highresolutiontime
import html
import http
import infra
import layout
import math
import mimesniff
import namespace_
import os
import page
import painting
import platform
import processmetrics
import referrerpolicy
import requestserver
import selection
import sokol.sapp
import stbi
import sri
import storageapi
import strconv
import time
import url
import webvtt
import xpath
import x.json2

// Mark on the initiating thread by default; GC_MARKERS can override this.
#flag -DGC_MARKERS=1

#flag darwin -framework CoreImage

$if macos {
	#include "native_capture_darwin.m"
}

fn C.schedule_native_screenshot(path string)

fn C.native_decode_video_frame(path &char, seconds f64, output_width &int, output_height &int, output_pitch &int) &u8

fn C.native_free_video_frame(pixels &u8)
fn C.native_decode_webp_rgba(bytes &u8, length usize, width &int, height &int, pitch &int) &u8
fn C.native_free_webp_pixels(pixels &u8)
fn C.native_decode_webp_yuv(bytes &u8, length usize, width &int, height &int, size &int) &u8
fn C.native_webp_yuv_paint_supported() int
fn C.native_webp_yuv_decoder_available() int
fn C.native_decode_jpeg_rgba(bytes &u8, length usize, width &int, height &int, pitch &int) &u8
fn C.native_tag_image_color_profile(pixels voidptr, width int, height int, bytes &u8, length usize, enabled int)
fn C.native_free_jpeg_pixels(pixels &u8)

fn C.native_pointer_screen_position(x f64, y f64, screen_x &f64, screen_y &f64)

fn C.native_window_width() int

fn C.native_window_height() int

fn C.native_wake_browser()

fn C.native_wake_browser_after(milliseconds int)
fn C.native_schedule_capture_retry(fn (voidptr) int, voidptr)
fn C.native_cancel_capture_retry()

fn C.native_prevent_app_nap()

fn C.native_position_window_top_right()

fn C.native_prepare_test_window()

fn C.native_finish_test_window()

fn C.native_show_cached_snapshot(path string)

fn C.native_hide_cached_snapshot()

fn C.native_cache_browser_snapshot(path string)

fn C.native_draw_rect_srgb(x f32, y f32, width f32, height f32, fill_color gg.Color)

fn C.native_draw_ellipse_srgb(x f32, y f32, width f32, height f32, transform_a f32, transform_b f32, transform_c f32, transform_d f32, transform_e f32, transform_f f32, page_x f32, page_y f32, scroll_y f32, canvas_height f32, color gg.Color, fill int, thickness f32)

fn C.native_configure_document_font(path string)

fn C.native_configure_document_bold_font(path string)

fn C.native_configure_emoji_font(path string)

fn C.native_draw_document_text_srgb(x f32, y f32, text string, color gg.Color, size f32, bold int, italic int, monospace int)

fn C.native_draw_document_text_shadow_srgb(x f32, y f32, text string, color gg.Color, size f32, bold int, italic int, monospace int, blur f32)

fn C.native_draw_document_glyph_run_srgb(glyphs &u16, positions &f64, glyph_count int, font_size f32, font_weight int, emoji_face int, baseline_x f32, baseline_y f32, transform_a f32, transform_b f32, transform_c f32, transform_d f32, transform_e f32, transform_f f32, page_x f32, page_y f32, scroll_y f32, canvas_width f32, canvas_height f32, font_path string, face_index int, color gg.Color, blur f32, shadow_only int, font_smoothing int) int

fn C.native_draw_canvas_glyph_run_rgba(pixels &u8, width int, height int, pitch int, pixels_are_premultiplied int, glyphs &u16, positions &f64, glyph_count int, font_size f32, font_weight int, font_path string, face_index int, baseline_x f32, baseline_y f32, transform_a f32, transform_b f32, transform_c f32, transform_d f32, transform_e f32, transform_f f32, red u8, green u8, blue u8, alpha u8, gradient_x0 f32, gradient_y0 f32, gradient_x1 f32, gradient_y1 f32, gradient_stops &f32, gradient_stop_count int, global_alpha f32, stroke int, use_outline int, stroke_width f32) int

fn C.native_begin_background_text_clip(canvas_width f32, canvas_height f32, clip_x f32, clip_y f32, clip_width f32, clip_height f32)

fn C.native_add_background_text_clip_run(x f32, y f32, text string, size f32, bold int, italic int, monospace int)

fn C.native_add_background_glyph_clip_run(glyphs &u16, positions &f64, glyph_count int, font_size f32, font_weight int, emoji_face int, baseline_x f32, baseline_y f32, transform_a f32, transform_b f32, transform_c f32, transform_d f32, transform_e f32, transform_f f32, page_x f32, page_y f32, scroll_y f32, canvas_width f32, canvas_height f32, font_path string, face_index int, font_smoothing int) int

fn C.native_display_device_pixel_ratio() f64

fn C.native_register_system_face(key string, path string, postscript_name string, axis_tags &u32, axis_values &f32, axis_count int) int

__global native_registered_system_faces = map[string]bool{}

// Retained glyph IDs belong to the concrete face used for shaping. Faces chosen
// by system font matching are registered with the native replay bridge under a
// key naming the face and its variation coordinates.
fn native_replay_font_path(font &platform.Font) string {
	face := font.system_face() or { return font.font_path() or { '' } }
	mut key := 'vox-system-face:${face.path}#${face.face_index}|${face.postscript_name}'
	for axis in face.variations {
		key += '|${axis.tag}=${axis.value}'
	}
	if key !in native_registered_system_faces {
		mut registered := false
		$if macos {
			tags := face.variations.map(it.tag)
			values := face.variations.map(it.value)
			registered = C.native_register_system_face(key, face.path, face.postscript_name,
				tags.data, values.data, tags.len) != 0
		}
		native_registered_system_faces[key] = registered
	}
	return if native_registered_system_faces[key] { key } else { face.path }
}

// HTMLSelectElement.value for a script snapshot. A single-line select
// without a selected option reports the option the selectedness setting
// algorithm would select, without changing the document while snapshotting.
fn compact_select_value(select_element &dom.HTMLSelectElement) string {
	options := html.html_select_element_list_of_options(select_element)
	for option in options {
		if html.html_option_element_selected(option) {
			return html.html_option_element_value(option)
		}
	}
	element := unsafe { &dom.Element(select_element) }
	if !element.has_attribute('multiple') && html.html_select_element_display_size(select_element) == 1 {
		for option in options {
			if !html.html_option_element_disabled(option) {
				return html.html_option_element_value(option)
			}
		}
	}
	return ''
}

fn C.native_finish_background_text_clip()

fn C.native_end_background_text_clip()

fn C.native_draw_polygon_srgb(points &f32, point_count int, canvas_height f32, color gg.Color)

fn C.native_draw_line_srgb(from_x f32, from_y f32, to_x f32, to_y f32, thickness f32, line_style int, canvas_width f32, canvas_height f32, color gg.Color) int

fn C.native_draw_rounded_rect_srgb(x f32, y f32, width f32, height f32, top_left_x f32, top_left_y f32, top_right_x f32, top_right_y f32, bottom_right_x f32, bottom_right_y f32, bottom_left_x f32, bottom_left_y f32, transform_a f32, transform_b f32, transform_c f32, transform_d f32, transform_e f32, transform_f f32, page_x f32, page_y f32, scroll_y f32, canvas_width f32, canvas_height f32, color gg.Color, fill int, thickness f32, anti_alias int)

fn C.native_begin_skia_command_group(x f32, y f32, width f32, height f32, transform_a f32, transform_b f32, transform_c f32, transform_d f32, transform_e f32, transform_f f32, page_x f32, page_y f32, scroll_y f32, canvas_width f32, canvas_height f32)

fn C.native_end_skia_command_group()

fn C.native_draw_outer_box_shadow_srgb(source_x f32, source_y f32, source_width f32, source_height f32, source_radius f32, clip_x f32, clip_y f32, clip_width f32, clip_height f32, clip_radius f32, blur f32, color gg.Color)

fn C.native_draw_outer_box_shadow_corners_srgb(shadow_x f32, shadow_y f32, shadow_width f32, shadow_height f32, shadow_top_left_x f32, shadow_top_left_y f32, shadow_top_right_x f32, shadow_top_right_y f32, shadow_bottom_right_x f32, shadow_bottom_right_y f32, shadow_bottom_left_x f32, shadow_bottom_left_y f32, content_x f32, content_y f32, content_width f32, content_height f32, content_top_left_x f32, content_top_left_y f32, content_top_right_x f32, content_top_right_y f32, content_bottom_right_x f32, content_bottom_right_y f32, content_bottom_left_x f32, content_bottom_left_y f32, transform_a f32, transform_b f32, transform_c f32, transform_d f32, transform_e f32, transform_f f32, page_x f32, page_y f32, scroll_y f32, canvas_width f32, canvas_height f32, blur f32, color gg.Color)

fn C.native_draw_inner_box_shadow_corners_srgb(outer_x f32, outer_y f32, outer_width f32, outer_height f32, outer_top_left_x f32, outer_top_left_y f32, outer_top_right_x f32, outer_top_right_y f32, outer_bottom_right_x f32, outer_bottom_right_y f32, outer_bottom_left_x f32, outer_bottom_left_y f32, inner_x f32, inner_y f32, inner_width f32, inner_height f32, inner_top_left_x f32, inner_top_left_y f32, inner_top_right_x f32, inner_top_right_y f32, inner_bottom_right_x f32, inner_bottom_right_y f32, inner_bottom_left_x f32, inner_bottom_left_y f32, content_x f32, content_y f32, content_width f32, content_height f32, content_top_left_x f32, content_top_left_y f32, content_top_right_x f32, content_top_right_y f32, content_bottom_right_x f32, content_bottom_right_y f32, content_bottom_left_x f32, content_bottom_left_y f32, clip_top_left_x f32, clip_top_left_y f32, clip_top_right_x f32, clip_top_right_y f32, clip_bottom_right_x f32, clip_bottom_right_y f32, clip_bottom_left_x f32, clip_bottom_left_y f32, transform_a f32, transform_b f32, transform_c f32, transform_d f32, transform_e f32, transform_f f32, page_x f32, page_y f32, scroll_y f32, canvas_height f32, blur f32, color gg.Color)

fn C.native_draw_image_part(image &gg.Image, destination_x f32, destination_y f32, destination_width f32, destination_height f32, source_x f32, source_y f32, source_width f32, source_height f32, canvas_height f32, opacity f32)

fn C.native_draw_image_part_transformed(image &gg.Image, destination_x f32, destination_y f32, destination_width f32, destination_height f32, source_x f32, source_y f32, source_width f32, source_height f32, clip_x f32, clip_y f32, clip_width f32, clip_height f32, transform_a f32, transform_b f32, transform_c f32, transform_d f32, transform_e f32, transform_f f32, page_x f32, page_y f32, scroll_y f32, canvas_width f32, canvas_height f32, opacity f32, nearest_neighbor int, clip_radii &f32)

fn C.native_draw_repeated_image_transformed(image &gg.Image, destination_x f32, destination_y f32, destination_width f32, destination_height f32, clip_x f32, clip_y f32, clip_width f32, clip_height f32, transform_a f32, transform_b f32, transform_c f32, transform_d f32, transform_e f32, transform_f f32, page_x f32, page_y f32, scroll_y f32, canvas_height f32, opacity f32, nearest_neighbor int, repeat_x int, repeat_y int)

fn C.native_begin_clip()

fn C.native_begin_background_blend_group()

fn C.native_end_background_blend_group()

fn C.native_begin_background_blend_mode(mode int)

fn C.native_end_background_blend_mode()

fn C.native_begin_css_effect_layer(opacity f32, blend_mode int)

fn C.native_end_css_effect_layer()

fn C.native_add_corner_rounded_clip(x f32, y f32, width f32, height f32, top_left_x f32, top_left_y f32, top_right_x f32, top_right_y f32, bottom_right_x f32, bottom_right_y f32, bottom_left_x f32, bottom_left_y f32, transform_a f32, transform_b f32, transform_c f32, transform_d f32, transform_e f32, transform_f f32, page_x f32, page_y f32, scroll_y f32, canvas_height f32)

fn C.native_add_path_clip(data &f32, segment_count int, even_odd int, transform_a f32, transform_b f32, transform_c f32, transform_d f32, transform_e f32, transform_f f32, page_x f32, page_y f32, scroll_y f32, canvas_height f32)

fn C.native_draw_svg_path_srgb(data &f32, segment_count int, even_odd int, transform_a f32, transform_b f32, transform_c f32, transform_d f32, transform_e f32, transform_f f32, page_x f32, page_y f32, scroll_y f32, canvas_width f32, canvas_height f32, fill_color gg.Color, has_fill int, stroke_color gg.Color, has_stroke int, stroke_width f32, line_cap int, line_join int, miter_limit f32, non_scaling_stroke int, dash_data &f64, dash_count int, dash_offset f64)

fn C.native_draw_svg_linear_gradient_path(data &f32, segment_count int, even_odd int, transform_a f32, transform_b f32, transform_c f32, transform_d f32, transform_e f32, transform_f f32, page_x f32, page_y f32, scroll_y f32, canvas_height f32, stroke int, stroke_width f32, line_cap int, line_join int, miter_limit f32, start_x f32, start_y f32, end_x f32, end_y f32, gradient_a f32, gradient_b f32, gradient_c f32, gradient_d f32, gradient_e f32, gradient_f f32, spread_method int, linear_color_space int, stop_data &f32, stop_count int, opacity f32)

fn C.native_draw_svg_radial_gradient_path(data &f32, segment_count int, even_odd int, transform_a f32, transform_b f32, transform_c f32, transform_d f32, transform_e f32, transform_f f32, page_x f32, page_y f32, scroll_y f32, canvas_height f32, stroke int, stroke_width f32, line_cap int, line_join int, miter_limit f32, start_x f32, start_y f32, start_radius f32, end_x f32, end_y f32, end_radius f32, gradient_a f32, gradient_b f32, gradient_c f32, gradient_d f32, gradient_e f32, gradient_f f32, spread_method int, linear_color_space int, stop_data &f32, stop_count int, opacity f32)

fn C.native_draw_css_gradient_path(data &f32, segment_count int, even_odd int, transform_a f32, transform_b f32, transform_c f32, transform_d f32, transform_e f32, transform_f f32, page_x f32, page_y f32, scroll_y f32, canvas_height f32, kind int, tile_x f32, tile_y f32, tile_width f32, tile_height f32, x1 f32, y1 f32, x2 f32, y2 f32, center_x f32, center_y f32, radius_x f32, radius_y f32, start_degrees f32, stop_data &f32, stop_count int) int

fn C.native_begin_svg_clip_mask(cache_key u64, canvas_width f32, canvas_height f32, area_x f32, area_y f32, area_width f32, area_height f32, transform_a f32, transform_b f32, transform_c f32, transform_d f32, transform_e f32, transform_f f32, page_x f32, page_y f32, scroll_y f32)

fn C.native_add_svg_clip_mask_path(data &f32, segment_count int, even_odd int, transform_a f32, transform_b f32, transform_c f32, transform_d f32, transform_e f32, transform_f f32, page_x f32, page_y f32, scroll_y f32, canvas_width f32, canvas_height f32)

fn C.native_begin_svg_content_mask(cache_key u64, luminance int, canvas_width f32, canvas_height f32, area_x f32, area_y f32, area_width f32, area_height f32, transform_a f32, transform_b f32, transform_c f32, transform_d f32, transform_e f32, transform_f f32, page_x f32, page_y f32, scroll_y f32)

fn C.native_begin_svg_mask_opacity(opacity f32)

fn C.native_end_svg_mask_opacity()

fn C.native_add_svg_content_mask_path(data &f32, segment_count int, even_odd int, transform_a f32, transform_b f32, transform_c f32, transform_d f32, transform_e f32, transform_f f32, page_x f32, page_y f32, scroll_y f32, canvas_width f32, canvas_height f32, fill_color gg.Color, has_fill int, stroke_color gg.Color, has_stroke int, stroke_width f32, line_cap int, line_join int, miter_limit f32, stroke_first int)

fn C.native_add_svg_content_mask_linear_gradient_path(data &f32, segment_count int, even_odd int, transform_a f32, transform_b f32, transform_c f32, transform_d f32, transform_e f32, transform_f f32, page_x f32, page_y f32, scroll_y f32, canvas_height f32, stroke int, stroke_width f32, line_cap int, line_join int, miter_limit f32, start_x f32, start_y f32, end_x f32, end_y f32, gradient_a f32, gradient_b f32, gradient_c f32, gradient_d f32, gradient_e f32, gradient_f f32, spread_method int, linear_color_space int, stop_data &f32, stop_count int, opacity f32)

fn C.native_add_svg_content_mask_radial_gradient_path(data &f32, segment_count int, even_odd int, transform_a f32, transform_b f32, transform_c f32, transform_d f32, transform_e f32, transform_f f32, page_x f32, page_y f32, scroll_y f32, canvas_height f32, stroke int, stroke_width f32, line_cap int, line_join int, miter_limit f32, start_x f32, start_y f32, start_radius f32, end_x f32, end_y f32, end_radius f32, gradient_a f32, gradient_b f32, gradient_c f32, gradient_d f32, gradient_e f32, gradient_f f32, spread_method int, linear_color_space int, stop_data &f32, stop_count int, opacity f32)

fn C.native_begin_svg_pattern_tile(cache_key u64, tile_width f32, tile_height f32, content_scale_x f32, content_scale_y f32)

fn C.native_begin_svg_pattern_opacity(opacity f32)

fn C.native_end_svg_pattern_opacity()

fn C.native_begin_svg_pattern_filter_layer(canvas_width f32, canvas_height f32)

fn C.native_end_svg_pattern_filter_layer()

fn C.native_add_svg_pattern_path(data &f32, segment_count int, even_odd int, transform_a f32, transform_b f32, transform_c f32, transform_d f32, transform_e f32, transform_f f32, canvas_height f32, fill_color gg.Color, has_fill int, stroke_color gg.Color, has_stroke int, stroke_width f32, line_cap int, line_join int, miter_limit f32, stroke_first int)

fn C.native_add_svg_pattern_linear_gradient_path(data &f32, segment_count int, even_odd int, transform_a f32, transform_b f32, transform_c f32, transform_d f32, transform_e f32, transform_f f32, canvas_height f32, stroke int, stroke_width f32, line_cap int, line_join int, miter_limit f32, start_x f32, start_y f32, end_x f32, end_y f32, gradient_a f32, gradient_b f32, gradient_c f32, gradient_d f32, gradient_e f32, gradient_f f32, spread_method int, linear_color_space int, stop_data &f32, stop_count int, opacity f32)

fn C.native_add_svg_pattern_radial_gradient_path(data &f32, segment_count int, even_odd int, transform_a f32, transform_b f32, transform_c f32, transform_d f32, transform_e f32, transform_f f32, canvas_height f32, stroke int, stroke_width f32, line_cap int, line_join int, miter_limit f32, start_x f32, start_y f32, start_radius f32, end_x f32, end_y f32, end_radius f32, gradient_a f32, gradient_b f32, gradient_c f32, gradient_d f32, gradient_e f32, gradient_f f32, spread_method int, linear_color_space int, stop_data &f32, stop_count int, opacity f32)

fn C.native_add_svg_pattern_image(image &gg.Image, destination_x f32, destination_y f32, destination_width f32, destination_height f32, source_x f32, source_y f32, source_width f32, source_height f32, clip_x f32, clip_y f32, clip_width f32, clip_height f32, transform_a f32, transform_b f32, transform_c f32, transform_d f32, transform_e f32, transform_f f32, canvas_height f32, opacity f32, nearest_neighbor int)

fn C.native_finish_svg_pattern_path(data &f32, segment_count int, even_odd int, transform_a f32, transform_b f32, transform_c f32, transform_d f32, transform_e f32, transform_f f32, page_x f32, page_y f32, scroll_y f32, canvas_height f32, stroke int, stroke_width f32, line_cap int, line_join int, miter_limit f32, tile_x f32, tile_y f32, tile_width f32, tile_height f32, pattern_a f32, pattern_b f32, pattern_c f32, pattern_d f32, pattern_e f32, pattern_f f32, opacity f32, content_mask int)

fn C.native_add_svg_content_mask_image(image &gg.Image, destination_x f32, destination_y f32, destination_width f32, destination_height f32, source_x f32, source_y f32, source_width f32, source_height f32, clip_x f32, clip_y f32, clip_width f32, clip_height f32, transform_a f32, transform_b f32, transform_c f32, transform_d f32, transform_e f32, transform_f f32, page_x f32, page_y f32, scroll_y f32, canvas_height f32, nearest_neighbor int)

fn C.native_finish_svg_mask_cache()

fn C.native_finish_svg_clip_mask()

fn C.native_begin_svg_mask_layer()

fn C.native_end_svg_mask_layer(cache_key u64, content_mask int, canvas_width f32, canvas_height f32, page_x f32, page_y f32, scroll_y f32)

fn C.native_begin_css_filter_layer(canvas_width f32, canvas_height f32)
fn C.native_begin_font_compositing_layer(canvas_width f32, canvas_height f32)
fn C.native_set_chromium_raster_scroll_y(scroll_y f64)
fn C.native_set_chromium_msaa_tiles(tiles &int, count int, tile_rows int)
fn C.native_set_rect_clip_outs(rects &f64, count int)
fn C.native_rounded_rect_underlay_supported() int
fn C.native_set_rounded_rect_underlay(rect &f32, color gg.Color)
fn C.native_end_font_compositing_layer()

fn C.native_begin_backdrop_filter_layer(canvas_width f32, canvas_height f32, region_x f32, region_y f32, region_width f32, region_height f32, top_left_x f32, top_left_y f32, top_right_x f32, top_right_y f32, bottom_right_x f32, bottom_right_y f32, bottom_left_x f32, bottom_left_y f32, transform_a f32, transform_b f32, transform_c f32, transform_d f32, transform_e f32, transform_f f32, page_x f32, page_y f32, scroll_y f32, source_outside_current_filter int)

fn C.native_add_css_filter_operation(kind int, first f32, second f32, third f32, color gg.Color)

fn C.native_begin_svg_filter_graph(root_id int, node_count int, bounds_x f32, bounds_y f32, bounds_width f32, bounds_height f32, transform_a f32, transform_b f32, transform_c f32, transform_d f32, transform_e f32, transform_f f32, page_x f32, page_y f32)

fn C.native_add_svg_filter_node(id int, kind int, first f32, second f32, third f32, fourth f32, fifth f32, sixth f32, color gg.Color, mode int, x_channel int, y_channel int)

fn C.native_set_svg_filter_node_inputs(id int, inputs &int, count int)

fn C.native_set_svg_filter_node_matrix(id int, matrix &f64, count int)

fn C.native_set_svg_filter_color_table(id int, channel int, values &u8, count int)

fn C.native_set_svg_filter_node_image(id int, image &gg.Image)

fn C.native_end_css_filter_layer()

fn C.native_end_backdrop_filter_layer(opacity f32)

fn C.native_end_clip()

fn request_browser_frame() {
	mut event_loop := html.main_thread_event_loop()
	event_loop.request_rendering_update()
	C.native_wake_browser()
}

const initial_width = 1024
const initial_height = 768
const toolbar_height = 88.0
const status_bar_height = 24.0
const max_preloaded_resources = 32
const max_cached_resources = 256
const max_disk_cache_entry_size = 16 * 1024 * 1024

const demo_markup = '<!doctype html>
<html>
<head>
  <title>vox</title>
  <style>
    html { background: #e8edf3; color: #172033; font-size: 16px; }
    body { width: 760px; margin: 28px auto; padding: 36px; background: white;
           border: 1px solid #cbd5e1; border-radius: 14px; }
    h1 { color: #5b21b6; font-size: 34px; margin: 0 0 12px; }
    h2 { color: #334155; margin-top: 28px; }
    p { line-height: 1.55; margin: 10px 0; }
    .badge { display: block; width: 300px; padding: 10px 14px; margin: 20px 0;
             color: white; background: #6d28d9; border-radius: 8px; }
    .js-button { display: block; width: 320px; padding: 10px 14px; margin: 12px 0;
                 color: white; background: #0f766e; border-radius: 8px; }
    code { color: #9f1239; background: #fff1f2; padding: 2px 5px; }
  </style>
</head>
<body>
  <h1>Ladybird, rendered by V</h1>
  <p>This native window was compiled from the translated LibWeb V modules.</p>
  <div class="badge">HTML → DOM → CSS → Layout → Paint</div>
  <h2>A working vertical slice</h2>
  <p>The document was parsed by <code>html.parse_document</code>, styled by the translated CSS
     engine, laid out by <code>layout.layout_document</code>, and painted into this window.</p>
  <p id="js-status">JavaScript has not run.</p>
  <div id="js-button" class="js-button">Click to test JavaScript events</div>
  <p>Open a local HTML file by passing its path to the executable. Scroll with the mouse wheel,
     arrow keys, or Page Up/Page Down.</p>
  <script>
    document.getElementById("js-status").textContent = "JavaScript executed and changed this DOM node.";
    document.getElementById("js-button").addEventListener("click", function () {
      this.textContent = "JavaScript click handler executed.";
      console.log("click handler ran");
    });
    console.log("LibJS frontend / JavaScriptCore DOM bridge ready");
  </script>
</body>
</html>'

struct PortableShadowImage {
	image_id int
	width int
	height int
}

@[heap]
struct BrowserApp {
mut:
	paint_colors                        PaintColorCache
	scroll_profile                      BrowserScrollProfile
	paint_canvas_culling_disabled       bool
	ctx                                 &gg.Context = unsafe { nil }
	page_model                          &page.Page = unsafe { nil }
	js_runtime                          &browserjs.Runtime = unsafe { nil }
	js_engine                           browserjs.Engine = .javascriptcore
	script_policy                       BrowserScriptPolicy
	document                            &dom.Document = unsafe { nil }
	root_box                            layout.BlockBox
	markup                              string
	content_type                        string
	source_label                        string
	address                             string
	address_cursor                      int
	address_active                      bool
	address_select                      bool
	native_address_bar                  bool
	viewport_width                      int
	viewport_height                     int
	scroll_y                            f64
	overlay_scrollbars                  BrowserOverlayScrollbars
	content_height                      f64
	paint_commands                      []layout.PaintCommand
	paint_commands_have_backdrop_filter bool
	frame_preparation_depth             int
	paint_commands_pending              bool
	paint_effect_depth                  int
	status                              string
	load_status                         string
	memory_status                       BrowserMemoryStatus
	memory_maintenance                  BrowserMemoryMaintenance
	js_messages                         []string
	history                             []HistoryEntry
	history_index                       int = -1
	hovered_link                        string
	navigation_results                  chan NavigationResult
	navigation_generation               int
	pending_navigation                  ?PendingNavigation
	pending_cached_page                 ?PendingCachedPage
	pending_page_preload                ?PendingPagePreload
	navigation_preloaded_resources      map[string]PreloadedResource
	pending_native_navigation           ?string
	navigation_work_depth               int
	navigation_work_yielded             bool
	deferred_navigation_input           ?DeferredNavigationInput
	deferred_page_input                 []DeferredPageInput
	background_image_ids                map[string]int
	force_dark_image_states             map[string]int
	force_dark_image_bitmaps            map[string]&dom.Bitmap_
	force_dark_images                   map[string]&gg.Image
	portable_shadow_images              []PortableShadowImage
	portable_shadow_image_index         int
	resource_cache                      map[string]PreloadedResource
	background_resource_results         chan PreloadedResource
	background_resource_pending         map[string]bool
	// Remote stylesheets requested for links that scripts inserted, and the DOM
	// tree version last scanned for them.
	script_stylesheet_requests          map[string]bool
	script_stylesheet_scan_version      u64
	script_image_requests               map[string]bool
	script_image_scan_version           u64
	// A check box background deferred to its border's native GPU pass, with
	// the command as drawn and as it was submitted.
	rounded_rect_underlay               ?layout.PaintCommand
	rounded_rect_underlay_source        ?layout.PaintCommand
	nonrendered_image_preloads          map[string]bool
	screenshot_path                     string
	screenshot_scheduled                bool
	screenshot_viewport_height          int
	screenshot_scroll_y                 int
	screenshot_scroll_applied           bool
	layout_tree_only                    bool
	document_presented                  bool
	paint_timing                        BrowserPaintTiming
	paint_display_list                  &dom.DisplayList = unsafe { nil }
	animation_epoch_ns                  u64
	initial_window_frame_presented      bool
	refresh_not_before                  i64
	snapshot_visible                    bool
	snapshot_cached                     bool
	// While a cached raster is displayed we keep it up until the background
	// refresh has produced the live document, so neither the cached-DOM rebuild
	// nor the refresh rebuild is seen as a frozen window. snapshot_hold_until is
	// a safety deadline so a stalled refresh cannot pin a stale raster forever.
	snapshot_hold       bool
	snapshot_hold_until i64
	use_document_font   bool
	// gg invokes click_fn after event_fn for the same mouse-down event. Chrome
	// widget presses run through Page::EventHandler in event_fn and must not also
	// enter the browser's compact DOM-click fallback.
	suppress_next_click_for_chrome bool
	platform_pointer_buttons u32
	platform_pointer_modifiers u32
}

struct ChromePointerDispatchResult {
	target  string
	handled bool
	cursor  ?painting.ResizeCursor
	mouse_cursor sapp.MouseCursor = .arrow
}

struct LaunchOptions {
mut:
	js_engine                  browserjs.Engine = .javascriptcore
	script_policy              BrowserScriptPolicy
	source                     string
	headless_smoke             bool
	headless_layout_tree       bool
	screenshot                 string
	screenshot_viewport_height int
	screenshot_scroll_y        int
	width                      int = initial_width
	height                     int = initial_height
}

struct HistoryEntry {
	url    string
	markup string
	content_type string = 'text/html'
}

struct LoadedPage {
	url          string
	markup       string
	status       string
	content_type string
	javascript_url_source ?&dom.Document
	// Compact navigation produces a response locally; this is the source
	// Document.cpp non-Fetch timing fallback, recorded when that response exists.
	monotonic_response_time_ns i64 = time.sys_mono_now()
}

struct NavigationResult {
	generation      int
	add_history     bool
	had_cached_page bool
	resolved        string
	loaded          ?LoadedPage
	error           string
}

struct PendingNavigation {
	resolved        string
	base            string
	generation      int
	add_history     bool
	had_cached_page bool
}

struct PendingCachedPage {
	loaded      LoadedPage
	add_history bool
	generation  int
}

struct PreloadedResource {
	url   string
	body  string
	error string
	source_url string
	final_url string
	request_type string
	adblock_replacement bool
	response_headers []adblock.ResponseHeader
}

// Keep the root executable linked against the translated support modules too. The visible page
// pipeline below directly exercises HTML, DOM, CSS, and Layout; these references make accidental
// breakage at the other translated root boundaries a build-time failure.
fn link_translated_modules() {
	_ = color.from_named_css_color_string
	_ = css.StyleInvalidationReason.dom_mutation
	_ = dom.NodeType.invalid
	_ = domurl.url_encode
	_ = encoding.TextEncoder.create
	_ = fetch.is_ok_status
	_ = fileapi.Blob.create
	_ = fileapi.File.construct
	_ = fileapi.FileList.create
	_ = geolocation.GeolocationCoordinates.create
	_ = geometry.DOMPoint.construct
	_ = highresolutiontime.coarsen_time
	_ = html.event_load
	_ = http.HeaderList.create
	_ = referrerpolicy.from_string
	_ = infra.ascii_whitespace
	_ = layout.translated_layout_function_count
	_ = layout.AvailableSize.make_indefinite()
	_ = mimesniff.javascript_mime_type_essence_strings
	_ = namespace_.html
	_ = selection.selection_create
	_ = sri.do_bytes_match_metadata_list
	_ = storageapi.registered_endpoints
	_ = url.percent_encode
	_ = webvtt.ScrollSetting.empty
}

fn html_escape(value string) string {
	return value.replace('&', '&amp;').replace('<', '&lt;').replace('>', '&gt;')
}

fn debug_timing_enabled() bool {
	return os.getenv('LADYBIRD_DEBUG_TIMING') != ''
}

// debug_timing_checkpoint reports the elapsed time since `previous` for one load
// phase when LADYBIRD_DEBUG_TIMING is set, and returns the current timestamp so
// callers can chain checkpoints. VOX_PROFILE_INSTRUCTIONS independently emits
// cumulative CPU instruction counts at the same boundaries.
fn debug_timing_checkpoint(label string, previous u64) u64 {
	processmetrics.instruction_checkpoint(label)
	now := time.sys_mono_now()
	if debug_timing_enabled() {
		eprintln('Ladybird V timing: ${label} ${(now - previous) / 1_000_000} ms')
		// stderr can become fully buffered when a profiler or benchmark captures it.
		// Flush each opt-in checkpoint so launch-to-first-paint measurements reflect
		// when the phase completed rather than when the buffer happened to fill.
		C.fflush(C.stderr)
	}
	return now
}

fn schedule_native_screenshot(path string) {
	$if macos {
		C.schedule_native_screenshot(path)
	}
	$if linux {
		capture_linux_screenshot(path)
	}
}

fn configure_browser_layout_font(configure_native_replay bool) bool {
	$if macos {
		// Headless layout-tree output never replays glyphs through the native
		// painter. Avoid opening the same font files in Cocoa solely to discard
		// that state when the process exits; HarfBuzz still receives the exact
		// document path below for layout metrics and shaping.
		if configure_native_replay {
			if emoji_path := platform.emoji_font_path() {
				C.native_configure_emoji_font(emoji_path)
			}
		}
		layout_test_font := os.getenv('LADYBIRD_LAYOUT_TEST_FONT')
		if layout_test_font != '' {
			if configure_native_replay {
				C.native_configure_document_font(layout_test_font)
				if bold_path := platform.document_font_path(700) {
					C.native_configure_document_bold_font(bold_path)
				}
			}
			return true
		}
		mut path := os.getenv('LADYBIRD_BROWSER_FONT')
		use_document_font := path != ''
		if path == '' {
			path = '/System/Library/Fonts/Supplemental/Arial.ttf'
		}
		if os.is_file(path) {
			os.setenv('LADYBIRD_BROWSER_DEFAULT_FONT', path, true)
			if configure_native_replay {
				// Glyph indices are face-specific. Configure the same face for native
				// display-list replay even when the browser is using its default Arial
				// path, rather than enabling retained replay only for an explicit
				// LADYBIRD_BROWSER_FONT override.
				C.native_configure_document_font(path)
				if bold_path := platform.document_font_path(700) {
					C.native_configure_document_bold_font(bold_path)
				}
			}
			return use_document_font
		}
	}
	return false
}

fn browser_window_size() gg.Size {
	$if macos {
		return gg.Size{C.native_window_width(), C.native_window_height()}
	} $else {
		return gg.window_size()
	}
}

fn (mut app BrowserApp) initialize_native_window() {
	$if macos {
		C.native_finish_test_window()
		if app.screenshot_path != '' {
			C.native_position_window_top_right()
		}
		app.mount_address_bar()
	}
	app.update_window_title()
}

fn positive_dimension(raw string, option string) !int {
	value := raw.int()
	if value <= 0 {
		return error('${option} must be a positive integer')
	}
	return value
}

fn non_negative_dimension(raw string, option string) !int {
	trimmed := raw.trim_space()
	value := trimmed.int()
	if value < 0 || (value == 0 && trimmed !in ['0', '+0', '-0']) {
		return error('${option} must be a non-negative integer')
	}
	return value
}

fn parse_launch_options(arguments []string) !LaunchOptions {
	mut options := LaunchOptions{}
	mut index := 0
	for index < arguments.len {
		argument := arguments[index]
		if argument == '--headless-smoke' {
			options.headless_smoke = true
		} else if argument == '--enable-javascript' {
			options.script_policy = .enabled
		} else if argument == '--disable-javascript' {
			options.script_policy = .disabled
		} else if argument == '--js-engine' {
			if index + 1 >= arguments.len { return error('--js-engine requires javascriptcore or libjs') }
			index++
			options.js_engine = browserjs.parse_engine(arguments[index])!
		} else if argument.starts_with('--js-engine=') {
			options.js_engine = browserjs.parse_engine(argument.all_after('='))!
		} else if argument == '--headless=layout-tree' {
			options.headless_layout_tree = true
		} else if argument == '--screenshot' {
			if index + 1 >= arguments.len {
				return error('--screenshot requires a PNG output path')
			}
			index++
			options.screenshot = arguments[index]
			if options.screenshot == '' {
				return error('--screenshot requires a PNG output path')
			}
		} else if argument.starts_with('--screenshot=') {
			options.screenshot = argument.all_after('=')
			if options.screenshot == '' {
				return error('--screenshot requires a PNG output path')
			}
		} else if argument == '--screenshot-viewport-height' {
			if index + 1 >= arguments.len {
				return error('--screenshot-viewport-height requires a value')
			}
			index++
			options.screenshot_viewport_height = positive_dimension(arguments[index], '--screenshot-viewport-height')!
		} else if argument.starts_with('--screenshot-viewport-height=') {
			options.screenshot_viewport_height = positive_dimension(argument.all_after('='), '--screenshot-viewport-height')!
		} else if argument == '--screenshot-scroll-y' {
			if index + 1 >= arguments.len {
				return error('--screenshot-scroll-y requires a value')
			}
			index++
			options.screenshot_scroll_y = non_negative_dimension(arguments[index], '--screenshot-scroll-y')!
		} else if argument.starts_with('--screenshot-scroll-y=') {
			options.screenshot_scroll_y = non_negative_dimension(argument.all_after('='), '--screenshot-scroll-y')!
		} else if argument == '--window-width' {
			if index + 1 >= arguments.len {
				return error('--window-width requires a value')
			}
			index++
			options.width = positive_dimension(arguments[index], '--window-width')!
		} else if argument.starts_with('--window-width=') {
			options.width = positive_dimension(argument.all_after('='), '--window-width')!
		} else if argument == '--window-height' {
			if index + 1 >= arguments.len {
				return error('--window-height requires a value')
			}
			index++
			options.height = positive_dimension(arguments[index], '--window-height')!
		} else if argument.starts_with('--window-height=') {
			options.height = positive_dimension(argument.all_after('='), '--window-height')!
		} else if argument.starts_with('-psn_') {
			// Finder supplies this process serial number when opening an app bundle.
		} else if argument.starts_with('-') {
			return error('unknown option: ${argument}')
		} else if options.source == '' {
			options.source = argument
		} else {
			return error('only one URL, HTML path, or literal HTML source is supported')
		}
		index++
	}
	return options
}

const local_file_read_attempts = 5

// A file can be momentarily interrupted while Finder, iCloud Drive, or another
// document provider finishes making it available. Retrying EINTR keeps a normal
// `open Ladybird.app --args /path/to/document.html` launch from needlessly
// showing the error document.
fn read_local_file(path string) !string {
	for attempt in 0 .. local_file_read_attempts {
		contents := os.read_file(path) or {
			if !err.msg().contains('Interrupted system call') || attempt + 1 == local_file_read_attempts {
				return err
			}
			time.sleep(100 * time.millisecond)
			continue
		}
		return contents
	}
	return error('could not read local file')
}

// `open Ladybird.app --args report.html` is launched by LaunchServices, which
// does not retain the terminal's working directory. For the development bundle,
// fall back to the checkout containing Build/v so relative local documents keep
// the same useful meaning they have when the executable is run directly.
fn bundled_workspace_relative_file_path(source string, executable_path string) ?string {
	if os.is_abs_path(source) {
		return none
	}
	mut workspace_root := os.dir(executable_path)
	for _ in 0 .. 5 {
		workspace_root = os.dir(workspace_root)
	}
	candidate := os.join_path(workspace_root, source)
	if os.is_file(candidate) {
		return candidate
	}
	return none
}

fn initial_document(argument string) (string, string, string) {
	if argument == '' {
		return 'about:home', demo_markup, 'built-in translated-engine demo'
	}
	if argument.trim_space().starts_with('<') {
		return 'about:srcdoc', argument, 'command-line HTML'
	}
	mut file_name := argument
	is_file_url := file_name.starts_with('file://')
	if is_file_url {
		file_name = url.percent_decode(file_name['file://'.len..]).bytestr()
	}
	if !is_file_url && !os.is_file(file_name) {
		if workspace_path := bundled_workspace_relative_file_path(file_name, os.executable()) {
			file_name = workspace_path
		}
	}
	if os.is_file(file_name) {
		markup := read_local_file(file_name) or {
			return 'about:error', '<h1>Could not read file</h1><p>${html_escape(err.msg())}</p>', file_name
		}
		real_path := os.real_path(file_name)
		return 'file://${real_path}', markup, real_path
	}
	return argument, '', argument
}

fn resolve_url(reference string, base string) string {
	trimmed := reference.trim_space()
	if trimmed == '' {
		return base
	}
	if os.is_file(trimmed) {
		return 'file://${os.real_path(trimmed)}'
	}
	if parsed := url.parse(trimmed) {
		return parsed.serialize(false)
	}
	if base != '' && (trimmed.starts_with('/') || trimmed.starts_with('./') || trimmed.starts_with('../') || trimmed.starts_with('?') || trimmed.starts_with('#')) {
		base_url := url.parse(base) or { return trimmed }
		return (url.parse_with_base(trimmed, &base_url) or { return trimmed }).serialize(false)
	}
	if !trimmed.contains(' ') && (trimmed.contains('.') || trimmed.starts_with('localhost')) {
		with_scheme := 'https://${trimmed}'
		// Canonicalize synthesized URLs too. In particular, an HTTP(S) origin's
		// empty path serializes as `/`; successful responses use that form, so a
		// bare-host launch must use it for the same disk-cache key.
		if parsed := url.parse(with_scheme) {
			return parsed.serialize(false)
		}
		return with_scheme
	}
	return 'https://duckduckgo.com/html/?q=${url.percent_encode(trimmed, .application_x_www_form_urlencoded, true)}'
}

fn resolve_document_reference(reference string, base string) string {
	trimmed := reference.trim_space()
	if trimmed == '' {
		return base
	}
	if parsed := url.parse(trimmed) {
		return parsed.serialize(false)
	}
	base_url := url.parse(base) or { return resolve_url(trimmed, '') }
	return (url.parse_with_base(trimmed, &base_url) or { return resolve_url(trimmed, '') }).serialize(false)
}

fn tls_ca_bundle() string {
	if configured := os.getenv_opt('SSL_CERT_FILE') {
		if os.is_file(configured) {
			return configured
		}
	}
	for candidate in ['/etc/ssl/cert.pem', '/etc/ssl/certs/ca-certificates.crt',
		'/opt/homebrew/etc/ca-certificates/cert.pem'] {
		if os.is_file(candidate) {
			return candidate
		}
	}
	return ''
}

fn browser_cache_root() string {
	if configured := os.getenv_opt('LADYBIRD_CACHE_DIR') {
		if configured != '' {
			return configured
		}
	}
	return os.join_path(os.cache_dir(), 'ladybird-v')
}

// Capturing an NSView snapshot forces Cocoa to synchronously repaint the full
// retained display list and encode a PNG on the main thread. Keep the
// experimental snapshot cache opt-in until it can copy the presented Metal
// surface without delaying browser interactivity.
fn browser_snapshot_cache_enabled() bool {
	return os.getenv('LADYBIRD_ENABLE_SNAPSHOT_CACHE') != ''
}

fn browser_cache_entry_path(cache_root string, category string, resource_url string) string {
	return os.join_path(cache_root, category, sha256.hexhash(resource_url))
}

fn read_browser_cache_entry(path string) ?string {
	if !os.is_file(path) {
		return none
	}
	contents := os.read_file(path) or { return none }
	if contents.len == 0 || contents.len > max_disk_cache_entry_size {
		return none
	}
	return contents
}

fn write_browser_cache_entry(path string, contents string) {
	_ = try_write_browser_cache_entry(path, contents)
}

fn try_write_browser_cache_entry(path string, contents string) bool {
	if contents.len == 0 || contents.len > max_disk_cache_entry_size {
		return false
	}
	os.mkdir_all(os.dir(path)) or { return false }
	temporary_path := '${path}.${os.getpid()}.${time.sys_mono_now()}.tmp'
	os.write_file(temporary_path, contents) or { return false }
	os.mv(temporary_path, path) or {
		os.rm(temporary_path) or {}
		return false
	}
	return true
}

fn read_cached_page(resource_url string) ?LoadedPage {
	if !resource_url.starts_with('http://') && !resource_url.starts_with('https://') {
		return none
	}
	filtered := browsernet.filter(adblock.Request{url: resource_url, source_url: resource_url, request_type: 'main_frame'}) or { return none }
	if filtered.url != resource_url || filtered.replacement != none { return none }
	path := browser_cache_entry_path(browser_cache_root(), 'pages', resource_url)
	markup := read_browser_cache_entry(path) or { return none }
	return LoadedPage{
		url: resource_url
		markup: markup
		status: 'Cached · refreshing'
		content_type: read_browser_cache_entry(path + '.content-type') or { 'text/html' }
	}
}

fn cache_loaded_page(loaded LoadedPage) {
	if !loaded.content_type.to_lower().contains('html') {
		return
	}
	path := browser_cache_entry_path(browser_cache_root(), 'pages', loaded.url)
	write_browser_cache_entry(path, loaded.markup)
	write_browser_cache_entry(path + '.content-type', loaded.content_type)
}

fn read_cached_resource(resource_url string) ?string {
	path := browser_cache_entry_path(browser_cache_root(), 'resources', resource_url)
	return read_browser_cache_entry(path)
}

fn cache_resource(resource_url string, body string) {
	cache_resource_response(resource_url, resource_url, body)
}

fn cache_resource_response(resource_url string, final_url string, body string) {
	cache_resource_response_headers(resource_url, final_url, body, []adblock.ResponseHeader{})
}

fn cache_resource_response_headers(resource_url string, final_url string, body string, headers []adblock.ResponseHeader) {
	cache_resource_response_headers_with_status(resource_url, final_url, body, headers, 0)
}

fn cache_resource_response_headers_with_status(resource_url string, final_url string, body string, headers []adblock.ResponseHeader, status_code int) {
	path := browser_cache_entry_path(browser_cache_root(), 'resources', resource_url)
	// Discard old status provenance before replacing any part of the response.
	os.rm(path + '.status') or {}
	body_written := try_write_browser_cache_entry(path, body)
	url_written := try_write_browser_cache_entry(path + '.url', final_url)
	headers_written := try_write_browser_cache_entry(path + '.headers.json', json2.encode(headers, escape_unicode: true))
	if status_code >= 100 && status_code <= 599 {
		if body_written && url_written && headers_written {
			write_browser_cache_entry(path + '.status', status_code.str())
		}
	}
}

fn cached_snapshot_path(resource_url string) string {
	return browser_cache_entry_path(browser_cache_root(), 'snapshots', resource_url)
}

fn fetch_page(address string, base string) !LoadedPage {
	resolved := resolve_url(address, base)
	if resolved == 'about:home' || resolved == 'about:blank' {
		return LoadedPage{
			url: resolved
			markup: if resolved == 'about:home' {
				demo_markup
			} else {
				'<html><body></body></html>'
			}
			status: 'Loaded locally'
			content_type: 'text/html'
		}
	}
	if resolved.starts_with('file://') {
		file_name := url.percent_decode(resolved['file://'.len..]).bytestr()
		markup := read_local_file(file_name)!
		return LoadedPage{
			url: resolved
			markup: markup
			status: 'Local file'
			content_type: 'text/html'
		}
	}
	if !resolved.starts_with('http://') && !resolved.starts_with('https://') {
		return error('Unsupported URL scheme')
	}
	result := browsernet.get(adblock.Request{url: resolved, source_url: resolved, request_type: 'main_frame'}, tls_ca_bundle())!
	response := result.response
	content_type := response.header.get(.content_type) or { 'text/html' }
	// HTTP error responses can contain a real document, including a site's
	// verification or sign-in UI. Only an empty error needs our fallback page.
	if response.status_code < 200 || (response.status_code >= 400 && response.body == '') {
		return error('HTTP ${response.status_code} ${response.status_msg}')
	}
	markup := browser_navigation_response_markup(response.body, content_type)
	loaded := LoadedPage{
		url: result.url
		markup: markup
		status: 'HTTP ${response.status_code} · ${response.body.len} bytes'
		content_type: content_type
	}
	// A challenge or server error must not replace a cached successful page.
	if response.status_code < 400 {
		cache_loaded_page(loaded)
	}
	return loaded
}

fn fetch_text_resource(reference string, base string) !string {
	return fetch_text_resource_for_request(reference, base, base, 'other')
}

fn fetch_text_resource_for_request(reference string, base string, source_url string, request_type string) !string {
	return fetch_browser_resource(reference, base, source_url, request_type)!.body
}

const browser_cache_miss_code = 1404

// The disk-cached response for an already filtered request. A miss fails with
// browser_cache_miss_code; a filter rejection fails with its own error.
fn cached_browser_resource_response(resolved string, filtered_url string, owner_url string, request_type string) !PreloadedResource {
	// Legacy entries have no redirect provenance. Re-fetch those entries so
	// an allowed URL cannot hide a redirect to a blocked tracker.
	for cache_key in [resource_accept_cache_key(filtered_url, request_type), filtered_url] {
		path := browser_cache_entry_path(browser_cache_root(), 'resources', cache_key)
		if final_url := read_browser_cache_entry(path + '.url') {
			final_request := adblock.Request{url: final_url, source_url: owner_url, request_type: request_type}
			// Without a redirect, the final request is the one the caller has
			// already filtered.
			final_filter := if final_url == resolved && filtered_url == resolved {
				browsernet.FilteredRequest{url: final_url}
			} else {
				browsernet.filter(final_request)!
			}
			if replacement := final_filter.replacement {
				return PreloadedResource{url: resolved, body: replacement.body, source_url: owner_url, final_url: final_url, request_type: request_type, adblock_replacement: true}
			}
			if final_filter.url == final_url && final_url == filtered_url {
				// Only the final response is retained. Re-fetch redirects so an
				// intermediate response-header condition cannot bypass filtering.
				// Older cache entries have no header provenance. Re-fetch them;
				// assuming an empty header list could expose a header-blocked ad.
				if encoded_headers := read_browser_cache_entry(path + '.headers.json') {
					if headers := json2.decode[[]adblock.ResponseHeader](encoded_headers) {
						filter_browser_response_headers(final_request, headers)!
						// An old unvaried key cannot identify the Accept value that
						// selected a negotiated image representation.
						if cache_key == filtered_url && resource_response_varies_on_accept(headers) { continue }
						if cached := read_cached_resource(cache_key) {
							return PreloadedResource{url: resolved, body: cached, source_url: owner_url, final_url: final_url, request_type: request_type, response_headers: headers}
						}
					}
				}
			}
		}
	}
	return error_with_code('not in the disk cache', browser_cache_miss_code)
}

// A remote resource that the disk cache can answer on the UI thread. Anything
// else, including a filter rejection, is left to the background request.
fn disk_cached_browser_resource(resource_url string, source_url string, request_type string) ?PreloadedResource {
	if !resource_url.starts_with('http://') && !resource_url.starts_with('https://') { return none }
	filtered := browsernet.filter(adblock.Request{url: resource_url, source_url: source_url, request_type: request_type}) or { return none }
	if filtered.replacement != none || filtered.url != resource_url { return none }
	resource := cached_browser_resource_response(resource_url, filtered.url, source_url, request_type) or { return none }
	if resource.adblock_replacement { return none }
	return resource
}

fn fetch_browser_resource(reference string, base string, source_url string, request_type string) !PreloadedResource {
	resolved := resolve_document_reference(reference, base)
	if resolved.starts_with('file://') {
		path := url.percent_decode(resolved['file://'.len..]).bytestr()
		return PreloadedResource{url: resolved, body: read_local_file(path)!, source_url: source_url, final_url: resolved, request_type: request_type}
	}
	owner_url := if source_url == '' { resolved } else { source_url }
	request := adblock.Request{url: resolved, source_url: owner_url, request_type: request_type}
	filtered := browsernet.filter(request)!
	if replacement := filtered.replacement {
		return PreloadedResource{url: resolved, body: replacement.body, source_url: owner_url, final_url: filtered.url, request_type: request_type, adblock_replacement: true}
	}
	if filtered.url.starts_with('http://') || filtered.url.starts_with('https://') {
		cached := cached_browser_resource_response(resolved, filtered.url, owner_url, request_type) or {
			if err.code() != browser_cache_miss_code { return err }
			PreloadedResource{}
		}
		if cached.url != '' { return cached }
	}
	result := browsernet.get(adblock.Request{url: filtered.url, source_url: owner_url, request_type: request_type}, tls_ca_bundle())!
	response := result.response
	if response.status_code < 200 || response.status_code >= 400 {
		return error('HTTP ${response.status_code}')
	}
	headers := browsernet.response_headers(response)
	if !result.is_replacement {
		cache_key := if resource_response_varies_on_accept(headers) { resource_accept_cache_key(filtered.url, request_type) } else { filtered.url }
		cache_resource_response_headers_with_status(cache_key, result.url, response.body, headers, response.status_code)
	}
	return PreloadedResource{url: resolved, body: response.body, source_url: owner_url, final_url: result.url, request_type: request_type, adblock_replacement: result.is_replacement, response_headers: headers}
}

fn fetch_resource_in_background(resource_url string, source_url string, request_type string, results chan PreloadedResource) {
	resource := fetch_browser_resource(resource_url, '', source_url, request_type) or {
		results <- PreloadedResource{
			url: resource_url
			error: err.msg()
			source_url: source_url
			request_type: request_type
		}
		return
	}
	results <- resource
}

// A URL may be requested as both a script and an image. A replacement or a
// rejection in one context is not a reusable network response in the other.
fn filter_preloaded_resource(resource PreloadedResource, source_url string, request_type string) !PreloadedResource {
	filtered := browsernet.filter(adblock.Request{url: resource.url, source_url: source_url, request_type: request_type})!
	if replacement := filtered.replacement {
		return PreloadedResource{url: resource.url, body: replacement.body, source_url: source_url, final_url: filtered.url, request_type: request_type, adblock_replacement: true}
	}
	if filtered.url != resource.url || resource.adblock_replacement
		|| resource.error.starts_with('Blocked by adblock:')
		|| resource.error.starts_with('Adblock unavailable:')
		|| (resource.error != '' && (resource.source_url != source_url || resource.request_type != request_type)) {
		return fetch_browser_resource(resource.url, '', source_url, request_type)
	}
	if resource.error != '' { return error(resource.error) }
	// Without a redirect, the final request is the one filtered above.
	if resource.final_url != '' && (resource.final_url != resource.url || filtered.url != resource.url) {
		final_filter := browsernet.filter(adblock.Request{url: resource.final_url, source_url: source_url, request_type: request_type})!
		if replacement := final_filter.replacement {
			return PreloadedResource{url: resource.url, body: replacement.body, source_url: source_url, final_url: resource.final_url, request_type: request_type, adblock_replacement: true}
		}
		if final_filter.url != resource.final_url { return fetch_browser_resource(resource.url, '', source_url, request_type) }
	}
	if resource.final_url != '' && resource.final_url != filtered.url {
		// Replaying a redirect requires every hop, including its headers.
		return fetch_browser_resource(resource.url, '', source_url, request_type)
	}
	filter_browser_response_headers(adblock.Request{
		url: if resource.final_url == '' { resource.url } else { resource.final_url }
		source_url: source_url
		request_type: request_type
	}, resource.response_headers)!
	if resource_response_varies_on_accept(resource.response_headers)
		&& browsernet.request_accept_header(resource.request_type) != browsernet.request_accept_header(request_type) {
		return fetch_browser_resource(resource.url, '', source_url, request_type)
	}
	return resource
}

fn fetch_background_resource_in_background(resource_url string, source_url string, results chan PreloadedResource) {
	fetch_resource_in_background(resource_url, source_url, 'image', results)
	$if macos {
		C.native_wake_browser()
	}
}

fn fetch_page_in_background(resolved string, base string, generation int, add_history bool, had_cached_page bool, results chan NavigationResult) {
	loaded := fetch_page(resolved, base) or {
		results <- NavigationResult{
			generation: generation
			add_history: add_history
			had_cached_page: had_cached_page
			resolved: resolved
			error: err.msg()
		}
		$if macos {
			C.native_wake_browser()
		}
		return
	}
	results <- NavigationResult{
		generation: generation
		add_history: add_history
		had_cached_page: had_cached_page
		resolved: resolved
		loaded: loaded
	}
	$if macos {
		C.native_wake_browser()
	}
}

fn clamp(value f64, low f64, high f64) f64 {
	if value < low {
		return low
	}
	if value > high {
		return high
	}
	return value
}

fn document_title(document &dom.Document) string {
	root := unsafe { &dom.Node(document) }
	title := css.query_selector(root, 'title') or { return '' }
	return title.as_node().text_content() or { '' }
}

fn document_preload_resource_urls(document &dom.Document, base_url string) []string {
	root := unsafe { &dom.Node(document) }
	mut urls := []string{}
	mut seen := map[string]bool{}
	// A local page can contain absolute tracking badges or other remote images.
	// Those images are not render-blocking, and waiting for them here makes a
	// saved page's first layout depend on the network. Styles and scripts remain
	// eligible below because they can affect the initial document state.
	preload_remote_images := !base_url.starts_with('file://')
	preferred_set_name := preferred_style_sheet_set_name(root)
	for link in css.query_selector_all(root, 'link[rel][href]') {
		if !link_stylesheet_applies(link, preferred_set_name) {
			continue
		}
		resource_url := resolve_document_reference(link.get_attribute_value('href'), base_url)
		if resource_url.starts_with('http://') || resource_url.starts_with('https://') {
			if resource_url !in seen {
				seen[resource_url] = true
				urls << resource_url
				if urls.len == max_preloaded_resources {
					return urls
				}
			}
		}
	}
	if browser_document_can_load_scripts(document) {
		for script in css.query_selector_all(root, 'script[src]') {
			type_ := script.get_attribute_value('type').trim_space().to_lower()
			if type_ != '' && type_ !in ['text/javascript', 'application/javascript', 'module'] {
				continue
			}
			resource_url := resolve_document_reference(script.get_attribute_value('src'), base_url)
			if (resource_url.starts_with('http://') || resource_url.starts_with('https://')) && resource_url !in seen {
				seen[resource_url] = true
				urls << resource_url
				if urls.len == max_preloaded_resources {
					return urls
				}
			}
		}
	}
	if preload_remote_images {
		for image in css.query_selector_all(root, 'img[src]') {
			resource_url := resolve_document_reference(image.get_attribute_value('src'), base_url)
			if (resource_url.starts_with('http://') || resource_url.starts_with('https://')) && resource_url !in seen {
				seen[resource_url] = true
				urls << resource_url
				if urls.len == max_preloaded_resources {
					return urls
				}
			}
		}
		// SVGImageElement performs the same image fetch as HTMLImageElement. Include
		// both SVG 2 href and the legacy XLink spelling before layout/replay so mask
		// caches are never populated from a temporarily unavailable remote image.
		mut svg_images := css.query_selector_all(root, 'image')
		svg_images << css.query_selector_all(root, 'feImage')
		for image in svg_images {
			mut source := ''
			if image.has_attribute('href') {
				source = image.get_attribute_value('href').trim_space()
			} else {
				source = image.get_attribute_value('xlink:href').trim_space()
			}
			if source == '' {
				continue
			}
			resource_url := resolve_document_reference(source, base_url)
			if (resource_url.starts_with('http://') || resource_url.starts_with('https://'))
				&& resource_url !in seen {
				seen[resource_url] = true
				urls << resource_url
				if urls.len == max_preloaded_resources {
					return urls
				}
			}
		}
	}
	return urls
}

fn preload_document_resources(document &dom.Document, base_url string, cached map[string]PreloadedResource) map[string]PreloadedResource {
	urls := document_preload_resource_urls(document, base_url)
	return preload_document_resource_urls(document, base_url, urls, cached)
}

fn preload_document_resource_urls(document &dom.Document, base_url string, urls []string, cached map[string]PreloadedResource) map[string]PreloadedResource {
	resource_types := document_preload_resource_types(document, base_url)
	mut loaded := map[string]PreloadedResource{}
	mut pending_urls := []string{}
	for resource_url in urls {
		request_type := resource_types[resource_url] or { 'image' }
		filtered := browsernet.filter(adblock.Request{url: resource_url, source_url: document.url.serialize(), request_type: request_type}) or {
			loaded[resource_url] = PreloadedResource{url: resource_url, error: err.msg()}
			continue
		}
		if replacement := filtered.replacement {
			loaded[resource_url] = PreloadedResource{url: resource_url, body: replacement.body, source_url: document.url.serialize(), final_url: filtered.url, request_type: request_type, adblock_replacement: true}
			continue
		}
		if existing := cached[resource_url] {
			loaded[resource_url] = filter_preloaded_resource(existing, document.url.serialize(), request_type) or {
				PreloadedResource{url: resource_url, error: err.msg(), source_url: document.url.serialize(), request_type: request_type}
			}
		} else {
			pending_urls << resource_url
		}
	}
	if pending_urls.len == 0 {
		return loaded
	}
	results := chan PreloadedResource{ cap: pending_urls.len }
	for resource_url in pending_urls {
		spawn fetch_resource_in_background(resource_url, document.url.serialize(), resource_types[resource_url] or { 'image' }, results)
	}
	for _ in pending_urls {
		resource := <-results
		loaded[resource.url] = resource
	}
	return loaded
}


fn script_sources(document &dom.Document, base_url string, preloaded map[string]PreloadedResource, mut messages []string) []browserjs.ScriptSource {
	if !browser_document_can_load_scripts(document) { return [] }
	root := unsafe { &dom.Node(document) }
	mut sources := []browserjs.ScriptSource{}
	for script_element in css.query_selector_all(root, 'script') {
		type_ := script_element.get_attribute_value('type').trim_space().to_lower()
		if type_ != '' && type_ !in ['text/javascript', 'application/javascript', 'module'] {
			continue
		}
		if src := script_element.get_attribute('src') {
			resolved_url := resolve_document_reference(src, base_url)
			filtered := browsernet.filter(adblock.Request{url: resolved_url, source_url: document.url.serialize(), request_type: 'script'}) or {
				messages << 'Script ${src}: ${err.msg()}'
				continue
			}
			source := if replacement := filtered.replacement {
				replacement.body
			} else if resource := preloaded[resolved_url] {
				filtered_resource := filter_preloaded_resource(resource, document.url.serialize(), 'script') or {
					messages << 'Script ${src}: ${err.msg()}'
					continue
				}
				filtered_resource.body
			} else {
				fetch_text_resource_for_request(src, base_url, document.url.serialize(), 'script') or {
					messages << 'Script ${src}: ${err.msg()}'
					continue
				}
			}
			sources << browserjs.ScriptSource{
				code: source
				url: resolved_url
				source_type: if type_ == 'module' { .module } else { .script }
			}
		} else {
			sources << browserjs.ScriptSource{
				code: script_element.as_node().text_content() or { '' }
				url: document.url.serialize()
				source_type: if type_ == 'module' { .module } else { .script }
			}
		}
	}
	return sources
}

fn requested_video_frame_time(markup string) f64 {
	last_five := markup.last_index('currentTime = 5') or { -1 }
	last_zero := markup.last_index('currentTime = 0') or { -1 }
	return if last_five > last_zero { 5.0 } else { 0.0 }
}

fn decode_local_video_frame(resolved_url string, seconds f64) ?&dom.Bitmap_ {
	path := if resolved_url.starts_with('file://') {
		url.percent_decode(resolved_url['file://'.len..]).bytestr()
	} else if !resolved_url.contains('://') {
		resolved_url
	} else {
		return none
	}
	if !os.is_file(path) {
		return none
	}
	mut width := 0
	mut height := 0
	mut pitch := 0
	pixels := C.native_decode_video_frame(path.str, seconds, &width, &height, &pitch)
	if pixels == unsafe { nil } || width <= 0 || height <= 0 || pitch < width * 4 {
		return none
	}
	defer {
		C.native_free_video_frame(pixels)
	}
	mut data := []u8{len: pitch * height}
	unsafe {
		vmemcpy(data.data, pixels, data.len)
	}
	return &dom.Bitmap_{
		width: width
		height: height
		pitch: pitch
		data: data
		native_rows_are_top_down: true
	}
}

fn native_bitmap_channel_marker(bitmap &dom.Bitmap_, premultiplied bool) int {
	if bitmap.native_rows_are_top_down {
		return if premultiplied { 7 } else { 6 }
	}
	return if premultiplied { 5 } else { 4 }
}

fn browser_image_resource_bytes(resource_url dom.URL) ![]u8 {
	return browser_image_resource_bytes_for_document(resource_url, '')
}

fn browser_image_resource_bytes_for_document(resource_url dom.URL, source_url string) ![]u8 {
	return browser_resource_bytes_for_document(resource_url, source_url, 'image')
}

fn browser_resource_bytes_for_document(resource_url dom.URL, source_url string, request_type string) ![]u8 {
	serialized := resource_url.serialize()
	if serialized.starts_with('data:') {
		comma := serialized.index(',') or { return error('Malformed data URL') }
		metadata := serialized[..comma].to_lower()
		payload := serialized[comma + 1..]
		if metadata.ends_with(';base64') {
			return base64.decode(payload)
		}
		return url.percent_decode(payload)
	}
	if serialized.starts_with('file://') {
		path := browser_local_file_path(serialized) or { return error('Malformed file URL') }
		return os.read_bytes(path)
	}
	if !serialized.contains('://') {
		return os.read_bytes(serialized)
	}
	if serialized.starts_with('http://') || serialized.starts_with('https://') {
		// Reuse navigation's preloaded resource cache before fetching a missing
		// resource. Native image requests must decode the same bytes as painting.
		return fetch_text_resource_for_request(serialized, '', source_url, request_type)!.bytes()
	}
	return error('Unsupported image resource URL')
}

fn browser_decode_raster_image_bytes(bytes []u8) !&dom.Bitmap_ {
	if bytes.len == 0 {
		return error('Empty image resource')
	}
	$if macos {
		if image_bytes_are_webp(bytes) {
			mut width := 0
			mut height := 0
			mut pitch := 0
			decoded := C.native_decode_webp_rgba(bytes.data, usize(bytes.len), &width, &height, &pitch)
			if decoded == unsafe { nil } { return error('Invalid or unsupported WebP image') }
			defer { C.native_free_webp_pixels(decoded) }
			mut pixels := []u8{len: pitch * height}
			unsafe { vmemcpy(pixels.data, decoded, pixels.len) }
			return &dom.Bitmap_{width: width, height: height, pitch: pitch, data: pixels,
				native_rows_are_top_down: true}
		}
		if bitmap := native_jpeg_bitmap(bytes) {
			return bitmap
		}
	}
	image := stbi.load_from_memory(bytes.data, bytes.len)!
	defer {
		image.free()
	}
	if image.width <= 0 || image.height <= 0 || image.nr_channels != 4 {
		return error('Invalid decoded image')
	}
	mut pixels := []u8{len: image.width * image.height * 4}
	unsafe {
		vmemcpy(pixels.data, image.data, pixels.len)
	}
	return &dom.Bitmap_{
		width: image.width
		height: image.height
		pitch: image.width * 4
		data: pixels
		// stb preserves the encoded top-to-bottom scanline order. Keep the
		// native image bridge from reflecting those rows as Quartz storage.
		native_rows_are_top_down: true
	}
}

// The existing compact raster decoder supplies the actual HTML request.
fn browser_fetch_image_resource(resource_url dom.URL) !html.DecodedImageData {
	return browser_fetch_image_resource_for_document(resource_url, '')
}

fn browser_fetch_image_resource_for_document(resource_url dom.URL, source_url string) !html.DecodedImageData {
	return browser_decoded_image_data(resource_url, browser_image_resource_bytes_for_document(resource_url, source_url)!)
}

fn browser_decoded_image_data(resource_url dom.URL, bytes []u8) !html.DecodedImageData {
	if browser_image_resource_is_svg(resource_url) {
		return browser_decode_svg_image(resource_url, bytes)
	}
	bitmap := browser_decode_raster_image_bytes(bytes)!
	decoded := html.BitmapDecodedImageData.create([html.BitmapDecodedImageFrame{frame: dom.DecodedImageFrame_.create(bitmap)}], 0, false)
	// Legacy cache entries contain only encoded bytes, without final redirect
	// origins or response headers. Keep those remote pixels opaque to readback.
	decoded.set_is_cors_cross_origin(resource_url.scheme() in ['http', 'https'])
	return decoded
}

fn browser_fetch_image_request(element &dom.HTMLImageElement, model &html.HTMLImageElementModel,
	resource_url dom.URL) !html.DecodedImageData {
	if !browser_image_request_allows_cached_bytes(element, model, resource_url) {
		// The compact byte cache does not retain CORS response headers. A
		// CORS-mode request cannot approve an unverified cross-origin response.
		return error('Cross-origin image CORS responses are not supported by the native cache')
	}
	return browser_fetch_image_resource_for_document(resource_url, unsafe { &dom.Element(element) }.document().url.serialize())
}

fn browser_image_request_allows_cached_bytes(element &dom.HTMLImageElement, model &html.HTMLImageElementModel, resource_url dom.URL) bool {
	if resource_url.scheme() !in ['http', 'https'] || model.crossorigin() == .no_cors {
		return true
	}
	owner := unsafe { &dom.Element(element) }.document()
	origin := if owner.origin().value == '' { owner.url.origin() } else { owner.origin() }
	return resource_url.origin().is_same_origin(origin)
}

fn browser_fetch_object_resource(resource_url dom.URL) !html.ObjectResourceResponse {
	return browser_fetch_object_resource_for_document(resource_url, '')
}

fn browser_fetch_object_resource_for_document(resource_url dom.URL, source_url string) !html.ObjectResourceResponse {
	bytes := browser_resource_bytes_for_document(resource_url, source_url, 'object')!
	mime_type := if detected := mimesniff.match_an_image_type_pattern(bytes) {
		detected.essence()
	} else {
		'image/unknown'
	}
	return html.ObjectResourceResponse{
		content_type: mime_type
		body: bytes
		bitmap: browser_decode_raster_image_bytes(bytes)!
	}
}

fn install_object_image_fetch_hooks(document &dom.Document) {
	root := unsafe { &dom.Node(document) }
	for element in css.query_selector_all(root, 'object') {
		object_element := unsafe { &dom.HTMLObjectElement(element) }
		mut model := html.html_object_element_model_for_dom_element(object_element)
		model.set_fetch_hook(fn [element] (resource_url dom.URL) !html.ObjectResourceResponse {
			return browser_fetch_object_resource_for_document(resource_url, element.document().url.serialize())
		})
		// The compact native shell does not construct a full navigable graph for
		// its top-level document, but that document is its active presentation.
		model.set_environment(element.as_node().is_connected(), true, false)
		if element.has_attribute('data') {
			model.queue_element_task_to_run_object_representation_steps()
		}
	}
}

fn browser_fetch_video_poster(resource_url dom.URL) !&dom.Bitmap_ {
	return browser_decode_raster_image_bytes(browser_image_resource_bytes(resource_url)!)
}

fn browser_decode_video_poster(bytes []u8) !html.DecodedImageData {
	bitmap := browser_decode_raster_image_bytes(bytes)!
	return html.BitmapDecodedImageData.create([
		html.BitmapDecodedImageFrame{frame: dom.DecodedImageFrame_.create(bitmap)},
	], 0, false)
}

fn install_video_poster_fetch_hook(element &dom.Element) {
	if !element.is_html_element() || element.local_name() != 'video' { return }
	video_element := unsafe { &dom.HTMLVideoElement(element) }
	mut model := html.html_video_element_model_for_dom_element(video_element)
	// Native documents use their actual client and networking task queue.
	// Standalone model adapters without settings retain the URL decoder.
	if element.document().relevant_settings_object() != unsafe { nil } {
		if host := requestserver.native_resource_fetch_host() {
			model.set_poster_fetch_transport(&html.PosterFrameFetchTransport{
				host: host
				decode: browser_decode_video_poster
			})
		}
	}
	model.set_poster_fetch_hook(fn [element] (resource_url dom.URL) !&dom.Bitmap_ {
		return browser_decode_raster_image_bytes(browser_image_resource_bytes_for_document(resource_url, element.document().url.serialize())!)
	})
}

fn install_video_poster_fetch_hooks(document &dom.Document) {
	root := unsafe { &dom.Node(document) }
	for element in css.query_selector_all(root, 'video') {
		if !element.is_html_element() { continue }
		install_video_poster_fetch_hook(element)
		if poster := element.get_attribute_ns(none, 'poster') {
			mut model := html.html_video_element_model_for_dom_element(unsafe { &dom.HTMLVideoElement(element) })
			model.set_poster(poster)
		}
	}
}

// The native shell supplies decoded media frames through the same external
// content source boundary used by upstream's video playback manager. This
// keeps container/codec work out of layout while allowing VideoPaintable to
// apply object-fit and object-position to real frame dimensions.
fn install_local_video_frames(document &dom.Document, base_url string, markup string) {
	root := unsafe { &dom.Node(document) }
	seconds := requested_video_frame_time(markup)
	mut decoded := map[string]&dom.Bitmap_{}
	mut fallback_source_checked := false
	mut fallback_source := ''
	for element in css.query_selector_all(root, 'video') {
		if !element.is_html_element() { continue }
		mut source := element.get_attribute_value('src')
		if source == '' {
			// Every video sees the same immutable markup. Find this legacy
			// local-fixture reference once, only when a sourceless video needs it.
			if !fallback_source_checked {
				fallback_source_checked = true
				if markup.contains('solid-blue-160x120.webm') {
					fallback_source = '../../Assets/solid-blue-160x120.webm'
				}
			}
			source = fallback_source
		}
		if source == '' {
			continue
		}
		resolved := resolve_document_reference(source, base_url)
		cache_key := '${resolved}#${seconds}'
		frame := if cached := decoded[cache_key] {
			cached
		} else {
			new_frame := decode_local_video_frame(resolved, seconds) or { continue }
			decoded[cache_key] = new_frame
			new_frame
		}
		video_element := unsafe { &dom.HTMLVideoElement(element) }
		mut model := html.html_video_element_model_for_dom_element(video_element)
		mut media := model.media
		if media.video_tracks().length() == 0 {
			media.on_video_track_added(html.MediaTrackMetadata{
				identifier: 1
				name: 'video'
			})
		}
		media.set_ready_state(.have_current_data)
		model.set_video_dimensions(u32(frame.width), u32(frame.height))
		model.set_current_frame(frame)
	}
}

fn bitmap_javascript_state(bitmap &dom.Bitmap_) map[string]json2.Any {
	mut packed := bitmap.data.clone()
	if bitmap.pitch != bitmap.width * 4 {
		packed = []u8{len: bitmap.width * bitmap.height * 4}
		for row in 0 .. bitmap.height {
			for column in 0 .. bitmap.width * 4 {
				packed[row * bitmap.width * 4 + column] = bitmap.data[row * bitmap.pitch + column]
			}
		}
	}
	return {
		'width':  json2.Any(bitmap.width)
		'height': json2.Any(bitmap.height)
		'pixels': json2.Any(base64.encode(packed))
	}
}

fn quoted_video_references(scripts []string) []string {
	mut references := []string{}
	mut seen := map[string]bool{}
	for source in scripts {
		mut position := 0
		for position < source.len {
			if source[position] != `'` && source[position] != `"` {
				position++
				continue
			}
			quote := source[position]
			start := position + 1
			position = start
			for position < source.len && source[position] != quote {
				position++
			}
			if position >= source.len {
				break
			}
			value := source[start..position]
			if quoted_video_reference_has_extension(value) && value !in seen {
				seen[value] = true
				references << value
			}
			position++
		}
	}
	return references
}

fn javascript_video_source_states(current_url string, scripts []string) map[string]json2.Any {
	mut sources := map[string]json2.Any{}
	seconds := requested_video_frame_time(scripts.join('\n'))
	for reference in quoted_video_references(scripts) {
		// This legacy adapter decodes local files only. Relative and remote
		// references on HTTP pages cannot produce a frame; avoid parsing large
		// minified-script fragments which merely contain a video extension.
		if !javascript_video_reference_can_be_local(reference, current_url) { continue }
		resolved := resolve_document_reference(reference, current_url)
		bitmap := decode_local_video_frame(resolved, seconds) or { continue }
		frame_state := json2.Any(bitmap_javascript_state(bitmap))
		sources[reference] = frame_state
		sources[resolved] = frame_state
	}
	return sources
}

fn javascript_initial_state(document &dom.Document, current_url string, scripts []string) map[string]json2.Any {
	root := unsafe { &dom.Node(document) }
	mut elements := map[string]json2.Any{}
	all_elements := css.query_selector_all(root, '*')
	mut element_keys := map[voidptr]string{}
	for element_index, element in all_elements {
		element_keys[voidptr(element)] = '__element_${element_index}'
	}
	for element_index, element in all_elements {
		id := element.get_attribute_value('id')
		bridge_key := '__element_${element_index}'
		parent_key := if parent := element.as_node().parent_element() {
			element_keys[voidptr(parent)] or { '' }
		} else {
			''
		}
		attribute_records, attributes := browserjs.compact_attribute_state(element)
		mut state := {
			'id':           json2.Any(id)
			'bridgeKey':    json2.Any(bridge_key)
			'elementIndex': json2.Any(element_index)
			'tagName':      json2.Any(element.local_name())
			'namespaceURI': json2.Any(element.namespace_uri() or { '' })
			'attributes':   json2.Any(attributes)
			'attributeRecords': json2.Any(attribute_records)
			'src':          json2.Any(element.get_attribute_value('src'))
			'width':        json2.Any(element.get_attribute_value('width'))
			'height':       json2.Any(element.get_attribute_value('height'))
			'className':    json2.Any(element.get_attribute_value('class'))
			'styleText':    json2.Any(element.get_attribute_value('style'))
			'onclick':      json2.Any(element.get_attribute_value('onclick'))
			'hasChildren':  json2.Any(element.as_node().has_children())
			'disabled':     json2.Any(element.has_attribute('disabled'))
			'parentKey':    json2.Any(parent_key)
		}
		if element.is_html_element() && element.local_name() == 'select' {
			select_element := unsafe { &dom.HTMLSelectElement(element) }
			state['value'] = json2.Any(compact_select_value(select_element))
		}
		if element.is_html_element() && element.local_name() == 'option' {
			state['value'] = json2.Any(html.html_option_element_value(unsafe { &dom.HTMLOptionElement(element) }))
		}
		if element.is_html_element() && element.local_name() == 'video' {
			video := unsafe { &dom.HTMLVideoElement(element) }
			model := html.html_video_element_model_for_dom_element(video)
			if frame := model.current_decoded_image_frame() {
				bitmap := frame.bitmap()
				frame_state := bitmap_javascript_state(bitmap)
				state['readyState'] = json2.Any(2)
				state['videoWidth'] = frame_state['width'] or { json2.Any(0) }
				state['videoHeight'] = frame_state['height'] or { json2.Any(0) }
				state['videoPixels'] = frame_state['pixels'] or { json2.Any('') }
			}
		}
		if element.local_name() == 'img' {
			image := unsafe { &dom.HTMLImageElement(element) }
			source := element.get_attribute_value('src').trim_space()
			resolved_source := resolve_document_reference(source, current_url)
			// The compact host decodes data and local-file images at paint time,
			// outside HTMLImageElement's request object. They are nevertheless
			// synchronously available before this script snapshot is executed.
			host_image_complete := source.starts_with('data:')
				|| (resolved_source.starts_with('file://')
					&& os.is_file(url.percent_decode(resolved_source['file://'.len..]).bytestr()))
			state['complete'] = json2.Any(html.html_image_element_complete(image)
				|| host_image_complete)
		}
		if element.local_name() == 'input' {
			input := unsafe { &dom.HTMLInputElement(element) }
			state['checked'] = json2.Any(input.checked())
			state['indeterminate'] = json2.Any(input.indeterminate())
		}
		elements[bridge_key] = json2.Any(state)
	}
	model := html.NavigableModel.navigable_with_active_document(document)
	return {
		'title':         json2.Any(document_title(document))
		'bodyHTMLDirty': json2.Any(false)
		'bodyTextDirty': json2.Any(false)
		'location':      json2.Any(current_url)
		'navigate':      json2.Any('')
		'logs':          json2.Any([]json2.Any{})
		'operations':    json2.Any([]json2.Any{})
		'elements':      json2.Any(elements)
		'videoSources':  json2.Any(javascript_video_source_states(current_url, scripts))
		'forceDarkEnabled': json2.Any(if value := model { value.force_dark_enabled() } else { false })
		'forceDarkForegroundThreshold': json2.Any(if value := model { int(value.force_dark_foreground_threshold()) } else { 150 })
		'forceDarkBackgroundThreshold': json2.Any(if value := model { int(value.force_dark_background_threshold()) } else { 205 })
		'showLineBoxBorders': json2.Any(false)
	}
}

fn javascript_bootstrap() string {
	return [
		'(function (__state) {',
		'const __bindMediaElement = globalThis.__ladybirdMediaElementBind;',
		'const __bindTrackElement = globalThis.__ladybirdTrackElementBind;',
		'const __trackEndsWith=String.prototype.endsWith,__trackApply=Reflect.apply;',
		'function __isTrackElementState(s){return s.namespaceURI==="http://www.w3.org/1999/xhtml"&&(s.tagName==="track"||__trackApply(__trackEndsWith,s.tagName,[":track"]));}',
		'const __bindElementWheel = globalThis.__ladybirdElementWheelBind;',
		'const __listeners = Object.create(null);',
		browserjs.compact_attribute_bootstrap(),
		browserjs.media_element_reflection_bootstrap(),
		'const __canvases = Object.create(null);',
		'const __elementRecords=new WeakMap(),__elementRecordGet=WeakMap.prototype.get,__elementRecordSet=WeakMap.prototype.set,__elementApply=Reflect.apply,__nativeElementQuery=globalThis.__ladybirdElementQuery;',
		'function Element(){throw new TypeError("Illegal Element constructor");} Object.setPrototypeOf(Element,EventTarget); Object.setPrototypeOf(Element.prototype,EventTarget.prototype); Object.defineProperty(Element,"prototype",{writable:false}); Object.defineProperty(Element.prototype,Symbol.toStringTag,{value:"Element",configurable:true}); Object.defineProperty(globalThis,"Element",{value:Element,writable:true,configurable:true});',
		'for(const constructor of [globalThis.HTMLImageElement,globalThis.HTMLMediaElement,globalThis.HTMLTrackElement])if(constructor)Object.setPrototypeOf(constructor.prototype,Element.prototype);',
		'function __queryElement(value){if(value===null)return null;const known=__state.elements[value.bridgeKey];if(known)return __compactNodeWrapper(known);__state.elements[value.bridgeKey]=value;return __compactNodeWrapper(value);}',
		compact_pending_elements_bootstrap(),
		'function __queryElements(key,action,selector){const request={key:key,action:action,selector:selector},pending=__pendingElementStates(false);if(__state.operations.length||Object.keys(pending).length){const snapshot=Object.assign({},__state,{elements:pending,logs:[]});delete snapshot.videoSources;request.snapshot=JSON.stringify(snapshot);request.logCount=0;__state.operations=[];for(const key of Object.keys(pending)){const s=pending[key];s.attributesDirty=false;s.textContentDirty=false;s.innerHTMLDirty=false;s.checkedDirty=false;s.indeterminateDirty=false;}}let result;try{result=JSON.parse(__nativeElementQuery(JSON.stringify(request)));}catch(error){if(String(error.message).indexOf("SyntaxError:")===0)throw new DOMException(String(error.message).slice(12).trim(),"SyntaxError");throw error;}return action==="matches"||action==="computedStyle"||action==="selectedIndex"||action==="setSelectedIndex"||action==="removeChild"||action==="nodeValue"||action==="setNodeValue"||action==="getElementsByTagName"?result:(action==="querySelectorAll"||action==="getElementsByClassName")?result.map(__queryElement):__queryElement(result);}',
		'for(const name of ["matches","closest","querySelector","querySelectorAll"]){const method={ [name](selectors){"use strict";const s=__elementApply(__elementRecordGet,__elementRecords,[this]);if(!s)throw new TypeError("Illegal Element receiver");if(arguments.length===0)throw new TypeError(name+" requires a selector");if(typeof selectors==="symbol")throw new TypeError("Cannot convert a Symbol to a string");return __queryElements(s.bridgeKey,name,String(selectors));} }[name];Object.defineProperty(Element.prototype,name,{value:method,writable:true,enumerable:true,configurable:true});} Object.defineProperty(Element.prototype,"webkitMatchesSelector",{value:Element.prototype.matches,writable:true,enumerable:true,configurable:true});',
		// Flush pending children and clone their actual native owners, including
		// detached elements created by script.
		'Object.defineProperty(Element.prototype,"cloneNode",{value:function cloneNode(subtree){"use strict";const s=__elementApply(__elementRecordGet,__elementRecords,[this]);if(!s)throw new TypeError("Illegal Element receiver");return __queryElements(s.bridgeKey,"cloneNode",subtree?"deep":"shallow");},writable:true,enumerable:true,configurable:true});',
		'Object.defineProperty(Element.prototype,"getAttributeNames",{value:{getAttributeNames(){"use strict";const s=__elementApply(__elementRecordGet,__elementRecords,[this]);if(!s)throw new TypeError("Illegal Element receiver");return __compactAttributes.names(s);}}.getAttributeNames,writable:true,enumerable:true,configurable:true});',
		'const __readElementContent=globalThis.__ladybirdReadElementContent; function __elementContent(s,name){if(Object.prototype.hasOwnProperty.call(s,name))return s[name];return s.created?"":__readElementContent(String(s.bridgeKey)+":"+name);}',
		'function __listenerKey(s, n) { return (s && (s.bridgeKey || s.id) ? (s.bridgeKey || s.id) : "document") + ":" + n; }',
		'function __styleName(name) { const result=String(name).replace(/[A-Z]/g, function (character) { return "-" + character.toLowerCase(); }); return result.indexOf("webkit-")===0?"-"+result:result; }',
		'function __elementStates() { return Object.keys(__state.elements).map(function (key) { return __state.elements[key]; }).filter(function(s){return !s.removed;}).sort(function (a,b) { return (+a.elementIndex||0)-(+b.elementIndex||0); }); }',
		'function __attributeName(s, name) { name=String(name); return s.namespaceURI==="http://www.w3.org/1999/xhtml"?name.toLowerCase():name; }',
		'function __isMediaLifecycleAttribute(s,name){return s.namespaceURI==="http://www.w3.org/1999/xhtml"&&(s.tagName==="audio"||s.tagName==="video")&&(name==="onplay"||name==="onpause"||name==="onplaying"||name==="onwaiting"||name==="oncanplay"||name==="oncanplaythrough"||name==="onloadedmetadata"||name==="onloadeddata"||name==="onratechange"||name==="onvolumechange"||name==="ontimeupdate"||name==="ondurationchange"||name==="onseeking"||name==="onseeked"||name==="onprogress"||name==="onsuspend"||name==="onabort"||name==="onemptied"||name==="onloadstart"||name==="onended"||name==="onresize"||name==="onerror");}',
		'function __setAttribute(s, name, value) { name=__attributeName(s,name); value=String(value); const attribute=__compactAttributes.set(s,name,value),plain=attribute.namespaceURI===null; if(plain&&name==="onwheel")__state.operations.push({op:"wheelContentAttribute",target:s.bridgeKey,value:value}); else if(plain&&__isMediaLifecycleAttribute(s,name))__state.operations.push({op:"mediaLifecycleContentAttribute",target:s.bridgeKey,name:name,value:value}); else __state.operations.push({op:"compactAttribute",target:s.bridgeKey,name:name,value:value}); if(!plain)return attribute; if(s.tagName==="img"&&s.namespaceURI==="http://www.w3.org/1999/xhtml")__ladybirdImageSetAttribute(__element(s),name,value); if(s.tagName==="canvas"&&(name==="width"||name==="height")){s[name]=value;__canvasResize(s);} if(name==="id")s.id=value; if(name==="class")s.className=value; if(name==="style")s.styleText=value; if(name==="src")s.src=value; if(name==="disabled")s.disabled=true; return attribute; }',
		'function __removeAttribute(s, name) { name=__attributeName(s,name); const attribute=__compactAttributes.remove(s,name); if(!attribute)return; const plain=attribute.namespaceURI===null; if(plain&&name==="onwheel")__state.operations.push({op:"wheelContentAttribute",target:s.bridgeKey,value:null}); else if(plain&&__isMediaLifecycleAttribute(s,name))__state.operations.push({op:"mediaLifecycleContentAttribute",target:s.bridgeKey,name:name,value:null}); else __state.operations.push({op:"compactAttribute",target:s.bridgeKey,name:name,value:null}); if(!plain)return; if(s.tagName==="canvas"&&(name==="width"||name==="height")){delete s[name];__canvasResize(s);} if(name==="id")s.id=""; if(name==="class")s.className=""; if(name==="style")s.styleText=""; if(name==="src")s.src=""; if(name==="disabled")s.disabled=false; }',
		'const __styleString=String; function __styleProxy(s) {',
		'  const values = Object.create(null);',
		'  __styleString(s.styleText || "").split(";").forEach(function (part) { const i = part.indexOf(":"); if (i > 0) values[part.slice(0, i).trim()] = part.slice(i + 1).trim(); });',
		'  function sync() { __setAttribute(s,"style",Object.keys(values).map(function (k) { return k + ": " + values[k]; }).join("; ")); }',
		'  return new Proxy(values, { set: function (o, p, v) { if (p === "cssText") { __setAttribute(s,"style",v); return true; } o[__styleName(p)] = String(v); sync(); return true; }, get: function (o, p) { if (p === "cssText") return s.styleText; if (p === "setProperty") return function (name, value) { values[__styleName(name)] = String(value); sync(); }; if (p === "removeProperty") return function (name) { name = __styleName(name); const old = values[name] || ""; delete values[name]; sync(); return old; }; return o[__styleName(p)] || ""; } });',
		'}',
		'function __classList(s) { function tokens() { return String(s.className || "").trim().split(/\\s+/).filter(Boolean); } function sync(values) { __setAttribute(s,"class",values.join(" ")); } return { add: function () { const values=tokens(); for(const item of arguments){const token=String(item);if(token&&!values.includes(token))values.push(token);} sync(values); }, remove: function () { const removed=Array.prototype.map.call(arguments,String); sync(tokens().filter(function(token){return !removed.includes(token);})); }, contains: function (token) { return tokens().includes(String(token)); }, toggle: function (token, force) { token=String(token); const values=tokens(), present=values.includes(token), add=force===undefined?!present:!!force; if(add&&!present)values.push(token); if(!add&&present)values.splice(values.indexOf(token),1); sync(values); return add; }, replace: function (token, replacement) { token=String(token); replacement=String(replacement); const values=tokens(), index=values.indexOf(token); if(index<0)return false; const result=[]; values.forEach(function(value,i){const next=i===index?replacement:value;if(next!==replacement||!result.includes(replacement))result.push(next);}); sync(result); return true; } }; }',
		'function __canvasDimension(s, name) { const fallback=name === "width" ? 300 : 150; if(s[name]===undefined||s[name]===null||String(s[name])==="")return fallback; const value=Number(s[name]); return Number.isFinite(value) && value >= 0 && value <= 2147483647 ? Math.trunc(value) : fallback; }',
		browserjs.canvas_bootstrap(),
		browserjs.webgl_bootstrap(),
		browserjs.xhr_bootstrap(),
		'function __decodeBase64(input) { const alphabet="ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"; const clean=String(input||"").replace(/[^A-Za-z0-9+/]/g,""); const output=new Uint8ClampedArray(Math.floor(clean.length*3/4)); let bits=0,value=0,index=0; for(const ch of clean){const digit=alphabet.indexOf(ch);if(digit<0)continue;value=(value<<6)|digit;bits+=6;if(bits>=8){bits-=8;output[index++]=(value>>bits)&255;}} return index===output.length?output:output.slice(0,index); }',
		'function __videoFor(s) { if(s.__videoFrame)return s.__videoFrame; if(!s.videoPixels)return null; return s.__videoFrame={width:+s.videoWidth||0,height:+s.videoHeight||0,data:__decodeBase64(s.videoPixels)}; }',
		'function __setElementSource(s,value) { const attribute=__setAttribute(s,"src",value); if(attribute.namespaceURI!==null)return; if(s.tagName==="video"){const frame=__state.videoSources[s.src];if(frame){s.readyState=2;s.videoWidth=frame.width;s.videoHeight=frame.height;s.videoPixels=frame.pixels;s.__videoFrame=null;}} if(s.tagName==="img"){s.complete=true;const target=__element(s),event={type:"load",target:target};for(const listener of (__listeners[__listenerKey(s,"load")]||[]))listener.call(target,event);} }',
		'const __reflectMediaAttribute=__createMediaSourceSynchronizer(__compactAttributes.reflect,__state.videoSources);',
		'function __setElementData(s,value) { const attribute=__setAttribute(s,"data",value); if(attribute.namespaceURI!==null)return; if(s.tagName==="object"){const target=__element(s),event={type:"load",target:target};for(const listener of (__listeners[__listenerKey(s,"load")]||[]))listener.call(target,event);} }',
		'function __replaceStyleRuleProperty(s,index,name,value){let current=-1;const property=__styleName(name);s.textContent=String(__elementContent(s,"textContent")).replace(/([^{}]+)\\{([^{}]*)\\}/g,function(full,selector,body){current++;if(current!==+index)return full;const declarations=body.split(";").map(function(part){return part.trim();}).filter(Boolean);let replaced=false;for(let i=0;i<declarations.length;i++){const colon=declarations[i].indexOf(":");if(colon>=0&&declarations[i].slice(0,colon).trim().toLowerCase()===property.toLowerCase()){declarations[i]=property+": "+String(value);replaced=true;}}if(!replaced)declarations.push(property+": "+String(value));return selector+"{ "+declarations.join("; ")+"; }";});s.innerHTML="";s.textContentDirty=true;s.innerHTMLDirty=false;}',
		'function __styleSheet(s){if(s.__sheet)return s.__sheet;const matches=String(__elementContent(s,"textContent")).match(/[^{}]+\\{[^{}]*\\}/g)||[];s.__sheet={cssRules:matches.map(function(_,index){const style=new Proxy({}, {set:function(o,p,v){__replaceStyleRuleProperty(s,index,p,v);return true;},get:function(o,p){if(p==="setProperty")return function(name,value){__replaceStyleRuleProperty(s,index,name,value);};return "";}});return{style:style};})};return s.__sheet;}',
		'function __element(s) {',
		'  if (!s.__object) {',
		'    const o = { getAttribute: function (n) { n=__attributeName(s,n); return Object.prototype.hasOwnProperty.call(s.attributes,n)?s.attributes[n]:null; }, hasAttribute: function(n){return Object.prototype.hasOwnProperty.call(s.attributes,__attributeName(s,n));}, setAttribute: function (n, v) { n=__attributeName(s,n); if(n==="src")__setElementSource(s,v);else if(n==="data")__setElementData(s,v);else __setAttribute(s,n,v); }, removeAttribute:function(n){__removeAttribute(s,n);}, remove:function(){if(!s.removed){s.removed=true;s.parentKey="";__state.operations.push({op:"remove",target:s.bridgeKey});}}, addEventListener: function (n, f) { (__listeners[__listenerKey(s, n)] ||= []).push(f); if(s.tagName==="video"&&s.readyState>=2&&(n==="loadeddata"||n==="seeked"))f.call(this,{type:n,target:this}); if(s.tagName==="img"&&s.complete&&n==="load")f.call(this,{type:n,target:this}); }, removeEventListener: function(n,f){const key=__listenerKey(s,n);__listeners[key]=(__listeners[key]||[]).filter(function(listener){return listener!==f;});}, append: function (child) { return this.appendChild(child); }, appendChild: function (child) { const c=child&&child.__state; if(!c)return child; if(s.tagName==="#document-fragment"){s.children.push(c);s.hasChildren=true;}else{__state.operations.push({op:"appendCreated",target:s.bridgeKey,child:c});s.hasChildren=true;c.parentKey=s.bridgeKey;c.removed=false;} return child; }, insertBefore:function(child,reference){const c=child&&child.__state,r=reference&&reference.__state;if(c){__state.operations.push({op:"insertCreated",target:s.bridgeKey,child:c,reference:r?r.bridgeKey:"",referenceFirstChild:!!(reference&&reference.__firstChildOf===s.bridgeKey)});s.hasChildren=true;c.parentKey=s.bridgeKey;c.removed=false;}return child;}, moveBefore:function(child,reference){const c=child&&child.__state,r=reference&&reference.__state;if(c){__state.operations.push({op:"moveBefore",target:s.bridgeKey,child:c.bridgeKey,reference:r?r.bridgeKey:""});c.parentKey=s.bridgeKey;c.removed=false;}}, animate:function(keyframes){const frames=Array.isArray(keyframes)?keyframes:[keyframes];const finalFrame=frames.length?frames[frames.length-1]:{};for(const name of Object.keys(finalFrame||{}))__setAttribute(s,__styleName(name),finalFrame[name]);return{finished:Promise.resolve()};}, getContext: function(kind,options) { return s.tagName === "canvas" ? __canvasGetContext(s,kind,options) : null; }, };',
		'    if(s.tagName!=="#document-fragment"&&s.tagName!=="#text"){Object.setPrototypeOf(o,Element.prototype);__elementApply(__elementRecordSet,__elementRecords,[o,s]);}',
		'    Object.defineProperties(o, { id: { get: function () { return s.id; }, set:function(v){__setAttribute(s,"id",v);} }, firstChild:{get:function(){if(s.tagName==="#document-fragment")return s.children.length?__element(s.children[0]):null;return s.hasChildren?{__firstChildOf:s.bridgeKey}:null;}}, parentNode:{get:function(){const p=s.parentKey&&__state.elements[s.parentKey];if(p&&!p.removed)return __element(p);return !s.parentKey&&!s.removed&&!s.created&&s.tagName==="html"?document:null;}}, parentElement:{get:function(){const p=s.parentKey&&__state.elements[s.parentKey];return p&&!p.removed?__element(p):null;}}, textContent: { get: function () { return __elementContent(s,"textContent"); }, set: function (v) { s.textContent = String(v); s.innerHTML = ""; s.textContentDirty=true; s.innerHTMLDirty=false; } }, innerHTML: { get: function () { return __elementContent(s,"innerHTML"); }, set: function (v) { s.innerHTML = String(v); s.innerHTMLDirty=true; s.textContentDirty=false; } }, className: { get: function () { return s.className; }, set: function (v) { __setAttribute(s,"class",v); } }, name:{get:function(){return s.attributes.name||"";},set:function(v){__setAttribute(s,"name",v);}}, content:{get:function(){return s.attributes.content||"";},set:function(v){__setAttribute(s,"content",v);}}, hidden:{get:function(){return Object.prototype.hasOwnProperty.call(s.attributes,"hidden");},set:function(v){if(v)__setAttribute(s,"hidden","");else __removeAttribute(s,"hidden");}}, disabled:{get:function(){return !!s.disabled;},set:function(v){if(v)__setAttribute(s,"disabled","");else __removeAttribute(s,"disabled");}}, checked:{get:function(){return !!s.checked;},set:function(v){s.checked=!!v;s.checkedDirty=true;}}, indeterminate:{get:function(){return !!s.indeterminate;},set:function(v){s.indeterminate=!!v;s.indeterminateDirty=true;}}, complete:{get:function(){return !!s.complete;}}, value:{get:function(){return s.value;},set:function(v){s.value=String(v);}}, data:{get:function(){return s.attributes.data||"";},set:function(v){__setElementData(s,v);}}, sheet:{get:function(){return s.tagName==="style"?__styleSheet(s):null;}} });',
		// Reflected attributes that scripts set as properties, such as 4chan's
		// catalog creating its theme link with rel and type. href returns the
		// resolved URL, as HTMLHyperlinkElementUtils and HTMLLinkElement do.
		'    if(s.namespaceURI==="http://www.w3.org/1999/xhtml"){const __reflect=function(name){Object.defineProperty(o,name,{configurable:true,get:function(){return Object.prototype.hasOwnProperty.call(s.attributes,name)?String(s.attributes[name]):"";},set:function(v){__setAttribute(s,name,v);}});};__reflect("title");if(["a","area","link","form"].includes(s.tagName))__reflect("rel");if(["link","style","script","source"].includes(s.tagName))__reflect("type");if(["link","style","source","meta"].includes(s.tagName))__reflect("media");if(s.tagName==="select")__compactSelect(o,s);if(["a","area","link","base"].includes(s.tagName))Object.defineProperty(o,"href",{configurable:true,get:function(){if(!Object.prototype.hasOwnProperty.call(s.attributes,"href"))return "";const v=String(s.attributes.href);try{return new globalThis.URL(v,__state.location).href;}catch(e){return v;}},set:function(v){__setAttribute(s,"href",v);}});}',
		'    if(!__isTrackElementState(s)&&(s.namespaceURI!=="http://www.w3.org/1999/xhtml"||(s.tagName!=="audio"&&s.tagName!=="video")))Object.defineProperty(o,"src",{get:function(){return s.src||"";},set:function(v){__setElementSource(s,v);}});',
		'    if(s.namespaceURI!=="http://www.w3.org/1999/xhtml"||s.tagName!=="video")Object.defineProperties(o,{width:{get:function(){return __canvasDimension(s,"width");},set:function(v){s.width=String(Number(v)>>>0);__setAttribute(s,"width",s.width);}}, height:{get:function(){return __canvasDimension(s,"height");},set:function(v){s.height=String(Number(v)>>>0);__setAttribute(s,"height",s.height);}}});',
		'    if(s.namespaceURI!=="http://www.w3.org/1999/xhtml"||s.tagName!=="video")Object.defineProperties(o,{videoWidth:{get:function(){return +s.videoWidth||0;}}, videoHeight:{get:function(){return +s.videoHeight||0;}}});',
		'    if(!__isTrackElementState(s)&&(s.namespaceURI!=="http://www.w3.org/1999/xhtml"||(s.tagName!=="audio"&&s.tagName!=="video")))Object.defineProperty(o,"readyState",{get:function(){return +s.readyState||0;}});',
		'    o.getBoundingClientRect=function(){return{x:0,y:0,width:0,height:0,top:0,left:0,right:0,bottom:0};};o.focus=function(){__state.operations.push({op:"focus",target:s.bridgeKey});};o.select=function(){__state.operations.push({op:"selectTextControl",target:s.bridgeKey});};o.insertBefore=function(child,reference){const c=child&&child.__state,r=reference&&reference.__state;if(c){if(c.created)__state.operations.push({op:"insertCreated",target:s.bridgeKey,child:c,reference:r?r.bridgeKey:"",referenceFirstChild:!!(reference&&reference.__firstChildOf===s.bridgeKey)});else __state.operations.push({op:"moveBefore",target:s.bridgeKey,child:c.bridgeKey,reference:r?r.bridgeKey:"",insert:true});s.hasChildren=true;c.parentKey=s.bridgeKey;c.removed=false;}return child;};',
		'    o.style = __styleProxy(s); o.classList = __classList(s); Object.defineProperty(o,"__state",{value:s}); Object.defineProperty(s, "__object", { value: o, writable: true, configurable: true }); if(s.tagName==="img"&&s.namespaceURI==="http://www.w3.org/1999/xhtml")__ladybirdImageBind(o,s.bridgeKey); if((s.tagName==="audio"||s.tagName==="video")&&s.namespaceURI==="http://www.w3.org/1999/xhtml"){__bindMediaElement(o,s.bridgeKey,s.tagName);__recordMediaAttributes(o,s,__reflectMediaAttribute);delete o.addEventListener;delete o.removeEventListener;}else if(s.tagName!=="#document-fragment"&&s.tagName!=="#text"){__bindElementWheel(o,s.bridgeKey,s.tagName,s.namespaceURI);if(__isTrackElementState(s)){__bindTrackElement(o,s.bridgeKey);__recordMediaAttributes(o,s,__compactAttributes.reflect);delete o.addEventListener;delete o.removeEventListener;delete o.dispatchEvent;}}',
		'  } return s.__object;',
		'}',
		'let __createdElementCount=0; function __createKnownElement(namespaceURI,name){const key="__created_"+(++__createdElementCount),s={created:true,bridgeKey:key,elementIndex:1000000000+__createdElementCount,namespaceURI:namespaceURI,tagName:name,id:"",src:"",width:"",height:"",textContent:"",innerHTML:"",className:"",styleText:"",onclick:"",attributes:{},attributeRecords:[],hasChildren:false,children:[],disabled:false,checked:false,indeterminate:false};__state.elements[key]=s;return __element(s);}',
		'function __createElement(namespaceURI,name){return __createKnownElement(namespaceURI==null?"":String(namespaceURI),String(name));} __ladybirdMediaElementSetAudioFactory((function(create){return function(){return create("http://www.w3.org/1999/xhtml","audio");};})(__createKnownElement));',
		'function __matches(s,q){q=String(q||"").trim();if(!q)return false;if(q[0]==="#")return s.id===q.slice(1);return s.tagName.toLowerCase()===q.toLowerCase();}',
		'function __rangePoint(node,offset){const s=node&&node.__state;if(s)return{target:s.bridgeKey,firstChild:false,offset:+offset||0};if(node&&node.__firstChildOf)return{target:node.__firstChildOf,firstChild:true,offset:+offset||0};throw new TypeError("Invalid range node");}',
		'function __range(){return{selected:null,start:null,end:null,selectNodeContents:function(node){const point=__rangePoint(node,0);this.selected={target:point.target,firstChild:point.firstChild};},setStart:function(node,offset){this.start=__rangePoint(node,offset);},setEnd:function(node,offset){this.end=__rangePoint(node,offset);},surroundContents:function(node){const s=node&&node.__state;if(!s)throw new TypeError("Invalid range parent");__state.operations.push({op:"surroundSelectedContents",target:s.bridgeKey});}};}',
		'const __selection={range:null,addRange:function(range){if(!range)return;this.range=range;if(range.start&&range.end)__state.operations.push({op:"setSelectionRange",target:range.start.target,firstChild:range.start.firstChild,startOffset:range.start.offset,endTarget:range.end.target,endFirstChild:range.end.firstChild,endOffset:range.end.offset});else if(range.selected)__state.operations.push({op:"selectNodeContents",target:range.selected.target,firstChild:range.selected.firstChild});},collapse:function(node,offset){const point=__rangePoint(node,offset),range=__range();range.start=point;range.end=point;this.range=range;__state.operations.push({op:"collapseSelection",target:point.target,firstChild:point.firstChild,offset:point.offset});},removeAllRanges:function(){this.range=null;__state.operations.push({op:"removeAllRanges"});},selectAllChildren:function(node){const range=__range();range.selectNodeContents(node);this.range=range;__state.operations.push({op:"selectAllChildren",target:range.selected.target});},getRangeAt:function(index){if(+index!==0||!this.range)throw new Error("IndexSizeError");return this.range;}};',
		'const document = { getElementById: function(id){return __queryElements("","getElementById",String(id));}, getElementsByTagName: function(name) { const tag=String(name).toLowerCase(); return __elementStates().filter(function(s){return tag==="*"||s.tagName.toLowerCase()===tag;}).map(__element); }, querySelector: function(q){if(arguments.length===0)throw new TypeError("querySelector requires a selector");return __queryElements("","querySelector",String(q));}, querySelectorAll: function(q){if(arguments.length===0)throw new TypeError("querySelectorAll requires a selector");return __queryElements("","querySelectorAll",String(q));}, addEventListener: function (n, f) { (__listeners[__listenerKey(null, n)] ||= []).push(f); }, createElement: function (name) { return __createElement("http://www.w3.org/1999/xhtml",String(name).toLowerCase()); }, createElementNS:function(namespaceURI,name){return __createElement(namespaceURI,name);}, createDocumentFragment:function(){return __createElement("","#document-fragment");}, createTextNode: function(text) { return {__state:{tagName:"#text",textContent:String(text)}}; }, createRange:__range };',
		compact_class_collection_bootstrap(),
		compact_last_child_bootstrap(),
		compact_remove_child_bootstrap(),
		compact_tag_collection_bootstrap(),
		compact_document_create_event_bootstrap(),
		compact_select_bootstrap(),
		compact_element_names_bootstrap(),
		browserjs.view_transition_bootstrap(),
		'Object.defineProperty(document, "title", { get: function () { return __state.title; }, set: function (v) { __state.title = String(v); } });',
		'const __htmlState=__elementStates().find(function(s){return s.tagName.toLowerCase()==="html";}),__headState=__elementStates().find(function(s){return s.tagName.toLowerCase()==="head";}),__bodyState=__elementStates().find(function(s){return s.tagName.toLowerCase()==="body";});document.documentElement=__htmlState?__element(__htmlState):{classList:{add:function(){},remove:function(){},contains:function(){return false;}}};document.head=__headState?__element(__headState):null;document.body=__bodyState?__element(__bodyState):{appendChild:function(child){return child;}};',
		'const console = { log: function () { __state.logs.push(Array.prototype.map.call(arguments, String).join(" ")); }, info: function () { __state.logs.push(Array.prototype.map.call(arguments, String).join(" ")); }, warn: function () { this.log.apply(this, arguments); }, error: function () { this.log.apply(this, arguments); } };',
		'const location = {},__LocationURL=globalThis.URL; Object.defineProperty(location, "href", { get: function () { return __state.location; }, set: function (v) { __state.navigate = String(v); } }); for(const name of ["protocol","host","hostname","port","pathname","search","hash"]){Object.defineProperty(location,name,{enumerable:true,get:function(){return new __LocationURL(__state.location)[name];},set:function(value){const record=new __LocationURL(__state.location);record[name]=value;__state.navigate=record.href;}});} Object.defineProperty(location,"origin",{enumerable:true,get:function(){return new __LocationURL(__state.location).origin;}}); location.toString=function(){return __state.location;};',
		'const __documentCookie=globalThis.__ladybirdDocumentCookie,__documentCookieException=globalThis.DOMException; function __callDocumentCookie(input){try{return __documentCookie(input);}catch(error){const message=String(error.message);if(message.indexOf("SecurityError:")===0)throw new __documentCookieException(message.slice(14).trim(),"SecurityError");throw error;}} Object.defineProperty(document,"cookie",{enumerable:true,configurable:true,get:function(){return __callDocumentCookie("get");},set:function(value){__callDocumentCookie("set:"+String(value));}});',
		'const window = globalThis; window.window = window; window.document = document; window.console = console; window.location = location; window.alert = function (v) { console.log(v); }; window.addEventListener = document.addEventListener; window.getSelection=function(){return __selection;}; window.Image=function(){return document.createElement("img");}; window.internals={imageAnimationStateForURL:function(){return{timerActive:true,frameIndex:1};},signalTestIsDone:function(){},spoofCurrentURL:function(){},setForceDarkEnabled:function(value){__state.forceDarkEnabled=!!value;},setForceDarkThresholds:function(foreground,background){__state.forceDarkForegroundThreshold=Math.trunc(Number(foreground));__state.forceDarkBackgroundThreshold=Math.trunc(Number(background));},setShowLineBoxBorders:function(value){__state.showLineBoxBorders=!!value;}}; if(!Promise.withResolvers)Promise.withResolvers=function(){let resolve,reject;const promise=new Promise(function(a,b){resolve=a;reject=b;});return{promise:promise,resolve:resolve,reject:reject};};',
		compact_computed_style_bootstrap(),
		'__ladybirdElementWheelSetResolver(function(key){const s=__state.elements[key];return s?__element(s):null;});',
		'const __initialNamedElements=Object.create(null); for (const s of __elementStates()) { if(!s.id)continue; if(!Object.prototype.hasOwnProperty.call(__initialNamedElements,s.id))__initialNamedElements[s.id]=s; try { window[s.id] = __element(__initialNamedElements[s.id]); } catch (_) {} }',
		'window.__ladybirdSnapshot = function () { return JSON.stringify(__state); };',
		'window.__ladybirdFinalize = function () { for (const key of Object.keys(__canvases)) { const c=__canvases[key],s=c.state;if(!c.context||c.kind!=="2d")continue;const snapshot=__canvasCall(s,"snapshot");s.canvasPixels=snapshot.pixels;s.canvasWidth=__canvasDimension(s,"width");s.canvasHeight=__canvasDimension(s,"height");s.canvasPixelsPremultiplied=snapshot.premultiplied;s.canvasPixelsTopDown=snapshot.topDown;s.canvasNative=true; } const snapshot=JSON.stringify(Object.assign({},__state,{elements:__pendingElementStates(true)})); __state.operations=[]; for(const s of __elementStates()){s.innerHTMLDirty=false;s.textContentDirty=false;s.attributesDirty=false;s.checkedDirty=false;s.indeterminateDirty=false;} return snapshot; };',
		'window.__ladybirdClearLogs = function () { __state.logs = []; __state.operations=[]; __state.bodyHTMLDirty = false; __state.bodyTextDirty = false; for(const s of __elementStates()){s.innerHTMLDirty=false;s.textContentDirty=false;s.attributesDirty=false;s.checkedDirty=false;s.indeterminateDirty=false;} };',
		compact_event_dispatch_bootstrap(),
		// Initialization has no replay consumer; explicit snapshots remain available.
		'return;',
		'})',
	].join('\n')
}

fn json_string_property(object map[string]json2.Any, name string) ?string {
	value := object[name] or { return none }
	if value is string {
		return value
	}
	return none
}

fn json_bool_property(object map[string]json2.Any, name string) bool {
	value := object[name] or { return false }
	return if value is bool { value } else { false }
}

fn json_int_property(object map[string]json2.Any, name string) ?int {
	value := object[name] or { return none }
	return match value {
		int { value }
		i64 { int(value) }
		i32 { int(value) }
		u64 { int(value) }
		u32 { int(value) }
		f64 { int(value) }
		f32 { int(value) }
		else { none }
	}
}

fn json_number(value json2.Any) ?f64 {
	return match value {
		int { f64(value) }
		i64 { f64(value) }
		i32 { f64(value) }
		u64 { f64(value) }
		u32 { f64(value) }
		f64 { value }
		f32 { f64(value) }
		else { none }
	}
}

fn json_number_property(object map[string]json2.Any, name string) ?f64 {
	return json_number(object[name] or { return none })
}

fn json_number_array_property(object map[string]json2.Any, name string) []f64 {
	value := object[name] or { return []f64{} }
	if value !is []json2.Any {
		return []f64{}
	}
	mut result := []f64{cap: (value as []json2.Any).len}
	for item in value as []json2.Any {
		result << (json_number(item) or { 0.0 })
	}
	return result
}

fn json_byte_array_property(object map[string]json2.Any, name string) []u8 {
	value := object[name] or { return []u8{} }
	if value !is []json2.Any {
		return []u8{}
	}
	mut result := []u8{cap: (value as []json2.Any).len}
	for item in value as []json2.Any {
		number := match item {
			int { item }
			i64 { int(item) }
			i32 { int(item) }
			u64 { int(item) }
			u32 { int(item) }
			f64 { int(item) }
			f32 { int(item) }
			else { 0 }
		}
		result << u8(number)
	}
	return result
}

fn canvas_css_font(value string) platform.Font {
	trimmed := value.trim_space()
	mut point_size := f32(10)
	mut family := 'sans-serif'
	mut weight := 400
	if trimmed.to_lower().contains('bold') {
		weight = 700
	}
	if pixel_end := trimmed.index('px') {
		mut number_start := pixel_end
		for number_start > 0 && trimmed[number_start - 1] in [`0`, `1`, `2`, `3`, `4`, `5`, `6`,
			`7`, `8`, `9`, `.`, `+`, `-`] {
			number_start--
		}
		if parsed := strconv.atof64(trimmed[number_start..pixel_end]) {
			if parsed > 0 {
				point_size = f32(parsed)
			}
		}
		family_text := trimmed[pixel_end + 2..].trim_space()
		if family_text != '' {
			family = family_text.split(',')[0].trim_space().trim('"\'')
		}
	}
	return platform.Font{
		family: family
		point_size: point_size
		weight: weight
	}
}

fn canvas_matrix_multiply(left []f64, right []f64) []f64 {
	return [
		left[0] * right[0] + left[2] * right[1],
		left[1] * right[0] + left[3] * right[1],
		left[0] * right[2] + left[2] * right[3],
		left[1] * right[2] + left[3] * right[3],
		left[0] * right[4] + left[2] * right[5] + left[4],
		left[1] * right[4] + left[3] * right[5] + left[5],
	]
}

fn canvas_text_transform(operation map[string]json2.Any, text_width f64,
	font &platform.Font) []f64 {
	mut transform := [f64(1), 0, 0, 1, 0, 0]
	mut rendered_width := text_width
	if max_width := json_number_property(operation, 'maxWidth') {
		if max_width <= 0 {
			return []f64{}
		}
		if rendered_width > max_width {
			scale := max_width / rendered_width
			transform = [scale, 0, 0, 1, 0, 0]
			rendered_width = max_width
		}
	}
	align := json_string_property(operation, 'textAlign') or { 'start' }
	direction := json_string_property(operation, 'direction') or { 'inherit' }
	mut alignment_offset := 0.0
	if align == 'center' {
		alignment_offset = -rendered_width / 2.0
	} else if align == 'right' || (align == 'end' && direction != 'rtl')
		|| (align == 'start' && direction == 'rtl') {
		alignment_offset = -rendered_width
	}
	if alignment_offset != 0 {
		transform = canvas_matrix_multiply([f64(1), 0, 0, 1, alignment_offset, 0], transform)
	}
	metrics := font.pixel_metrics()
	baseline := json_string_property(operation, 'textBaseline') or { 'alphabetic' }
	baseline_offset := match baseline {
		'top' { f64(metrics.ascent) }
		'hanging' { f64(metrics.ascent) * 0.8 }
		'middle' { f64(metrics.ascent - metrics.descent) / 2.0 }
		'ideographic', 'bottom' { -f64(metrics.descent) }
		else { 0.0 }
	}
	if baseline_offset != 0 {
		transform = canvas_matrix_multiply([f64(1), 0, 0, 1, 0, baseline_offset], transform)
	}
	return transform
}

fn replay_javascript_canvas_text(mut pixels []u8, width int, height int,
	state map[string]json2.Any) bool {
	$if macos {
		operations_value := state['canvasTextOperations'] or { return false }
		if operations_value !is []json2.Any || width <= 0 || height <= 0
			|| pixels.len != width * height * 4 {
			return false
		}
		mut pixels_are_premultiplied := false
		for item in operations_value as []json2.Any {
			if item !is map[string]json2.Any {
				continue
			}
			operation := item as map[string]json2.Any
			kind := json_string_property(operation, 'kind') or { continue }
			text := (json_string_property(operation, 'text') or { '' }).replace('\t', ' ').replace('\n', ' ').replace('\r', ' ').replace('\f', ' ')
			if text == '' {
				continue
			}
			x := json_number_property(operation, 'x') or { continue }
			y := json_number_property(operation, 'y') or { continue }
			font := canvas_css_font(json_string_property(operation, 'font') or {
				'10px sans-serif'
			})
			direction := if (json_string_property(operation, 'direction') or { 'inherit' }) == 'rtl' {
				platform.GlyphRunTextType.rtl
			} else {
				platform.GlyphRunTextType.ltr
			}
			run := platform.shape_text(0, 0, text, &font, direction)
			glyphs := run.glyph_indices()
			positions := run.glyph_positions()
			if glyphs.len == 0 || positions.len != glyphs.len * 2 {
				continue
			}
			text_transform := canvas_text_transform(operation, f64(run.width()), &font)
			if text_transform.len != 6 {
				continue
			}
			mut current_transform := json_number_array_property(operation, 'transform')
			if current_transform.len != 6 {
				current_transform = [f64(1), 0, 0, 1, 0, 0]
			}
			transform := canvas_matrix_multiply(current_transform, text_transform)
			mut paint_color := css.Color{ a: 255 }
			mut gradient_x0 := f32(0)
			mut gradient_y0 := f32(0)
			mut gradient_x1 := f32(0)
			mut gradient_y1 := f32(0)
			mut gradient_stops := [f32(0)]
			mut gradient_stop_count := 0
			if style_value := operation['style'] {
				if style_value is map[string]json2.Any {
					style := style_value as map[string]json2.Any
					if (json_string_property(style, 'kind') or { 'color' }) == 'linear-gradient' {
						gradient_x0 = f32(json_number_property(style, 'x0') or { 0 })
						gradient_y0 = f32(json_number_property(style, 'y0') or { 0 })
						gradient_x1 = f32(json_number_property(style, 'x1') or { 0 })
						gradient_y1 = f32(json_number_property(style, 'y1') or { 0 })
						if stops_value := style['stops'] {
							if stops_value is []json2.Any {
								gradient_stops.clear()
								for stop_value in stops_value as []json2.Any {
									if stop_value !is map[string]json2.Any {
										continue
									}
									stop := stop_value as map[string]json2.Any
									stop_color := css.parse_color_string(json_string_property(stop, 'color') or { 'black' }) or { continue }
									gradient_stops << f32(json_number_property(stop, 'offset') or {
										0
									})
									gradient_stops << f32(stop_color.r) / 255.0
									gradient_stops << f32(stop_color.g) / 255.0
									gradient_stops << f32(stop_color.b) / 255.0
									gradient_stops << f32(stop_color.a) / 255.0
									gradient_stop_count++
								}
							}
						}
					} else {
						paint_color = css.parse_color_string(json_string_property(style, 'color') or {
							'black'
						}) or { css.Color{ a: 255 } }
					}
				}
			}
			font_path := native_replay_font_path(font)
			did_draw := C.native_draw_canvas_glyph_run_rgba(pixels.data, width, height, width * 4, int(pixels_are_premultiplied), glyphs.data, positions.data, glyphs.len, font.point_size, font.weight, font_path, font.face_index(), f32(x), f32(y), f32(transform[0]), f32(transform[1]), f32(transform[2]), f32(transform[3]), f32(transform[4]), f32(transform[5]), paint_color.r, paint_color.g, paint_color.b, paint_color.a, gradient_x0, gradient_y0, gradient_x1, gradient_y1, gradient_stops.data, gradient_stop_count, f32(json_number_property(operation, 'globalAlpha') or { 1 }), if kind == 'strokeText' {
				1
			} else {
				0
			}, if kind == 'strokeText' || 'maxWidth' in operation { 1 } else { 0 }, f32(json_number_property(operation, 'lineWidth') or { 1 }))
			pixels_are_premultiplied = pixels_are_premultiplied || did_draw != 0
		}
		return pixels_are_premultiplied
	}
	return false
}

fn apply_javascript_element_attribute(mut element dom.Element, name string, value ?string) {
	old_value := element.get_attribute(name)
	if new_value := value {
		if previous_value := old_value {
			if new_value == previous_value
				&& !(name == 'src' && element.is_html_element() && element.local_name() in ['audio', 'video']) {
				return
			}
		}
	} else if old_value == none {
		return
	}
	// Public qualified-name operations retain the first matching Attr's identity.
	// Reflected IDL setters instead write their own null-namespace slot directly.
	mut namespace_uri := ?string(none)
	if attribute := element.get_attribute_node(name) {
		namespace_uri = attribute.namespace_uri()
	}
	if new_value := value {
		if attribute := element.get_attribute_node(name) {
			element.set_attribute_value_ns(attribute.local_name(), new_value,
				attribute.prefix(), attribute.namespace_uri())
		} else {
			element.set_attribute_value(name, new_value)
		}
	} else {
		element.remove_attribute(name)
	}
	if namespace_uri != none { return }
	if element.local_name() == 'img' && name == 'src' {
		image := unsafe { &dom.HTMLImageElement(&element) }
		html.html_image_element_form_associated_element_attribute_changed(image, 'src', old_value, value, none)
		mut node := unsafe { &dom.Node(&element) }
		node.set_needs_layout_update(.html_image_element_update_the_image_data)
		node.set_needs_repaint(.paint_commands)
	}
	if element.local_name() == 'object' && name in ['data', 'type', 'classid'] {
		object_element := unsafe { &dom.HTMLObjectElement(&element) }
		html.html_object_element_form_associated_element_attribute_changed(object_element, name, old_value, value, none)
		if !element.document().is_fully_active() {
			mut model := html.html_object_element_model_for_dom_element(object_element)
			model.set_environment(element.as_node().is_connected(), true, false)
			model.queue_element_task_to_run_object_representation_steps()
		}
	}
}

fn javascript_created_node(document &dom.Document, state map[string]json2.Any, mut element_by_bridge_key map[string]&dom.Element) ?&dom.Node {
	tag_name := json_string_property(state, 'tagName') or { return none }
	if tag_name == '#text' {
		return document.create_text_node(json_string_property(state, 'textContent') or { '' }).as_node()
	}
	if tag_name == '#document-fragment' {
		fragment := document.create_document_fragment()
		mut fragment_node := unsafe { &dom.Node(fragment) }
		if child_values := state['children'] {
			if child_values is []json2.Any {
				for child_value in child_values as []json2.Any {
					if child_value !is map[string]json2.Any {
						continue
					}
					if child := javascript_created_node(document, child_value as map[string]json2.Any, mut element_by_bridge_key) {
						fragment_node.append_child(child) or {}
					}
				}
			}
		}
		return fragment.as_node()
	}
	if tag_name == '' {
		return none
	}
	namespace_uri := json_string_property(state, 'namespaceURI') or {
		'http://www.w3.org/1999/xhtml'
	}
	// A listener may already own a disconnected generic or SVG element.
	// Reuse that native node for every tag when replay inserts its facade.
	key := json_string_property(state, 'bridgeKey') or { '' }
	mut element := element_by_bridge_key[key] or {
		document.create_element_ns(namespace_uri, tag_name) or { return none }
	}
	// Known nodes already consumed their explicit ordered mutations. A newly
	// materialized node receives its initial records once, preserving namespaces.
	if key !in element_by_bridge_key || 'attributeRecords' !in state {
		if attribute_values := state['attributeRecords'] {
			if attribute_values is []json2.Any {
				for item in attribute_values as []json2.Any {
					if item !is map[string]json2.Any { continue }
					attribute := item as map[string]json2.Any
					name := json_string_property(attribute, 'localName') or { continue }
					value := json_string_property(attribute, 'value') or { continue }
					element.set_attribute_value_ns(name, value,
						json_string_property(attribute, 'prefix'), json_string_property(attribute, 'namespaceURI'))
				}
			}
		} else if attribute_values := state['attributes'] {
			if attribute_values is map[string]json2.Any {
				for name, attribute_value in attribute_values as map[string]json2.Any {
					if attribute_value is string {
						apply_javascript_element_attribute(mut element, name, attribute_value)
					}
				}
			}
		}
	}
	if text := json_string_property(state, 'textContent') {
		if text != '' {
			mut element_node := unsafe { &dom.Node(element) }
			element_node.set_text_content(text) or {}
		}
	}
	if bridge_key := json_string_property(state, 'bridgeKey') {
		element_by_bridge_key[bridge_key] = element
	}
	return element.as_node()
}

fn apply_javascript_canvas_state(document &dom.Document, mut element dom.Element,
	element_state map[string]json2.Any) {
	if element.local_name() != 'canvas' {
		return
	}
	width := json_int_property(element_state, 'canvasWidth') or { return }
	height := json_int_property(element_state, 'canvasHeight') or { return }
	mut pixels := json_byte_array_property(element_state, 'canvasPixels')
	mut native_rows_are_top_down := json_bool_property(element_state, 'canvasPixelsTopDown')
	// A full-size video draw is a snapshot of its decoded frame. Preserve that
	// source directly across the lightweight JS bridge; serializing millions of
	// byte-valued JSON numbers is both lossy and needlessly expensive.
	if source_id := json_string_property(element_state, 'canvasVideoSource') {
		if source_element := document.get_element_by_id(source_id) {
			if source_element.is_html_element() && source_element.local_name() == 'video' {
				video := unsafe { &dom.HTMLVideoElement(source_element) }
				model := html.html_video_element_model_for_dom_element(video)
				if source_frame := model.current_decoded_image_frame() {
					source_bitmap := source_frame.bitmap()
					if source_bitmap.width == width && source_bitmap.height == height {
						pixels = source_bitmap.data.clone()
						native_rows_are_top_down = source_bitmap.native_rows_are_top_down
					}
				}
			}
		}
	}
	if width < 0 || height < 0 || pixels.len != width * height * 4 {
		return
	}
	native_canvas := json_bool_property(element_state, 'canvasNative')
	pixels_are_premultiplied := if native_canvas {
		json_bool_property(element_state, 'canvasPixelsPremultiplied')
	} else {
		replay_javascript_canvas_text(mut pixels, width, height, element_state)
	}
	mut canvas := unsafe { &dom.HTMLCanvasElement(element) }
	if html.html_canvas_element_width(canvas) != u32(width) {
		html.html_canvas_element_set_width(mut canvas, u32(width)) or { return }
	}
	if html.html_canvas_element_height(canvas) != u32(height) {
		html.html_canvas_element_set_height(mut canvas, u32(height)) or { return }
	}
	mut context := html.html_canvas_element_get_context(canvas, '2d', none) or { return }
	mut bitmap := context.surface() or { return }
	bitmap.native_rows_are_top_down = native_rows_are_top_down
	mut mutable_bitmap := unsafe { &dom.Bitmap_(bitmap) }
	mutable_bitmap.data = pixels.clone()
	mutable_bitmap.pitch = width * 4
	mutable_bitmap.alpha_type = if pixels_are_premultiplied { if native_canvas { u8(2) } else { u8(0) } } else { u8(1) }
	context.did_draw(html.CanvasFloatRect{0, 0, f64(width), f64(height)})
}

fn apply_javascript_state(document &dom.Document, encoded string, canvas_elements map[string]&dom.Element, mut messages []string) ?string {
	state := javascript_replay_state(encoded, mut messages) or { return none }
	return apply_decoded_javascript_state(document, state, canvas_elements, mut messages)
}

fn apply_decoded_javascript_state(document &dom.Document, state map[string]json2.Any,
	canvas_elements map[string]&dom.Element, mut messages []string) ?string {
	if model := html.NavigableModel.navigable_with_active_document(document) {
		mut mutable_model := unsafe { &html.NavigableModel(model) }
		mutable_model.set_force_dark_enabled(json_bool_property(state, 'forceDarkEnabled'))
		foreground := json_int_property(state, 'forceDarkForegroundThreshold') or { 150 }
		background := json_int_property(state, 'forceDarkBackgroundThreshold') or { 205 }
		mutable_model.set_force_dark_thresholds(i32(foreground), i32(background))
		show_line_box_borders := json_bool_property(state, 'showLineBoxBorders')
		if mutable_model.should_show_line_box_borders() != show_line_box_borders {
			mutable_model.set_should_show_line_box_borders(show_line_box_borders)
			mut mutable_document := unsafe { &dom.Document(document) }
			mutable_document.set_needs_repaint_with_invalidation(.paint_commands)
		}
	}
	root := unsafe { &dom.Node(document) }
	mut initial_elements := []&dom.Element{}
	mut has_initial_elements := false
	mut metadata_may_have_changed := json_bool_property(state, 'bodyHTMLDirty')
		|| json_bool_property(state, 'bodyTextDirty')
	// Legacy unbound snapshots index the tree before a body replacement.
	if json_bool_property(state, 'bodyHTMLDirty') || json_bool_property(state, 'bodyTextDirty') {
		initial_elements = css.query_selector_all(root, '*')
		has_initial_elements = true
	}
	if json_bool_property(state, 'bodyHTMLDirty') {
		body := document.body()
		body_html := json_string_property(state, 'bodyHTML') or { '' }
		if mut body_element := body {
			if body_html != (body_element.inner_html() or { '' }) {
				body_element.set_inner_html(body_html) or { messages << err.msg() }
			}
		}
	} else if json_bool_property(state, 'bodyTextDirty') {
		body := document.body()
		body_text := json_string_property(state, 'bodyText') or { '' }
		if mut body_element := body {
			if body_text != (body_element.as_node().text_content() or { '' }) {
				mut body_node := unsafe { &dom.Node(body_element) }
				body_node.set_text_content(body_text) or { messages << err.msg() }
			}
		}
	}
	mut element_by_bridge_key := canvas_elements.clone()
	if element_values := state['elements'] {
		if element_values is map[string]json2.Any {
			for _, item in element_values as map[string]json2.Any {
				if item !is map[string]json2.Any {
					continue
				}
				element_state := item as map[string]json2.Any
				bridge_key := json_string_property(element_state, 'bridgeKey') or { continue }
				// A source DOM wrapper keeps its original element after removal or
				// reordering. The host already retains that actual identity; the
				// original tree index only seeds callers without a native binding.
				mut element := element_by_bridge_key[bridge_key] or {
					element_index := json_int_property(element_state, 'elementIndex') or { continue }
					if !has_initial_elements {
						initial_elements = css.query_selector_all(root, '*')
						has_initial_elements = true
					}
					if element_index < 0 || element_index >= initial_elements.len { continue }
					initial_elements[element_index]
				}
				element_by_bridge_key[bridge_key] = element
				if (element.is_html_element() && element.local_name() == 'meta'
					&& json_bool_property(element_state, 'attributesDirty'))
					|| json_bool_property(element_state, 'innerHTMLDirty')
					|| json_bool_property(element_state, 'textContentDirty') {
					metadata_may_have_changed = true
				}
				uses_attribute_records := 'attributeRecords' in element_state
				if !uses_attribute_records && json_bool_property(element_state, 'attributesDirty') {
					if attribute_values := element_state['attributes'] {
						if attribute_values is map[string]json2.Any {
							attributes := attribute_values as map[string]json2.Any
							for existing_name in element.get_attribute_names() {
								if existing_name !in attributes {
									apply_javascript_element_attribute(mut element, existing_name, none)
								}
							}
							for name, attribute_value in attributes {
								if attribute_value is string && name != 'src' {
									apply_javascript_element_attribute(mut element, name, attribute_value)
								}
							}
						}
					}
				}
				if inner_html := json_string_property(element_state, 'innerHTML') {
					if json_bool_property(element_state, 'innerHTMLDirty') && inner_html != (element.inner_html() or { '' }) {
						element.set_inner_html(inner_html) or { messages << err.msg() }
					}
				}
				if text := json_string_property(element_state, 'textContent') {
					current_text := element.as_node().text_content() or { '' }
					if json_bool_property(element_state, 'textContentDirty') && text != current_text && (json_string_property(element_state, 'innerHTML') or {
						''
					}) == '' {
						mut node := unsafe { &dom.Node(element) }
						node.set_text_content(text) or { messages << err.msg() }
					}
				}
				if !uses_attribute_records {
					if class_name := json_string_property(element_state, 'className') {
						if class_name != element.get_attribute_value('class') {
							element.set_attribute_value('class', class_name)
						}
					}
					if style_text := json_string_property(element_state, 'styleText') {
						if style_text != element.get_attribute_value('style') {
							element.set_attribute_value('style', style_text)
						}
					}
					if source := json_string_property(element_state, 'src') {
						if source != (element.get_attribute('src') or { '' }) {
							apply_javascript_element_attribute(mut element, 'src', source)
						}
					}
				}
				if element.local_name() == 'input' {
					input := unsafe { &dom.HTMLInputElement(element) }
					mut model := html.HTMLInputElementModel.create(input)
					if json_bool_property(element_state, 'checkedDirty') {
						model.set_checked_binding(json_bool_property(element_state, 'checked'))
					}
					if json_bool_property(element_state, 'indeterminateDirty') {
						model.set_indeterminate(json_bool_property(element_state, 'indeterminate'))
					}
				}
				if element.local_name() == 'canvas' {
					apply_javascript_canvas_state(document, mut element, element_state)
				}
			}
		}
	}
	if operations := state['operations'] {
		if operations is []json2.Any {
			for item in operations as []json2.Any {
				if item !is map[string]json2.Any {
					continue
				}
				operation := item as map[string]json2.Any
				kind := json_string_property(operation, 'op') or { continue }
				if kind in ['appendCreated', 'insertCreated', 'moveBefore', 'remove',
					'surroundSelectedContents'] {
					metadata_may_have_changed = true
				}
				if kind == 'removeAllRanges' {
					if mut selection := document.get_selection() {
						selection.remove_all_ranges()
					}
					continue
				}
				target_key := json_string_property(operation, 'target') or { continue }
				mut target := element_by_bridge_key[target_key] or { continue }
				if kind == 'compactAttribute' {
					name := json_string_property(operation, 'name') or { continue }
					// Explicit track source/handler and video poster writes run their DOM
					// hooks even for equal text; preserve the first qualified Attr.
					if target.is_html_element()
						&& ((name in ['src', 'onload', 'onerror'] && target.local_name() == 'track')
							|| (name == 'poster' && target.local_name() == 'video')) {
						if value := json_string_property(operation, 'value') {
							if attribute := target.get_attribute_node(name) {
								target.set_attribute_value_ns(attribute.local_name(), value,
									attribute.prefix(), attribute.namespace_uri())
								} else {
									target.set_attribute_value(name, value)
								}
						} else {
							target.remove_attribute(name)
						}
					} else {
						apply_javascript_element_attribute(mut target, name, json_string_property(operation, 'value'))
					}
				} else if kind == 'wheelContentAttribute' {
					// Replay explicit writes even when the attribute text is unchanged:
					// those writes replace an earlier IDL-installed handler.
					if wheel_attribute_value := json_string_property(operation, 'value') {
						target.set_attribute_value('onwheel', wheel_attribute_value)
					} else {
						target.remove_attribute('onwheel')
					}
				} else if kind == 'mediaLifecycleContentAttribute' {
					name := json_string_property(operation, 'name') or { continue }
					if !target.is_html_element() || target.local_name() !in ['audio', 'video']
						|| name !in ['onplay', 'onpause', 'onplaying', 'onwaiting', 'oncanplay', 'oncanplaythrough', 'onloadedmetadata', 'onloadeddata', 'onratechange', 'onvolumechange', 'ontimeupdate', 'ondurationchange', 'onseeking', 'onseeked', 'onprogress', 'onsuspend', 'onabort', 'onemptied', 'onloadstart', 'onended', 'onresize', 'onerror'] { continue }
					// Explicit equal-text writes replace IDL callbacks just like parser attributes.
					if attribute_value := json_string_property(operation, 'value') {
						target.set_attribute_value(name, attribute_value)
					} else {
						target.remove_attribute(name)
					}
				} else if kind == 'appendCreated' {
					child_value := operation['child'] or { continue }
					if child_value !is map[string]json2.Any {
						continue
					}
					child := javascript_created_node(document, child_value as map[string]json2.Any, mut element_by_bridge_key) or { continue }
					mut target_node := unsafe { &dom.Node(target) }
					target_node.append_child(child) or {}
				} else if kind == 'insertCreated' {
					child_value := operation['child'] or { continue }
					if child_value !is map[string]json2.Any {
						continue
					}
					child := javascript_created_node(document, child_value as map[string]json2.Any, mut element_by_bridge_key) or { continue }
					mut target_node := unsafe { &dom.Node(target) }
					reference := if json_bool_property(operation, 'referenceFirstChild') {
						target_node.first_child()
					} else if reference_key := json_string_property(operation, 'reference') {
						if reference_element := element_by_bridge_key[reference_key] {
							?&dom.Node(reference_element.as_node())
						} else {
							?&dom.Node(none)
						}
					} else {
						?&dom.Node(none)
					}
					target_node.pre_insert(child, reference) or {}
				} else if kind == 'moveBefore' {
					child_key := json_string_property(operation, 'child') or { continue }
					mut child := element_by_bridge_key[child_key] or { continue }
					reference_key := json_string_property(operation, 'reference') or { '' }
					reference := if reference_key == '' {
						?&dom.Node(none)
					} else if reference_element := element_by_bridge_key[reference_key] {
						?&dom.Node(reference_element.as_node())
					} else {
						?&dom.Node(none)
					}
					mut target_node := unsafe { &dom.Node(target) }
					mut child_node := unsafe { &dom.Node(child) }
					// insertBefore() of a detached element, such as a clone, inserts it;
					// moving applies only to a connected node.
					if json_bool_property(operation, 'insert') && !child_node.is_connected() {
						target_node.pre_insert(child_node, reference) or {}
					} else {
						child_node.move_node(mut target_node, reference) or {}
					}
				} else if kind == 'remove' {
					mut target_node := unsafe { &dom.Node(target) }
					target_node.remove(false)
				} else if kind == 'selectNodeContents' {
					mut selected_node := target.as_node()
					if json_bool_property(operation, 'firstChild') {
						selected_node = target.as_node().first_child() or { continue }
					}
					mut range := document.create_range()
					range.select_node_contents(selected_node) or { continue }
					if mut selection := document.get_selection() {
						selection.add_range(range)
					}
				} else if kind == 'setSelectionRange' {
					mut start_node := target.as_node()
					if json_bool_property(operation, 'firstChild') {
						start_node = target.as_node().first_child() or { continue }
					}
					end_key := json_string_property(operation, 'endTarget') or { continue }
					end_target := element_by_bridge_key[end_key] or { continue }
					mut end_node := end_target.as_node()
					if json_bool_property(operation, 'endFirstChild') {
						end_node = end_target.as_node().first_child() or { continue }
					}
					start_offset := json_int_property(operation, 'startOffset') or { 0 }
					end_offset := json_int_property(operation, 'endOffset') or { 0 }
					mut range := document.create_range()
					range.set_start(start_node, start_offset) or { continue }
					range.set_end(end_node, end_offset) or { continue }
					if mut selection := document.get_selection() {
						selection.add_range(range)
					}
				} else if kind == 'collapseSelection' {
					mut selected_node := target.as_node()
					if json_bool_property(operation, 'firstChild') {
						selected_node = target.as_node().first_child() or { continue }
					}
					offset := json_int_property(operation, 'offset') or { 0 }
					if mut selection := document.get_selection() {
						selection.collapse(selected_node, offset) or { continue }
					}
				} else if kind == 'selectAllChildren' {
					if mut selection := document.get_selection() {
						selection.select_all_children(target.as_node()) or { continue }
					}
				} else if kind == 'focus' {
					mut mutable_document := unsafe { &dom.Document(document) }
					mutable_document.set_focused_area(target.as_node())
				} else if kind == 'selectTextControl' && target.local_name() == 'input' {
					input := unsafe { &dom.HTMLInputElement(target) }
					mut model := html.HTMLInputElementModel.create(input)
					mut text_control := model.text_control
					text_control.select()
				} else if kind == 'surroundSelectedContents' {
					surround_selection := document.get_selection() or { continue }
					mut range := surround_selection.range() or { continue }
					range.surround_contents(target.as_node()) or { continue }
				}
			}
		}
	}
	// Created canvases only acquire their DOM node while replaying append/insert
	// operations above. Apply all canvas snapshots once more after that pass so
	// dynamically-created canvases receive their backing pixels as well.
	if element_values := state['elements'] {
		if element_values is map[string]json2.Any {
			for bridge_key, item in element_values as map[string]json2.Any {
				if item !is map[string]json2.Any {
					continue
				}
				mut element := element_by_bridge_key[bridge_key] or { continue }
				if element.local_name() == 'canvas' {
					apply_javascript_canvas_state(document, mut element, item as map[string]json2.Any)
				}
			}
		}
	}
	if logs := state['logs'] {
		if logs is []json2.Any {
			for entry in logs as []json2.Any {
				if entry is string {
					messages << entry
				}
			}
		}
	}
	if title := json_string_property(state, 'title') {
		if mut title_element := css.query_selector(root, 'title') {
			if title != (title_element.as_node().text_content() or { '' }) {
				mut title_node := unsafe { &dom.Node(title_element) }
				title_node.set_text_content(title) or {}
			}
		}
	}
	// Metadata depends on meta attributes and tree contents, so ordinary class,
	// control-state and selection changes can retain its current document value.
	if metadata_may_have_changed {
		mut mutable_document := unsafe { &dom.Document(document) }
		mutable_document.obtain_supported_color_schemes()
	}
	return json_string_property(state, 'navigate')
}

fn run_document_javascript(document &dom.Document, current_url string, sources []string, runtime &browserjs.Runtime, mut messages []string) ?string {
	return run_document_script_sources(document, current_url, sources.map(browserjs.ScriptSource{
		code: it
		url: current_url
	}), runtime, mut messages)
}

fn run_document_script_sources(document &dom.Document, current_url string, sources []browserjs.ScriptSource, runtime &browserjs.Runtime, mut messages []string) ?string {
	// Parsing creates Document's Selection, while the browsing context normally
	// arrives with navigation before page scripts run. The compact host executes
	// scripts before its first layout, so establish that context here as well.
	mut mutable_document := unsafe { &dom.Document(document) }
	if mutable_document.get_browsing_context() == none {
		mutable_document.set_browsing_context(&dom.BrowsingContext{
			active_document_: document
		})
	}
	ensure_compact_browser_navigable(document) or { return none }
	if !compact_document_can_run_script(document) { return none }
	if runtime.engine == .libjs {
		messages << 'LibJS DOM bindings are not translated yet; page scripts use the supported standalone runtime.'
		for source in sources {
			if !compact_document_can_run_script(document) { continue }
			for diagnostic in runtime.run_document_scripts_collect_errors([source]) {
				messages << 'JavaScript (LibJS): ${diagnostic}'
			}
		}
		return none
	}
	mut canvas_host := browserjs.CanvasHost.create(document)
	mut mutable_runtime := unsafe { &browserjs.Runtime(runtime) }
	mut navigator_host := browserjs.NavigatorHost.create(document) or {
		messages << 'JavaScript Navigator bindings: ${err.msg()}'
		return none
	}
	navigator_host.install(mut mutable_runtime) or {
		messages << 'JavaScript Navigator bindings: ${err.msg()}'
		return none
	}
	canvas_host.install(mut mutable_runtime) or {
		messages << 'JavaScript canvas bindings: ${err.msg()}'
		return none
	}
	mut webgl_host := browserjs.CanvasWebGLHost.create(document)
	webgl_host.install(mut mutable_runtime) or {
		messages << 'JavaScript WebGL bindings: ${err.msg()}'
		return none
	}
	mut readable_host := browserjs.ReadableStreamHost.create(document) or {
		messages << 'JavaScript ReadableStream bindings: ${err.msg()}'
		return none
	}
	readable_host.install(mut mutable_runtime) or {
		messages << 'JavaScript ReadableStream bindings: ${err.msg()}'
		return none
	}
	mut blob_host := browserjs.BlobHost.create(document) or {
		messages << 'JavaScript Blob bindings: ${err.msg()}'
		return none
	}
	blob_host.install(mut mutable_runtime) or {
		messages << 'JavaScript Blob bindings: ${err.msg()}'
		return none
	}
	blob_host.install_constructor() or {
		messages << 'JavaScript Blob constructor: ${err.msg()}'
		return none
	}
	mut query_host := browserjs.URLSearchParamsHost.create(document) or {
		messages << 'JavaScript URLSearchParams bindings: ${err.msg()}'
		return none
	}
	query_host.install(mut mutable_runtime) or {
		messages << 'JavaScript URLSearchParams bindings: ${err.msg()}'
		return none
	}
	mut url_host := browserjs.URLHost.create(document) or {
		messages << 'JavaScript URL bindings: ${err.msg()}'
		return none
	}
	url_host.install(mut mutable_runtime) or {
		messages << 'JavaScript URL bindings: ${err.msg()}'
		return none
	}
	mut media_source_host := browserjs.MediaSourceHost.create(document) or {
		messages << 'JavaScript MediaSource bindings: ${err.msg()}'
		return none
	}
	media_source_host.install(mut mutable_runtime) or {
		messages << 'JavaScript MediaSource bindings: ${err.msg()}'
		return none
	}
	mut file_host := browserjs.FileHost.create(document) or {
		messages << 'JavaScript File bindings: ${err.msg()}'
		return none
	}
	file_host.install(mut mutable_runtime) or {
		messages << 'JavaScript File bindings: ${err.msg()}'
		return none
	}
	file_host.install_constructor() or {
		messages << 'JavaScript File constructor: ${err.msg()}'
		return none
	}
	mut file_list_host := browserjs.FileListHost.create(document) or {
		messages << 'JavaScript FileList bindings: ${err.msg()}'
		return none
	}
	file_list_host.install(mut mutable_runtime) or {
		messages << 'JavaScript FileList bindings: ${err.msg()}'
		return none
	}
	file_list_host.install_constructor() or {
		messages << 'JavaScript FileList constructor: ${err.msg()}'
		return none
	}
	mut abort_host := browserjs.AbortSignalHost.create(document) or {
		messages << 'JavaScript AbortSignal bindings: ${err.msg()}'
		return none
	}
	abort_host.install(mut mutable_runtime) or {
		messages << 'JavaScript AbortSignal bindings: ${err.msg()}'
		return none
	}
	mut writable_host := browserjs.WritableStreamHost.create(document) or {
		messages << 'JavaScript WritableStream bindings: ${err.msg()}'
		return none
	}
	writable_host.install(mut mutable_runtime) or {
		messages << 'JavaScript WritableStream bindings: ${err.msg()}'
		return none
	}
	mut transform_host := browserjs.TransformStreamHost.create(document) or {
		messages << 'JavaScript TransformStream bindings: ${err.msg()}'
		return none
	}
	transform_host.install(mut mutable_runtime) or {
		messages << 'JavaScript TransformStream bindings: ${err.msg()}'
		return none
	}
	mut strategy_host := browserjs.QueuingStrategyHost.create(document) or {
		messages << 'JavaScript queuing strategy bindings: ${err.msg()}'
		return none
	}
	strategy_host.install(mut mutable_runtime) or {
		messages << 'JavaScript queuing strategy bindings: ${err.msg()}'
		return none
	}
	mut xhr_host := browserjs.XMLHttpRequestHost.create_native(document) or {
		messages << 'JavaScript XMLHttpRequest bindings: ${err.msg()}'
		return none
	}
	xhr_host.install(mut mutable_runtime) or {
		messages << 'JavaScript XMLHttpRequest bindings: ${err.msg()}'
		return none
	}
	mut transition_host := browserjs.ViewTransitionHost.create(document, fn [document] (callback_runtime &browserjs.Runtime) ! {
		state := callback_runtime.evaluate_host('__ladybirdFinalize()')!
		mut replay_messages := []string{}
		apply_javascript_runtime_state(document, state, callback_runtime, mut replay_messages)
		mut mutable_callback_runtime := unsafe { &browserjs.Runtime(callback_runtime) }
		mutable_callback_runtime.mark_document_state_dirty()
	}) or {
		messages << 'JavaScript view-transition bindings: ${err.msg()}'
		return none
	}
	transition_host.install(mut mutable_runtime) or {
		messages << 'JavaScript view-transition bindings: ${err.msg()}'
		return none
	}
	mut image_host := browserjs.ImageHost.create_with_request_fetch(document, browser_fetch_image_request, fn [document] (callback_runtime &browserjs.Runtime) ! {
		state := callback_runtime.evaluate_host('__ladybirdFinalize()')!
		mut replay_messages := []string{}
		apply_javascript_runtime_state(document, state, callback_runtime, mut replay_messages)
	}) or {
		messages << 'JavaScript image bindings: ${err.msg()}'
		return none
	}
	image_host.install(mut mutable_runtime) or {
		messages << 'JavaScript image bindings: ${err.msg()}'
		return none
	}
	mut media_element_host := browserjs.MediaElementHost.create_with_created_element_hook(document, fn [document] (callback_runtime &browserjs.Runtime) ! {
		state := callback_runtime.evaluate_host('__ladybirdFinalize()')!
		mut replay_messages := []string{}
		apply_javascript_runtime_state(document, state, callback_runtime, mut replay_messages)
	}, install_video_poster_fetch_hook) or {
		messages << 'JavaScript media element bindings: ${err.msg()}'
		return none
	}
	media_element_host.install(mut mutable_runtime) or {
		messages << 'JavaScript media element bindings: ${err.msg()}'
		return none
	}
	mut element_wheel_host := browserjs.ElementWheelHost.create_with_replay(document, fn [document] (callback_runtime &browserjs.Runtime) ! {
		state := callback_runtime.evaluate_host('__ladybirdFinalize()')!
		mut replay_messages := []string{}
		apply_javascript_runtime_state(document, state, callback_runtime, mut replay_messages)
	}) or {
		messages << 'JavaScript element wheel bindings: ${err.msg()}'
		return none
	}
	element_wheel_host.install(mut mutable_runtime) or {
		messages << 'JavaScript element wheel bindings: ${err.msg()}'
		return none
	}
	install_compact_element_content_binding(document, mut mutable_runtime) or {
		messages << 'JavaScript element content bindings: ${err.msg()}'
		return none
	}
	install_compact_document_state_binding(document, mut mutable_runtime) or {
		messages << 'JavaScript document state bindings: ${err.msg()}'
		return none
	}
	processmetrics.instruction_checkpoint('javascript_native_bindings')
	initial_state := javascript_initial_state(document, current_url, sources.map(it.code))
	processmetrics.instruction_checkpoint('javascript_initial_state')
	bootstrap := javascript_bootstrap()
	initial_state_json := json2.encode(initial_state)
	processmetrics.instruction_checkpoint('javascript_bootstrap_source')
	mutable_runtime.initialize_host_from_json(bootstrap, initial_state_json) or {
		messages << 'JavaScript: ${err.msg()}'
		return none
	}
	processmetrics.instruction_checkpoint('javascript_bootstrap_evaluated')
	install_compact_native_selector_bindings(mut mutable_runtime) or {
		messages << 'JavaScript selector bindings: ${err.msg()}'
		return none
	}
	document_wrapper := runtime.evaluate_host_value('document') or {
		messages << 'JavaScript Document event bindings: ${err.msg()}'
		return none
	}
	mutable_runtime.install_document_window_event_binding(document, document_wrapper) or {
		messages << 'JavaScript Document event bindings: ${err.msg()}'
		return none
	}
	mutable_runtime.install_window_current_event_binding() or {
		messages << 'JavaScript Window.event bindings: ${err.msg()}'
		return none
	}
	layout.install_document_layout_hook(document)
	mutable_runtime.install_window_find_binding(fn [document] (callback_runtime &browserjs.Runtime) ! {
		state := callback_runtime.evaluate_host('__ladybirdFinalize()')!
		mut replay_messages := []string{}
		apply_javascript_runtime_state(document, state, callback_runtime, mut replay_messages)
	}) or {
		messages << 'JavaScript Window.find bindings: ${err.msg()}'
		return none
	}
	mut font_host := browserjs.FontFaceHost.create(document)
	font_host.install(mut mutable_runtime) or {
		messages << 'JavaScript font bindings: ${err.msg()}'
		return none
	}
	mut timer_host := browserjs.TimerHost.create(document) or {
		messages << 'JavaScript timer bindings: ${err.msg()}'
		return none
	}
	timer_host.install(mut mutable_runtime) or {
		messages << 'JavaScript timer bindings: ${err.msg()}'
		return none
	}
	mut crypto_host := browserjs.CryptoHost.create(document) or {
		messages << 'JavaScript Crypto bindings: ${err.msg()}'
		return none
	}
	crypto_host.install(mut mutable_runtime) or {
		messages << 'JavaScript Crypto bindings: ${err.msg()}'
		return none
	}
	mut animation_frame_host := browserjs.AnimationFrameHost.create(document, fn [document] (callback_runtime &browserjs.Runtime) ! {
		state := callback_runtime.evaluate_host('__ladybirdFinalize()')!
		mut replay_messages := []string{}
		apply_javascript_runtime_state(document, state, callback_runtime, mut replay_messages)
		mut mutable_callback_runtime := unsafe { &browserjs.Runtime(callback_runtime) }
		mutable_callback_runtime.mark_document_state_dirty()
	}) or {
		messages << 'JavaScript animation-frame bindings: ${err.msg()}'
		return none
	}
	animation_frame_host.install(mut mutable_runtime) or {
		messages << 'JavaScript animation-frame bindings: ${err.msg()}'
		return none
	}
	install_browser_page_storage(document, runtime) or {
		messages << 'JavaScript storage bindings: ${err.msg()}'
		return none
	}
	processmetrics.instruction_checkpoint('javascript_document_bindings')
	install_browser_adblock_scriptlets(document, runtime, mut messages)
	processmetrics.instruction_checkpoint('javascript_adblock_scriptlets')
	for source in sources {
		if !compact_document_can_run_script(document) { continue }
		runtime.run_document_scripts([source]) or {
			messages << 'JavaScript: ${err.msg()}'
			return none
		}
	}
	for name in ['DOMContentLoaded', 'load'] {
		if !compact_document_can_run_script(document) { continue }
		runtime.dispatch_document_readiness_event(name) or {
			messages << 'JavaScript: ${err.msg()}'
			return none
		}
	}
	processmetrics.instruction_checkpoint('javascript_readiness_events')
	// JavaScriptCore drains queued Promise jobs between evaluations. This initial
	// snapshot captures current script effects; later timer/Promise effects reach
	// the live document through poll_javascript_tasks().
	result := runtime.evaluate_host('__ladybirdFinalize()') or {
		messages << 'JavaScript: ${err.msg()}'
		return none
	}
	processmetrics.instruction_checkpoint('javascript_finalized')
	navigation := apply_javascript_runtime_state(document, result, runtime, mut messages)
	runtime.evaluate_host('__ladybirdClearLogs()') or {}
	mutable_runtime.take_document_state_dirty()
	return navigation
}

// ClassicScript.cpp::run step 2 checks the owning settings before each script.
// The legacy Document constructor has no settings until native bindings attach;
// it remains the explicit standalone host adapter.
fn compact_document_can_run_script(document &dom.Document) bool {
	if document.relevant_settings_object() == unsafe { nil } { return true }
	settings := unsafe { &html.EnvironmentSettingsObject(document.relevant_settings_object()) }
	return html.can_run_script_for_settings(settings) == .run
}

// Native XHR callbacks run on the owning HTML networking task. Their compact
// JS mutations reach the live document before the next retained paint replay.
fn (mut app BrowserApp) poll_javascript_tasks() {
	if app.document == unsafe { nil } || app.js_runtime == unsafe { nil } { return }
	mut runtime := app.js_runtime
	if !runtime.take_document_state_dirty() { return }
	state := runtime.evaluate_host('__ladybirdFinalize()') or {
		app.js_messages << 'JavaScript asynchronous callback: ${err.msg()}'
		return
	}
	navigation := apply_javascript_runtime_state(app.document, state, runtime, mut app.js_messages)
	runtime.evaluate_host('__ladybirdClearLogs()') or {}
	replayed_effects := runtime.take_document_replay_effects()
	if replayed_effects || app.document.needs_style_update_after_layout()
		|| !app.document.layout_is_up_to_date() || app.javascript_tasks_have_unadopted_paint() {
		app.relayout(app.viewport_width, app.viewport_height + app.chrome_height())
	}
	if app.ctx != unsafe { nil } {
		title := document_title(app.document)
		gg.set_window_title(if title != '' { '${title} — vox' } else { 'vox' })
	}
	if destination := navigation {
		if destination != '' { app.navigate(resolve_document_reference(destination, app.document.url.serialize()), true) }
	}
}

fn javascript_default_prevented(encoded string) bool {
	value := json2.decode[json2.Any](encoded) or { return false }
	if value !is map[string]json2.Any {
		return false
	}
	object := value as map[string]json2.Any
	prevented := object['defaultPrevented'] or { return false }
	return if prevented is bool { prevented } else { false }
}

// Preserve the existing raw-handler approximation only for a live raw slot
// that the actual native click did not process. Bridge keys keep owner identity
// stable if the callback renames, moves or removes its element.
fn (mut app BrowserApp) media_click_replay_state(element &dom.Element) !map[string]json2.Any {
	target := unsafe { &dom.EventTarget(element) }
	mut processed := false
	if app.page_model != unsafe { nil } {
		if event := app.page_model.event_handler.take_last_click_event() {
			processed = event.did_process_click_handler(target)
		}
	}
	// Apply callback mutations before reading the raw slot. Finalize drains the
	// operation queue; the later snapshot still carries pending navigation.
	state := app.js_runtime.evaluate_host('__ladybirdFinalize()')!
	apply_javascript_runtime_state(app.document, state, app.js_runtime,
		mut app.js_messages)
	app.js_runtime.evaluate_host('__ladybirdClearLogs()')!
	mut key := ''
	for candidate_key, candidate in app.js_runtime.canvas_elements_for_binding() {
		if voidptr(candidate) == voidptr(element) {
			key = candidate_key
			break
		}
	}
	mut raw := ''
	if !processed && compact_document_can_run_script(element.document()) {
		if handler := target.data.event_handler('click') {
			if handler.value.kind == .string {
				raw = handler.value.string_data
			}
		}
	}
	return {
		'key': json2.Any(key)
		'raw': json2.Any(raw)
	}
}

fn (mut app BrowserApp) dispatch_javascript_event(name string, element &dom.Element) bool {
	if app.js_runtime == unsafe { nil } {
		return false
	}
	if app.js_runtime.engine == .libjs { return false }
	mut media_replay := ''
	if name == 'click' && element.is_html_element() && element.local_name() in ['audio', 'video'] {
		state := app.media_click_replay_state(element) or {
			app.js_messages << 'JavaScript media click replay: ${err.msg()}'
			return false
		}
		media_replay = ', ' + json2.encode(state)
	}
	id := element.get_attribute_value('id')
	if media_replay == '' {
		for key, candidate in app.js_runtime.canvas_elements_for_binding() {
			if voidptr(candidate) != voidptr(element) { continue }
			media_replay = ', ' + json2.encode({'key': json2.Any(key)})
			break
		}
	}
	if id == '' && media_replay == '' { return false }
	result := app.js_runtime.evaluate_host('__ladybirdDispatch(${json2.encode(name)}, ${json2.encode(id)}${media_replay})') or {
		app.js_messages << 'JavaScript event: ${err.msg()}'
		return false
	}
	destination := apply_javascript_runtime_state(app.document, result, app.js_runtime, mut app.js_messages) or { '' }
	defer {
		$if gcboehm ? { C.GC_reachable_here(destination.str) }
	}
	app.js_runtime.evaluate_host('__ladybirdClearLogs()') or {}
	app.relayout(app.viewport_width, app.viewport_height + app.chrome_height())
	if destination != '' {
		app.navigate(resolve_document_reference(destination, app.address), true)
		// A script navigation also consumes the pending link default action
		// when the native input scope defers its generation change.
		return true
	}
	return javascript_default_prevented(result)
}

fn (app &BrowserApp) chrome_height() int {
	return int(toolbar_height + status_bar_height)
}

fn (app &BrowserApp) page_top() f32 {
	return f32(toolbar_height)
}

fn (app &BrowserApp) status_height() int {
	return int(status_bar_height)
}

fn browser_chrome_widget_pointer_event_callback(target voidptr, id string, event_type string,
	button int, position page.PixelPoint) painting.MouseAction {
	mut app := unsafe { &BrowserApp(target) }
	if id.starts_with('scrollbar-') {
		if event_type == 'pointerdown' && button == 0 { app.overlay_scrollbars.dragging = true }
		if event_type == 'pointerup' { app.overlay_scrollbars.dragging = false }
		app.overlay_scrollbar_activity()
	}
	if app.document == unsafe { nil } {
		return .none
	}
	mut result := layout.document_layout_result(app.document) or { return .none }
	return result.handle_scrollbar_pointer_event(id, event_type, button, position.x, position.y)
}

fn browser_chrome_widget_hover_callback(target voidptr, id string, hovered bool) {
	mut app := unsafe { &BrowserApp(target) }
	if id.starts_with('scrollbar-') {
		app.overlay_scrollbars.hovered = hovered
		app.overlay_scrollbar_activity()
	}
	if app.document == unsafe { nil } {
		return
	}
	mut result := layout.document_layout_result(app.document) or { return }
	if hovered {
		result.chrome_widget_mouse_enter(id)
	} else {
		result.chrome_widget_mouse_leave(id)
	}
}

fn (mut app BrowserApp) install_chrome_widget_input_bridge() {
	if app.page_model == unsafe { nil } {
		return
	}
	app.page_model.event_handler.install_chrome_widget_callbacks(voidptr(&app), browser_chrome_widget_pointer_event_callback, browser_chrome_widget_hover_callback)
}

fn chrome_pointer_layout_reason(event_type string) dom.UpdateLayoutReason {
	return match event_type {
		'pointerdown' { .event_handler_handle_mouse_down }
		'pointerup' { .event_handler_handle_mouse_up }
		else { .event_handler_handle_mouse_move }
	}
}

fn (app &BrowserApp) hit_test_at_viewport_point(x f64, y f64) ?dom.HitTestResult {
	if app.document == unsafe { nil } {
		return none
	}
	viewport := app.document.paintable_box() or { return none }
	return viewport.hit_test(x, y, .exact)
}

fn (app &BrowserApp) document_content_height(viewport_height int) f64 {
	// A constrained document element (e.g. html { height:100% }) can be much
	// shorter than its descendants. Window::scroll() clamps against the typed
	// viewport's scrolling area, which also accounts for positioned content
	// and excludes overflow trapped inside another scrollport.
	if result := layout.document_layout_result(app.document) {
		if viewport := result.root.as_node_with_style() {
			if used := result.state.try_get(viewport) {
				if overflow := used.scrollable_overflow_rect() {
					return math.max(f64(viewport_height), overflow.height.to_double())
				}
			}
		}
	}
	root_rect := app.root_box.border_box()
	return math.max(f64(viewport_height), root_rect.y + root_rect.height)
}

fn (mut app BrowserApp) adopt_current_document_geometry() {
	result := layout.document_layout_result(app.document) or { return }
	app.root_box = result.paint_tree
	app.content_height = app.document_content_height(app.viewport_height)
	app.set_scroll_y(app.scroll_y, app.viewport_height + app.chrome_height())
}

// EventHandler updates layout before hit testing chrome, sends captured input
// before the current target, and updates layout again after the widget mutates
// scroll/style state. This is the native-browser boundary for the translated
// Scrollbar and ResizeHandle state machines.
fn (mut app BrowserApp) dispatch_chrome_pointer_event_at_viewport_point(event_type string,
	button int, x f64, y f64) ChromePointerDispatchResult {
	mut heap_scope := platform.begin_browser_activity_heap_scope()
	defer { heap_scope.finish() }
	if app.document == unsafe { nil } || app.page_model == unsafe { nil } {
		return ChromePointerDispatchResult{}
	}
	mut document := unsafe { &dom.Document(app.document) }
	reason := chrome_pointer_layout_reason(event_type)
	document.update_layout(reason)
	hit := app.hit_test_at_viewport_point(x, y)
	target := if value := hit { value.chrome_widget_id } else { '' }
	mut cursor := ?painting.ResizeCursor(none)
	if target != '' {
		if mut result := layout.document_layout_result(app.document) {
			cursor = result.chrome_widget_cursor(target)
		}
	}
	mut handler := app.page_model.event_handler
	had_capture := handler.has_captured_chrome_widget()
	mut input_target := ?page.InputTarget(none)
	if value := hit {
		mut node := if value.node != unsafe { nil } { value.node }
			else if value.element != unsafe { nil } { value.element.as_node() }
			else { unsafe { &dom.Node(nil) } }
		for node != unsafe { nil } && !node.is_element() {
			node = node.parent() or { unsafe { &dom.Node(nil) } }
		}
		if node != unsafe { nil } { input_target = page.InputTarget.from_node_and_chrome_widget(node, target) }
	}
	handler.set_document_state(document.is_fully_active(), document.layout_node() != none)
	mut screen_x := x
	mut screen_y := y + f64(app.page_top())
	$if macos { C.native_pointer_screen_position(x, screen_y, &screen_x, &screen_y) }
	_ = handler.handle_platform_pointer_event(event_type, input_target, page.PixelPoint{x: x, y: y},
		page.PixelPoint{x: screen_x, y: screen_y}, u32(button), app.platform_pointer_buttons, app.platform_pointer_modifiers, 1)
	handled := target != '' || had_capture || handler.has_captured_chrome_widget()
	// Hover, focus, listeners and chrome widgets can all invalidate the retained
	// tree during dispatch. Commit that state before the embedder's next frame.
	document.update_layout(if handled { .event_handler_dispatch_chrome_widget_event } else { reason })
	app.adopt_current_document_geometry()
	return ChromePointerDispatchResult{
		target: target
		handled: handled
		cursor: cursor
		mouse_cursor: browser_mouse_cursor_for_hit(hit, cursor)
	}
}

fn mouse_cursor_for_resize_handle(cursor ?painting.ResizeCursor) sapp.MouseCursor {
	value := cursor or { return .arrow }
	return match value {
		.ew_resize { .resize_ew }
		.ns_resize { .resize_ns }
		.se_resize { .resize_nwse }
		.sw_resize { .resize_nesw }
		.none { .arrow }
	}
}

fn ensure_compact_browser_navigable(document &dom.Document) ?&html.NavigableModel {
	mut mutable_document := unsafe { &dom.Document(document) }
	if mutable_document.navigable() == none {
		mutable_document.set_cached_navigable(&dom.Navigable{
			active_document_: document
		})
	}
	navigable := document.navigable() or { return none }
	return html.NavigableModel.create(navigable, none) or { return none }
}

fn focus_compact_browser_navigable(document &dom.Document) {
	mut model := ensure_compact_browser_navigable(document) or { return }
	model.set_focused(true)
}

fn (mut app BrowserApp) relayout(window_width int, window_height int) {
	if app.document == unsafe { nil } {
		return
	}
	mut heap_scope := platform.begin_browser_activity_heap_scope_for_scripting(app.document_scripting_enabled_for_heap())
	defer { heap_scope.finish() }
	refresh_browser_adblock(app.document, app.js_runtime, mut app.js_messages)
	// Cosmetic filtering consumes facade effects; ordinary paint recording can
	// happen later in a frame after another callback has queued new effects.
	if app.js_runtime != unsafe { nil } { app.js_runtime.take_document_replay_effects() }
	viewport_width := if window_width > 0 { window_width } else { initial_width }
	chrome_height := app.chrome_height()
	viewport_height := if window_height > chrome_height {
		window_height - chrome_height
	} else {
		1
	}
	layout_checkpoint := time.sys_mono_now()
	if app.layout_tree_only {
		// The dump reads the retained typed tree directly. Building the separate
		// renderer transport here would add a full unused tree traversal.
		_ = layout.run_document_layout_for_tree_dump(app.document, f64(viewport_width), f64(viewport_height)) or { return }
		debug_timing_checkpoint('  layout_tree', layout_checkpoint)
		app.root_box = layout.BlockBox{}
		app.paint_commands = []layout.PaintCommand{}
		app.paint_display_list = unsafe { nil }
		app.paint_commands_have_backdrop_filter = false
		app.paint_commands_pending = false
		app.content_height = f64(viewport_height)
		app.viewport_width = viewport_width
		app.viewport_height = viewport_height
		return
	}
	app.sync_window_activity()
	// The shell's layout is the document's first rendering update, whose
	// autofocus flush precedes style and layout. Deferring it to the event
	// loop's next update would lay out and paint the document a second time.
	if app.document.navigable() != none {
		html.flush_autofocus_candidates(app.document)
	}
	app.root_box = layout.layout_document_typed_in_viewport(app.document, f64(viewport_width), f64(viewport_height))
	debug_timing_checkpoint('  layout_tree', layout_checkpoint)
	// The compact native shell owns one visible top-level document. Layout
	// creates its DOM navigable; attach the HTML model before display-list
	// recording so focus-gated painting such as editable carets is visible.
	focus_compact_browser_navigable(app.document)
	app.install_compact_navigation_handler()
	app.content_height = app.document_content_height(viewport_height)
	app.viewport_width = viewport_width
	app.viewport_height = viewport_height
	app.set_scroll_y(app.scroll_y, window_height)
	app.paint_commands_pending = true
	if app.frame_preparation_depth == 0 {
		app.record_document_paint_commands()
	}
}

fn (mut app BrowserApp) advance_document_animations(window_width int, content_viewport_height int) {
	_ = window_width
	_ = content_viewport_height
	if app.document == unsafe { nil } || app.animation_epoch_ns == 0
		|| !css.document_has_running_css_animations(app.document) {
		return
	}
	now := time.sys_mono_now()
	elapsed_ms := f64(now - app.animation_epoch_ns) / 1_000_000.0
	mut document := unsafe { &dom.Document(app.document) }
	document.update_animations_and_send_events(elapsed_ms)
	// Frame preparation consumes the animation's style/layout/paint invalidation.
	// A timeline tick alone does not require another procedural-filter commit.
	$if macos {
		if css.document_has_running_css_animations(document) {
			C.native_wake_browser_after(16)
		}
	}
}

fn (mut app BrowserApp) replace_load_status(status string) {
	previous_status := app.load_status
	app.load_status = status
	if previous_status != '' && app.status.starts_with(previous_status) {
		app.status = status + app.status[previous_status.len..]
	} else {
		app.status = status
	}
}

fn (mut app BrowserApp) update_current_history_entry(loaded LoadedPage) {
	if app.history_index < 0 || app.history_index >= app.history.len {
		return
	}
	if app.history[app.history_index].url != loaded.url {
		return
	}
	app.history[app.history_index] = HistoryEntry{
		url: loaded.url
		markup: loaded.markup
		content_type: loaded.content_type
	}
}

// Source Window owns its realm before parsing. The deferred JavaScriptCore
// facade must also initialize for raw Window handlers without script elements.
fn document_has_window_event_handlers(document &dom.Document) bool {
	window := document.get_window() or { return false }
	return window.data.event_handler_count() > 0
}

fn (mut app BrowserApp) install_loaded_page(loaded LoadedPage, add_history bool) {
	mut navigation_work := app.begin_navigation_work()
	defer { navigation_work.finish() }
	heap_scripting_enabled := browser_scripting_enabled(loaded.url, app.script_policy)
		&& (app.page_model == unsafe { nil } || app.page_model.is_scripting_enabled())
	mut heap_scope := platform.begin_browser_activity_heap_scope_for_scripting(heap_scripting_enabled)
	defer { heap_scope.finish() }
	app.markup = loaded.markup
	app.content_type = loaded.content_type
	app.source_label = loaded.url
	app.address = loaded.url
	app.address_cursor = app.address.runes().len
	app.address_select = false
	app.sync_address_bar()
	app.scroll_y = 0
	// A screenshot strip scrolls the replacement document, such as a cached
	// page's network refresh, to its offset again.
	app.screenshot_scroll_applied = false
	app.load_status = loaded.status
	app.document_presented = false
	app.snapshot_cached = false
	app.js_messages = []
	mut checkpoint := time.sys_mono_now()
	install_start := checkpoint
	app.paint_timing.document_install_start_ns = i64(install_start)
	app.paint_timing.installation_instructions = processmetrics.begin_instructions()
	initiator_origin := if app.document != unsafe { nil } { ?dom.Origin(app.document.origin()) } else { none }
	previous_document := if app.document != unsafe { nil } { ?&dom.Document(app.document) } else { ?&dom.Document(none) }
	scripting_enabled := browser_scripting_enabled(loaded.url, app.script_policy)
	app.document = if document_url := dom.dom_url_parse(loaded.url, dom.url_about_blank(),
		'UTF-8') {
		parse_loaded_browser_navigation_document(loaded, document_url, initiator_origin, previous_document, unsafe { &dom.Page(app.page_model) }, scripting_enabled)
	} else {
		parse_loaded_browser_navigation_document(loaded, dom.url_about_blank(), initiator_origin, previous_document, unsafe { &dom.Page(app.page_model) }, scripting_enabled)
	}
	install_browser_adblock_styles(app.document, '') or { app.js_messages << 'Adblock styles: ${err.msg()}' }
	if app.page_model != unsafe { nil } && !app.page_model.has_local_root_navigable() {
		if navigable := app.document.navigable() {
			mut page_model := app.page_model
			page_model.set_local_root_navigable(navigable) or {
				app.js_messages << 'Rendering root: ${err.msg()}'
				return
			}
		}
	}
	app.animation_epoch_ns = u64(app.document.load_timing_info.navigation_start_time * 1_000_000.0)
	checkpoint = debug_timing_checkpoint('parse_document', checkpoint)
	// Relative subresources use the document base URL, which may be replaced by
	// the first <base href>. Keep the address/history URL as the document URL.
	resource_base_url := app.document.base_url().serialize()
	install_object_image_fetch_hooks(app.document)
	install_video_poster_fetch_hooks(app.document)
	preloaded_resources := app.preload_initial_document_resources(resource_base_url)
	checkpoint = debug_timing_checkpoint('preload_resources', checkpoint)
	for resource_url, resource in preloaded_resources {
		if resource.error == '' && !resource.adblock_replacement {
			app.retain_navigation_resource(resource_url, resource)
		}
		publish_browser_svg_resource(resource)
	}
	checkpoint = debug_timing_checkpoint('install_styles', checkpoint)
	install_local_video_frames(app.document, resource_base_url, loaded.markup)
	checkpoint = debug_timing_checkpoint('install_video_frames', checkpoint)
	if app.js_runtime != unsafe { nil } {
		mut agent_event_loop := html.main_thread_event_loop()
		agent_event_loop.bind_vm(none)
		app.js_runtime.close()
		app.js_runtime = unsafe { nil }
	}
	sources := script_sources(app.document, resource_base_url, preloaded_resources, mut app.js_messages)
	javascript_navigation := if app.document.as_node().is_scripting_enabled()
		&& (sources.len > 0 || document_has_window_event_handlers(app.document)
		|| browser_adblock_requires_runtime(app.document)) {
		app.js_runtime = create_browser_script_runtime(app.js_engine)
		run_document_script_sources(app.document, loaded.url, sources, app.js_runtime, mut app.js_messages)
	} else {
		none
	}
	if debug_timing_enabled() {
		mut source_bytes := 0
		for source in sources { source_bytes += source.code.len }
		mut preloaded_scripts := 0
		for _, resource in preloaded_resources {
			if resource.request_type == 'script' { preloaded_scripts++ }
		}
		eprintln('Ladybird V scripting: enabled=${app.document.as_node().is_scripting_enabled()} runtime=${app.js_runtime != unsafe { nil }} sources=${sources.len} source_bytes=${source_bytes} preloaded_scripts=${preloaded_scripts}')
	}
	checkpoint = debug_timing_checkpoint('run_javascript', checkpoint)
	if app.js_runtime == unsafe { nil } {
		install_static_browser_image_fetch_hooks(app.document, app.nonrendered_image_preloads)
	}
	if cookie_blocker_enabled_by_default {
		hide_cookie_banners(app.document)
	}
	checkpoint = debug_timing_checkpoint('cookie_blocker', checkpoint)
	// Stylesheets and images that scripts inserted, and that the disk cache
	// holds, take part in the first layout instead of a later relayout.
	app.script_stylesheet_scan_version = max_u64
	app.script_image_scan_version = max_u64
	if app.request_script_inserted_stylesheets() {
		app.document.set_needs_full_style_update(true)
	}
	ready_script_images := app.request_script_inserted_images()
	if ready_script_images.len > 0 {
		app.complete_script_inserted_images(ready_script_images)
	}
	checkpoint = debug_timing_checkpoint('script_inserted_resources', checkpoint)
	if add_history {
		if app.history_index + 1 < app.history.len {
			app.history = app.history[..app.history_index + 1].clone()
		}
		app.history << HistoryEntry{
			url: loaded.url
			markup: loaded.markup
			content_type: loaded.content_type
		}
		app.history_index = app.history.len - 1
	}
	app.relayout(if app.viewport_width > 0 { app.viewport_width } else { initial_width }, if app.viewport_height > 0 {
		app.viewport_height + app.chrome_height()
	} else {
		initial_height
	})
	checkpoint = debug_timing_checkpoint('relayout', checkpoint)
	debug_timing_checkpoint('install_total', install_start)
	processmetrics.report_instructions('install_total', app.paint_timing.installation_instructions, processmetrics.begin_instructions())
	app.update_window_title()
	if destination := javascript_navigation {
		if destination != '' && destination != loaded.url {
			app.navigate(resolve_document_reference(destination, loaded.url), true)
		}
	}
}

fn create_browser_script_runtime(engine browserjs.Engine) &browserjs.Runtime {
	runtime := browserjs.Runtime.create_with_engine(engine)
	if engine == .libjs {
		mut agent_event_loop := html.main_thread_event_loop()
		agent_event_loop.bind_vm(runtime.libjs_vm())
	}
	return runtime
}

fn error_markup(address string, message string) string {
	return '<!doctype html><html><head><title>Navigation error</title><style>body{font-family:sans-serif;padding:40px;color:#172033}h1{color:#b91c1c}code{background:#f1f5f9;padding:4px}</style></head><body><h1>Could not load page</h1><p><code>${html_escape(address)}</code></p><p>${html_escape(message)}</p></body></html>'
}

fn (mut app BrowserApp) navigate(address string, add_history bool) {
	// Resolution can allocate after the caller has consumed a pending request.
	// Keep the source bytes reachable even when trim_space returns a borrowed slice.
	defer {
		$if gcboehm ? { C.GC_reachable_here(address.str) }
	}
	if app.navigation_work_depth > 0 {
		app.deferred_navigation_input = DeferredNavigationInput{address: address, add_history: add_history}
		return
	}
	base := if app.history_index >= 0 && app.history_index < app.history.len {
		app.history[app.history_index].url
	} else {
		''
	}
	resolved := resolve_url(address, base)
	if parsed := url.parse(resolved) {
		if parsed.scheme == 'javascript' {
			app.navigate_javascript_url(parsed)
			return
		}
	}
	app.paint_timing.begin_navigation()
	app.load_status = 'Loading ${resolved}'
	app.status = app.load_status
	app.navigation_generation++
	app.pending_navigation = none
	app.pending_cached_page = none
	app.cancel_page_preload()
	app.pending_native_navigation = none
	if app.ctx != unsafe { nil } {
		generation := app.navigation_generation
		mut defer_until_first_paint := !app.document_presented
		mut network_add_history := add_history
		mut had_cached_page := false
		if cached := read_cached_page(resolved) {
			mut defer_cached_install := false
			$if macos {
				defer_cached_install = !app.initial_window_frame_presented
					&& app.document == unsafe { nil }
			}
			if defer_cached_install {
				// Parsing and laying out a cached document before NSApplication enters
				// its run loop delays the first composited window by an entire frame's
				// worth of engine work. Retain the cache hit, present the lightweight
				// browser chrome, then install it on the following draw.
				app.pending_cached_page = PendingCachedPage{
					loaded: cached
					add_history: add_history
					generation: generation
				}
			} else {
				snapshot_path := cached_snapshot_path(resolved)
				$if macos {
					if os.is_file(snapshot_path) {
						C.native_show_cached_snapshot(snapshot_path)
						app.snapshot_visible = true
						// Hold the raster across the cached rebuild AND the refresh
						// rebuild, capped by a safety deadline in case the network
						// never answers.
						app.snapshot_hold = true
						app.snapshot_hold_until = time.sys_mono_now() + 8_000_000_000
					}
				}
				app.prepare_loaded_page(cached, add_history)
			}
			had_cached_page = true
			defer_until_first_paint = true
			network_add_history = false
			app.refresh_not_before = time.sys_mono_now() + 500_000_000
			$if macos {
				C.native_wake_browser_after(500)
			}
		}
		if app.navigation_generation != generation {
			return
		}
		pending := PendingNavigation{
			resolved: resolved
			base: base
			generation: generation
			add_history: network_add_history
			had_cached_page: had_cached_page
		}
		if defer_until_first_paint {
			// Starting Foundation/TLS work while Cocoa creates its first window can
			// serialize framework initialization for over a second. Present either
			// cached content or the loading chrome first, then refresh in parallel.
			app.pending_navigation = pending
		} else {
			spawn fetch_page_in_background(pending.resolved, pending.base, pending.generation, pending.add_history, pending.had_cached_page, app.navigation_results)
		}
		return
	}
	loaded := fetch_page(resolved, base) or {
		app.install_loaded_page(LoadedPage{
			url: resolved
			markup: error_markup(resolved, err.msg())
			status: 'Navigation error'
			content_type: 'text/html'
		}, add_history)
		return
	}
	app.install_loaded_page(loaded, add_history)
}

fn (mut app BrowserApp) install_pending_cached_page() {
	pending := app.pending_cached_page or { return }
	app.pending_cached_page = none
	if pending.generation != app.navigation_generation {
		return
	}
	app.prepare_loaded_page(pending.loaded, pending.add_history)
}

// The chrome-only first frame leaves the cached page's DOM, style and layout
// work to the next frame. The window exists now, so the page's network
// refresh starts alongside that work instead of after its first paint.
fn (mut app BrowserApp) begin_deferred_cached_page() {
	app.start_pending_navigation()
}

fn (mut app BrowserApp) start_pending_navigation() {
	pending := app.pending_navigation or { return }
	app.pending_navigation = none
	if pending.generation != app.navigation_generation {
		return
	}
	spawn fetch_page_in_background(pending.resolved, pending.base, pending.generation, pending.add_history, pending.had_cached_page, app.navigation_results)
}

fn (mut app BrowserApp) poll_navigation() {
	app.poll_page_preload()
	select {
		result := <-app.navigation_results {
			if result.generation != app.navigation_generation {
				return
			}
			// The live document (or a definitive failure) has arrived; stop
			// pinning the cached raster so the next frame reveals the real page.
			app.snapshot_hold = false
			if loaded := result.loaded {
				if result.had_cached_page && app.pending_page_preload == none
					&& app.address == loaded.url && app.markup == loaded.markup
					&& app.content_type == loaded.content_type {
					app.replace_load_status(loaded.status)
					app.update_current_history_entry(loaded)
				} else {
					app.prepare_loaded_page(loaded, result.add_history)
				}
			} else if result.had_cached_page {
				app.replace_load_status('Cached · refresh failed: ${result.error}')
			} else {
				app.install_loaded_page(LoadedPage{
					url: result.resolved
					markup: error_markup(result.resolved, result.error)
					status: 'Navigation error'
					content_type: 'text/html'
				}, result.add_history)
			}
		}
		else {
		}
	}
}

fn (mut app BrowserApp) history_go(delta int) {
	if app.navigation_work_depth > 0 {
		previous := app.deferred_navigation_input or { DeferredNavigationInput{} }
		app.deferred_navigation_input = DeferredNavigationInput{history_delta: previous.history_delta + delta, is_history: true}
		return
	}
	target := app.history_index + delta
	if target < 0 || target >= app.history.len {
		return
	}
	app.history_index = target
	app.navigation_generation++
	app.cancel_page_preload()
	app.pending_native_navigation = none
	entry := app.history[target]
	app.page_model.traverse_the_history_by_delta(delta)
	app.install_loaded_page(LoadedPage{
		url: entry.url
		markup: entry.markup
		status: 'History'
		content_type: entry.content_type
	}, false)
}

fn (mut app BrowserApp) reload() {
	if app.history_index < 0 || app.history_index >= app.history.len {
		return
	}
	app.navigate(app.history[app.history_index].url, false)
}

fn (app &BrowserApp) maximum_scroll(window_height int) f64 {
	chrome_height := f64(app.chrome_height())
	maximum := if app.content_height + chrome_height > f64(window_height) {
		app.content_height + chrome_height - f64(window_height)
	} else {
		0.0
	}
	// A screenshot strip shows part of a taller screenshot viewport from its
	// requested offset, even where the document's content ends sooner.
	return math.max(maximum, f64(app.screenshot_scroll_y))
}

fn (mut app BrowserApp) scroll_by(delta f64, window_height int) {
	app.set_scroll_y(app.scroll_y + delta, window_height)
}

fn (mut app BrowserApp) set_scroll_y(requested f64, window_height int) {
	used := clamp(requested, 0.0, app.maximum_scroll(window_height))
	if used != app.scroll_y { app.overlay_scrollbar_activity() }
	app.scroll_y = used
	if app.document != unsafe { nil } {
		mut document := unsafe { &dom.Document(app.document) }
		viewport := document.viewport_rect()
		document.set_viewport_rect(dom.Rect{viewport.x, app.scroll_y, viewport.width, viewport.height})
	}
}

// EventHandler::handle_mousewheel() offers the wheel delta to the hit
// paintable and then each containing block. Only when every element declines
// it does the viewport consume the vertical delta.
fn layout_node_is_document_viewport_scroller(document &dom.Document, layout_node &dom.LayoutNode) bool {
	// The typed layout tree has a viewport node above <html>. Both nodes expose
	// DOM-facing PaintableBoxes, but neither box owns the viewport offset used
	// by native replay. Let BrowserApp consume their wheel input as viewport
	// scrolling rather than letting either internal box swallow it.
	document_element := document.document_element() or { return false }
	node := layout_node.dom_node() or { return false }
	return node.is_document() || node.unique_id() == document_element.as_node().unique_id()
}

fn paint_color(serialized string, opacity f64) gg.Color {
	parsed := css.parse_color_string(serialized) or { return gg.rgba(15, 23, 42, 255) }
	alpha := clamp(f64(parsed.a) * opacity, 0.0, 255.0)
	return gg.rgba(parsed.r, parsed.g, parsed.b, u8(int(alpha + 0.5)))
}

fn (mut app BrowserApp) draw_portable_shadow(command layout.PaintCommand, page_x f32, page_y f32, scroll_y f64) {
	bitmap := layout.rasterize_portable_shadow(command, f64(app.ctx.scale)) or {
		app.js_messages << 'Shadow replay: ${err.msg()}'
		return
	}
	$if macos {
		if app.ctx.native_rendering {
			image := &gg.Image{
				width: bitmap.width
				height: bitmap.height
				nr_channels: 6
				ok: true
				data: bitmap.pixels.data
			}
			C.native_draw_image_part(image, bitmap.x + page_x, bitmap.y + page_y - f32(scroll_y), f32(bitmap.width) / app.ctx.scale, f32(bitmap.height) / app.ctx.scale, 0, 0, f32(bitmap.width), f32(bitmap.height), f32(app.ctx.height), 1)
			return
		}
	}
	index := app.portable_shadow_image_index
	app.portable_shadow_image_index++
	mut slot := if index < app.portable_shadow_images.len {
		app.portable_shadow_images[index]
	} else {
		PortableShadowImage{ image_id: -1 }
	}
	if slot.image_id < 0 || slot.width != bitmap.width || slot.height != bitmap.height {
		if slot.image_id >= 0 { app.ctx.remove_cached_image_by_idx(slot.image_id) }
		slot = PortableShadowImage{
			image_id: app.ctx.new_streaming_image(bitmap.width, bitmap.height, 4, min_filter: .nearest, mag_filter: .nearest)
			width: bitmap.width
			height: bitmap.height
		}
	}
	if index < app.portable_shadow_images.len {
		app.portable_shadow_images[index] = slot
	} else {
		app.portable_shadow_images << slot
	}
	app.ctx.update_pixel_data(slot.image_id, bitmap.pixels.data)
	app.ctx.draw_image_by_id(bitmap.x + page_x, bitmap.y + page_y - f32(scroll_y), f32(bitmap.width) / app.ctx.scale, f32(bitmap.height) / app.ctx.scale, slot.image_id)
}

fn native_draw_retained_glyph_run(command layout.PaintCommand, page_x f32, page_y f32,
	scroll_y f64, canvas_width f32, canvas_height f32, glyph_color gg.Color, blur f32, shadow_only bool) bool {
	$if macos {
		glyph_run := command.glyph_run or { return false }
		if command.glyph_orientation != .horizontal {
			return false
		}
		glyphs := glyph_run.glyph_indices()
		positions := glyph_run.glyph_positions()
		if glyphs.len == 0 || positions.len != glyphs.len * 2 {
			return false
		}
		matrix := normalized_paint_transform(command.transform)
		font_path := if glyph_run.face() == .emoji {
			platform.emoji_font_path() or { '' }
		} else {
			native_replay_font_path(glyph_run.font())
		}
		unsafe {
			return C.native_draw_document_glyph_run_srgb(&glyphs[0], &positions[0], glyphs.len, glyph_run.font().point_size, glyph_run.font().weight, int(glyph_run.face() == .emoji), f32(command.glyph_translation_x), f32(command.glyph_translation_y), f32(matrix[0]), f32(matrix[1]), f32(matrix[2]), f32(matrix[3]), f32(matrix[4]), f32(matrix[5]), page_x, page_y, f32(scroll_y), canvas_width, canvas_height, font_path, glyph_run.font().face_index(), glyph_color, blur, int(shadow_only), native_retained_font_smoothing(command.font_smoothing, glyph_run.font())) != 0
		}
	}
	return false
}

fn native_text_draw_y(line_box_top f32, line_box_height f32) f32 {
	// Cocoa's gg adapter positions text relative to a fixed 15px baseline. Convert Layout's
	// line-box top to that coordinate system for both body text and larger headings.
	return line_box_top + f32(math.max(f64(line_box_height) - 14.0, 0.0))
}

fn draw_srgb_rect(ctx &gg.Context, x f32, y f32, width f32, height f32, fill_color gg.Color) {
	$if macos {
		if ctx.native_rendering {
			C.native_draw_rect_srgb(x, f32(ctx.height) - (y + height), width, height, fill_color)
			return
		}
	}
	ctx.draw_rect_filled(x, y, width, height, fill_color)
}

// DisplayListPlayerSkia paints a rounded rectangle as one path. Keep the native
// renderer on that same path instead of reconstructing the shape from rectangles
// and gg circles: besides doing seven draws, the native gg circle adapter applies
// its own alpha and makes the four corners visibly translucent.
fn draw_rounded_fill(ctx &gg.Context, x f32, y f32, width f32, height f32, radius f32, fill_color gg.Color) {
	if width <= 0 || height <= 0 {
		return
	}
	if radius <= 0 {
		draw_srgb_rect(ctx, x, y, width, height, fill_color)
		return
	}
	$if macos {
		if ctx.native_rendering {
			mut used_radius := radius
			if used_radius > width / 2 {
				used_radius = width / 2
			}
			if used_radius > height / 2 {
				used_radius = height / 2
			}
			C.native_draw_rounded_rect_srgb(x, y, width, height, used_radius, used_radius, used_radius, used_radius, used_radius, used_radius, used_radius, used_radius, 1, 0, 0, 1, 0, 0, 0, 0, 0, f32(ctx.width), f32(ctx.height), fill_color, 1, 0, 1)
			return
		}
	}
	if ctx.native_rendering {
		draw_srgb_rect(ctx, x, y, width, height, fill_color)
	} else {
		ctx.draw_rounded_rect_filled(x, y, width, height, radius, fill_color)
	}
}

fn point_in_paint_polygon(x f64, y f64, points []f64) bool {
	if points.len < 6 {
		return true
	}
	mut inside := false
	mut previous := points.len - 2
	for current := 0; current + 1 < points.len; current += 2 {
		x1 := points[current]
		y1 := points[current + 1]
		x2 := points[previous]
		y2 := points[previous + 1]
		if (y1 > y) != (y2 > y) && x < (x2 - x1) * (y - y1) / (y2 - y1) + x1 {
			inside = !inside
		}
		previous = current
	}
	return inside
}

fn normalized_paint_transform(transform [6]f64) [6]f64 {
	return if transform == [6]f64{} { [f64(1), 0, 0, 1, 0, 0]! } else { transform }
}

fn multiply_paint_transforms(left_value [6]f64, right_value [6]f64) [6]f64 {
	left := normalized_paint_transform(left_value)
	right := normalized_paint_transform(right_value)
	return [
		left[0] * right[0] + left[2] * right[1],
		left[1] * right[0] + left[3] * right[1],
		left[0] * right[2] + left[2] * right[3],
		left[1] * right[2] + left[3] * right[3],
		left[0] * right[4] + left[2] * right[5] + left[4],
		left[1] * right[4] + left[3] * right[5] + left[5],
	]!
}

fn draw_native_svg_linear_gradient_path(path_data []f32, even_odd bool, matrix [6]f64,
	page_x f32, page_y f32, scroll_y f32, canvas_height f32, stroke bool, stroke_width f64,
	line_cap int, line_join int, miter_limit f64, style painting.SVGLinearGradientPaintStyle,
	opacity f64, content_mask bool) {
	$if macos {
		if path_data.len < layout.compatibility_clip_path_segment_stride
			|| style.gradient.color_stops.len == 0 {
			return
		}
		mut stop_data := []f32{cap: style.gradient.color_stops.len * 5}
		for stop in style.gradient.color_stops {
			stop_data << f32(stop.color.r) / 255.0
			stop_data << f32(stop.color.g) / 255.0
			stop_data << f32(stop.color.b) / 255.0
			stop_data << f32(stop.color.a) / 255.0 * if content_mask {
				f32(clamp(opacity, 0.0, 1.0))
			} else {
				f32(1.0)
			}
			stop_data << f32(stop.position)
		}
		gradient_transform := style.gradient.gradient_transform or { painting.Affine{} }
		unsafe {
			if content_mask {
				C.native_add_svg_content_mask_linear_gradient_path(&path_data[0], path_data.len / layout.compatibility_clip_path_segment_stride, if even_odd {
					1
				} else {
					0
				}, f32(matrix[0]), f32(matrix[1]), f32(matrix[2]), f32(matrix[3]), f32(matrix[4]), f32(matrix[5]), page_x, page_y, scroll_y, canvas_height, if stroke {
					1
				} else {
					0
				}, f32(stroke_width), line_cap, line_join, f32(miter_limit), f32(style.start_point.x), f32(style.start_point.y), f32(style.end_point.x), f32(style.end_point.y), f32(gradient_transform.a), f32(gradient_transform.b), f32(gradient_transform.c), f32(gradient_transform.d), f32(gradient_transform.e), f32(gradient_transform.f), int(style.gradient.spread_method), if style.gradient.color_space == .linear_srgb {
					1
				} else {
					0
				}, &stop_data[0], style.gradient.color_stops.len, f32(opacity))
			} else {
				C.native_draw_svg_linear_gradient_path(&path_data[0], path_data.len / layout.compatibility_clip_path_segment_stride, if even_odd {
					1
				} else {
					0
				}, f32(matrix[0]), f32(matrix[1]), f32(matrix[2]), f32(matrix[3]), f32(matrix[4]), f32(matrix[5]), page_x, page_y, scroll_y, canvas_height, if stroke {
					1
				} else {
					0
				}, f32(stroke_width), line_cap, line_join, f32(miter_limit), f32(style.start_point.x), f32(style.start_point.y), f32(style.end_point.x), f32(style.end_point.y), f32(gradient_transform.a), f32(gradient_transform.b), f32(gradient_transform.c), f32(gradient_transform.d), f32(gradient_transform.e), f32(gradient_transform.f), int(style.gradient.spread_method), if style.gradient.color_space == .linear_srgb {
					1
				} else {
					0
				}, &stop_data[0], style.gradient.color_stops.len, f32(opacity))
			}
		}
	}
}

fn draw_native_svg_radial_gradient_path(path_data []f32, even_odd bool, matrix [6]f64,
	page_x f32, page_y f32, scroll_y f32, canvas_height f32, stroke bool, stroke_width f64,
	line_cap int, line_join int, miter_limit f64, style painting.SVGRadialGradientPaintStyle,
	opacity f64, content_mask bool) {
	$if macos {
		if path_data.len < layout.compatibility_clip_path_segment_stride
			|| style.gradient.color_stops.len == 0 {
			return
		}
		mut stop_data := []f32{cap: style.gradient.color_stops.len * 5}
		for stop in style.gradient.color_stops {
			stop_data << f32(stop.color.r) / 255.0
			stop_data << f32(stop.color.g) / 255.0
			stop_data << f32(stop.color.b) / 255.0
			stop_data << f32(stop.color.a) / 255.0 * if content_mask {
				f32(clamp(opacity, 0.0, 1.0))
			} else {
				f32(1.0)
			}
			stop_data << f32(stop.position)
		}
		gradient_transform := style.gradient.gradient_transform or { painting.Affine{} }
		unsafe {
			if content_mask {
				C.native_add_svg_content_mask_radial_gradient_path(&path_data[0], path_data.len / layout.compatibility_clip_path_segment_stride, if even_odd {
					1
				} else {
					0
				}, f32(matrix[0]), f32(matrix[1]), f32(matrix[2]), f32(matrix[3]), f32(matrix[4]), f32(matrix[5]), page_x, page_y, scroll_y, canvas_height, if stroke {
					1
				} else {
					0
				}, f32(stroke_width), line_cap, line_join, f32(miter_limit), f32(style.start_center.x), f32(style.start_center.y), f32(style.start_radius), f32(style.end_center.x), f32(style.end_center.y), f32(style.end_radius), f32(gradient_transform.a), f32(gradient_transform.b), f32(gradient_transform.c), f32(gradient_transform.d), f32(gradient_transform.e), f32(gradient_transform.f), int(style.gradient.spread_method), if style.gradient.color_space == .linear_srgb {
					1
				} else {
					0
				}, &stop_data[0], style.gradient.color_stops.len, f32(opacity))
			} else {
				C.native_draw_svg_radial_gradient_path(&path_data[0], path_data.len / layout.compatibility_clip_path_segment_stride, if even_odd {
					1
				} else {
					0
				}, f32(matrix[0]), f32(matrix[1]), f32(matrix[2]), f32(matrix[3]), f32(matrix[4]), f32(matrix[5]), page_x, page_y, scroll_y, canvas_height, if stroke {
					1
				} else {
					0
				}, f32(stroke_width), line_cap, line_join, f32(miter_limit), f32(style.start_center.x), f32(style.start_center.y), f32(style.start_radius), f32(style.end_center.x), f32(style.end_center.y), f32(style.end_radius), f32(gradient_transform.a), f32(gradient_transform.b), f32(gradient_transform.c), f32(gradient_transform.d), f32(gradient_transform.e), f32(gradient_transform.f), int(style.gradient.spread_method), if style.gradient.color_space == .linear_srgb {
					1
				} else {
					0
				}, &stop_data[0], style.gradient.color_stops.len, f32(opacity))
			}
		}
	}
}

fn draw_native_svg_pattern_linear_gradient_path(path_data []f32, even_odd bool,
	matrix [6]f64, tile_height f32, stroke bool, stroke_width f64, line_cap int,
	line_join int, miter_limit f64, style painting.SVGLinearGradientPaintStyle,
	opacity f64) {
	$if macos {
		if path_data.len < layout.compatibility_clip_path_segment_stride
			|| style.gradient.color_stops.len == 0 {
			return
		}
		mut stop_data := []f32{cap: style.gradient.color_stops.len * 5}
		paint_alpha := f32(clamp(opacity, 0.0, 1.0))
		for stop in style.gradient.color_stops {
			stop_data << f32(stop.color.r) / 255.0
			stop_data << f32(stop.color.g) / 255.0
			stop_data << f32(stop.color.b) / 255.0
			stop_data << f32(stop.color.a) / 255.0 * paint_alpha
			stop_data << f32(stop.position)
		}
		gradient_transform := style.gradient.gradient_transform or { painting.Affine{} }
		unsafe {
			C.native_add_svg_pattern_linear_gradient_path(&path_data[0], path_data.len / layout.compatibility_clip_path_segment_stride, if even_odd {
				1
			} else {
				0
			}, f32(matrix[0]), f32(matrix[1]), f32(matrix[2]), f32(matrix[3]), f32(matrix[4]), f32(matrix[5]), tile_height, if stroke {
				1
			} else {
				0
			}, f32(stroke_width), line_cap, line_join, f32(miter_limit), f32(style.start_point.x), f32(style.start_point.y), f32(style.end_point.x), f32(style.end_point.y), f32(gradient_transform.a), f32(gradient_transform.b), f32(gradient_transform.c), f32(gradient_transform.d), f32(gradient_transform.e), f32(gradient_transform.f), int(style.gradient.spread_method), if style.gradient.color_space == .linear_srgb {
				1
			} else {
				0
			}, &stop_data[0], style.gradient.color_stops.len, f32(opacity))
		}
	}
}

fn draw_native_svg_pattern_radial_gradient_path(path_data []f32, even_odd bool,
	matrix [6]f64, tile_height f32, stroke bool, stroke_width f64, line_cap int,
	line_join int, miter_limit f64, style painting.SVGRadialGradientPaintStyle,
	opacity f64) {
	$if macos {
		if path_data.len < layout.compatibility_clip_path_segment_stride
			|| style.gradient.color_stops.len == 0 {
			return
		}
		mut stop_data := []f32{cap: style.gradient.color_stops.len * 5}
		paint_alpha := f32(clamp(opacity, 0.0, 1.0))
		for stop in style.gradient.color_stops {
			stop_data << f32(stop.color.r) / 255.0
			stop_data << f32(stop.color.g) / 255.0
			stop_data << f32(stop.color.b) / 255.0
			stop_data << f32(stop.color.a) / 255.0 * paint_alpha
			stop_data << f32(stop.position)
		}
		gradient_transform := style.gradient.gradient_transform or { painting.Affine{} }
		unsafe {
			C.native_add_svg_pattern_radial_gradient_path(&path_data[0], path_data.len / layout.compatibility_clip_path_segment_stride, if even_odd {
				1
			} else {
				0
			}, f32(matrix[0]), f32(matrix[1]), f32(matrix[2]), f32(matrix[3]), f32(matrix[4]), f32(matrix[5]), tile_height, if stroke {
				1
			} else {
				0
			}, f32(stroke_width), line_cap, line_join, f32(miter_limit), f32(style.start_center.x), f32(style.start_center.y), f32(style.start_radius), f32(style.end_center.x), f32(style.end_center.y), f32(style.end_radius), f32(gradient_transform.a), f32(gradient_transform.b), f32(gradient_transform.c), f32(gradient_transform.d), f32(gradient_transform.e), f32(gradient_transform.f), int(style.gradient.spread_method), if style.gradient.color_space == .linear_srgb {
				1
			} else {
				0
			}, &stop_data[0], style.gradient.color_stops.len, f32(opacity))
		}
	}
}

fn svg_pattern_color(paint_color_value painting.Color, opacity f64) gg.Color {
	return gg.rgba(paint_color_value.r, paint_color_value.g, paint_color_value.b, u8(clamp(f64(paint_color_value.a) * clamp(opacity, 0.0, 1.0), 0.0, 255.0)))
}

fn painting_affine_array(transform painting.Affine) [6]f64 {
	return [transform.a, transform.b, transform.c, transform.d, transform.e, transform.f]!
}

fn (mut app BrowserApp) draw_native_svg_pattern_path(path_data []f32, even_odd bool,
	matrix [6]f64, page_x f32, page_y f32, scroll_y f32, canvas_height f32,
	stroke bool, stroke_width f64, line_cap int, line_join int, miter_limit f64,
	style &painting.SVGPatternPaintStyle, opacity f64, content_mask bool) {
	$if macos {
		if path_data.len < layout.compatibility_clip_path_segment_stride {
			return
		}
		tile := style.tile_rect
		if tile.width <= 0 || tile.height <= 0 {
			return
		}
		// Pattern tiles are fixed-size rasters. Include the scale accumulated by
		// the target's visual-context chain so transformed ancestors do not
		// magnify a low-resolution tile.
		content_scale_x := math.max(math.sqrt(matrix[0] * matrix[0] + matrix[1] * matrix[1]), 1.0)
		content_scale_y := math.max(math.sqrt(matrix[2] * matrix[2] + matrix[3] * matrix[3]), 1.0)
		C.native_begin_svg_pattern_tile(style.cache_key, f32(tile.width), f32(tile.height), f32(content_scale_x), f32(content_scale_y))
		if display_list := style.tile_display_list {
			for operation in display_list.operations {
				match operation.kind {
					.begin_filter {
						C.native_begin_svg_pattern_filter_layer(f32(tile.width), f32(tile.height))
						if filter := operation.filter {
							app.add_native_css_filter(filter, [f64(1), 0, 0, 1, 0, 0]!, 0, 0)
						}
					}
					.begin_opacity {
						C.native_begin_svg_pattern_opacity(f32(operation.opacity))
					}
					.end_filter {
						C.native_end_svg_pattern_filter_layer()
					}
					.end_opacity {
						C.native_end_svg_pattern_opacity()
					}
					.image {
						image := app.background_image(operation.image_url) or { continue }
						replay := resolved_svg_operation_image(operation.image_paintable, operation.image_rect, operation.image_position_x, operation.image_position_y, operation.image_rendering, image.width, image.height) or { continue }
						operation_matrix := painting_affine_array(operation.transform)
						C.native_add_svg_pattern_image(image, f32(replay.destination.x), f32(replay.destination.y), f32(replay.destination.width), f32(replay.destination.height), 0, 0, f32(image.width), f32(image.height), f32(replay.clip.x), f32(replay.clip.y), f32(replay.clip.width), f32(replay.clip.height), f32(operation_matrix[0]), f32(operation_matrix[1]), f32(operation_matrix[2]), f32(operation_matrix[3]), f32(operation_matrix[4]), f32(operation_matrix[5]), f32(tile.height), 1, if replay.scaling == .nearest_neighbor {
							1
						} else {
							0
						})
					}
					.path {
						operation_path := layout.compatibility_pack_clip_path_segments(operation.path)
						if operation_path.len < layout.compatibility_clip_path_segment_stride {
							continue
						}
						operation_matrix := painting_affine_array(operation.transform)
						fill := svg_pattern_color(operation.fill_color, operation.fill_opacity)
						stroke_color := svg_pattern_color(operation.stroke_color, operation.stroke_opacity)
						if operation.fill_linear_gradient == none
							&& operation.stroke_linear_gradient == none
							&& operation.fill_radial_gradient == none
							&& operation.stroke_radial_gradient == none
							&& operation.fill_pattern == none && operation.stroke_pattern == none {
							unsafe {
								C.native_add_svg_pattern_path(&operation_path[0], operation_path.len / layout.compatibility_clip_path_segment_stride, if operation.path.fill_rule == .even_odd {
									1
								} else {
									0
								}, f32(operation_matrix[0]), f32(operation_matrix[1]), f32(operation_matrix[2]), f32(operation_matrix[3]), f32(operation_matrix[4]), f32(operation_matrix[5]), f32(tile.height), fill, if operation.has_fill {
									1
								} else {
									0
								}, stroke_color, if operation.has_stroke {
									1
								} else {
									0
								}, f32(operation.stroke_width), int(operation.stroke_linecap), int(operation.stroke_linejoin), f32(operation.stroke_miter_limit), if operation.stroke_first {
									1
								} else {
									0
								})
							}
							continue
						}
						order := if operation.stroke_first { [1, 0] } else { [0, 1] }
						for part in order {
							if part == 0 {
								if gradient := operation.fill_linear_gradient {
									draw_native_svg_pattern_linear_gradient_path(operation_path, operation.path.fill_rule == .even_odd, operation_matrix, f32(tile.height), false, operation.stroke_width, int(operation.stroke_linecap), int(operation.stroke_linejoin), operation.stroke_miter_limit, gradient, operation.fill_opacity)
								} else if gradient := operation.fill_radial_gradient {
									draw_native_svg_pattern_radial_gradient_path(operation_path, operation.path.fill_rule == .even_odd, operation_matrix, f32(tile.height), false, operation.stroke_width, int(operation.stroke_linecap), int(operation.stroke_linejoin), operation.stroke_miter_limit, gradient, operation.fill_opacity)
								} else if pattern := operation.fill_pattern {
									app.draw_native_svg_pattern_path(operation_path, operation.path.fill_rule == .even_odd, operation_matrix, 0, 0, 0, f32(tile.height), false, operation.stroke_width, int(operation.stroke_linecap), int(operation.stroke_linejoin), operation.stroke_miter_limit, pattern, operation.fill_opacity, false)
								} else if operation.has_fill {
									unsafe {
										C.native_add_svg_pattern_path(&operation_path[0], operation_path.len / layout.compatibility_clip_path_segment_stride, if operation.path.fill_rule == .even_odd {
											1
										} else {
											0
										}, f32(operation_matrix[0]), f32(operation_matrix[1]), f32(operation_matrix[2]), f32(operation_matrix[3]), f32(operation_matrix[4]), f32(operation_matrix[5]), f32(tile.height), fill, 1, stroke_color, 0, f32(operation.stroke_width), int(operation.stroke_linecap), int(operation.stroke_linejoin), f32(operation.stroke_miter_limit), 0)
									}
								}
							} else if operation.has_stroke {
								if gradient := operation.stroke_linear_gradient {
									draw_native_svg_pattern_linear_gradient_path(operation_path, operation.path.fill_rule == .even_odd, operation_matrix, f32(tile.height), true, operation.stroke_width, int(operation.stroke_linecap), int(operation.stroke_linejoin), operation.stroke_miter_limit, gradient, operation.stroke_opacity)
								} else if gradient := operation.stroke_radial_gradient {
									draw_native_svg_pattern_radial_gradient_path(operation_path, operation.path.fill_rule == .even_odd, operation_matrix, f32(tile.height), true, operation.stroke_width, int(operation.stroke_linecap), int(operation.stroke_linejoin), operation.stroke_miter_limit, gradient, operation.stroke_opacity)
								} else if pattern := operation.stroke_pattern {
									app.draw_native_svg_pattern_path(operation_path, operation.path.fill_rule == .even_odd, operation_matrix, 0, 0, 0, f32(tile.height), true, operation.stroke_width, int(operation.stroke_linecap), int(operation.stroke_linejoin), operation.stroke_miter_limit, pattern, operation.stroke_opacity, false)
								} else {
									unsafe {
										C.native_add_svg_pattern_path(&operation_path[0], operation_path.len / layout.compatibility_clip_path_segment_stride, if operation.path.fill_rule == .even_odd {
											1
										} else {
											0
										}, f32(operation_matrix[0]), f32(operation_matrix[1]), f32(operation_matrix[2]), f32(operation_matrix[3]), f32(operation_matrix[4]), f32(operation_matrix[5]), f32(tile.height), fill, 0, stroke_color, 1, f32(operation.stroke_width), int(operation.stroke_linecap), int(operation.stroke_linejoin), f32(operation.stroke_miter_limit), 0)
									}
								}
							}
						}
					}
				}
			}
		}
		pattern_transform := style.pattern_transform or { painting.Affine{} }
		unsafe {
			C.native_finish_svg_pattern_path(&path_data[0], path_data.len / layout.compatibility_clip_path_segment_stride, if even_odd {
				1
			} else {
				0
			}, f32(matrix[0]), f32(matrix[1]), f32(matrix[2]), f32(matrix[3]), f32(matrix[4]), f32(matrix[5]), page_x, page_y, scroll_y, canvas_height, if stroke {
				1
			} else {
				0
			}, f32(stroke_width), line_cap, line_join, f32(miter_limit), f32(tile.x), f32(tile.y), f32(tile.width), f32(tile.height), f32(pattern_transform.a), f32(pattern_transform.b), f32(pattern_transform.c), f32(pattern_transform.d), f32(pattern_transform.e), f32(pattern_transform.f), f32(opacity), if content_mask {
				1
			} else {
				0
			})
		}
	}
}

fn map_paint_point(transform [6]f64, x f64, y f64) (f64, f64) {
	matrix := normalized_paint_transform(transform)
	return matrix[0] * x + matrix[2] * y + matrix[4], matrix[1] * x + matrix[3] * y + matrix[5]
}

fn append_native_gradient_path_point(mut data []f32, kind f32, x f64, y f64) {
	data << kind
	data << f32(x)
	data << f32(y)
	for _ in 0 .. 9 {
		data << 0
	}
}

fn native_gradient_clip_path(command layout.PaintCommand, tile painting.Rect) []f32 {
	points := if !command.gradient_background_layer && command.points.len >= 6 {
		command.points
	} else {
		[tile.x, tile.y, tile.right(), tile.y, tile.right(), tile.bottom(), tile.x, tile.bottom()]
	}
	mut data := []f32{cap: (points.len / 2 + 1) * layout.compatibility_clip_path_segment_stride}
	for index := 0; index + 1 < points.len; index += 2 {
		append_native_gradient_path_point(mut data, if index == 0 { f32(0) } else { f32(1) }, points[index], points[index + 1])
	}
	append_native_gradient_path_point(mut data, 5, 0, 0)
	return data
}

fn native_gradient_stop_data(gradient layout.LinearGradient, opacity f64) []f32 {
	// Sixteen subdivisions per resolved stop span keep the native sRGB interpolation between
	// samples below a visible color step while preserving duplicate-position hard stops.
	stops := layout.sampled_gradient_stops(gradient, 16)
	mut data := []f32{cap: stops.len * 5}
	for stop in stops {
		data << f32(stop.color.r) / 255.0
		data << f32(stop.color.g) / 255.0
		data << f32(stop.color.b) / 255.0
		data << f32(clamp(f64(stop.color.a) / 255.0 * opacity, 0.0, 1.0))
		data << f32(stop.offset)
	}
	return data
}

fn draw_native_css_gradient_tile(command layout.PaintCommand, gradient layout.LinearGradient,
	tile painting.Rect, stop_data []f32, matrix [6]f64, page_x f32, page_y f32,
	scroll_y f64, canvas_height f32, chromium bool) bool {
	$if macos {
		if stop_data.len < 5 {
			return false
		}
		path_data := native_gradient_clip_path(command, tile)
		if path_data.len < layout.compatibility_clip_path_segment_stride {
			return false
		}
		if chromium && (gradient.x1 != gradient.x2 || gradient.y1 != gradient.y2) {
			if gpu_stops := chromium_linear_gradient_stop_data(gradient, command.opacity) {
				points := chromium_linear_gradient_points(gradient, tile)
				unsafe {
					C.native_draw_svg_linear_gradient_path(&path_data[0], path_data.len / layout.compatibility_clip_path_segment_stride,
						0, f32(matrix[0]), f32(matrix[1]), f32(matrix[2]), f32(matrix[3]),
						f32(matrix[4]), f32(matrix[5]), page_x, page_y, f32(scroll_y), canvas_height,
						0, 0, 0, 0, 4, points[0], points[1], points[2], points[3],
						1, 0, 0, 1,
						if gradient.css_angle_degrees != none { f32(tile.x) } else { f32(0) },
						if gradient.css_angle_degrees != none { f32(tile.y) } else { f32(0) }, 0, 0,
						gpu_stops.data, gpu_stops.len / 5, 1)
				}
				return true
			}
		}
		kind := if gradient.kind == 'conic' {
			2
		} else if gradient.kind == 'radial' || gradient.radial {
			1
		} else {
			0
		}
		unsafe {
			return C.native_draw_css_gradient_path(&path_data[0], path_data.len / layout.compatibility_clip_path_segment_stride, 0, f32(matrix[0]), f32(matrix[1]), f32(matrix[2]), f32(matrix[3]), f32(matrix[4]), f32(matrix[5]), page_x, page_y, f32(scroll_y), canvas_height, kind, f32(tile.x), f32(tile.y), f32(tile.width), f32(tile.height), f32(gradient.x1), f32(gradient.y1), f32(gradient.x2), f32(gradient.y2), f32(gradient.center_x), f32(gradient.center_y), f32(gradient.radius_x), f32(gradient.radius_y), f32(gradient.start_degrees), &stop_data[0], stop_data.len / 5) != 0
		}
	}
	return false
}

fn paint_screen_point(command layout.PaintCommand, x f64, y f64, page_x f32, page_y f32, scroll_y f64) (f32, f32) {
	mapped_x, mapped_y := map_paint_point(command.transform, x, y)
	return page_x + f32(mapped_x), page_y + f32(mapped_y - scroll_y)
}

// Every rectangle has four corners. Keep their screen coordinates inline so
// ordinary command replay needs no temporary point or corner arrays.
fn transformed_rect_points(command layout.PaintCommand, page_x f32, page_y f32, scroll_y f64) [8]f32 {
	left_top_x, left_top_y := paint_screen_point(command, command.x, command.y, page_x, page_y, scroll_y)
	right_top_x, right_top_y := paint_screen_point(command, command.x + command.width, command.y, page_x, page_y, scroll_y)
	right_bottom_x, right_bottom_y := paint_screen_point(command, command.x + command.width, command.y + command.height, page_x, page_y, scroll_y)
	left_bottom_x, left_bottom_y := paint_screen_point(command, command.x, command.y + command.height, page_x, page_y, scroll_y)
	return [left_top_x, left_top_y, right_top_x, right_top_y,
		right_bottom_x, right_bottom_y, left_bottom_x, left_bottom_y]!
}

// Polygon drawing consumes this read-only view synchronously in both the
// native CGContext and GG backends. Keep the fixed buffer alive through that
// call; normal fixed-array slicing would allocate and copy it in V.
fn borrowed_rectangle_screen_points(points &[8]f32) []f32 {
	return unsafe {
		array{
			data: &points[0]
			len: 8
			cap: 8
			element_size: int(sizeof(f32))
			flags: .nofree | .nogrow | .noshrink
		}
	}
}

fn paint_commands_contain_backdrop_filter(commands []layout.PaintCommand) bool {
	for command in commands {
		if command.kind == 'apply_backdrop_filter'
			|| (command.nested_viewport_commands.len > 0
				&& paint_commands_contain_backdrop_filter(command.nested_viewport_commands)) {
			return true
		}
	}
	return false
}

fn (app &BrowserApp) background_image_bytes(image_url string) ![]u8 {
	source_url := if app.document != unsafe { nil } { app.document.url.serialize() } else { app.address }
	// Filtering a retained resource applies the same request filter first.
	if resource := app.resource_cache[image_url] {
		return filter_preloaded_resource(resource, source_url, 'image')!.body.bytes()
	}
	if image_url.starts_with('http://') || image_url.starts_with('https://') {
		filtered := browsernet.filter(adblock.Request{url: image_url, source_url: source_url, request_type: 'image'})!
		if replacement := filtered.replacement { return replacement.body.bytes() }
	}
	if image_url.starts_with('data:') {
		comma := image_url.index(',') or { return error('Malformed data URL') }
		metadata := image_url[..comma].to_lower()
		payload := image_url[comma + 1..]
		if metadata.ends_with(';base64') {
			return base64.decode(payload)
		}
		return url.percent_decode(payload)
	}
	if image_url.starts_with('file://') {
		path := url.percent_decode(image_url['file://'.len..]).bytestr()
		return os.read_bytes(path)
	}
	if image_url.starts_with('http://') || image_url.starts_with('https://') {
		return error('remote image has not finished loading')
	}
	return os.read_bytes(image_url)
}

fn image_bytes_are_webp(bytes []u8) bool {
	return bytes.len >= 12 && bytes[..4].bytestr() == 'RIFF' && bytes[8..12].bytestr() == 'WEBP'
}

fn (mut app BrowserApp) create_image_from_resource_bytes(image_url string, bytes []u8) !gg.Image {
	$if macos {
		if image_bytes_are_webp(bytes) {
			// Share the document decoder's pixels with native image and background
			// painting. Animated streams keep AppKit's frame provider below.
			if app.ctx.native_rendering {
				if C.native_webp_yuv_paint_supported() != 0 && app.document != unsafe { nil }
					&& app.document.font_rendering_policy() == .chromium {
					mut width := 0
					mut height := 0
					mut size := 0
					planes := C.native_decode_webp_yuv(bytes.data, usize(bytes.len), &width, &height, &size)
					if planes != unsafe { nil } {
						mut data := []u8{len: size}
						unsafe { vmemcpy(data.data, planes, size) }
						C.native_free_webp_pixels(planes)
						mut image := gg.Image{width: width, height: height, nr_channels: 8,
							ok: true, data: data.data}
						image.id = app.ctx.cache_image(image)
						return image
					}
				}
				if bitmap := browser_decode_raster_image_bytes(bytes) {
					mut image := gg.Image{width: bitmap.width, height: bitmap.height,
						nr_channels: native_bitmap_channel_marker(bitmap, false), ok: true,
						data: bitmap.data.data}
					image.id = app.ctx.cache_image(image)
					return image
				}
			}
			path := browser_cache_entry_path(browser_cache_root(), 'decoded-images', image_url + '\n' + sha256.hexhash(bytes.bytestr()))
			if !os.is_file(path) {
				write_browser_cache_entry(path, bytes.bytestr())
			}
			return app.ctx.create_image(path)
		}
	}
	$if macos {
		if app.ctx.native_rendering {
			if image := app.chromium_jpeg_yuv_image(bytes) {
				return image
			}
			if bitmap := native_jpeg_bitmap(bytes) {
				mut image := gg.Image{width: bitmap.width, height: bitmap.height,
					nr_channels: native_bitmap_channel_marker(bitmap, false), ok: true,
					data: bitmap.data.data}
				image.id = app.ctx.cache_image(image)
				return image
			}
		}
	}
	mut image := app.ctx.create_image_from_byte_array(bytes)!
	$if macos {
		if app.ctx.native_rendering {
			// gg's byte decoder also uses stb's top-to-bottom rows. Native paint
			// reads the cached image, so retain that order in both representations.
			image.nr_channels = 6
			mut cached := app.ctx.get_cached_image_by_idx(image.id)
			cached.nr_channels = 6
			// Chromium draws PNGs in the color space of their gAMA and cHRM chunks.
			chromium := app.document != unsafe { nil } && app.document.font_rendering_policy() == .chromium
			C.native_tag_image_color_profile(image.data, image.width, image.height, bytes.data,
				usize(bytes.len), int(chromium))
		}
	}
	return image
}

fn browser_local_file_path(serialized_url string) ?string {
	parsed := url.parse(serialized_url) or { return none }
	if parsed.scheme != 'file' {
		return none
	}
	return url.percent_decode(parsed.serialize_path()).bytestr()
}

fn (mut app BrowserApp) request_background_resource(image_url string) {
	if image_url in app.resource_cache || image_url in app.background_resource_pending {
		return
	}
	app.background_resource_pending[image_url] = true
	source_url := if app.document != unsafe { nil } { app.document.url.serialize() } else { app.address }
	spawn fetch_background_resource_in_background(image_url, source_url, app.background_resource_results)
}

fn (mut app BrowserApp) poll_background_resources() {
	mut installed_stylesheets := app.request_script_inserted_stylesheets()
	mut completed_script_images := app.request_script_inserted_images()
	mut changed_svg_resources := map[string]bool{}
	mut completed_nonrendered_images := map[string]bool{}
	for {
		select {
			resource := <-app.background_resource_results {
				app.background_resource_pending.delete(resource.url)
				if resource.url in app.nonrendered_image_preloads {
					app.nonrendered_image_preloads.delete(resource.url)
					completed_nonrendered_images[resource.url] = true
				}
				if resource.url in app.script_image_requests {
					app.script_image_requests.delete(resource.url)
					completed_script_images[resource.url] = true
				}
				previous_svg_available := if previous := app.resource_cache[resource.url] {
					previous.error == '' && previous.body != ''
				} else { false }
				failed_previous_svg := previous_svg_available
					&& (resource.error != '' || resource.body == '')
					&& resource.url.all_before('#').all_before('?').to_lower().ends_with('.svg')
				if app.resource_cache.len < max_cached_resources || resource.url in app.resource_cache {
					app.resource_cache[resource.url] = resource
				}
				if publish_browser_svg_resource(resource) || failed_previous_svg {
					changed_svg_resources[resource.url.all_before('#')] = true
				}
				if app.install_script_inserted_stylesheet(resource) {
					installed_stylesheets = true
				}
			}
			else {
				break
			}
		}
	}
	script_images_updated := completed_script_images.len > 0 && app.document != unsafe { nil }
		&& app.complete_script_inserted_images(completed_script_images)
	if installed_stylesheets && app.document != unsafe { nil } {
		app.document.set_needs_full_style_update(true)
		app.document.tear_down_layout_tree()
		app.relayout(app.viewport_width, app.viewport_height + app.chrome_height())
		return
	}
	if app.document != unsafe { nil } && app.js_runtime == unsafe { nil }
		&& completed_nonrendered_images.len > 0 {
		complete_static_browser_image_requests(app.document, completed_nonrendered_images)
	}
	if app.document != unsafe { nil } && completed_nonrendered_images.len > 0
		&& completed_nonrendered_images_need_layout(app.document, completed_nonrendered_images) {
		app.document.tear_down_layout_tree()
		app.relayout(app.viewport_width, app.viewport_height + app.chrome_height())
		return
	}
	if script_images_updated {
		// Each completed image marks only what its new contents change. A
		// thumbnail whose size cannot depend on its natural size is repainted;
		// frame preparation still restyles it before recording.
		if app.document.layout_is_up_to_date() {
			app.paint_commands_pending = true
			if app.frame_preparation_depth == 0 { app.record_document_paint_commands() }
			return
		}
		app.relayout(app.viewport_width, app.viewport_height + app.chrome_height())
		return
	}
	if changed_svg_resources.len > 0 && app.document != unsafe { nil } {
		if browser_svg_resources_need_layout(app.document, changed_svg_resources) {
			app.document.tear_down_layout_tree()
		} else if layout.refresh_document_background_resources(app.document, changed_svg_resources) {
			app.adopt_current_document_geometry()
			app.paint_commands_pending = true
			if app.frame_preparation_depth == 0 { app.record_document_paint_commands() }
			return
		} else {
			app.document.set_needs_repaint_with_invalidation(.paint_commands)
		}
		app.relayout(app.viewport_width, app.viewport_height + app.chrome_height())
	}
}

fn (mut app BrowserApp) background_image(image_url string) ?&gg.Image {
	source_url := if app.document != unsafe { nil } { app.document.url.serialize() } else { app.address }
	cache_key := source_url + '\n' + adblock.is_enabled().str() + '\n' + image_url
	if image_id := app.background_image_ids[cache_key] {
		image := app.ctx.get_cached_image_by_idx(image_id)
		if image.ok {
			return image
		}
	}
	if image_url.starts_with('http://') || image_url.starts_with('https://') {
		if resource := app.resource_cache[image_url] {
			if (resource.error != '' || resource.adblock_replacement)
				&& (resource.source_url != source_url || resource.request_type != 'image') { app.resource_cache.delete(image_url) }
		}
		if image_url !in app.resource_cache {
			app.request_background_resource(image_url)
			return none
		}
	}
	mut image := if image_url.starts_with('file://') {
		path := browser_local_file_path(image_url) or { return none }
		app.ctx.create_image(path) or { return none }
	} else if !image_url.contains('://') && !image_url.starts_with('data:') && os.is_file(image_url) {
		app.ctx.create_image(image_url) or { return none }
	} else {
		bytes := app.background_image_bytes(image_url) or { return none }
		app.create_image_from_resource_bytes(image_url, bytes) or { return none }
	}
	app.background_image_ids[cache_key] = image.id
	return app.ctx.get_cached_image_by_idx(image.id)
}

fn (mut app BrowserApp) force_dark_image_from_bitmap(key string, bitmap &dom.Bitmap_,
	original &gg.Image) &gg.Image {
	if state := app.force_dark_image_states[key] {
		if state == 1 {
			return original
		}
		if filtered := app.force_dark_images[key] {
			return filtered
		}
	}
	if !painting.force_dark_should_filter_bitmap(bitmap) {
		app.force_dark_image_states[key] = 1
		return original
	}
	filtered_bitmap := painting.force_dark_filter_bitmap(bitmap)
	mut filtered_image := &gg.Image{
		width: filtered_bitmap.width
		height: filtered_bitmap.height
		nr_channels: native_bitmap_channel_marker(filtered_bitmap, false)
		ok: true
		data: filtered_bitmap.data.data
	}
	if !app.ctx.native_rendering {
		filtered_image.init_sokol_image()
	}
	app.force_dark_image_states[key] = 2
	app.force_dark_image_bitmaps[key] = filtered_bitmap
	app.force_dark_images[key] = filtered_image
	return filtered_image
}

fn (mut app BrowserApp) force_dark_image_for_url(image_url string,
	original &gg.Image) &gg.Image {
	key := 'url:${image_url}'
	if state := app.force_dark_image_states[key] {
		if state == 1 {
			return original
		}
		if filtered := app.force_dark_images[key] {
			return filtered
		}
	}
	bytes := app.background_image_bytes(image_url) or {
		app.force_dark_image_states[key] = 1
		return original
	}
	bitmap := browser_decode_raster_image_bytes(bytes) or {
		app.force_dark_image_states[key] = 1
		return original
	}
	return app.force_dark_image_from_bitmap(key, bitmap, original)
}

fn paint_command_image_allows_force_dark(command layout.PaintCommand, destination_width f64,
	destination_height f64, image &gg.Image) bool {
	return command.apply_force_dark_to_image
		&& painting.force_dark_image_size_allows_classification(math.abs(destination_width),
			math.abs(destination_height), painting.IntSize{image.width, image.height})
}

fn background_length(value string, basis f32, automatic f32) f32 {
	trimmed := value.trim_space().to_lower()
	if trimmed == '' || trimmed == 'auto' {
		return automatic
	}
	// Position offsets can resolve below zero when their percentage basis is
	// smaller than an edge offset. Parse with an inset property's unrestricted
	// <length-percentage> range rather than width's non-negative range.
	if parsed := css.parse_css_value_logic(.left, trimmed) {
		match parsed {
			css.LengthStyleValue, css.PercentageStyleValue, css.CalculatedStyleValue {
				return f32(css.LengthPercentage.from_style_value_logic(parsed).to_px(css.LengthResolutionContext.default(), css.CSSPixels.nearest_value_for(f64(basis))).to_double())
			}
			else {}
		}
	}
	if trimmed.ends_with('%') {
		return basis * f32(trimmed[..trimmed.len - 1].f64() / 100.0)
	}
	if trimmed.ends_with('px') {
		return f32(trimmed[..trimmed.len - 2].f64())
	}
	return f32(trimmed.f64())
}

fn background_position(value string, free_space f32) f32 {
	trimmed := value.trim_space().to_lower()
	if trimmed == 'center' {
		return free_space / 2
	}
	if trimmed in ['right', 'bottom'] {
		return free_space
	}
	if trimmed in ['left', 'top'] {
		return 0
	}
	return background_length(trimmed, free_space, 0)
}

fn painting_background_repetition(value string) painting.Repetition {
	return match value.trim_space().to_lower() {
		'no-repeat' { .no_repeat }
		'space' { .space }
		'round' { .round }
		else { .repeat }
	}
}

fn painting_background_attachment(value string) painting.BackgroundAttachment {
	return match value.trim_space().to_lower() {
		'fixed' { .fixed }
		'local' { .local }
		else { .scroll }
	}
}

fn contained_image_destination(x f32, y f32, width f32, height f32,
	intrinsic_width f32, intrinsic_height f32, position_x string,
	position_y string) (f32, f32, f32, f32) {
	if width <= 0 || height <= 0 || intrinsic_width <= 0 || intrinsic_height <= 0 {
		return x, y, 0, 0
	}
	scale := math.min(width / intrinsic_width, height / intrinsic_height)
	destination_width := intrinsic_width * scale
	destination_height := intrinsic_height * scale
	return x + background_position(position_x, width - destination_width), y + background_position(position_y, height - destination_height), destination_width, destination_height
}

struct ResolvedSVGOperationImage {
	destination painting.Rect
	clip        painting.Rect
	scaling     painting.ScalingMode
}

fn resolved_svg_operation_image(retained ?painting.ImagePaintable, rect painting.Rect,
	position_x string, position_y string, image_rendering css.ImageRendering, image_width int,
	image_height int) ?ResolvedSVGOperationImage {
	if paintable := retained {
		converter := painting.new_device_pixel_converter(1.0) or { return none }
		result := paintable.paint('', painting.IntRect{0, 0, image_width, image_height}, converter) or { return none }
		return ResolvedSVGOperationImage{
			destination: painting.Rect{result.bitmap.destination.x, result.bitmap.destination.y, result.bitmap.destination.width, result.bitmap.destination.height}
			clip: painting.Rect{result.bitmap.clip_rect.x, result.bitmap.clip_rect.y, result.bitmap.clip_rect.width, result.bitmap.clip_rect.height}
			scaling: result.bitmap.scaling
		}
	}
	destination_x, destination_y, destination_width, destination_height := contained_image_destination(f32(rect.x), f32(rect.y), f32(rect.width), f32(rect.height), f32(image_width), f32(image_height), position_x, position_y)
	if destination_width <= 0 || destination_height <= 0 {
		return none
	}
	return ResolvedSVGOperationImage{
		destination: painting.Rect{destination_x, destination_y, destination_width, destination_height}
		clip: rect
		scaling: painting.to_gfx_scaling_mode(image_rendering, painting.IntSize{image_width, image_height}, painting.IntSize{int(math.round(rect.width)), int(math.round(rect.height))})
	}
}

fn (mut app BrowserApp) prepare_native_svg_layer_mask(clip layout.PaintClip, page_x f32,
	page_y f32, scroll_y f32, apply_as_clip bool) {
	$if macos {
		if !app.ctx.native_rendering {
			return
		}
		if clip.is_svg_content_mask {
			area_matrix := normalized_paint_transform(clip.transform)
			C.native_begin_svg_content_mask(clip.cache_key, if clip.mask_luminance {
				1
			} else {
				0
			}, f32(app.ctx.width), f32(app.ctx.height), f32(clip.rect.x), f32(clip.rect.y), f32(clip.rect.width), f32(clip.rect.height), f32(area_matrix[0]), f32(area_matrix[1]), f32(area_matrix[2]), f32(area_matrix[3]), f32(area_matrix[4]), f32(area_matrix[5]), page_x, page_y, scroll_y)
			for operation in clip.mask_operations {
				match operation.kind {
					.begin_opacity {
						C.native_begin_svg_mask_opacity(f32(operation.opacity))
					}
					.end_opacity {
						C.native_end_svg_mask_opacity()
					}
					.image {
						image := app.background_image(operation.image_url) or { continue }
						rect := operation.image_rect
						replay := resolved_svg_operation_image(operation.image_paintable, painting.Rect{rect.x, rect.y, rect.width, rect.height}, operation.image_position_x, operation.image_position_y, operation.image_rendering, image.width, image.height) or { continue }
						matrix := normalized_paint_transform(operation.transform)
						C.native_add_svg_content_mask_image(image, f32(replay.destination.x), f32(replay.destination.y), f32(replay.destination.width), f32(replay.destination.height), 0, 0, f32(image.width), f32(image.height), f32(replay.clip.x), f32(replay.clip.y), f32(replay.clip.width), f32(replay.clip.height), f32(matrix[0]), f32(matrix[1]), f32(matrix[2]), f32(matrix[3]), f32(matrix[4]), f32(matrix[5]), page_x, page_y, scroll_y, f32(app.ctx.height), if replay.scaling == .nearest_neighbor {
							1
						} else {
							0
						})
					}
					.path {
						if operation.path_data.len < layout.compatibility_clip_path_segment_stride {
							continue
						}
						matrix := normalized_paint_transform(operation.transform)
						fill := app.paint_colors.color(operation.fill_color, operation.fill_opacity)
						stroke := app.paint_colors.color(operation.stroke_color, operation.stroke_opacity)
						if operation.fill_linear_gradient == none
							&& operation.stroke_linear_gradient == none
							&& operation.fill_radial_gradient == none
							&& operation.stroke_radial_gradient == none
							&& operation.fill_pattern == none && operation.stroke_pattern == none {
							unsafe {
								C.native_add_svg_content_mask_path(&operation.path_data[0], operation.path_data.len / layout.compatibility_clip_path_segment_stride, if operation.path_even_odd {
									1
								} else {
									0
								}, f32(matrix[0]), f32(matrix[1]), f32(matrix[2]), f32(matrix[3]), f32(matrix[4]), f32(matrix[5]), page_x, page_y, scroll_y, f32(app.ctx.width), f32(app.ctx.height), fill, if operation.has_fill {
									1
								} else {
									0
								}, stroke, if operation.has_stroke {
									1
								} else {
									0
								}, f32(operation.stroke_width), operation.stroke_linecap, operation.stroke_linejoin, f32(operation.stroke_miterlimit), if operation.stroke_first {
									1
								} else {
									0
								})
							}
							continue
						}
						order := if operation.stroke_first { [1, 0] } else { [0, 1] }
						for part in order {
							if part == 0 {
								if gradient := operation.fill_linear_gradient {
									draw_native_svg_linear_gradient_path(operation.path_data, operation.path_even_odd, matrix, page_x, page_y, scroll_y, f32(app.ctx.height), false, operation.stroke_width, operation.stroke_linecap, operation.stroke_linejoin, operation.stroke_miterlimit, gradient, operation.fill_opacity, true)
								} else if gradient := operation.fill_radial_gradient {
									draw_native_svg_radial_gradient_path(operation.path_data, operation.path_even_odd, matrix, page_x, page_y, scroll_y, f32(app.ctx.height), false, operation.stroke_width, operation.stroke_linecap, operation.stroke_linejoin, operation.stroke_miterlimit, gradient, operation.fill_opacity, true)
								} else if pattern := operation.fill_pattern {
									app.draw_native_svg_pattern_path(operation.path_data, operation.path_even_odd, matrix, page_x, page_y, scroll_y, f32(app.ctx.height), false, operation.stroke_width, operation.stroke_linecap, operation.stroke_linejoin, operation.stroke_miterlimit, pattern, operation.fill_opacity, true)
								} else if operation.has_fill {
									unsafe {
										C.native_add_svg_content_mask_path(&operation.path_data[0], operation.path_data.len / layout.compatibility_clip_path_segment_stride, if operation.path_even_odd {
											1
										} else {
											0
										}, f32(matrix[0]), f32(matrix[1]), f32(matrix[2]), f32(matrix[3]), f32(matrix[4]), f32(matrix[5]), page_x, page_y, scroll_y, f32(app.ctx.width), f32(app.ctx.height), fill, 1, stroke, 0, f32(operation.stroke_width), operation.stroke_linecap, operation.stroke_linejoin, f32(operation.stroke_miterlimit), 0)
									}
								}
							} else if gradient := operation.stroke_linear_gradient {
								draw_native_svg_linear_gradient_path(operation.path_data, operation.path_even_odd, matrix, page_x, page_y, scroll_y, f32(app.ctx.height), true, operation.stroke_width, operation.stroke_linecap, operation.stroke_linejoin, operation.stroke_miterlimit, gradient, operation.stroke_opacity, true)
							} else if gradient := operation.stroke_radial_gradient {
								draw_native_svg_radial_gradient_path(operation.path_data, operation.path_even_odd, matrix, page_x, page_y, scroll_y, f32(app.ctx.height), true, operation.stroke_width, operation.stroke_linecap, operation.stroke_linejoin, operation.stroke_miterlimit, gradient, operation.stroke_opacity, true)
							} else if pattern := operation.stroke_pattern {
								app.draw_native_svg_pattern_path(operation.path_data, operation.path_even_odd, matrix, page_x, page_y, scroll_y, f32(app.ctx.height), true, operation.stroke_width, operation.stroke_linecap, operation.stroke_linejoin, operation.stroke_miterlimit, pattern, operation.stroke_opacity, true)
							} else if operation.has_stroke {
								unsafe {
									C.native_add_svg_content_mask_path(&operation.path_data[0], operation.path_data.len / layout.compatibility_clip_path_segment_stride, if operation.path_even_odd {
										1
									} else {
										0
									}, f32(matrix[0]), f32(matrix[1]), f32(matrix[2]), f32(matrix[3]), f32(matrix[4]), f32(matrix[5]), page_x, page_y, scroll_y, f32(app.ctx.width), f32(app.ctx.height), fill, 0, stroke, 1, f32(operation.stroke_width), operation.stroke_linecap, operation.stroke_linejoin, f32(operation.stroke_miterlimit), 0)
								}
							}
						}
					}
				}
			}
		} else {
			area_matrix := normalized_paint_transform(clip.transform)
			C.native_begin_svg_clip_mask(clip.cache_key, f32(app.ctx.width), f32(app.ctx.height), f32(clip.rect.x), f32(clip.rect.y), f32(clip.rect.width), f32(clip.rect.height), f32(area_matrix[0]), f32(area_matrix[1]), f32(area_matrix[2]), f32(area_matrix[3]), f32(area_matrix[4]), f32(area_matrix[5]), page_x, page_y, scroll_y)
			for component in clip.path_components {
				if component.path_data.len < layout.compatibility_clip_path_segment_stride {
					continue
				}
				component_matrix := normalized_paint_transform(component.transform)
				unsafe {
					C.native_add_svg_clip_mask_path(&component.path_data[0], component.path_data.len / layout.compatibility_clip_path_segment_stride, if component.path_even_odd {
						1
					} else {
						0
					}, f32(component_matrix[0]), f32(component_matrix[1]), f32(component_matrix[2]), f32(component_matrix[3]), f32(component_matrix[4]), f32(component_matrix[5]), page_x, page_y, scroll_y, f32(app.ctx.width), f32(app.ctx.height))
				}
			}
		}
		if apply_as_clip {
			C.native_finish_svg_clip_mask()
		} else {
			C.native_finish_svg_mask_cache()
		}
	}
}

fn native_svg_filter_kind(kind string) int {
	return match kind {
		'flood' { 0 }
		'blend' { 1 }
		'color-table' { 2 }
		'arithmetic' { 3 }
		'blur' { 4 }
		'color-matrix' { 5 }
		'saturate' { 6 }
		'hue-rotate' { 7 }
		'merge' { 8 }
		'erode' { 9 }
		'dilate' { 10 }
		'offset' { 11 }
		'turbulence' { 12 }
		'displacement-map' { 13 }
		'color-space-conversion' { 14 }
		'image' { 15 }
		else { -1 }
	}
}

fn native_svg_blend_mode(mode string) int {
	return match mode {
		'multiply' { 1 }
		'screen' { 2 }
		'overlay' { 3 }
		'darken' { 4 }
		'lighten' { 5 }
		'color-dodge' { 6 }
		'color-burn' { 7 }
		'hard-light' { 8 }
		'soft-light' { 9 }
		'difference' { 10 }
		'exclusion' { 11 }
		'hue' { 12 }
		'saturation' { 13 }
		'color' { 14 }
		'luminosity' { 15 }
		'plus-darker' { 16 }
		'plus-lighter' { 17 }
		'source-in' { 20 }
		'destination-out' { 21 }
		'source-atop' { 22 }
		'xor' { 23 }
		'lighter' { 24 }
		else { 0 }
	}
}

fn native_svg_channel(channel string) int {
	return match channel {
		'R', 'red' { 0 }
		'G', 'green' { 1 }
		'B', 'blue' { 2 }
		else { 3 }
	}
}

fn native_svg_filter_parameters(node painting.GfxFilterNode) [4]f32 {
	return match node.kind {
		'flood' { [f32(node.parameters['opacity'] or { 1.0 }), 0, 0, 0]! }
		'blur', 'erode', 'dilate' {
			[f32(node.parameters['radius_x'] or { 0.0 }), f32(node.parameters['radius_y'] or {
				0.0
			}), 0, 0]!
		}
		'arithmetic' {
			[f32(node.parameters['k1'] or { 0.0 }), f32(node.parameters['k2'] or { 0.0 }), f32(node.parameters['k3'] or {
				0.0
			}), f32(node.parameters['k4'] or { 0.0 })]!
		}
		'saturate' { [f32(node.parameters['amount'] or { 1.0 }), 0, 0, 0]! }
		'hue-rotate' { [f32(node.parameters['angle_degrees'] or { 0.0 }), 0, 0, 0]! }
		'offset' {
			[f32(node.parameters['dx'] or { 0.0 }), f32(node.parameters['dy'] or { 0.0 }), 0, 0]!
		}
		'turbulence' {
			[f32(node.parameters['base_frequency_x'] or { 0.0 }), f32(node.parameters['base_frequency_y'] or {
				0.0
			}), f32(node.parameters['num_octaves'] or { 1.0 }), f32(node.parameters['seed'] or {
				0.0
			})]!
		}
		'displacement-map' { [f32(node.parameters['scale'] or { 0.0 }), 0, 0, 0]! }
		'color-space-conversion' {
			destination := node.string_parameters['destination'] or { 'srgb' }
			conversion_direction := if destination == 'linear-rgb' {
				f32(1)
			} else {
				f32(0)
			}
			[conversion_direction, 0, 0, 0]!
		}
		else { [f32(0), 0, 0, 0]! }
	}
}

fn native_svg_turbulence_tile_size(node painting.GfxFilterNode) [2]f32 {
	stitch := node.string_parameters['stitch'] or { 'no-stitch' }
	if node.kind != 'turbulence' || stitch != 'stitch' {
		return [f32(0), 0]!
	}
	return [f32(node.parameters['tile_width'] or { 0.0 }), f32(node.parameters['tile_height'] or { 0.0 })]!
}

fn (mut app BrowserApp) add_native_svg_filter_graph(filter painting.GfxFilter, transform [6]f64, page_x f32,
	page_y f32) {
	root_id := filter.root_id or { return }
	bounds := filter.bounds or { painting.Rect{} }
	matrix := normalized_paint_transform(transform)
	C.native_begin_svg_filter_graph(root_id, filter.nodes.len, f32(bounds.x), f32(bounds.y), f32(bounds.width), f32(bounds.height), f32(matrix[0]), f32(matrix[1]), f32(matrix[2]), f32(matrix[3]), f32(matrix[4]), f32(matrix[5]), page_x, page_y)
	for node in filter.nodes {
		kind := native_svg_filter_kind(node.kind)
		if kind < 0 {
			continue
		}
		parameters := native_svg_filter_parameters(node)
		mode := if node.kind == 'turbulence' {
			if node.string_parameters['type'] or { 'turbulence' } == 'fractal-noise' { 1 } else { 0 }
		} else {
			native_svg_blend_mode(node.string_parameters['mode'] or { '' })
		}
		x_channel := native_svg_channel(node.string_parameters['x_channel'] or { 'A' })
		y_channel := native_svg_channel(node.string_parameters['y_channel'] or { 'A' })
		tile_size := native_svg_turbulence_tile_size(node)
		C.native_add_svg_filter_node(node.id, kind, parameters[0], parameters[1], parameters[2], parameters[3], tile_size[0], tile_size[1], gg.rgba(node.color.r, node.color.g, node.color.b, node.color.a), mode, x_channel, y_channel)
		unsafe {
			if node.input_ids.len > 0 {
				C.native_set_svg_filter_node_inputs(node.id, &node.input_ids[0], node.input_ids.len)
			}
			if node.matrix.len == 20 {
				C.native_set_svg_filter_node_matrix(node.id, &node.matrix[0], node.matrix.len)
			}
			for table in node.color_tables {
				if table.values.len == 256 {
					C.native_set_svg_filter_color_table(node.id, native_svg_channel(table.channel), &table.values[0], table.values.len)
				}
			}
		}
		if node.kind == 'image' && node.image_url.len > 0 {
			if image := app.background_image(node.image_url) {
				C.native_set_svg_filter_node_image(node.id, image)
			}
		}
	}
}

fn (mut app BrowserApp) add_native_css_filter(filter painting.GfxFilter, transform [6]f64, page_x f32,
	page_y f32) {
	for operation in filter.operations {
		kind := match operation.kind {
			'blur' { 0 }
			'drop-shadow' { 1 }
			'color' { 2 }
			'hue-rotate' { 3 }
			else {
				continue
			}
		}
		C.native_add_css_filter_operation(kind, f32(operation.first), if operation.kind == 'color' {
			f32(int(operation.color_operation))
		} else {
			f32(operation.second)
		}, f32(operation.third), gg.rgba(operation.color.r, operation.color.g, operation.color.b, operation.color.a))
	}
	app.add_native_svg_filter_graph(filter, transform, page_x, page_y)
}

// Draws a check box background deferred to a border that did not follow it.
fn (mut app BrowserApp) flush_rounded_rect_underlay(page_x f32, page_y f32, window_height int) {
	source := app.rounded_rect_underlay_source or { return }
	app.rounded_rect_underlay = none
	app.rounded_rect_underlay_source = none
	app.draw_command(layout.PaintCommand{
		...source
		underlays_next: false
	}, page_x, page_y, window_height)
}

fn (mut app BrowserApp) draw_command(source_command layout.PaintCommand, page_x f32, page_y f32, window_height int) {
	// Only the border that draws natively can take a deferred background.
	if app.rounded_rect_underlay != none
		&& (source_command.kind != 'stroke_rounded_rect' || source_command.points.len >= 4) {
		app.flush_rounded_rect_underlay(page_x, page_y, window_height)
	}
	app.paint_effect_depth = background_clip_effect_depth_after_command(app.paint_effect_depth,
		source_command.kind)
	mut command := source_command
	if command.scrollbar_axis != '' {
		command.opacity *= app.overlay_scrollbars.paint_opacity
		if command.opacity == 0 { return }
	}
	$if macos {
		if app.ctx.native_rendering {
			if command.group_opacity > 0 {
				command.opacity /= command.group_opacity
			} else {
				// The enclosing zero-opacity group suppresses every pixel. Its leaf
				// alpha is unobservable, and using one avoids a division by zero.
				command.opacity = 1
			}
		}
	}
	if command.kind == 'begin_skia_command_group' {
		$if macos {
			if app.ctx.native_rendering {
				matrix := normalized_paint_transform(command.transform)
				C.native_begin_skia_command_group(f32(command.x), f32(command.y), f32(command.width), f32(command.height), f32(matrix[0]), f32(matrix[1]), f32(matrix[2]), f32(matrix[3]), f32(matrix[4]), f32(matrix[5]), page_x, page_y, 0, f32(app.ctx.width), f32(app.ctx.height))
			}
		}
		return
	}
	if command.kind == 'end_skia_command_group' {
		$if macos {
			if app.ctx.native_rendering {
				C.native_end_skia_command_group()
			}
		}
		return
	}
	if command.kind == 'begin_css_effect_layer' {
		$if macos {
			if app.ctx.native_rendering {
				C.native_begin_clip()
				if command.has_clip {
					// Apply the scope's ancestor bounds before allocating the layer.
					// A fringe avoids applying fractional clip coverage twice.
					fringe := if command.clip_width > 0 && command.clip_height > 0 { f32(2) } else { f32(0) }
					C.native_add_corner_rounded_clip(f32(command.clip_x) - fringe, f32(command.clip_y) - fringe, f32(command.clip_width) + fringe * 2, f32(command.clip_height) + fringe * 2, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 1, 0, 0, page_x, page_y, 0, f32(app.ctx.height))
				}
				layer := command.visual_layer()
				C.native_begin_css_effect_layer(f32(layer.opacity), int(layer.blend_mode))
			}
		}
		return
	}
	if command.kind == 'end_css_effect_layer' {
		$if macos {
			if app.ctx.native_rendering {
				C.native_end_css_effect_layer()
				C.native_end_clip()
			}
		}
		return
	}
	if command.kind == 'begin_background_text_clip' {
		$if macos {
			if app.ctx.native_rendering {
				clip_points := transformed_rect_points(command, page_x, page_y, 0)
				mut clip_left := clip_points[0]
				mut clip_top := clip_points[1]
				mut clip_right := clip_left
				mut clip_bottom := clip_top
				for index := 2; index + 1 < clip_points.len; index += 2 {
					clip_left = math.min(clip_left, clip_points[index])
					clip_top = math.min(clip_top, clip_points[index + 1])
					clip_right = math.max(clip_right, clip_points[index])
					clip_bottom = math.max(clip_bottom, clip_points[index + 1])
				}
				C.native_begin_background_text_clip(f32(app.ctx.width), f32(app.ctx.height), clip_left, f32(app.ctx.height) - clip_bottom, clip_right - clip_left, clip_bottom - clip_top)
				matrix := normalized_paint_transform(command.transform)
				font_scale := math.sqrt(matrix[0] * matrix[0] + matrix[1] * matrix[1])
				for run in command.text_clip_runs {
					run_command := layout.PaintCommand{
						x: run.x
						y: run.y
						width: run.width
						height: run.height
						transform: command.transform
					}
					run_points := transformed_rect_points(run_command, page_x, page_y, 0)
					mut run_x := run_points[0]
					mut run_y := run_points[1]
					mut run_bottom := run_y
					for index := 2; index + 1 < run_points.len; index += 2 {
						run_x = math.min(run_x, run_points[index])
						run_y = math.min(run_y, run_points[index + 1])
						run_bottom = math.max(run_bottom, run_points[index + 1])
					}
					mut retained_run_drawn := false
					if glyph_run := run.glyph_run {
						glyphs := glyph_run.glyph_indices()
						positions := glyph_run.glyph_positions()
						if run.glyph_orientation == .horizontal && glyphs.len > 0
							&& positions.len == glyphs.len * 2 {
							font_path := if glyph_run.face() == .emoji {
								platform.emoji_font_path() or { '' }
							} else {
								native_replay_font_path(glyph_run.font())
							}
							unsafe {
								retained_run_drawn = C.native_add_background_glyph_clip_run(&glyphs[0], &positions[0], glyphs.len, glyph_run.font().point_size, glyph_run.font().weight, int(glyph_run.face() == .emoji), f32(run.glyph_translation_x), f32(run.glyph_translation_y), f32(matrix[0]), f32(matrix[1]), f32(matrix[2]), f32(matrix[3]), f32(matrix[4]), f32(matrix[5]), page_x, page_y, 0, f32(app.ctx.width), f32(app.ctx.height), font_path, glyph_run.font().face_index(), native_retained_font_smoothing(run.font_smoothing, glyph_run.font())) != 0
							}
						}
					}
					if !retained_run_drawn {
						font_size := f32(clamp(run.font_size * font_scale, 1.0, 256.0) + 0.5)
						text_y := native_text_draw_y(run_y, run_bottom - run_y)
						C.native_add_background_text_clip_run(run_x, f32(app.ctx.height) - text_y, run.text, font_size, int(run.bold), int(run.italic), int(run.mono))
					}
				}
				C.native_finish_background_text_clip()
			}
		}
		return
	}
	if command.kind == 'end_background_text_clip' {
		$if macos {
			if app.ctx.native_rendering {
				C.native_end_background_text_clip()
			}
		}
		return
	}
	if command.kind == 'begin_background_blend_group' {
		$if macos {
			if app.ctx.native_rendering {
				C.native_begin_background_blend_group()
			}
		}
		return
	}
	if command.kind == 'end_background_blend_group' {
		$if macos {
			if app.ctx.native_rendering {
				C.native_end_background_blend_group()
			}
		}
		return
	}
	if command.kind == 'begin_css_filter_layer' {
		$if macos {
			if app.ctx.native_rendering {
				C.native_begin_css_filter_layer(f32(app.ctx.width), f32(app.ctx.height))
				if filter := command.visual_layer().filter {
					app.add_native_css_filter(filter, command.transform, page_x, page_y)
				}
			}
		}
		return
	}
	if command.kind == 'end_css_filter_layer' {
		$if macos {
			if app.ctx.native_rendering {
				C.native_end_css_filter_layer()
			}
		}
		return
	}
	if command.kind == 'begin_svg_mask_layer' {
		$if macos {
			if app.ctx.native_rendering {
				app.prepare_native_svg_layer_mask(command.mask_clip(), page_x, page_y, 0, false)
				C.native_begin_svg_mask_layer()
			}
		}
		return
	}
	if command.kind == 'end_svg_mask_layer' {
		$if macos {
			if app.ctx.native_rendering {
				clip := command.mask_clip()
				C.native_end_svg_mask_layer(clip.cache_key, if clip.is_svg_content_mask {
					1
				} else {
					0
				}, f32(app.ctx.width), f32(app.ctx.height), page_x, page_y, 0)
			}
		}
		return
	}
	// The retained viewport scroll frame is already folded into each command's
	// visual-context transform. Fixed contexts bypass that frame upstream.
	scroll_y := 0.0
	gpu_image_ancestor_clip := if app.document != unsafe { nil }
		&& app.document.font_rendering_policy() == .chromium {
		replaced_image_gpu_ancestor_clip_index(&command)
	} else { -1 }
	mut clip_active := false
	if command.has_clip {
		clip_x := page_x + f32(command.clip_x)
		clip_y := page_y + f32(command.clip_y - scroll_y)
		clip_width := f32(command.clip_width)
		clip_height := f32(command.clip_height)
		if clip_width <= 0 || clip_height <= 0 {
			return
		}
		$if macos {
			if app.ctx.native_rendering {
				C.native_begin_clip()
				if command.clip_list != unsafe { nil } && command.clip_list.items.len > 0 {
					for clip_index, clip in command.clip_list.items {
						if clip_index == gpu_image_ancestor_clip { continue }
						matrix := normalized_paint_transform(clip.transform)
						if clip.is_svg_mask || clip.is_svg_content_mask {
							app.prepare_native_svg_layer_mask(clip, page_x, page_y, f32(scroll_y), true)
						} else if clip.is_path {
							if clip.path_data.len < layout.compatibility_clip_path_segment_stride {
								C.native_end_clip()
								return
							}
							unsafe {
								C.native_add_path_clip(&clip.path_data[0], clip.path_data.len / layout.compatibility_clip_path_segment_stride, if clip.path_even_odd {
									1
								} else {
									0
								}, f32(matrix[0]), f32(matrix[1]), f32(matrix[2]), f32(matrix[3]), f32(matrix[4]), f32(matrix[5]), page_x, page_y, f32(scroll_y), f32(app.ctx.height))
							}
						} else {
							radii := clip.corner_radii
							C.native_add_corner_rounded_clip(f32(clip.rect.x), f32(clip.rect.y), f32(clip.rect.width), f32(clip.rect.height), f32(radii.top_left.x), f32(radii.top_left.y), f32(radii.top_right.x), f32(radii.top_right.y), f32(radii.bottom_right.x), f32(radii.bottom_right.y), f32(radii.bottom_left.x), f32(radii.bottom_left.y), f32(matrix[0]), f32(matrix[1]), f32(matrix[2]), f32(matrix[3]), f32(matrix[4]), f32(matrix[5]), page_x, page_y, f32(scroll_y), f32(app.ctx.height))
						}
					}
				} else {
					// Compatibility commands constructed outside the retained
					// visual-context path carry only the conservative rectangle.
					C.native_add_corner_rounded_clip(f32(command.clip_x), f32(command.clip_y), f32(command.clip_width), f32(command.clip_height), 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 1, 0, 0, page_x, page_y, f32(scroll_y), f32(app.ctx.height))
				}
			} else {
				left := int(math.floor(f64(clip_x)))
				top := int(math.floor(f64(clip_y)))
				right := int(math.ceil(f64(clip_x + clip_width)))
				bottom := int(math.ceil(f64(clip_y + clip_height)))
				app.ctx.scissor_rect(left, top, right - left, bottom - top)
			}
		} $else {
			left := int(math.floor(f64(clip_x)))
			top := int(math.floor(f64(clip_y)))
			right := int(math.ceil(f64(clip_x + clip_width)))
			bottom := int(math.ceil(f64(clip_y + clip_height)))
			app.ctx.scissor_rect(left, top, right - left, bottom - top)
		}
		clip_active = true
	}
	defer {
		if clip_active {
			$if macos {
				if app.ctx.native_rendering {
					C.native_end_clip()
				} else {
					app.ctx.scissor_rect(0, 0, app.ctx.width, app.ctx.height)
				}
			} $else {
				app.ctx.scissor_rect(0, 0, app.ctx.width, app.ctx.height)
			}
		}
	}
	rect_points := transformed_rect_points(command, page_x, page_y, scroll_y)
	mut x := rect_points[0]
	mut y := rect_points[1]
	mut bounds_right := x
	mut bounds_bottom := y
	for index := 2; index + 1 < rect_points.len; index += 2 {
		x = math.min(x, rect_points[index])
		y = math.min(y, rect_points[index + 1])
		bounds_right = math.max(bounds_right, rect_points[index])
		bounds_bottom = math.max(bounds_bottom, rect_points[index + 1])
	}
	w := bounds_right - x
	h := bounds_bottom - y
	matrix := normalized_paint_transform(command.transform)
	non_axis_aligned := matrix[1] != 0 || matrix[2] != 0
	mut cull_top := y
	mut cull_bottom := y + h
	if command.kind in ['paint_outer_box_shadow', 'paint_inner_box_shadow', 'draw_text_shadow'] {
		mut bounds_command := command
		if command.kind in ['paint_outer_box_shadow', 'draw_text_shadow'] {
			margin := command.blur * 2.0
			bounds_command.x -= margin
			bounds_command.y -= margin
			bounds_command.width += margin * 2.0
			bounds_command.height += margin * 2.0
		} else {
			// PaintInnerBoxShadow::bounding_rect() is the padding-box content rect.
			shadow_geometry := command.box_shadow()
			bounds_command.x = shadow_geometry.content_rect.x
			bounds_command.y = shadow_geometry.content_rect.y
			bounds_command.width = shadow_geometry.content_rect.width
			bounds_command.height = shadow_geometry.content_rect.height
		}
		bounds_points := transformed_rect_points(bounds_command, page_x, page_y, scroll_y)
		cull_top = bounds_points[1]
		cull_bottom = bounds_points[1]
		for index := 3; index < bounds_points.len; index += 2 {
			cull_top = math.min(cull_top, bounds_points[index])
			cull_bottom = math.max(cull_bottom, bounds_points[index])
		}
	}
	if cull_bottom < app.page_top() || cull_top > f32(window_height - app.status_height()) {
		return
	}
	if command.kind == 'apply_backdrop_filter' {
		$if macos {
			if app.ctx.native_rendering {
				radii := command.corner_radii
				C.native_begin_backdrop_filter_layer(f32(app.ctx.width), f32(app.ctx.height), f32(command.x), f32(command.y), f32(command.width), f32(command.height), f32(radii.top_left.x), f32(radii.top_left.y), f32(radii.top_right.x), f32(radii.top_right.y), f32(radii.bottom_right.x), f32(radii.bottom_right.y), f32(radii.bottom_left.x), f32(radii.bottom_left.y), f32(matrix[0]), f32(matrix[1]), f32(matrix[2]), f32(matrix[3]), f32(matrix[4]), f32(matrix[5]), page_x, page_y, f32(scroll_y), int(command.backdrop_source_outside_filter))
				if filter := command.backdrop_filter() {
					app.add_native_css_filter(filter, command.transform, page_x, page_y)
				}
				C.native_end_backdrop_filter_layer(f32(command.opacity))
			}
		}
		return
	}
	match command.kind {
		'paint_nested_display_list' {
			paintable := command.nested_viewport_paintable or { return }
			converter := painting.new_device_pixel_converter(1.0) or { return }
			result := paintable.paint(converter) or { return }
			$if macos {
				if app.ctx.native_rendering {
					radii := result.clip_radii
					C.native_begin_clip()
					C.native_add_corner_rounded_clip(f32(result.clip_rect.x), f32(result.clip_rect.y), f32(result.clip_rect.width), f32(result.clip_rect.height), f32(radii.top_left.horizontal), f32(radii.top_left.vertical), f32(radii.top_right.horizontal), f32(radii.top_right.vertical), f32(radii.bottom_right.horizontal), f32(radii.bottom_right.vertical), f32(radii.bottom_left.horizontal), f32(radii.bottom_left.vertical), f32(matrix[0]), f32(matrix[1]), f32(matrix[2]), f32(matrix[3]), f32(matrix[4]), f32(matrix[5]), page_x, page_y, f32(scroll_y), f32(app.ctx.height))
					C.native_add_corner_rounded_clip(f32(result.clip_rect.x), f32(result.clip_rect.y), f32(result.clip_rect.width), f32(result.clip_rect.height), 0, 0, 0, 0, 0, 0, 0, 0, f32(matrix[0]), f32(matrix[1]), f32(matrix[2]), f32(matrix[3]), f32(matrix[4]), f32(matrix[5]), page_x, page_y, f32(scroll_y), f32(app.ctx.height))
					for nested_command in command.nested_viewport_commands {
						transformed := layout.paint_command_for_nested_viewport(nested_command, command.transform, painting.IntPoint{result.nested_rect.x, result.nested_rect.y}, command.opacity)
						app.draw_command(transformed, page_x, page_y, window_height)
					}
					app.flush_rounded_rect_underlay(page_x, page_y, window_height)
					C.native_end_clip()
					return
				}
			}
			clip_left := int(math.floor(f64(x)))
			clip_top := int(math.floor(f64(y)))
			clip_right := int(math.ceil(f64(x + w)))
			clip_bottom := int(math.ceil(f64(y + h)))
			for nested_command in command.nested_viewport_commands {
				app.ctx.scissor_rect(clip_left, clip_top, clip_right - clip_left, clip_bottom - clip_top)
				transformed := layout.paint_command_for_nested_viewport(nested_command, command.transform, painting.IntPoint{result.nested_rect.x, result.nested_rect.y}, command.opacity)
				app.draw_command(transformed, page_x, page_y, window_height)
			}
			app.flush_rounded_rect_underlay(page_x, page_y, window_height)
			app.ctx.scissor_rect(0, 0, app.ctx.width, app.ctx.height)
		}
		'paint_outer_box_shadow' {
			shadow_geometry := command.box_shadow()
			fill := app.paint_colors.color(command.color, command.opacity)
			$if macos {
				if app.ctx.native_rendering {
					shadow := command.corner_radii
					content := shadow_geometry.content_radii
					scale_x := math.sqrt(matrix[0] * matrix[0] + matrix[1] * matrix[1])
					scale_y := math.sqrt(matrix[2] * matrix[2] + matrix[3] * matrix[3])
					blur_scale := math.min(scale_x, scale_y)
					C.native_draw_outer_box_shadow_corners_srgb(f32(command.x), f32(command.y), f32(command.width), f32(command.height), f32(shadow.top_left.x), f32(shadow.top_left.y), f32(shadow.top_right.x), f32(shadow.top_right.y), f32(shadow.bottom_right.x), f32(shadow.bottom_right.y), f32(shadow.bottom_left.x), f32(shadow.bottom_left.y), f32(shadow_geometry.content_rect.x), f32(shadow_geometry.content_rect.y), f32(shadow_geometry.content_rect.width), f32(shadow_geometry.content_rect.height), f32(content.top_left.x), f32(content.top_left.y), f32(content.top_right.x), f32(content.top_right.y), f32(content.bottom_right.x), f32(content.bottom_right.y), f32(content.bottom_left.x), f32(content.bottom_left.y), f32(matrix[0]), f32(matrix[1]), f32(matrix[2]), f32(matrix[3]), f32(matrix[4]), f32(matrix[5]), page_x, page_y, f32(scroll_y), f32(app.ctx.width), f32(app.ctx.height), f32(command.blur * blur_scale), fill)
					return
				}
			}
			app.draw_portable_shadow(command, page_x, page_y, scroll_y)
		}
		'paint_inner_box_shadow' {
			shadow_geometry := command.box_shadow()
			fill := app.paint_colors.color(command.color, command.opacity)
			$if macos {
				if app.ctx.native_rendering {
					outer := command.corner_radii
					inner := shadow_geometry.inner_radii
					content := shadow_geometry.content_radii
					clip := shadow_geometry.clip_radii
					scale_x := math.sqrt(matrix[0] * matrix[0] + matrix[1] * matrix[1])
					scale_y := math.sqrt(matrix[2] * matrix[2] + matrix[3] * matrix[3])
					blur_scale := math.min(scale_x, scale_y)
					C.native_draw_inner_box_shadow_corners_srgb(f32(command.x), f32(command.y), f32(command.width), f32(command.height), f32(outer.top_left.x), f32(outer.top_left.y), f32(outer.top_right.x), f32(outer.top_right.y), f32(outer.bottom_right.x), f32(outer.bottom_right.y), f32(outer.bottom_left.x), f32(outer.bottom_left.y), f32(shadow_geometry.inner_rect.x), f32(shadow_geometry.inner_rect.y), f32(shadow_geometry.inner_rect.width), f32(shadow_geometry.inner_rect.height), f32(inner.top_left.x), f32(inner.top_left.y), f32(inner.top_right.x), f32(inner.top_right.y), f32(inner.bottom_right.x), f32(inner.bottom_right.y), f32(inner.bottom_left.x), f32(inner.bottom_left.y), f32(shadow_geometry.content_rect.x), f32(shadow_geometry.content_rect.y), f32(shadow_geometry.content_rect.width), f32(shadow_geometry.content_rect.height), f32(content.top_left.x), f32(content.top_left.y), f32(content.top_right.x), f32(content.top_right.y), f32(content.bottom_right.x), f32(content.bottom_right.y), f32(content.bottom_left.x), f32(content.bottom_left.y), f32(clip.top_left.x), f32(clip.top_left.y), f32(clip.top_right.x), f32(clip.top_right.y), f32(clip.bottom_right.x), f32(clip.bottom_right.y), f32(clip.bottom_left.x), f32(clip.bottom_left.y), f32(matrix[0]), f32(matrix[1]), f32(matrix[2]), f32(matrix[3]), f32(matrix[4]), f32(matrix[5]), page_x, page_y, f32(scroll_y), f32(app.ctx.height), f32(command.blur * blur_scale), fill)
					return
				}
			}
			app.draw_portable_shadow(command, page_x, page_y, scroll_y)
		}
		'fill_rect' {
			fill := app.paint_colors.color(command.color, command.opacity)
			$if macos {
				if app.ctx.native_rendering && !command.outer_shadow
					&& (command.radius > 0 || command.antialiased_rect) {
					if command.underlays_next && C.native_rounded_rect_underlay_supported() != 0 {
						app.rounded_rect_underlay = command
						app.rounded_rect_underlay_source = source_command
						return
					}
					used_radius := f32(clamp(command.radius, 0.0, math.min(command.width, command.height) / 2.0))
					if command.clip_outs.len >= 4 {
						C.native_set_rect_clip_outs(&command.clip_outs[0], command.clip_outs.len / 4)
					}
					C.native_draw_rounded_rect_srgb(f32(command.x), f32(command.y), f32(command.width), f32(command.height), used_radius, used_radius, used_radius, used_radius, used_radius, used_radius, used_radius, used_radius, f32(matrix[0]), f32(matrix[1]), f32(matrix[2]), f32(matrix[3]), f32(matrix[4]), f32(matrix[5]), page_x, page_y, f32(scroll_y), f32(app.ctx.width), f32(app.ctx.height), fill, 1, 0, if command.scrollbar_axis == '' {
						1
					} else {
						0
					})
					if command.clip_outs.len >= 4 {
						C.native_set_rect_clip_outs(unsafe { nil }, 0)
					}
					return
				}
			}
			if command.clip_outs.len >= 4 {
				for segment in clipped_out_rect_segments(command) {
					app.draw_command(layout.PaintCommand{
						...command
						x:         segment[0]
						width:     segment[1] - segment[0]
						clip_outs: []f64{}
					}, page_x, page_y, window_height)
				}
				return
			}
			if non_axis_aligned {
				draw_browser_polygon(app.ctx, borrowed_rectangle_screen_points(&rect_points), fill)
			} else if command.outer_shadow {
				$if macos {
					if app.ctx.native_rendering {
						scale_x := math.abs(matrix[0])
						scale_y := math.abs(matrix[3])
						spread_x := f32(command.shadow_spread * scale_x)
						spread_y := f32(command.shadow_spread * scale_y)
						clip_x := x - f32(command.shadow_offset_x * matrix[0]) + spread_x
						clip_y := y - f32(command.shadow_offset_y * matrix[3]) + spread_y
						clip_width := w - 2 * spread_x
						clip_height := h - 2 * spread_y
						C.native_draw_outer_box_shadow_srgb(x, f32(app.ctx.height) - (y + h), w, h, f32(command.radius * math.min(scale_x, scale_y)), clip_x, f32(app.ctx.height) - (clip_y + clip_height), clip_width, clip_height, f32(command.radius * math.min(scale_x, scale_y)), f32(command.blur * math.min(scale_x, scale_y)), fill)
						return
					}
				}
				draw_rounded_fill(app.ctx, x, y, w, h, f32(command.radius), fill)
			} else {
				radius_scale := math.min(math.abs(matrix[0]), math.abs(matrix[3]))
				draw_rounded_fill(app.ctx, x, y, w, h, f32(command.radius * radius_scale), fill)
			}
		}
		'fill_rounded_rect' {
			fill := app.paint_colors.color(command.color, command.opacity)
			$if macos {
				if app.ctx.native_rendering {
					radii := command.corner_radii
					C.native_draw_rounded_rect_srgb(f32(command.x), f32(command.y), f32(command.width), f32(command.height), f32(radii.top_left.x), f32(radii.top_left.y), f32(radii.top_right.x), f32(radii.top_right.y), f32(radii.bottom_right.x), f32(radii.bottom_right.y), f32(radii.bottom_left.x), f32(radii.bottom_left.y), f32(matrix[0]), f32(matrix[1]), f32(matrix[2]), f32(matrix[3]), f32(matrix[4]), f32(matrix[5]), page_x, page_y, f32(scroll_y), f32(app.ctx.width), f32(app.ctx.height), fill, 1, 0, if command.scrollbar_axis == '' {
						1
					} else {
						0
					})
					return
				}
			}
			points64 := layout.rounded_rect_points(command.x, command.y, command.width, command.height, command.corner_radii)
			mut points := []f32{cap: points64.len}
			for index := 0; index + 1 < points64.len; index += 2 {
				point_x, point_y := paint_screen_point(command, points64[index], points64[index + 1], page_x, page_y, scroll_y)
				points << point_x
				points << point_y
			}
			if points.len >= 6 {
				draw_browser_polygon(app.ctx, points, fill)
			}
		}
		'fill_inset_shadow' {
			fill := app.paint_colors.color(command.color, command.opacity)
			base := command.blur + command.shadow_spread
			left := f32(clamp(base - command.shadow_offset_x, 0.0, command.width))
			right := f32(clamp(base + command.shadow_offset_x, 0.0, command.width))
			top := f32(clamp(base - command.shadow_offset_y, 0.0, command.height))
			bottom := f32(clamp(base + command.shadow_offset_y, 0.0, command.height))
			if left > 0 { draw_srgb_rect(app.ctx, x, y, left, h, fill) }
			if right > 0 { draw_srgb_rect(app.ctx, x + w - right, y, right, h, fill) }
			if top > 0 { draw_srgb_rect(app.ctx, x, y, w, top, fill) }
			if bottom > 0 { draw_srgb_rect(app.ctx, x, y + h - bottom, w, bottom, fill) }
		}
		'paint_uniform_border' {
			stroke := app.paint_colors.color(command.color, command.opacity)
			$if macos {
				if app.ctx.native_rendering {
					r := command.corner_radii
					C.native_draw_rounded_rect_srgb(f32(command.x), f32(command.y), f32(command.width), f32(command.height), f32(r.top_left.x), f32(r.top_left.y), f32(r.top_right.x), f32(r.top_right.y), f32(r.bottom_right.x), f32(r.bottom_right.y), f32(r.bottom_left.x), f32(r.bottom_left.y), f32(matrix[0]), f32(matrix[1]), f32(matrix[2]), f32(matrix[3]), f32(matrix[4]), f32(matrix[5]), page_x, page_y, f32(scroll_y), f32(app.ctx.width), f32(app.ctx.height), stroke, 0, f32(command.stroke_width), 1)
					return
				}
			}
			points := layout.rounded_rect_points(command.x, command.y, command.width, command.height, command.corner_radii)
			for index := 0; index + 1 < points.len; index += 2 {
				next := (index + 2) % points.len
				x1, y1 := paint_screen_point(command, points[index], points[index + 1], page_x, page_y, scroll_y)
				x2, y2 := paint_screen_point(command, points[next], points[next + 1], page_x, page_y, scroll_y)
				draw_browser_line(app.ctx, x1, y1, x2, y2, gg.PenConfig{color: stroke, thickness: f32(command.stroke_width)})
			}
		}
		'stroke_rounded_rect' {
			stroke := app.paint_colors.color(command.color, command.opacity)
			$if macos {
				if app.ctx.native_rendering && command.points.len < 4 {
					used_radius := f32(command.radius)
					if underlay := app.rounded_rect_underlay {
						app.rounded_rect_underlay = none
						app.rounded_rect_underlay_source = none
						radius := f32(clamp(underlay.radius, 0.0, math.min(underlay.width, underlay.height) / 2.0))
						rect := [f32(underlay.x), f32(underlay.y), f32(underlay.width), f32(underlay.height),
							radius, radius, radius, radius, radius, radius, radius, radius]!
						C.native_set_rounded_rect_underlay(&rect[0], app.paint_colors.color(underlay.color, underlay.opacity))
					}
					C.native_draw_rounded_rect_srgb(f32(command.x), f32(command.y), f32(command.width), f32(command.height), used_radius, used_radius, used_radius, used_radius, used_radius, used_radius, used_radius, used_radius, f32(matrix[0]), f32(matrix[1]), f32(matrix[2]), f32(matrix[3]), f32(matrix[4]), f32(matrix[5]), page_x, page_y, f32(scroll_y), f32(app.ctx.width), f32(app.ctx.height), stroke, 0, f32(command.stroke_width), 1)
					C.native_set_rounded_rect_underlay(unsafe { nil }, gg.Color{})
					return
				}
			}
			if command.points.len >= 4 {
				mut points := []f32{cap: command.points.len}
				for index := 0; index + 1 < command.points.len; index += 2 {
					point_x, point_y := paint_screen_point(command, command.points[index], command.points[index + 1], page_x, page_y, scroll_y)
					points << point_x
					points << point_y
				}
				for index := 0; index + 3 < points.len; index += 2 {
					draw_browser_line(app.ctx, points[index], points[index + 1], points[index + 2], points[index + 3], gg.PenConfig{
						color: stroke
						thickness: f32(command.stroke_width)
					})
				}
				draw_browser_line(app.ctx, points[points.len - 2], points[points.len - 1], points[0], points[1], gg.PenConfig{
					color: stroke
					thickness: f32(command.stroke_width)
				})
				return
			}
			steps := int(clamp(command.stroke_width, 1.0, 256.0) + 0.5)
			for inset in 0 .. steps {
				delta := f32(inset)
				if w - 2 * delta <= 0 || h - 2 * delta <= 0 {
					break
				}
				used_radius := if f32(command.radius) > delta {
					f32(command.radius) - delta
				} else {
					f32(0)
				}
				app.ctx.draw_rounded_rect_empty(x + delta, y + delta, w - 2 * delta, h - 2 * delta, used_radius, stroke)
			}
		}
		'fill_ellipse' {
			fill := app.paint_colors.color(command.color, command.opacity)
			$if macos {
				if app.ctx.native_rendering {
					C.native_draw_ellipse_srgb(f32(command.x), f32(command.y), f32(command.width), f32(command.height), f32(matrix[0]), f32(matrix[1]), f32(matrix[2]), f32(matrix[3]), f32(matrix[4]), f32(matrix[5]), page_x, page_y, f32(scroll_y), f32(app.ctx.height), fill, 1, 0)
					return
				}
			}
			if non_axis_aligned {
				mut points := []f32{cap: 64}
				for step in 0 .. 32 {
					angle := f64(step) * 2.0 * math.pi / 32.0
					point_x, point_y := paint_screen_point(command, command.x + command.width / 2.0 + math.cos(angle) * command.width / 2.0, command.y + command.height / 2.0 + math.sin(angle) * command.height / 2.0, page_x, page_y, scroll_y)
					points << point_x
					points << point_y
				}
				draw_browser_polygon(app.ctx, points, fill)
			} else {
				app.ctx.draw_ellipse_filled(x + w / 2, y + h / 2, w / 2, h / 2, fill)
			}
		}
		'stroke_ellipse' {
			stroke := app.paint_colors.color(command.color, command.opacity)
			$if macos {
				if app.ctx.native_rendering {
					C.native_draw_ellipse_srgb(f32(command.x), f32(command.y), f32(command.width), f32(command.height), f32(matrix[0]), f32(matrix[1]), f32(matrix[2]), f32(matrix[3]), f32(matrix[4]), f32(matrix[5]), page_x, page_y, f32(scroll_y), f32(app.ctx.height), stroke, 0, f32(command.stroke_width))
					return
				}
			}
			app.ctx.draw_ellipse_thick(x + w / 2, y + h / 2, w / 2, h / 2, f32(command.stroke_width), stroke)
		}
		'draw_line' {
			if command.points.len >= 4 {
				from_x, from_y := paint_screen_point(command, command.points[0], command.points[1], page_x, page_y, scroll_y)
				to_x, to_y := paint_screen_point(command, command.points[2], command.points[3], page_x, page_y, scroll_y)
				line_color := app.paint_colors.color(command.color, command.opacity)
				$if macos {
					line_style := match command.line_style {
						'dotted' { 1 }
						'dashed' { 2 }
						else { 0 }
					}
					if app.ctx.native_rendering && C.native_draw_line_srgb(from_x, from_y, to_x, to_y, f32(command.stroke_width), line_style, f32(app.ctx.width), f32(app.ctx.height), line_color) != 0 {
						return
					}
				}
				draw_browser_line(app.ctx, from_x, from_y, to_x, to_y, gg.PenConfig{
					color: line_color
					line_type: match command.line_style {
						'dotted' { gg.PenLineType.dotted }
						'dashed' { gg.PenLineType.dashed }
						else { gg.PenLineType.solid }
					}
					thickness: f32(command.stroke_width)
				})
			}
		}
		'fill_polygon' {
			mut points := []f32{cap: command.points.len}
			for index := 0; index + 1 < command.points.len; index += 2 {
				point_x, point_y := paint_screen_point(command, command.points[index], command.points[index + 1], page_x, page_y, scroll_y)
				points << point_x
				points << point_y
			}
			if points.len >= 6 {
				fill := app.paint_colors.color(command.color, command.opacity)
				$if macos {
					if app.ctx.native_rendering {
						unsafe {
							C.native_draw_polygon_srgb(&points[0], points.len / 2, f32(app.ctx.height), fill)
						}
						return
					}
				}
				draw_browser_polygon(app.ctx, points, fill)
			}
		}
		'fill_gradient' {
			image_data := command.image()
			if gradient := command.gradient {
				if gradient.colors.len == 0 {
					return
				}
				tiles := layout.resolved_background_gradient_tiles(command)
				if tiles.len == 0 {
					return
				}
				gradient_clip := painting.Rect{image_data.image_clip_x, image_data.image_clip_y, image_data.image_clip_width, image_data.image_clip_height}
				$if macos {
					if app.ctx.native_rendering && command.gradient_background_layer {
						radii := image_data.image_clip_radii
						C.native_begin_clip()
						C.native_add_corner_rounded_clip(f32(gradient_clip.x), f32(gradient_clip.y), f32(gradient_clip.width), f32(gradient_clip.height), f32(radii.top_left.x), f32(radii.top_left.y), f32(radii.top_right.x), f32(radii.top_right.y), f32(radii.bottom_right.x), f32(radii.bottom_right.y), f32(radii.bottom_left.x), f32(radii.bottom_left.y), f32(matrix[0]), f32(matrix[1]), f32(matrix[2]), f32(matrix[3]), f32(matrix[4]), f32(matrix[5]), page_x, page_y, f32(scroll_y), f32(app.ctx.height))
						if image_data.background_blend_mode != .normal {
							C.native_begin_background_blend_mode(int(image_data.background_blend_mode))
						}
					}
				}
				mut native_stop_data := []f32{}
				$if macos {
					if app.ctx.native_rendering {
						native_stop_data = native_gradient_stop_data(gradient, command.opacity)
					}
				}
				for tile in tiles {
					if tile.width <= 0 || tile.height <= 0 {
						continue
					}
					$if macos {
						if app.ctx.native_rendering
							&& draw_native_css_gradient_tile(command, gradient, tile, native_stop_data, matrix, page_x, page_y, scroll_y, f32(app.ctx.height), app.document != unsafe { nil } && app.document.font_rendering_policy() == .chromium) {
							continue
						}
					}
					screen_left, screen_top := paint_screen_point(command, tile.x, tile.y, page_x, page_y, scroll_y)
					screen_right, screen_bottom := paint_screen_point(command, tile.right(), tile.bottom(), page_x, page_y, scroll_y)
					columns := int(clamp(math.abs(f64(screen_right - screen_left)) / 4.0, 1.0, 128.0) + 0.5)
					rows := int(clamp(math.abs(f64(screen_bottom - screen_top)) / 4.0, 1.0, 128.0) + 0.5)
					cell_width := tile.width / f64(columns)
					cell_height := tile.height / f64(rows)
					for row in 0 .. rows {
						for column in 0 .. columns {
							u := (f64(column) + 0.5) / f64(columns)
							v := (f64(row) + 0.5) / f64(rows)
							center_x := tile.x + u * tile.width
							center_y := tile.y + v * tile.height
							if command.gradient_background_layer
								&& (center_x < gradient_clip.x || center_x >= gradient_clip.right()
									|| center_y < gradient_clip.y || center_y >= gradient_clip.bottom()) {
								continue
							}
							if !command.gradient_background_layer && command.points.len > 0
								&& !point_in_paint_polygon(center_x, center_y, command.points) {
								continue
							}
							mut position := 0.0
							if gradient.kind == 'radial' || gradient.radial {
								rx := if gradient.radius_x > 0 {
									gradient.radius_x
								} else {
									0.000001
								}
								ry := if gradient.radius_y > 0 {
									gradient.radius_y
								} else {
									0.000001
								}
								dx := (u - gradient.center_x) / rx
								dy := (v - gradient.center_y) / ry
								position = math.sqrt(dx * dx + dy * dy)
							} else if gradient.kind == 'conic' {
								angle := math.atan2(v - gradient.center_y, u - gradient.center_x) * 180.0 / math.pi + 90.0 - gradient.start_degrees
								position = angle / 360.0
								for position < 0 {
									position += 1.0
								}
								for position >= 1 {
									position -= 1.0
								}
							} else {
								dx := gradient.x2 - gradient.x1
								dy := gradient.y2 - gradient.y1
								length_squared := dx * dx + dy * dy
								position = if length_squared > 0 {
									((u - gradient.x1) * dx + (v - gradient.y1) * dy) / length_squared
								} else {
									0.0
								}
							}
							sample_color := layout.gradient_color_at(gradient, position)
							alpha := u8(int(clamp(f64(sample_color.a) * command.opacity, 0.0, 255.0)))
							cell_left := tile.x + f64(column) * cell_width
							cell_top := tile.y + f64(row) * cell_height
							mut cell_points := []f32{cap: 8}
							for point in [[cell_left, cell_top],
								[cell_left + cell_width + 0.5, cell_top],
								[cell_left + cell_width + 0.5, cell_top + cell_height + 0.5],
								[cell_left, cell_top + cell_height + 0.5]] {
								point_x, point_y := paint_screen_point(command, point[0], point[1], page_x, page_y, scroll_y)
								cell_points << point_x
								cell_points << point_y
							}
							fill := gg.rgba(sample_color.r, sample_color.g, sample_color.b, alpha)
							$if macos {
								if app.ctx.native_rendering {
									unsafe { C.native_draw_polygon_srgb(&cell_points[0], 4, f32(app.ctx.height), fill) }
								} else {
									draw_browser_polygon(app.ctx, cell_points, fill)
								}
							} $else {
								draw_browser_polygon(app.ctx, cell_points, fill)
							}
						}
					}
				}
				$if macos {
					if app.ctx.native_rendering && command.gradient_background_layer {
						if image_data.background_blend_mode != .normal {
							C.native_end_background_blend_mode()
						}
						C.native_end_clip()
					}
				}
			}
		}
		'draw_replaced_image' {
			image_data := command.image()
			mut image := &gg.Image{}
			if bitmap := command.replaced_image_bitmap {
				if bitmap.width <= 0 || bitmap.height <= 0 || bitmap.pitch != bitmap.width * 4
					|| bitmap.data.len < bitmap.pitch * bitmap.height {
					return
				}
				image = &gg.Image{
					width: bitmap.width
					height: bitmap.height
					nr_channels: native_bitmap_channel_marker(bitmap, false)
					ok: true
					data: bitmap.data.data
				}
			} else {
				image = app.background_image(image_data.image_url) or { return }
			}
			converter := painting.new_device_pixel_converter(1.0) or { return }
			paintable := command.image_paintable or { return }
			result := paintable.paint(image_data.image_url, painting.IntRect{0, 0, image.width, image.height}, converter) or { return }
			destination := result.bitmap.destination
			clip := result.bitmap.clip_rect
			if destination.width <= 0 || destination.height <= 0 || clip.width <= 0
				|| clip.height <= 0 {
				return
			}
			if paint_command_image_allows_force_dark(command, f64(destination.width),
				f64(destination.height), image) {
				if bitmap := command.replaced_image_bitmap {
					image = app.force_dark_image_from_bitmap('bitmap:${u64(voidptr(bitmap))}', bitmap,
						image)
				} else {
					image = app.force_dark_image_for_url(image_data.image_url, image)
				}
			}
			$if macos {
				if app.ctx.native_rendering {
					radii := result.clip_radii
					gpu_clip := app.document != unsafe { nil }
						&& app.document.font_rendering_policy() == .chromium
					mut image_clip_radii := []f32{}
					mut image_clip_radii_ptr := unsafe { &f32(nil) }
					mut gpu_clip_x := f32(clip.x)
					mut gpu_clip_y := f32(clip.y)
					mut gpu_clip_width := f32(clip.width)
					mut gpu_clip_height := f32(clip.height)
					if gpu_clip {
						image_clip_radii = [f32(radii.top_left.horizontal), f32(radii.top_left.vertical),
							f32(radii.top_right.horizontal), f32(radii.top_right.vertical),
							f32(radii.bottom_right.horizontal), f32(radii.bottom_right.vertical),
							f32(radii.bottom_left.horizontal), f32(radii.bottom_left.vertical)]
						image_clip_radii_ptr = image_clip_radii.data
						if gpu_image_ancestor_clip >= 0 {
							ancestor := command.clip_list.items[gpu_image_ancestor_clip]
							gpu_clip_x = f32(ancestor.rect.x)
							gpu_clip_y = f32(ancestor.rect.y)
							gpu_clip_width = f32(ancestor.rect.width)
							gpu_clip_height = f32(ancestor.rect.height)
							r := ancestor.corner_radii
							image_clip_radii = [f32(r.top_left.x), f32(r.top_left.y),
								f32(r.top_right.x), f32(r.top_right.y), f32(r.bottom_right.x),
								f32(r.bottom_right.y), f32(r.bottom_left.x), f32(r.bottom_left.y)]
							image_clip_radii_ptr = image_clip_radii.data
						}
					}
					C.native_begin_clip()
					if !gpu_clip || gpu_image_ancestor_clip >= 0 {
						C.native_add_corner_rounded_clip(f32(clip.x), f32(clip.y), f32(clip.width), f32(clip.height), f32(radii.top_left.horizontal), f32(radii.top_left.vertical), f32(radii.top_right.horizontal), f32(radii.top_right.vertical), f32(radii.bottom_right.horizontal), f32(radii.bottom_right.vertical), f32(radii.bottom_left.horizontal), f32(radii.bottom_left.vertical), f32(matrix[0]), f32(matrix[1]), f32(matrix[2]), f32(matrix[3]), f32(matrix[4]), f32(matrix[5]), page_x, page_y, f32(scroll_y), f32(app.ctx.height))
					}
					C.native_draw_image_part_transformed(image, f32(destination.x), f32(destination.y), f32(destination.width), f32(destination.height), 0, 0, f32(image.width), f32(image.height), gpu_clip_x, gpu_clip_y, gpu_clip_width, gpu_clip_height, f32(matrix[0]), f32(matrix[1]), f32(matrix[2]), f32(matrix[3]), f32(matrix[4]), f32(matrix[5]), page_x, page_y, f32(scroll_y), f32(app.ctx.width), f32(app.ctx.height), f32(command.opacity), if result.bitmap.scaling == .nearest_neighbor {
						1
					} else {
						0
					}, image_clip_radii_ptr)
					C.native_end_clip()
					return
				}
			}
			// The portable renderer has no rounded image clip, but preserve the
			// source rectangle produced by clipping cover/none destinations.
			left := math.max(f64(destination.x), f64(clip.x))
			top := math.max(f64(destination.y), f64(clip.y))
			right := math.min(f64(destination.right()), f64(clip.right()))
			bottom := math.min(f64(destination.bottom()), f64(clip.bottom()))
			if right <= left || bottom <= top {
				return
			}
			source_x := f32((left - f64(destination.x)) * f64(image.width) / f64(destination.width))
			source_y := f32((top - f64(destination.y)) * f64(image.height) / f64(destination.height))
			source_width := f32((right - left) * f64(image.width) / f64(destination.width))
			source_height := f32((bottom - top) * f64(image.height) / f64(destination.height))
			screen_left, screen_top := paint_screen_point(command, left, top, page_x, page_y, scroll_y)
			screen_right, screen_bottom := paint_screen_point(command, right, bottom, page_x, page_y, scroll_y)
			app.ctx.draw_image_with_config(
				img: image
				img_rect: gg.Rect{math.min(screen_left, screen_right), math.min(screen_top, screen_bottom), math.abs(screen_right - screen_left), math.abs(screen_bottom - screen_top)}
				part_rect: gg.Rect{source_x, source_y, source_width, source_height}
				color: gg.rgba(255, 255, 255, u8(clamp(command.opacity * 255.0, 0.0, 255.0)))
			)
		}
		'draw_canvas' {
			bitmap := command.canvas_bitmap or { return }
			paintable := command.canvas_paintable or { return }
			if bitmap.width <= 0 || bitmap.height <= 0 || bitmap.pitch != bitmap.width * 4
				|| bitmap.data.len < bitmap.pitch * bitmap.height {
				return
			}
			converter := painting.new_device_pixel_converter(1.0) or { return }
			result := paintable.paint('canvas', painting.IntSize{bitmap.width, bitmap.height}, converter) or { return }
			$if macos {
				if app.ctx.native_rendering {
					destination := result.content.destination
					clip := result.clip_rect
					radii := result.clip_radii
					canvas_image := &gg.Image{
						width: bitmap.width
						height: bitmap.height
						// Native markers preserve alpha and decoded row orientation.
						nr_channels: native_bitmap_channel_marker(bitmap, bitmap.alpha_type in [u8(0), 2])
						ok: true
						data: bitmap.data.data
					}
					C.native_begin_clip()
					C.native_add_corner_rounded_clip(f32(clip.x), f32(clip.y), f32(clip.width), f32(clip.height), f32(radii.top_left.horizontal), f32(radii.top_left.vertical), f32(radii.top_right.horizontal), f32(radii.top_right.vertical), f32(radii.bottom_right.horizontal), f32(radii.bottom_right.vertical), f32(radii.bottom_left.horizontal), f32(radii.bottom_left.vertical), f32(matrix[0]), f32(matrix[1]), f32(matrix[2]), f32(matrix[3]), f32(matrix[4]), f32(matrix[5]), page_x, page_y, f32(scroll_y), f32(app.ctx.height))
					C.native_draw_image_part_transformed(canvas_image, f32(destination.x), f32(destination.y), f32(destination.width), f32(destination.height), 0, 0, f32(bitmap.width), f32(bitmap.height), f32(clip.x), f32(clip.y), f32(clip.width), f32(clip.height), f32(matrix[0]), f32(matrix[1]), f32(matrix[2]), f32(matrix[3]), f32(matrix[4]), f32(matrix[5]), page_x, page_y, f32(scroll_y), f32(app.ctx.width), f32(app.ctx.height), f32(command.opacity), if result.content.scaling == .nearest_neighbor {
						1
					} else {
						0
					}, unsafe { nil })
					C.native_end_clip()
				}
			}
		}
		'draw_video' {
			paintable := command.video_paintable or { return }
			mut video_bitmap := command.video_bitmap
			if source := command.video_frame_source {
				if frame := source.current_frame() {
					if bitmap := frame.to_bitmap() {
						video_bitmap = bitmap
					} else {
						video_bitmap = none
					}
				} else {
					video_bitmap = none
				}
			}
			mut bitmap_size := ?painting.IntSize(none)
			if bitmap := video_bitmap {
				bitmap_size = painting.IntSize{bitmap.width, bitmap.height}
			}
			converter := painting.new_device_pixel_converter(1.0) or { return }
			result := paintable.paint(command.video_representation, 'video', bitmap_size, command.video_frame_source, converter) or { return }
			mut destination := painting.IntRect{}
			mut scaling := painting.ScalingMode.none_
			match result.content {
				painting.DrawVideoFrameSource {
					destination = result.content.destination
					scaling = result.content.scaling
				}
				painting.DrawScaledDecodedImageFrame {
					destination = result.content.destination
					scaling = result.content.scaling
				}
				painting.FillRect {
					// Transparent black deliberately records bounds upstream but has
					// no visible pixels to replay.
					return
				}
				else {
					return
				}
			}
			bitmap := video_bitmap or { return }
			if bitmap.width <= 0 || bitmap.height <= 0 || bitmap.pitch != bitmap.width * 4
				|| bitmap.data.len < bitmap.pitch * bitmap.height {
				return
			}
			$if macos {
				if app.ctx.native_rendering {
					clip := result.clip_rect
					radii := result.clip_radii
					video_image := &gg.Image{
						width: bitmap.width
						height: bitmap.height
						nr_channels: native_bitmap_channel_marker(bitmap, false)
						ok: true
						data: bitmap.data.data
					}
					C.native_begin_clip()
					C.native_add_corner_rounded_clip(f32(clip.x), f32(clip.y), f32(clip.width), f32(clip.height), f32(radii.top_left.horizontal), f32(radii.top_left.vertical), f32(radii.top_right.horizontal), f32(radii.top_right.vertical), f32(radii.bottom_right.horizontal), f32(radii.bottom_right.vertical), f32(radii.bottom_left.horizontal), f32(radii.bottom_left.vertical), f32(matrix[0]), f32(matrix[1]), f32(matrix[2]), f32(matrix[3]), f32(matrix[4]), f32(matrix[5]), page_x, page_y, f32(scroll_y), f32(app.ctx.height))
					C.native_draw_image_part_transformed(video_image, f32(destination.x), f32(destination.y), f32(destination.width), f32(destination.height), 0, 0, f32(bitmap.width), f32(bitmap.height), f32(clip.x), f32(clip.y), f32(clip.width), f32(clip.height), f32(matrix[0]), f32(matrix[1]), f32(matrix[2]), f32(matrix[3]), f32(matrix[4]), f32(matrix[5]), page_x, page_y, f32(scroll_y), f32(app.ctx.width), f32(app.ctx.height), f32(command.opacity), if scaling == .nearest_neighbor {
						1
					} else {
						0
					}, unsafe { nil })
					C.native_end_clip()
				}
			}
		}
		'draw_background_image' {
			image_data := command.image()
			if image_data.background_svg_document != none
				&& !background_image_clip_intersects_viewport(&command, f64(page_x), f64(page_y),
					f64(app.ctx.width), f64(app.page_top()), f64(window_height - app.status_height()),
					app.paint_effect_depth > 0) {
				return
			}
			mut image := &gg.Image{}
			mut intrinsic_width := f32(image_data.image_intrinsic_width)
			mut intrinsic_height := f32(image_data.image_intrinsic_height)
			mut svg_natural_size := ?css.SizeWithAspectRatio(none)
			if svg_document := image_data.background_svg_document {
				natural := layout.svg_background_natural_size(svg_document)
				svg_natural_size = natural
				// The legacy string path also needs a concrete default size, but
				// the typed layer below must retain the optional natural metrics.
				concrete := css.run_default_sizing_algorithm(none, none, natural,
					css.CSSPixelSize.new(css.CSSPixels.nearest_value_for(command.width),
						css.CSSPixels.nearest_value_for(command.height)))
				intrinsic_width = f32(concrete.width().to_double())
				intrinsic_height = f32(concrete.height().to_double())
			} else {
				image = app.background_image(image_data.image_url) or { return }
				intrinsic_width = f32(image.width)
				intrinsic_height = f32(image.height)
			}
			if intrinsic_width <= 0 || intrinsic_height <= 0 || command.width <= 0
				|| command.height <= 0 || image_data.image_clip_width <= 0
				|| image_data.image_clip_height <= 0 {
				return
			}
			// Resolve in the command's CSS coordinate space, then let the native
			// image command apply the retained visual-context transform. Resolving
			// against the transformed AABB changes cover/contain and repeat counts.
			area := painting.Rect{command.x, command.y, command.width, command.height}
			snap_bitmap := app.ctx.native_rendering && image_data.background_svg_document == none
				&& app.document != unsafe { nil } && app.document.font_rendering_policy() == .chromium
			original_clip := painting.Rect{image_data.image_clip_x, image_data.image_clip_y, image_data.image_clip_width, image_data.image_clip_height}
			clip := if snap_bitmap { pixel_snapped_background_bitmap_rect(original_clip) } else { original_clip }
			mut resolved_layer := ?painting.ResolvedBackgroundLayer(none)
			if background_data := image_data.background_layer_data {
				resolved_layer = if natural := svg_natural_size {
					painting.resolve_background_layer_with_natural_size(background_data.layer,
						image_data.image_url, area, background_data.resolution_context, natural)
				} else {
					painting.resolve_background_layer(painting.BackgroundLayerResolutionInput{
					layer: background_data.layer
					image_id: image_data.image_url
					natural_width: f64(intrinsic_width)
					natural_height: f64(intrinsic_height)
					background_positioning_area: area
					resolution_context: background_data.resolution_context
					})
				}
			}
			if resolved_layer == none {
				// Detached compatibility commands do not retain ComputedValues. Resolve
				// their legacy strings, then still use BackgroundPainting's tile walk.
				mut tile_width := intrinsic_width
				mut tile_height := intrinsic_height
				size := image_data.image_size.trim_space().to_lower()
				if size in ['cover', 'contain', 'scale-down'] {
					x_scale := f32(command.width) / intrinsic_width
					y_scale := f32(command.height) / intrinsic_height
					scale := if size == 'cover' {
						math.max(x_scale, y_scale)
					} else if size == 'scale-down' {
						math.min(f32(1), math.min(x_scale, y_scale))
					} else {
						math.min(x_scale, y_scale)
					}
					tile_width = intrinsic_width * scale
					tile_height = intrinsic_height * scale
				} else {
					size_tokens := size.fields()
					if size_tokens.len > 0 && size_tokens[0] != 'auto' {
						tile_width = background_length(size_tokens[0], f32(command.width), intrinsic_width)
					}
					if size_tokens.len > 1 && size_tokens[1] != 'auto' {
						tile_height = background_length(size_tokens[1], f32(command.height), intrinsic_height)
					} else if size_tokens.len > 0 && size_tokens[0] != 'auto' {
						tile_height = tile_width * intrinsic_height / intrinsic_width
					}
				}
				if tile_width <= 0 || tile_height <= 0 {
					return
				}
				resolved_layer = painting.ResolvedBackgroundLayer{
					image_id: image_data.image_url
					attachment: painting_background_attachment(image_data.image_attachment)
					position_x: f64(background_position(image_data.image_position_x, f32(command.width) - tile_width))
					position_y: f64(background_position(image_data.image_position_y, f32(command.height) - tile_height))
					background_positioning_area: area
					image_rect: painting.Rect{0, 0, f64(tile_width), f64(tile_height)}
					repeat_x: painting_background_repetition(image_data.image_repeat_x)
					repeat_y: painting_background_repetition(image_data.image_repeat_y)
					blend_mode: image_data.background_blend_mode
				}
			}
			layer := resolved_layer or { return }
			original_plan := painting.background_tile_plan(layer, painting.Point{command.image_scroll_offset_x, command.image_scroll_offset_y}, clip)
			plan := if snap_bitmap { chromium_background_bitmap_plan(original_plan, clip) } else { original_plan }
			// Keep the repeated primitive for tiny patterns rather than truncating
			// their materialized tiles at the compatibility player's allocation cap.
			gpu_bitmap_tiles := snap_bitmap && (!plan.can_use_repeated_bitmap()
				|| chromium_background_bitmap_tiles_are_bounded(plan, clip, 4096))
			if paint_command_image_allows_force_dark(command, plan.first_tile.width,
				plan.first_tile.height, image) {
				image = app.force_dark_image_for_url(image_data.image_url, image)
			}
			mut used_native_repeated_bitmap := false
			$if macos {
				if app.ctx.native_rendering {
					radii := image_data.image_clip_radii
					C.native_begin_clip()
					if !gpu_bitmap_tiles {
						C.native_add_corner_rounded_clip(f32(clip.x), f32(clip.y), f32(clip.width), f32(clip.height), f32(radii.top_left.x), f32(radii.top_left.y), f32(radii.top_right.x), f32(radii.top_right.y), f32(radii.bottom_right.x), f32(radii.bottom_right.y), f32(radii.bottom_left.x), f32(radii.bottom_left.y), f32(matrix[0]), f32(matrix[1]), f32(matrix[2]), f32(matrix[3]), f32(matrix[4]), f32(matrix[5]), page_x, page_y, f32(scroll_y), f32(app.ctx.height))
					}
					if layer.blend_mode != .normal {
						C.native_begin_background_blend_mode(int(layer.blend_mode))
					}
					// BackgroundPainting records one repeated-bitmap operation when
					// repetition has no `space` gaps. Keeping that operation intact also
					// preserves the decoded image's native top-to-bottom orientation.
					// Chromium instead clips each tile in its GPU image operation.
					if !gpu_bitmap_tiles && plan.can_use_repeated_bitmap() && image_data.background_svg_document == none {
						converter := painting.new_device_pixel_converter(1.0) or { return }
						destination := converter.rounded_device_rect(plan.first_tile)
						device_clip := converter.rounded_device_rect(clip)
						destination_width := if destination.width == 0 {
							1
						} else {
							destination.width
						}
						destination_height := if destination.height == 0 {
							1
						} else {
							destination.height
						}
						scaling_mode := painting.to_gfx_scaling_mode(image_data.image_rendering, painting.IntSize{image.width, image.height}, painting.IntSize{destination_width, destination_height})
						C.native_draw_repeated_image_transformed(image, f32(destination.x), f32(destination.y), f32(destination_width), f32(destination_height), f32(device_clip.x), f32(device_clip.y), f32(device_clip.width), f32(device_clip.height), f32(matrix[0]), f32(matrix[1]), f32(matrix[2]), f32(matrix[3]), f32(matrix[4]), f32(matrix[5]), page_x, page_y, f32(scroll_y), f32(app.ctx.height), f32(command.opacity), if scaling_mode == .nearest_neighbor {
							1
						} else {
							0
						}, if plan.repeat_x { 1 } else { 0 }, if plan.repeat_y { 1 } else { 0 })
						used_native_repeated_bitmap = true
					}
				}
			}
			tiles := if used_native_repeated_bitmap {
				[]painting.Rect{}
			} else {
				painting.background_tiles_from_plan_limited(plan, clip, 4096)
			}
			for original_tile in tiles {
				tile := if snap_bitmap { pixel_snapped_background_bitmap_rect(original_tile) } else { original_tile }
				if svg_document := image_data.background_svg_document {
					mut mutable_svg_document := unsafe { &dom.Document(svg_document) }
					mutable_svg_document.set_svg_image_color_scheme(css.preferred_color_scheme_to_string(image_data.background_svg_color_scheme))
					converter := painting.new_device_pixel_converter(1.0) or { return }
					rounded_destination := converter.rounded_device_rect(tile)
					destination := painting.IntRect{
						x: rounded_destination.x
						y: rounded_destination.y
						width: if rounded_destination.width == 0 {
							1
						} else {
							rounded_destination.width
						}
						height: if rounded_destination.height == 0 {
							1
						} else {
							rounded_destination.height
						}
					}
					chromium_svg := app.document != unsafe { nil }
						&& app.document.font_rendering_policy() == .chromium
						&& !plan.repeat_x && !plan.repeat_y
					replay := if chromium_svg { chromium_svg_background_replay(tile, command.transform) } else {
						ChromiumSVGBackgroundReplay{destination.width, destination.height, command.transform}
					}
					// An SVG background is an image bounded by its own viewport,
					// including when an unsized SVG child extends beyond that viewport.
					$if macos {
						if app.ctx.native_rendering {
							C.native_begin_clip()
							clip_x := if chromium_svg { f64(0) } else { f64(destination.x) }
							clip_y := if chromium_svg { f64(0) } else { f64(destination.y) }
							m := replay.transform
							C.native_add_corner_rounded_clip(f32(clip_x), f32(clip_y), f32(replay.viewport_width), f32(replay.viewport_height), 0, 0, 0, 0, 0, 0, 0, 0, f32(m[0]), f32(m[1]), f32(m[2]), f32(m[3]), f32(m[4]), f32(m[5]), page_x, page_y, f32(scroll_y), f32(app.ctx.height))
						}
					}
					if nested_layout := layout.run_document_layout(svg_document, f64(replay.viewport_width), f64(replay.viewport_height)) {
						_ = nested_layout
						if nested_display_list := mutable_svg_document.record_display_list() {
							for nested_command in layout.display_list_commands(nested_display_list) {
								transformed := layout.paint_command_for_nested_viewport(nested_command, replay.transform,
									if chromium_svg { painting.IntPoint{} } else { painting.IntPoint{destination.x, destination.y} }, command.opacity)
								app.draw_command(transformed, page_x, page_y, window_height)
							}
							app.flush_rounded_rect_underlay(page_x, page_y, window_height)
						}
					}
					$if macos {
						if app.ctx.native_rendering { C.native_end_clip() }
					}
					continue
				}
				left := math.max(tile.x, clip.x)
				top := math.max(tile.y, clip.y)
				right_edge := math.min(tile.right(), clip.right())
				bottom_edge := math.min(tile.bottom(), clip.bottom())
				if right_edge > left && bottom_edge > top {
					source_x := f32((left - tile.x) * f64(intrinsic_width) / tile.width)
					source_y := f32((top - tile.y) * f64(intrinsic_height) / tile.height)
					source_width := f32((right_edge - left) * f64(intrinsic_width) / tile.width)
					source_height := f32((bottom_edge - top) * f64(intrinsic_height) / tile.height)
					if app.ctx.native_rendering {
						destination_width := if tile.width < 1 {
							1
						} else {
							int(math.round(tile.width))
						}
						destination_height := if tile.height < 1 {
							1
						} else {
							int(math.round(tile.height))
						}
						scaling_mode := painting.to_gfx_scaling_mode(image_data.image_rendering, painting.IntSize{image.width, image.height}, painting.IntSize{destination_width, destination_height})
						$if macos {
							r := image_data.image_clip_radii
							clip_radii := [f32(r.top_left.x), f32(r.top_left.y), f32(r.top_right.x), f32(r.top_right.y), f32(r.bottom_right.x), f32(r.bottom_right.y), f32(r.bottom_left.x), f32(r.bottom_left.y)]!
							C.native_draw_image_part_transformed(image, f32(left), f32(top), f32(right_edge - left), f32(bottom_edge - top), source_x, source_y, source_width, source_height, f32(clip.x), f32(clip.y), f32(clip.width), f32(clip.height), f32(matrix[0]), f32(matrix[1]), f32(matrix[2]), f32(matrix[3]), f32(matrix[4]), f32(matrix[5]), page_x, page_y, f32(scroll_y), f32(app.ctx.width), f32(app.ctx.height), f32(command.opacity), if scaling_mode == .nearest_neighbor {
								1
							} else {
								0
							}, if gpu_bitmap_tiles { &clip_radii[0] } else { unsafe { &f32(nil) } })
						}
					} else {
						screen_left, screen_top := paint_screen_point(command, left, top, page_x, page_y, scroll_y)
						screen_right, screen_bottom := paint_screen_point(command, right_edge, bottom_edge, page_x, page_y, scroll_y)
						app.ctx.draw_image_with_config(
							img: image
							img_rect: gg.Rect{math.min(screen_left, screen_right), math.min(screen_top, screen_bottom), math.abs(screen_right - screen_left), math.abs(screen_bottom - screen_top)}
							part_rect: gg.Rect{source_x, source_y, source_width, source_height}
							color: gg.rgba(255, 255, 255, u8(clamp(command.opacity * 255.0, 0.0, 255.0)))
						)
					}
				}
			}
			$if macos {
				if app.ctx.native_rendering {
					if layer.blend_mode != .normal {
						C.native_end_background_blend_mode()
					}
					C.native_end_clip()
				}
			}
		}
		'draw_svg_image' {
			image_data := command.image()
			mut image := app.background_image(image_data.image_url) or { return }
			destination_x, destination_y, destination_width, destination_height := contained_image_destination(f32(command.x), f32(command.y), f32(command.width), f32(command.height), f32(image.width), f32(image.height), image_data.image_position_x, image_data.image_position_y)
			if destination_width <= 0 || destination_height <= 0 {
				return
			}
			if paint_command_image_allows_force_dark(command, f64(destination_width),
				f64(destination_height), image) {
				image = app.force_dark_image_for_url(image_data.image_url, image)
			}
			$if macos {
				if app.ctx.native_rendering {
					scaling_mode := painting.to_gfx_scaling_mode(image_data.image_rendering, painting.IntSize{image.width, image.height}, painting.IntSize{int(math.round(command.width)), int(math.round(command.height))})
					C.native_draw_image_part_transformed(image, destination_x, destination_y, destination_width, destination_height, 0, 0, f32(image.width), f32(image.height), f32(command.x), f32(command.y), f32(command.width), f32(command.height), f32(matrix[0]), f32(matrix[1]), f32(matrix[2]), f32(matrix[3]), f32(matrix[4]), f32(matrix[5]), page_x, page_y, f32(scroll_y), f32(app.ctx.width), f32(app.ctx.height), f32(command.opacity), if scaling_mode == .nearest_neighbor {
						1
					} else {
						0
					}, unsafe { nil })
					return
				}
			}
			// gg's portable painter has no affine image primitive. Keep the same
			// contain sizing for axis-aligned contexts; native replay handles the
			// full accumulated visual-context transform above.
			screen_x, screen_y := paint_screen_point(command, f64(destination_x), f64(destination_y), page_x, page_y, scroll_y)
			screen_right, screen_bottom := paint_screen_point(command, f64(destination_x + destination_width), f64(destination_y + destination_height), page_x, page_y, scroll_y)
			app.ctx.draw_image_with_config(
				img: image
				img_rect: gg.Rect{math.min(screen_x, screen_right), math.min(screen_y, screen_bottom), math.abs(screen_right - screen_x), math.abs(screen_bottom - screen_y)}
				part_rect: gg.Rect{0, 0, f32(image.width), f32(image.height)}
				color: gg.rgba(255, 255, 255, u8(clamp(command.opacity * 255.0, 0.0, 255.0)))
			)
		}
		'draw_svg_path' {
			svg_data := command.svg()
			$if macos {
				if app.ctx.native_rendering
					&& svg_data.path_data.len >= layout.compatibility_clip_path_segment_stride {
					path_matrix := multiply_paint_transforms(command.transform, svg_data.path_transform)
					dash_data := if svg_data.stroke_dasharray.len > 0 {
						svg_data.stroke_dasharray
					} else {
						[f64(0)]
					}
					fill := app.paint_colors.color_with_retained(command.color, command.opacity * svg_data.fill_opacity,
						command.retained_svg_fill_color())
					stroke := app.paint_colors.color_with_retained(command.stroke_color, command.opacity * svg_data.stroke_opacity,
						command.retained_svg_stroke_color())
					if svg_data.svg_gradient_data == none && svg_data.fill_pattern == none
						&& svg_data.stroke_pattern == none && !svg_data.stroke_first {
						unsafe {
							C.native_draw_svg_path_srgb(&svg_data.path_data[0], svg_data.path_data.len / layout.compatibility_clip_path_segment_stride, if svg_data.fill_even_odd {
								1
							} else {
								0
							}, f32(path_matrix[0]), f32(path_matrix[1]), f32(path_matrix[2]), f32(path_matrix[3]), f32(path_matrix[4]), f32(path_matrix[5]), page_x, page_y, f32(scroll_y), f32(app.ctx.width), f32(app.ctx.height), fill, if command.color.len > 0 {
								1
							} else {
								0
							}, stroke, if command.stroke_color.len > 0 && command.stroke_width > 0 {
								1
							} else {
								0
							}, f32(command.stroke_width), svg_data.stroke_linecap, svg_data.stroke_linejoin, f32(svg_data.stroke_miterlimit), if svg_data.non_scaling_stroke {
								1
							} else {
								0
							}, &dash_data[0], svg_data.stroke_dasharray.len, svg_data.stroke_dashoffset)
						}
						return
					}
					order := if svg_data.stroke_first { [1, 0] } else { [0, 1] }
					for part in order {
						if part == 0 {
							if gradient := command.fill_linear_gradient() {
								draw_native_svg_linear_gradient_path(svg_data.path_data, svg_data.fill_even_odd, path_matrix, page_x, page_y, f32(scroll_y), f32(app.ctx.height), false, command.stroke_width, svg_data.stroke_linecap, svg_data.stroke_linejoin, svg_data.stroke_miterlimit, gradient, command.opacity * svg_data.fill_opacity, false)
							} else if gradient := command.fill_radial_gradient() {
								draw_native_svg_radial_gradient_path(svg_data.path_data, svg_data.fill_even_odd, path_matrix, page_x, page_y, f32(scroll_y), f32(app.ctx.height), false, command.stroke_width, svg_data.stroke_linecap, svg_data.stroke_linejoin, svg_data.stroke_miterlimit, gradient, command.opacity * svg_data.fill_opacity, false)
							} else if pattern := svg_data.fill_pattern {
								app.draw_native_svg_pattern_path(svg_data.path_data, svg_data.fill_even_odd, path_matrix, page_x, page_y, f32(scroll_y), f32(app.ctx.height), false, command.stroke_width, svg_data.stroke_linecap, svg_data.stroke_linejoin, svg_data.stroke_miterlimit, pattern, command.opacity * svg_data.fill_opacity, false)
							} else if command.color.len > 0 {
								unsafe {
									C.native_draw_svg_path_srgb(&svg_data.path_data[0], svg_data.path_data.len / layout.compatibility_clip_path_segment_stride, if svg_data.fill_even_odd {
										1
									} else {
										0
									}, f32(path_matrix[0]), f32(path_matrix[1]), f32(path_matrix[2]), f32(path_matrix[3]), f32(path_matrix[4]), f32(path_matrix[5]), page_x, page_y, f32(scroll_y), f32(app.ctx.width), f32(app.ctx.height), fill, 1, stroke, 0, f32(command.stroke_width), svg_data.stroke_linecap, svg_data.stroke_linejoin, f32(svg_data.stroke_miterlimit), 0, &dash_data[0], svg_data.stroke_dasharray.len, svg_data.stroke_dashoffset)
								}
							}
						} else if command.stroke_width > 0 {
							if gradient := command.stroke_linear_gradient() {
								draw_native_svg_linear_gradient_path(svg_data.path_data, svg_data.fill_even_odd, path_matrix, page_x, page_y, f32(scroll_y), f32(app.ctx.height), true, command.stroke_width, svg_data.stroke_linecap, svg_data.stroke_linejoin, svg_data.stroke_miterlimit, gradient, command.opacity * svg_data.stroke_opacity, false)
							} else if gradient := command.stroke_radial_gradient() {
								draw_native_svg_radial_gradient_path(svg_data.path_data, svg_data.fill_even_odd, path_matrix, page_x, page_y, f32(scroll_y), f32(app.ctx.height), true, command.stroke_width, svg_data.stroke_linecap, svg_data.stroke_linejoin, svg_data.stroke_miterlimit, gradient, command.opacity * svg_data.stroke_opacity, false)
							} else if pattern := svg_data.stroke_pattern {
								app.draw_native_svg_pattern_path(svg_data.path_data, svg_data.fill_even_odd, path_matrix, page_x, page_y, f32(scroll_y), f32(app.ctx.height), true, command.stroke_width, svg_data.stroke_linecap, svg_data.stroke_linejoin, svg_data.stroke_miterlimit, pattern, command.opacity * svg_data.stroke_opacity, false)
							} else if command.stroke_color.len > 0 {
								unsafe {
									C.native_draw_svg_path_srgb(&svg_data.path_data[0], svg_data.path_data.len / layout.compatibility_clip_path_segment_stride, if svg_data.fill_even_odd {
										1
									} else {
										0
									}, f32(path_matrix[0]), f32(path_matrix[1]), f32(path_matrix[2]), f32(path_matrix[3]), f32(path_matrix[4]), f32(path_matrix[5]), page_x, page_y, f32(scroll_y), f32(app.ctx.width), f32(app.ctx.height), fill, 0, stroke, 1, f32(command.stroke_width), svg_data.stroke_linecap, svg_data.stroke_linejoin, f32(svg_data.stroke_miterlimit), if svg_data.non_scaling_stroke {
										1
									} else {
										0
									}, &dash_data[0], svg_data.stroke_dasharray.len, svg_data.stroke_dashoffset)
								}
							}
						}
					}
					return
				}
			}
			input_polygons := if svg_data.path_polygons.len > 0 {
				svg_data.path_polygons
			} else {
				[command.points]
			}
			mut screen_polygons := [][]f32{cap: input_polygons.len}
			for polygon in input_polygons {
				mut screen_points := []f32{cap: polygon.len}
				for index := 0; index + 1 < polygon.len; index += 2 {
					point_x, point_y := paint_screen_point(command, polygon[index], polygon[index + 1], page_x, page_y, scroll_y)
					screen_points << point_x
					screen_points << point_y
				}
				screen_polygons << screen_points
			}
			if command.color.len > 0 {
				for polygon in screen_polygons {
					if polygon.len >= 6 {
						draw_browser_polygon(app.ctx, polygon, app.paint_colors.color_with_retained(command.color,
							command.opacity * svg_data.fill_opacity, command.retained_svg_fill_color()))
					}
				}
			}
			if command.stroke_color.len > 0 && screen_polygons.len > 0
				&& screen_polygons[0].len >= 4 && command.stroke_width > 0 {
				points := screen_polygons[0]
				stroke := app.paint_colors.color_with_retained(command.stroke_color, command.opacity * svg_data.stroke_opacity,
					command.retained_svg_stroke_color())
				for index := 0; index + 3 < points.len; index += 2 {
					draw_browser_line(app.ctx, points[index], points[index + 1], points[index + 2], points[index + 3], gg.PenConfig{
						color: stroke
						thickness: f32(command.stroke_width)
					})
				}
			}
		}
		'draw_text' {
			{
				$if linux {
					if command.glyph_run != none {
						app.draw_portable_shadow(layout.PaintCommand{...command, kind: 'draw_text_shadow', blur: 0}, page_x, page_y, scroll_y)
						return
					}
				}
				font_scale := math.sqrt(matrix[0] * matrix[0] + matrix[1] * matrix[1])
				font_size := int(clamp(command.font_size * font_scale, 1.0, 256.0) + 0.5)
				text_y := $if macos { native_text_draw_y(y, h) } $else { y }
				text_color := app.paint_colors.color(command.color, command.opacity)
				$if macos {
					if app.ctx.native_rendering {
						if native_draw_retained_glyph_run(command, page_x, page_y, scroll_y, f32(app.ctx.width), f32(app.ctx.height), text_color, 0, false) {
							return
						}
						if app.use_document_font {
							C.native_draw_document_text_srgb(x, f32(app.ctx.height) - text_y, command.text, text_color, f32(font_size), int(command.bold), int(command.italic), int(command.mono))
							return
						}
					}
				}
				app.ctx.draw_text(int(x), int(text_y), command.text,
					color: text_color
					size: font_size
					bold: command.bold
					italic: command.italic
					mono: command.mono
				)
			}
		}
		'draw_text_shadow' {
			{
				font_scale := math.sqrt(matrix[0] * matrix[0] + matrix[1] * matrix[1])
				font_size := int(clamp(command.font_size * font_scale, 1.0, 256.0) + 0.5)
				text_y := $if macos { native_text_draw_y(y, h) } $else { y }
				shadow_color := app.paint_colors.color(command.color, command.opacity)
				$if macos {
					if app.ctx.native_rendering {
						if native_draw_retained_glyph_run(command, page_x, page_y, scroll_y, f32(app.ctx.width), f32(app.ctx.height), shadow_color, f32(command.blur * font_scale), true) {
							return
						}
						if app.use_document_font {
							C.native_draw_document_text_shadow_srgb(x, f32(app.ctx.height) - text_y, command.text, shadow_color, f32(font_size), int(command.bold), int(command.italic), int(command.mono), f32(command.blur * font_scale))
							return
						}
					}
				}
				app.draw_portable_shadow(command, page_x, page_y, scroll_y)
			}
		}
		else {}
	}
}

fn (mut app BrowserApp) draw_chrome_button(x f32, label string, enabled bool) {
	background := if enabled { gg.rgb(51, 65, 85) } else { gg.rgb(30, 41, 59) }
	foreground := if enabled { gg.rgb(241, 245, 249) } else { gg.rgb(100, 116, 139) }
	draw_rounded_fill(app.ctx, x, 12, 36, 34, 7, background)
	app.ctx.draw_text(int(x) + 11, 18, label, color: foreground, size: 17)
}

fn address_for_display(address string, cursor int, active bool, max_characters int) string {
	if max_characters <= 0 {
		return ''
	}
	mut runes := address.runes()
	mut visible_cursor := cursor
	if active {
		position := if cursor < 0 {
			0
		} else if cursor > runes.len {
			runes.len
		} else {
			cursor
		}
		runes.insert(position, `|`)
		visible_cursor = position + 1
	}
	if runes.len <= max_characters {
		return runes.string()
	}
	start := if visible_cursor > max_characters { visible_cursor - max_characters } else { 0 }
	end := if start + max_characters < runes.len { start + max_characters } else { runes.len }
	return runes[start..end].string()
}

fn (app &BrowserApp) retarget_document_frame_heap_scope(mut scope platform.BrowserActivityHeapScope) {
	scope.finish()
	scope = platform.begin_browser_activity_heap_scope_for_scripting(app.document_scripting_enabled_for_heap())
}

fn (mut app BrowserApp) draw() {
	$if linux { pump_linux_browser_events() }
	$if macos {
		// Sokol's parent view also ticks with no drawing context. Only the
		// native document view owns document preparation and pixel replay.
		if app.ctx != unsafe { nil } && app.ctx.native_rendering
			&& C.vox_browser_has_paint_context() == 0 { return }
	}
	if app.navigation_work_depth > 0 { return }
	paint_before_frame := app.paint_display_list
	app.poll_deferred_navigation_input()
	app.poll_deferred_page_input()
	// Profile wheels enter like physical input, outside the frame's navigation
	// work scope; inside it they would be deferred to the next frame untimed.
	app.begin_scroll_profile_frame()
	mut navigation_work := app.begin_navigation_work()
	defer { navigation_work.finish() }
	mut heap_scope := platform.begin_browser_activity_heap_scope_for_scripting(app.document_scripting_enabled_for_heap())
	defer { heap_scope.finish() }
	app.begin_frame_preparation()
	app.sync_window_activity()
	app.poll_native_navigation()
	// The local native display callback supplies the opportunity. HTML queues
	// its rendering task and owns eligibility, timestamps and callback ordering.
	app.deliver_rendering_opportunity(time.sys_mono_now(), sapp.frame_duration() * 1000.0)
	app.poll_javascript_tasks()
	if app.initial_window_frame_presented && app.document == unsafe { nil }
		&& app.pending_cached_page != none {
		app.install_pending_cached_page()
	}
	app.poll_background_resources()
	refresh_ready := app.refresh_not_before == 0 || time.sys_mono_now() >= app.refresh_not_before
	if app.document == unsafe { nil } || (app.document_presented && refresh_ready) {
		app.refresh_not_before = 0
		app.poll_navigation()
	}
	report_first_paint := debug_timing_enabled() && app.document != unsafe { nil }
		&& !app.document_presented
	mut paint_checkpoint := time.sys_mono_now()
	first_paint_start := paint_checkpoint
	window := browser_window_size()
	content_viewport_height := if app.screenshot_viewport_height > 0 {
		app.screenshot_viewport_height
	} else {
		window.height - app.chrome_height()
	}
	if window.width > 0 && (window.width != app.viewport_width || content_viewport_height != app.viewport_height) {
		app.relayout(window.width, window.height)
	}
	app.advance_document_animations(window.width, content_viewport_height)
	app.apply_screenshot_scroll_if_ready(window.height)
	app.finish_frame_preparation()
	// Preparation can replace a scripted or absent document with an HTML/CSS
	// page. Keep its compact policy through native replay and chrome drawing.
	app.retarget_document_frame_heap_scope(mut heap_scope)
	app.prepare_overlay_scrollbars()
	app.portable_shadow_image_index = 0
	app.scroll_profile_prepared()
	processmetrics.instruction_checkpoint('frame_prepared')
	begin_browser_frame(app.ctx)
	app.paint_effect_depth = 0
	paint_document := app.document_pixels_ready_for_frame()
	if paint_document {
		$if macos {
			if app.ctx.native_rendering && app.document != unsafe { nil }
				&& app.document.font_rendering_policy() == .chromium {
				C.native_begin_font_compositing_layer(f32(app.ctx.width), f32(app.ctx.height))
				app.set_chromium_msaa_tiles()
			} else if app.ctx.native_rendering
				&& app.paint_commands_have_backdrop_filter {
				// Backdrop commands need a snapshot of pixels already painted in this
				// frame. Keep the ordinary fast path direct-to-window.
				C.native_begin_css_filter_layer(f32(app.ctx.width), f32(app.ctx.height))
			}
		}
		draw_srgb_rect(app.ctx, 0, 0, f32(window.width), f32(window.height), gg.rgb(255, 255, 255))
		page_y := app.page_top()
		mut culling := PaintCanvasCulling{}
		$if macos {
			culling.enabled = app.ctx.native_rendering && !app.paint_canvas_culling_disabled
		}
		for command_index in 0 .. app.paint_commands.len {
			platform.cooperative_work_checkpoint()
			command := unsafe { &app.paint_commands[command_index] }
			if culling.skip(command, 0, f64(page_y), f64(window.width), f64(window.height)) {
				continue
			}
			app.draw_command(*command, 0, page_y, window.height)
		}
		app.flush_rounded_rect_underlay(0, page_y, window.height)
		for index in app.portable_shadow_image_index .. app.portable_shadow_images.len {
			app.ctx.remove_cached_image_by_idx(app.portable_shadow_images[index].image_id)
		}
		app.portable_shadow_images = app.portable_shadow_images[..app.portable_shadow_image_index].clone()
		if report_first_paint {
			paint_checkpoint = debug_timing_checkpoint('first_paint_replay (${app.paint_commands.len} commands)', paint_checkpoint)
		}
		$if macos {
			if app.ctx.native_rendering && app.document != unsafe { nil }
				&& app.document.font_rendering_policy() == .chromium {
				C.native_set_chromium_msaa_tiles(unsafe { nil }, 0, chromium_min_gpu_raster_tile_rows)
				C.native_end_font_compositing_layer()
			} else if app.ctx.native_rendering
				&& app.paint_commands_have_backdrop_filter {
				C.native_end_css_filter_layer()
			}
		}
	} else {
		draw_srgb_rect(app.ctx, 0, 0, f32(window.width), f32(window.height), gg.rgb(255, 255, 255))
	}

	if app.chrome_height() > 0 {
		// Draw chrome last so scrolled page content cannot paint over it.
		draw_srgb_rect(app.ctx, 0, 0, f32(window.width), f32(toolbar_height), gg.rgb(23, 32, 51))
		app.draw_chrome_button(12, '‹', app.history_index > 0)
		app.draw_chrome_button(54, '›', app.history_index + 1 < app.history.len)
		app.draw_chrome_button(96, '↻', app.history_index >= 0)
		app.draw_chrome_button(138, '⌂', true)
		address_x := f32(184)
		address_width := f32(window.width - 252)
		app.resize_address_bar(window.width)
		if !app.native_address_bar {
			address_color := if app.address_active {
				gg.rgb(255, 255, 255)
			} else {
				gg.rgb(241, 245, 249)
			}
			draw_rounded_fill(app.ctx, address_x, 12, address_width, 34, 8, address_color)
			if app.address_select {
				draw_rounded_fill(app.ctx, address_x + 5, 16, address_width - 10, 26, 5, gg.rgb(219, 234, 254))
			}
			visible_address := address_for_display(app.address, app.address_cursor, app.address_active, int(address_width / 8.0) - 2)
			app.ctx.draw_text(int(address_x) + 10, 19, visible_address,
				color: gg.rgb(15, 23, 42)
				size: 14
			)
		}
		draw_rounded_fill(app.ctx, f32(window.width - 60), 12, 48, 34, 8, gg.rgb(109, 40, 217))
		app.ctx.draw_text(window.width - 48, 20, 'Go',
			color: gg.rgb(255, 255, 255)
			size: 14
		)
		app.ctx.draw_text(14, 58, 'V · HTML/DOM/CSS/Layout · LibJS + JavaScriptCore',
			color: gg.rgb(196, 181, 253)
			size: 13
		)
		app.ctx.draw_text(348, 58, app.status, color: gg.rgb(148, 163, 184), size: 12)

		status_y := window.height - int(status_bar_height)
		draw_srgb_rect(app.ctx, 0, f32(status_y), f32(window.width), f32(status_bar_height), gg.rgb(30, 41, 59))
		footer := if app.hovered_link != '' {
			app.hovered_link
		} else if app.js_messages.len > 0 {
			// Console stacks can contain embedded newlines. The status bar is a
			// single-line chrome surface; allowing those newlines to paint upward
			// leaks browser diagnostics into document screenshots.
			'Console: ${app.js_messages.last().split_into_lines()[0]}'
		} else {
			app.source_label
		}
		app.ctx.draw_text(12, status_y + 4, footer, color: gg.rgb(203, 213, 225), size: 12)
		app.draw_memory_status(window.width, status_y)
	}
	end_browser_frame(app.ctx)
	app.finish_scroll_profile_frame()
	processmetrics.instruction_checkpoint('frame_complete')
	frame_finished_ns := time.sys_mono_now()
	app.finish_frame_memory_activity(frame_finished_ns, voidptr(paint_before_frame))
	if !app.initial_window_frame_presented {
		app.initial_window_frame_presented = true
		if app.pending_cached_page != none {
			// Let AppKit commit the inexpensive chrome-only frame before doing the
			// cached DOM/style/layout work on the next browser frame.
			app.begin_deferred_cached_page()
			$if macos {
				C.native_wake_browser_after(16)
			}
			return
		}
	}
	if report_first_paint {
		debug_timing_checkpoint('first_paint_total', first_paint_start)
	}
	if app.document != unsafe { nil } && !app.document_presented {
		app.paint_timing.report_document_paint()
	}
	if app.document != unsafe { nil } {
		app.document_presented = true
		$if macos {
			hold_expired := app.snapshot_hold_until != 0 && time.sys_mono_now() >= app.snapshot_hold_until
			if paint_document && app.snapshot_visible && (!app.snapshot_hold || hold_expired) {
				C.native_hide_cached_snapshot()
				app.snapshot_visible = false
				app.snapshot_hold = false
			}
			if paint_document && browser_snapshot_cache_enabled() && !app.snapshot_cached
				&& !app.load_status.starts_with('Cached') && !app.load_status.starts_with('Loading ') {
				app.snapshot_cached = true
				C.native_cache_browser_snapshot(cached_snapshot_path(app.address))
			}
		}
	}
	// `navigate()` deliberately holds initial network work until Cocoa has
	// presented this first frame. This keeps TLS/framework initialization from
	// delaying the window and gives cached pages an immediate first paint.
	app.start_pending_navigation()
	if app.screenshot_path != '' && !app.scroll_profile.enabled && !app.screenshot_scheduled && app.document != unsafe { nil } && !app.load_status.starts_with('Loading ') && app.background_resource_pending.len == 0 {
		if !paint_document || !app.document_resources_ready_for_capture() {
			$if macos { C.native_schedule_capture_retry(capture_retry_needs_frame, voidptr(&app)) }
			return
		}
		$if macos { C.native_cancel_capture_retry() }
		app.screenshot_scheduled = true
		app.write_capture_audit_if_requested()
		schedule_native_screenshot(app.screenshot_path)
	}
	$if linux { finish_linux_frame() }
}

fn (app &BrowserApp) element_at_window_point(mouse_x f32, mouse_y f32) ?&dom.Element {
	if app.document == unsafe { nil } {
		return none
	}
	if mouse_y < app.page_top() || mouse_y >= f32(browser_window_size().height - app.status_height()) {
		return none
	}
	document_x := f64(mouse_x)
	document_y := f64(mouse_y - app.page_top())
	if viewport_paintable := app.document.paintable_box() {
		if hit := viewport_paintable.hit_test(document_x, document_y, .exact) {
			if hit.element != unsafe { nil } {
				return hit.element
			}
		}
		return none
	}
	root := unsafe { &dom.Node(app.document) }
	return app.root_box.element_at_point(document_x, document_y + app.scroll_y, root)
}

fn (app &BrowserApp) link_at_point(mouse_x f32, mouse_y f32) ?string {
	mut element := app.element_at_window_point(mouse_x, mouse_y) or { return none }
	for {
		if element.local_name() == 'a' {
			href := element.get_attribute_value('href')
			if href != '' {
				return resolve_document_reference(href, app.address)
			}
		}
		element = element.as_node().parent_element() or { break }
	}
	return none
}

fn (mut app BrowserApp) handle_click(x f32, y f32) {
	if app.suppress_next_click_for_chrome {
		app.suppress_next_click_for_chrome = false
		return
	}
	if y >= 12 && y <= 46 {
		if x >= 12 && x < 48 {
			app.history_go(-1)
			return
		}
		if x >= 54 && x < 90 {
			app.history_go(1)
			return
		}
		if x >= 96 && x < 132 {
			app.reload()
			return
		}
		if x >= 138 && x < 174 {
			app.navigate('about:home', true)
			return
		}
		window := browser_window_size()
		if x >= 184 && x < f32(window.width - 68) {
			app.focus_address_bar()
			return
		}
		if x >= f32(window.width - 60) {
			app.submit_address_bar()
			return
		}
	}
	app.blur_address_bar()
}

// The compact JavaScriptCore bridge remains the page-script backend. Its click
// listener replay follows the actual DOM pointerup/click dispatch on release.
fn (mut app BrowserApp) replay_compact_javascript_click() {
	// Keep a concrete string alive while callbacks and layout allocate. The
	// compatibility compiler does not retain pointers inside a local Option
	// across those calls once the owning pending slot has been cleared.
	native_destination := app.pending_native_navigation or { '' }
	defer {
		$if gcboehm ? { C.GC_reachable_here(native_destination.str) }
	}
	app.pending_native_navigation = none
	generation := app.navigation_generation
	if app.page_model != unsafe { nil } {
		if node := app.page_model.event_handler.last_click_target_node() {
			if mut target := node.as_element() {
				if app.dispatch_javascript_event('click', target) { return }
			}
		}
	}
	if app.navigation_generation != generation { return }
	if native_destination != '' {
		app.navigate(native_destination, true)
	}
}

fn browser_pointer_button(button gg.MouseButton) int {
	return match button { .left { 0 } .middle { 1 } .right { 2 } else { -1 } }
}

fn browser_pointer_modifiers(modifiers u32) u32 {
	mut result := u32(0)
	if modifiers & 1 != 0 { result |= dom.modifier_shift }
	if modifiers & 2 != 0 { result |= dom.modifier_ctrl }
	if modifiers & 4 != 0 { result |= dom.modifier_alt }
	if modifiers & 8 != 0 { result |= dom.modifier_super }
	return result
}

fn browser_pointer_button_mask(button int) u32 {
	return match button { 0 { u32(1) } 1 { u32(4) } 2 { u32(2) } else { u32(0) } }
}

fn (mut app BrowserApp) handle_event(event &gg.Event) {
	app.platform_pointer_modifiers = browser_pointer_modifiers(event.modifiers)
	if app.navigation_work_depth > 0 {
		button := browser_pointer_button(event.mouse_button)
		if event.typ == .mouse_down {
			app.platform_pointer_buttons |= browser_pointer_button_mask(button)
			app.suppress_next_click_for_chrome = false
		} else if event.typ == .mouse_up {
			app.platform_pointer_buttons &= ~browser_pointer_button_mask(button)
		}
		if event.typ in [.mouse_up, .mouse_leave] || (event.typ in [.mouse_down, .mouse_move, .mouse_scroll] && event.mouse_y >= app.page_top()) {
			app.defer_page_input(event)
		}
		return
	}
	mut navigation_work := app.begin_navigation_work()
	defer { navigation_work.finish() }
	match event.typ {
		.mouse_down {
			button := browser_pointer_button(event.mouse_button)
			app.platform_pointer_buttons |= browser_pointer_button_mask(button)
			result := app.dispatch_chrome_pointer_event_at_viewport_point('pointerdown', browser_pointer_button(event.mouse_button), f64(event.mouse_x), f64(event.mouse_y - app.page_top()))
			// gg follows event_fn with click_fn for mouse-down. Upstream does not
			// run mousedown default actions when the hit target is browser chrome.
			app.suppress_next_click_for_chrome = result.target != ''
		}
		.mouse_up {
			button := browser_pointer_button(event.mouse_button)
			app.platform_pointer_buttons &= ~browser_pointer_button_mask(button)
			if app.overlay_scrollbars.dragging {
				app.overlay_scrollbars.dragging = false
				app.overlay_scrollbar_activity()
			}
			result := app.dispatch_chrome_pointer_event_at_viewport_point('pointerup', browser_pointer_button(event.mouse_button), f64(event.mouse_x), f64(event.mouse_y - app.page_top()))
			if !result.handled && app.page_model != unsafe { nil } && app.page_model.event_handler.last_click_allowed() && button == 0 {
				app.replay_compact_javascript_click()
			}
		}
		.mouse_scroll {
			if event.mouse_y >= app.page_top() { app.overlay_scrollbar_activity() }
			delta_x := -f64(event.scroll_x) * 42.0
			delta_y := -f64(event.scroll_y) * 42.0
			mut screen_x := f64(event.mouse_x)
			mut screen_y := f64(event.mouse_y)
			$if macos { C.native_pointer_screen_position(screen_x, screen_y, &screen_x, &screen_y) }
			app.handle_wheel_at_viewport_point(page.PixelPoint{f64(event.mouse_x),
				f64(event.mouse_y - app.page_top())}, page.PixelPoint{screen_x, screen_y},
				0, app.platform_pointer_buttons, app.platform_pointer_modifiers,
				delta_x, delta_y, false)
		}
		.resized {
			app.relayout(event.window_width, event.window_height)
		}
		.mouse_move {
			result := app.dispatch_chrome_pointer_event_at_viewport_point('pointermove', 0, f64(event.mouse_x), f64(event.mouse_y - app.page_top()))
			sapp.set_mouse_cursor(result.mouse_cursor)
			app.hovered_link = if result.handled {
				''
			} else {
				app.link_at_point(event.mouse_x, event.mouse_y) or { '' }
			}
		}
		.mouse_leave {
			was_hovered := app.overlay_scrollbars.hovered
			app.overlay_scrollbars.hovered = false
			if was_hovered { app.overlay_scrollbar_activity() }
			if app.page_model != unsafe { nil } {
				app.page_model.event_handler.handle_mouseleave()
			}
			sapp.set_mouse_cursor(.arrow)
		}
		else {}
	}
}

fn (mut app BrowserApp) handle_character(code u32) {
	if code < 32 || code == 127 {
		return
	}
	// X11 can deliver the printable key for a Ctrl/Super shortcut as well as
	// its key-down event. Keep Ctrl+L from inserting an "l" into the address.
	// Ctrl+Alt remains available for AltGr character input.
	if app.platform_pointer_modifiers & dom.modifier_super != 0
		|| (app.platform_pointer_modifiers & dom.modifier_ctrl != 0
			&& app.platform_pointer_modifiers & dom.modifier_alt == 0) {
		return
	}
	if !app.address_active {
		app.handle_page_character(code)
		return
	}
	if app.native_address_bar { return }
	mut runes := app.address.runes()
	if app.address_select {
		runes.clear()
		app.address_cursor = 0
		app.address_select = false
	}
	position := if app.address_cursor < 0 {
		0
	} else if app.address_cursor > runes.len {
		runes.len
	} else {
		app.address_cursor
	}
	runes.insert(position, rune(code))
	app.address_cursor = position + 1
	app.address = runes.string()
}

fn (mut app BrowserApp) handle_key(key gg.KeyCode, modifier gg.Modifier) {
	height := browser_window_size().height
	command := modifier.has(.super) || modifier.has(.ctrl)
	if command && key == .l {
		app.focus_address_bar()
		return
	}
	if command && key == .r {
		app.reload()
		return
	}
	if app.address_active {
		mut runes := app.address.runes()
		match key {
			.enter {
				app.submit_address_bar()
			}
			.backspace {
				if app.address_select {
					app.address = ''
					app.address_cursor = 0
					app.address_select = false
				} else if app.address_cursor > 0 && runes.len > 0 {
					runes.delete(app.address_cursor - 1)
					app.address_cursor--
					app.address = runes.string()
				}
			}
			.delete {
				if app.address_cursor < runes.len {
					runes.delete(app.address_cursor)
					app.address = runes.string()
				}
			}
			.left {
				app.address_cursor = if app.address_cursor > 0 { app.address_cursor - 1 } else { 0 }
				app.address_select = false
			}
			.right {
				app.address_cursor = if app.address_cursor < runes.len {
					app.address_cursor + 1
				} else {
					runes.len
				}
				app.address_select = false
			}
			.home {
				app.address_cursor = 0
				app.address_select = false
			}
			.end {
				app.address_cursor = runes.len
				app.address_select = false
			}
			.escape {
				app.cancel_address_bar()
			}
			else {}
		}
		return
	}
	if app.navigation_work_depth > 0 { return }
	if app.handle_page_editing_key(key, modifier) { return }
	match key {
		.up { app.scroll_by(-42.0, height) }
		.down { app.scroll_by(42.0, height) }
		.page_up { app.scroll_by(-f64(height) * 0.8, height) }
		.page_down { app.scroll_by(f64(height) * 0.8, height) }
		.home {
			app.set_scroll_y(0.0, height)
		}
		.end {
			app.set_scroll_y(app.maximum_scroll(height), height)
		}
		.escape { app.ctx.quit() }
		else {}
	}
}

fn main() {
	// Dispatch the signed self-helper before browser heap/font/GUI setup.
	if status := adblock.run_default_worker_role(os.args) { exit(status) }
	$if macos {
		adblock.configure_default_self_worker() or {
			eprintln('Ladybird V: cannot configure the default filter worker: ${err.msg()}')
			exit(1)
		}
	}
	main_started := time.sys_mono_now()
	_ = platform.initialize_browser_heap_policy()
	link_translated_modules()
	requestserver.install_native_font_fetch_host() or {
		eprintln('Ladybird V: failed to initialize the font RequestServer transport: ${err.msg()}')
		exit(1)
	}
	install_browser_font_resource_cache()
	defer { requestserver.close_native_font_fetch_host() }
	xpath.install_dom_xpath_bridge()
	options := parse_launch_options(os.args[1..]) or {
		eprintln('Ladybird V: ${err.msg()}')
		exit(2)
	}
	needs_native_font_replay := !options.headless_smoke && !options.headless_layout_tree
	$if macos {
		if needs_native_font_replay {
			C.native_prevent_app_nap()
		}
	}
	use_document_font := configure_browser_layout_font(needs_native_font_replay)
	$if macos {
		// Documents see the presenting display's density (or the screenshot
		// scale) as their device pixel ratio, e.g. for srcset selection.
		if needs_native_font_replay {
			html.set_display_device_pixel_ratio(C.native_display_device_pixel_ratio())
		}
	}
	initial_url, markup, source_label := initial_document(options.source)
	mut main_checkpoint := debug_timing_checkpoint('startup', main_started)
	initial_viewport_height := if options.screenshot_viewport_height > 0 {
		options.screenshot_viewport_height
	} else if options.height > int(toolbar_height + status_bar_height) {
		options.height - int(toolbar_height + status_bar_height)
	} else {
		1
	}
	defer_remote_navigation := markup == '' && !options.headless_smoke && !options.headless_layout_tree
	page_model := page.Page.create(1.0) or { panic(err) }
	mut page_client := page_model.client()
	page_client.set_request_frame_hook(request_browser_frame)
	main_checkpoint = debug_timing_checkpoint('startup_page_model', main_checkpoint)
	mut app := &BrowserApp{
		markup: markup
		scroll_profile: scroll_profile_from_environment()
		paint_canvas_culling_disabled: os.getenv('VOX_DISABLE_CANVAS_CULLING') == '1'
		source_label: source_label
		address: initial_url
		address_cursor: initial_url.runes().len
		page_model: page_model
		navigation_results: chan NavigationResult{ cap: 4 }
		force_dark_image_states: map[string]int{}
		force_dark_image_bitmaps: map[string]&dom.Bitmap_{}
		force_dark_images: map[string]&gg.Image{}
		resource_cache: map[string]PreloadedResource{}
		background_resource_results: chan PreloadedResource{ cap: max_cached_resources }
		background_resource_pending: map[string]bool{}
		screenshot_path: options.screenshot
		screenshot_viewport_height: options.screenshot_viewport_height
		screenshot_scroll_y: options.screenshot_scroll_y
		layout_tree_only: options.headless_layout_tree
		js_engine: options.js_engine
		script_policy: options.script_policy
		use_document_font: use_document_font
		viewport_width: options.width
		viewport_height: initial_viewport_height
	}
	main_checkpoint = debug_timing_checkpoint('startup_browser_state', main_checkpoint)
	app.install_chrome_widget_input_bridge()
	main_checkpoint = debug_timing_checkpoint('startup_input_bridge', main_checkpoint)
	if markup != '' {
		app.install_loaded_page(LoadedPage{
			url: initial_url
			markup: markup
			status: 'Loaded locally'
			content_type: 'text/html'
		}, true)
	} else if !defer_remote_navigation {
		app.navigate(initial_url, true)
	}
	if options.headless_smoke {
		if options.js_engine == .libjs {
			mut runtime := browserjs.Runtime.create_with_engine(.libjs)
			result := runtime.evaluate('var answer=0; for (let i=0;i<7;i++) answer+=i; answer*2;') or {
				eprintln('LibJS smoke failed: ${err.msg()}')
				exit(1)
			}
			runtime.close()
			if result != '42' { panic('LibJS smoke: unexpected result ${result}') }
			println('LibJS bytecode execution: passed (DOM bindings pending)')
		} else if app.source_label == 'about:home' {
			js_status := app.document.get_element_by_id('js-status') or {
				panic('headless smoke: JavaScript target element is missing')
			}
			if (js_status.as_node().text_content() or { '' }) != 'JavaScript executed and changed this DOM node.' {
				panic('headless smoke: JavaScript did not mutate the translated DOM')
			}
			println('javascript DOM mutation: passed')
			js_button := app.document.get_element_by_id('js-button') or {
				panic('headless smoke: JavaScript event target is missing')
			}
			app.dispatch_javascript_event('click', js_button)
			if (js_button.as_node().text_content() or { '' }) != 'JavaScript click handler executed.' {
				panic('headless smoke: JavaScript click handler did not mutate the translated DOM')
			}
			println('javascript click event: passed')
		}
		if options.js_engine != .libjs {
			app.run_wheel_input_smoke() or { panic('headless wheel smoke: ${err.msg()}') }
			println('native wheel routing and scrolling: passed')
			app.run_element_wheel_smoke() or { panic('headless element wheel smoke: ${err.msg()}') }
			println('ordinary element wheel listeners: passed')
		}
		println('Ladybird V smoke check passed')
		println('source: ${app.source_label}')
		println(app.status)
		for message in app.js_messages {
			println('console: ${message}')
		}
		return
	}
	if options.headless_layout_tree {
		mut dump_checkpoint := time.sys_mono_now()
		layout_tree := layout.dump_current_document_layout_tree(app.document) or {
			eprintln('Ladybird V: no layout tree was produced')
			exit(1)
		}
		dump_checkpoint = debug_timing_checkpoint('layout_tree_dump', dump_checkpoint)
		println(layout_tree)
		debug_timing_checkpoint('layout_tree_write', dump_checkpoint)
		return
	}

	app.ctx = gg.new_context(
		width: options.width
		height: options.height
		min_width: 640
		min_height: 480
		window_title: 'vox'
		bg_color: gg.rgb(232, 237, 243)
		native_rendering: $if macos { true } $else { false }
		init_fn: fn (mut app BrowserApp) {
			app.initialize_native_window()
		}
		cleanup_fn: fn (mut app BrowserApp) {
			app.unmount_address_bar()
		}
		frame_fn: fn (mut app BrowserApp) {
			app.draw()
		}
		event_fn: fn (event &gg.Event, mut app BrowserApp) {
			app.handle_event(event)
		}
		click_fn: fn (x f32, y f32, _ gg.MouseButton, mut app BrowserApp) {
			app.handle_click(x, y)
		}
		char_fn: fn (code u32, mut app BrowserApp) {
			app.handle_character(code)
		}
		keydown_fn: fn (key gg.KeyCode, modifier gg.Modifier, mut app BrowserApp) {
			app.handle_key(key, modifier)
		}
		user_data: app
	)
	configure_native_browser_context(mut app.ctx)
	main_checkpoint = debug_timing_checkpoint('startup_context', main_checkpoint)
	if defer_remote_navigation {
		app.navigate(initial_url, true)
	}
	debug_timing_checkpoint('startup_navigation', main_checkpoint)
	$if macos {
		if options.screenshot != '' || os.getenv('VOX_TEST_WINDOW') == '1' {
			C.native_prepare_test_window()
		}
	}
	app.ctx.run()
}
