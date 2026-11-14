module css

import dom
import strconv
import strings

// This file ports the LibWeb/CSS selector data model and selector-engine logic.
const selector_ancestor_hash_count = 8
const selector_unbounded_sibling_invalidation_distance = int(0x3fffffff)
const selector_html_namespace = 'http://www.w3.org/1999/xhtml'

// This is a <complex-selector> in the spec. https://www.w3.org/TR/selectors-4/#complex
pub enum SelectorKind {
	normal
	relative
}

pub enum HasMatchResult {
	matched
	not_matched
}

@[heap]
pub struct HasResultCache {
pub mut:
	results map[string]HasMatchResult
	attempted_pseudo_classes map[string]PseudoClassBitmap
mut:
	observed_arguments_ map[u64]ObservedHasAnchor
	rechecking_arguments_ bool
}

pub struct MatchContext {
pub mut:
	style_sheet_for_rule                              ?&CSSStyleSheet
	subject                                           ?&dom.Element
	pseudo_argument                                   string
	slotted_element                                   ?&dom.Element // Only set when matching a ::slotted() pseudo-element
	part_owning_parent                                ?&dom.Element // Only set temporarily when matching a ::part() pseudo-element
	rule_shadow_root                                  ?&dom.ShadowRoot // Shadow root the matched rule belongs to
	for_host_part_matching                            bool
	collect_per_element_selector_involvement_metadata bool
	inside_has_argument_match                         bool
	attempted_pseudo_class_matches                    PseudoClassBitmap
	has_result_cache                                  &HasResultCache = &HasResultCache{}
}

pub enum PseudoClass {
	invalid
	link
	any_link
	local_link
	visited
	active
	hover
	focus
	focus_visible
	focus_within
	fullscreen
	first_child
	last_child
	only_child
	empty
	root
	host
	scope
	first_of_type
	last_of_type
	only_of_type
	lang
	disabled
	enabled
	checked
	unchecked
	indeterminate
	high_value
	low_value
	optimal_value
	suboptimal_value
	even_less_good_value
	defined
	has
	is_
	where
	not_
	nth_child
	nth_last_child
	nth_of_type
	nth_last_of_type
	playing
	paused
	seeking
	muted
	volume_locked
	buffering
	stalled
	target
	dir
	read_only
	read_write
	placeholder_shown
	open
	closed
	modal
	popover_open
	valid
	invalid_state
	user_valid
	user_invalid
	required
	optional
	default_
	autofill
	state
	heading
	current_
}

pub struct PseudoClassBitmap {
pub mut:
	words [2]u64
}

pub fn (bitmap PseudoClassBitmap) get(pseudo_class PseudoClass) bool {
	index := int(pseudo_class)
	return bitmap.words[index / 64] & (u64(1) << (index % 64)) != 0
}

pub fn (mut bitmap PseudoClassBitmap) set(pseudo_class PseudoClass, value bool) {
	index := int(pseudo_class)
	mask := u64(1) << (index % 64)
	if value {
		bitmap.words[index / 64] |= mask
	} else {
		bitmap.words[index / 64] &= ~mask
	}
}

pub fn (mut bitmap PseudoClassBitmap) merge(other PseudoClassBitmap) {
	for index in 0 .. bitmap.words.len {
		bitmap.words[index] |= other.words[index]
	}
}

pub enum PseudoElement {
	after
	backdrop
	before
	details_content
	file_selector_button
	first_letter
	first_line
	marker
	part
	placeholder
	selection
	slider_fill
	slider_thumb
	slider_track
	slotted
	view_transition
	view_transition_group
	view_transition_image_pair
	view_transition_new
	view_transition_old
	highlight
	color_swatch
	webkit_color_swatch_wrapper
	target_text
	spelling_error
	grammar_error
	search_text
	cue
	known_pseudo_element_count
	unknown_webkit
	// V uses a sentinel where C++'s pseudo_element_from_string() returns Optional{}.
	unknown
}

pub fn is_known_pseudo_element_type(pseudo_element PseudoElement) bool {
	return pseudo_element != .known_pseudo_element_count && pseudo_element != .unknown_webkit
		&& pseudo_element != .unknown
}

pub fn is_has_allowed_pseudo_element(pseudo_element PseudoElement) bool {
	_ = pseudo_element
	// Generated from PseudoElements.json: no current pseudo-element is allowed in :has().
	return false
}

pub fn is_pseudo_element_root(pseudo_element PseudoElement) bool {
	return pseudo_element == .view_transition
}

pub fn selector_pseudo_class_name(pseudo_class PseudoClass) string {
	return match pseudo_class {
		.invalid { '' }
		.link { 'link' }
		.any_link { 'any-link' }
		.local_link { 'local-link' }
		.visited { 'visited' }
		.active { 'active' }
		.hover { 'hover' }
		.focus { 'focus' }
		.focus_visible { 'focus-visible' }
		.focus_within { 'focus-within' }
		.fullscreen { 'fullscreen' }
		.first_child { 'first-child' }
		.last_child { 'last-child' }
		.only_child { 'only-child' }
		.empty { 'empty' }
		.root { 'root' }
		.host { 'host' }
		.scope { 'scope' }
		.first_of_type { 'first-of-type' }
		.last_of_type { 'last-of-type' }
		.only_of_type { 'only-of-type' }
		.lang { 'lang' }
		.disabled { 'disabled' }
		.enabled { 'enabled' }
		.checked { 'checked' }
		.unchecked { 'unchecked' }
		.indeterminate { 'indeterminate' }
		.high_value { 'high-value' }
		.low_value { 'low-value' }
		.optimal_value { 'optimal-value' }
		.suboptimal_value { 'suboptimal-value' }
		.even_less_good_value { 'even-less-good-value' }
		.defined { 'defined' }
		.has { 'has' }
		.is_ { 'is' }
		.where { 'where' }
		.not_ { 'not' }
		.nth_child { 'nth-child' }
		.nth_last_child { 'nth-last-child' }
		.nth_of_type { 'nth-of-type' }
		.nth_last_of_type { 'nth-last-of-type' }
		.playing { 'playing' }
		.paused { 'paused' }
		.seeking { 'seeking' }
		.muted { 'muted' }
		.volume_locked { 'volume-locked' }
		.buffering { 'buffering' }
		.stalled { 'stalled' }
		.target { 'target' }
		.dir { 'dir' }
		.read_only { 'read-only' }
		.read_write { 'read-write' }
		.placeholder_shown { 'placeholder-shown' }
		.open { 'open' }
		.closed { 'closed' }
		.modal { 'modal' }
		.popover_open { 'popover-open' }
		.valid { 'valid' }
		.invalid_state { 'invalid' }
		.user_valid { 'user-valid' }
		.user_invalid { 'user-invalid' }
		.required { 'required' }
		.optional { 'optional' }
		.default_ { 'default' }
		.autofill { 'autofill' }
		.state { 'state' }
		.heading { 'heading' }
		.current_ { 'current' }
	}
}

pub fn pseudo_class_from_string(name string) PseudoClass {
	return match name.to_lower() {
		'link' { .link }
		'any-link', '-webkit-any-link' { .any_link }
		'local-link' { .local_link }
		'visited' { .visited }
		'active' { .active }
		'hover' { .hover }
		'focus' { .focus }
		'focus-visible' { .focus_visible }
		'focus-within' { .focus_within }
		'fullscreen' { .fullscreen }
		'first-child' { .first_child }
		'last-child' { .last_child }
		'only-child' { .only_child }
		'empty' { .empty }
		'root' { .root }
		'host' { .host }
		'scope' { .scope }
		'first-of-type' { .first_of_type }
		'last-of-type' { .last_of_type }
		'only-of-type' { .only_of_type }
		'lang' { .lang }
		'disabled' { .disabled }
		'enabled' { .enabled }
		'checked' { .checked }
		'unchecked' { .unchecked }
		'indeterminate' { .indeterminate }
		'high-value' { .high_value }
		'low-value' { .low_value }
		'optimal-value' { .optimal_value }
		'suboptimal-value' { .suboptimal_value }
		'even-less-good-value' { .even_less_good_value }
		'defined' { .defined }
		'has' { .has }
		'is' { .is_ }
		'where' { .where }
		'not' { .not_ }
		'nth-child' { .nth_child }
		'nth-last-child' { .nth_last_child }
		'nth-of-type' { .nth_of_type }
		'nth-last-of-type' { .nth_last_of_type }
		'playing' { .playing }
		'paused' { .paused }
		'seeking' { .seeking }
		'muted' { .muted }
		'volume-locked' { .volume_locked }
		'buffering' { .buffering }
		'stalled' { .stalled }
		'target' { .target }
		'dir' { .dir }
		'read-only' { .read_only }
		'read-write' { .read_write }
		'placeholder-shown' { .placeholder_shown }
		'open' { .open }
		'closed' { .closed }
		'modal' { .modal }
		'popover-open' { .popover_open }
		'valid' { .valid }
		'invalid' { .invalid_state }
		'user-valid' { .user_valid }
		'user-invalid' { .user_invalid }
		'required' { .required }
		'optional' { .optional }
		'default' { .default_ }
		'autofill', '-webkit-autofill' { .autofill }
		'state' { .state }
		'heading' { .heading }
		'current' { .current_ }
		else { .invalid }
	}
}

pub fn pseudo_element_name(pseudo_element PseudoElement) string {
	return match pseudo_element {
		.after { 'after' }
		.backdrop { 'backdrop' }
		.before { 'before' }
		.details_content { 'details-content' }
		.file_selector_button { 'file-selector-button' }
		.first_letter { 'first-letter' }
		.first_line { 'first-line' }
		.marker { 'marker' }
		.part { 'part' }
		.placeholder { 'placeholder' }
		.selection { 'selection' }
		.slider_fill { 'slider-fill' }
		.slider_thumb { 'slider-thumb' }
		.slider_track { 'slider-track' }
		.slotted { 'slotted' }
		.view_transition { 'view-transition' }
		.view_transition_group { 'view-transition-group' }
		.view_transition_image_pair { 'view-transition-image-pair' }
		.view_transition_new { 'view-transition-new' }
		.view_transition_old { 'view-transition-old' }
		.highlight { 'highlight' }
		.color_swatch { 'color-swatch' }
		.webkit_color_swatch_wrapper { '-webkit-color-swatch-wrapper' }
		.target_text { 'target-text' }
		.spelling_error { 'spelling-error' }
		.grammar_error { 'grammar-error' }
		.search_text { 'search-text' }
		.cue { 'cue' }
		.known_pseudo_element_count, .unknown { '' }
		.unknown_webkit { '-webkit-unknown' }
	}
}

pub fn pseudo_element_from_string(name string) PseudoElement {
	return match name.to_lower() {
		'target-text' { .target_text }
		'spelling-error' { .spelling_error }
		'grammar-error' { .grammar_error }
		'search-text' { .search_text }
		'cue' { .cue }
		'highlight' { .highlight }
		'color-swatch' { .color_swatch }
		'-webkit-color-swatch-wrapper' { .webkit_color_swatch_wrapper }
		'after' {
			.after
		}
		'backdrop' {
			.backdrop
		}
		'before' {
			.before
		}
		'details-content' {
			.details_content
		}
		'file-selector-button' {
			.file_selector_button
		}
		'first-letter' {
			.first_letter
		}
		'first-line' {
			.first_line
		}
		'marker' {
			.marker
		}
		'part' {
			.part
		}
		'placeholder' {
			.placeholder
		}
		'selection' {
			.selection
		}
		'slider-fill' {
			.slider_fill
		}
		'slider-thumb' {
			.slider_thumb
		}
		'slider-track' {
			.slider_track
		}
		'slotted' {
			.slotted
		}
		'view-transition' {
			.view_transition
		}
		'view-transition-group' {
			.view_transition_group
		}
		'view-transition-image-pair' {
			.view_transition_image_pair
		}
		'view-transition-new' {
			.view_transition_new
		}
		'view-transition-old' {
			.view_transition_old
		}
		else {
			aliased := aliased_pseudo_element_from_string(name)
			if aliased != .unknown {
				aliased
			} else if name.to_lower().starts_with('-webkit-') {
				PseudoElement.unknown_webkit
			} else {
				PseudoElement.unknown
			}
		}
	}
}

// The legacy aliases generated from PseudoElements.json, kept apart from the
// canonical names as `aliased_pseudo_element_from_string()` is upstream:
// Parser::parse_pseudo_element_selector() consults the canonical table first and
// only then this one, because an aliased pseudo-element keeps its authored
// spelling when it serializes while a canonical one does not.
pub fn aliased_pseudo_element_from_string(name string) PseudoElement {
	return match name.to_lower() {
		'-moz-color-swatch', '-webkit-color-swatch' {
			.color_swatch
		}
		'-moz-meter-bar', '-moz-progress-bar', '-moz-range-progress', '-webkit-progress-value' {
			.slider_fill
		}
		'-moz-range-thumb', '-webkit-slider-thumb' {
			.slider_thumb
		}
		'-moz-range-track', '-webkit-meter-bar', '-webkit-progress-bar', '-webkit-slider-runnable-track' {
			.slider_track
		}
		'-moz-placeholder', '-webkit-input-placeholder' {
			.placeholder
		}
		else {
			.unknown
		}
	}
}

pub struct PseudoElementPTNameSelector {
pub mut:
	is_universal bool
	value        string
}

pub enum PseudoElementSelectorValueKind {
	empty
	pt_name_selector
	compound_selector
	ident_list
}

pub struct PseudoElementSelector {
pub mut:
	type_             PseudoElement
	name              string
	value_kind        PseudoElementSelectorValueKind
	pt_name_selector  PseudoElementPTNameSelector
	compound_selector ?Selector
	ident_list        []string
}

pub fn PseudoElementSelector.new(type_ PseudoElement) PseudoElementSelector {
	return PseudoElementSelector{
		type_: type_
	}
}

pub fn (selector PseudoElementSelector) serialize() string {
	mut builder := strings.new_builder(16)
	builder.write_string('::')

	if selector.name.len != 0 {
		builder.write_string(selector.name)
	} else {
		builder.write_string(pseudo_element_name(selector.type_))
	}

	match selector.value_kind {
		.empty {}
		.compound_selector {
			if compound_selector := selector.compound_selector {
				builder.write_u8(`(`)
				builder.write_string(compound_selector.serialize())
				builder.write_u8(`)`)
			}
		}
		.pt_name_selector {
			builder.write_u8(`(`)
			if selector.pt_name_selector.is_universal {
				builder.write_u8(`*`)
			} else {
				builder.write_string(selector.pt_name_selector.value)
			}
			builder.write_u8(`)`)
		}
		.ident_list {
			builder.write_u8(`(`)
			for index, ident in selector.ident_list {
				if index != 0 {
					builder.write_u8(` `)
				}
				builder.write_string(serialize_an_identifier(ident))
			}
			builder.write_u8(`)`)
		}
	}

	return builder.str()
}

pub enum SimpleSelectorType {
	universal
	tag_name
	id
	class
	attribute
	pseudo_class
	pseudo_element
	nesting
	invalid
}

// https://drafts.csswg.org/css-syntax-3/#anb-microsyntax
pub struct ANPlusBPattern {
pub mut:
	step_size int // "A"
	offset    int // "B"
}

pub fn (pattern ANPlusBPattern) matches(index int) bool {
	// "If both a and b are equal to zero, the pseudo-class represents no element in the document tree."
	if pattern.step_size == 0 && pattern.offset == 0 {
		return false
	}

	// When "step_size == -1", selector represents first "offset" elements in document tree.
	if pattern.step_size == -1 {
		return !(pattern.offset <= 0 || index > pattern.offset)
	}

	// When "step_size == 1", selector represents last "offset" elements in document tree.
	if pattern.step_size == 1 {
		return !(pattern.offset < 0 || index < pattern.offset)
	}

	// When "step_size == 0", selector picks only the "offset" element.
	if pattern.step_size == 0 {
		return index == pattern.offset
	}

	// If both are negative, nothing can match.
	if pattern.step_size < 0 && pattern.offset < 0 {
		return false
	}

	// Like "a % b", but handles negative integers correctly.
	canonical_modulo := fn (a int, b int) int {
		mut c := a % b
		if (c < 0 && b > 0) || (c > 0 && b < 0) {
			c += b
		}
		return c
	}

	// When "step_size < 0", we start at "offset" and count backwards.
	if pattern.step_size < 0 {
		return index <= pattern.offset && canonical_modulo(index - pattern.offset, -pattern.step_size) == 0
	}

	// Otherwise, we start at "offset" and count forwards.
	return index >= pattern.offset && canonical_modulo(index - pattern.offset, pattern.step_size) == 0
}

// https://drafts.csswg.org/css-syntax-3/#serializing-anb
pub fn (pattern ANPlusBPattern) serialize() string {
	// 1. If A is zero, return the serialization of B.
	if pattern.step_size == 0 {
		return pattern.offset.str()
	}

	// 2. Otherwise, let result initially be an empty string.
	mut result := strings.new_builder(8)

	// 3.
	// - A is 1: Append "n" to result.
	if pattern.step_size == 1 {
		result.write_u8(`n`)
		// - A is -1: Append "-n" to result.
	} else if pattern.step_size == -1 {
		result.write_string('-n')
		// - A is non-zero: Serialize A and append it to result, then append "n" to result.
	} else if pattern.step_size != 0 {
		result.write_string('${pattern.step_size}n')
	}

	// 4.
	// - B is greater than zero: Append "+" to result, then append the serialization of B to result.
	if pattern.offset > 0 {
		result.write_string('+${pattern.offset}')
		// - B is less than zero: Append the serialization of B to result.
	} else if pattern.offset < 0 {
		result.write_string('${pattern.offset}')
	}

	// 5. Return result.
	return result.str()
}

pub enum DirectionKeyword {
	invalid
	ltr
	rtl
}

pub struct PseudoClassIdent {
pub mut:
	keyword      DirectionKeyword
	string_value string
}

pub struct PseudoClassSelector {
pub mut:
	type_ PseudoClass

	// Used for the :nth-*() pseudo-classes
	an_plus_b_pattern ANPlusBPattern

	// FIXME: This would make more sense as part of SelectorList but that's currently a `using`
	is_forgiving           bool
	argument_selector_list SelectorList

