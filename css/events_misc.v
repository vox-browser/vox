module css

import dom

// --- AnimationEvent ---

// https://www.w3.org/TR/css-animations-1/#dictdef-animationeventinit
pub struct AnimationEventInit {
	dom.EventInit
pub mut:
	animation_name string
	elapsed_time   f64
	pseudo_element string
}

// https://www.w3.org/TR/css-animations-1/#animationevent
pub struct AnimationEvent {
pub mut:
	event           &dom.Event = unsafe { nil }
	animation_name_ string
	elapsed_time_   f64
	pseudo_element_ string
}

pub fn AnimationEvent.create(type_ string, event_init AnimationEventInit) &AnimationEvent {
	return AnimationEvent.new(type_, event_init)
}

pub fn AnimationEvent.construct_impl(type_ string, event_init AnimationEventInit) !&AnimationEvent {
	return AnimationEvent.create(type_, event_init)
}

pub fn AnimationEvent.new(type_ string, event_init AnimationEventInit) &AnimationEvent {
	return &AnimationEvent{
		event:           dom.Event.new_with_init(type_, event_init.EventInit)
		animation_name_: event_init.animation_name
		elapsed_time_:   event_init.elapsed_time
		pseudo_element_: event_init.pseudo_element
	}
}

pub fn (e AnimationEvent) animation_name() string {
	return e.animation_name_
}

pub fn (e AnimationEvent) elapsed_time() f64 {
	return e.elapsed_time_
}

pub fn (e AnimationEvent) pseudo_element() string {
	return e.pseudo_element_
}

pub fn (mut e AnimationEvent) initialize() {
	// WEB_SET_PROTOTYPE_FOR_INTERFACE(AnimationEvent);
	e.event.initialize()
}

// --- TransitionEvent ---

pub struct TransitionEventInit {
	dom.EventInit
pub mut:
	property_name  string
	elapsed_time   f64
	pseudo_element string
}

pub struct TransitionEvent {
pub mut:
	event           &dom.Event = unsafe { nil }
	property_name_  string
	elapsed_time_   f64
	pseudo_element_ string
}

pub fn TransitionEvent.create(type_ string, event_init TransitionEventInit) &TransitionEvent {
	mut event := TransitionEvent.new(type_, event_init)
	event.event.set_is_trusted(true)
	return event
}

pub fn TransitionEvent.construct_impl(type_ string, event_init TransitionEventInit) &TransitionEvent {
	return TransitionEvent.new(type_, event_init)
}

pub fn TransitionEvent.new(type_ string, event_init TransitionEventInit) &TransitionEvent {
	return &TransitionEvent{
		event:           dom.Event.new_with_init(type_, event_init.EventInit)
		property_name_:  event_init.property_name
		elapsed_time_:   event_init.elapsed_time
		pseudo_element_: event_init.pseudo_element
	}
}

pub fn (e TransitionEvent) property_name() string {
	return e.property_name_
}

pub fn (e TransitionEvent) elapsed_time() f64 {
	return e.elapsed_time_
}

pub fn (e TransitionEvent) pseudo_element() string {
	return e.pseudo_element_
}

pub fn (mut e TransitionEvent) initialize() {
	// WEB_SET_PROTOTYPE_FOR_INTERFACE(TransitionEvent);
	e.event.initialize()
}

// --- MediaQueryListEvent ---

pub struct MediaQueryListEventInit {
	dom.EventInit
pub mut:
	media   string
	matches bool
}

@[heap]
pub struct MediaQueryListEvent {
	dom.Event
pub mut:
	media_   string
	matches_ bool
}

pub fn MediaQueryListEvent.create(event_name string, event_init MediaQueryListEventInit) &MediaQueryListEvent {
	mut event := MediaQueryListEvent.new(event_name, event_init)
	event.set_is_trusted(true)
	return event
}

pub fn MediaQueryListEvent.construct_impl(event_name string, event_init MediaQueryListEventInit) &MediaQueryListEvent {
	return MediaQueryListEvent.new(event_name, event_init)
}

