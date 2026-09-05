// Copyright (c) 2026, Ladybird contributors
// SPDX-License-Identifier: BSD-2-Clause

// Translation of Internals.cpp/.h. PageClient operations become observable
// PlatformState changes and typed input actions at the embedder boundary.
module internals

import aria
import dom
import gamepad
import html

pub const mod_none = u16(0)
pub const mod_alt = u16(1)
pub const mod_ctrl = u16(2)
pub const mod_shift = u16(4)
pub const mod_super = u16(8)
pub const mod_keypad = u16(16)
pub const button_left = u16(0)
pub const button_middle = u16(1)
pub const button_right = u16(2)

pub struct ReferenceLink {
pub:
	relation string
	href     string
}

pub struct FuzzyMetadata {
pub:
	reference string
	content   string
}

pub struct DocumentMetadata {
pub:
	references []ReferenceLink
	fuzzy      []FuzzyMetadata
	variants   []string
}

pub struct HitTestObject {
pub:
	node          ?&dom.Node
	index_in_node int
}

@[heap]
pub struct Internals {
	InternalsBase
pub:
	navigator &gamepad.NavigatorGamepadPartial
pub mut:
	gamepads_        []&InternalGamepad
	next_gamepad_id_ int = 1
}

pub fn Internals.create(platform &PlatformState, navigator &gamepad.NavigatorGamepadPartial) &Internals {
	return &Internals{
		InternalsBase: InternalsBase.new(platform)
		navigator: navigator
	}
}

pub fn (mut api Internals) signal_test_is_done(text string) {
	api.perform_per_test_cleanup()
	api.platform.test_done_text = text
}

pub fn (mut api Internals) set_test_timeout(milliseconds f64) {
	api.platform.test_timeout_ms = milliseconds
}

fn json_escape(value string) string {
	return value.replace('\\', '\\\\').replace('"', '\\"').replace('\n', '\\n')
}

pub fn (mut api Internals) load_reference_test_metadata(metadata DocumentMetadata) {
	mut matches := []string{}
	mut mismatches := []string{}
	for reference in metadata.references {
		encoded := '"${json_escape(reference.href)}"'
		if reference.relation == 'match' { matches << encoded }
		if reference.relation == 'mismatch' { mismatches << encoded }
	}
	mut fuzzy := []string{}
	for value in metadata.fuzzy {
		prefix := if value.reference.len > 0 {
			'"reference":"${json_escape(value.reference)}",'
		} else {
			''
		}
		fuzzy << '{${prefix}"content":"${json_escape(value.content)}"}'
	}
	api.platform.ref_metadata_json = '{"match_references":[${matches.join(',')}],"mismatch_references":[${mismatches.join(',')}],"fuzzy":[${fuzzy.join(',')}]}'
}

pub fn (mut api Internals) load_test_variants(metadata DocumentMetadata) {
	values := metadata.variants.map('"${json_escape(it)}"')
	api.platform.test_variants_json = '[${values.join(',')}]'
}

pub fn (mut api Internals) set_time_zone(time_zone string) !string {
	if time_zone.len == 0 {
		return error('Could not set time zone: empty identifier')
	}
	previous := api.platform.time_zone
	api.platform.time_zone = time_zone
	return previous
}

pub fn (mut api Internals) gc() {
	api.platform.garbage_collections++
}

pub fn (api &Internals) hit_test(_ f64, _ f64) ?HitTestObject {
	result := api.platform.hit_test_result or { return none }
	return HitTestObject{
		node: result.node
		index_in_node: result.index_in_node
	}
}

struct WebDriverKeyData {
	key        string
	modifiers  u16
	code_point u32
}

fn webdriver_key_to_key_code(code_point u32) ?WebDriverKeyData {
	return match code_point {
		0xe003 { WebDriverKeyData{'Backspace', 0, 8} }
		0xe004 { WebDriverKeyData{'Tab', 0, 9} }
		0xe006 { WebDriverKeyData{'Return', 0, 10} }
		0xe007 { WebDriverKeyData{'Return', mod_keypad, 10} }
		0xe008 { WebDriverKeyData{'Shift', mod_shift, 0} }
		0xe009 { WebDriverKeyData{'Control', mod_ctrl, 0} }
		0xe00a { WebDriverKeyData{'Alt', mod_alt, 0} }
		0xe00d { WebDriverKeyData{'Space', 0, 32} }
		0xe010 { WebDriverKeyData{'End', 0, 0} }
		0xe011 { WebDriverKeyData{'Home', 0, 0} }
		0xe012 { WebDriverKeyData{'ArrowLeft', 0, 0} }
		0xe013 { WebDriverKeyData{'ArrowUp', 0, 0} }
		0xe014 { WebDriverKeyData{'ArrowRight', 0, 0} }
		0xe015 { WebDriverKeyData{'ArrowDown', 0, 0} }
		0xe017 { WebDriverKeyData{'Delete', 0, 0} }
		0xe03d { WebDriverKeyData{'Meta', mod_super, 0} }
		else { none }
	}
}