	// Used for :lang(en-gb,dk)
	languages []string

	// Used by :dir()
	ident ?PseudoClassIdent

	// Used by :heading()
	levels []i64
}

pub struct SelectorName {
pub mut:
	name           string
	lowercase_name string
}

pub fn SelectorName.new(name string) SelectorName {
	return SelectorName{
		name: name
		lowercase_name: name.to_lower()
	}
}

// Equivalent to `<wq-name>`
// https://www.w3.org/TR/selectors-4/#typedef-wq-name
pub enum QualifiedNameNamespaceType {
	default_ // `E`
	none // `|E`
	any // `*|E`
	named // `ns|E`
}

pub struct SelectorQualifiedName {
pub mut:
	namespace_type QualifiedNameNamespaceType = .default_
	namespace_     string
	name           SelectorName
}

pub enum AttributeMatchType {
	has_attribute
	exact_value_match
	contains_word // [att~=val]
	contains_string // [att*=val]
	starts_with_segment // [att|=val]
	starts_with_string // [att^=val]
	ends_with_string // [att$=val]
}

pub enum AttributeCaseType {
	default_match
	case_sensitive_match
	case_insensitive_match
}

pub struct SelectorAttribute {
pub mut:
	match_type     AttributeMatchType
	qualified_name SelectorQualifiedName
	value          string
	case_type      AttributeCaseType
}

// The payload tag is independent of the public selector kind: changing type_
// must keep the same inactive values that an ordinary V record copy retained.
pub struct SimpleSelector {
pub mut:
 type_ SimpleSelectorType
mut:
 payload_kind_ SimpleSelectorPayloadKind
 payload_ SimpleSelectorPayload
}

// https://www.w3.org/TR/cssom/#serialize-a-simple-selector
pub fn (simple_selector SimpleSelector) serialize() string {
	mut s := strings.new_builder(16)
	match simple_selector.type_ {
		.tag_name, .universal {
			qualified_name := simple_selector.qualified_name()
			// 1. If the namespace prefix maps to a namespace that is not the default namespace and is not the null
			//    namespace (not in a namespace) append the serialization of the namespace prefix as an identifier,
			//    followed by a "|" (U+007C) to s.
			if qualified_name.namespace_type == .named {
				s.write_string(serialize_an_identifier(qualified_name.namespace_))
				s.write_u8(`|`)
			}

			// 2. If the namespace prefix maps to a namespace that is the null namespace (not in a namespace)
			//    append "|" (U+007C) to s.
			// NOTE: Unlike an attribute selector, the any-namespace prefix is not
			//       serialized here; `*|div` serializes as `div` and `*|*` as `*`.
			if qualified_name.namespace_type == .none {
				s.write_u8(`|`)
			}

			// 3. If this is a type selector append the serialization of the element name as an identifier to s.
			if simple_selector.type_ == .tag_name {
				s.write_string(serialize_an_identifier(qualified_name.name.name))
			}

			// 4. If this is a universal selector append "*" (U+002A) to s.
			if simple_selector.type_ == .universal {
				s.write_u8(`*`)
			}
		}
		.attribute {
			attribute := simple_selector.attribute()

			// 1. Append "[" (U+005B) to s.
			s.write_u8(`[`)

			// 2. If the namespace prefix maps to a namespace that is not the null namespace (not in a namespace)
			//    append the serialization of the namespace prefix as an identifier, followed by a "|" (U+007C) to s.
			if attribute.qualified_name.namespace_type == .named {
				s.write_string(serialize_an_identifier(attribute.qualified_name.namespace_))
				s.write_u8(`|`)
			} else if attribute.qualified_name.namespace_type == .any {
				s.write_string('*|')
			}

			// 3. Append the serialization of the attribute name as an identifier to s.
			s.write_string(serialize_an_identifier(attribute.qualified_name.name.name))

			// 4. If there is an attribute value specified, append "=", "~=", "|=", "^=", "$=", or "*=" as appropriate (depending on the type of attribute selector),
			//    followed by the serialization of the attribute value as a string, to s.
			if attribute.value.len != 0 || attribute.match_type != .has_attribute {
				match attribute.match_type {
					.exact_value_match { s.write_u8(`=`) }
					.contains_word { s.write_string('~=') }
					.contains_string { s.write_string('*=') }
					.starts_with_segment { s.write_string('|=') }
					.starts_with_string { s.write_string('^=') }
					.ends_with_string { s.write_string('\$=') }
					.has_attribute {}
				}

				s.write_string(serialize_a_string(attribute.value))
			}

			// 5. If the attribute selector has the case-insensitivity flag present, append " i" (U+0020 U+0069) to s.
			//    If the attribute selector has the case-insensitivity flag present, append " s" (U+0020 U+0073) to s.
			//    (the line just above is an addition to CSS OM to match Selectors Level 4 last draft)
			match attribute.case_type {
				.case_insensitive_match { s.write_string(' i') }
				.case_sensitive_match { s.write_string(' s') }
				.default_match {}
			}

			// 6. Append "]" (U+005D) to s.
			s.write_u8(`]`)
		}
		.class {
			// Append a "." (U+002E), followed by the serialization of the class name as an identifier to s.
			s.write_u8(`.`)
			s.write_string(serialize_an_identifier(simple_selector.name().name))
		}
		.id {
			// Append a "#" (U+0023), followed by the serialization of the ID as an identifier to s.
			s.write_u8(`#`)
			s.write_string(serialize_an_identifier(simple_selector.name().name))
		}
		.pseudo_class {
			pseudo_class := simple_selector.pseudo_class()
			name := selector_pseudo_class_name(pseudo_class.type_)
			accepts_arguments := pseudo_class_accepts_arguments(pseudo_class)

			// If the pseudo-class does not accept arguments append ":" (U+003A), followed by the name of the pseudo-class, to s.
			if !accepts_arguments {
				s.write_u8(`:`)
				s.write_string(name)
			} else {
				// Otherwise, append ":" (U+003A), followed by the name of the pseudo-class, followed by "(" (U+0028),
				// followed by the value of the pseudo-class argument(s) determined as per below, followed by ")" (U+0029), to s.
				s.write_u8(`:`)
				s.write_string(name)
				s.write_u8(`(`)
				match pseudo_class.type_ {
					.nth_child, .nth_last_child, .nth_of_type, .nth_last_of_type {
						// Both the ANPlusB and ANPlusBOf parameter types serialize as
						// "the result of serializing the value using the rules to
						// serialize an <an+b> value" - the `of S` part is dropped.
						s.write_string(pseudo_class.an_plus_b_pattern.serialize())
					}
					.has, .host, .is_, .where, .not_ {
						s.write_string(serialize_a_group_of_selectors(pseudo_class.argument_selector_list))
					}
					.dir, .state {
						if ident := pseudo_class.ident {
							s.write_string(serialize_an_identifier(ident.string_value))
						}
					}
					.lang {
						s.write_string(pseudo_class.languages.join(', '))
					}
					.heading {
						mut level_strings := []string{}
						for level in pseudo_class.levels {
							level_strings << level.str()
						}
						s.write_string(level_strings.join(', '))
					}
					else {}
				}

				s.write_u8(`)`)
			}
		}
		.pseudo_element {
			// AD-HOC: Spec issue: https://github.com/w3c/csswg-drafts/issues/11997
			s.write_string(simple_selector.pseudo_element().serialize())
		}
		.nesting {
			// AD-HOC: Not in spec yet.
			s.write_u8(`&`)
		}
		.invalid {
			// AD-HOC: We're not told how to do these. Just serialize their component values.
			s.write_string(simple_selector.invalid_text())
		}
	}

	return s.str()
}

pub fn (simple_selector SimpleSelector) absolutized(selector_for_nesting SimpleSelector) ?SimpleSelector {
	match simple_selector.type_ {
		.nesting {
			// Nesting selectors get replaced directly.
			return selector_for_nesting
		}
		.pseudo_class {
			// Pseudo-classes may contain other selectors, so we need to absolutize them.
			// Copy the PseudoClassSelector, and then replace its argument selector list.
			mut pseudo_class := simple_selector.pseudo_class()
			if pseudo_class.argument_selector_list.selectors.len != 0 {
				mut new_selector_list := SelectorList{}
				for argument_selector in pseudo_class.argument_selector_list.selectors {
					if absolutized := argument_selector.absolutized(selector_for_nesting) {
						new_selector_list.selectors << absolutized
					} else if !pseudo_class.is_forgiving {
						return none
					}
				}
				pseudo_class.argument_selector_list = new_selector_list
			}

			// :has() has special validity rules
			if pseudo_class.type_ == .has {
				for selector in pseudo_class.argument_selector_list.selectors {
					if contains_invalid_contents_for_has(selector) {
						return none
					}
				}
			}

			mut result := simple_selector
			result.set_pseudo_class(pseudo_class)
			return result
		}
		else {
			// Everything else isn't affected
			return simple_selector
		}
	}
}

pub enum Combinator {
	no_combinator
	immediate_child // >
	descendant // <whitespace>
	next_sibling // +
	subsequent_sibling // ~
	column // ||
}

pub struct CompoundSelector {

	// Spec-wise, the <combinator> is not part of a <compound-selector>,
	// but it is more understandable to put them together.
pub mut:
	combinator       Combinator
	simple_selectors []SimpleSelector
}

// C++ Selector is RefCounted and SelectorList stores NonnullRefPtr<Selector>.
// Keep the recursive selector graph behind one shared allocation as well; a
// by-value graph makes every Selector copy recursively retain/copy its arrays.
pub struct SelectorData {
pub mut:
	repeated_rule_parse            bool
	text                          string
	compound_selectors            []CompoundSelector
	specificity                   ?u32
	pseudo_element                ?PseudoElementSelector
	sibling_invalidation_distance ?int
	can_use_fast_matches          bool
	can_use_ancestor_filter       bool
	contains_the_nesting_selector bool
	contains_part_pseudo_element  bool
	contained_pseudo_classes      PseudoClassBitmap
	ancestor_hashes               [8]u32
}

// Kept as traversal entry points for the declared-value fallback cache. Parsed
// selectors themselves are retained by Selector, matching C++ Selector's typed
// ComplexSelector storage.
pub fn begin_selector_parse_cache() {
	begin_parsed_value_cache()
}

pub fn end_selector_parse_cache() {
	end_parsed_value_cache()
}

pub fn selector_from_text(text string) Selector {
	return parse_owned_selector(text)
}

// Recursive parser calls stay in the outer construction workspace. Only the
// public entry point publishes its completed graph into the caller's owner.
fn selector_from_text_impl(text string) Selector {
	return create_selector(text, parse_complex_selector(text))
}

fn selector_from_compound_selectors(compound_selectors []CompoundSelector) Selector {
	return create_selector(serialize_compound_selectors_raw(compound_selectors), compound_selectors.clone())
}

fn create_selector(text string, compound_selectors []CompoundSelector) Selector {
	mut data := &SelectorData{
		text: text
		compound_selectors: compound_selectors
	}
	selector := Selector{
		data_: data
	}

	// Selector::Selector computes these once in C++. Matching then reads the
	// cached metadata through the selector's RefPtr rather than traversing the
	// selector graph again for every candidate element.
	data.pseudo_element = selector_pseudo_element_uncached(compound_selectors)
	data.contains_part_pseudo_element = selector_contains_part_pseudo_element_uncached(compound_selectors)
	data.contains_the_nesting_selector = selector_contains_nesting_uncached(compound_selectors)
	data.contained_pseudo_classes = selector_contained_pseudo_classes_uncached(compound_selectors)
	data.can_use_fast_matches = can_selector_use_fast_matches(selector)
	ancestor_hashes, can_use_ancestor_filter := selector_ancestor_hashes(selector)
	data.ancestor_hashes = ancestor_hashes
	data.can_use_ancestor_filter = can_use_ancestor_filter
	return selector
}

pub fn (compound_selector CompoundSelector) absolutized(selector_for_nesting SimpleSelector) ?CompoundSelector {
	// TODO: Cache if it contains the nesting selector?
	mut absolutized_simple_selectors := []SimpleSelector{cap: compound_selector.simple_selectors.len}
	for simple_selector in compound_selector.simple_selectors {
		if absolutized := simple_selector.absolutized(selector_for_nesting) {
			absolutized_simple_selectors << absolutized
		} else {
			return none
		}
	}

	return CompoundSelector{
		combinator: compound_selector.combinator
		simple_selectors: absolutized_simple_selectors
	}
}

pub fn (selector Selector) compound_selectors() []CompoundSelector {
	if selector.data_ != unsafe { nil } {
		return selector.data_.compound_selectors
	}
	return []CompoundSelector{}
}

pub fn (selector Selector) text() string {
	if selector.data_ == unsafe { nil } {
		return ''
	}
	return selector.data_.text
}

pub fn (selector Selector) contains_the_nesting_selector() bool {
	if selector.data_ != unsafe { nil } {
		return selector.data_.contains_the_nesting_selector
	}
	return selector_contains_nesting_uncached(selector.compound_selectors())
}

fn selector_contains_nesting_uncached(compound_selectors []CompoundSelector) bool {
	for compound_selector in compound_selectors {
		for simple_selector in compound_selector.simple_selectors {
			if simple_selector.type_ == .nesting {
				return true
			}
			if simple_selector.type_ == .pseudo_class {
				for child_selector in simple_selector.pseudo_class().argument_selector_list.selectors {
					if child_selector.contains_the_nesting_selector() {
						return true
					}
				}
			}
			if simple_selector.type_ == .pseudo_element {
				if child_selector := simple_selector.pseudo_element().compound_selector {
					if child_selector.contains_the_nesting_selector() {
						return true
					}
				}
			}
		}
	}
	return false
}

pub fn (selector Selector) pseudo_element() ?PseudoElementSelector {
	if selector.data_ != unsafe { nil } {
		return selector.data_.pseudo_element
	}
	return selector_pseudo_element_uncached(selector.compound_selectors())
}

// The target pseudo-element is the rightmost pseudo-element selected by this
// selector. Keep the upstream name at rule-filtering call sites while the
// existing pseudo_element() accessor remains available to older V callers.
pub fn (selector Selector) target_pseudo_element() ?PseudoElementSelector {
	return selector.pseudo_element()
}

fn selector_pseudo_element_uncached(compound_selectors []CompoundSelector) ?PseudoElementSelector {
	if compound_selectors.len == 0 {
		return none
	}
	last := unsafe { &compound_selectors[compound_selectors.len - 1] }
	mut pseudo_element := ?PseudoElementSelector(none)
	for index in 0 .. last.simple_selectors.len {
		// Inspect the retained selector in place. A value loop makes the
		// pointer-receiver call escape a temporary copy on current V.
		simple_selector := unsafe { &last.simple_selectors[index] }
		if simple_selector.type_ == .pseudo_element {
			pseudo_element = simple_selector.pseudo_element()
		}
	}
	return pseudo_element
}

fn selector_contains_part_pseudo_element_uncached(compound_selectors []CompoundSelector) bool {
	if compound_selectors.len == 0 {
		return false
	}
	last := compound_selectors[compound_selectors.len - 1]
	for simple_selector in last.simple_selectors {
		if simple_selector.type_ == .pseudo_element && simple_selector.pseudo_element().type_ == .part {
			return true
		}
	}
	return false
}

pub fn (selector Selector) contains_pseudo_class(pseudo_class PseudoClass) bool {
	if selector.data_ != unsafe { nil } {
		return selector.data_.contained_pseudo_classes.get(pseudo_class)
	}
	return selector_contained_pseudo_classes_uncached(selector.compound_selectors()).get(pseudo_class)
}

pub fn (selector Selector) contains_unknown_webkit_pseudo_element() bool {
	for compound_selector in selector.compound_selectors() {
		for simple_selector in compound_selector.simple_selectors {
			if simple_selector.type_ == .pseudo_class {
				for child_selector in simple_selector.pseudo_class().argument_selector_list.selectors {
					if child_selector.contains_unknown_webkit_pseudo_element() {
						return true
					}
				}
			}
			if simple_selector.type_ == .pseudo_element && simple_selector.pseudo_element().type_ == .unknown_webkit {
				return true
			}
		}
	}
	return false
}

pub fn (selector Selector) can_use_fast_matches() bool {
	if selector.data_ != unsafe { nil } {
		return selector.data_.can_use_fast_matches
	}
	return can_selector_use_fast_matches(selector)
}

pub fn (selector Selector) can_use_ancestor_filter() bool {
	if selector.data_ != unsafe { nil } {
		return selector.data_.can_use_ancestor_filter
	}
	_, can_use := selector_ancestor_hashes(selector)
	return can_use
}

pub fn (selector Selector) ancestor_hashes() [8]u32 {
	if selector.data_ != unsafe { nil } {
		return selector.data_.ancestor_hashes
	}
	hashes, _ := selector_ancestor_hashes(selector)
	return hashes
}

pub fn (selector Selector) is_slotted() bool {
	pseudo := selector.pseudo_element() or { return false }
	return pseudo.type_ == .slotted
}

pub fn (selector Selector) has_part_pseudo_element() bool {
	if selector.data_ != unsafe { nil } {
		return selector.data_.contains_part_pseudo_element
	}
	return selector_contains_part_pseudo_element_uncached(selector.compound_selectors())
}

