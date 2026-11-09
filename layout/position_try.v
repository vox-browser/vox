module layout

import css
import dom

@[heap]
struct PositionTryLayoutState {
mut:
	base_layout &css.ComputedValues = unsafe { nil }
	base_css &css.ComputedProperties = unsafe { nil }
	applied_layout &css.ComputedValues = unsafe { nil }
	current_success bool
	current_option string
	current_anchors map[string]css.CSSPixelRect
	capture_anchors bool
	use_last_anchors bool
	last_success bool
	last_option string
	last_anchors map[string]css.CSSPixelRect
	options_signature string
}

fn commit_document_position_try_options(_ voidptr, document &dom.Document) {
	if document.layout_engine_handle() == unsafe { nil } { return }
	mut storage := document.enter_native_storage()
	defer { storage.finish() }
	result := unsafe { &DocumentLayoutResult(document.layout_engine_handle()) }
	commit_position_try_options_in_subtree(unsafe { &Node(result.root) })
}

fn commit_position_try_options_in_subtree(node &Node) {
	if box := node.as_box() {
		if mut retained := box.position_try_state_ {
			if retained.current_success {
				retained.last_success = true
				retained.last_option = retained.current_option
				retained.last_anchors = retained.current_anchors.clone()
			}
		}
	}
	for child in node.children() { commit_position_try_options_in_subtree(child) }
}

fn position_try_saved_anchor(node &Node, name string) ?css.CSSPixelRect {
	box := node.as_box() or { return none }
	retained := box.position_try_state_ or { return none }
	if !retained.use_last_anchors { return none }
	return retained.last_anchors[name] or { none }
}

fn position_try_note_anchor(node &Node, name string, rect css.CSSPixelRect) {
	box := node.as_box() or { return }
	mut retained := box.position_try_state_ or { return }
	if retained.capture_anchors { retained.current_anchors[name] = rect }
}

fn position_try_options_signature(target dom.AbstractElement, text string) string {
	mut signature := text
	for entry in text.split(',') {
		for word in entry.trim_space().split(' ') {
			if word.starts_with('--') {
				if rule := css.position_try_rule_for_element(target,word) { signature += '\n'+rule.css_text() }
				else { signature += '\n<missing>' }
			}
		}
	}
	return signature
}

fn position_try_target(box &Node) ?dom.AbstractElement {
	if generator := box.pseudo_element_generator() {
		pseudo := box.generated_for_pseudo_element() or { return none }
		return dom.AbstractElement.new(generator,unsafe { dom.PseudoElement(int(pseudo)) })
	}
	node := box.dom_node() or { return none }
	return dom.AbstractElement.new(node.as_element() or { return none },none)
}

fn position_try_property_text(computed &css.ComputedValues, property css.PropertyID) string {
	return (unsafe { &css.ComputedProperties(computed) }.property(property,.yes) or { return '' }).css_text
}

fn position_try_fits(state &LayoutState, box &Node) bool {
	styled := box.as_node_with_style() or { return false }
	values := state.try_get(styled) or { return false }
	containing := values.containing_block_used_values() or { return false }
	x := values.offset.x().minus(values.margin_box_left())
	y := values.offset.y().minus(values.margin_box_top())
	rect := position_try_inset_rect(state,box,values,containing)
	return x.raw_value() >= rect.left().raw_value() && y.raw_value() >= rect.top().raw_value()
		&& x.plus(values.margin_box_width()).raw_value() <= rect.right().raw_value()
		&& y.plus(values.margin_box_height()).raw_value() <= rect.bottom().raw_value()
}

fn position_try_inset_rect(state &LayoutState, box &Node, values &UsedValues, containing &UsedValues) css.CSSPixelRect {
	container := box.containing_block() or { return position_try_containing_rect(values,containing) }
	computed := box.computed_values()
	mut rect := position_try_containing_rect(values,containing)
	if area := resolved_position_area(state,box,containing,computed,rect) { rect = area.rect }
	left := resolved_inset_with_anchors(state,box,container,containing,computed,.left,rect.x,rect.width,false,true) or { CSSPixels.new(0) }
	right := resolved_inset_with_anchors(state,box,container,containing,computed,.right,rect.x,rect.width,true,true) or { CSSPixels.new(0) }
	top := resolved_inset_with_anchors(state,box,container,containing,computed,.top,rect.y,rect.height,false,false) or { CSSPixels.new(0) }
	bottom := resolved_inset_with_anchors(state,box,container,containing,computed,.bottom,rect.y,rect.height,true,false) or { CSSPixels.new(0) }
	return css.CSSPixelRect{x:rect.x.plus(left),y:rect.y.plus(top),width:rect.width.minus(left).minus(right),height:rect.height.minus(top).minus(bottom)}
}

