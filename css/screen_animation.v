module css

import dom
import math
import time

pub struct CSSPixelPoint {
pub mut:
	x_ CSSPixels
	y_ CSSPixels
}

pub fn CSSPixelPoint.new(x CSSPixels, y CSSPixels) CSSPixelPoint {
	return CSSPixelPoint{
		x_: x
		y_: y
	}
}

pub fn CSSPixelPoint.from_values(x f64, y f64) CSSPixelPoint {
	return CSSPixelPoint.new(CSSPixels.nearest_value_for(x), CSSPixels.nearest_value_for(y))
}

pub fn (point CSSPixelPoint) x() CSSPixels {
	return point.x_
}

pub fn (point CSSPixelPoint) y() CSSPixels {
	return point.y_
}

pub fn (point CSSPixelPoint) plus(other CSSPixelPoint) CSSPixelPoint {
	return CSSPixelPoint.new(point.x_.plus(other.x_), point.y_.plus(other.y_))
}

pub fn (point CSSPixelPoint) minus(other CSSPixelPoint) CSSPixelPoint {
	return CSSPixelPoint.new(point.x_.minus(other.x_), point.y_.minus(other.y_))
}

pub fn (point CSSPixelPoint) times_float(value f64) CSSPixelPoint {
	return CSSPixelPoint.new(point.x_.times_float(value), point.y_.times_float(value))
}

pub fn (point CSSPixelPoint) divided_by_float(value f64) CSSPixelPoint {
	return CSSPixelPoint.new(point.x_.divided_by_float(value), point.y_.divided_by_float(value))
}

pub fn (point CSSPixelPoint) to_double_pair() [2]f64 {
	return [point.x_.to_double(), point.y_.to_double()]!
}

fn screen_animation_clamp_f64(value f64, min f64, max f64) f64 {
	if value < min {
		return min
	}
	if value > max {
		return max
	}
	return unsafe { value }
}

pub struct AffineTransform {
pub mut:
	// Gfx::AffineTransform float coefficients: a, b, c, d, e, f.
	scale_x     f32 = 1.0
	shear_y     f32
	shear_x     f32
	scale_y     f32 = 1.0
	translate_x f32
	translate_y f32
}

pub fn (mut transform AffineTransform) translate(x f32, y f32) {
	if transform.scale_x == 1 && transform.scale_y == 1
		&& transform.shear_x == 0 && transform.shear_y == 0 {
		transform.translate_x += x
		transform.translate_y += y
		return
	}
	transform.translate_x += x * transform.scale_x + y * transform.shear_x
	transform.translate_y += x * transform.shear_y + y * transform.scale_y
}

pub fn (mut transform AffineTransform) scale(scale_x f32, scale_y f32) {
	transform.scale_x *= scale_x
	transform.shear_y *= scale_x
	transform.shear_x *= scale_y
	transform.scale_y *= scale_y
}

pub fn (transform AffineTransform) map(position CSSPixelPoint) CSSPixelPoint {
	x := f32(position.x_.to_double())
	y := f32(position.y_.to_double())
	return CSSPixelPoint.from_values(f64(transform.scale_x * x + transform.shear_x * y + transform.translate_x),
		f64(transform.shear_y * x + transform.scale_y * y + transform.translate_y))
}

pub fn (transform AffineTransform) determinant() f32 {
	return transform.scale_x * transform.scale_y - transform.shear_y * transform.shear_x
}

pub fn (transform AffineTransform) inverse() ?AffineTransform {
	determinant := transform.determinant()
	if determinant == 0 { return none }
	return AffineTransform{
		scale_x: transform.scale_y / determinant
		shear_y: -transform.shear_y / determinant
		shear_x: -transform.shear_x / determinant
		scale_y: transform.scale_x / determinant
		translate_x: (transform.shear_x * transform.translate_y - transform.scale_y * transform.translate_x) / determinant
		translate_y: (transform.shear_y * transform.translate_x - transform.scale_x * transform.translate_y) / determinant
	}
}

pub fn (transform AffineTransform) map_int_point(x int, y int) [2]int {
	mapped_x := transform.scale_x * f32(x) + transform.shear_x * f32(y) + transform.translate_x
	mapped_y := transform.shear_y * f32(x) + transform.scale_y * f32(y) + transform.translate_y
	return [affine_round_to_int(mapped_x), affine_round_to_int(mapped_y)]!
}

pub fn (transform AffineTransform) inverse_map(position CSSPixelPoint) CSSPixelPoint {
	inverse := transform.inverse() or { AffineTransform{} }
	mapped := inverse.map_int_point(position.x().to_int(), position.y().to_int())
	return CSSPixelPoint.new(CSSPixels.new(mapped[0]), CSSPixels.new(mapped[1]))
}

// https://drafts.csswg.org/cssom-view/#the-screen-interface
@[heap]
pub struct Screen {
	dom.EventTarget
pub mut:
	web_exposed_screen_area           CSSPixelRect = CSSPixelRect.new(0, 0, 800, 600)
	web_exposed_available_screen_area CSSPixelRect = CSSPixelRect.new(0, 0, 800, 600)
	screen_count                      int = 1
	window_management_allowed         bool
	orientation_                      ?&ScreenOrientation
}

pub fn Screen.create() &Screen {
	return &Screen{}
}

pub fn (mut screen Screen) initialize() {
	// WEB_SET_PROTOTYPE_FOR_INTERFACE(Screen);
	screen.EventTarget.initialize()
}

pub fn (mut screen Screen) visit_edges(mut visitor dom.CellVisitor) {
	screen.EventTarget.visit_edges(mut visitor)
	// visitor.visit(m_window);
	if orientation := screen.orientation_ {
		visitor.visit(orientation)
	}
}

fn (screen &Screen) event_target() &dom.EventTarget {
	return unsafe { &dom.EventTarget(screen) }
}

// https://drafts.csswg.org/cssom-view-1/#dom-screen-width
pub fn (screen &Screen) width() int {
	// The width attribute must return the width of the Web-exposed screen area.
	return int(screen.web_exposed_screen_area.width.to_double())
}

// https://drafts.csswg.org/cssom-view-1/#dom-screen-height
pub fn (screen &Screen) height() int {
	// The height attribute must return the height of the Web-exposed screen area.
	return int(screen.web_exposed_screen_area.height.to_double())
}

// https://drafts.csswg.org/cssom-view-1/#dom-screen-availwidth
pub fn (screen &Screen) avail_width() int {
	// The availWidth attribute must return the width of the Web-exposed available screen area.
	return int(screen.web_exposed_available_screen_area.width.to_double())
}

// https://drafts.csswg.org/cssom-view-1/#dom-screen-availheight
pub fn (screen &Screen) avail_height() int {
	// The availHeight attribute must return the height of the Web-exposed available screen area.
	return int(screen.web_exposed_available_screen_area.height.to_double())
}

// https://drafts.csswg.org/cssom-view-1/#dom-screen-colordepth
pub fn (screen &Screen) color_depth() u32 {
	_ = screen
	// The colorDepth and pixelDepth attributes should return the number of bits allocated to colors for a pixel in
	// the output device, excluding the alpha channel.
	return 24
}

// https://drafts.csswg.org/cssom-view-1/#dom-screen-pixeldepth
pub fn (screen &Screen) pixel_depth() u32 {
	_ = screen
	// The colorDepth and pixelDepth attributes should return the number of bits allocated to colors for a pixel in
	// the output device, excluding the alpha channel.
	return 24
}

pub fn (mut screen Screen) orientation() &ScreenOrientation {
	if orientation := screen.orientation_ {
		return orientation
	}
	orientation := ScreenOrientation.create()
	screen.orientation_ = orientation
	return orientation
}

// https://w3c.github.io/window-management/#dom-screen-isextended
pub fn (screen &Screen) is_extended() bool {
	// 1. If this's relevant global object's associated Document is not allowed to use
	//    the policy-controlled feature named "window-management", return false.
	if !screen.window_management_allowed {
		return false
	}

	// 2. Return true if the device has more than one screen, and false otherwise.
	return screen.screen_count > 1
}

// https://w3c.github.io/window-management/#dom-screen-onchange
pub fn (screen &Screen) set_onchange(event_handler ?&dom.CallbackType) {
	screen.event_target().set_event_handler_attribute('change', event_handler)
}

// https://w3c.github.io/window-management/#dom-screen-onchange
pub fn (screen &Screen) onchange() ?&dom.CallbackType {
	return screen.event_target().event_handler_attribute('change')
}

pub enum OrientationLockType {
	any_
	natural
	landscape
	portrait
	portrait_primary
	portrait_secondary
	landscape_primary
	landscape_secondary
}

pub enum OrientationType {
	portrait_primary
	portrait_secondary
	landscape_primary
	landscape_secondary
}

@[heap]
pub struct ScreenOrientation {
	dom.EventTarget
}

pub fn ScreenOrientation.create() &ScreenOrientation {
	return &ScreenOrientation{}
}

pub fn (mut orientation ScreenOrientation) initialize() {
	// WEB_SET_PROTOTYPE_FOR_INTERFACE(ScreenOrientation);
	orientation.EventTarget.initialize()
}

fn (orientation &ScreenOrientation) event_target() &dom.EventTarget {
	return unsafe { &dom.EventTarget(orientation) }
}

// https://w3c.github.io/screen-orientation/#lock-method
pub fn (orientation &ScreenOrientation) lock(lock_type OrientationLockType) ! {
	_ = orientation
	_ = lock_type
	// Boundary: the C++ implementation currently returns NotSupportedError here.
	// A real lock needs WebIDL Promise plumbing plus browser/platform orientation support.
	return error('NotSupportedError: ScreenOrientation::lock() is not supported in this port')
}

// https://w3c.github.io/screen-orientation/#unlock-method
pub fn (orientation &ScreenOrientation) unlock() {
	_ = orientation
	// Boundary: C++ currently only logs from ScreenOrientation::unlock().
	// There is no platform orientation lock state to clear in this V port yet.
}

// https://w3c.github.io/screen-orientation/#type-attribute
pub fn (orientation &ScreenOrientation) type_() OrientationType {
	_ = orientation
	// Boundary: C++ currently only logs from ScreenOrientation::type()
	// and reports LandscapePrimary until browser/platform orientation state exists.
	return .landscape_primary
}

// https://w3c.github.io/screen-orientation/#angle-attribute
pub fn (orientation &ScreenOrientation) angle() u16 {
	_ = orientation
	// Boundary: C++ currently only logs from ScreenOrientation::angle()
	// and reports 0 until browser/platform orientation state exists.
	return 0
}