// https://www.w3.org/TR/selectors-4/#specificity-rules
pub fn (selector Selector) specificity() u32 {
	if selector.data_ != unsafe { nil } {
		if specificity := selector.data_.specificity {
			return specificity
		}
	}
	ids_shift := u32(16)
	classes_shift := u32(8)
	tag_names_shift := u32(0)
	ids_mask := u32(0xff) << ids_shift
	classes_mask := u32(0xff) << classes_shift
	tag_names_mask := u32(0xff) << tag_names_shift

	mut ids := u32(0)
	mut classes := u32(0)
	mut tag_names := u32(0)

	count_specificity_of_most_complex_selector := fn (selector_list SelectorList) u32 {
		mut max_selector_list_argument_specificity := u32(0)
		for complex_selector in selector_list.selectors {
			specificity := complex_selector.specificity()
			if specificity > max_selector_list_argument_specificity {
				max_selector_list_argument_specificity = specificity
			}
		}
		return max_selector_list_argument_specificity
	}

	for list in selector.compound_selectors() {
		for simple_selector in list.simple_selectors {
			match simple_selector.type_ {
				.id {
					// count the number of ID selectors in the selector (= A)
					ids++
				}
				.class, .attribute {
					// count the number of class selectors, attributes selectors, and pseudo-classes in the selector (= B)
					classes++
				}
				.pseudo_class {
					pseudo_class := simple_selector.pseudo_class()
					match pseudo_class.type_ {
						.has, .is_, .not_ {
							// The specificity of an :is(), :not(), or :has() pseudo-class is replaced by the
							// specificity of the most specific complex selector in its selector list argument.
							child_specificity := count_specificity_of_most_complex_selector(pseudo_class.argument_selector_list)
							ids += (child_specificity & ids_mask) >> ids_shift
							classes += (child_specificity & classes_mask) >> classes_shift
							tag_names += (child_specificity & tag_names_mask) >> tag_names_shift
						}
						.nth_child, .nth_last_child {
							// Analogously, the specificity of an :nth-child() or :nth-last-child() selector
							// is the specificity of the pseudo class itself (counting as one pseudo-class selector)
							// plus the specificity of the most specific complex selector in its selector list argument (if any).
							classes++
							child_specificity := count_specificity_of_most_complex_selector(pseudo_class.argument_selector_list)
							ids += (child_specificity & ids_mask) >> ids_shift
							classes += (child_specificity & classes_mask) >> classes_shift
							tag_names += (child_specificity & tag_names_mask) >> tag_names_shift
						}
						.where {
							// The specificity of a :where() pseudo-class is replaced by zero.
						}
						else {
							classes++
						}
					}
				}
				.tag_name {
					// count the number of type selectors and pseudo-elements in the selector (= C)
					tag_names++
				}
				.pseudo_element {
					// https://drafts.csswg.org/css-view-transitions-1/#named-view-transition-pseudo
					// The specificity of a named view transition pseudo-element selector with a <custom-ident> argument is equivalent
					// to a type selector. The specificity of a named view transition pseudo-element selector with a '*' argument is zero.
					// NB: We just break before adding to the type (tag name) specificity in case this is a named view transition pseudo that uses '*'
					if simple_selector.pseudo_element().type_ in [.view_transition_group,
						.view_transition_image_pair, .view_transition_old, .view_transition_new, .highlight] && simple_selector.pseudo_element().pt_name_selector.is_universal {
						continue
					}

					// count the number of type selectors and pseudo-elements in the selector (= C)
					tag_names++
				}
				.universal {
					// ignore the universal selector
				}
				.nesting {
					// "The specificity of the nesting selector is equal to the largest specificity among the complex selectors in the parent style rule’s selector list (identical to the behavior of :is()), or zero if no such selector list exists."
					// - https://drafts.csswg.org/css-nesting/#ref-for-specificity
					// The parented case is handled by replacing & with :is().
					// So if we got here, the specificity is 0.
				}
				.invalid {
					// Ignore invalid selectors
				}
			}
		}
	}

	// Due to storage limitations, implementations may have limitations on the size of A, B, or C.
	// If so, values higher than the limit must be clamped to that limit, and not overflow.
	specificity := (selector_min_u32(ids, 0xff) << ids_shift) + (selector_min_u32(classes, 0xff) << classes_shift) + (selector_min_u32(tag_names, 0xff) << tag_names_shift)
	if selector.data_ != unsafe { nil } {
		mut data := unsafe { &SelectorData(selector.data_) }
		data.specificity = specificity
	}
	return specificity
}

// https://www.w3.org/TR/cssom/#serialize-a-selector
pub fn (selector Selector) serialize() string {
	compound_selectors := selector.compound_selectors()
	if compound_selectors.len == 0 {
		return selector.text().trim_space()
	}

	mut s := strings.new_builder(selector.text().len)

	// AD-HOC: If this is a relative selector, we need to serialize the starting combinator.
	if compound_selectors.len != 0 {
		match compound_selectors[0].combinator {
			.immediate_child { s.write_string('> ') }
			.next_sibling { s.write_string('+ ') }
			.subsequent_sibling { s.write_string('~ ') }
			.column { s.write_string('|| ') }
			else {}
		}
	}

	// To serialize a selector let s be the empty string, run the steps below for each part of the chain of the selector, and finally return s:
	for i, compound_selector in compound_selectors {
		// 1. If there is only one simple selector in the compound selectors which is a universal selector, append the result of serializing the universal selector to s.
		if compound_selector.simple_selectors.len == 1 && compound_selector.simple_selectors[0].type_ == .universal {
			s.write_string(compound_selector.simple_selectors[0].serialize())
		} else {
			// 2. Otherwise, for each simple selector in the compound selectors that is not a universal selector
			//    of which the namespace prefix maps to a namespace that is not the default namespace
			//    serialize the simple selector and append the result to s.
			for simple_selector in compound_selector.simple_selectors {
				if simple_selector.type_ == .universal {
					qualified_name := simple_selector.qualified_name()
					if qualified_name.namespace_type == .default_ || qualified_name.namespace_type == .any {
						continue
					}
					// FIXME: I *think* if we have a namespace prefix that happens to equal the same as the default namespace,
					//        we also should skip it. But we don't have access to that here. eg:
					// <style>
					//   @namespace "http://example";
					//   @namespace foo "http://example";
					//   foo|*.bar { } /* This would skip the `foo|*` when serializing. */
					// </style>
				}
				s.write_string(simple_selector.serialize())
			}
		}

		// 3. If this is not the last part of the chain of the selector append a single SPACE (U+0020),
		//    followed by the combinator ">", "+", "~", ">>", "||", as appropriate, followed by another
		//    single SPACE (U+0020) if the combinator was not whitespace, to s.
		if i != compound_selectors.len - 1 {
			s.write_u8(` `)
			// Note: The combinator that appears between parts `i` and `i+1` appears with the `i+1` selector,
			//       so we have to check that one.
			match compound_selectors[i + 1].combinator {
				.immediate_child { s.write_string('> ') }
				.next_sibling { s.write_string('+ ') }
				.subsequent_sibling { s.write_string('~ ') }
				.column { s.write_string('|| ') }
				else {}
			}
		} else {
			// 4. If this is the last part of the chain of the selector and there is a pseudo-element,
			// append "::" followed by the name of the pseudo-element, to s.
			// This algorithm has a problem, see https://github.com/w3c/csswg-drafts/issues/11997
			//      serialization of pseudoElements was moved to SimpleSelector::serialize()
		}
	}

	return s.str()
}

pub fn (selector Selector) relative_to(parent SimpleSelector) Selector {
	// To make us relative to the parent, prepend it to the list of compound selectors,
	// and ensure the next compound selector starts with a combinator.
	mut copied_compound_selectors := []CompoundSelector{cap: selector.compound_selectors().len + 1}
	copied_compound_selectors << CompoundSelector{
		simple_selectors: [parent]
	}

	mut first := true
	for compound_selector in selector.compound_selectors() {
		copied_compound_selectors << CompoundSelector{
			...compound_selector
			combinator: if first && compound_selector.combinator == .no_combinator {
				.descendant
			} else { compound_selector.combinator }
		}
		first = false
	}

	return selector_from_compound_selectors(copied_compound_selectors)
}

pub fn sibling_invalidation_distance_for_selector(selector Selector) int {
	return selector.sibling_invalidation_distance()
}

pub fn (selector Selector) sibling_invalidation_distance() int {
	if selector.data_ != unsafe { nil } {
		if distance := selector.data_.sibling_invalidation_distance {
			return distance
		}
	}
	mut sibling_invalidation_distance := 0
	mut current_distance := 0
	for compound_selector in selector.compound_selectors() {
		if compound_selector.combinator == .no_combinator {
			continue
		}

		if compound_selector.combinator == .subsequent_sibling {
			sibling_invalidation_distance = selector_unbounded_sibling_invalidation_distance
			break
		}

		if compound_selector.combinator == .next_sibling {
			current_distance++
		} else {
			if current_distance > sibling_invalidation_distance {
				sibling_invalidation_distance = current_distance
			}
			current_distance = 0
		}
	}

	if sibling_invalidation_distance != selector_unbounded_sibling_invalidation_distance
		&& current_distance > 0 && current_distance > sibling_invalidation_distance {
		sibling_invalidation_distance = current_distance
	}
	if selector.data_ != unsafe { nil } {
		mut data := unsafe { &SelectorData(selector.data_) }
		data.sibling_invalidation_distance = sibling_invalidation_distance
	}
	return sibling_invalidation_distance
}

pub enum StyleNestingParent {
	none_
	style
	scope
}

pub fn adapt_nested_relative_selector_list(selectors SelectorList, nesting_parent StyleNestingParent) SelectorList {
	// "Nested style rules differ from non-nested rules in the following ways:
	// - A nested style rule accepts a <relative-selector-list> as its prelude (rather than just a <selector-list>).
	//   Any relative selectors are relative to the elements represented by the nesting selector.
	// - If a selector in the <relative-selector-list> does not start with a combinator but does contain the nesting
	//   selector, it is interpreted as a non-relative selector."
	// https://drafts.csswg.org/css-nesting-1/#syntax
	// NOTE: We already parsed the selectors as a <relative-selector-list>

	// Nested relative selectors get a `&` inserted when the nearest nesting parent is a style rule.
	// This is, handily, how the spec wants them serialized:
	// "When serializing a relative selector in a nested style rule, the selector must be absolutized,
	// with the implied nesting selector inserted."
	// - https://drafts.csswg.org/css-nesting-1/#cssom
	mut new_list := SelectorList{}
	for selector in selectors.selectors {
		compound_selectors := selector.compound_selectors()
		if compound_selectors.len == 0 {
			new_list.selectors << selector
			continue
		}
		first_combinator := compound_selectors[0].combinator
		insert_leading_ampersand := nesting_parent == .style
			&& (first_combinator !in [.no_combinator, .descendant] || !selector.contains_the_nesting_selector())
		if insert_leading_ampersand {
			new_list.selectors << selector.relative_to(SimpleSelector{
				type_: .nesting
			})
		} else if first_combinator == .descendant {
			// Replace leading descendant combinator (whitespace) with none, because we're not actually relative.
			mut copied_compound_selectors := compound_selectors.clone()
			copied_compound_selectors[0].combinator = .no_combinator
			new_list.selectors << selector_from_compound_selectors(copied_compound_selectors)
		} else {
			new_list.selectors << selector
		}
	}
	return new_list
}

pub fn adapt_scope_relative_selector_list(selectors SelectorList) SelectorList {
	return adapt_nested_relative_selector_list(selectors, .scope)
}

pub fn selector_matches(selector Selector, element &dom.Element) bool {
	mut context := MatchContext{has_result_cache: unsafe { nil }}
	return matches(selector, element, none, mut context, none, none, .normal, none)
}

pub fn matches(selector Selector, element &dom.Element, shadow_host ?&dom.Element, mut context MatchContext, pseudo_element ?PseudoElement, scope ?&dom.ParentNode, selector_kind SelectorKind, anchor ?&dom.Element) bool {
	if selector_kind == .normal && selector.can_use_fast_matches() {
		return fast_matches(selector, element, shadow_host, mut context)
	}

	compound_selectors := selector.compound_selectors()
	if compound_selectors.len == 0 {
		return false
	}

	if selector.has_part_pseudo_element() {
		// For ::part() selectors, find any additional pseudo-element beyond ::part() (e.g., the ::selection in
		// ::part(foo)::selection) and verify it matches the target pseudo-element. A bare ::part(foo) selector has no
		// additional pseudo-element and should only match base element styles.
		mut target_pseudo := ?PseudoElement(none)
		for simple in compound_selectors[compound_selectors.len - 1].simple_selectors {
			if simple.type_ == .pseudo_element && simple.pseudo_element().type_ != .part {
				target_pseudo = simple.pseudo_element().type_
				break
			}
		}
		if !optional_pseudo_element_equal(target_pseudo, pseudo_element) {
			return false
		}
	} else {
		selector_pseudo := selector.pseudo_element()
		if target := pseudo_element {
			if selector_pseudo_value := selector_pseudo {
				if selector_pseudo_value.type_ != target {
					return false
				}
			}
		}
		if pseudo_element == none && selector_pseudo != none {
			return false
		}
	}

	return matches_selector_at(selector, compound_selectors.len - 1, element, shadow_host, mut context, scope, selector_kind, anchor)
}

fn matches_selector_at(selector Selector, component_list_index int, initial_element &dom.Element, shadow_host ?&dom.Element, mut context MatchContext, scope ?&dom.ParentNode, selector_kind SelectorKind, anchor ?&dom.Element) bool {
	mut matching_shadow_host := shadow_host
	compound_selectors := selector.compound_selectors()
	if component_list_index < 0 || component_list_index >= compound_selectors.len {
		return false
	}
	compound_selector := compound_selectors[component_list_index]
	saved_for_host_part_matching := context.for_host_part_matching
	defer {
		context.for_host_part_matching = saved_for_host_part_matching
	}
	if context.rule_shadow_root != none && compound_selector_contains_host_for_part_matching(compound_selector) {
		context.for_host_part_matching = true
	}
	mut element_for_compound_matching := unsafe { initial_element }
	for i := compound_selector.simple_selectors.len - 1; i >= 0; i-- {
		// The immutable selector owns this array throughout the bounded reverse loop.
		simple_selector := unsafe { &SimpleSelector(compound_selector.simple_selectors.data) + i }
		if !matches_simple(simple_selector, element_for_compound_matching, matching_shadow_host, mut context, scope, selector_kind, anchor) {
			return false
		}
		if part_owning_parent := context.part_owning_parent {
			// Match the rest of the compound selector against the shadow host that element is a part of.
			element_for_compound_matching = part_owning_parent
			if !context.for_host_part_matching {
				// The remaining selector addresses the exposing host in the rule
				// tree. Its own shadow boundary no longer limits matching.
				matching_shadow_host = if root := context.rule_shadow_root { root.host() } else { none }
			}
			context.part_owning_parent = none
		}
	}
	element := element_for_compound_matching

	if selector_kind == .relative && component_list_index == 0 {
		anchor_element := anchor or { return true }
		return voidptr(element) != voidptr(anchor_element)
	}

	match compound_selector.combinator {
		.no_combinator {
			return selector_kind != .relative
		}
		.descendant {
			if component_list_index == 0 {
				return false
			}
			mut ancestor := traverse_up(element.as_node(), matching_shadow_host)
			for ancestor != none {
				ancestor_node := ancestor or { break }
				if ancestor_element := ancestor_node.as_element() {
					if anchor_element := anchor {
						if voidptr(ancestor_element) == voidptr(anchor_element) {
							return false
						}
					}
					if context.inside_has_argument_match
						&& context.collect_per_element_selector_involvement_metadata {
						mut mutable_ancestor := unsafe { &dom.Element(ancestor_element) }
						mutable_ancestor.set_in_has_scope(true)
					}
					if matches_selector_at(selector, component_list_index - 1, ancestor_element, matching_shadow_host, mut context, scope, selector_kind, anchor) {
						return true
					}
				}
				ancestor = traverse_up(ancestor_node, matching_shadow_host)
			}
			return false
		}
		.immediate_child {
			if component_list_index == 0 {
				return false
			}
			parent := traverse_up(element.as_node(), matching_shadow_host) or { return false }
			ancestor_element := parent.as_element() or { return false }
			if context.inside_has_argument_match
				&& context.collect_per_element_selector_involvement_metadata {
				mut mutable_parent := unsafe { &dom.Element(ancestor_element) }
				mutable_parent.set_in_has_scope(true)
			}
			return matches_selector_at(selector, component_list_index - 1, ancestor_element, matching_shadow_host, mut context, scope, selector_kind, anchor)
		}
		.next_sibling {
			if context.collect_per_element_selector_involvement_metadata {
				mut mutable_element := unsafe { &dom.Element(element) }
				mutable_element.affected_by_direct_sibling_combinator = true
				if subject := context.subject {
					if voidptr(element) != voidptr(subject) {
						mutable_element.set_affected_by_sibling_combinator_in_non_subject_position()
					}
				} else {
					mutable_element.set_affected_by_sibling_combinator_in_non_subject_position()
				}
				distance := selector.sibling_invalidation_distance()
				if distance > mutable_element.sibling_invalidation_distance {
					mutable_element.sibling_invalidation_distance = distance
				}
			}
			if component_list_index == 0 {
				return false
			}
			if sibling := previous_element_sibling(element) {
				if context.inside_has_argument_match
					&& context.collect_per_element_selector_involvement_metadata {
					mut mutable_sibling := unsafe { &dom.Element(sibling) }
					mutable_sibling.set_in_has_scope(true)
				}
				return matches_selector_at(selector, component_list_index - 1, sibling, matching_shadow_host, mut context, scope, selector_kind, anchor)
			}
			return false
		}
		.subsequent_sibling {
			if context.collect_per_element_selector_involvement_metadata {
				mut mutable_element := unsafe { &dom.Element(element) }
				mutable_element.affected_by_indirect_sibling_combinator = true
				if subject := context.subject {
					if voidptr(element) != voidptr(subject) {
						mutable_element.set_affected_by_sibling_combinator_in_non_subject_position()
					}
				} else {
					mutable_element.set_affected_by_sibling_combinator_in_non_subject_position()
				}
			}
			if component_list_index == 0 {
				return false
			}
			mut sibling := previous_element_sibling(element)
			for sibling != none {
				sibling_element := sibling or { break }
				if context.inside_has_argument_match
					&& context.collect_per_element_selector_involvement_metadata {
					mut mutable_sibling := unsafe { &dom.Element(sibling_element) }
					mutable_sibling.set_in_has_scope(true)
				}
				if matches_selector_at(selector, component_list_index - 1, sibling_element, matching_shadow_host, mut context, scope, selector_kind, anchor) {
					return true
				}
				sibling = previous_element_sibling(sibling_element)
			}
			return false
		}
		.column {
			// FIXME: Column combinator matching requires table-column layout hooks.
			return false
		}
	}
}

