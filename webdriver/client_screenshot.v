// Copyright (c) 2026, Ladybird contributors
// SPDX-License-Identifier: BSD-2-Clause

// Translation of Client and Screenshot. Network I/O and framebuffer capture
// remain explicit host boundaries.
module webdriver

import encoding.base64
import x.json2

pub enum HttpMethod {
	get
	post
	delete
}

pub struct MatchedRoute {
pub:
	command    string
	parameters []string
}

struct Route {
	method  HttpMethod
	path    string
	command string
}

fn webdriver_routes() []Route {
	return [
		Route{.post, '/session', 'new_session'},
		Route{.delete, '/session/:session_id', 'delete_session'},
		Route{.get, '/status', 'get_status'},
		Route{.get, '/session/:session_id/timeouts', 'get_timeouts'},
		Route{.post, '/session/:session_id/timeouts', 'set_timeouts'},
		Route{.post, '/session/:session_id/url', 'navigate_to'},
		Route{.get, '/session/:session_id/url', 'get_current_url'},
		Route{.post, '/session/:session_id/back', 'back'},
		Route{.post, '/session/:session_id/forward', 'forward'},
		Route{.post, '/session/:session_id/refresh', 'refresh'},
		Route{.get, '/session/:session_id/title', 'get_title'},
		Route{.get, '/session/:session_id/window', 'get_window_handle'},
		Route{.delete, '/session/:session_id/window', 'close_window'},
		Route{.post, '/session/:session_id/window', 'switch_to_window'},
		Route{.get, '/session/:session_id/window/handles', 'get_window_handles'},
		Route{.post, '/session/:session_id/window/new', 'new_window'},
		Route{.post, '/session/:session_id/frame', 'switch_to_frame'},
		Route{.post, '/session/:session_id/frame/parent', 'switch_to_parent_frame'},
		Route{.get, '/session/:session_id/window/rect', 'get_window_rect'},
		Route{.post, '/session/:session_id/window/rect', 'set_window_rect'},
		Route{.post, '/session/:session_id/window/maximize', 'maximize_window'},
		Route{.post, '/session/:session_id/window/minimize', 'minimize_window'},
		Route{.post, '/session/:session_id/window/fullscreen', 'fullscreen_window'},
		Route{.post, '/session/:session_id/window/consume-user-activation', 'consume_user_activation'},
		Route{.post, '/session/:session_id/element', 'find_element'},
		Route{.post, '/session/:session_id/elements', 'find_elements'},
		Route{.post, '/session/:session_id/element/:element_id/element', 'find_element_from_element'},
		Route{.post, '/session/:session_id/element/:element_id/elements', 'find_elements_from_element'},
		Route{.post, '/session/:session_id/shadow/:shadow_id/element', 'find_element_from_shadow_root'},
		Route{.post, '/session/:session_id/shadow/:shadow_id/elements', 'find_elements_from_shadow_root'},
		Route{.get, '/session/:session_id/element/active', 'get_active_element'},
		Route{.get, '/session/:session_id/element/:element_id/shadow', 'get_element_shadow_root'},
		Route{.get, '/session/:session_id/element/:element_id/selected', 'is_element_selected'},
		Route{.get, '/session/:session_id/element/:element_id/attribute/:name', 'get_element_attribute'},
		Route{.get, '/session/:session_id/element/:element_id/property/:name', 'get_element_property'},
		Route{.get, '/session/:session_id/element/:element_id/css/:name', 'get_element_css_value'},
		Route{.get, '/session/:session_id/element/:element_id/text', 'get_element_text'},
		Route{.get, '/session/:session_id/element/:element_id/name', 'get_element_tag_name'},
		Route{.get, '/session/:session_id/element/:element_id/rect', 'get_element_rect'},
		Route{.get, '/session/:session_id/element/:element_id/enabled', 'is_element_enabled'},
		Route{.get, '/session/:session_id/element/:element_id/computedrole', 'get_computed_role'},
		Route{.get, '/session/:session_id/element/:element_id/computedlabel', 'get_computed_label'},
		Route{.post, '/session/:session_id/element/:element_id/click', 'element_click'},
		Route{.post, '/session/:session_id/element/:element_id/clear', 'element_clear'},
		Route{.post, '/session/:session_id/element/:element_id/value', 'element_send_keys'},
		Route{.get, '/session/:session_id/source', 'get_source'},
		Route{.post, '/session/:session_id/execute/sync', 'execute_script'},
		Route{.post, '/session/:session_id/execute/async', 'execute_async_script'},
		Route{.get, '/session/:session_id/cookie', 'get_all_cookies'},
		Route{.get, '/session/:session_id/cookie/:name', 'get_named_cookie'},
		Route{.post, '/session/:session_id/cookie', 'add_cookie'},
		Route{.delete, '/session/:session_id/cookie/:name', 'delete_cookie'},
		Route{.delete, '/session/:session_id/cookie', 'delete_all_cookies'},
		Route{.post, '/session/:session_id/actions', 'perform_actions'},
		Route{.delete, '/session/:session_id/actions', 'release_actions'},
		Route{.post, '/session/:session_id/alert/dismiss', 'dismiss_alert'},
		Route{.post, '/session/:session_id/alert/accept', 'accept_alert'},
		Route{.get, '/session/:session_id/alert/text', 'get_alert_text'},
		Route{.post, '/session/:session_id/alert/text', 'send_alert_text'},
		Route{.get, '/session/:session_id/screenshot', 'take_screenshot'},
		Route{.get, '/session/:session_id/element/:element_id/screenshot', 'take_element_screenshot'},
		Route{.post, '/session/:session_id/print', 'print_page'},
	]
}