pub fn MediaQueryListEvent.new(event_name string, event_init MediaQueryListEventInit) &MediaQueryListEvent {
	return &MediaQueryListEvent{
		Event: dom.Event{
			interface_: .media_query_list_event
			type_: event_name
			bubbles_: event_init.bubbles
			cancelable_: event_init.cancelable
			composed_: event_init.composed
			initialized_: true
			time_stamp_: dom.current_event_timestamp()
		}
		media_:   event_init.media
		matches_: event_init.matches
	}
}

pub fn (e MediaQueryListEvent) media() string {
	return e.media_
}

pub fn (e MediaQueryListEvent) matches() bool {
	return e.matches_
}

pub fn (mut e MediaQueryListEvent) initialize() {
	// WEB_SET_PROTOTYPE_FOR_INTERFACE(MediaQueryListEvent);
	e.Event.initialize()
}

// --- FontFaceSetLoadEvent ---

// FontFace is the WebIDL interface name. Keep it as an alias so load events
// carry the same translated objects created by the FontFace constructor.
pub type FontFace = FontFaceObject

pub struct FontFaceSetLoadEventInit {
	dom.EventInit
pub mut:
	fontfaces []&FontFace
}

@[heap]
pub struct FontFaceSetLoadEvent {
	dom.Event
pub mut:
	event      &dom.Event = unsafe { nil }
	fontfaces_ []&FontFace
}

pub fn FontFaceSetLoadEvent.create(event_name string, event_init FontFaceSetLoadEventInit) &FontFaceSetLoadEvent {
	return FontFaceSetLoadEvent.new(event_name, event_init)
}

pub fn FontFaceSetLoadEvent.create_with_time_stamp(event_name string, event_init FontFaceSetLoadEventInit, time_stamp f64) &FontFaceSetLoadEvent {
	mut event := FontFaceSetLoadEvent.new(event_name, event_init)
	event.Event.set_time_stamp(time_stamp)
	return event
}

pub fn FontFaceSetLoadEvent.create_for_fonts(event_name string, fontfaces []&FontFaceObject, time_stamp f64) &FontFaceSetLoadEvent {
	return FontFaceSetLoadEvent.create_with_time_stamp(event_name, FontFaceSetLoadEventInit{fontfaces: fontfaces}, time_stamp)
}

// https://drafts.csswg.org/css-font-loading/#dom-fontfacesetloadevent-fontfacesetloadevent
pub fn FontFaceSetLoadEvent.construct_impl(event_name string, event_init FontFaceSetLoadEventInit) !&FontFaceSetLoadEvent {
	return FontFaceSetLoadEvent.create(event_name, event_init)
}

pub fn FontFaceSetLoadEvent.new(event_name string, event_init FontFaceSetLoadEventInit) &FontFaceSetLoadEvent {
	mut fontfaces := []&FontFace{cap: event_init.fontfaces.len}
	for font_face in event_init.fontfaces {
		if unsafe { font_face == nil } {
			panic('VERIFY_NOT_REACHED')
		}
		fontfaces << font_face
	}
	mut event := &FontFaceSetLoadEvent{
		Event:      *dom.Event.new_with_init(event_name, event_init.EventInit)
		fontfaces_: fontfaces
	}
	event.Event.interface_ = .font_face_set_load_event
	event.event = unsafe { &dom.Event(event) }
	return event
}

pub fn (e FontFaceSetLoadEvent) fontfaces() []&FontFace {
	return e.fontfaces_
}

pub fn (mut e FontFaceSetLoadEvent) initialize() {
	// WEB_SET_PROTOTYPE_FOR_INTERFACE(FontFaceSetLoadEvent);
	e.event.initialize()
}

pub fn (mut e FontFaceSetLoadEvent) visit_edges(mut visitor dom.CellVisitor) {
	e.event.visit_edges(mut visitor)
	for face in e.fontfaces_ { visitor.visit(face) }
}

// --- StyleProperty ---

pub enum Important {
	no
	yes
}

pub struct StyleProperty {
pub mut:
	important   Important = .no
	property_id PropertyID
	value       &dom.StyleValue = unsafe { nil }
}

pub fn (p StyleProperty) equals(other StyleProperty) bool {
	if p.important != other.important || p.property_id != other.property_id {
		return false
	}
	return p.value == other.value
}

pub struct StylePropertyAndName {
pub mut:
	property StyleProperty
	name     string
}

// --- Descriptor ---

