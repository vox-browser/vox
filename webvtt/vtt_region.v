// Copyright (c) 2023, Tim Flynn <trflynn89@serenityos.org>
//
// SPDX-License-Identifier: BSD-2-Clause

// Translation of Libraries/LibWeb/WebVTT/VTTRegion.cpp — a WebVTT region record with
// range-validated setters. https://w3c.github.io/webvtt/#vttregion
module webvtt

// Bindings::ScrollSetting: "" (none) or "up".
pub enum ScrollSetting {
	empty
	up
}

// https://w3c.github.io/webvtt/#vttregion
@[heap]
pub struct VTTRegion {
mut:
	// https://w3c.github.io/webvtt/#webvtt-region-identifier
	identifier_ string
	// https://w3c.github.io/webvtt/#webvtt-region-width
	width_ f64 = 100.0
	// https://w3c.github.io/webvtt/#webvtt-region-lines
	lines_ u32 = 3
	// https://w3c.github.io/webvtt/#webvtt-region-anchor
	anchor_x_ f64 = 0.0
	anchor_y_ f64 = 100.0
	// https://w3c.github.io/webvtt/#webvtt-region-viewport-anchor
	viewport_anchor_x_ f64 = 0.0
	viewport_anchor_y_ f64 = 100.0
	// https://w3c.github.io/webvtt/#webvtt-region-scroll
	scroll_setting_ ScrollSetting = .empty
}

// https://w3c.github.io/webvtt/#dom-vttregion-vttregion
pub fn VTTRegion.construct_impl() &VTTRegion {
	// Steps 2-9 set the WebVTT region defaults; these match the struct field defaults.
	return &VTTRegion{}
}

// https://w3c.github.io/webvtt/#dom-vttregion-id
pub fn (region &VTTRegion) id() string {
	return region.identifier_
}

pub fn (mut region VTTRegion) set_id(id string) {
	region.identifier_ = id
}

// https://w3c.github.io/webvtt/#dom-vttregion-width
pub fn (region &VTTRegion) width() f64 {
	return region.width_
}

pub fn (mut region VTTRegion) set_width(width f64) ! {
	// On setting, if the new value is negative or greater than 100, throw an IndexSizeError.
	if width < 0 || width > 100 {
		return error('Value is negative or greater than 100')
	}
	region.width_ = width
}

// https://w3c.github.io/webvtt/#dom-vttregion-lines
pub fn (region &VTTRegion) lines() u32 {
	return region.lines_
}

pub fn (mut region VTTRegion) set_lines(lines u32) {
	region.lines_ = lines
}

// https://w3c.github.io/webvtt/#dom-vttregion-regionanchorx
pub fn (region &VTTRegion) region_anchor_x() f64 {
	return region.anchor_x_
}

pub fn (mut region VTTRegion) set_region_anchor_x(region_anchor_x f64) ! {
	if region_anchor_x < 0 || region_anchor_x > 100 {
		return error('Value is negative or greater than 100')
	}
	region.anchor_x_ = region_anchor_x
}

// https://w3c.github.io/webvtt/#dom-vttregion-regionanchory
pub fn (region &VTTRegion) region_anchor_y() f64 {
	return region.anchor_y_
}

pub fn (mut region VTTRegion) set_region_anchor_y(region_anchor_y f64) ! {
	if region_anchor_y < 0 || region_anchor_y > 100 {
		return error('Value is negative or greater than 100')
	}
	region.anchor_y_ = region_anchor_y
}

// https://w3c.github.io/webvtt/#dom-vttregion-viewportanchorx
pub fn (region &VTTRegion) viewport_anchor_x() f64 {
	return region.viewport_anchor_x_
}

pub fn (mut region VTTRegion) set_viewport_anchor_x(viewport_anchor_x f64) ! {
	if viewport_anchor_x < 0 || viewport_anchor_x > 100 {
		return error('Value is negative or greater than 100')
	}
	region.viewport_anchor_x_ = viewport_anchor_x
}

// https://w3c.github.io/webvtt/#dom-vttregion-viewportanchory
pub fn (region &VTTRegion) viewport_anchor_y() f64 {
	return region.viewport_anchor_y_
}

pub fn (mut region VTTRegion) set_viewport_anchor_y(viewport_anchor_y f64) ! {
	if viewport_anchor_y < 0 || viewport_anchor_y > 100 {
		return error('Value is negative or greater than 100')
	}
	region.viewport_anchor_y_ = viewport_anchor_y
}

// https://w3c.github.io/webvtt/#dom-vttregion-scroll
pub fn (region &VTTRegion) scroll() ScrollSetting {
	return region.scroll_setting_
}

pub fn (mut region VTTRegion) set_scroll(scroll ScrollSetting) {
	region.scroll_setting_ = scroll
}