// https://w3c.github.io/screen-orientation/#onchange-event-handler-attribute
pub fn (orientation &ScreenOrientation) set_onchange(event_handler ?&dom.CallbackType) {
	orientation.event_target().set_event_handler_attribute('change', event_handler)
}

// https://w3c.github.io/screen-orientation/#onchange-event-handler-attribute
pub fn (orientation &ScreenOrientation) onchange() ?&dom.CallbackType {
	return orientation.event_target().event_handler_attribute('change')
}

// https://drafts.csswg.org/cssom-view/#visualviewport
@[heap]
pub struct VisualViewport {
	dom.EventTarget
pub mut:
	document_      ?&dom.Document
	offset_        CSSPixelPoint
	scale_         f64 = 1.0
	viewport_rect_ CSSPixelRect = CSSPixelRect.new(0, 0, 800, 600)
	needs_repaint  bool
	needs_contexts bool
}

pub fn VisualViewport.create(document &dom.Document) &VisualViewport {
	return &VisualViewport{
		document_: document
	}
}

pub fn (mut viewport VisualViewport) initialize() {
	// WEB_SET_PROTOTYPE_FOR_INTERFACE(VisualViewport);
	viewport.EventTarget.initialize()
}

pub fn (mut viewport VisualViewport) visit_edges(mut visitor dom.CellVisitor) {
	viewport.EventTarget.visit_edges(mut visitor)
	if document := viewport.document_ {
		visitor.visit(document)
	}
}

pub fn (viewport &VisualViewport) event_target() &dom.EventTarget {
	return unsafe { &dom.EventTarget(viewport) }
}

pub fn (viewport &VisualViewport) document() &dom.Document {
	return viewport.document_ or { panic('VERIFY(VisualViewport document)') }
}

pub fn (viewport &VisualViewport) relevant_global_impl() ?&dom.Window {
	return viewport.document().get_window()
}

pub fn (viewport &VisualViewport) visual_viewport_record() voidptr {
	return voidptr(viewport)
}

pub fn (viewport &VisualViewport) offset() CSSPixelPoint {
	return viewport.offset_
}

fn (viewport &VisualViewport) associated_document_is_fully_active() bool {
	if document := viewport.document_ {
		return document.is_fully_active()
	}
	return true
}

fn (viewport &VisualViewport) layout_viewport_rect() CSSPixelRect {
	if document := viewport.document_ {
		rect := document.viewport_rect()
		return CSSPixelRect.new(rect.x, rect.y, rect.width, rect.height)
	}
	return viewport.viewport_rect_
}

// DOM/Document.cpp resize snapshots cast its CSS viewport dimensions to int.
// This is the CSSPixels ABI boundary; the DOM facade cannot import CSS types.
pub fn (viewport &VisualViewport) layout_viewport_size_for_resize() [2]int {
	rect := viewport.layout_viewport_rect()
	return [rect.width.to_int(), rect.height.to_int()]!
}

// https://drafts.csswg.org/cssom-view/#dom-visualviewport-offsetleft
pub fn (viewport &VisualViewport) offset_left() f64 {
	// 1. If the visual viewport's associated document is not fully active, return 0.
	if !viewport.associated_document_is_fully_active() {
		return 0
	}

	// 2. Otherwise, return the offset of the left edge of the visual viewport from the left edge of the layout viewport.
	return viewport.offset_.x().to_double()
}

// https://drafts.csswg.org/cssom-view/#dom-visualviewport-offsettop
pub fn (viewport &VisualViewport) offset_top() f64 {
	// 1. If the visual viewport's associated document is not fully active, return 0.
	if !viewport.associated_document_is_fully_active() {
		return 0
	}

	// 2. Otherwise, return the offset of the top edge of the visual viewport from the top edge of the layout viewport.
	return viewport.offset_.y().to_double()
}

// https://drafts.csswg.org/cssom-view/#dom-visualviewport-pageleft
pub fn (viewport &VisualViewport) page_left() f64 {
	// 1. If the visual viewport's associated document is not fully active, return 0.
	if !viewport.associated_document_is_fully_active() {
		return 0
	}

	// 2. Otherwise, return the offset of the left edge of the visual viewport from the
	//    left edge of the initial containing block of the layout viewport's document.
	return viewport.layout_viewport_rect().x.to_double() + viewport.offset_left()
}

// https://drafts.csswg.org/cssom-view/#dom-visualviewport-pagetop
pub fn (viewport &VisualViewport) page_top() f64 {
	// 1. If the visual viewport's associated document is not fully active, return 0.
	if !viewport.associated_document_is_fully_active() {
		return 0
	}

	// 2. Otherwise, return the offset of the top edge of the visual viewport from the
	//    top edge of the initial containing block of the layout viewport's document.
	return viewport.layout_viewport_rect().y.to_double() + viewport.offset_top()
}

// https://drafts.csswg.org/cssom-view/#dom-visualviewport-width
pub fn (viewport &VisualViewport) width() f64 {
	// 1. If the visual viewport's associated document is not fully active, return 0.
	if !viewport.associated_document_is_fully_active() {
		return 0
	}

	// 2. Otherwise, return the width of the visual viewport
	//    FIXME: excluding the width of any rendered vertical classic scrollbar that is fixed to the visual viewport.
	return viewport.layout_viewport_rect().width.to_double() / viewport.scale_
}

// https://drafts.csswg.org/cssom-view/#dom-visualviewport-height
pub fn (viewport &VisualViewport) height() f64 {
	// 1. If the visual viewport's associated document is not fully active, return 0.
	if !viewport.associated_document_is_fully_active() {
		return 0
	}

	// 2. Otherwise, return the height of the visual viewport
	//    FIXME: excluding the height of any rendered vertical classic scrollbar that is fixed to the visual viewport.
	return viewport.layout_viewport_rect().height.to_double() / viewport.scale_
}

// https://drafts.csswg.org/cssom-view/#dom-visualviewport-scale
pub fn (viewport &VisualViewport) scale() f64 {
	return viewport.scale_
}

pub fn (viewport &VisualViewport) set_onresize(event_handler ?&dom.CallbackType) {
	viewport.event_target().set_event_handler_attribute('resize', event_handler)
}

pub fn (viewport &VisualViewport) onresize() ?&dom.CallbackType {
	return viewport.event_target().event_handler_attribute('resize')
}

pub fn (viewport &VisualViewport) set_onscroll(event_handler ?&dom.CallbackType) {
	viewport.event_target().set_event_handler_attribute('scroll', event_handler)
}

pub fn (viewport &VisualViewport) onscroll() ?&dom.CallbackType {
	return viewport.event_target().event_handler_attribute('scroll')
}

pub fn (viewport &VisualViewport) set_onscrollend(event_handler ?&dom.CallbackType) {
	viewport.event_target().set_event_handler_attribute('scrollend', event_handler)
}

pub fn (viewport &VisualViewport) onscrollend() ?&dom.CallbackType {
	return viewport.event_target().event_handler_attribute('scrollend')
}

pub fn (mut viewport VisualViewport) scroll_by(delta CSSPixelPoint) {
	if delta.x().to_double() == 0 && delta.y().to_double() == 0 { return }
	viewport.offset_ = viewport.offset_.plus(delta)
	viewport.did_scroll()
	viewport.needs_contexts = true
	viewport.needs_repaint = true
	if mut document := viewport.document_ { document.set_needs_repaint() }
}

fn (mut viewport VisualViewport) did_scroll() {
	if mut document := viewport.document_ {
		document.append_pending_scroll_event(dom.PendingScrollEvent{
			event_target: viewport.event_target()
			type_: 'scroll'
		})
	}
}

pub fn (viewport &VisualViewport) transform() AffineTransform {
	mut transform := AffineTransform{}
	// Source multiplies double coordinates before converting to the float
	// affine arguments. Do not round through another CSSPixelPoint first.
	transform.translate(f32(-viewport.offset_.x().to_double() * viewport.scale_),
		f32(-viewport.offset_.y().to_double() * viewport.scale_))
	transform.scale(f32(viewport.scale_), f32(viewport.scale_))
	return transform
}

pub fn (mut viewport VisualViewport) zoom(position CSSPixelPoint, scale_delta f64) {
	min_allowed_scale := 1.0
	max_allowed_scale := 5.0
	new_scale := screen_animation_clamp_f64(viewport.scale_ * (1.0 + scale_delta), min_allowed_scale, max_allowed_scale)
	applied_delta := new_scale / viewport.scale_

	// For pinch zoom we want focal_point to stay put on screen:
	// scale_new * (focal_point - offset_new) = scale_old * (focal_point - offset_old)
	mut new_offset_x := viewport.offset_.x().to_double() * viewport.scale_ * applied_delta
	mut new_offset_y := viewport.offset_.y().to_double() * viewport.scale_ * applied_delta
	new_offset_x += position.x().to_double() * (applied_delta - 1.0)
	new_offset_y += position.y().to_double() * (applied_delta - 1.0)

	viewport_rect := viewport.layout_viewport_rect()
	max_x_offset := math.max(0.0, viewport_rect.width.to_double() * (new_scale - 1.0))
	max_y_offset := math.max(0.0, viewport_rect.height.to_double() * (new_scale - 1.0))
	new_offset_x = screen_animation_clamp_f64(new_offset_x, 0.0, max_x_offset)
	new_offset_y = screen_animation_clamp_f64(new_offset_y, 0.0, max_y_offset)

	viewport.scale_ = new_scale
	old_offset := viewport.offset_
	viewport.offset_ = CSSPixelPoint.from_values(new_offset_x / viewport.scale_, new_offset_y / viewport.scale_)
	if old_offset != viewport.offset_ { viewport.did_scroll() }
	viewport.needs_contexts = true
	viewport.needs_repaint = true
}

pub fn (viewport &VisualViewport) map_to_layout_viewport(position CSSPixelPoint) CSSPixelPoint {
	return viewport.transform().inverse_map(position)
}

pub fn (mut viewport VisualViewport) reset() {
	viewport.scale_ = 1.0
	old_offset := viewport.offset_
	viewport.offset_ = CSSPixelPoint.from_values(0, 0)
	if old_offset != viewport.offset_ {
		viewport.did_scroll()
		if mut document := viewport.document_ {
			document.append_pending_scroll_event(dom.PendingScrollEvent{event_target: viewport.event_target(), type_: 'scrollend'})
		}
	}
	viewport.needs_contexts = true
	viewport.needs_repaint = true
}

pub enum AnimationClass {
	css_animation_with_owning_element
	css_transition
	css_animation_without_owning_element
	none_
}

pub enum WebAnimationPlayState {
	idle
	running
	paused
	finished
}

pub struct UnresolvedKeyframeEasing {
pub:
	value &dom.StyleValue
}