fn compound_selector_contains_host_for_part_matching(compound_selector CompoundSelector) bool {
	for simple_selector in compound_selector.simple_selectors {
		if simple_selector.type_ != .pseudo_class {
			continue
		}
		if simple_selector.pseudo_class().type_ == .host {
			return true
		}
		if simple_selector.pseudo_class().type_ != .is_ {
			continue
		}
		for argument in simple_selector.pseudo_class().argument_selector_list.selectors {
			for argument_compound in argument.compound_selectors() {
				for argument_simple in argument_compound.simple_selectors {
					if argument_simple.type_ == .pseudo_class
						&& argument_simple.pseudo_class().type_ == .host {
						return true
					}
				}
			}
		}
	}
	return false
}

fn part_element_map_contains(part_map map[string][]dom.AbstractElement, name string, element &dom.Element) bool {
	entries := part_map[name] or { return false }
	for entry in entries {
		if voidptr(entry.element()) == voidptr(element) && entry.pseudo_element() == none {
			return true
		}
	}
	return false
}

fn matches_simple(component &SimpleSelector, element &dom.Element, shadow_host ?&dom.Element, mut context MatchContext, scope ?&dom.ParentNode, selector_kind SelectorKind, anchor ?&dom.Element) bool {
	_ = anchor
	if should_block_shadow_host_matching(component, shadow_host, element) {
		return false
	}
	match component.type_ {
		.universal, .tag_name {
			qualified_name := component.qualified_name()

			// Reject if the tag name doesn't match
			if component.type_ == .tag_name {
				// See https://html.spec.whatwg.org/multipage/semantics-other.html#case-sensitivity-of-selectors
				if element.document() != unsafe { nil } && element.document().document_type() == .html && element.namespace_uri() or {
					''
				} == selector_html_namespace {
					if qualified_name.name.lowercase_name != element.local_name() {
						return false
					}
				} else if qualified_name.name.name != element.local_name() {
					return false
				}
			}

			return matches_namespace(qualified_name, element, context.style_sheet_for_rule)
		}
		.id {
			id := element.id() or { return false }
			if element.document() != unsafe { nil } && element.document().in_quirks_mode() {
				return equals_ignoring_ascii_case(component.name().name, id)
			}
			return component.name().name == id
		}
		.class {
			// Class selectors are matched case insensitively in quirks mode.
			// See: https://drafts.csswg.org/selectors-4/#class-html
			if element.document() != unsafe { nil } && element.document().in_quirks_mode() {
				return element.has_class_case_insensitive(component.name().name)
			}
			return element.has_class(component.name().name)
		}
		.attribute {
			return matches_attribute(component.attribute(), context.style_sheet_for_rule, element)
		}
		.pseudo_class {
			return matches_pseudo_class(component.pseudo_class(), element, shadow_host, mut context, scope, selector_kind)
		}
		.pseudo_element {
			if component.pseudo_element().type_ == .highlight {
    if component.pseudo_element().value_kind == .pt_name_selector && component.pseudo_element().pt_name_selector.is_universal { return true }
				names := component.pseudo_element().ident_list
				return names.len == 1 && names[0] == context.pseudo_argument
			}
			if component.pseudo_element().type_ == .slotted {
				slotted_element := context.slotted_element or { return false }
				compound_selector := component.pseudo_element().compound_selector or { return false }
				return matches(compound_selector, slotted_element, shadow_host, mut context, none, none, .normal, none)
			}
			if component.pseudo_element().type_ == .part {
				// ::part() only consults maps owned by a host in the rule's direct
				// child scope, except for :host::part() in the rule's own root.
				mut ancestor_shadow_root := element.as_node().containing_shadow_root()
				for ancestor_shadow_root != none {
					root := ancestor_shadow_root or { break }
					host := root.host() or { break }
					is_direct_child_scope := style_scope_optional_shadow_root_equal(host.as_node().containing_shadow_root(), context.rule_shadow_root)
					is_host_part_own_scope := if rule_root := context.rule_shadow_root {
						voidptr(root) == voidptr(rule_root) && context.for_host_part_matching
					} else {
						false
					}
					if is_direct_child_scope || is_host_part_own_scope {
						part_element_map := root.part_element_map()
						mut all_part_names_match := true
						for part_name in component.pseudo_element().ident_list {
							if !part_element_map_contains(part_element_map, part_name, element) {
								all_part_names_match = false
								break
							}
						}
						if all_part_names_match {
							context.part_owning_parent = host
							return true
						}
					}
					ancestor_shadow_root = host.as_node().containing_shadow_root()
				}
				return false
			}
			// Other pseudo-element matching/not-matching is handled in the top level matches().
			return true
		}
		.nesting {
			// Nesting either behaves like :is(), or like :scope.
			// :is() is handled already, by us replacing it with :is() directly, so if we
			// got here, it's :scope.
			return matches_pseudo_class(PseudoClassSelector{
				type_: .scope
			}, element, shadow_host, mut context, scope, selector_kind)
		}
		.invalid {
			// Invalid selectors never match
			return false
		}
	}
}

fn note_structural_pseudo_class_match_attempt(context &MatchContext, target &dom.Element) {
	if subject := context.subject {
		if voidptr(target) == voidptr(subject) { return }
	}
	mut mutable_target := unsafe { &dom.Element(target) }
	mutable_target.set_affected_by_structural_pseudo_class_in_non_subject_position()
}

fn matches_pseudo_class(pseudo_class PseudoClassSelector, element &dom.Element, shadow_host ?&dom.Element, mut context MatchContext, scope ?&dom.ParentNode, selector_kind SelectorKind) bool {
	context.attempted_pseudo_class_matches.set(pseudo_class.type_, true)
	match pseudo_class.type_ {
		.invalid {
			return false
		}
		.link, .any_link {
			// NOTE: AnyLink should match whether the link is visited or not, so if we ever start matching
			//       :visited, we'll need to handle these differently.
			return element.matches_link_pseudo_class()
		}
		.local_link {
			return element.matches_local_link_pseudo_class()
		}
		.visited {
			// FIXME: Maybe match this selector sometimes?
			return false
		}
		.active {
			return element.is_being_activated()
		}
		.hover {
			return matches_hover_pseudo_class(element)
		}
		.focus {
			return element.is_focused() && element.document().shows_focus_state()
		}
		.focus_visible {
			return element.is_focused() && element.should_indicate_focus()
				&& element.document().shows_focus_state()
		}
		.focus_within {
			focused_area := element.document().focused_area() or { return false }
			return element.as_node().is_inclusive_ancestor_of(focused_area)
				&& element.document().shows_focus_state()
		}
		.fullscreen {
			return element.is_fullscreen_element()
		}
		.first_child {
			if context.collect_per_element_selector_involvement_metadata {
				mut mutable_element := unsafe { &dom.Element(element) }
				mutable_element.affected_by_first_child_pseudo_class = true
				note_structural_pseudo_class_match_attempt(&context, element)
			}
			return previous_element_sibling(element) == none
		}
		.last_child {
			if context.collect_per_element_selector_involvement_metadata {
				mut mutable_element := unsafe { &dom.Element(element) }
				mutable_element.set_affected_by_last_child_pseudo_class(true)
				note_structural_pseudo_class_match_attempt(&context, element)
			}
			return next_element_sibling(element) == none
		}
		.only_child {
			if context.collect_per_element_selector_involvement_metadata {
				mut mutable_element := unsafe { &dom.Element(element) }
				mutable_element.affected_by_first_child_pseudo_class = true
				mutable_element.set_affected_by_last_child_pseudo_class(true)
				note_structural_pseudo_class_match_attempt(&context, element)
			}
			return previous_element_sibling(element) == none && next_element_sibling(element) == none
		}
		.empty {
			if !element.as_node().has_children() {
				return true
			}
			for child in element.as_node().children {
				if child.as_element() != none {
					return false
				}
				if character_data := child.character_data() {
					if character_data.data().len != 0 {
						return false
					}
				}
			}
			return true
		}
		.root {
			// https://drafts.csswg.org/selectors/#root-pseudo
			// The root is the document element in every document type, not every
			// HTMLHtmlElement and not only the document element of an HTML document.
			return element.is_document_element()
		}
		.host {
			return matches_host_pseudo_class(element, shadow_host, mut context, pseudo_class.argument_selector_list)
		}
		.scope {
			if scope_node := scope {
				if scope_document := scope_node.as_node().as_document() {
					return element.is_document_element()
						&& voidptr(element.document()) == voidptr(scope_document)
				}
				return voidptr(scope_node.as_node()) == voidptr(element.as_node())
			}
			return element.is_html_element() && element.local_name() == 'html'
		}
		.first_of_type {
			if context.collect_per_element_selector_involvement_metadata {
				mut mutable_element := unsafe { &dom.Element(element) }
				mutable_element.affected_by_forward_positional_pseudo_class = true
				note_structural_pseudo_class_match_attempt(&context, element)
			}
			return previous_sibling_with_same_type(element) == none
		}
		.last_of_type {
			if context.collect_per_element_selector_involvement_metadata {
				mut mutable_element := unsafe { &dom.Element(element) }
				mutable_element.set_affected_by_backward_positional_pseudo_class(true)
				note_structural_pseudo_class_match_attempt(&context, element)
			}
			return next_sibling_with_same_type(element) == none
		}
		.only_of_type {
			if context.collect_per_element_selector_involvement_metadata {
				mut mutable_element := unsafe { &dom.Element(element) }
				mutable_element.affected_by_forward_positional_pseudo_class = true
				mutable_element.set_affected_by_backward_positional_pseudo_class(true)
				note_structural_pseudo_class_match_attempt(&context, element)
			}
			return previous_sibling_with_same_type(element) == none && next_sibling_with_same_type(element) == none
		}
		.lang {
			return matches_lang_pseudo_class(element, pseudo_class.languages)
		}
		.disabled {
			return element.matches_disabled_pseudo_class()
		}
		.enabled {
			return element.matches_enabled_pseudo_class()
		}
		.checked {
			return element.matches_checked_pseudo_class()
		}
		.unchecked {
			return element.matches_unchecked_pseudo_class()
		}
		.indeterminate {
			return matches_indeterminate_pseudo_class(element)
		}
		.high_value, .low_value, .optimal_value, .suboptimal_value, .even_less_good_value {
			return matches_optimal_value_pseudo_class(element, pseudo_class.type_)
		}
		.defined {
			return element.is_defined()
		}
		.has {
			// :has() cannot be nested in a :has()
			if selector_kind == .relative {
				return false
			}
			if context.collect_per_element_selector_involvement_metadata {
				mut mutable_element := unsafe { &dom.Element(element) }
				if subject := context.subject {
					if voidptr(element) == voidptr(subject) {
						mutable_element.affected_by_has_pseudo_class_in_subject_position = true
					} else {
						mutable_element.affected_by_has_pseudo_class_in_non_subject_position = true
					}
				}
			}
			// These selectors should be relative selectors (https://drafts.csswg.org/selectors-4/#relative-selector)
			for selector in pseudo_class.argument_selector_list.selectors {
				if matches_has_pseudo_class(selector, element, shadow_host, mut context, scope) {
					return true
				}
			}
			return false
		}
		.is_, .where {
			for selector in pseudo_class.argument_selector_list.selectors {
				if matches(selector, element, shadow_host, mut context, none, scope, .normal, none) {
					return true
				}
			}
			return false
		}
		.not_ {
			for selector in pseudo_class.argument_selector_list.selectors {
				if matches(selector, element, shadow_host, mut context, none, scope, .normal, none) {
					return false
				}
			}
			return true
		}
		.nth_child, .nth_last_child, .nth_of_type, .nth_last_of_type {
			if context.collect_per_element_selector_involvement_metadata {
				mut mutable_element := unsafe { &dom.Element(element) }
				match pseudo_class.type_ {
					.nth_child, .nth_of_type {
						mutable_element.affected_by_forward_positional_pseudo_class = true
					}
					.nth_last_child, .nth_last_of_type {
						mutable_element.set_affected_by_backward_positional_pseudo_class(true)
					}
					else {}
				}
				note_structural_pseudo_class_match_attempt(&context, element)
			}

			// https://drafts.csswg.org/selectors-4/#child-index
			// The pseudo-classes defined in this section select elements based on their index amongst their inclusive siblings.
			// NB: An element without a parent has no siblings, so its index is 1.
			mut index := 1
			match pseudo_class.type_ {
				.nth_child {
					if !matches_nth_selector_list(pseudo_class.argument_selector_list, element, shadow_host, mut context) {
						return false
					}
					parent := element.as_node().parent() or {
						return pseudo_class.an_plus_b_pattern.matches(index)
					}
					for child in parent.children {
						child_element := child.as_element() or { continue }
						if voidptr(child_element) == voidptr(element) {
							break
						}
						if matches_nth_selector_list(pseudo_class.argument_selector_list, child_element, shadow_host, mut context) {
							index++
						}
					}
				}
				.nth_last_child {
					if !matches_nth_selector_list(pseudo_class.argument_selector_list, element, shadow_host, mut context) {
						return false
					}
					parent := element.as_node().parent() or {
						return pseudo_class.an_plus_b_pattern.matches(index)
					}
					for i := parent.children.len - 1; i >= 0; i-- {
						child_element := parent.children[i].as_element() or { continue }
						if voidptr(child_element) == voidptr(element) {
							break
						}
						if matches_nth_selector_list(pseudo_class.argument_selector_list, child_element, shadow_host, mut context) {
							index++
						}
					}
				}
				.nth_of_type {
					mut child := previous_sibling_with_same_type(element)
					for child != none {
						index++
						child = previous_sibling_with_same_type(child or { break })
					}
				}
				.nth_last_of_type {
					mut child := next_sibling_with_same_type(element)
					for child != none {
						index++
						child = next_sibling_with_same_type(child or { break })
					}
				}
				else {}
			}

			return pseudo_class.an_plus_b_pattern.matches(index)
		}
		.playing { return element.matches_media_pseudo_class(.playing) }
		.paused { return element.matches_media_pseudo_class(.paused) }
		.seeking { return element.matches_media_pseudo_class(.seeking) }
		.muted { return element.matches_media_pseudo_class(.muted) }
		.buffering { return element.matches_media_pseudo_class(.buffering) }
		.stalled { return element.matches_media_pseudo_class(.stalled) }
		.volume_locked {
			// Source's volume is never locked.
			return false
		}
		.target {
			return element.is_target()
		}
		.dir {
			// "Values other than ltr and rtl are not invalid, but do not match anything."
			// - https://www.w3.org/TR/selectors-4/#the-dir-pseudo
			ident := pseudo_class.ident or { return false }
			if ident.keyword !in [.ltr, .rtl] {
				return false
			}
			match element.directionality() {
				.ltr {
					return ident.keyword == .ltr
				}
				.rtl {
					return ident.keyword == .rtl
				}
			}
		}
		.read_only {
			return !matches_read_write_pseudo_class(element)
		}
		.read_write {
			return matches_read_write_pseudo_class(element)
		}
		.placeholder_shown {
			return element.matches_placeholder_shown_pseudo_class()
		}
		.open {
			return matches_open_state_pseudo_class(element, true)
		}
		.closed {
			return matches_open_state_pseudo_class(element, false)
		}
		.modal {
			return element.local_name() == 'dialog' && element.has_attribute('open') && element.in_top_layer()
		}
		.popover_open {
			// https://html.spec.whatwg.org/multipage/semantics-other.html#selector-popover-open
			// The :popover-open pseudo-class is defined to match any HTML element whose popover attribute is not in the
			// No Popover state and whose popover visibility state is showing.
			return element.has_attribute('popover') && element.in_top_layer()
		}
		.required {
			return element.matches_required_pseudo_class()
		}
		.optional {
			return element.matches_optional_pseudo_class()
		}
		.default_ {
			return element.matches_default_pseudo_class()
		}
		.valid, .invalid_state, .user_valid, .user_invalid {
			// FIXME: Requires form-associated element constraint-validation hooks.
			return false
		}
		.autofill {
			// https://html.spec.whatwg.org/multipage/semantics-other.html#selector-autofill
			// FIXME: The :autofill and :-webkit-autofill pseudo-classes must match input elements which have been autofilled by
			//        user agent. These pseudo-classes must stop matching if the user edits the autofilled field.
			// NB: We don't support autofilling inputs yet, so this is always false.
			return false
		}
		.state {
			// https://html.spec.whatwg.org/multipage/semantics-other.html#selector-custom
			// The :state(identifier) pseudo-class must match all custom elements whose states set's set entries contains identifier.
			ident := pseudo_class.ident or { return false }
			states := element.custom_state_set() or { return false }
			return states.has_state(ident.string_value)
		}
		.heading {
			// https://html.spec.whatwg.org/multipage/semantics-other.html#selector-heading
			// The :heading pseudo-class must match all h1, h2, h3, h4, h5, and h6 elements.

			// https://html.spec.whatwg.org/multipage/semantics-other.html#selector-heading-functional
			// The :heading(integer#) pseudo-class must match all h1, h2, h3, h4, and h6 elements that have a heading level of integer. [CSSSYNTAX] [CSSVALUES]
			if !element.local_name().starts_with('h') || element.local_name().len != 2 {
				return false
			}
			level := int(element.local_name()[1] - `0`)
			if level < 1 || level > 6 {
				return false
			}
			if pseudo_class.levels.len == 0 {
				return true
			}
			return i64(level) in pseudo_class.levels
		}
	}

	return false
}

