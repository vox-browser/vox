module css

import dom
import math

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
	translate_x f64
	translate_y f64
	scale_x     f64 = 1.0
	scale_y     f64 = 1.0
}

pub fn (mut transform AffineTransform) translate(x f64, y f64) {
	transform.translate_x += x
	transform.translate_y += y
}

pub fn (mut transform AffineTransform) scale(scale_x f64, scale_y f64) {
	transform.scale_x *= scale_x
	transform.scale_y *= scale_y
}

pub fn (transform AffineTransform) map(position CSSPixelPoint) CSSPixelPoint {
	return CSSPixelPoint.from_values(position.x_.to_double() * transform.scale_x +
		transform.translate_x, position.y_.to_double() * transform.scale_y + transform.translate_y)
}

pub fn (transform AffineTransform) inverse_map(position CSSPixelPoint) CSSPixelPoint {
	if transform.scale_x == 0 || transform.scale_y == 0 {
		return position
	}
	return CSSPixelPoint.from_values((position.x_.to_double() - transform.translate_x) / transform.scale_x,
		(position.y_.to_double() - transform.translate_y) / transform.scale_y)
}

// https://drafts.csswg.org/cssom-view/#the-screen-interface
@[heap]
pub struct Screen {
	dom.EventTarget
pub mut:
	web_exposed_screen_area           CSSPixelRect = CSSPixelRect.new(0, 0, 800, 600)
	web_exposed_available_screen_area CSSPixelRect = CSSPixelRect.new(0, 0, 800, 600)
	screen_count                      int          = 1
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
	scale_         f64          = 1.0
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

fn (viewport &VisualViewport) event_target() &dom.EventTarget {
	return unsafe { &dom.EventTarget(viewport) }
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
	viewport.offset_ = viewport.offset_.plus(delta)
}

pub fn (viewport &VisualViewport) transform() AffineTransform {
	mut transform := AffineTransform{}
	offset := viewport.offset_.times_float(viewport.scale_)
	transform.translate(-offset.x().to_double(), -offset.y().to_double())
	transform.scale(viewport.scale_, viewport.scale_)
	return transform
}

pub fn (mut viewport VisualViewport) zoom(position CSSPixelPoint, scale_delta f64) {
	min_allowed_scale := 1.0
	max_allowed_scale := 5.0
	new_scale := screen_animation_clamp_f64(viewport.scale_ * (1.0 + scale_delta),
		min_allowed_scale, max_allowed_scale)
	applied_delta := new_scale / viewport.scale_

	// For pinch zoom we want focal_point to stay put on screen:
	// scale_new * (focal_point - offset_new) = scale_old * (focal_point - offset_old)
	mut new_offset_x := viewport.offset_.x().to_double() * viewport.scale_ * applied_delta
	mut new_offset_y := viewport.offset_.y().to_double() * viewport.scale_ * applied_delta
	new_offset_x += math.round(position.x().to_double()) * (applied_delta - 1.0)
	new_offset_y += math.round(position.y().to_double()) * (applied_delta - 1.0)

	viewport_rect := viewport.layout_viewport_rect()
	max_x_offset := math.max(0.0, viewport_rect.width.to_double() * (new_scale - 1.0))
	max_y_offset := math.max(0.0, viewport_rect.height.to_double() * (new_scale - 1.0))
	new_offset_x = screen_animation_clamp_f64(new_offset_x, 0.0, max_x_offset)
	new_offset_y = screen_animation_clamp_f64(new_offset_y, 0.0, max_y_offset)

	viewport.scale_ = new_scale
	viewport.offset_ = CSSPixelPoint.from_values(new_offset_x / viewport.scale_,
		new_offset_y / viewport.scale_)
	viewport.needs_contexts = true
	viewport.needs_repaint = true
}

pub fn (viewport &VisualViewport) map_to_layout_viewport(position CSSPixelPoint) CSSPixelPoint {
	return viewport.transform().inverse_map(position)
}

pub fn (mut viewport VisualViewport) reset() {
	viewport.scale_ = 1.0
	viewport.offset_ = CSSPixelPoint.from_values(0, 0)
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

pub struct ResolvedKeyFrame {
pub mut:
	properties map[PropertyID]&dom.StyleValue
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
	iteration_count              f64            = 1.0
	timing_function_             EasingFunction = EasingFunction.linear()
	fill_mode                    AnimationFillMode
	playback_direction           AnimationDirection
	composite                    CompositeOperation
	key_frame_set                ?&KeyFrameSet
	normalized_specified_timing  bool
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

pub fn (mut effect KeyframeEffect) set_key_frame_set(key_frame_set &KeyFrameSet) {
	effect.key_frame_set = key_frame_set
}

fn abstract_elements_equal(a dom.AbstractElement, b dom.AbstractElement) bool {
	if a.element_ != b.element_ {
		return false
	}
	return a.pseudo_element_ == b.pseudo_element_
}

const animation_key_frame_key_scale_factor = 1000

@[heap]
pub struct CSSAnimation {
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
}

pub fn CSSAnimation.create() &CSSAnimation {
	return &CSSAnimation{}
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
	animation.play_state_ = .running
}

pub fn (mut animation CSSAnimation) pause() ! {
	animation.play_state_ = .paused
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
		return old_source != new_source
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
	timeline_                    ?&AnimationTimeline
	play_state_                  WebAnimationPlayState
}

// This is designed to be created from AnimationEffect::Phase.
pub enum CSSTransitionPhase {
	before
	active
	after
	idle
	pending
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
	registered_transition_attributes []CSSTransitionStorageEntry
	associated_transitions           []CSSTransitionStorageEntry
}

pub struct TransitionTimingAttributes {
pub mut:
	delay               f64
	duration            f64
	timing_function     EasingFunction = EasingFunction.linear()
	transition_behavior TransitionBehavior
}

fn style_values_equal(a &dom.StyleValue, b &dom.StyleValue) bool {
	return a == b
}

fn transition_attributes_from_transition_properties(properties TransitionProperties) TransitionTimingAttributes {
	return TransitionTimingAttributes{
		delay:               properties.delay
		duration:            properties.duration
		timing_function:     properties.timing_function
		transition_behavior: properties.transition_behavior
	}
}

pub fn (mut storage CSSTransitionStorage) clear_registered_transitions(abstract_element dom.AbstractElement) {
	mut kept := []CSSTransitionStorageEntry{}
	for entry in storage.registered_transition_attributes {
		if !abstract_elements_equal(entry.abstract_element, abstract_element) {
			kept << entry
		}
	}
	storage.registered_transition_attributes = kept
}

pub fn (mut storage CSSTransitionStorage) add_transitioned_properties(abstract_element dom.AbstractElement, transitions []TransitionProperties) {
	for transition_properties in transitions {
		attributes := transition_attributes_from_transition_properties(transition_properties)
		for property_id in transition_properties.properties {
			mut did_update_existing_entry := false
			for mut entry in storage.registered_transition_attributes {
				if abstract_elements_equal(entry.abstract_element, abstract_element)
					&& entry.property_id == property_id {
					entry.attributes = attributes
					did_update_existing_entry = true
					break
				}
			}
			if did_update_existing_entry {
				continue
			}

			storage.registered_transition_attributes << CSSTransitionStorageEntry{
				abstract_element: abstract_element
				property_id:      property_id
				attributes:       attributes
			}
		}
	}
}

pub fn (storage &CSSTransitionStorage) property_ids_with_matching_transition_property_entry(abstract_element dom.AbstractElement) []PropertyID {
	mut property_ids := []PropertyID{}
	for entry in storage.registered_transition_attributes {
		if abstract_elements_equal(entry.abstract_element, abstract_element)
			&& entry.property_id !in property_ids {
			property_ids << entry.property_id
		}
	}
	return property_ids
}

pub fn (storage &CSSTransitionStorage) property_transition_attributes(abstract_element dom.AbstractElement, property_id PropertyID) ?TransitionTimingAttributes {
	for entry in storage.registered_transition_attributes {
		if abstract_elements_equal(entry.abstract_element, abstract_element)
			&& entry.property_id == property_id {
			return entry.attributes or { return none }
		}
	}
	return none
}

pub fn (storage &CSSTransitionStorage) property_ids_with_existing_transitions(abstract_element dom.AbstractElement) []PropertyID {
	mut property_ids := []PropertyID{}
	for entry in storage.associated_transitions {
		if abstract_elements_equal(entry.abstract_element, abstract_element)
			&& entry.property_id !in property_ids {
			property_ids << entry.property_id
		}
	}
	return property_ids
}

pub fn (storage &CSSTransitionStorage) property_transition(abstract_element dom.AbstractElement, property_id PropertyID) ?&CSSTransition {
	for entry in storage.associated_transitions {
		if abstract_elements_equal(entry.abstract_element, abstract_element)
			&& entry.property_id == property_id {
			return entry.transition
		}
	}
	return none
}

pub fn (mut storage CSSTransitionStorage) set_transition(abstract_element dom.AbstractElement, property_id PropertyID, transition &CSSTransition) {
	for entry in storage.associated_transitions {
		if abstract_elements_equal(entry.abstract_element, abstract_element)
			&& entry.property_id == property_id {
			panic('Transition already associated for property ${string_from_property_id(property_id)}')
		}
	}
	storage.associated_transitions << CSSTransitionStorageEntry{
		abstract_element: abstract_element
		property_id:      property_id
		transition:       transition
	}
}

pub fn (mut storage CSSTransitionStorage) remove_transition(abstract_element dom.AbstractElement, property_id PropertyID) {
	mut kept := []CSSTransitionStorageEntry{}
	mut did_remove := false
	for entry in storage.associated_transitions {
		if !abstract_elements_equal(entry.abstract_element, abstract_element)
			|| entry.property_id != property_id {
			kept << entry
		} else {
			did_remove = true
		}
	}
	if !did_remove {
		panic('No transition associated for property ${string_from_property_id(property_id)}')
	}
	storage.associated_transitions = kept
}

pub fn compute_transitioned_properties_for_storage(style &ComputedProperties, abstract_element dom.AbstractElement, mut storage CSSTransitionStorage) {
	// FIXME: For now we don't bother registering transitions on the first computation since they can't run (because
	//        there is nothing to transition from) but this will change once we implement @starting-style.
	if abstract_element.computed_properties() == none {
		return
	}

	storage.clear_registered_transitions(abstract_element)
	storage.add_transitioned_properties(abstract_element, style.transitions())
}

fn combined_transition_duration(transition_attributes TransitionTimingAttributes) f64 {
	// Define the combined duration of the transition as the sum of max(matching transition duration, 0s) and the matching transition delay.
	return math.max(transition_attributes.duration, 0) + transition_attributes.delay
}

fn collect_transition_into_computed_properties(abstract_element dom.AbstractElement, transition &CSSTransition, mut computed_properties ComputedProperties) {
	_ = abstract_element
	_ = transition
	_ = computed_properties
	// Boundary: StyleComputer::collect_animation_into() requires Animation sampling and effect stacks that are not
	// translated into this V port yet. Keep the transition-starting flow intact without synthesizing an incorrect value.
}

pub fn transition_timing_attributes_for_property(abstract_element dom.AbstractElement, property_id PropertyID) TransitionTimingAttributes {
	_ = abstract_element
	_ = property_id
	// Boundary: Element::property_transition_attributes(pseudo_element, property_id) is not translated on DOM::Element.
	// Callers that translate StyleComputer's transition update flow should pass CSSTransitionStorage explicitly.
	return TransitionTimingAttributes{}
}

fn document_timeline_for_transition(abstract_element dom.AbstractElement) ?&AnimationTimeline {
	_ = abstract_element
	// Boundary: abstract_element.document().timeline() is a DOM DocumentTimeline in this partial port,
	// while CSS animations currently use the local AnimationTimeline model.
	return &AnimationTimeline{}
}

fn set_transition_on_element(abstract_element dom.AbstractElement, property_id PropertyID, transition &CSSTransition) {
	_ = abstract_element
	_ = property_id
	_ = transition
	// Boundary: Element::set_transition(pseudo_element, property_id, transition) is not translated yet.
}

pub fn CSSTransition.start_a_transition(abstract_element dom.AbstractElement, property_id PropertyID, transition_generation int, delay f64, start_time f64, end_time f64, start_value &dom.StyleValue, end_value &dom.StyleValue, reversing_adjusted_start_value &dom.StyleValue, reversing_shortening_factor f64) &CSSTransition {
	return CSSTransition.new(abstract_element, property_id, transition_generation, delay,
		start_time, end_time, start_value, end_value, reversing_adjusted_start_value,
		reversing_shortening_factor)
}

pub fn CSSTransition.new(abstract_element dom.AbstractElement, property_id PropertyID, transition_generation int, delay f64, start_time f64, end_time f64, start_value &dom.StyleValue, end_value &dom.StyleValue, reversing_adjusted_start_value &dom.StyleValue, reversing_shortening_factor f64) &CSSTransition {
	transition_attributes := transition_timing_attributes_for_property(abstract_element,
		property_id)
	return CSSTransition.new_with_timing_attributes(abstract_element, property_id,
		transition_generation, transition_attributes, delay, start_time, end_time, start_value,
		end_value, reversing_adjusted_start_value, reversing_shortening_factor)
}

pub fn CSSTransition.start_a_transition_for_storage(mut storage CSSTransitionStorage, abstract_element dom.AbstractElement, property_id PropertyID, transition_generation int, transition_attributes TransitionTimingAttributes, delay f64, start_time f64, end_time f64, start_value &dom.StyleValue, end_value &dom.StyleValue, reversing_adjusted_start_value &dom.StyleValue, reversing_shortening_factor f64) &CSSTransition {
	transition := CSSTransition.new_with_timing_attributes(abstract_element, property_id,
		transition_generation, transition_attributes, delay, start_time, end_time, start_value,
		end_value, reversing_adjusted_start_value, reversing_shortening_factor)
	storage.set_transition(abstract_element, property_id, transition)
	return transition
}

pub fn CSSTransition.new_with_timing_attributes(abstract_element dom.AbstractElement, property_id PropertyID, transition_generation int, transition_attributes TransitionTimingAttributes, delay f64, start_time f64, end_time f64, start_value &dom.StyleValue, end_value &dom.StyleValue, reversing_adjusted_start_value &dom.StyleValue, reversing_shortening_factor f64) &CSSTransition {
	mut transition := &CSSTransition{
		transition_property_:            property_id
		transition_generation_:          transition_generation
		start_time_:                     start_time + delay
		end_time_:                       end_time + delay
		start_value_:                    start_value
		end_value_:                      end_value
		reversing_adjusted_start_value_: reversing_adjusted_start_value
		reversing_shortening_factor_:    reversing_shortening_factor
		keyframe_effect_:                KeyframeEffect.create()
	}

	// FIXME:
	// Transitions generated using the markup defined in this specification are not added to the global animation list
	// when they are created. Instead, these animations are appended to the global animation list at the first moment
	// when they transition out of the idle play state after being disassociated from their owning element. Transitions
	// that have been disassociated from their owning element but are still idle do not have a defined composite order.

	// Construct a KeyframesEffect for our animation
	transition.keyframe_effect_.set_target(abstract_element)
	transition.keyframe_effect_.set_specified_start_delay(delay)
	transition.keyframe_effect_.set_specified_iteration_duration(end_time - start_time)
	// https://drafts.csswg.org/web-animations-2/#updating-animationeffect-timing
	// Timing properties may also be updated due to a style change. Any change to a CSS animation property that affects
	// timing requires rerunning the procedure to normalize specified timing.
	transition.keyframe_effect_.normalize_specified_timing()
	transition.keyframe_effect_.set_timing_function(transition_attributes.timing_function)

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
	set_transition_on_element(abstract_element, transition.transition_property_, transition)

	// Boundary: HTML::TemporaryExecutionContext is not translated yet.
	transition.play() or {}
	return transition
}

fn start_transition_for_storage(abstract_element dom.AbstractElement, property_id PropertyID, transition_generation int, transition_attributes TransitionTimingAttributes, delay f64, start_time f64, end_time f64, start_value &dom.StyleValue, end_value &dom.StyleValue, reversing_adjusted_start_value &dom.StyleValue, reversing_shortening_factor f64, mut new_style ComputedProperties, mut storage CSSTransitionStorage) &CSSTransition {
	transition := CSSTransition.start_a_transition_for_storage(mut storage, abstract_element,
		property_id, transition_generation, transition_attributes, delay, start_time, end_time,
		start_value, end_value, reversing_adjusted_start_value, reversing_shortening_factor)

	// Immediately set the property's value to the transition's current value, to prevent single-frame jumps.
	collect_transition_into_computed_properties(abstract_element, transition, mut new_style)
	return transition
}

// https://drafts.csswg.org/css-transitions/#starting
pub fn start_needed_transitions_for_storage(previous_style &ComputedProperties, mut new_style ComputedProperties, abstract_element dom.AbstractElement, transition_generation int, style_change_event_time f64, mut storage CSSTransitionStorage) {
	// For each element and property, the implementation must act as follows:
	// NB: C++ gets style_change_event_time from DocumentTimeline's current time in milliseconds. The caller supplies it
	// here because DocumentTimeline is not translated into this CSS animation model yet.

	// OPTIMIZATION: Instead of iterating over all properties we split the logic into two loops, one for the properties
	//               which appear in transition-property and one for those which have existing transitions
	for property_id in storage.property_ids_with_matching_transition_property_entry(abstract_element) {
		matching_transition_properties := storage.property_transition_attributes(abstract_element,
			property_id) or { continue }
		before_change_value := previous_style.property(property_id, .yes) or { continue }
		after_change_value := new_style.property(property_id, .no) or { continue }

		mut existing_transition := &CSSTransition(unsafe { nil })
		mut has_existing_transition := false
		if transition := storage.property_transition(abstract_element, property_id) {
			existing_transition = unsafe { &CSSTransition(transition) }
			has_existing_transition = true
		}

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

			start_transition_for_storage(abstract_element, property_id, transition_generation,
				matching_transition_properties, delay, start_time, end_time, start_value,
				end_value, reversing_adjusted_start_value, reversing_shortening_factor, mut
				new_style, mut storage)
		}
		// 2. Otherwise, if the element has a completed transition for the property
		//    and the end value of the completed transition is different from the after-change style for the property,
		//    then implementations must remove the completed transition from the set of completed transitions.
		else if has_completed_transition
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
			}
			// 2. Otherwise, if the combined duration is less than or equal to 0s,
			//    or if the current value of the property in the running transition is not transitionable with the value of the property in the after-change style,
			//    then implementations must cancel the running transition.
			else if combined_transition_duration(matching_transition_properties) <= 0
				|| !property_values_are_transitionable(property_id, current_value, after_change_value, abstract_element.element(), matching_transition_properties.transition_behavior) {
				existing_transition.cancel()
			}
			// 3. Otherwise, if the reversing-adjusted start value of the running transition is the same as the value of the property in the after-change style
			//    (see the section on reversing of transitions for why these case exists),
			else if style_values_equal(existing_transition.reversing_adjusted_start_value(),
				after_change_value)
			{
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
				reversing_shortening_factor := screen_animation_clamp_f64(math.abs(term_1 + term_2),
					0.0, 1.0)

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
				end_time := start_time +
					(matching_transition_properties.duration * reversing_shortening_factor)

				// - start value is the current value of the property in the running transition,
				start_value := current_value

				// - end value is the value of the property in the after-change style,
				end_value := after_change_value

				start_transition_for_storage(abstract_element, property_id, transition_generation,
					matching_transition_properties, delay, start_time, end_time, start_value,
					end_value, reversing_adjusted_start_value, reversing_shortening_factor, mut
					new_style, mut storage)
			}
			// 4. Otherwise,
			else {
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

				start_transition_for_storage(abstract_element, property_id, transition_generation,
					matching_transition_properties, delay, start_time, end_time, start_value,
					end_value, reversing_adjusted_start_value, reversing_shortening_factor, mut
					new_style, mut storage)
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
	visitor.visit(transition.keyframe_effect_)
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
	mut progress := (t - transition.transition_start_time()) / (transition.transition_end_time() - transition.transition_start_time())
	// AD-HOC: If the transition has an empty duration then we get NaN here,
	// setting progress to 1 because an instant transition may be considered "finished".
	if transition.transition_start_time() < transition.transition_end_time() {
		progress = 1
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