pub type ResolvedKeyframeEasing = EasingFunction | UnresolvedKeyframeEasing

pub fn (easing ResolvedKeyframeEasing) to_string() string {
	return match easing {
		EasingFunction { easing.to_string() }
		UnresolvedKeyframeEasing { easing.value.css_text }
	}
}

pub struct ResolvedKeyFrame {
pub mut:
	properties                    map[PropertyID]&dom.StyleValue
	custom_properties             map[string]&dom.StyleValue
	use_initial_properties        map[PropertyID]bool
	use_initial_custom_properties map[string]bool
	composite                     ?CompositeOperation
	easing                        ?ResolvedKeyframeEasing
}

@[heap]
pub struct KeyFrameSet {
pub mut:
	keyframes_by_key map[int]ResolvedKeyFrame
}

@[heap]
pub struct KeyframeEffect {
pub mut:
	target_                      ?dom.AbstractElement
	specified_start_delay        f64
	specified_iteration_duration f64
	iteration_count              f64 = 1.0
	timing_function_             EasingFunction = EasingFunction.linear()
	fill_mode                    AnimationFillMode
	playback_direction           AnimationDirection
	composite                    CompositeOperation
	key_frame_set                ?&KeyFrameSet
	normalized_specified_timing  bool
	// CSS-side sampling state. Upstream obtains these through AnimationEffect's
	// associated Animation and timeline; keeping them on the translated effect
	// preserves that behavior without making dom import css.
	output_progress            ?f64
	default_easing             EasingFunction = EasingFunction.ease()
	is_css_transition          bool
	previous_phase             WebAnimationEffectPhase = .idle
	current_phase              WebAnimationEffectPhase = .idle
	previous_current_iteration f64
	current_iteration          f64
}

pub enum WebAnimationEffectPhase {
	before
	active
	after
	idle
}

pub fn KeyframeEffect.create() &KeyframeEffect {
	return &KeyframeEffect{}
}

pub fn (mut effect KeyframeEffect) set_target(target dom.AbstractElement) {
	effect.target_ = target
}

pub fn (mut effect KeyframeEffect) set_specified_start_delay(delay f64) {
	effect.specified_start_delay = delay
}

pub fn (mut effect KeyframeEffect) set_specified_iteration_duration(duration f64) {
	effect.specified_iteration_duration = duration
}

pub fn (mut effect KeyframeEffect) set_iteration_count(iteration_count f64) {
	effect.iteration_count = iteration_count
}

pub fn (mut effect KeyframeEffect) normalize_specified_timing() {
	effect.normalized_specified_timing = true
}

pub fn (mut effect KeyframeEffect) set_timing_function(timing_function EasingFunction) {
	effect.timing_function_ = timing_function
}

pub fn (effect &KeyframeEffect) timing_function() EasingFunction {
	return effect.timing_function_
}

pub fn (mut effect KeyframeEffect) set_fill_mode(fill_mode AnimationFillMode) {
	effect.fill_mode = fill_mode
}

pub fn (mut effect KeyframeEffect) set_playback_direction(direction AnimationDirection) {
	effect.playback_direction = direction
}

pub fn (mut effect KeyframeEffect) set_composite(composite CompositeOperation) {
	effect.composite = composite
}

pub fn (mut effect KeyframeEffect) set_key_frame_set(key_frame_set ?&KeyFrameSet) {
	effect.key_frame_set = key_frame_set
}

pub fn (mut effect KeyframeEffect) set_output_progress(progress ?f64) {
	effect.output_progress = progress
}

pub fn (mut effect KeyframeEffect) set_default_easing(easing EasingFunction) {
	effect.default_easing = easing
}

pub fn (mut effect KeyframeEffect) mark_as_css_transition() {
	effect.is_css_transition = true
}

fn abstract_elements_equal(a dom.AbstractElement, b dom.AbstractElement) bool {
	// AbstractElement equality is element identity plus pseudo-element type.
	// Comparing V references directly invokes the generated structural Element
	// equality routine, recursively traversing the DOM graph; C++ compares the
	// GC pointers here.
	if voidptr(a.element_) != voidptr(b.element_) {
		return false
	}
	return a.pseudo_element_ == b.pseudo_element_
}

const animation_key_frame_key_scale_factor = 1000

@[heap]
pub struct CSSAnimation {
	dom.Animation
pub mut:
	animation_name_                string
	default_easing_                EasingFunction = EasingFunction.ease()
	ignored_css_properties         map[PropertyID]bool
	owning_element_                ?dom.AbstractElement
	global_animation_list_order_   int
	timeline_                      ?&AnimationTimeline
	effect_                        &KeyframeEffect = unsafe { nil }
	play_state_                    WebAnimationPlayState
	last_css_animation_play_state_ ?AnimationPlayState
	start_time_                    f64
	last_sample_time_              ?f64
	paused_progress_               ?f64
}

pub fn CSSAnimation.create() &CSSAnimation {
	mut animation := &CSSAnimation{}
	animation.Animation.concrete_handle_ = voidptr(animation)
	animation.Animation.concrete_kind_ = .css_animation
	return animation
}

// https://drafts.csswg.org/css-animations-2/#dom-cssanimation-animationname
pub fn (animation &CSSAnimation) animation_name() string {
	return animation.animation_name_
}

pub fn (mut animation CSSAnimation) set_animation_name(animation_name string) {
	animation.animation_name_ = animation_name
}

pub fn (animation &CSSAnimation) default_easing() EasingFunction {
	return animation.default_easing_
}

pub fn (animation &CSSAnimation) owning_element() ?dom.AbstractElement {
	return animation.owning_element_
}

pub fn (mut animation CSSAnimation) set_owning_element(owning_element ?dom.AbstractElement) {
	animation.owning_element_ = owning_element
}

pub fn (animation &CSSAnimation) global_animation_list_order() int {
	return animation.global_animation_list_order_
}

pub fn (animation &CSSAnimation) timeline() ?&AnimationTimeline {
	return animation.timeline_
}

pub fn (mut animation CSSAnimation) set_timeline(timeline ?&AnimationTimeline) {
	animation.timeline_ = timeline
}

pub fn (animation &CSSAnimation) effect() ?&KeyframeEffect {
	if animation.effect_ == unsafe { nil } {
		return none
	}
	return animation.effect_
}

pub fn (mut animation CSSAnimation) set_effect(effect &KeyframeEffect) {
	animation.effect_ = effect
}

pub fn (animation &CSSAnimation) play_state() WebAnimationPlayState {
	return animation.play_state_
}

pub fn (mut animation CSSAnimation) play() ! {
	if animation.play_state_ == .paused {
		if paused_at := animation.last_sample_time_ {
			// Move the animation's origin forward by the time spent paused. The
			// next sample supplies the new timeline time and completes this
			// adjustment in sample_at().
			animation.start_time_ = paused_at - animation.start_time_
		}
	}
	animation.play_state_ = .running
}

pub fn (mut animation CSSAnimation) pause() ! {
	animation.play_state_ = .paused
	if animation.effect_ != unsafe { nil } {
		animation.paused_progress_ = animation.effect_.output_progress
	}
}

pub fn (mut animation CSSAnimation) cancel() {
	animation.play_state_ = .idle
	if animation.effect_ != unsafe { nil } {
		animation.effect_.set_output_progress(none)
		animation.effect_.current_phase = .idle
	}
	animation.last_sample_time_ = none
	animation.paused_progress_ = none
}

pub fn (animation &CSSAnimation) last_css_animation_play_state() ?AnimationPlayState {
	return animation.last_css_animation_play_state_
}

pub fn (mut animation CSSAnimation) set_last_css_animation_play_state(state AnimationPlayState) {
	animation.last_css_animation_play_state_ = state
}

// https://www.w3.org/TR/css-animations-2/#animation-composite-order
pub fn (animation &CSSAnimation) class_specific_composite_order(other &CSSAnimation) int {
	animation_has_owner := animation.owning_element_ != none
	other_has_owner := other.owning_element_ != none
	if animation_has_owner != other_has_owner {
		panic('The existence of an owning element determines the animation class')
	}

	// Within the set of CSS Animations with an owning element, two animations A and B are sorted in composite order
	// (first to last) as follows:
	if animation_owner := animation.owning_element_ {
		other_owner := other.owning_element_ or { return 0 }

		// 1. If the owning element of A and B differs, sort A and B by tree order of their corresponding owning elements.
		//    With regard to pseudo-elements, the sort order is as follows:
		//    - element
		//    - ::marker
		//    - ::before
		//    - any other pseudo-elements not mentioned specifically in this list, sorted in ascending order by the Unicode
		//      codepoints that make up each selector
		//    - ::after
		//    - element children
		if !abstract_elements_equal(animation_owner, other_owner) {
			// FIXME: Sort by tree order
			return 0
		}

		// 2. Otherwise, sort A and B based on their position in the computed value of the animation-name property of the
		//    (common) owning element.
		// FIXME: Do this when animation-name supports multiple values
		return 0
	}

	// The composite order of CSS Animations without an owning element is based on their position in the global animation list.
	return animation.global_animation_list_order() - other.global_animation_list_order()
}

pub fn (animation &CSSAnimation) animation_class() AnimationClass {
	if animation.owning_element_ != none {
		return .css_animation_with_owning_element
	}
	return .css_animation_without_owning_element
}

// NB: Unrelated style changes shouldn't cause us to recreate anonymous timelines, to achieve this we drop updates
//     between two equivalent anonymous timelines.
fn should_update_timeline(old_timeline ?&AnimationTimeline, new_timeline ?&AnimationTimeline) bool {
	if old_timeline == none || new_timeline == none {
		return true
	}

	old := old_timeline or { return true }
	new := new_timeline or { return true }
	if old.kind == .scroll && new.kind == .scroll {
		old_source := old.anonymous_source or { return true }
		new_source := new.anonymous_source or { return true }
		return old_source != new_source || old.scroll_scroller != new.scroll_scroller
			|| old.scroll_axis != new.scroll_axis
	}

	return true
}