pub fn match_route(method HttpMethod, request_path string) !MatchedRoute {
	request_parts := request_path.trim('/').split('/')
	for route in webdriver_routes() {
		if route.method != method { continue
		 }
		route_parts := route.path.trim('/').split('/')
		if route_parts.len != request_parts.len { continue
		 }
		mut parameters := []string{}
		mut matches := true
		for index, part in route_parts {
			if part.starts_with(':') {
				parameters << request_parts[index]
			} else if part != request_parts[index] {
				matches = false
				break
			}
		}
		if matches { return MatchedRoute{
				command:    route.command
				parameters: parameters
			} }
	}
	return error(WebDriverError.from_code(.unknown_command, 'The command was not recognized.').msg())
}

pub fn make_success_response(value json2.Any) map[string]json2.Any {
	return {
		'value': value
	}
}

pub struct FramebufferImage {
pub:
	width  u32
	height u32
	rgba   []u8
}

pub type PngEncoder = fn (FramebufferImage) ![]u8

pub fn draw_bounding_box_from_framebuffer(frame FramebufferImage, rect Rect) !FramebufferImage {
	left := int(rect.x)
	top := int(rect.y)
	rect_width := int(rect.width)
	rect_height := int(rect.height)
	if frame.width == 0 || frame.height == 0 {
		return error(WebDriverError.from_code(.unable_to_capture_screen, 'Viewport is empty').msg())
	}
	if frame.rgba.len != int(frame.width) * int(frame.height) * 4 {
		return error(WebDriverError.from_code(.unable_to_capture_screen,
			'Framebuffer pixel data has an invalid length').msg())
	}
	// WebDriver paints from the rectangle origin to the viewport edge; the
	// rectangle dimensions only determine which edge is the leading edge.
	leading_x := if left < left + rect_width { left } else { left + rect_width }
	leading_y := if top < top + rect_height { top } else { top + rect_height }
	width := int(frame.width) - leading_x
	height := int(frame.height) - leading_y
	if left < 0 || top < 0 || width <= 0 || height <= 0 || left + width > int(frame.width)
		|| top + height > int(frame.height) {
		return error(WebDriverError.from_code(.unable_to_capture_screen,
			'Bounding box lies outside the framebuffer').msg())
	}
	mut data := []u8{len: width * height * 4}
	for row in 0 .. height {
		source_start := (top + row) * int(frame.width) * 4 + left * 4
		destination_start := row * width * 4
		copy(mut data[destination_start..destination_start + width * 4], frame.rgba[source_start..
			source_start + width * 4])
	}
	return FramebufferImage{
		width:  u32(width)
		height: u32(height)
		rgba:   data
	}
}

pub fn encode_canvas_element(image FramebufferImage, encoder PngEncoder) Response {
	if image.width == 0 || image.height == 0 || image.rgba.len == 0 {
		return failure(.unable_to_capture_screen, 'Captured screenshot is empty')
	}
	png := encoder(image) or { return failure(.unable_to_capture_screen, err.msg()) }
	return success(base64.encode(png))
}