fn position_try_containing_rect(values &UsedValues, containing &UsedValues) css.CSSPixelRect {
	return values.abspos_containing_block_rect() or { css.CSSPixelRect{x:CSSPixels.new(0).minus(containing.padding_left),
		y:CSSPixels.new(0).minus(containing.padding_top),width:containing.content_width().plus(containing.padding_left).plus(containing.padding_right),
		height:containing.content_height().plus(containing.padding_top).plus(containing.padding_bottom)} }
}

fn position_try_order_extent(state &LayoutState, box &Node, order string) CSSPixels {
	styled := box.as_node_with_style() or { return CSSPixels.new(0) }
	values := state.try_get(styled) or { return CSSPixels.new(0) }
	containing := values.containing_block_used_values() or { return CSSPixels.new(0) }
	container := box.containing_block() or { return CSSPixels.new(0) }
	horizontal := match order { 'most-width' {true} 'most-height' {false}
		'most-inline-size' { container.computed_values().writing_mode() == .horizontal_tb }
		else { container.computed_values().writing_mode() != .horizontal_tb } }
	computed := box.computed_values()
	mut rect := position_try_containing_rect(values,containing)
	if area := resolved_position_area(state,box,containing,computed,rect) { rect = area.rect }
	basis := if horizontal { rect.width } else { rect.height }
	start := if horizontal { rect.x } else { rect.y }
	low := resolved_inset_with_anchors(state,box,container,containing,computed,if horizontal { css.PropertyID.left } else { css.PropertyID.top },start,basis,false,horizontal) or { CSSPixels.new(0) }
	high := resolved_inset_with_anchors(state,box,container,containing,computed,if horizontal { css.PropertyID.right } else { css.PropertyID.bottom },start,basis,true,horizontal) or { CSSPixels.new(0) }
	return basis.minus(low).minus(high)
}

fn position_try_declaration(target dom.AbstractElement, text string) ?&css.CSSStyleProperties {
	words := text.trim_space().split(' ')
	for word in words {
		if word.starts_with('--') {
			rule := css.position_try_rule_for_element(target,word) or { return none }
			return rule.style()
		}
	}
	if text.contains('flip-') { return css.CSSStyleProperties.create() }
	mut declaration := css.CSSStyleProperties.create()
	declaration.set_property('position-area',text,'') or { return none }
	return declaration
}

fn position_try_start_side(node &Node, horizontal bool) int {
	return if horizontal { if absolute_axis_starts_low(node,true) { 3 } else { 1 } }
		else { if absolute_axis_starts_low(node,false) { 0 } else { 2 } }
}

fn position_try_tactic_context(node &Node, text string) ?css.PositionTryTacticContext {
	containing_box := node.containing_block() or { return none }
	containing := unsafe { &Node(containing_box) }
	inline_horizontal := containing.computed_values().writing_mode() == .horizontal_tb
	inline_start := position_try_start_side(containing,inline_horizontal)
	block_start := position_try_start_side(containing,!inline_horizontal)
	mut mapping := [0,1,2,3]!
	for word in text.split(' ') {
		mut pairs := [][2]int{}
		match word {
			'flip-block' { pairs << [block_start,(block_start+2)%4]! }
			'flip-inline' { pairs << [inline_start,(inline_start+2)%4]! }
			'flip-x' { pairs << [1,3]! }
			'flip-y' { pairs << [0,2]! }
			'flip-start' { pairs << [block_start,inline_start]!; pairs << [(block_start+2)%4,(inline_start+2)%4]! }
			else {}
		}
		for pair in pairs {
			for index, side in mapping {
				if side == pair[0] { mapping[index] = pair[1] }
				else if side == pair[1] { mapping[index] = pair[0] }
			}
		}
	}
	return css.PositionTryTacticContext{mapping:mapping,inline_horizontal:inline_horizontal,
		container_starts:[position_try_start_side(containing,true),position_try_start_side(containing,false)]!,
		self_starts:[position_try_start_side(node,true),position_try_start_side(node,false)]!}
}

fn position_try_area_range_text(range PositionAreaRange, horizontal bool) string {
	low := if horizontal { 'left' } else { 'top' }
	high := if horizontal { 'right' } else { 'bottom' }
	if range.first == 0 && range.last == 0 { return low }
	if range.first == 2 && range.last == 2 { return high }
	if range.first == 0 && range.last == 1 { return 'span-'+low }
	if range.first == 1 && range.last == 2 { return 'span-'+high }
	return if range.first == 1 && range.last == 1 { 'center' } else { 'span-all' }
}