pub fn (mut animation CSSAnimation) apply_css_properties(animation_properties ComputedAnimationProperties) {
	// FIXME: Don't apply overriden properties as defined here: https://drafts.csswg.org/css-animations-2/#animations

	if animation.effect_ == unsafe { nil } {
		animation.effect_ = KeyframeEffect.create()
	}
	mut effect := animation.effect_

	if !animation.ignored_css_properties[PropertyID.animation_timeline]
		&& should_update_timeline(animation.timeline_, animation_properties.timeline) {
		animation.set_timeline(animation_properties.timeline)
	}

	effect.set_specified_iteration_duration(animation_properties.duration)
	effect.set_specified_start_delay(animation_properties.delay)
	effect.set_iteration_count(animation_properties.iteration_count)
	// https://drafts.csswg.org/web-animations-2/#updating-animationeffect-timing
	// Timing properties may also be updated due to a style change. Any change to a CSS animation property that affects
	// timing requires rerunning the procedure to normalize specified timing.
	effect.normalize_specified_timing()
	// NB: animation-timing-function is applied per-keyframe, not as the effect-level timing function.
	//     The effect-level timing function remains linear.
	animation.default_easing_ = animation_properties.timing_function
	effect.set_default_easing(animation_properties.timing_function)
	effect.set_fill_mode(animation_properties.fill_mode)
	effect.set_playback_direction(animation_properties.direction)
	effect.set_composite(match animation_properties.composition {
		.replace { CompositeOperation.replace }
		.add { CompositeOperation.add }
		.accumulate { CompositeOperation.accumulate }
	})

	if last_play_state := animation.last_css_animation_play_state() {
		if animation_properties.play_state == last_play_state {
			return
		}
	}

	if animation_properties.play_state == .running && animation.play_state() != .running {
		animation.play() or {}
	} else if animation_properties.play_state == .paused && animation.play_state() != .paused {
		animation.pause() or {}
	}

	animation.set_last_css_animation_play_state(animation_properties.play_state)
}

// Return the directed iteration progress at `timeline_time`, including delay,
// fill-mode, iteration-count, direction, and play-state handling.
pub fn (mut animation CSSAnimation) sample_at(timeline_time f64) ?f64 {
	if animation.effect_ == unsafe { nil } {
		return none
	}
	mut effect := animation.effect_
	if animation.play_state_ == .idle || animation.timeline_ == none {
		effect.set_output_progress(none)
		effect.current_phase = .idle
		return none
	}
	if animation.play_state_ == .paused {
		if progress := animation.paused_progress_ {
			effect.set_output_progress(progress)
			return progress
		}
	}
	// Scroll progress has its own clock. In particular, a scroll timeline
	// without a resolved source is inactive, rather than a zero-duration
	// document animation that can publish its forwards-filled end values.
	mut sample_time := timeline_time
	if timeline := animation.timeline_ {
		if timeline.kind == .scroll {
			sample_time = timeline.current_time_ms() or {
				effect.set_output_progress(none)
				effect.current_phase = .idle
				return none
			}
		}
	}
	if animation.play_state_ == .running && animation.paused_progress_ != none {
		// play() temporarily stores the old origin as (pause time - origin).
		animation.start_time_ = sample_time - animation.start_time_
		animation.paused_progress_ = none
	}
	animation.last_sample_time_ = sample_time
	duration := effect.specified_iteration_duration
	active_time := sample_time - animation.start_time_ - effect.specified_start_delay
	active_duration := if math.is_inf(effect.iteration_count, 0) {
		math.inf(1)
	} else {
		math.max(0.0, duration) * math.max(0.0, effect.iteration_count)
	}
	effect.current_phase = if active_time < 0 {
		.before
	} else if active_time >= active_duration && !math.is_inf(active_duration, 0) {
		.after
	} else {
		.active
	}

	mut simple_progress := 0.0
	mut iteration_index := i64(0)
	if active_time < 0 {
		if effect.fill_mode !in [.backwards, .both] {
			effect.set_output_progress(none)
			return none
		}
	} else if active_time >= active_duration && !math.is_inf(active_duration, 0) {
		if effect.fill_mode !in [.forwards, .both] {
			effect.set_output_progress(none)
			return none
		}
		if effect.iteration_count > 0 {
			completed_iterations := math.floor(effect.iteration_count)
			fractional_iteration := effect.iteration_count - completed_iterations
			if fractional_iteration > 0 {
				simple_progress = fractional_iteration
				iteration_index = i64(completed_iterations)
			} else {
				simple_progress = 1.0
				iteration_index = i64(math.max(0.0, completed_iterations - 1.0))
			}
		}
	} else if duration <= 0 {
		simple_progress = 1.0
	} else {
		iteration_position := active_time / duration
		iteration_index = i64(math.floor(iteration_position))
		simple_progress = iteration_position - math.floor(iteration_position)
		if simple_progress == 0 && active_time > 0 {
			simple_progress = 1.0
			iteration_index--
		}
	}
	is_reverse_iteration := match effect.playback_direction {
		.reverse { true }
		.alternate { iteration_index % 2 != 0 }
		.alternate_reverse { iteration_index % 2 == 0 }
		.normal { false }
	}
	if is_reverse_iteration {
		simple_progress = 1.0 - simple_progress
	}

	effect.set_output_progress(simple_progress)
	effect.current_iteration = f64(iteration_index)
	if animation.play_state_ == .paused {
		animation.paused_progress_ = simple_progress
	}
	return simple_progress
}

pub struct CSSAnimationStorageEntry {
pub mut:
	abstract_element dom.AbstractElement
	name             string
	animation        &CSSAnimation = unsafe { nil }
}

@[heap]
pub struct CSSAnimationStorage {
pub mut:
	entries []CSSAnimationStorageEntry
}

pub fn (storage &CSSAnimationStorage) animation(abstract_element dom.AbstractElement, name string) ?&CSSAnimation {
	for entry in storage.entries {
		if entry.name == name && abstract_elements_equal(entry.abstract_element, abstract_element) {
			return entry.animation
		}
	}
	return none
}

pub fn (storage &CSSAnimationStorage) animations_for(abstract_element dom.AbstractElement) []&CSSAnimation {
	mut result := []&CSSAnimation{}
	for entry in storage.entries {
		if abstract_elements_equal(entry.abstract_element, abstract_element) {
			result << entry.animation
		}
	}
	return result
}

pub fn (mut storage CSSAnimationStorage) set(abstract_element dom.AbstractElement, name string, animation &CSSAnimation) {
	for mut entry in storage.entries {
		if entry.name == name && abstract_elements_equal(entry.abstract_element, abstract_element) {
			entry.animation = animation
			return
		}
	}
	storage.entries << CSSAnimationStorageEntry{
		abstract_element: abstract_element
		name: name
		animation: animation
	}
	mut mutable_abstract_element := abstract_element
	mutable_abstract_element.set_css_defined_animation(name, &dom.CSSAnimation_{
		target: voidptr(animation)
		cancel_callback: dom_css_animation_cancel
		play_callback: dom_css_animation_play
		pause_callback: dom_css_animation_pause
		last_play_state_callback: dom_css_animation_last_play_state
	})
}

pub fn (mut storage CSSAnimationStorage) remove_animations_not_named(abstract_element dom.AbstractElement, defined_names map[string]bool) {
	// Most style recomputations leave the target's animation names unchanged.
	// Keep the global storage in place unless this target actually lost a name.
	mut needs_removal := false
	for entry in storage.entries {
		if abstract_elements_equal(entry.abstract_element, abstract_element)
			&& entry.name !in defined_names {
			needs_removal = true
			break
		}
	}
	if !needs_removal {
		return
	}
	mut kept := []CSSAnimationStorageEntry{}
	for entry in storage.entries {
		if !abstract_elements_equal(entry.abstract_element, abstract_element)
			|| entry.name in defined_names {
			kept << entry
		} else {
			mut animation := entry.animation
			animation.cancel()
			mut mutable_abstract_element := abstract_element
			mutable_abstract_element.remove_css_defined_animation(entry.name)
		}
	}
	storage.entries = kept
}

fn dom_css_animation_cancel(target voidptr) {
	mut animation := unsafe { &CSSAnimation(target) }
	animation.cancel()
}

fn dom_css_animation_play(target voidptr) {
	mut animation := unsafe { &CSSAnimation(target) }
	animation.play() or {}
}

fn dom_css_animation_pause(target voidptr) {
	mut animation := unsafe { &CSSAnimation(target) }
	animation.pause() or {}
}

fn dom_css_animation_last_play_state(target voidptr) ?dom.CSSAnimationPlayState_ {
	animation := unsafe { &CSSAnimation(target) }
	state := animation.last_css_animation_play_state() or { return none }
	return match state {
		.running { dom.CSSAnimationPlayState_.running }
		.paused { dom.CSSAnimationPlayState_.paused }
	}
}

pub fn (mut animation CSSAnimation) set_timeline_for_bindings(timeline ?&AnimationTimeline) {
	// AD-HOC: When the timeline of a CSS animation is modified by the author from JS we should no longer apply changes
	//         to the `animation-timeline` property. See https://github.com/w3c/csswg-drafts/issues/13472
	animation.ignored_css_properties[PropertyID.animation_timeline] = true
	animation.set_timeline(timeline)
}

pub fn (animation &CSSAnimation) is_css_animation() bool {
	_ = animation
	return true
}

@[heap]
pub struct CSSTransition {
	dom.Animation
pub mut:
	owning_element_              ?dom.AbstractElement
	global_animation_list_order_ int
	transition_property_         PropertyID
	// https://drafts.csswg.org/css-transitions-2/#transition-generation
	transition_generation_ int
	// https://drafts.csswg.org/css-transitions/#transition-start-time
	start_time_ f64
	// https://drafts.csswg.org/css-transitions/#transition-end-time
	end_time_ f64
	// https://drafts.csswg.org/css-transitions/#transition-start-value
	start_value_ &dom.StyleValue = unsafe { nil }
	// https://drafts.csswg.org/css-transitions/#transition-end-value
	end_value_ &dom.StyleValue = unsafe { nil }
	// https://drafts.csswg.org/css-transitions/#transition-reversing-adjusted-start-value
	reversing_adjusted_start_value_ &dom.StyleValue = unsafe { nil }
	// https://drafts.csswg.org/css-transitions/#transition-reversing-shortening-factor
	reversing_shortening_factor_ f64
	keyframe_effect_             &KeyframeEffect = unsafe { nil }
	cached_declaration           ?&CSSStyleProperties
	previous_phase_              CSSTransitionPhase = .idle
	current_phase_               CSSTransitionPhase = .idle
	timeline_                    ?&AnimationTimeline
	play_state_                  WebAnimationPlayState
	is_provisional_              bool
}

// This is designed to be created from AnimationEffect::Phase.
pub enum CSSTransitionPhase {
	before
	active
	after
	idle
	pending
}

pub enum CSSTransitionPublication {
	committed
	provisional
}

pub struct CSSTransitionStorageEntry {
pub mut:
	abstract_element dom.AbstractElement
	property_id      PropertyID
	attributes       ?TransitionTimingAttributes
	transition       &CSSTransition = unsafe { nil }
}