fn fast_matches(selector Selector, element_to_match &dom.Element, shadow_host ?&dom.Element, mut context MatchContext) bool {
	compound_selectors := selector.compound_selectors()
	if compound_selectors.len == 0 {
		return false
	}
	mut current := unsafe { element_to_match }
	mut compound_selector_index := compound_selectors.len - 1

	if !fast_matches_compound_selector(compound_selectors[compound_selectors.len - 1], current, shadow_host, mut context) {
		return false
	}

	// NOTE: If we fail after following a child combinator, we may need to backtrack
	//       to the last matched descendant. We store the state here.
	mut backtrack_element := ?&dom.Element(none)
	mut backtrack_compound_selector_index := 0

	for {
		if compound_selector_index < 0 {
			return false
		}

		compound_selector := compound_selectors[compound_selector_index]
		match compound_selector.combinator {
			.no_combinator {
				return true
			}
			.descendant {
				backtrack_element = parent_element(current)
				backtrack_compound_selector_index = compound_selector_index
				compound_selector_index--
				if compound_selector_index < 0 {
					return false
				}
				left_compound_selector := compound_selectors[compound_selector_index]
				mut ancestor := parent_element(current)
				for ancestor != none {
					ancestor_element := ancestor or { break }
					if fast_matches_compound_selector(left_compound_selector, ancestor_element, shadow_host, mut context) {
						current = ancestor_element
						break
					}
					ancestor = parent_element(ancestor_element)
				}
				if ancestor == none {
					return false
				}
			}
			.immediate_child {
				compound_selector_index--
				if compound_selector_index < 0 {
					return false
				}
				current = parent_element(current) or { return false }
				if !fast_matches_compound_selector(compound_selectors[compound_selector_index], current, shadow_host, mut context) {
					if backtrack := backtrack_element {
						current = backtrack
						compound_selector_index = backtrack_compound_selector_index
						continue
					}
					return false
				}
			}
			else {
				return false
			}
		}
	}
	return false
}

fn fast_matches_compound_selector(compound_selector CompoundSelector, element &dom.Element, shadow_host ?&dom.Element, mut context MatchContext) bool {
	// Borrow each immutable record for this call instead of copying its payload.
	for index in 0 .. compound_selector.simple_selectors.len {
		if !fast_matches_simple_selector(&compound_selector.simple_selectors[index], element, shadow_host, mut context) {
			return false
		}
	}
	return true
}

fn fast_matches_simple_selector(simple_selector &SimpleSelector, element &dom.Element, shadow_host ?&dom.Element, mut context MatchContext) bool {
	if should_block_shadow_host_matching(simple_selector, shadow_host, element) {
		return false
	}

	match simple_selector.type_ {
		.universal {
			return matches_namespace(simple_selector.qualified_name(), element, context.style_sheet_for_rule)
		}
		.tag_name {
			// https://html.spec.whatwg.org/multipage/semantics-other.html#case-sensitivity-of-selectors
			// When comparing a CSS element type selector to the names of HTML elements in HTML documents, the CSS element type selector must first be converted to ASCII lowercase. The
			// same selector when compared to other elements must be compared according to its original case. In both cases, to match the values must be identical to each other (and therefore
			// the comparison is case sensitive).
			if element.namespace_uri() or { '' } == selector_html_namespace && element.document() != unsafe { nil } && element.document().document_type() == .html {
				if simple_selector.qualified_name().name.lowercase_name != element.local_name() {
					return false
				}
			} else if simple_selector.qualified_name().name.name != element.local_name() {
				// NOTE: Any other elements are either SVG, XHTML or MathML, all of which are case-sensitive.
				return false
			}
			return matches_namespace(simple_selector.qualified_name(), element, context.style_sheet_for_rule)
		}
		.class {
			// Class selectors are matched case insensitively in quirks mode.
			// See: https://drafts.csswg.org/selectors-4/#class-html
			if element.document() != unsafe { nil } && element.document().in_quirks_mode() {
				return element.has_class_case_insensitive(simple_selector.name().name)
			}
			return element.has_class(simple_selector.name().name)
		}
		.id {
			id := element.id() or { return false }
			if element.document() != unsafe { nil } && element.document().in_quirks_mode() {
				return equals_ignoring_ascii_case(simple_selector.name().name, id)
			}
			return simple_selector.name().name == id
		}
		.attribute {
			return matches_attribute(simple_selector.attribute(), context.style_sheet_for_rule, element)
		}
		.pseudo_class {
			return matches_pseudo_class(simple_selector.pseudo_class(), element, shadow_host, mut context, none, .normal)
		}
		else {
			return false
		}
	}
}

fn parse_complex_selector(source string) []CompoundSelector {
	text := source.trim_space()
	if text.len == 0 {
		return []
	}

	mut compounds := []CompoundSelector{}
	mut current := []SimpleSelector{}
	mut combinator := Combinator.no_combinator
	mut i := 0
	for i < text.len {
		mut saw_whitespace := false
		for i < text.len && is_ascii_whitespace_byte(text[i]) {
			saw_whitespace = true
			i++
		}
		if i >= text.len {
			break
		}

		if saw_whitespace && current.len != 0 && !is_combinator_start(text, i) {
			compounds << CompoundSelector{
				combinator: combinator
				simple_selectors: current
			}
			current = []
			combinator = .descendant
		}

		if is_combinator_start(text, i) {
			if current.len != 0 {
				compounds << CompoundSelector{
					combinator: combinator
					simple_selectors: current
				}
				current = []
			}
			if text[i] == `>` {
				combinator = .immediate_child
				i++
			} else if text[i] == `+` {
				combinator = .next_sibling
				i++
			} else if text[i] == `~` {
				combinator = .subsequent_sibling
				i++
			} else if text[i] == `|` && i + 1 < text.len && text[i + 1] == `|` {
				combinator = .column
				i += 2
			}
			continue
		}

		parsed := parse_simple_selector(text, i)
		if parsed.next <= i {
			current << SimpleSelector.with_invalid_text(.invalid, text[i..i + 1])
			i++
		} else {
			current << parsed.selector
			i = parsed.next
		}
	}

	if current.len != 0 {
		compounds << CompoundSelector{
			combinator: combinator
			simple_selectors: current
		}
	}

	return compounds
}

struct ParsedSimpleSelector {
	selector SimpleSelector
	next     int
}

fn parse_simple_selector(text string, start int) ParsedSimpleSelector {
	if start >= text.len {
		return ParsedSimpleSelector{
			next: start
		}
	}
	ch := text[start]
	if ch == `&` {
		return ParsedSimpleSelector{
			selector: SimpleSelector{
				type_: .nesting
			}
			next: start + 1
		}
	}
	if ch == `#` {
		name, next := parse_identifier(text, start + 1)
		if name.len == 0 {
			return ParsedSimpleSelector{
				selector: invalid_simple_selector('#')
				next: next
			}
		}
		return ParsedSimpleSelector{
			selector: SimpleSelector.with_name(.id, SelectorName.new(name))
			next: next
		}
	}
	if ch == `.` {
		name, next := parse_identifier(text, start + 1)
		if name.len == 0 {
			return ParsedSimpleSelector{
				selector: invalid_simple_selector('.')
				next: next
			}
		}
		return ParsedSimpleSelector{
			selector: SimpleSelector.with_name(.class, SelectorName.new(name))
			next: next
		}
	}
	if ch == `[` {
		body, next := read_balanced(text, start, `[`, `]`)
		return ParsedSimpleSelector{
			selector: parse_attribute_selector(body)
			next: next
		}
	}
	if ch == `:` {
		return parse_pseudo_selector(text, start)
	}
	if ch == `*` || ch == `|` || ch == `\\` || is_ident_start_byte(ch) {
		return parse_type_or_universal_selector(text, start)
	}
	return ParsedSimpleSelector{
		selector: SimpleSelector.with_invalid_text(.invalid, text[start..start + 1])
		next: start + 1
	}
}

fn parse_type_or_universal_selector(text string, start int) ParsedSimpleSelector {
	mut namespace_type := QualifiedNameNamespaceType.default_
	mut namespace_ := ''
	mut name := ''
	mut is_universal := false
	mut i := start

	if text[i] == `*` {
		if i + 1 < text.len && text[i + 1] == `|` {
			namespace_type = .any
			i += 2
			if i < text.len && text[i] == `*` {
				is_universal = true
				name = '*'
				i++
			} else {
				name, i = parse_identifier(text, i)
			}
		} else {
			is_universal = true
			name = '*'
			i++
		}
	} else if text[i] == `|` {
		namespace_type = .none
		i++
		if i < text.len && text[i] == `*` {
			is_universal = true
			name = '*'
			i++
		} else {
			name, i = parse_identifier(text, i)
		}
	} else {
		first, next := parse_identifier(text, i)
		if next < text.len && text[next] == `|` {
			namespace_type = .named
			namespace_ = first
			i = next + 1
			if i < text.len && text[i] == `*` {
				is_universal = true
				name = '*'
				i++
			} else {
				name, i = parse_identifier(text, i)
			}
		} else {
			name = first
			i = next
		}
	}

	qualified_name := SelectorQualifiedName{
		namespace_type: namespace_type
		namespace_: namespace_
		name: SelectorName.new(name)
	}
	if is_universal {
		return ParsedSimpleSelector{
			selector: SimpleSelector.with_qualified_name(.universal, qualified_name)
			next: i
		}
	}
	return ParsedSimpleSelector{
		selector: SimpleSelector.with_qualified_name(.tag_name, qualified_name)
		next: i
	}
}

fn parse_attribute_selector(body string) SimpleSelector {
	mut text := body.trim_space()
	if text.len == 0 {
		return invalid_simple_selector('[${body}]')
	}
	mut case_type := AttributeCaseType.default_match

	operators := ['~=', '*=', '|=', '^=', '\$=', '=']
	mut operator := ''
	mut operator_index := -1
	for candidate in operators {
		if idx := top_level_index(text, candidate) {
			operator = candidate
			operator_index = idx
			break
		}
	}

	name_text := if operator_index >= 0 { text[..operator_index].trim_space() } else { text }
	qualified_name := parse_attribute_qualified_name(name_text) or {
		return invalid_simple_selector('[${body}]')
	}
	value := if operator_index >= 0 {
		value_text, parsed_case_type, ok := parse_attribute_value_and_case_suffix(text[operator_index + operator.len..].trim_space())
		if !ok {
			return invalid_simple_selector('[${body}]')
		}
		case_type = parsed_case_type
		value_text
	} else {
		if selector_text_contains_unquoted_whitespace(name_text) {
			return invalid_simple_selector('[${body}]')
		}
		''
	}
	match_type := match operator {
		'~=' { AttributeMatchType.contains_word }
		'*=' { AttributeMatchType.contains_string }
		'|=' { AttributeMatchType.starts_with_segment }
		'^=' { AttributeMatchType.starts_with_string }
		'\$=' { AttributeMatchType.ends_with_string }
		'=' { AttributeMatchType.exact_value_match }
		else { AttributeMatchType.has_attribute }
	}

	return SimpleSelector.with_attribute(.attribute, SelectorAttribute{
			match_type: match_type
			qualified_name: qualified_name
			value: value
			case_type: case_type
		})
}

fn parse_attribute_qualified_name(name_text string) ?SelectorQualifiedName {
	text := name_text.trim_space()
	if text.len == 0 || selector_text_contains_unquoted_whitespace(text) {
		return none
	}
	if text.starts_with('*|') {
		name := text[2..]
		if !is_valid_selector_identifier(name) || name == '*' {
			return none
		}
		return SelectorQualifiedName{
			namespace_type: .any
			name: SelectorName.new(name)
		}
	}
	if text.starts_with('|') {
		name := text[1..]
		if !is_valid_selector_identifier(name) || name == '*' {
			return none
		}
		return SelectorQualifiedName{
			namespace_type: .none
			name: SelectorName.new(name)
		}
	}
	if text.contains('|') {
		parts := text.split_nth('|', 2)
		if parts.len != 2 || !is_valid_selector_identifier(parts[0]) || !is_valid_selector_identifier(parts[1]) || parts[1] == '*' {
			return none
		}
		return SelectorQualifiedName{
			namespace_type: .named
			namespace_: parts[0]
			name: SelectorName.new(parts[1])
		}
	}
	if !is_valid_selector_identifier(text) {
		return none
	}
	return SelectorQualifiedName{
		namespace_type: .default_
		name: SelectorName.new(text)
	}
}

fn parse_attribute_value_and_case_suffix(text string) (string, AttributeCaseType, bool) {
	trimmed := text.trim_space()
	if trimmed.len == 0 {
		return '', AttributeCaseType.default_match, false
	}
	mut value_text := trimmed
	mut case_type := AttributeCaseType.default_match
	if whitespace_index := last_top_level_whitespace_index(trimmed) {
		suffix := trimmed[whitespace_index..].trim_space()
		if suffix.len != 0 {
			lower_suffix := suffix.to_lower()
			if lower_suffix == 'i' {
				case_type = .case_insensitive_match
				value_text = trimmed[..whitespace_index].trim_space()
			} else if lower_suffix == 's' {
				case_type = .case_sensitive_match
				value_text = trimmed[..whitespace_index].trim_space()
			} else {
				return '', AttributeCaseType.default_match, false
			}
		}
	}
	if value_text.len == 0 {
		return '', AttributeCaseType.default_match, false
	}
	if selector_is_quoted_string(value_text) {
		return strip_css_string(value_text), case_type, true
	}
	if !is_valid_selector_identifier(value_text) {
		return '', AttributeCaseType.default_match, false
	}
	decoded, consumed := parse_identifier(value_text, 0)
	if consumed != value_text.len {
		return '', AttributeCaseType.default_match, false
	}
	return decoded, case_type, true
}

fn parse_pseudo_selector(text string, start int) ParsedSimpleSelector {
	mut i := start + 1
	mut is_pseudo_element := false
	if i < text.len && text[i] == `:` {
		is_pseudo_element = true
		i++
	}
	name, mut next := parse_identifier(text, i)
	mut argument := ''
	mut is_function := false
	if next < text.len && text[next] == `(` {
		is_function = true
		argument, next = read_balanced(text, next, `(`, `)`)
	}

	if is_pseudo_element {
		return ParsedSimpleSelector{
			selector: parse_pseudo_element_selector(name, argument, is_function)
			next: next
		}
	}

	pseudo_element := pseudo_element_from_string(name)
	if pseudo_element != .unknown && !is_function && pseudo_element in [.before, .after, .first_line,
		.first_letter] {
		return ParsedSimpleSelector{
			selector: parse_pseudo_element_selector(name, argument, false)
			next: next
		}
	}

	return ParsedSimpleSelector{
		selector: parse_pseudo_class_selector(name, argument, is_function)
		next: next
	}
}

fn parse_pseudo_element_selector(name string, argument string, is_function bool) SimpleSelector {
	pseudo_element := pseudo_element_from_string(name)
	if pseudo_element == .unknown || (pseudo_element == .unknown_webkit && is_function) {
		return invalid_simple_selector(if is_function {
			'::${name}(${argument})'
		} else {
			'::${name}'
		})
	}
	if is_function {
		if !pseudo_element_valid_as_function(pseudo_element) || argument.trim_space().len == 0 {
			return invalid_simple_selector('::${name}(${argument})')
		}
	} else if !pseudo_element_valid_as_identifier(pseudo_element) {
		return invalid_simple_selector('::${name}')
	}
	is_aliased_pseudo := aliased_pseudo_element_from_string(name) != .unknown
	mut selector := PseudoElementSelector{
		type_: pseudo_element
		name: if pseudo_element == .unknown_webkit || is_aliased_pseudo {
			name.to_lower()
		} else {
			''
		}
	}
	if is_function {
		match pseudo_element {
			.highlight {
				arg := argument.trim_space()
    if arg == '*' {
     selector.value_kind = .pt_name_selector
     selector.pt_name_selector = PseudoElementPTNameSelector{is_universal:true}
    } else {
				if !is_valid_selector_identifier(arg) { return invalid_simple_selector('::${name}(${argument})') }
				ident,consumed := parse_identifier(arg,0)
				if consumed != arg.len || ident.to_lower() in ['initial','inherit','unset','revert','revert-layer','default'] { return invalid_simple_selector('::${name}(${argument})') }
				selector.value_kind = .ident_list
				selector.ident_list = [ident]
    }
			}
			.slotted {
				if !selector_text_is_valid_compound(argument.trim_space()) {
					return invalid_simple_selector('::${name}(${argument})')
				}
				selector.value_kind = .compound_selector
				selector.compound_selector = selector_from_text_impl(argument.trim_space())
			}
			.part {
				idents := split_selector_whitespace(argument)
				if idents.len == 0 {
					return invalid_simple_selector('::${name}(${argument})')
				}
				for ident in idents {
					if !is_valid_selector_identifier(ident) {
						return invalid_simple_selector('::${name}(${argument})')
					}
				}
				selector.value_kind = .ident_list
				selector.ident_list = idents
			}
			.view_transition_group, .view_transition_image_pair, .view_transition_old, .view_transition_new {
				selector.value_kind = .pt_name_selector
				arg := argument.trim_space()
				if arg != '*' && !is_valid_selector_identifier(arg) {
					return invalid_simple_selector('::${name}(${argument})')
				}
				selector.pt_name_selector = PseudoElementPTNameSelector{
					is_universal: arg == '*'
					value: arg
				}
			}
			else {
				selector.value_kind = .ident_list
				selector.ident_list = split_selector_whitespace(argument)
			}
		}
	}
	return SimpleSelector.with_pseudo_element(.pseudo_element, selector)
}

fn invalid_simple_selector(text string) SimpleSelector {
	return SimpleSelector.with_invalid_text(.invalid, text)
}