fn position_try_apply_tactics(node &Node, properties &css.ComputedProperties, text string) ?&css.CSSStyleProperties {
	context := position_try_tactic_context(node,text) or { return none }
	mut declaration := css.position_try_tactic_declaration(properties,context)
	area := (properties.property(.position_area,.yes) or { return declaration }).css_text
	containing := node.containing_block() or { return declaration }
	x, y := position_area_tracks(area,unsafe { &Node(containing) },node) or { return declaration }
	mut horizontal := x
	mut vertical := y
	for axis, original in [x,y] {
		destination := context.mapping[if axis == 0 { 3 } else { 0 }]
		range := if destination in [1,2] { PositionAreaRange{2-original.last,2-original.first} } else { original }
		if destination in [1,3] { horizontal = range } else { vertical = range }
	}
	h := position_try_area_range_text(horizontal,true)
	v := position_try_area_range_text(vertical,false)
	order_block_first := h in ['center','span-all'] && v in ['center','span-all'] && context.inline_horizontal
	declaration.set_property('position-area',if order_block_first { v+' '+h } else { h+' '+v },'') or { return none }
	return declaration
}

fn position_try_layout_option(mut state LayoutState, node &Node, mut target dom.AbstractElement,
 mut retained PositionTryLayoutState, option string) bool {
 mut styled := node.as_node_with_style() or { return false }
 mut box := node.as_box() or { return false }
 styled.computed_values_ = retained.base_layout
 css.install_position_try_style(mut target,retained.base_css)
 retained.capture_anchors = !retained.use_last_anchors
 if retained.capture_anchors { retained.current_anchors = map[string]css.CSSPixelRect{} }
 defer { retained.capture_anchors = false }
 if option != '' {
  declaration := position_try_declaration(target,option) or { return false }
  mut properties := css.compute_position_try_style(target,declaration)
  if option.contains('flip-') {
   transformed := position_try_apply_tactics(node,properties,option) or { return false }
   properties = css.compute_position_try_style(target,transformed)
  }
  styled.set_computed_values(properties)
  css.install_position_try_style(mut target,properties)
 }
 box.reset_cached_intrinsic_sizes()
 layout_absolutely_positioned_box_once(mut state,node)
 retained.applied_layout = styled.computed_values()
 return true
}

fn layout_with_position_try_fallbacks(mut state LayoutState, node &Node) bool {
 mut box := node.as_box() or { return false }
 styled := node.as_node_with_style() or { return false }
 mut target := position_try_target(node) or { return false }
 mut retained := box.position_try_state_ or {
  if position_try_property_text(styled.computed_values(),.position_try_fallbacks) in ['', 'none'] { return false }
  value := &PositionTryLayoutState{}
  box.position_try_state_ = value
  value
 }
 if voidptr(styled.computed_values()) != voidptr(retained.applied_layout) {
  retained.base_layout = styled.computed_values()
  mirror := target.computed_properties() or { return false }
  retained.base_css = unsafe { &css.ComputedProperties(mirror.css_handle) }
 }
 text := position_try_property_text(retained.base_layout,.position_try_fallbacks)
 signature := position_try_options_signature(target,text)
 if signature != retained.options_signature {
  retained.last_success = false
  retained.options_signature = signature
 }
 retained.current_success = false
 order := position_try_property_text(retained.base_layout,.position_try_order)
 ordered := order !in ['', 'normal']
 // The last successful option has priority while it still fits. Only the
 // resize-observation boundary commits a newly successful option.
 if !ordered && retained.last_success {
  if position_try_layout_option(mut state,node,mut target,mut retained,retained.last_option) && position_try_fits(state,node) {
   retained.current_option = retained.last_option
   retained.current_success = true
   return true
  }
 }
 _ = position_try_layout_option(mut state,node,mut target,mut retained,'')
 base_fits := position_try_fits(state,node)
 if text in ['', 'none'] || (!ordered && base_fits) {
  retained.current_option = ''
  retained.current_success = base_fits
  return true
 }
 mut best_option := ''
 mut best_fits := base_fits
 mut best_extent := if base_fits { position_try_order_extent(state,node,order) } else { CSSPixels.new(-1) }
 for index, raw in text.split(',') {
  if index >= 256 { break }
  entry := raw.trim_space()
  if !ordered && retained.last_success && entry == retained.last_option { continue }
  if !position_try_layout_option(mut state,node,mut target,mut retained,entry) { continue }
  if position_try_fits(state,node) {
   if !ordered {
    retained.current_option = entry
    retained.current_success = true
    return true
   }
   extent := position_try_order_extent(state,node,order)
   if !best_fits || extent.raw_value() > best_extent.raw_value() {
    best_option = entry
    best_fits = true
    best_extent = extent
   }
  }
 }
 if best_fits {
  _ = position_try_layout_option(mut state,node,mut target,mut retained,best_option)
  retained.current_option = best_option
  retained.current_success = true
 } else if retained.last_success {
  // Retain the successful option, resolving it against the current anchors.
  _ = position_try_layout_option(mut state,node,mut target,mut retained,retained.last_option)
 } else {
  _ = position_try_layout_option(mut state,node,mut target,mut retained,'')
 }
 return true
}