pub fn (mut api Internals) send_text(target &dom.Element, value string, modifiers u16) {
	html.HTMLOrSVGElement.create(target).focus()
	for character in value.runes() {
		code_point := u32(character)
		if data := webdriver_key_to_key_code(code_point) {
			api.platform.input_actions << InputAction{
				kind: .key_down
				key: data.key
				modifiers: modifiers | data.modifiers
				code_point: data.code_point
			}
		} else {
			api.platform.input_actions << InputAction{
				kind: .key_down
				key: character.str()
				modifiers: modifiers
				code_point: code_point
			}
		}
	}
}

pub fn (mut api Internals) send_key(target &dom.Element, key_name string, modifiers u16) {
	html.HTMLOrSVGElement.create(target).focus()
	api.platform.input_actions << InputAction{
		kind: .key_down
		key: key_name
		modifiers: modifiers
	}
}

pub fn (mut api Internals) paste(target &dom.Element, text string) {
	html.HTMLOrSVGElement.create(target).focus()
	api.platform.input_actions << InputAction{
		kind: .paste
		text: text
	}
}

pub fn (mut api Internals) commit_text() {
	api.platform.input_actions << InputAction{
		kind: .commit_text
		code_point: 13
	}
}

pub fn (mut api Internals) mouse_down(x f64, y f64, click_count u16, button u16, modifiers u16) {
	api.platform.input_actions << InputAction{
		kind: .mouse_down
		x: x
		y: y
		click_count: click_count
		button: api.button_from_unsigned_short(button)
		modifiers: modifiers
	}
}

pub fn (mut api Internals) mouse_up(x f64, y f64, button u16, modifiers u16) {
	api.platform.input_actions << InputAction{
		kind: .mouse_up
		x: x
		y: y
		button: api.button_from_unsigned_short(button)
		modifiers: modifiers
	}
}

pub fn (_ &Internals) button_from_unsigned_short(button u16) u16 {
	return match button {
		button_middle { button_middle }
		button_right { button_right }
		else { button_left }
	}
}

pub fn (mut api Internals) mouse_move(x f64, y f64, modifiers u16) {
	api.platform.input_actions << InputAction{
		kind: .mouse_move
		x: x
		y: y
		modifiers: modifiers
	}
}

pub fn (mut api Internals) click(x f64, y f64, click_count u16, button u16, modifiers u16) {
	api.mouse_down(x, y, click_count, button, modifiers)
	api.mouse_up(x, y, button, modifiers)
}

pub fn (mut api Internals) click_and_hold(x f64, y f64, click_count u16, button u16, modifiers u16) {
	api.mouse_down(x, y, click_count, button, modifiers)
}

pub fn (mut api Internals) wheel(x f64, y f64, delta_x f64, delta_y f64) {
	api.platform.input_actions << InputAction{
		kind: .wheel
		x: x
		y: y
		delta_x: delta_x
		delta_y: delta_y
	}
}

pub fn (mut api Internals) pinch(x f64, y f64, scale f64) {
	api.platform.input_actions << InputAction{
		kind: .pinch
		x: x
		y: y
		scale: scale
	}
}

pub fn (api &Internals) current_cursor() string {
	return api.platform.current_cursor_
}

pub fn (api &Internals) dispatch_user_activated_event(target &dom.EventTarget, event &dom.Event) !bool {
	mut mutable_event := unsafe { &dom.Event(event) }
	mutable_event.set_is_trusted(true)
	return target.dispatch_event(event)
}

fn parse_absolute_url(url string) ?dom.URL {
	colon := url.index_u8(`:`)
	if colon <= 0 || !url[0].is_letter() {
		return none
	}
	for byte in url[1..colon] {
		if !byte.is_alnum() && byte !in [`+`, `-`, `.`] {
			return none
		}
	}
	return dom.dom_url_parse(url, dom.url_about_blank(), 'UTF-8')
}

pub fn (mut api Internals) spoof_current_url(url string) ! {
	parsed := parse_absolute_url(url) or { return error('invalid absolute URL') }
	api.platform.current_url = parsed.serialize()
}

pub fn (api &Internals) create_internal_animation_timeline() &InternalAnimationTimeline {
	return InternalAnimationTimeline.create()
}

pub fn (mut api Internals) simulate_drag_start(x f64, y f64, mime_type string, contents string) {
	api.platform.input_actions << InputAction{
		kind: .drag_start
		x: x
		y: y
		mime_type: mime_type
		text: contents
	}
}

pub fn (mut api Internals) simulate_drag_move(x f64, y f64) {
	api.platform.input_actions << InputAction{
		kind: .drag_move
		x: x
		y: y
	}
}

pub fn (mut api Internals) simulate_drop(x f64, y f64) {
	api.platform.input_actions << InputAction{
		kind: .drop
		x: x
		y: y
	}
}

pub fn (mut api Internals) expire_cookies_with_time_offset(seconds i64) {
	api.platform.cookie_expiry_offset = seconds
}