pub struct CSSTransitionStorage {
pub mut:
	registered_transition_attributes map[i64]&CSSRegisteredTransitionStorageBucket
	associated_transitions           map[i64]&CSSTransitionStorageBucket
	transition_generation            int
}

@[heap]
pub struct CSSTransitionStorageBucket {
pub mut:
	entries []CSSTransitionStorageEntry
	indexes map[PropertyID]int
}

// One transition declaration supplies the same timing to every physical
// longhand it expands to. Keep that timing once, rather than copying it into
// hundreds of entries for transition-property: all on every style update.
@[heap]
pub struct CSSRegisteredTransitionStorageBucket {
pub mut:
	property_ids []PropertyID
	attributes   []TransitionTimingAttributes
	indexes      map[PropertyID]int
}

pub struct TransitionTimingAttributes {
pub mut:
	delay               f64
	duration            f64
	timing_function     EasingFunction = EasingFunction.linear()
	transition_behavior TransitionBehavior
}

fn style_values_equal(a &dom.StyleValue, b &dom.StyleValue) bool {
	if typed_a := typed_style_value_logic_from_dom(a) {
		if typed_b := typed_style_value_logic_from_dom(b) {
			return typed_a.equals(typed_b)
		}
	}
	return a.css_text == b.css_text
}

fn transition_attributes_from_transition_properties(properties TransitionProperties) TransitionTimingAttributes {
	return TransitionTimingAttributes{
		delay: properties.delay
		duration: properties.duration
		timing_function: properties.timing_function
		transition_behavior: properties.transition_behavior
	}
}

fn abstract_element_storage_key(abstract_element dom.AbstractElement) i64 {
	pseudo_key := if pseudo := abstract_element.pseudo_element_ {
		i64(int(pseudo) + 1)
	} else {
		i64(0)
	}
	return abstract_element.element_.as_node().unique_id().value() * 16 + pseudo_key
}

fn (mut storage CSSTransitionStorage) ensure_registered_transition_bucket(abstract_element dom.AbstractElement) &CSSRegisteredTransitionStorageBucket {
	key := abstract_element_storage_key(abstract_element)
	if bucket := storage.registered_transition_attributes[key] {
		return bucket
	}
	bucket := &CSSRegisteredTransitionStorageBucket{}
	storage.registered_transition_attributes[key] = bucket
	return bucket
}

fn (mut storage CSSTransitionStorage) ensure_associated_transition_bucket(abstract_element dom.AbstractElement) &CSSTransitionStorageBucket {
	key := abstract_element_storage_key(abstract_element)
	if bucket := storage.associated_transitions[key] {
		return bucket
	}
	bucket := &CSSTransitionStorageBucket{}
	storage.associated_transitions[key] = bucket
	return bucket
}

pub fn (mut storage CSSTransitionStorage) clear_registered_transitions(abstract_element dom.AbstractElement) {
	storage.registered_transition_attributes.delete(abstract_element_storage_key(abstract_element))
}

pub fn (mut storage CSSTransitionStorage) add_transitioned_properties(abstract_element dom.AbstractElement, transitions []TransitionProperties) {
	mut bucket := storage.ensure_registered_transition_bucket(abstract_element)
	for transition_properties in transitions {
		if transition_properties.properties.len == 0 { continue }
		attributes_index := bucket.attributes.len
		bucket.attributes << transition_attributes_from_transition_properties(transition_properties)
		for property_id in transition_properties.properties {
			if property_id !in bucket.indexes {
				bucket.property_ids << property_id
			}
			bucket.indexes[property_id] = attributes_index
		}
	}
}

pub fn (storage &CSSTransitionStorage) property_ids_with_matching_transition_property_entry(abstract_element dom.AbstractElement) []PropertyID {
	bucket := storage.registered_transition_attributes[abstract_element_storage_key(abstract_element)] or {
		return []PropertyID{}
	}
	return bucket.property_ids.clone()
}

pub fn (storage &CSSTransitionStorage) property_transition_attributes(abstract_element dom.AbstractElement, property_id PropertyID) ?TransitionTimingAttributes {
	bucket := storage.registered_transition_attributes[abstract_element_storage_key(abstract_element)] or {
		return none
	}
	index := bucket.indexes[property_id] or { return none }
	return bucket.attributes[index]
}

pub fn (storage &CSSTransitionStorage) property_ids_with_existing_transitions(abstract_element dom.AbstractElement) []PropertyID {
	mut property_ids := []PropertyID{}
	bucket := storage.associated_transitions[abstract_element_storage_key(abstract_element)] or {
		return property_ids
	}
	for entry in bucket.entries {
		property_ids << entry.property_id
	}
	return property_ids
}

pub fn (storage &CSSTransitionStorage) property_transition(abstract_element dom.AbstractElement, property_id PropertyID) ?&CSSTransition {
	bucket := storage.associated_transitions[abstract_element_storage_key(abstract_element)] or {
		return none
	}
	index := bucket.indexes[property_id] or { return none }
	return bucket.entries[index].transition
}

pub fn (storage &CSSTransitionStorage) transitions_for(abstract_element dom.AbstractElement) []&CSSTransition {
	mut result := []&CSSTransition{}
	bucket := storage.associated_transitions[abstract_element_storage_key(abstract_element)] or {
		return result
	}
	for entry in bucket.entries {
		result << entry.transition
	}
	return result
}

pub fn (mut storage CSSTransitionStorage) set_transition(abstract_element dom.AbstractElement, property_id PropertyID, transition &CSSTransition) {
	mut bucket := storage.ensure_associated_transition_bucket(abstract_element)
	if property_id in bucket.indexes {
		panic('Transition already associated for property ${string_from_property_id(property_id)}')
	}
	bucket.indexes[property_id] = bucket.entries.len
	bucket.entries << CSSTransitionStorageEntry{
		abstract_element: abstract_element
		property_id: property_id
		transition: transition
	}
}

pub fn (mut storage CSSTransitionStorage) remove_transition(abstract_element dom.AbstractElement, property_id PropertyID) {
	key := abstract_element_storage_key(abstract_element)
	mut bucket := storage.associated_transitions[key] or {
		panic('No transition associated for property ${string_from_property_id(property_id)}')
	}
	index := bucket.indexes[property_id] or {
		panic('No transition associated for property ${string_from_property_id(property_id)}')
	}
	bucket.entries.delete(index)
	bucket.indexes.delete(property_id)
	for current := index; current < bucket.entries.len; current++ {
		bucket.indexes[bucket.entries[current].property_id] = current
	}
	if bucket.entries.len == 0 {
		storage.associated_transitions.delete(key)
	}
}

pub fn compute_transitioned_properties(style &ComputedProperties, abstract_element dom.AbstractElement, mut storage CSSTransitionStorage) {
	// FIXME: For now we don't bother registering transitions on the first computation since they can't run (because
	//        there is nothing to transition from) but this will change once we implement @starting-style.
	if abstract_element.computed_properties() == none {
		return
	}

	storage.clear_registered_transitions(abstract_element)

	delay := style.property(.transition_delay, .no) or { return }
	duration := style.property(.transition_duration, .no) or { return }

	value_is_list_containing_a_single_time_of_zero_seconds := fn (value &dom.StyleValue) bool {
		style_value := typed_style_value_logic_from_dom(value) or { return false }
		if style_value !is StyleValueList {
			return false
		}

		value_list := style_value as StyleValueList
		values := value_list.values()
		if values.len != 1 {
			return false
		}

		if values[0] !is TimeStyleValue {
			return false
		}

		return (values[0] as TimeStyleValue).time().to_seconds() == 0
	}

	// OPTIMIZATION: Registered transitions with a "combined duration" of less than or equal to 0s are equivalent to not
	//               having a transition registered at all, except in the case that we already have an associated
	//               transition for that property, so we can skip registering them. This implementation intentionally
	//               ignores some of those cases (e.g. transitions being registered but for other properties, multiple
	//               transitions, negative delays, etc) since it covers the common (initial property values) case and
	//               the other cases are rare enough that the cost of identifying them would likely more than offset any
	//               gains.
	if storage.property_ids_with_existing_transitions(abstract_element).len == 0
		&& value_is_list_containing_a_single_time_of_zero_seconds(delay)
		&& value_is_list_containing_a_single_time_of_zero_seconds(duration) {
		return
	}

	storage.add_transitioned_properties(abstract_element, style.transitions())
}

fn combined_transition_duration(transition_attributes TransitionTimingAttributes) f64 {
	// Define the combined duration of the transition as the sum of max(matching transition duration, 0s) and the matching transition delay.
	return math.max(transition_attributes.duration, 0) + transition_attributes.delay
}

fn collect_transition_into_computed_properties(abstract_element dom.AbstractElement, transition &CSSTransition, mut computed_properties ComputedProperties) {
	start := transition.transition_start_value()
	end := transition.transition_end_value()
	value := interpolate_property(abstract_element.element(), transition.transition_property_, start, end, 0.0, .yes) or { start }
	computed_properties.set_animated_property(transition.transition_property_, value, .yes, .no)
}

pub fn transition_timing_attributes_for_property(abstract_element dom.AbstractElement, property_id PropertyID) TransitionTimingAttributes {
	style_computer := css_style_computer_for(abstract_element.document())
	storage := style_computer.css_transition_storage_
	if storage == unsafe { nil } {
		return TransitionTimingAttributes{}
	}
	return storage.property_transition_attributes(abstract_element, property_id) or {
		TransitionTimingAttributes{}
	}
}

fn document_timeline_for_transition(abstract_element dom.AbstractElement) ?&AnimationTimeline {
	style_computer := css_style_computer_for(abstract_element.document())
	if style_computer.document_timeline_ == unsafe { nil } {
		return none
	}
	return style_computer.document_timeline_
}

fn set_transition_on_element(abstract_element dom.AbstractElement, property_id PropertyID, transition &CSSTransition) {
	mut style_computer := css_style_computer_for(abstract_element.document())
	if style_computer.css_transition_storage_ == unsafe { nil } {
		return
	}
	style_computer.css_transition_storage_.set_transition(abstract_element, property_id, transition)
}

pub fn CSSTransition.start_a_transition(abstract_element dom.AbstractElement, property_id PropertyID, transition_generation int, delay f64, start_time f64, end_time f64, start_value &dom.StyleValue, end_value &dom.StyleValue, reversing_adjusted_start_value &dom.StyleValue, reversing_shortening_factor f64) &CSSTransition {
	return CSSTransition.new(abstract_element, property_id, transition_generation, delay, start_time, end_time, start_value, end_value, reversing_adjusted_start_value, reversing_shortening_factor)
}