fn parse_pseudo_class_selector(name string, argument string, is_function bool) SimpleSelector {
	pseudo_class_type := pseudo_class_from_string(name)
	if pseudo_class_type == .invalid {
		return invalid_simple_selector(if is_function {
			':${name}(${argument})'
		} else {
			':${name}'
		})
	}
	if is_function {
		if !pseudo_class_valid_as_function(pseudo_class_type) || argument.trim_space().len == 0 {
			return invalid_simple_selector(':${name}(${argument})')
		}
	} else if !pseudo_class_valid_as_identifier(pseudo_class_type) {
		return invalid_simple_selector(':${name}')
	}
	mut pseudo_class := PseudoClassSelector{
		type_: pseudo_class_type
	}
	match pseudo_class_type {
		.has {
			if !selector_list_text_is_valid_for_standard(argument, true) {
				return invalid_simple_selector(':${name}(${argument})')
			}
			pseudo_class.argument_selector_list = selector_list_from_text(argument, true)
		}
		.host {
			if is_function {
				if !selector_text_is_valid_compound(argument.trim_space()) {
					return invalid_simple_selector(':${name}(${argument})')
				}
				pseudo_class.argument_selector_list = selector_list_from_text(argument, false)
			}
		}
		.is_, .where, .not_ {
			if pseudo_class_type == .not_ && !selector_list_text_is_valid_for_standard(argument, false) {
				return invalid_simple_selector(':${name}(${argument})')
			}
			pseudo_class.is_forgiving = pseudo_class_type in [.is_, .where]
			pseudo_class.argument_selector_list = selector_list_from_text(argument, false)
			if pseudo_class_type == .not_ {
				for argument_selector in pseudo_class.argument_selector_list.selectors {
					for compound in argument_selector.compound_selectors() {
						for simple in compound.simple_selectors {
							if simple.type_ == .pseudo_element { return invalid_simple_selector(':${name}(${argument})') }
						}
					}
				}
			}
		}
		.nth_child, .nth_last_child, .nth_of_type, .nth_last_of_type {
			has_of_selector := top_level_ascii_word_index(argument, 'of') != none
			anb, selector_list_text := split_an_plus_b_of_selector(argument)
			pseudo_class.an_plus_b_pattern = parse_an_plus_b(anb) or {
				return invalid_simple_selector(':${name}(${argument})')
			}
			if has_of_selector {
				if pseudo_class_type !in [.nth_child, .nth_last_child] {
					return invalid_simple_selector(':${name}(${argument})')
				}
				if selector_list_text.len == 0 || !selector_list_text_is_valid_for_standard(selector_list_text, false) {
					return invalid_simple_selector(':${name}(${argument})')
				}
				pseudo_class.argument_selector_list = selector_list_from_text(selector_list_text, false)
			}
		}
		.lang {
			for language in split_selector_list_text(argument) {
				trimmed := language.trim_space()
				if !selector_is_quoted_string(trimmed) && !is_valid_selector_identifier(trimmed) {
					return invalid_simple_selector(':${name}(${argument})')
				}
				pseudo_class.languages << strip_css_string(trimmed)
			}
		}
		.dir, .state {
			ident := argument.trim_space()
			if !is_valid_selector_identifier(ident) {
				return invalid_simple_selector(':${name}(${argument})')
			}
			pseudo_class.ident = PseudoClassIdent{
				keyword: direction_keyword_from_string(ident)
				string_value: ident
			}
		}
		.heading {
			for part in split_selector_list_text(argument) {
				trimmed := part.trim_space()
				if trimmed.len != 0 {
					level := parse_selector_signed_integer(trimmed) or {
						return invalid_simple_selector(':${name}(${argument})')
					}
					pseudo_class.levels << i64(level)
				}
			}
		}
		else {}
	}

	return SimpleSelector.with_pseudo_class(SimpleSelectorType.pseudo_class, pseudo_class)
}

fn pseudo_class_valid_as_function(pseudo_class PseudoClass) bool {
	return pseudo_class in [.dir, .has, .heading, .host, .is_, .lang, .not_, .nth_child,
		.nth_last_child, .nth_of_type, .nth_last_of_type, .state, .where]
}

fn pseudo_class_valid_as_identifier(pseudo_class PseudoClass) bool {
	if pseudo_class == .invalid {
		return false
	}
	return !pseudo_class_valid_as_function(pseudo_class) || pseudo_class in [.heading, .host]
}

fn pseudo_element_valid_as_function(pseudo_element PseudoElement) bool {
	return pseudo_element in [.highlight, .part, .slotted, .view_transition_group, .view_transition_image_pair,
		.view_transition_old, .view_transition_new]
}

fn pseudo_element_valid_as_identifier(pseudo_element PseudoElement) bool {
	if pseudo_element in [.unknown, .highlight, .part, .slotted, .view_transition_group,
		.view_transition_image_pair, .view_transition_old, .view_transition_new] {
		return false
	}
	return true
}

fn selector_list_text_is_valid_for_standard(text string, relative bool) bool {
	parts := split_selector_list_text(text)
	if parts.len == 0 {
		return false
	}
	for part in parts {
		trimmed := part.trim_space()
		if trimmed.len == 0 || selector_text_has_invalid_simple_selectors(trimmed, relative) {
			return false
		}
	}
	return true
}

fn selector_text_has_invalid_simple_selectors(text string, relative bool) bool {
	return parsed_selector_has_invalid_simple_selectors(text, parse_complex_selector(text), relative)
}

fn parsed_selector_has_invalid_simple_selectors(text string, compound_selectors []CompoundSelector, relative bool) bool {
	if selector_text_has_bad_top_level_combinators(text, relative) {
		return true
	}
	if compound_selectors.len == 0 {
		return true
	}
	if !relative && compound_selectors[0].combinator != .no_combinator {
		return true
	}

	mut pseudo_element_count := 0
	mut first_pseudo_element := PseudoElement.unknown
	mut second_pseudo_element := PseudoElement.unknown
	for compound_index, compound_selector in compound_selectors {
		if compound_selector.simple_selectors.len == 0 {
			return true
		}
		for simple_index, simple_selector in compound_selector.simple_selectors {
			match simple_selector.type_ {
				.invalid {
					return true
				}
				.class, .id {
					if simple_selector.name().name.len == 0 {
						return true
					}
				}
				.tag_name, .universal {
					if simple_selector.qualified_name().name.name.len == 0 || simple_index != 0 {
						return true
					}
				}
				.attribute {
					if simple_selector.attribute().qualified_name.name.name.len == 0 {
						return true
					}
				}
				.pseudo_element {
					pseudo := simple_selector.pseudo_element().type_
					if pseudo in [.selection, .highlight, .target_text, .spelling_error, .grammar_error, .search_text]
						&& !highlight_selector_suffix_is_valid(pseudo, compound_selector.simple_selectors[simple_index + 1..]) { return true }
					pseudo_element_count++
					if pseudo_element_count == 1 {
						first_pseudo_element = simple_selector.pseudo_element().type_
					} else if pseudo_element_count == 2 {
						second_pseudo_element = simple_selector.pseudo_element().type_
					}
					if compound_index != compound_selectors.len - 1 {
						return true
					}
				}
				else {}
			}
		}
	}
	if pseudo_element_count > 1 {
		is_valid_chain := pseudo_element_count == 2 && first_pseudo_element == .part
			&& second_pseudo_element != .part
		if !is_valid_chain {
			return true
		}
	}
	return false
}

fn selector_text_has_bad_top_level_combinators(text string, relative bool) bool {
	mut quote := u8(0)
	mut parens := 0
	mut squares := 0
	mut saw_compound_token := false
	mut expecting_compound_after_combinator := false
	mut i := 0
	for i < text.len {
		ch := text[i]
		if quote != 0 {
			if ch == `\\` && i + 1 < text.len {
				i += 2
				continue
			}
			if ch == quote {
				quote = 0
			}
			i++
			continue
		}
		match ch {
			`"`, `'` {
				quote = ch
				saw_compound_token = true
				expecting_compound_after_combinator = false
				i++
			}
			`(` {
				parens++
				saw_compound_token = true
				expecting_compound_after_combinator = false
				i++
			}
			`)` {
				parens--
				i++
			}
			`[` {
				squares++
				saw_compound_token = true
				expecting_compound_after_combinator = false
				i++
			}
			`]` {
				squares--
				i++
			}
			`\\` {
				// An escaped code point belongs to an identifier, even when it
				// spells a combinator or bracket (`.mobileOnly\+`).
				saw_compound_token = true
				expecting_compound_after_combinator = false
				i += if i + 1 < text.len { 2 } else { 1 }
			}
			else {
				if parens == 0 && squares == 0 && is_combinator_start(text, i) {
					if (!relative && !saw_compound_token) || expecting_compound_after_combinator {
						return true
					}
					expecting_compound_after_combinator = true
					i += if text[i] == `|` { 2 } else { 1 }
					continue
				}
				if !is_ascii_whitespace_byte(ch) {
					saw_compound_token = true
					expecting_compound_after_combinator = false
				}
				i++
			}
		}
	}
	return expecting_compound_after_combinator
}

fn selector_list_from_text(text string, relative bool) SelectorList {
	mut list := SelectorList{}
	for part in split_selector_list_text(text) {
		trimmed := part.trim_space()
		if trimmed.len == 0 {
			continue
		}
		mut selector := selector_from_text_impl(trimmed)
		if relative {
			// Parser::parse_complex_selector(): parse_compound_selector() leaves the
			// leading combinator as Descendant, and only SelectorType::Standalone
			// resets it to None. A relative selector written without an explicit
			// combinator - `:has(.a)` - is therefore a *descendant* relative
			// selector; leaving it as no-combinator made it match nothing.
			compound_selectors := selector.compound_selectors()
			if compound_selectors.len > 0 && compound_selectors[0].combinator == .no_combinator {
				mut adapted := compound_selectors.clone()
				adapted[0].combinator = .descendant
				selector = selector_from_compound_selectors(adapted)
			}
		}
		list.selectors << selector
	}
	return list
}

fn parse_an_plus_b(text string) ?ANPlusBPattern {
	mut input := text.to_lower().replace(' ', '').replace('\t', '').replace('\n', '')
	if input == 'odd' {
		return ANPlusBPattern{
			step_size: 2
			offset: 1
		}
	}
	if input == 'even' {
		return ANPlusBPattern{
			step_size: 2
		}
	}
	if !input.contains('n') {
		offset := parse_selector_signed_integer(input) or { return none }
		return ANPlusBPattern{
			offset: offset
		}
	}
	n_index := input.index('n') or { -1 }
	if n_index < 0 || input[n_index + 1..].contains('n') {
		return none
	}
	a_text := input[..n_index]
	b_text := input[n_index + 1..]
	step_size := match a_text {
		'', '+' { 1 }
		'-' { -1 }
		else { parse_selector_signed_integer(a_text) or { return none } }
	}

	offset := if b_text.len == 0 {
		0
	} else {
		if !(b_text.starts_with('+') || b_text.starts_with('-')) {
			return none
		}
		parse_selector_signed_integer(b_text) or { return none }
	}
	return ANPlusBPattern{
		step_size: step_size
		offset: offset
	}
}

fn parse_selector_signed_integer(text string) ?int {
	if text.len == 0 {
		return none
	}
	if text == '+' || text == '-' {
		return none
	}
	start := if text[0] == `+` || text[0] == `-` { 1 } else { 0 }
	for i := start; i < text.len; i++ {
		if text[i] < `0` || text[i] > `9` {
			return none
		}
	}
	return strconv.atoi(text) or { none }
}

fn split_an_plus_b_of_selector(argument string) (string, string) {
	idx := top_level_ascii_word_index(argument, 'of') or { return argument.trim_space(), '' }
	return argument[..idx].trim_space(), argument[idx + 2..].trim_space()
}

fn serialize_compound_selectors_raw(compound_selectors []CompoundSelector) string {
	mut builder := strings.new_builder(32)
	for i, compound_selector in compound_selectors {
		if i != 0 {
			builder.write_u8(` `)
			match compound_selector.combinator {
				.immediate_child { builder.write_string('> ') }
				.next_sibling { builder.write_string('+ ') }
				.subsequent_sibling { builder.write_string('~ ') }
				.column { builder.write_string('|| ') }
				else {}
			}
		} else {
			match compound_selector.combinator {
				.immediate_child { builder.write_string('> ') }
				.next_sibling { builder.write_string('+ ') }
				.subsequent_sibling { builder.write_string('~ ') }
				.column { builder.write_string('|| ') }
				else {}
			}
		}
		for simple_selector in compound_selector.simple_selectors {
			builder.write_string(simple_selector.serialize())
		}
	}
	return builder.str()
}

fn can_selector_use_fast_matches(selector Selector) bool {
	for compound_selector in selector.compound_selectors() {
		if compound_selector.combinator !in [.no_combinator, .descendant, .immediate_child] {
			return false
		}

		for simple_selector in compound_selector.simple_selectors {
			if simple_selector.type_ == .pseudo_class {
				pseudo_class := simple_selector.pseudo_class().type_
				if pseudo_class !in [.active, .any_link, .autofill, .checked, .disabled, .empty,
					.enabled, .first_child, .focus, .focus_visible, .focus_within, .hover,
					.last_child, .link, .local_link, .only_child, .root, .state, .unchecked, .visited] {
					return false
				}
			} else if simple_selector.type_ !in [.tag_name, .universal, .class, .id, .attribute] {
				return false
			}
		}
	}

	return true
}

fn selector_ancestor_hashes(selector Selector) ([8]u32, bool) {
	return selector_ancestor_hashes_with_name_case(selector, false)
}

fn selector_ancestor_hashes_with_name_case(selector Selector, fold_id_and_class_name_case bool) ([8]u32, bool) {
	mut ancestor_hashes := [8]u32{}
	if selector.is_slotted() {
		// Ancestor filtering is not supported for slotted selectors, because those
		// are supposed to be collected for element inside a slot, while being
		// matched against slot element.
		return ancestor_hashes, false
	}

	compound_selectors := selector.compound_selectors()
	if compound_selectors.len == 0 {
		return ancestor_hashes, false
	}

	mut next_hash_index := 0
	mut combinator_to_right := compound_selectors[compound_selectors.len - 1].combinator

	for i := compound_selectors.len - 2; i >= 0; i-- {
		compound_selector := compound_selectors[i]
		match combinator_to_right {
			.descendant, .immediate_child {
				append_result := append_hashes_from_compound(compound_selector, ancestor_hashes, next_hash_index, fold_id_and_class_name_case)
				ancestor_hashes = append_result.ancestor_hashes
				next_hash_index = append_result.next_hash_index
				if append_result.is_full {
					return ancestor_hashes, next_hash_index > 0
				}
			}
			.next_sibling, .subsequent_sibling {
				// The compound immediately to the left is a sibling constraint, not an ancestor.
				// Do not collect hashes from it.
			}
			.column, .no_combinator {
				return [8]u32{}, false
			}
		}

		combinator_to_right = compound_selector.combinator
	}

	return ancestor_hashes, next_hash_index > 0
}

struct AppendHashResult {
mut:
	ancestor_hashes [8]u32
	next_hash_index int
	is_full         bool
}

fn append_hashes_from_compound(compound_selector CompoundSelector, ancestor_hashes [8]u32, next_hash_index int, fold_id_and_class_name_case bool) AppendHashResult {
	mut result := AppendHashResult{
		ancestor_hashes: ancestor_hashes
		next_hash_index: next_hash_index
	}
	for simple_selector in compound_selector.simple_selectors {
		match simple_selector.type_ {
			.id, .class {
				result = append_unique_hash(selector_string_hash(if fold_id_and_class_name_case { to_ascii_lowercase(simple_selector.name().name) } else { simple_selector.name().name }), result.ancestor_hashes, result.next_hash_index)
				if result.is_full {
					return result
				}
			}
			.tag_name {
				result = append_unique_hash(selector_string_hash(simple_selector.qualified_name().name.lowercase_name), result.ancestor_hashes, result.next_hash_index)
				if result.is_full {
					return result
				}
			}
			.attribute {
				result = append_unique_hash(selector_string_hash(simple_selector.attribute().qualified_name.name.lowercase_name), result.ancestor_hashes, result.next_hash_index)
				if result.is_full {
					return result
				}
			}
			else {}
		}
	}
	return result
}

fn append_unique_hash(hash u32, ancestor_hashes [8]u32, next_hash_index int) AppendHashResult {
	mut result := AppendHashResult{
		ancestor_hashes: ancestor_hashes
		next_hash_index: next_hash_index
	}
	if next_hash_index >= selector_ancestor_hash_count {
		result.is_full = true
		return result
	}
	for i := 0; i < next_hash_index; i++ {
		if ancestor_hashes[i] == hash {
			return result
		}
	}
	result.ancestor_hashes[next_hash_index] = hash
	result.next_hash_index++
	return result
}

fn selector_contained_pseudo_classes_uncached(compound_selectors []CompoundSelector) PseudoClassBitmap {
	mut bitmap := PseudoClassBitmap{}
	for compound_selector in compound_selectors {
		for simple_selector in compound_selector.simple_selectors {
			if simple_selector.type_ == .pseudo_class {
				bitmap.set(simple_selector.pseudo_class().type_, true)
				for child_selector in simple_selector.pseudo_class().argument_selector_list.selectors {
					if child_selector.data_ != unsafe { nil } {
						bitmap.merge(child_selector.data_.contained_pseudo_classes)
					} else {
						bitmap.merge(selector_contained_pseudo_classes_uncached(child_selector.compound_selectors()))
					}
				}
			}
		}
	}
	return bitmap
}

fn contains_invalid_contents_for_has(selector Selector) bool {
	// :has() has special validity rules:
	// - It can't appear inside itself
	// - It bans most pseudo-elements
	// https://drafts.csswg.org/selectors/#relational
	for compound_selector in selector.compound_selectors() {
		for simple_selector in compound_selector.simple_selectors {
			if simple_selector.type_ == .pseudo_element {
				if !is_has_allowed_pseudo_element(simple_selector.pseudo_element().type_) {
					return true
				}
			}
			if simple_selector.type_ == .pseudo_class {
				if simple_selector.pseudo_class().type_ == .has {
					return true
				}
				for child_selector in simple_selector.pseudo_class().argument_selector_list.selectors {
					if contains_invalid_contents_for_has(child_selector) {
						return true
					}
				}
			}
		}
	}

	return false
}

pub fn (selector Selector) absolutized(selector_for_nesting SimpleSelector) ?Selector {
	if !selector.contains_the_nesting_selector() {
		return selector
	}
	mut absolutized_compound_selectors := []CompoundSelector{cap: selector.compound_selectors().len}
	for compound_selector in selector.compound_selectors() {
		if absolutized := compound_selector.absolutized(selector_for_nesting) {
			absolutized_compound_selectors << absolutized
		} else {
			return none
		}
	}
	return selector_from_compound_selectors(absolutized_compound_selectors)
}

// Upward traversal for descendant (' ') and immediate child combinator ('>')
// If we're starting inside a shadow tree, traversal stops at the nearest shadow host.
// This is an implementation detail of the :host selector. Otherwise we would just traverse up to the document root.
fn traverse_up(node &dom.Node, shadow_host ?&dom.Element) ?&dom.Node {
	if host := shadow_host {
		// NOTE: We only traverse up to the shadow host, not beyond.
		if node.is_same_node(host.as_node()) {
			return none
		}
		return parent_or_shadow_host_element_node(node)
	}
	return node.parent()
}