pub fn (mut api Internals) set_http_memory_cache_enabled(enabled bool) bool {
	previous := api.platform.http_memory_cache_enabled
	api.platform.http_memory_cache_enabled = enabled
	return previous
}

fn internals_default_role(element &dom.Element) ?aria.Role {
	if !element.is_html_element() {
		return none
	}
	return match element.local_name() {
		'button', 'summary' {
			aria.Role.button
		}
		'a', 'area' {
			if element.has_attribute('href') {
				aria.Role.link
			} else {
				none
			}
		}
		'h1', 'h2', 'h3', 'h4', 'h5', 'h6' {
			aria.Role.heading
		}
		'th' {
			aria.Role.columnheader
		}
		'td' {
			aria.Role.cell
		}
		'tr' {
			aria.Role.row
		}
		'option' {
			aria.Role.option
		}
		else {
			none
		}
	}
}

fn internals_role_resolver(element &dom.Element) ?aria.Role {
	if value := element.get_attribute('role') {
		for token in value.fields() {
			role := aria.role_from_string(token) or { continue }
			if aria.is_abstract_role(role) {
				continue
			}
			return match role {
				.directory { aria.Role.list }
				.img { aria.Role.image }
				.presentation { aria.Role.none_ }
				else { role }
			}
		}
	}
	return internals_default_role(element)
}

pub fn (api &Internals) get_computed_role(element &dom.Element) string {
	mixin := aria.ARIAMixin.create(element, internals_default_role(element), internals_role_resolver)
	role := mixin.role_or_default() or { return '' }
	return aria.role_name(role)
}

pub fn (api &Internals) get_computed_label(element &dom.Element) string {
	html.install_document_accessibility_role_hook(element.document())
	return element.as_node().accessible_name(element.document(), .yes) or { '' }
}

pub fn (api &Internals) get_computed_aria_level(element &dom.Element) string {
	mixin := aria.ARIAMixin.create(element, internals_default_role(element), internals_role_resolver)
	data := aria.AriaData.from_mixin(mixin)
	level := data.aria_level_or_default() or { return '' }
	return level.str()
}

pub fn (api &Internals) get_echo_server_port() u16 {
	return api.platform.echo_server_port
}

pub fn (mut api Internals) set_echo_server_port(port u16) {
	api.platform.echo_server_port = port
}

pub fn (mut api Internals) set_browser_zoom(factor f64) {
	api.platform.browser_zoom = factor
}

pub fn (mut api Internals) set_device_pixel_ratio(ratio f64) {
	api.platform.device_pixel_ratio = ratio
}

pub fn (api &Internals) headless() bool {
	return api.platform.headless_
}

pub fn (api &Internals) dump_display_list() string {
	return api.platform.display_list_dump
}

pub fn (api &Internals) dump_layout_tree(node ?&dom.Node) string {
	return if node == none { '(no layout node)' } else { '(layout tree host boundary)' }
}

pub fn (api &Internals) dump_paintable_tree(node ?&dom.Node) string {
	return if node == none { '(no paintable)' } else { '(paintable tree host boundary)' }
}

pub fn (api &Internals) dump_stacking_context_tree() string {
	return api.platform.stacking_context_dump
}

pub fn (api &Internals) dump_gc_graph() string {
	return api.platform.gc_graph_dump
}

pub fn (api &Internals) get_shadow_root(element &dom.Element) ?&dom.ShadowRoot {
	return element.shadow_root()
}

pub fn (mut api Internals) handle_sdl_input_events() {
	api.platform.sdl_input_event_pumps++
}

pub fn (mut api Internals) connect_virtual_gamepad() &InternalGamepad {
	internal_pad := InternalGamepad.create(api.next_gamepad_id_, api.navigator, api)
	api.next_gamepad_id_++
	api.gamepads_ << internal_pad
	return internal_pad
}

pub fn (mut api Internals) disconnect_virtual_gamepad(gamepad_to_remove &InternalGamepad) {
	for index, candidate in api.gamepads_ {
		if candidate == gamepad_to_remove {
			api.gamepads_.delete(index)
			return
		}
	}
}

pub fn (mut api Internals) perform_per_test_cleanup() {
	for api.gamepads_.len > 0 {
		pad_pointer := api.gamepads_[0]
		mut internal_pad := unsafe { &InternalGamepad(pad_pointer) }
		internal_pad.disconnect()
	}
	api.gamepads_.clear()
}

pub fn (mut api Internals) set_highlighted_node(node ?&dom.Node) {
	api.platform.highlighted_node = node
}

pub fn (mut api Internals) clear_element(mut element dom.Element) {
	mut control := html.FormAssociatedElement.create(element)
	control.clear_algorithm()
}

pub fn (mut api Internals) set_environments_top_level_url(url string) ! {
	parsed := parse_absolute_url(url) or { return error('invalid absolute URL') }
	api.platform.top_level_url = parsed.serialize()
}