pub fn CSSTransition.start_a_provisional_transition(abstract_element dom.AbstractElement, property_id PropertyID, transition_generation int, delay f64, start_time f64, end_time f64, start_value &dom.StyleValue, end_value &dom.StyleValue, reversing_adjusted_start_value &dom.StyleValue, reversing_shortening_factor f64) &CSSTransition {
	transition_attributes := transition_timing_attributes_for_property(abstract_element, property_id)
	return CSSTransition.new_with_timing_attributes_and_publication(abstract_element, property_id, transition_generation, transition_attributes, delay, start_time, end_time, start_value, end_value, reversing_adjusted_start_value, reversing_shortening_factor, .provisional)
}

pub fn CSSTransition.new(abstract_element dom.AbstractElement, property_id PropertyID, transition_generation int, delay f64, start_time f64, end_time f64, start_value &dom.StyleValue, end_value &dom.StyleValue, reversing_adjusted_start_value &dom.StyleValue, reversing_shortening_factor f64) &CSSTransition {
	transition_attributes := transition_timing_attributes_for_property(abstract_element, property_id)
	transition := CSSTransition.new_with_timing_attributes(abstract_element, property_id, transition_generation, transition_attributes, delay, start_time, end_time, start_value, end_value, reversing_adjusted_start_value, reversing_shortening_factor)
	set_transition_on_element(abstract_element, property_id, transition)
	return transition
}

pub fn CSSTransition.start_a_transition_for_storage(mut storage CSSTransitionStorage, abstract_element dom.AbstractElement, property_id PropertyID, transition_generation int, transition_attributes TransitionTimingAttributes, delay f64, start_time f64, end_time f64, start_value &dom.StyleValue, end_value &dom.StyleValue, reversing_adjusted_start_value &dom.StyleValue, reversing_shortening_factor f64) &CSSTransition {
	transition := CSSTransition.new_with_timing_attributes(abstract_element, property_id, transition_generation, transition_attributes, delay, start_time, end_time, start_value, end_value, reversing_adjusted_start_value, reversing_shortening_factor)
	storage.set_transition(abstract_element, property_id, transition)
	return transition
}

pub fn CSSTransition.new_with_timing_attributes(abstract_element dom.AbstractElement, property_id PropertyID, transition_generation int, transition_attributes TransitionTimingAttributes, delay f64, start_time f64, end_time f64, start_value &dom.StyleValue, end_value &dom.StyleValue, reversing_adjusted_start_value &dom.StyleValue, reversing_shortening_factor f64) &CSSTransition {
	return CSSTransition.new_with_timing_attributes_and_publication(abstract_element, property_id, transition_generation, transition_attributes, delay, start_time, end_time, start_value, end_value, reversing_adjusted_start_value, reversing_shortening_factor, .committed)
}

fn CSSTransition.new_with_timing_attributes_and_publication(abstract_element dom.AbstractElement, property_id PropertyID, transition_generation int, transition_attributes TransitionTimingAttributes, delay f64, start_time f64, end_time f64, start_value &dom.StyleValue, end_value &dom.StyleValue, reversing_adjusted_start_value &dom.StyleValue, reversing_shortening_factor f64, publication CSSTransitionPublication) &CSSTransition {
	mut transition := &CSSTransition{
		transition_property_: property_id
		transition_generation_: transition_generation
		start_time_: start_time + delay
		end_time_: end_time + delay
		start_value_: start_value
		end_value_: end_value
		reversing_adjusted_start_value_: reversing_adjusted_start_value
		reversing_shortening_factor_: reversing_shortening_factor
		keyframe_effect_: KeyframeEffect.create()
		is_provisional_: publication == .provisional
	}
	transition.Animation.concrete_handle_ = voidptr(transition)
	transition.Animation.concrete_kind_ = .css_transition

	// FIXME:
	// Transitions generated using the markup defined in this specification are not added to the global animation list
	// when they are created. Instead, these animations are appended to the global animation list at the first moment
	// when they transition out of the idle play state after being disassociated from their owning element. Transitions
	// that have been disassociated from their owning element but are still idle do not have a defined composite order.

	// Construct a KeyframesEffect for our animation
	transition.keyframe_effect_.set_target(abstract_element)
	transition.keyframe_effect_.set_specified_start_delay(delay)
	transition.keyframe_effect_.set_specified_iteration_duration(end_time - start_time)
	// CSS transitions apply their start value throughout transition-delay. A
	// default keyframe effect does not fill the before phase, so use backwards
	// fill until the active interval begins.
	transition.keyframe_effect_.set_fill_mode(.backwards)
	// https://drafts.csswg.org/web-animations-2/#updating-animationeffect-timing
	// Timing properties may also be updated due to a style change. Any change to a CSS animation property that affects
	// timing requires rerunning the procedure to normalize specified timing.
	transition.keyframe_effect_.normalize_specified_timing()
	transition.keyframe_effect_.set_timing_function(transition_attributes.timing_function)
	transition.keyframe_effect_.mark_as_css_transition()
	transition.keyframe_effect_.set_default_easing(transition_attributes.timing_function)
	transition.keyframe_effect_.set_output_progress(0.0)

	mut key_frame_set := &KeyFrameSet{}
	mut initial_keyframe := ResolvedKeyFrame{}
	unsafe {
		initial_keyframe.properties[property_id] = start_value
	}
	mut final_keyframe := ResolvedKeyFrame{}
	unsafe {
		final_keyframe.properties[property_id] = end_value
	}
	key_frame_set.keyframes_by_key[0] = initial_keyframe
	key_frame_set.keyframes_by_key[100 * animation_key_frame_key_scale_factor] = final_keyframe

	transition.keyframe_effect_.set_key_frame_set(key_frame_set)
	transition.set_timeline(document_timeline_for_transition(abstract_element))
	transition.set_owning_element(abstract_element)
	transition.set_effect(transition.keyframe_effect_)
	document := abstract_element.document()
	execution_context := document.begin_temporary_execution_context()
	transition.play() or {}
	document.end_temporary_execution_context(execution_context)
	return transition
}

fn start_transition_for_storage(abstract_element dom.AbstractElement, property_id PropertyID, transition_generation int, transition_attributes TransitionTimingAttributes, delay f64, start_time f64, end_time f64, start_value &dom.StyleValue, end_value &dom.StyleValue, reversing_adjusted_start_value &dom.StyleValue, reversing_shortening_factor f64, mut new_style ComputedProperties, mut storage CSSTransitionStorage) &CSSTransition {
	// A transition keeps its endpoints for its whole run; the before-change
	// style can hold animation samples that are reused later.
	style_computer := css_style_computer_for(abstract_element.document())
	transition := CSSTransition.start_a_transition_for_storage(mut storage, abstract_element, property_id, transition_generation, transition_attributes, delay, start_time, end_time, style_computer.copy_sampled_style_value(property_id, start_value), style_computer.copy_sampled_style_value(property_id, end_value), style_computer.copy_sampled_style_value(property_id, reversing_adjusted_start_value), reversing_shortening_factor)

	// Immediately set the property's value to the transition's current value, to prevent single-frame jumps.
	collect_transition_into_computed_properties(abstract_element, transition, mut new_style)
	return transition
}