// https://www.rfc-editor.org/rfc/rfc4647.html#section-3.3.2
// NB: Language tags only use ASCII characters, so we can get away with using StringView.
fn language_range_matches_tag(language_range string, language_tag string) bool {
	// 1. Split both the extended language range and the language tag being compared into a list of subtags by
	//    dividing on the hyphen (%x2D) character.
	range_subtags := language_range.split('-')
	tag_subtags := language_tag.split('-')
	if range_subtags.len == 0 || tag_subtags.len == 0 {
		return false
	}

	//    Two subtags match if either they are the same when compared case-insensitively or the language range's subtag
	//    is the wildcard '*'.
	subtags_match := fn (language_range_subtag string, language_subtag string) bool {
		return language_range_subtag == '*' || equals_ignoring_ascii_case(language_range_subtag, language_subtag)
	}

	// 2. Begin with the first subtag in each list. If the first subtag in the range does not match the first
	//    subtag in the tag, the overall match fails. Otherwise, move to the next subtag in both the range and the
	//    tag.
	if !subtags_match(range_subtags[0], tag_subtags[0]) {
		return false
	}
	mut tag_index := 1
	mut range_index := 1

	// 3. While there are more subtags left in the language range's list:
	for range_index < range_subtags.len {
		// A. If the subtag currently being examined in the range is the wildcard ('*'), move to the next subtag in
		//    the range and continue with the loop.
		if range_subtags[range_index] == '*' {
			range_index++
			continue
		}

		// B. Else, if there are no more subtags in the language tag's list, the match fails.
		if tag_index >= tag_subtags.len {
			return false
		}

		// C. Else, if the current subtag in the range's list matches the current subtag in the language tag's
		//    list, move to the next subtag in both lists and continue with the loop.
		if subtags_match(range_subtags[range_index], tag_subtags[tag_index]) {
			range_index++
			tag_index++
			continue
		}

		// D. Else, if the language tag's subtag is a "singleton" (a single letter or digit, which includes the
		//    private-use subtag 'x') the match fails.
		if tag_subtags[tag_index].len == 1 && is_ascii_alphanumeric_byte(tag_subtags[tag_index][0]) {
			return false
		}

		// E. Else, move to the next subtag in the language tag's list and continue with the loop.
		tag_index++
	}

	// 4. When the language range's list has no more subtags, the match succeeds.
	return true
}

// https://drafts.csswg.org/selectors-4/#the-lang-pseudo
fn matches_lang_pseudo_class(element &dom.Element, languages []string) bool {
	maybe_element_language := element.lang()
	element_language := maybe_element_language or { return false }

	// The element’s content language matches a language range if its content language, as represented in BCP 47
	// syntax, matches the given language range in an extended filtering operation per [RFC4647] Matching of Language
	// Tags (section 3.3.2). Both the content language and the language range must be canonicalized and converted to
	// extlang form as per section 4.5 of [RFC5646] prior to the extended filtering operation. The matching is
	// performed case-insensitively within the ASCII range.

	// FIXME: Canonicalize both as extlang.
	for language_range in languages {
		if language_range_matches_tag(language_range, element_language) {
			return true
		}
	}
	return false
}

// https://drafts.csswg.org/selectors-4/#relational
fn matches_relative_selector(selector Selector, compound_index int, element &dom.Element, shadow_host ?&dom.Element, mut context MatchContext, anchor &dom.Element, scope ?&dom.ParentNode) bool {
	compound_selectors := selector.compound_selectors()
	if compound_index >= compound_selectors.len {
		return matches(selector, element, shadow_host, mut context, none, scope, .relative, anchor)
	}

	match compound_selectors[compound_index].combinator {
		.no_combinator {
			// Shouldn't be possible because we've parsed relative selectors, which always have a combinator, implicitly or explicitly.
			return false
		}
		.descendant {
			return has_matching_descendant_for_relative(selector, element.as_node(), shadow_host, mut context, anchor, scope)
		}
		.immediate_child {
			mut has := false
			for child in element.as_node().children {
				child_element := child.as_element() or { continue }
				if context.inside_has_argument_match
					&& context.collect_per_element_selector_involvement_metadata {
					mut mutable_child := unsafe { &dom.Element(child_element) }
					mutable_child.set_in_has_scope(true)
				}
				if !matches_selector_at(selector, compound_index, child_element, shadow_host, mut context, scope, .relative, anchor) {
					continue
				}
				if matches_relative_selector(selector, compound_index + 1, child_element, shadow_host, mut context, anchor, scope) {
					has = true
					break
				}
			}
			return has
		}
		.next_sibling {
			if context.collect_per_element_selector_involvement_metadata {
				mut mutable_anchor := unsafe { &dom.Element(anchor) }
				mutable_anchor.affected_by_has_pseudo_class_with_relative_selector_that_has_sibling_combinator = true
			}
			sibling := next_element_sibling(element) or { return false }
			if context.inside_has_argument_match
				&& context.collect_per_element_selector_involvement_metadata {
				mut mutable_sibling := unsafe { &dom.Element(sibling) }
				mutable_sibling.set_in_has_scope(true)
				mutable_sibling.set_in_subtree_of_has_pseudo_class_relative_selector_with_sibling_combinator(true)
			}
			if !matches_selector_at(selector, compound_index, sibling, shadow_host, mut context, scope, .relative, anchor) {
				return false
			}
			return matches_relative_selector(selector, compound_index + 1, sibling, shadow_host, mut context, anchor, scope)
		}
		.subsequent_sibling {
			if context.collect_per_element_selector_involvement_metadata {
				mut mutable_anchor := unsafe { &dom.Element(anchor) }
				mutable_anchor.affected_by_has_pseudo_class_with_relative_selector_that_has_sibling_combinator = true
			}
			mut sibling := next_element_sibling(element)
			for sibling != none {
				sibling_element := sibling or { break }
				if context.inside_has_argument_match
					&& context.collect_per_element_selector_involvement_metadata {
					mut mutable_sibling := unsafe { &dom.Element(sibling_element) }
					mutable_sibling.set_in_has_scope(true)
					mutable_sibling.set_in_subtree_of_has_pseudo_class_relative_selector_with_sibling_combinator(true)
				}
				if matches_selector_at(selector, compound_index, sibling_element, shadow_host, mut context, scope, .relative, anchor) && matches_relative_selector(selector, compound_index + 1, sibling_element, shadow_host, mut context, anchor, scope) {
					return true
				}
				sibling = next_element_sibling(sibling_element)
			}
			return false
		}
		.column {
			// FIXME: Column combinator matching requires table-column layout hooks.
			return false
		}
	}
}

fn has_matching_descendant_for_relative(selector Selector, node &dom.Node, shadow_host ?&dom.Element, mut context MatchContext, anchor &dom.Element, scope ?&dom.ParentNode) bool {
	if voidptr(node) == voidptr(anchor.as_node()) {
		if compound := static_has_descendant_compound(selector, shadow_host, context) {
			return has_static_matching_descendant(compound, node, mut context)
		}
	}
	for child in node.children {
		if descendant_element := child.as_element() {
			if context.inside_has_argument_match
				&& context.collect_per_element_selector_involvement_metadata {
				mut mutable_descendant := unsafe { &dom.Element(descendant_element) }
				mutable_descendant.set_in_has_scope(true)
			}
			if matches(selector, descendant_element, shadow_host, mut context, none, scope, .relative, anchor) {
				return true
			}
		}
		if child.children.len > 0
			&& has_matching_descendant_for_relative(selector, child, shadow_host, mut context, anchor, scope) {
			return true
		}
	}
	return false
}

// https://drafts.csswg.org/selectors-4/#relational
fn has_result_cache_key(selector Selector, anchor &dom.Element) string {
	return '${selector.text()}\x00${anchor.as_node().unique_id()}'
}

fn matches_has_pseudo_class(selector Selector, anchor &dom.Element, shadow_host ?&dom.Element, mut context MatchContext, scope ?&dom.ParentNode) bool {
	if context.has_result_cache == unsafe { nil } {
		context.has_result_cache = &HasResultCache{}
	}
	cache_key := has_result_cache_key(selector, anchor)
	if cached := context.has_result_cache.results[cache_key] {
		context.attempted_pseudo_class_matches.merge(context.has_result_cache.attempted_pseudo_classes[cache_key])
		record_has_argument_for_invalidation(selector,anchor,shadow_host,context,scope,cached == .matched,
			context.has_result_cache.attempted_pseudo_classes[cache_key])
		return cached == .matched
	}

	saved_inside_has := context.inside_has_argument_match
	saved_attempts := context.attempted_pseudo_class_matches
	context.attempted_pseudo_class_matches = PseudoClassBitmap{}
	context.inside_has_argument_match = true
	result := matches_relative_selector(selector, 0, anchor, shadow_host, mut context, anchor, scope)
	context.inside_has_argument_match = saved_inside_has
	context.has_result_cache.attempted_pseudo_classes[cache_key] = context.attempted_pseudo_class_matches
	context.attempted_pseudo_class_matches.merge(saved_attempts)
	context.has_result_cache.results[cache_key] = if result {
		HasMatchResult.matched
	} else {
		HasMatchResult.not_matched
	}
	record_has_argument_for_invalidation(selector,anchor,shadow_host,context,scope,result,
		context.has_result_cache.attempted_pseudo_classes[cache_key])
	return result
}

fn matches_hover_pseudo_class(element &dom.Element) bool {
	hovered_node := element.document().get_hovered_node() or { return false }
	if element.as_node().is_same_node(hovered_node) {
		return true
	}
	return element.as_node().is_shadow_including_ancestor_of(hovered_node)
}

// https://html.spec.whatwg.org/multipage/semantics-other.html#selector-indeterminate
fn matches_indeterminate_pseudo_class(element &dom.Element) bool {
	// The :indeterminate pseudo-class must match any element falling into one of the following categories:
	// - input elements whose type attribute is in the Checkbox state and whose indeterminate IDL attribute is set to true
	// FIXME: - input elements whose type attribute is in the Radio Button state and whose radio button group contains no input elements whose checkedness state is true.
	if element.local_name() == 'input'
		&& element.get_attribute_value('type').trim_space().to_lower() == 'checkbox' {
		input := unsafe { &dom.HTMLInputElement(element) }
		return input.indeterminate() && !element.has_attribute('switch')
	}
	// - progress elements with no value content attribute
	if element.local_name() == 'progress' {
		return !element.has_attribute('value')
	}
	return false
}

fn matches_optimal_value_pseudo_class(element &dom.Element, desired_state PseudoClass) bool {
	if !element.is_html_element() || element.local_name() != 'meter' {
		return false
	}

	meter := unsafe { &dom.HTMLMeterElement(element) }
	return match desired_state {
		.optimal_value { meter.cached_value_state_ == 0 }
		.suboptimal_value { meter.cached_value_state_ == 1 }
		.even_less_good_value { meter.cached_value_state_ == 2 }
		else { false }
	}
}

enum SelectorCaseSensitivity {
	case_sensitive
	case_insensitive
}

@[inline]
fn selector_attribute_case_sensitivity(attribute SelectorAttribute, element &dom.Element) SelectorCaseSensitivity {
	attribute_name := attribute.qualified_name.name.name

	return match attribute.case_type {
		.case_insensitive_match {
			SelectorCaseSensitivity.case_insensitive
		}
		.case_sensitive_match {
			SelectorCaseSensitivity.case_sensitive
		}
		.default_match {
			// See: https://html.spec.whatwg.org/multipage/semantics-other.html#case-sensitivity-of-selectors
			if element.document() != unsafe { nil } && element.document().is_html_document() && element.namespace_uri() or {
				''
			} == selector_html_namespace && attribute.qualified_name.namespace_type == .default_ && selector_html_attribute_is_case_insensitive(attribute_name) {
				SelectorCaseSensitivity.case_insensitive
			} else {
				SelectorCaseSensitivity.case_sensitive
			}
		}
	}
}

fn matches_attribute(attribute SelectorAttribute, style_sheet_for_rule ?&CSSStyleSheet, element &dom.Element) bool {
	return matches_attribute_in_namespace(attribute, style_sheet_for_rule, element,
		selector_attribute_case_sensitivity(attribute, element))
}

fn matches_attribute_in_namespace(attribute_selector SelectorAttribute,
	style_sheet_for_rule ?&CSSStyleSheet, element &dom.Element,
	case_sensitivity SelectorCaseSensitivity) bool {
	qualified_name := attribute_selector.qualified_name
	attribute_name := qualified_name.name.name

	match qualified_name.namespace_type {
		.default_, .none {
			// "In keeping with the Namespaces in the XML recommendation, default namespaces do not apply to attributes,
			//  therefore attribute selectors without a namespace component apply only to attributes that have no namespace (equivalent to "|attr")"
			if attribute := element.get_attribute_node(attribute_name) {
				return matches_single_attribute(attribute_selector, attribute, case_sensitivity)
			}
		}
		.any {
			// When comparing the name part of a CSS attribute selector to the names of attributes on HTML elements in HTML
			// documents, the name part of the CSS attribute selector must first be converted to ASCII lowercase. The same
			// selector when compared to other attributes must be compared according to its original case. In both cases, the
			// comparison is case-sensitive.
			// https://html.spec.whatwg.org/multipage/semantics-other.html#case-sensitivity-of-selectors
			case_insensitive := element.document() != unsafe { nil } && element.document().is_html_document() && element.namespace_uri() or {
				''
			} == selector_html_namespace

			if attrs := element.attributes_ {
				for i := 0; i < attrs.length(); i++ {
					attr := attrs.item(i) or { continue }
					is_match := if case_insensitive {
						attr.local_name_ == qualified_name.name.lowercase_name
					} else {
						attr.local_name_ == attribute_name
					}
					if is_match && matches_single_attribute(attribute_selector, attr, case_sensitivity) {
						return true
					}
				}
			}
		}
		.named {
			sheet := style_sheet_for_rule or { return false }
			selector_namespace := sheet.namespace_uri(qualified_name.namespace_) or {
				return false
			}
			if attribute := element.get_attribute_node_ns(selector_namespace, attribute_name) {
				return matches_single_attribute(attribute_selector, attribute, case_sensitivity)
			}
		}
	}

	return false
}

@[inline]
fn matches_single_attribute(attribute_selector SelectorAttribute, attribute &dom.Attr_, case_sensitivity SelectorCaseSensitivity) bool {
	return selector_attribute_matches_value(attribute_selector, attribute.value(), case_sensitivity)
}

// Whether an attribute holding `attribute_value` satisfies the selector's
// value test. The attribute's name and namespace are the caller's concern.
fn selector_attribute_matches_value(attribute_selector SelectorAttribute, attribute_value string, case_sensitivity SelectorCaseSensitivity) bool {
	case_insensitive_match := case_sensitivity == .case_insensitive
	match attribute_selector.match_type {
		.exact_value_match {
			return if case_insensitive_match {
				equals_ignoring_ascii_case(attribute_value, attribute_selector.value)
			} else {
				attribute_value == attribute_selector.value
			}
		}
		.contains_word {
			if attribute_selector.value.len == 0 {
				// This selector is always false is match value is empty.
				return false
			}
			for value in attribute_value.split(' ') {
				if case_insensitive_match {
					if equals_ignoring_ascii_case(value, attribute_selector.value) {
						return true
					}
				} else if value == attribute_selector.value {
					return true
				}
			}
			return false
		}
		.contains_string {
			return attribute_selector.value.len != 0 && selector_string_contains(attribute_value, attribute_selector.value, case_sensitivity)
		}
		.starts_with_segment {
			// https://www.w3.org/TR/CSS2/selector.html#attribute-selectors
			// [att|=val]
			// Represents an element with the att attribute, its value either being exactly "val" or beginning with "val" immediately followed by "-" (U+002D).
			if attribute_value.len == 0 {
				// If the attribute value on element is empty, the selector is true
				// if the match value is also empty and false otherwise.
				return attribute_selector.value.len == 0
			}
			if attribute_selector.value.len == 0 {
				return false
			}

			element_attribute_length := attribute_value.len
			attribute_length := attribute_selector.value.len
			if element_attribute_length < attribute_length {
				return false
			}

			if attribute_length == element_attribute_length {
				return if case_insensitive_match {
					equals_ignoring_ascii_case(attribute_value, attribute_selector.value)
				} else {
					attribute_value == attribute_selector.value
				}
			}

			return selector_string_starts_with(attribute_value, attribute_selector.value, case_sensitivity) && attribute_value[attribute_length] == `-`
		}
		.starts_with_string {
			return attribute_selector.value.len != 0 && selector_string_starts_with(attribute_value, attribute_selector.value, case_sensitivity)
		}
		.ends_with_string {
			return attribute_selector.value.len != 0 && selector_string_ends_with(attribute_value, attribute_selector.value, case_sensitivity)
		}
		.has_attribute {
			return true
		}
	}
}

fn matches_namespace(qualified_name SelectorQualifiedName, element &dom.Element, style_sheet_for_rule ?&CSSStyleSheet) bool {
	match qualified_name.namespace_type {
		.default_ {
			// "if no default namespace has been declared for selectors, this is equivalent to *|E."
			sheet := style_sheet_for_rule or { return true }
			default_namespace := sheet.default_namespace() or { return true }
			// "Otherwise it is equivalent to ns|E where ns is the default namespace."
			return element.namespace_uri() or { '' } == default_namespace
		}
		.none {
			// "elements with name E without a namespace"
			return element.namespace_uri() == none
		}
		.any {
			// "elements with name E in any namespace, including those without a namespace"
			return true
		}
		.named {
			// "elements with name E in namespace ns"
			// Unrecognized namespace prefixes are invalid, so don't match.
			// (We can't detect this at parse time, since a namespace rule may be inserted later.)
			// So, if we don't have a context to look up namespaces from, we fail to match.
			sheet := style_sheet_for_rule or { return false }
			selector_namespace := sheet.namespace_uri(qualified_name.namespace_) or { return false }

			// https://www.w3.org/TR/css-namespaces-3/#terminology
			// In CSS Namespaces a namespace name consisting of the empty string is taken to represent the null namespace
			// or lack of a namespace.
			if selector_namespace.len == 0 {
				return element.namespace_uri() == none
			}

			return element.namespace_uri() or { '' } == selector_namespace
		}
	}
}

