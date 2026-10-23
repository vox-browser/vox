module layout

import css
import dom
import painting

// Cold paint snapshots are immutable after publication. A copied box retains
// its previous header when live media or style state publishes a replacement.
pub struct BlockBoxMediaData {
pub:
	replaced_image_url         string
	replaced_image_size        string
	replaced_image_position_x  string
	replaced_image_position_y  string
	replaced_image_paintable   ?&painting.ImagePaintable = none
	replaced_image_bitmap      ?&dom.Bitmap_
	canvas_bitmap              ?&dom.Bitmap_
	canvas_paintable           ?&painting.CanvasPaintable = none
	video_bitmap               ?&dom.Bitmap_
	video_frame_source         ?&painting.VideoFrameSource
	video_representation       painting.VideoRepresentation
	video_paintable            ?&painting.VideoPaintable = none
	nested_viewport_document   ?&dom.Document
	nested_viewport_paintable  ?&painting.NavigableContainerViewportPaintable = none
	is_svg_image               bool
	form_control_kind          string
	form_control_checked       bool
	form_control_indeterminate bool
	form_control_enabled       bool = true
	form_control_activated     bool
	fieldset_paintable         ?&painting.FieldSetPaintable
}

__global empty_block_box_media = &BlockBoxMediaData{}

pub fn (box &BlockBox) media() &BlockBoxMediaData {
	if !isnil(box.media_data) { return box.media_data }
	return empty_block_box_media
}

pub struct BlockBoxDecorationData {
pub:
	border_radius         f64
	border_radii          BoxRadii
	outline_width         f64
	outline_offset        f64
	shadow                ?BoxShadow
	shadows               []BoxShadow
	background_gradient   ?&LinearGradient
	background_images     []BackgroundImageLayer
	background_color_clip string = 'border-box'
}

__global empty_block_box_decoration = &BlockBoxDecorationData{}

pub fn (box &BlockBox) decorations() &BlockBoxDecorationData {
	if !isnil(box.decoration_data) { return box.decoration_data }
	return empty_block_box_decoration
}

pub struct BlockBoxFilterData {
pub:
	filter          painting.ResolvedCSSFilter
	backdrop_filter painting.ResolvedCSSFilter
}

__global empty_block_box_filter = &BlockBoxFilterData{}

pub fn (box &BlockBox) filters() &BlockBoxFilterData {
	if !isnil(box.filter_data) { return box.filter_data }
	return empty_block_box_filter
}

pub struct BlockBoxScrollSnapData {
pub:
	scroll_snap_align css.ScrollSnapAlignData
	scroll_snap_stop  css.ScrollSnapStop
	scroll_snap_type  css.ScrollSnapType
	scroll_margin     BoxEdges
	scroll_padding    BoxEdges
}

__global empty_block_box_scroll_snap = &BlockBoxScrollSnapData{}

pub fn (box &BlockBox) scroll_snap() &BlockBoxScrollSnapData {
	if !isnil(box.scroll_snap_data) { return box.scroll_snap_data }
	return empty_block_box_scroll_snap
}

pub struct BlockBoxClipData {
pub:
	css_clip  ?&LayoutRect
	clip_path ?&painting.ClipPathVisualData
	svg_clip  ?&painting.SVGClipVisualData
	svg_mask  ?&painting.SVGMaskVisualData
}

__global empty_block_box_clip = &BlockBoxClipData{}

pub fn (box &BlockBox) clips() &BlockBoxClipData {
	if !isnil(box.clip_data) { return box.clip_data }
	return empty_block_box_clip
}

pub struct BlockBoxCanvasData {
pub:
	canvas_background_color  css.Color
	canvas_x                 f64
	canvas_y                 f64
	canvas_width             f64
	canvas_height            f64
	paints_canvas_background bool
	viewport_width           f64
	viewport_height          f64
}

__global empty_block_box_canvas = &BlockBoxCanvasData{}

pub fn (box &BlockBox) canvas() &BlockBoxCanvasData {
	if !isnil(box.canvas_data) { return box.canvas_data }
	return empty_block_box_canvas
}