// https://drafts.csswg.org/css-transitions/#starting
pub fn start_needed_transitions_for_storage(previous_style &ComputedProperties, mut new_style ComputedProperties, abstract_element dom.AbstractElement, transition_generation int, document_timeline &AnimationTimeline, mut storage CSSTransitionStorage) {
	// For each element and property, the implementation must act as follows:
	// NB: A DocumentTimeline's current time is always in milliseconds.
	style_change_event_time := document_timeline.current_time_ms() or { return }

	// OPTIMIZATION: Instead of iterating over all properties we split the logic into two loops, one for the properties
	//               which appear in transition-property and one for those which have existing transitions
	for property_id in storage.property_ids_with_matching_transition_property_entry(abstract_element) {
		matching_transition_properties := storage.property_transition_attributes(abstract_element, property_id) or { continue }

		mut existing_transition := &CSSTransition(unsafe { nil })
		mut has_existing_transition := false
		if transition := storage.property_transition(abstract_element, property_id) {
			existing_transition = unsafe { &CSSTransition(transition) }
			has_existing_transition = true
		}

		// None of the transition-starting steps below can have an effect when there is no
		// existing transition and the matching transition has no active duration. Avoid
		// resolving both computed values in that overwhelmingly common case.
		if !has_existing_transition
			&& combined_transition_duration(matching_transition_properties) <= 0 {
			continue
		}

		before_change_value := previous_style.property(property_id, .yes) or { continue }
		after_change_value := new_style.property(property_id, .no) or { continue }

		has_running_transition := has_existing_transition && !existing_transition.is_finished()
			&& !existing_transition.is_idle()
		has_completed_transition := has_existing_transition
			&& (existing_transition.is_finished() || existing_transition.is_idle())

		// 1. If all of the following are true:
		// - the element does not have a running transition for the property,
		// - there is a matching transition-property value, and
		// NOTE: We only iterate over properties for which this is true
		// - the before-change style is different from the after-change style for that property, and the values for the property are transitionable,
		before_and_after_are_transitionable :=
			!style_values_equal(before_change_value, after_change_value)
				&& property_values_are_transitionable(property_id, before_change_value, after_change_value, abstract_element.element(), matching_transition_properties.transition_behavior)
		// - the element does not have a completed transition for the property
		//   or the end value of the completed transition is different from the after-change style for the property,
		completed_transition_can_be_replaced := !has_completed_transition
			|| !style_values_equal(existing_transition.transition_end_value(), after_change_value)
		// - the combined duration is greater than 0s,
		matching_transition_has_duration := combined_transition_duration(matching_transition_properties) > 0
		if !has_running_transition && before_and_after_are_transitionable
			&& completed_transition_can_be_replaced && matching_transition_has_duration {
			// then implementations must remove the completed transition (if present) from the set of completed transitions
			if has_completed_transition {
				storage.remove_transition(abstract_element, property_id)
			}

			// and start a transition whose:

			// AD-HOC: We pass delay to the constructor separately so we can use it to construct the contained KeyframeEffect
			delay := matching_transition_properties.delay

			// - start time is the time of the style change event plus the matching transition delay,
			start_time := style_change_event_time

			// - end time is the start time plus the matching transition duration,
			end_time := start_time + matching_transition_properties.duration

			// - start value is the value of the transitioning property in the before-change style,
			start_value := before_change_value

			// - end value is the value of the transitioning property in the after-change style,
			end_value := after_change_value

			// - reversing-adjusted start value is the same as the start value, and
			reversing_adjusted_start_value := start_value

			// - reversing shortening factor is 1.
			reversing_shortening_factor := 1.0

			start_transition_for_storage(abstract_element, property_id, transition_generation, matching_transition_properties, delay, start_time, end_time, start_value, end_value, reversing_adjusted_start_value, reversing_shortening_factor, mut new_style, mut storage)
			// 2. Otherwise, if the element has a completed transition for the property
			//    and the end value of the completed transition is different from the after-change style for the property,
			//    then implementations must remove the completed transition from the set of completed transitions.
		} else if has_completed_transition
			&& !style_values_equal(existing_transition.transition_end_value(), after_change_value) {
			storage.remove_transition(abstract_element, property_id)
		}

		// NOTE: Step 3 is handled in a separate loop below for performance reasons

		// 4. If the element has a running transition for the property,
		//    there is a matching transition-property value,
		//    and the end value of the running transition is not equal to the value of the property in the after-change style, then:
		if has_running_transition
			&& !style_values_equal(existing_transition.transition_end_value(), after_change_value) {
			// 1. If the current value of the property in the running transition is equal to the value of the property in the after-change style,
			//    or if these two values are not transitionable,
			//    then implementations must cancel the running transition.
			current_value := new_style.property(property_id, .yes) or { continue }
			if style_values_equal(current_value, after_change_value)
				|| !property_values_are_transitionable(property_id, current_value, after_change_value, abstract_element.element(), matching_transition_properties.transition_behavior) {
				existing_transition.cancel()
				// 2. Otherwise, if the combined duration is less than or equal to 0s,
				//    or if the current value of the property in the running transition is not transitionable with the value of the property in the after-change style,
				//    then implementations must cancel the running transition.
			} else if combined_transition_duration(matching_transition_properties) <= 0
				|| !property_values_are_transitionable(property_id, current_value, after_change_value, abstract_element.element(), matching_transition_properties.transition_behavior) {
				existing_transition.cancel()
				// 3. Otherwise, if the reversing-adjusted start value of the running transition is the same as the value of the property in the after-change style
				//    (see the section on reversing of transitions for why these case exists),
			} else if style_values_equal(existing_transition.reversing_adjusted_start_value(), after_change_value) {
				// implementations must cancel the running transition and start a new transition whose:
				existing_transition.cancel()
				// AD-HOC: Remove the cancelled transition, otherwise it breaks the invariant that there is only one
				// running or completed transition for a property at once.
				storage.remove_transition(abstract_element, property_id)

				// - reversing-adjusted start value is the end value of the running transition,
				reversing_adjusted_start_value := existing_transition.transition_end_value()

				// - reversing shortening factor is the absolute value, clamped to the range [0, 1], of the sum of:
				//   1. the output of the timing function of the old transition at the time of the style change event,
				//      times the reversing shortening factor of the old transition
				term_1 := existing_transition.timing_function_output_at_time(style_change_event_time) * existing_transition.reversing_shortening_factor()
				//   2. 1 minus the reversing shortening factor of the old transition.
				term_2 := 1 - existing_transition.reversing_shortening_factor()
				reversing_shortening_factor := screen_animation_clamp_f64(math.abs(term_1 + term_2), 0.0, 1.0)

				// AD-HOC: We pass delay to the constructor separately so we can use it to construct the contained KeyframeEffect
				delay := if matching_transition_properties.delay >= 0 {
					matching_transition_properties.delay
				} else {
					reversing_shortening_factor * matching_transition_properties.delay
				}

				// - start time is the time of the style change event plus:
				//   1. if the matching transition delay is nonnegative, the matching transition delay, or
				//   2. if the matching transition delay is negative, the product of the new transition's reversing shortening factor and the matching transition delay,
				start_time := style_change_event_time

				// - end time is the start time plus the product of the matching transition duration and the new transition's reversing shortening factor,
				end_time := start_time + (matching_transition_properties.duration * reversing_shortening_factor)

				// - start value is the current value of the property in the running transition,
				start_value := current_value

				// - end value is the value of the property in the after-change style,
				end_value := after_change_value

				start_transition_for_storage(abstract_element, property_id, transition_generation, matching_transition_properties, delay, start_time, end_time, start_value, end_value, reversing_adjusted_start_value, reversing_shortening_factor, mut new_style, mut storage)
			} else {
				// 4. Otherwise,
				// implementations must cancel the running transition and start a new transition whose:
				existing_transition.cancel()
				// AD-HOC: Remove the cancelled transition, otherwise it breaks the invariant that there is only one
				// running or completed transition for a property at once.
				storage.remove_transition(abstract_element, property_id)

				// AD-HOC: We pass delay to the constructor separately so we can use it to construct the contained KeyframeEffect
				delay := matching_transition_properties.delay

				// - start time is the time of the style change event plus the matching transition delay,
				start_time := style_change_event_time

				// - end time is the start time plus the matching transition duration,
				end_time := start_time + matching_transition_properties.duration

				// - start value is the current value of the property in the running transition,
				start_value := current_value

				// - end value is the value of the property in the after-change style,
				end_value := after_change_value

				// - reversing-adjusted start value is the same as the start value, and
				reversing_adjusted_start_value := start_value

				// - reversing shortening factor is 1.
				reversing_shortening_factor := 1.0

				start_transition_for_storage(abstract_element, property_id, transition_generation, matching_transition_properties, delay, start_time, end_time, start_value, end_value, reversing_adjusted_start_value, reversing_shortening_factor, mut new_style, mut storage)
			}
		}
	}

	for property_id in storage.property_ids_with_existing_transitions(abstract_element) {
		// 3. If the element has a running transition or completed transition for the property, and there is not a
		//    matching transition-property value, then implementations must cancel the running transition or remove the
		//    completed transition from the set of completed transitions.
		if _ := storage.property_transition_attributes(abstract_element, property_id) {
			continue
		}

		mut existing_transition := unsafe {
			&CSSTransition(storage.property_transition(abstract_element, property_id) or {
				continue
			})
		}
		if !existing_transition.is_finished() && !existing_transition.is_idle() {
			existing_transition.cancel()
		} else {
			storage.remove_transition(abstract_element, property_id)
		}
	}
}

pub fn (mut transition CSSTransition) initialize() {
	_ = transition
	// WEB_SET_PROTOTYPE_FOR_INTERFACE(CSSTransition);
	// Base::initialize(realm);
}

pub fn (mut transition CSSTransition) visit_edges(mut visitor dom.CellVisitor) {
	// Base::visit_edges(visitor);
	if cached_declaration := transition.cached_declaration {
		visitor.visit(cached_declaration)
	}
	if transition.keyframe_effect_ != unsafe { nil } {
		visitor.visit(transition.keyframe_effect_)
	}
}

pub fn (transition &CSSTransition) transition_property() string {
	return string_from_property_id(transition.transition_property_)
}

pub fn (transition &CSSTransition) animation_class() AnimationClass {
	_ = transition
	return .css_transition
}

pub fn (transition &CSSTransition) owning_element() ?dom.AbstractElement {
	return transition.owning_element_
}

pub fn (mut transition CSSTransition) set_owning_element(owning_element dom.AbstractElement) {
	transition.owning_element_ = owning_element
}

pub fn (transition &CSSTransition) global_animation_list_order() int {
	return transition.global_animation_list_order_
}

pub fn (mut transition CSSTransition) set_timeline(timeline ?&AnimationTimeline) {
	transition.timeline_ = timeline
}

pub fn (mut transition CSSTransition) set_effect(effect &KeyframeEffect) {
	transition.keyframe_effect_ = effect
}

pub fn (mut transition CSSTransition) play() ! {
	transition.play_state_ = .running
}

pub fn (mut transition CSSTransition) cancel() {
	transition.play_state_ = .idle
	transition.current_phase_ = .idle
	if transition.keyframe_effect_ != unsafe { nil } {
		transition.keyframe_effect_.set_output_progress(none)
	}
}

pub fn (mut transition CSSTransition) sample_at(timeline_time f64) ?f64 {
	if transition.play_state_ == .idle || transition.keyframe_effect_ == unsafe { nil } {
		transition.current_phase_ = .idle
		return none
	}
	mut progress := 0.0
	if transition.end_time_ <= transition.start_time_ {
		progress = 1.0
		transition.current_phase_ = .after
	} else if timeline_time < transition.start_time_ {
		progress = 0.0
		transition.current_phase_ = .before
	} else if timeline_time >= transition.end_time_ {
		progress = 1.0
		transition.play_state_ = .finished
		transition.current_phase_ = .after
	} else {
		progress = (timeline_time - transition.start_time_) / (transition.end_time_ - transition.start_time_)
		transition.current_phase_ = .active
	}
	transition.keyframe_effect_.set_output_progress(progress)
	return progress
}

pub fn (transition &CSSTransition) is_finished() bool {
	return transition.play_state_ == .finished
}

pub fn (transition &CSSTransition) is_idle() bool {
	return transition.play_state_ == .idle
}

pub fn (transition &CSSTransition) effect() ?&KeyframeEffect {
	if transition.keyframe_effect_ == unsafe { nil } {
		return none
	}
	return transition.keyframe_effect_
}

pub fn (transition &CSSTransition) is_provisional() bool {
	return transition.is_provisional_
}

pub fn (mut transition CSSTransition) commit_provisional_transition() {
	if !transition.is_provisional_ {
		panic('Cannot commit a non-provisional CSS transition')
	}
	owner := transition.owning_element() or {
		panic('A provisional CSS transition must have an owning element')
	}
	set_transition_on_element(owner, transition.transition_property_, unsafe {
		&CSSTransition(transition)
	})
	transition.is_provisional_ = false
}

pub fn (mut transition CSSTransition) discard_provisional_transition() {
	if !transition.is_provisional_ {
		panic('Cannot discard a non-provisional CSS transition')
	}
	transition.set_timeline(none)
	transition.keyframe_effect_ = unsafe { nil }
	transition.is_provisional_ = false
}