pub enum DescriptorID {
	unknown
	custom
	result
	margin
	margin_top
	margin_right
	margin_bottom
	margin_left
	size
	page_orientation
	marks
	bleed
}

pub struct DescriptorNameAndID {
pub:
	name_ string
	id_   DescriptorID
}

pub fn DescriptorNameAndID.from_name(at_rule_id AtRuleID, name string) ?DescriptorNameAndID {
	if is_a_custom_property_name_string(name) {
		return DescriptorNameAndID{
			name_: name
			id_: .custom
		}
	}

	descriptor_id := descriptor_id_from_string(at_rule_id, name) or { return none }
	return DescriptorNameAndID.from_id(descriptor_id)
}

pub fn DescriptorNameAndID.from_id(descriptor_id DescriptorID) DescriptorNameAndID {
	assert descriptor_id != .custom
	return DescriptorNameAndID{
		name_: descriptor_id_to_string(descriptor_id)
		id_: descriptor_id
	}
}

pub fn (descriptor DescriptorNameAndID) id() DescriptorID {
	return descriptor.id_
}

pub fn (descriptor DescriptorNameAndID) name() string {
	return descriptor.name_
}

pub struct Descriptor {
pub mut:
	descriptor_name_and_id DescriptorNameAndID
	value                  &dom.StyleValue = unsafe { nil }
	serialized_value       string
}

// --- PageSelector ---

pub enum PagePseudoClass {
	left
	right
	first
	blank
}

pub fn page_pseudo_class_from_string(input string) ?PagePseudoClass {
	lower_input := input.to_lower()
	if lower_input == 'blank' {
		return .blank
	}
	if lower_input == 'first' {
		return .first
	}
	if lower_input == 'left' {
		return .left
	}
	if lower_input == 'right' {
		return .right
	}
	return none
}

pub fn page_pseudo_class_to_string(pseudo_class PagePseudoClass) string {
	return match pseudo_class {
		.blank { 'blank' }
		.first { 'first' }
		.left { 'left' }
		.right { 'right' }
	}
}

pub struct PageSelector {
pub mut:
	name_           ?string
	pseudo_classes_ []PagePseudoClass
}

pub type PageSelectorList = []PageSelector

pub fn PageSelector.new(name ?string, pseudo_classes []PagePseudoClass) PageSelector {
	return PageSelector{
		name_:           name
		pseudo_classes_: pseudo_classes
	}
}

pub fn (p PageSelector) name() ?string {
	return p.name_
}

pub fn (p PageSelector) pseudo_classes() []PagePseudoClass {
	return p.pseudo_classes_
}

pub fn (p PageSelector) serialize() string {
	mut serialized := ''
	if name := p.name_ {
		serialized += name
	}
	for pseudo_class in p.pseudo_classes_ {
		serialized += ':${page_pseudo_class_to_string(pseudo_class)}'
	}
	return serialized
}

// --- StyleSheetIdentifier ---

pub enum StyleSheetIdentifierType {
	style_element
	link_element
	import_rule
	user_agent
	user_style
}

pub struct StyleSheetIdentifier {
pub mut:
	type_                 StyleSheetIdentifierType
	dom_element_unique_id ?u64
	url                   ?string
	rule_count            uint
}

pub fn (s StyleSheetIdentifier) equals(other StyleSheetIdentifier) bool {
	return s.type_ == other.type_ && s.dom_element_unique_id == other.dom_element_unique_id
		&& s.url == other.url
}

pub fn style_sheet_identifier_type_to_string(type_ StyleSheetIdentifierType) string {
	return match type_ {
		.style_element { 'StyleElement' }
		.link_element { 'LinkElement' }
		.import_rule { 'ImportRule' }
		.user_agent { 'UserAgent' }
		.user_style { 'UserStyle' }
	}
}

pub fn style_sheet_identifier_type_from_string(string_ string) ?StyleSheetIdentifierType {
	if string_ == 'StyleElement' {
		return .style_element
	}
	if string_ == 'LinkElement' {
		return .link_element
	}
	if string_ == 'ImportRule' {
		return .import_rule
	}
	if string_ == 'UserAgent' {
		return .user_agent
	}
	if string_ == 'UserStyle' {
		return .user_style
	}
	return none
}