// These headers belong to the active paint arena. They must not enter the
// document arena: independently retained paint trees publish their own storage.
__global ordinary_block_box_media = &BlockBoxMediaData{
	video_representation:      .transparent_black
	replaced_image_position_x: '50%'
	replaced_image_position_y: '50%'
}

pub fn retained_block_box_media(value BlockBoxMediaData) &BlockBoxMediaData {
	if value.replaced_image_url == '' && value.replaced_image_size == ''
		&& value.replaced_image_paintable == none && value.replaced_image_bitmap == none
		&& value.canvas_bitmap == none && value.canvas_paintable == none
		&& value.video_bitmap == none && value.video_frame_source == none
		&& value.video_paintable == none
		&& value.nested_viewport_document == none && value.nested_viewport_paintable == none
		&& !value.is_svg_image && value.form_control_kind == '' && !value.form_control_checked
		&& !value.form_control_indeterminate && value.form_control_enabled
		&& !value.form_control_activated && value.fieldset_paintable == none {
		if value.video_representation == .video_frame && value.replaced_image_position_x == '' && value.replaced_image_position_y == '' {
			return unsafe { nil }
		}
		if value.video_representation == .transparent_black && value.replaced_image_position_x == '50%' && value.replaced_image_position_y == '50%' {
			return ordinary_block_box_media
		}
	}
	return &BlockBoxMediaData{ ...value }
}

pub fn retained_block_box_decoration(value BlockBoxDecorationData) &BlockBoxDecorationData {
	if value.border_radius == 0 && box_radii_are_zero(value.border_radii)
		&& value.outline_width == 0 && value.outline_offset == 0 && value.shadow == none
		&& value.shadows.len == 0 && value.background_gradient == none
		&& value.background_images.len == 0 && value.background_color_clip == 'border-box' {
		return unsafe { nil }
	}
	return &BlockBoxDecorationData{ ...value }
}

pub fn retained_block_box_filter(value BlockBoxFilterData) &BlockBoxFilterData {
	if !value.filter.has_filters() && value.filter.svg_filter_bounds() == none
		&& !value.backdrop_filter.has_filters() && value.backdrop_filter.svg_filter_bounds() == none {
		return unsafe { nil }
	}
	return &BlockBoxFilterData{ ...value }
}

fn empty_paint_box_edges(edges BoxEdges) bool {
	return edges.top == 0 && edges.right == 0 && edges.bottom == 0 && edges.left == 0
}

pub fn retained_block_box_scroll_snap(value BlockBoxScrollSnapData) &BlockBoxScrollSnapData {
	if value.scroll_snap_align.block_alignment == .none_
		&& value.scroll_snap_align.inline_alignment == .none_ && value.scroll_snap_stop == .normal
		&& value.scroll_snap_type.axis == .both && value.scroll_snap_type.strictness == .none_
		&& empty_paint_box_edges(value.scroll_margin) && empty_paint_box_edges(value.scroll_padding) {
		return unsafe { nil }
	}
	return &BlockBoxScrollSnapData{ ...value }
}

pub fn retained_block_box_clip(value BlockBoxClipData) &BlockBoxClipData {
	if value.css_clip == none && value.clip_path == none && value.svg_clip == none && value.svg_mask == none {
		return unsafe { nil }
	}
	return &BlockBoxClipData{ ...value }
}

pub fn retained_block_box_canvas(value BlockBoxCanvasData) &BlockBoxCanvasData {
	if value.canvas_background_color.r == 0 && value.canvas_background_color.g == 0
		&& value.canvas_background_color.b == 0 && value.canvas_background_color.a == 255
		&& value.canvas_x == 0 && value.canvas_y == 0 && value.canvas_width == 0
		&& value.canvas_height == 0 && !value.paints_canvas_background
		&& value.viewport_width == 0 && value.viewport_height == 0 {
		return unsafe { nil }
	}
	return &BlockBoxCanvasData{ ...value }
}