pub fn (transition &CSSTransition) class_specific_composite_order(other &CSSTransition) int {
	// Within the set of CSS Transitions, two animations A and B are sorted in composite order (first to last) as
	// follows:

	// 1. If neither A nor B has an owning element, sort based on their relative position in the global animation list.
	if transition.owning_element_ == none && other.owning_element_ == none {
		return transition.global_animation_list_order() - other.global_animation_list_order()
	}

	// 2. Otherwise, if only one of A or B has an owning element, let the animation with an owning element sort first.
	if transition.owning_element_ != none && other.owning_element_ == none {
		return -1
	}
	if transition.owning_element_ == none && other.owning_element_ != none {
		return 1
	}

	// 3. Otherwise, if the owning element of A and B differs, sort A and B by tree order of their corresponding owning
	//    elements. With regard to pseudo-elements, the sort order is as follows:
	//    - element
	//    - ::marker
	//    - ::before
	//    - any other pseudo-elements not mentioned specifically in this list, sorted in ascending order by the Unicode
	//      codepoints that make up each selector
	//    - ::after
	//    - element children
	transition_owner := transition.owning_element_ or { return 0 }
	other_owner := other.owning_element_ or { return 0 }
	if !abstract_elements_equal(transition_owner, other_owner) {
		// FIXME: Actually sort by tree order
		return 0
	}

	// 4. Otherwise, if A and B have different transition generation values, sort by their corresponding transition
	//    generation in ascending order.
	if transition.transition_generation_ != other.transition_generation_ {
		return transition.transition_generation_ - other.transition_generation_
	}

	// 5. Otherwise, sort A and B in ascending order by the Unicode codepoints that make up the expanded transition
	//    property name of each transition (i.e. without attempting case conversion and such that '-moz-column-width'
	//    sorts before 'column-width').
	// FIXME: This should operate on Unicode strings, not StringViews.
	return transition.transition_property().compare(other.transition_property())
}

pub fn (transition &CSSTransition) transition_start_time() f64 {
	return transition.start_time_
}

pub fn (transition &CSSTransition) transition_end_time() f64 {
	return transition.end_time_
}

pub fn (transition &CSSTransition) transition_start_value() &dom.StyleValue {
	return transition.start_value_
}

pub fn (transition &CSSTransition) transition_end_value() &dom.StyleValue {
	return transition.end_value_
}

pub fn (transition &CSSTransition) reversing_adjusted_start_value() &dom.StyleValue {
	return transition.reversing_adjusted_start_value_
}

pub fn (transition &CSSTransition) reversing_shortening_factor() f64 {
	return transition.reversing_shortening_factor_
}

pub fn (transition &CSSTransition) timing_function_output_at_time(t f64) f64 {
	// AD-HOC: If the transition has an empty duration then we get NaN here,
	// setting progress to 1 because an instant transition may be considered "finished".
	mut progress := 1.0
	if transition.transition_start_time() < transition.transition_end_time() {
		progress = (t - transition.transition_start_time()) / (transition.transition_end_time() - transition.transition_start_time())
	}

	// FIXME: Is this before_flag value correct?
	before_flag := t < transition.transition_start_time()
	return transition.keyframe_effect_.timing_function().evaluate_at(progress, before_flag)
}

pub fn (transition &CSSTransition) previous_phase() CSSTransitionPhase {
	return transition.previous_phase_
}

pub fn (mut transition CSSTransition) set_previous_phase(phase CSSTransitionPhase) {
	transition.previous_phase_ = phase
}

pub fn (transition &CSSTransition) is_css_transition() bool {
	_ = transition
	return true
}

enum TransitionEventInterval {
	start
	end
	active_time
}

fn css_animation_pseudo_element_string(owner dom.AbstractElement) string {
	pseudo := owner.pseudo_element() or { return '' }
	return '::${pseudo_element_name(style_scope_pseudo_element_from_dom(pseudo))}'
}

fn css_animation_event_scheduled_time() f64 {
	return f64(time.sys_mono_now()) / 1.0e6
}

fn append_transition_event(mut document dom.Document, transition &CSSTransition, name string, interval TransitionEventInterval) {
	owner := transition.owning_element() or { return }
	effect := transition.effect() or { return }
	active_duration := math.max(0.0, effect.specified_iteration_duration)
	elapsed_time_ms := match interval {
		.start { math.max(0.0, math.min(-effect.specified_start_delay, active_duration)) }
		.end { active_duration }
		.active_time { 0.0 }
	}
	document.append_pending_animation_event(dom.PendingAnimationEvent{
		event_factory: materialize_pending_css_transition_event
		event_type: name
		event_name: transition.transition_property()
		event_elapsed_time: elapsed_time_ms / 1000.0
		event_pseudo_element: css_animation_pseudo_element_string(owner)
		event_time_stamp: dom.current_event_timestamp()
		animation: &transition.Animation
		target: unsafe { &dom.EventTarget(owner.element().as_node()) }
		scheduled_event_time: css_animation_event_scheduled_time()
	})
}

// Document::dispatch_events_for_transition(), operating on the concrete
// CSS-owned transition after crossing DOM's module-cycle boundary.
fn dispatch_events_for_css_transition(mut document dom.Document, mut transition CSSTransition) {
	previous_phase := transition.previous_phase()
	transition_phase := transition.current_phase_
	if previous_phase == .idle {
		if transition_phase == .pending || transition_phase == .before {
			append_transition_event(mut document, transition, 'transitionrun', .start)
		}
		if transition_phase == .active {
			append_transition_event(mut document, transition, 'transitionrun', .start)
			append_transition_event(mut document, transition, 'transitionstart', .start)
		}
		if transition_phase == .after {
			append_transition_event(mut document, transition, 'transitionrun', .start)
			append_transition_event(mut document, transition, 'transitionstart', .start)
			append_transition_event(mut document, transition, 'transitionend', .end)
		}
	} else if previous_phase == .pending || previous_phase == .before {
		if transition_phase == .active {
			append_transition_event(mut document, transition, 'transitionstart', .start)
		}
		if transition_phase == .after {
			append_transition_event(mut document, transition, 'transitionstart', .start)
			append_transition_event(mut document, transition, 'transitionend', .end)
		}
	} else if previous_phase == .active {
		if transition_phase == .after {
			append_transition_event(mut document, transition, 'transitionend', .end)
		}
		if transition_phase == .before {
			append_transition_event(mut document, transition, 'transitionend', .start)
		}
	} else if previous_phase == .after {
		if transition_phase == .active {
			append_transition_event(mut document, transition, 'transitionstart', .end)
		}
		if transition_phase == .before {
			append_transition_event(mut document, transition, 'transitionstart', .end)
			append_transition_event(mut document, transition, 'transitionend', .start)
		}
	}
	if transition_phase == .idle && previous_phase != .idle && previous_phase != .after {
		// Preserve the current upstream spelling in this cancellation branch.
		append_transition_event(mut document, transition, 'animationstart', .active_time)
	}
	transition.set_previous_phase(transition_phase)
}

fn append_css_animation_event(mut document dom.Document, animation &CSSAnimation, name string, elapsed_time_ms f64) {
	effect := animation.effect() or { return }
	target := effect.target_ or { return }
	owner := animation.owning_element() or { target }
	document.append_pending_animation_event(dom.PendingAnimationEvent{
		event_factory: materialize_pending_css_animation_event
		event_type: name
		event_name: animation.animation_name()
		event_elapsed_time: elapsed_time_ms / 1000.0
		event_pseudo_element: css_animation_pseudo_element_string(owner)
		event_time_stamp: dom.current_event_timestamp()
		animation: &animation.Animation
		target: unsafe { &dom.EventTarget(target.element().as_node()) }
		scheduled_event_time: css_animation_event_scheduled_time()
	})
}

fn materialize_pending_css_animation_event(pending &dom.PendingAnimationEvent) &dom.Event {
	mut event := AnimationEvent.create(pending.event_type, AnimationEventInit{
		EventInit: dom.EventInit{
			bubbles: true
		}
		animation_name: pending.event_name
		elapsed_time: pending.event_elapsed_time
		pseudo_element: pending.event_pseudo_element
	}).base_event()
	event.set_time_stamp(pending.event_time_stamp)
	return event
}

fn materialize_pending_css_transition_event(pending &dom.PendingAnimationEvent) &dom.Event {
	mut event := TransitionEvent.create(pending.event_type, TransitionEventInit{
		EventInit: dom.EventInit{bubbles:true}
		property_name: pending.event_name
		elapsed_time: pending.event_elapsed_time
		pseudo_element: pending.event_pseudo_element
	}).base_event()
	event.set_time_stamp(pending.event_time_stamp)
	return event
}

// Document::dispatch_events_for_animation_if_necessary() for CSSAnimation.
fn dispatch_events_for_css_animation(mut document dom.Document, mut animation CSSAnimation) {
	mut effect := animation.effect() or { return }
	target := effect.target_ or { return }
	_ = target
	previous_phase := effect.previous_phase
	current_phase := effect.current_phase
	current_iteration := effect.current_iteration
	active_duration := if math.is_inf(effect.iteration_count, 0) {
		math.inf(1)
	} else {
		math.max(0.0, effect.specified_iteration_duration) * math.max(0.0, effect.iteration_count)
	}
	interval_start := math.max(0.0, math.min(-effect.specified_start_delay, active_duration))
	interval_end := active_duration
	if previous_phase == .before || previous_phase == .idle {
		if current_phase == .active {
			append_css_animation_event(mut document, animation, 'animationstart', interval_start)
		} else if current_phase == .after {
			append_css_animation_event(mut document, animation, 'animationstart', interval_start)
			append_css_animation_event(mut document, animation, 'animationend', interval_end)
		}
	} else if previous_phase == .active {
		if current_phase == .before {
			append_css_animation_event(mut document, animation, 'animationend', interval_start)
		} else if current_phase == .active {
			if effect.previous_current_iteration != current_iteration {
				iteration_boundary := if effect.previous_current_iteration > current_iteration {
					current_iteration + 1.0
				} else {
					current_iteration
				}
				elapsed_time := effect.specified_iteration_duration * iteration_boundary
				append_css_animation_event(mut document, animation, 'animationiteration', elapsed_time)
			}
		} else if current_phase == .after {
			append_css_animation_event(mut document, animation, 'animationend', interval_end)
		}
	} else if previous_phase == .after {
		if current_phase == .active {
			append_css_animation_event(mut document, animation, 'animationstart', interval_end)
		} else if current_phase == .before {
			append_css_animation_event(mut document, animation, 'animationstart', interval_end)
			append_css_animation_event(mut document, animation, 'animationend', interval_start)
		}
	}
	if current_phase == .idle && previous_phase != .idle && previous_phase != .after {
		append_css_animation_event(mut document, animation, 'animationcancel', 0.0)
	}
	effect.previous_phase = current_phase
	effect.previous_current_iteration = current_iteration
}

fn style_computer_dispatch_css_animation_event(_ voidptr, document &dom.Document, animation &dom.Animation) {
	if animation.concrete_handle_ == unsafe { nil } {
		return
	}
	mut mutable_document := unsafe { &dom.Document(document) }
	match animation.concrete_kind_ {
		.css_transition {
			mut transition := unsafe { &CSSTransition(animation.concrete_handle_) }
			dispatch_events_for_css_transition(mut mutable_document, mut transition)
		}
		.css_animation {
			mut css_animation := unsafe { &CSSAnimation(animation.concrete_handle_) }
			dispatch_events_for_css_animation(mut mutable_document, mut css_animation)
		}
		else {}
	}
}