fn previous_sibling_with_same_type(element &dom.Element) ?&dom.Element {
	mut sibling := previous_element_sibling(element)
	for sibling != none {
		sibling_element := sibling or { break }
		if sibling_element.local_name() == element.local_name() && optional_string_equal(sibling_element.namespace_uri(), element.namespace_uri()) {
			return sibling_element
		}
		sibling = previous_element_sibling(sibling_element)
	}
	return none
}

fn next_sibling_with_same_type(element &dom.Element) ?&dom.Element {
	mut sibling := next_element_sibling(element)
	for sibling != none {
		sibling_element := sibling or { break }
		if sibling_element.local_name() == element.local_name() && optional_string_equal(sibling_element.namespace_uri(), element.namespace_uri()) {
			return sibling_element
		}
		sibling = next_element_sibling(sibling_element)
	}
	return none
}

/// Returns true if this selector should be blocked from matching against the shadow host from within a shadow tree.
/// Only :host pseudo-class is allowed to match the shadow host from within shadow tree, all other selectors (including other pseudo-classes) are blocked.
/// Compound selectors (:has(), :is(), :where()), nesting, and pseudo-elements are allowed as they may contain or be contained within :host.
fn should_block_shadow_host_matching(component SimpleSelector, shadow_host ?&dom.Element, element &dom.Element) bool {
	host := shadow_host or { return false }
	if voidptr(element) != voidptr(host) {
		return false
	}

	// From within shadow tree, only :host pseudo-class can match the host element
	if component.type_ == .pseudo_class {
		pseudo_class := component.pseudo_class()
		return pseudo_class.type_ != .host && pseudo_class.type_ != .has && pseudo_class.type_ != .is_ && pseudo_class.type_ != .where
	}

	// Allow nesting and PseudoElement as it may contain :host class
	if component.type_ == .nesting || component.type_ == .pseudo_element {
		return false
	}

	return true
}

// https://html.spec.whatwg.org/multipage/semantics-other.html#selector-read-write
fn matches_read_write_pseudo_class(element &dom.Element) bool {
	return element.matches_read_write_pseudo_class()
}

// https://drafts.csswg.org/selectors-4/#open-state
fn matches_open_state_pseudo_class(element &dom.Element, open bool) bool {
	// The :open pseudo-class represents an element that has both “open” and “closed” states,
	// and which is currently in the “open” state.

	// https://html.spec.whatwg.org/multipage/semantics-other.html#selector-open
	// The :open pseudo-class must match any element falling into one of the following categories:
	// - details elements that have an open attribute
	// - dialog elements that have an open attribute
	if element.local_name() in ['details', 'dialog'] {
		return open == element.has_attribute('open')
	}
	// - select elements that are a drop-down box and whose drop-down boxes are open
	if element.local_name() == 'select' {
		select_element := unsafe { &dom.HTMLSelectElement(element) }
		return open == select_element.is_open()
	}
	// - input elements that support a picker and whose pickers are open
	if element.local_name() == 'input' {
		input := unsafe { &dom.HTMLInputElement(element) }
		return input.supports_a_picker() && open == input.is_open()
	}
	return false
}

// https://drafts.csswg.org/css-shadow-1/#host-selector
fn matches_host_pseudo_class(element &dom.Element, shadow_host ?&dom.Element, mut context MatchContext, argument_selector_list SelectorList) bool {
	// When evaluated in the context of a shadow tree, it matches the shadow tree’s shadow host if the shadow host,
	// in its normal context, matches the selector argument. In any other context, it matches nothing.
	host := shadow_host or { return false }
	if voidptr(element) != voidptr(host) {
		return false
	}

	// NOTE: There's either 0 or 1 argument selector, since the syntax is :host or :host(<compound-selector>)
	if argument_selector_list.selectors.len != 0 {
		return matches(argument_selector_list.selectors[0], element, none, mut context, none, none, .normal, none)
	}

	return true
}

fn matches_nth_selector_list(list SelectorList, element &dom.Element, shadow_host ?&dom.Element, mut context MatchContext) bool {
	if list.selectors.len == 0 {
		return true
	}
	for selector in list.selectors {
		if matches(selector, element, shadow_host, mut context, none, none, .normal, none) {
			return true
		}
	}
	return false
}

fn previous_element_sibling(element &dom.Element) ?&dom.Element {
	mut sibling := element.as_node().previous_sibling()
	for sibling != none {
		node := sibling or { break }
		if sibling_element := node.as_element() {
			return sibling_element
		}
		sibling = node.previous_sibling()
	}
	return none
}

fn next_element_sibling(element &dom.Element) ?&dom.Element {
	mut sibling := element.as_node().next_sibling()
	for sibling != none {
		node := sibling or { break }
		if sibling_element := node.as_element() {
			return sibling_element
		}
		sibling = node.next_sibling()
	}
	return none
}

fn parent_element(element &dom.Element) ?&dom.Element {
	return element.as_node().parent_element()
}

fn parent_or_shadow_host_element_node(node &dom.Node) ?&dom.Node {
	if parent := node.parent() {
		if shadow_root := parent.as_shadow_root() {
			if host := shadow_root.host() {
				return host.as_node()
			}
		}
		return parent
	}
	return none
}

fn pseudo_class_accepts_arguments(pseudo_class PseudoClassSelector) bool {
	return match pseudo_class.type_ {
		.has, .is_, .where, .not_, .nth_child, .nth_last_child, .nth_of_type, .nth_last_of_type, .lang, .dir, .state {
			true
		}
		.host {
			pseudo_class.argument_selector_list.selectors.len != 0
		}
		.heading {
			pseudo_class.levels.len != 0
		}
		else {
			false
		}
	}
}

fn split_selector_list_text(text string) []string {
	mut parts := []string{}
	mut depth_paren := 0
	mut depth_square := 0
	mut quote := u8(0)
	mut start := 0
	mut i := 0
	for i < text.len {
		ch := text[i]
		if quote != 0 {
			if ch == `\\` && i + 1 < text.len {
				i += 2
				continue
			}
			if ch == quote {
				quote = 0
			}
			i++
			continue
		}
		if ch == `\\` && i + 1 < text.len {
			// An escaped comma is part of an identifier, not a separator.
			i += 2
			continue
		}
		if ch == `"` || ch == `'` {
			quote = ch
		} else if ch == `(` {
			depth_paren++
		} else if ch == `)` && depth_paren > 0 {
			depth_paren--
		} else if ch == `[` {
			depth_square++
		} else if ch == `]` && depth_square > 0 {
			depth_square--
		} else if ch == `,` && depth_paren == 0 && depth_square == 0 {
			parts << text[start..i]
			start = i + 1
		}
		i++
	}
	parts << text[start..]
	return parts
}

fn split_selector_whitespace(text string) []string {
	mut result := []string{}
	for part in text.trim_space().split(' ') {
		trimmed := part.trim_space()
		if trimmed.len != 0 {
			result << trimmed
		}
	}
	return result
}

// https://drafts.csswg.org/css-syntax/#consume-escaped-code-point
//
// `start` is the index just past the reverse solidus. Returns the escape's
// decoded text and the index just past the sequence. This layer parses
// selectors from text rather than from tokens, so the numeric form has to be
// decoded here or `\\31 23` never becomes the identifier `123`.
fn consume_selector_escaped_code_point(text string, start int) (string, int) {
	mut i := start
	mut digits := ''
	for i < text.len && digits.len < 6 && is_ascii_hex_digit_byte(text[i]) {
		digits += text[i].ascii_str()
		i++
	}
	if digits.len > 0 {
		// If the next input code point is whitespace, consume it as well.
		if i < text.len && is_ascii_whitespace_byte(text[i]) {
			i++
		}
		value := strconv.parse_uint(digits, 16, 32) or { 0 }
		// A zero, surrogate, or out-of-range code point becomes U+FFFD.
		if value == 0 || value > 0x10ffff || (value >= 0xd800 && value <= 0xdfff) {
			return '�', i
		}
		return rune(value).str(), i
	}
	// EOF is a parse error; return U+FFFD.
	if i >= text.len {
		return '�', i
	}
	// Anything else: the code point itself, which may be multi-byte.
	mut end := i + 1
	for end < text.len && (text[end] & 0xc0) == 0x80 {
		end++
	}
	return text[i..end], end
}

fn is_ascii_hex_digit_byte(ch u8) bool {
	return (ch >= `0` && ch <= `9`) || (ch >= `a` && ch <= `f`) || (ch >= `A` && ch <= `F`)
}

// Skip one escape sequence, returning the index just past it.
fn skip_selector_escaped_code_point(text string, start int) int {
	_, next := consume_selector_escaped_code_point(text, start)
	return next
}

fn parse_identifier(text string, start int) (string, int) {
	mut i := start
	mut builder := strings.new_builder(16)
	for i < text.len {
		ch := text[i]
		if is_ident_byte(ch) {
			builder.write_u8(ch)
			i++
			continue
		}
		if ch == `\\` && i + 1 < text.len {
			decoded, next := consume_selector_escaped_code_point(text, i + 1)
			builder.write_string(decoded)
			i = next
			continue
		}
		break
	}
	return builder.str(), i
}

fn read_balanced(text string, start int, open u8, close u8) (string, int) {
	if start >= text.len || text[start] != open {
		return '', start
	}
	mut depth := 1
	mut quote := u8(0)
	mut i := start + 1
	for i < text.len {
		ch := text[i]
		if quote != 0 {
			if ch == `\\` && i + 1 < text.len {
				i += 2
				continue
			}
			if ch == quote {
				quote = 0
			}
			i++
			continue
		}
		if ch == `"` || ch == `'` {
			quote = ch
		} else if ch == open {
			depth++
		} else if ch == close {
			depth--
			if depth == 0 {
				return text[start + 1..i], i + 1
			}
		}
		i++
	}
	return text[start + 1..], text.len
}

fn strip_css_string(text string) string {
	if text.len >= 2 && ((text[0] == `"` && text[text.len - 1] == `"`) || (text[0] == `'` && text[text.len - 1] == `'`)) {
		return text[1..text.len - 1]
	}
	return text
}

fn selector_is_quoted_string(text string) bool {
	return text.len >= 2 && ((text[0] == `"` && text[text.len - 1] == `"`) || (text[0] == `'` && text[text.len - 1] == `'`))
}

fn selector_text_contains_unquoted_whitespace(text string) bool {
	mut quote := u8(0)
	mut i := 0
	for i < text.len {
		ch := text[i]
		if quote != 0 {
			if ch == `\\` && i + 1 < text.len {
				i += 2
				continue
			}
			if ch == quote {
				quote = 0
			}
			i++
			continue
		}
		if ch == `"` || ch == `'` {
			quote = ch
		} else if is_ascii_whitespace_byte(ch) {
			return true
		}
		i++
	}
	return false
}

fn last_top_level_whitespace_index(text string) ?int {
	mut quote := u8(0)
	mut result := -1
	mut i := 0
	for i < text.len {
		ch := text[i]
		if quote != 0 {
			if ch == `\\` && i + 1 < text.len {
				i += 2
				continue
			}
			if ch == quote {
				quote = 0
			}
			i++
			continue
		}
		if ch == `\\` && i + 1 < text.len {
			// The whitespace that terminates a numeric escape belongs to it.
			i = skip_selector_escaped_code_point(text, i + 1)
			continue
		}
		if ch == `"` || ch == `'` {
			quote = ch
		} else if is_ascii_whitespace_byte(ch) {
			result = i
		}
		i++
	}
	if result < 0 {
		return none
	}
	return result
}

fn is_valid_selector_identifier(text string) bool {
	if text.len == 0 {
		return false
	}
	if text.starts_with('--') {
		return text.len > 2
	}
	mut i := 0
	if text[i] == `-` {
		i++
		if i >= text.len || (text[i] >= `0` && text[i] <= `9`) {
			return false
		}
	}
	if i < text.len && text[i] == `\\` {
		if i + 1 >= text.len {
			return false
		}
		i = skip_selector_escaped_code_point(text, i + 1)
	} else {
		if i >= text.len || !is_ident_start_byte(text[i]) || (text[i] >= `0` && text[i] <= `9`) {
			return false
		}
		i++
	}
	for i < text.len {
		if is_ident_byte(text[i]) {
			i++
			continue
		}
		if text[i] == `\\` && i + 1 < text.len {
			i = skip_selector_escaped_code_point(text, i + 1)
			continue
		}
		return false
	}
	return true
}

fn selector_text_is_valid_compound(text string) bool {
	if text.len == 0 {
		return false
	}
	compound_selectors := parse_complex_selector(text)
	if compound_selectors.len != 1 || compound_selectors[0].simple_selectors.len == 0 {
		return false
	}
	for simple_selector in compound_selectors[0].simple_selectors {
		if simple_selector.type_ == .invalid {
			return false
		}
	}
	return true
}

fn top_level_index(text string, needle string) ?int {
	mut quote := u8(0)
	for i := 0; i <= text.len - needle.len; i++ {
		ch := text[i]
		if quote != 0 {
			if ch == quote {
				quote = 0
			}
			continue
		}
		if ch == `"` || ch == `'` {
			quote = ch
			continue
		}
		if selector_text_matches_at(text, needle, i, false) {
			return i
		}
	}
	return none
}

fn top_level_ascii_word_index(text string, word string) ?int {
	mut quote := u8(0)
	for i := 0; i <= text.len - word.len; i++ {
		ch := text[i]
		if quote != 0 {
			if ch == quote {
				quote = 0
			}
			continue
		}
		if ch == `"` || ch == `'` {
			quote = ch
			continue
		}
		before_ok := i == 0 || is_ascii_whitespace_byte(text[i - 1])
		after_index := i + word.len
		after_ok := after_index >= text.len || is_ascii_whitespace_byte(text[after_index])
		if before_ok && after_ok && selector_text_matches_at(text, word, i, true) {
			return i
		}
	}
	return none
}

// Compare a span in place. V string slices allocate, which otherwise creates
// one short-lived string at every byte while scanning attribute operators.
fn selector_text_matches_at(text string, needle string, index int, fold_ascii bool) bool {
	for j in 0 .. needle.len {
		mut byte := text[index + j]
		if fold_ascii && byte >= `A` && byte <= `Z` {
			byte += 0x20
		}
		if byte != needle[j] {
			return false
		}
	}
	return true
}

fn is_combinator_start(text string, index int) bool {
	if index >= text.len {
		return false
	}
	return text[index] == `>` || text[index] == `+` || text[index] == `~` || (text[index] == `|` && index + 1 < text.len && text[index + 1] == `|`)
}

fn is_ident_start_byte(ch u8) bool {
	return (ch >= `A` && ch <= `Z`) || (ch >= `a` && ch <= `z`) || ch == `_` || ch >= 0x80 || ch == `-`
}

fn is_ident_byte(ch u8) bool {
	return is_ident_start_byte(ch) || (ch >= `0` && ch <= `9`)
}

fn is_ascii_whitespace_byte(ch u8) bool {
	return ch == ` ` || ch == `\t` || ch == `\n` || ch == `\r` || ch == `\f`
}

fn is_ascii_alphanumeric_byte(ch u8) bool {
	return (ch >= `0` && ch <= `9`) || (ch >= `A` && ch <= `Z`) || (ch >= `a` && ch <= `z`)
}

fn direction_keyword_from_string(value string) DirectionKeyword {
	return match value.to_lower() {
		'ltr' { .ltr }
		'rtl' { .rtl }
		else { .invalid }
	}
}

fn optional_string_equal(left ?string, right ?string) bool {
	if left == none && right == none {
		return true
	}
	if l := left {
		if r := right {
			return l == r
		}
	}
	return false
}

fn optional_pseudo_element_equal(left ?PseudoElement, right ?PseudoElement) bool {
	if left == none && right == none {
		return true
	}
	if l := left {
		if r := right {
			return l == r
		}
	}
	return false
}

fn selector_string_contains(haystack string, needle string, case_sensitivity SelectorCaseSensitivity) bool {
	if needle.len == 0 { return true }
	if needle.len > haystack.len { return false }
	if needle.len > 32 {
		// Keep linear KMP search for unbounded author-provided patterns.
		return if case_sensitivity == .case_insensitive {
			to_ascii_lowercase(haystack).contains(to_ascii_lowercase(needle))
		} else { haystack.contains(needle) }
	}
	if !retain_selector_substring_scan {
		return selector_short_substring_contains(haystack, needle, case_sensitivity)
	}
	// Short attribute patterns dominate filtering selectors. Avoid rebuilding
	// KMP prefixes or allocating lowercase copies on every candidate element.
	// Each bounded substring is borrowed only for the comparison; it never escapes.
	for offset in 0 .. haystack.len - needle.len + 1 {
		if case_sensitivity == .case_insensitive {
			if equals_ignoring_ascii_case(unsafe { haystack.substr_unsafe(offset, offset + needle.len) }, needle) {
				return true
			}
		} else if haystack[offset] == needle[0]
			&& unsafe { haystack.substr_unsafe(offset, offset + needle.len) } == needle {
			return true
		}
	}
	return false
}

fn selector_string_starts_with(haystack string, needle string, case_sensitivity SelectorCaseSensitivity) bool {
	if needle.len > haystack.len { return false }
	if case_sensitivity == .case_insensitive {
		return equals_ignoring_ascii_case(unsafe { haystack.substr_unsafe(0, needle.len) }, needle)
	}
	return haystack.starts_with(needle)
}

fn selector_string_ends_with(haystack string, needle string, case_sensitivity SelectorCaseSensitivity) bool {
	if needle.len > haystack.len { return false }
	if case_sensitivity == .case_insensitive {
		return equals_ignoring_ascii_case(unsafe { haystack.substr_unsafe(haystack.len - needle.len, haystack.len) }, needle)
	}
	return haystack.ends_with(needle)
}

fn selector_min_u32(left u32, right u32) u32 {
	if left < right {
		return left
	}
	return right
}

fn selector_string_hash(value string) u32 {
	mut hash := u32(2166136261)
	for ch in value {
		hash ^= u32(ch)
		hash *= u32(16777619)
	}
	return hash
}
