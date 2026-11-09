module layout

import dom
import css
import platform

// Translation of Ladybird's Layout::Node (Layout/Node.h) — the base of the layout tree. In C++ Node is
// a JS::Cell + TreeNode<Node>; here the tree is modelled with a parent pointer + children array (as this
// port's DOM::Node is), rather than C++ TreeNode's intrusive first-child/next-sibling linked list.
//
// NodeWithStyle, Box, BlockContainer, Viewport, and TextNode below preserve the
// layout-tree identity and state used by the stateful formatting-context API.
@[heap]
pub struct Node {
pub mut:
	// Tree structure.
	parent_          ?&Node
	index_in_parent_ int = -1
	children_        []&Node
	// Layout::Node members (Layout/Node.h).
	document_                          &dom.Document = unsafe { nil }
	dom_node_                          ?&dom.Node
	containing_block_                  ?&Box
	inline_containing_block_           ?&InlineNode
	pseudo_element_generator_          ?&dom.Element
	generated_for_                     ?css.PseudoElement
	anonymous_                         bool
	has_style_                         bool
	children_are_inline_               bool
	is_flex_item_                      bool
	is_grid_item_                      bool
	is_body_                           bool
	is_in_ua_internal_shadow_tree_     bool
	is_button_content_box_             bool
	is_missing_table_cell_             bool
	needs_layout_update_               bool
	initial_quote_nesting_level_       u32
	has_been_wrapped_in_table_wrapper_ bool
	// Concrete-type discriminants (C++ uses virtual fast_is<T>(); V has no RTTI). Each subclass's
	// constructor sets its flags; a flag is true for the type AND its subclasses (is_box_ is set for
	// Box and BlockContainer, etc.).
	is_box_                          bool
	is_block_container_              bool
	is_inline_node_                  bool
	is_break_node_                   bool
	is_list_item_box_                bool
	is_replaced_box_                 bool
	is_navigable_container_viewport_ bool
	is_image_box_                    bool
	replaced_can_have_children_      bool
	is_fieldset_box_                 bool
	is_legend_box_                   bool
	is_text_input_box_               bool
	is_range_input_box_              bool
	is_textarea_box_                 bool
	is_table_wrapper_                bool
	is_list_item_marker_box_         bool
	is_text_node_                    bool
	is_generated_text_node_          bool
	is_viewport_                     bool
	is_svg_box_                      bool
	is_svg_graphics_box_             bool
	is_svg_geometry_box_             bool
	is_svg_image_box_                bool
	is_svg_clip_box_                 bool
	is_svg_mask_box_                 bool
	is_svg_pattern_box_              bool
	is_svg_svg_box_                  bool
	is_svg_text_box_                 bool
	is_svg_text_path_box_            bool
	is_svg_foreign_object_box_       bool
mut:
	// Live module-cycle boundary, retained for this exact typed layout node.
	dom_layout_node_ &dom.LayoutNode = unsafe { nil }
	flow_validation_cache_ &RetainedFlowValidationCache = unsafe { nil }
	ordinary_paint_box_ &OrdinaryPaintBoxProjection = unsafe { nil }
	table_fixup_skip_ bool
	tree_order_       &LayoutTreeOrder = unsafe { nil }
	tree_order_owner_ voidptr
	tree_order_start_ u32
	tree_order_end_   u32
}

// Node(DOM::Document&, DOM::Node*) — a layout node for `dom_node` (null for anonymous boxes).
pub fn Node.new(document &dom.Document, dom_node ?&dom.Node) &Node {
	return &Node{
		document_: document
		dom_node_: dom_node
	}
}

// Whether two layout nodes are the same object (pointer identity — V's `&Node == &Node` compares by value).
pub fn layout_nodes_same(a &Node, b &Node) bool {
	return voidptr(a) == voidptr(b)
}

// --- Tree structure ---

// TreeNode<Node>::append_child — append `child` as this node's last child.
pub fn (mut n Node) append_child(child &Node) {
	n.invalidate_tree_order()
	child.invalidate_tree_order()
	mut mutable_child := unsafe { &Node(child) }
	mutable_child.parent_ = n
	mutable_child.index_in_parent_ = n.children_.len
	n.children_ << child
	mutable_child.inserted_into(n)
}

pub fn (n &Node) is_label() bool {
	return false
}

pub fn (mut n Node) inserted_into(parent &Node) {
	_ = parent
}

fn (mut n Node) replace_children(children []&Node) {
	n.invalidate_tree_order()
	for old_child in n.children_ {
		old_child.invalidate_tree_order()
		if parent := old_child.parent_ {
			// Fixup can move an old child into a new anonymous wrapper before
			// replacing this vector. Its new parent already owns that link.
			if voidptr(parent) != voidptr(&n) { continue }
		}
		mut mutable_old_child := unsafe { &Node(old_child) }
		mutable_old_child.parent_ = none
		mutable_old_child.index_in_parent_ = -1
	}
	n.children_ = children.clone()
	for index, child in n.children_ {
		child.invalidate_tree_order()
		mut mutable_child := unsafe { &Node(child) }
		mutable_child.parent_ = n
		mutable_child.index_in_parent_ = index
	}
}

pub fn (n &Node) parent() ?&Node {
	return n.parent_
}

pub fn (n &Node) children() []&Node {
	return n.children_
}

pub fn (n &Node) has_children() bool {
	return n.children_.len > 0
}

pub fn (n &Node) child_count() int {
	return n.children_.len
}

pub fn (n &Node) first_child() ?&Node {
	if n.children_.len == 0 {
		return none
	}
	return n.children_[0]
}

pub fn (n &Node) last_child() ?&Node {
	if n.children_.len == 0 {
		return none
	}
	return n.children_[n.children_.len - 1]
}

pub fn (n &Node) next_sibling() ?&Node {
	parent := n.parent_ or { return none }
	index := n.index_in_parent_
	if index >= 0 && index + 1 < parent.children_.len {
		return parent.children_[index + 1]
	}
	return none
}

pub fn (n &Node) previous_sibling() ?&Node {
	parent := n.parent_ or { return none }
	index := n.index_in_parent_
	if index > 0 && index < parent.children_.len {
		return parent.children_[index - 1]
	}
	return none
}

// --- Layout::Node accessors (Layout/Node.h) ---

pub fn (n &Node) dom_node() ?&dom.Node {
	return n.dom_node_
}

pub fn (n &Node) document() &dom.Document {
	return n.document_
}

// Node::navigable().
pub fn (n &Node) navigable() ?&dom.Navigable {
	return n.document_.navigable()
}

pub fn (n &Node) is_anonymous() bool {
	return n.anonymous_
}

pub fn (n &Node) has_style() bool {
	return n.has_style_
}

pub fn (n &Node) has_style_or_parent_with_style() bool {
	if n.has_style_ {
		return true
	}
	parent := n.parent() or { return false }
	return parent.has_style_or_parent_with_style()
}

pub fn (n &Node) children_are_inline() bool {
	return n.children_are_inline_
}

pub fn (mut n Node) set_children_are_inline(value bool) {
	n.children_are_inline_ = value
}

pub fn (n &Node) is_flex_item() bool {
	return n.is_flex_item_
}

pub fn (mut n Node) set_flex_item(value bool) {
	n.is_flex_item_ = value
}

pub fn (n &Node) is_grid_item() bool {
	return n.is_grid_item_
}

pub fn (n &Node) vertical_align_applies() bool {
	// vertical-align has no effect on flex or grid items. Other applicability
	// remains intentionally broad until the generic baseline path is narrowed
	// to inline-level boxes and table cells.
	return !n.is_flex_item_ && !n.is_grid_item_
}

pub fn (mut n Node) set_grid_item(value bool) {
	n.is_grid_item_ = value
}

pub fn (n &Node) is_missing_table_cell() bool {
	return n.is_missing_table_cell_
}

pub fn (mut n Node) set_is_missing_table_cell(value bool) {
	n.is_missing_table_cell_ = value
}

pub fn (n &Node) is_body() bool {
	if n.is_body_ {
		return true
	}
	dom_node := n.dom_node_ or { return false }
	body := n.document_.body() or { return false }
	body_node := unsafe { &dom.Element(body) }.as_node()
	return dom_node.unique_id().value() == body_node.unique_id().value()
}

pub fn (n &Node) is_in_ua_internal_shadow_tree() bool {
	return n.is_in_ua_internal_shadow_tree_
}

pub fn (mut n Node) set_is_in_ua_internal_shadow_tree(value bool) {
	n.is_in_ua_internal_shadow_tree_ = value
}

pub fn (n &Node) needs_layout_update() bool {
	return n.needs_layout_update_
}

pub fn (mut n Node) set_needs_layout_update(value bool) {
	if !value {
		n.needs_layout_update_ = false
		return
	}
	if n.needs_layout_update_ {
		return
	}
	n.needs_layout_update_ = true
	if mut box := n.as_box() {
		box.reset_cached_intrinsic_sizes()
	}

	// Mark anonymous box children generated by this node. Table wrappers are
	// excluded exactly as in Node::set_needs_layout_update().
	for child in n.children_ {
		if child.is_box() && child.is_anonymous() && !child.is_table_wrapper() {
			mut mutable_child := unsafe { &Node(child) }
			mutable_child.needs_layout_update_ = true
			if mut child_box := mutable_child.as_box() {
				child_box.reset_cached_intrinsic_sizes()
			}
		}
	}

	// Propagate the layout-update bit through ancestors, stopping once an
	// ancestor was already dirty or at the SVG-root relayout boundary.
	mut ancestor := n.parent()
	for ancestor != none {
		current := ancestor or { break }
		mut mutable_current := unsafe { &Node(current) }
		if mutable_current.needs_layout_update_ {
			break
		}
		mutable_current.needs_layout_update_ = true
		if mutable_current.is_svg_svg_box() {
			break
		}
		ancestor = mutable_current.parent()
	}

	// Intrinsic sizes are independent of the dirty-bit early exit above. Clear
	// every ancestor cache up to an abspos or SVG-root boundary.
	ancestor = n.parent()
	for ancestor != none {
		current := ancestor or { break }
		if mut box := unsafe { &Node(current) }.as_box() {
			box.reset_cached_intrinsic_sizes()
			if current.is_absolutely_positioned() || current.is_svg_svg_box() {
				break
			}
		}
		ancestor = current.parent()
	}
}

pub fn (mut n Node) reset_needs_layout_update() {
	n.needs_layout_update_ = false
}

pub fn (n &Node) generated_for_pseudo_element() ?css.PseudoElement {
	return n.generated_for_
}

pub fn (n &Node) is_generated_for_pseudo_element() bool {
	return n.generated_for_ != none
}

pub fn (n &Node) is_generated_for_before_pseudo_element() bool {
	pseudo_element := n.generated_for_ or { return false }
	return pseudo_element == .before
}

pub fn (n &Node) is_generated_for_after_pseudo_element() bool {
	pseudo_element := n.generated_for_ or { return false }
	return pseudo_element == .after
}

pub fn (n &Node) is_generated_for_backdrop_pseudo_element() bool {
	pseudo_element := n.generated_for_ or { return false }
	return pseudo_element == .backdrop
}

pub fn (mut n Node) set_generated_for(type_ css.PseudoElement, element &dom.Element) {
	n.generated_for_ = type_
	n.pseudo_element_generator_ = element
}

pub fn (n &Node) pseudo_element_generator() ?&dom.Element {
	return n.pseudo_element_generator_
}

pub fn (n &Node) initial_quote_nesting_level() u32 {
	return n.initial_quote_nesting_level_
}

pub fn (mut n Node) set_initial_quote_nesting_level(value u32) {
	n.initial_quote_nesting_level_ = value
}

pub fn (n &Node) has_been_wrapped_in_table_wrapper() bool {
	return n.has_been_wrapped_in_table_wrapper_
}

pub fn (mut n Node) set_has_been_wrapped_in_table_wrapper(value bool) {
	n.has_been_wrapped_in_table_wrapper_ = value
}

pub fn (n &Node) display() css.Display {
	if n.has_style_ {
		return unsafe { &NodeWithStyle(n) }.computed_values().display()
	}
	// Node::display(): unstyled text content participates in inline flow.
	return css.Display.from_outside_inside(.inline_, .flow)
}

pub fn (n &Node) display_before_box_type_transformation() css.Display {
	if n.has_style_ {
		return unsafe { &NodeWithStyle(n) }.computed_values().display_before_box_type_transformation()
	}
	return css.Display.from_outside_inside(.inline_, .flow)
}

// Node::computed_values(): unstyled text nodes inherit the immutable computed
// values of their styled parent.
pub fn (n &Node) computed_values() &css.ComputedValues {
	// Keep the nearest styled ancestor lookup local. An explicit walk lets
	// callers inline the common styled-node read without a recursive call.
	mut current := unsafe { n }
	for !current.has_style_ {
		current = current.parent() or { panic('VERIFY(has_style_or_parent_with_style())') }
	}
	return unsafe { &NodeWithStyle(current) }.computed_values()
}

pub fn (n &Node) first_available_font() &platform.Font {
	// ComputedValues is the retained ComputedProperties allocation in V. A
	// style mutation can invalidate its font cache after line boxes have retained
	// the layout node, whereas C++'s immutable ComputedValues always carries the
	// materialized cascade. Rebuild that cache through the document's shared
	// FontComputer before reading it so repaint after relayout preserves the C++
	// lifetime invariant.
	mut computed_values := unsafe { &css.ComputedProperties(n.computed_values()) }
	computed_font := computed_values.first_available_computed_font(css.css_style_computer_for(n.document()).font_computer())
	return computed_font.font_for_rendering()
}

// ComputedValues owns a materialized FontCascadeList upstream. The V
// translation shares its allocation with ComputedProperties, whose cache can
// be cleared by a later style mutation while an old layout node is retained.
// Restore the immutable-ComputedValues invariant before a text iterator reads
// the complete cascade, just as first_available_font() does for one face.
pub fn (n &Node) font_list() &css.FontCascadeList {
	mut computed_values := unsafe { &css.ComputedProperties(n.computed_values()) }
	return computed_values.computed_font_list(css.css_style_computer_for(n.document()).font_computer())
}

pub fn (n &Node) debug_description() string {
	mut description := layout_debug_class_name(n)
	if dom_node := n.dom_node() {
		description += '<${dom_node.node_name()}>'
		if element := dom_node.as_element() {
			if id := element.id() {
				description += '#${id}'
			}
			for class_name in element.get_attribute_value('class').fields() {
				description += '.${class_name}'
			}
		}
	} else {
		description += '(anonymous)'
	}
	return description
}

pub fn (n &Node) is_inline() bool {
	return n.display().is_inline_outside()
}

pub fn (n &Node) is_inline_block() bool {
	return n.display().is_inline_block()
}

pub fn (n &Node) is_inline_table() bool {
	display := n.display()
	return display.is_inline_outside() && display.is_table_inside()
}

// Node::is_replaced_element(). Some native controls use a generic box so they
// can host their internal shadow tree, but remain replaced elements for CSS
// box generation and inline layout.
pub fn (n &Node) is_replaced_element() bool {
	if n.is_replaced_box() {
		return true
	}
	dom_node := n.dom_node() or { return false }
	return dom_node.is_html_input_element()
}

pub fn (n &Node) is_atomic_inline() bool {
	if n.is_replaced_element() {
		return true
	}
	display := n.display()
	return display.is_inline_outside() && !display.is_flow_inside()
}

pub fn (n &Node) is_floating() bool {
	styled := n.as_node_with_style() or { return false }
	// Flex items do not float. Grid formatting inhibits float positioning, but
	// Node::is_floating() still reflects the authored float value upstream.
	if n.is_flex_item_ {
		return false
	}
	return styled.computed_values().float_() != .none_
}

pub fn (n &Node) is_positioned() bool {
	styled := n.as_node_with_style() or { return false }
	return styled.computed_values().position() != .static_
}

pub fn (n &Node) is_absolutely_positioned() bool {
	styled := n.as_node_with_style() or { return false }
	position := styled.computed_values().position()
	return position == .absolute || position == .fixed
}

pub fn (n &Node) is_fixed_position() bool {
	styled := n.as_node_with_style() or { return false }
	return styled.computed_values().position() == .fixed
}

pub fn (n &Node) is_sticky_position() bool {
	styled := n.as_node_with_style() or { return false }
	return styled.computed_values().position() == .sticky
}

// Node::has_css_transform(). Individual transform properties count even when
// the transform-list shorthand itself is empty.
pub fn (n &Node) has_css_transform() bool {
	computed := n.computed_values()
	return computed.transformations().len > 0 || computed.rotate() != none
		|| computed.translate() != none || computed.scale() != none
}

// https://drafts.csswg.org/css-transforms-1/#transformable-element
pub fn (n &Node) is_transformable() bool {
	if n.is_svg_box() || n.is_svg_svg_box() || n.is_svg_foreign_object_box() {
		return (n.is_svg_graphics_box() && !n.is_svg_mask_box()) || n.is_svg_svg_box()
			|| n.is_svg_foreign_object_box()
	}
	dom_node := n.dom_node() or {
		return n.is_generated_for_pseudo_element() && n.is_box()
	}
	if dom_node.as_element() == none || !n.is_box() {
		return false
	}
	display := n.display()
	if display.is_table_column() || display.is_table_column_group() {
		return false
	}
	return !n.is_inline() || n.is_atomic_inline()
}

pub fn (n &Node) establishes_or_extends_a_3d_rendering_context() bool {
	// FIXME: Use the used transform-style value after grouping properties flatten it.
	return n.is_transformable() && n.computed_values().transform_style() == .preserve_3d
}

// https://drafts.csswg.org/css-transforms-2/#3d-rendering-contexts
pub fn (n &Node) participates_in_a_3d_rendering_context() bool {
	mut ancestor := n.parent()
	for ancestor != none {
		candidate := ancestor or { return false }
		if !candidate.is_anonymous() {
			return candidate.establishes_or_extends_a_3d_rendering_context()
		}
		ancestor = candidate.parent()
	}
	return false
}

// NodeWithStyle::is_scroll_container(). The viewport intentionally behaves as a scroll container
// even though its computed overflow is visible.
pub fn (n &Node) is_scroll_container() bool {
	if n.is_viewport() {
		return true
	}
	styled := n.as_node_with_style() or { return false }
	computed := styled.computed_values()
	x := computed.overflow_x()
	y := computed.overflow_y()
	return x == .auto_ || x == .hidden || x == .scroll
		|| y == .auto_ || y == .hidden || y == .scroll
}

pub fn (n &Node) is_out_of_flow() bool {
	return n.is_floating() || n.is_absolutely_positioned()
}

pub fn (n &Node) is_in_flow() bool {
	return !n.is_out_of_flow()
}

pub fn (n &Node) can_have_children() bool {
	if n.is_break_node_ {
		return false
	}
	if n.is_replaced_box_ {
		return n.replaced_can_have_children_
	}
	return true
}

pub fn (n &Node) has_size_containment() bool {
	display := n.display()
	if display.is_table_inside() || display.is_internal_table() {
		return false
	}
	computed := n.computed_values()
	return computed.contain().size_containment || computed.container_type().is_size_container
}

// https://drafts.csswg.org/css-sizing-4/#intrinsic-size-override
// These are physical dimensions even when the box uses a vertical writing
// mode; logical contain-intrinsic declarations have already been mapped by
// the cascade.
pub fn (n &Node) explicit_intrinsic_inner_width() ?CSSPixels {
	value := n.computed_values().contain_intrinsic_width()
	if !value.has_length {
		return none
	}
	return value.length
}

pub fn (n &Node) explicit_intrinsic_inner_height() ?CSSPixels {
	value := n.computed_values().contain_intrinsic_height()
	if !value.has_length {
		return none
	}
	return value.length
}

pub fn (n &Node) has_inline_size_containment() bool {
	display := n.display()
	if display.is_table_inside() || display.is_internal_table() {
		return false
	}
	computed := n.computed_values()
	return computed.contain().inline_size_containment
		|| computed.container_type().is_inline_size_container
}

pub fn (n &Node) has_layout_containment() bool {
	display := n.display()
	if display.is_internal_table() && !display.is_table_cell() {
		return false
	}
	computed := n.computed_values()
	return computed.contain().layout_containment || computed.content_visibility() == .auto_
}

pub fn (n &Node) has_style_containment() bool {
	computed := n.computed_values()
	container_type := computed.container_type()
	return computed.contain().style_containment || container_type.is_size_container
		|| container_type.is_inline_size_container || computed.content_visibility() == .auto_
}

pub fn (n &Node) has_paint_containment() bool {
	display := n.display()
	if display.is_internal_table() && !display.is_table_cell() {
		return false
	}
	computed := n.computed_values()
	return computed.contain().paint_containment || computed.content_visibility() == .auto_
}

fn layout_input_type_allows_readonly(element &dom.Element) bool {
	return element.get_attribute_value('type').trim_space().to_lower() in ['', 'text', 'search',
		'tel', 'url', 'email', 'password', 'date', 'month', 'week', 'time', 'datetime-local', 'number']
}

fn layout_form_text_control_is_mutable(element &dom.Element) bool {
	local_name := element.local_name()
	if (local_name != 'input' && local_name != 'textarea') || element.is_actually_disabled() {
		return false
	}
	if local_name == 'textarea' {
		return !element.has_attribute('readonly')
	}
	return !element.has_attribute('readonly') || !layout_input_type_allows_readonly(element)
}

// https://drafts.csswg.org/css-ui/#propdef-user-select
// Node::user_select_used_value().
pub fn (n &Node) user_select_used_value() css.UserSelect {
	if value := n.user_select_local_used_value() { return value }
	if parent := n.parent() {
		return inherited_user_select_used_value(parent.user_select_used_value())
	}
	return .text
}

// Preorder attachment already resolved the parent's value. Reuse that result
// rather than rechecking editing hosts and form controls along every ancestor.
fn (n &Node) user_select_used_value_with_parent(parent_used css.UserSelect) css.UserSelect {
	if value := n.user_select_local_used_value() { return value }
	return inherited_user_select_used_value(parent_used)
}

fn inherited_user_select_used_value(parent_used css.UserSelect) css.UserSelect {
	return if parent_used == .all || parent_used == .none_ { parent_used } else { .text }
}

fn (n &Node) user_select_local_used_value() ?css.UserSelect {
	computed_value := n.computed_values().user_select()
	if dom_node := n.dom_node() {
		if dom_node.is_editing_host() {
			return .contain
		}
		if element := dom_node.as_element() {
			if layout_form_text_control_is_mutable(element) {
				return .contain
			}
		}
	}
	if computed_value != .auto_ {
		return computed_value
	}
	if n.is_generated_for_before_pseudo_element() || n.is_generated_for_after_pseudo_element() {
		return .none_
	}
	return none
}

pub fn (n &Node) containing_block() ?&Box {
	return n.containing_block_
}

pub fn (n &Node) inline_containing_block_if_applicable() ?&InlineNode {
	return n.inline_containing_block_
}

fn (n &Node) is_root_element() bool {
	if n.is_anonymous() {
		return false
	}
	dom_node := n.dom_node_ or { return false }
	element := dom_node.as_element() or { return false }
	return element.is_html_element() && element.local_name() == 'html'
}

// https://developer.mozilla.org/en-US/docs/Web/CSS/CSS_positioned_layout/Stacking_context
pub fn (n &Node) establishes_stacking_context() bool {
	if !n.has_style() || n.is_svg_box() {
		return false
	}
	if n.is_viewport() || n.is_root_element() {
		return true
	}

	computed := n.computed_values()
	will_change := computed.will_change()
	position := computed.position()
	has_z_index := computed.z_index() != none || will_change.has_property(.z_index)
	if (position == .absolute || position == .relative) && has_z_index {
		return true
	}
	if position == .fixed || position == .sticky || will_change.has_property(.position) {
		return true
	}
	if computed.transformations().len > 0 || will_change.has_property(.transform)
		|| computed.translate() != none || will_change.has_property(.translate)
		|| computed.rotate() != none || will_change.has_property(.rotate)
		|| computed.scale() != none || will_change.has_property(.scale) {
		return true
	}
	if parent := n.parent() {
		if (parent.display().is_flex_inside() || parent.display().is_grid_inside()) && has_z_index {
			return true
		}
	}
	if computed.backdrop_filter().has_filters() || computed.filter().has_filters()
		|| will_change.has_property(.backdrop_filter) || will_change.has_property(.filter) {
		return true
	}
	if computed.clip_path() != none || computed.mask() != none || computed.mask_image() != none
		|| will_change.has_property(.clip_path)
		|| will_change.has_property(.mask_image) {
		return true
	}
	if n.is_svg_foreign_object_box() {
		return true
	}
	if computed.isolation() == .isolate || will_change.has_property(.isolation) {
		return true
	}
	if n.has_layout_containment() || n.has_paint_containment() || will_change.has_property(.contain) {
		return true
	}
	if computed.mix_blend_mode() != .normal || will_change.has_property(.mix_blend_mode) {
		return true
	}
	if computed.view_transition_name() != none || will_change.has_property(.view_transition_name) {
		return true
	}
	if computed.perspective() != none || will_change.has_property(.perspective) {
		return true
	}
	if computed.transform_style() == .preserve_3d || will_change.has_property(.transform_style) {
		return true
	}
	if (computed.backface_visibility() == .hidden
		|| will_change.has_property(.backface_visibility)) && n.is_transformable()
		&& n.participates_in_a_3d_rendering_context() {
		return true
	}
	return computed.opacity() < 1.0 || will_change.has_property(.opacity)
}

// Node::computed_values_establish_absolute_positioning_containing_block().
pub fn (n &Node) computed_values_establish_absolute_positioning_containing_block() bool {
	computed := n.computed_values()
	will_change := computed.will_change()
	if computed.position() != .static_ || will_change.has_property(.position) {
		return true
	}
	if computed.transformations().len > 0 || will_change.has_property(.transform) {
		return true
	}
	if computed.translate() != none || will_change.has_property(.translate) {
		return true
	}
	if computed.rotate() != none || will_change.has_property(.rotate) {
		return true
	}
	if computed.scale() != none || will_change.has_property(.scale) {
		return true
	}
	if computed.perspective() != none || will_change.has_property(.perspective) {
		return true
	}
	if (computed.filter().has_filters() || will_change.has_property(.filter))
		&& !n.is_root_element() {
		return true
	}
	if (computed.backdrop_filter().has_filters()
		|| will_change.has_property(.backdrop_filter)) && !n.is_root_element() {
		return true
	}
	if n.has_layout_containment() || n.has_paint_containment()
		|| will_change.has_property(.contain) {
		return true
	}
	if computed.transform_style() == .preserve_3d
		|| will_change.has_property(.transform_style) {
		return true
	}
	if (computed.backface_visibility() == .hidden
		|| will_change.has_property(.backface_visibility)) && n.is_transformable()
		&& n.participates_in_a_3d_rendering_context() {
		return true
	}
	return false
}

pub fn (n &Node) establishes_an_absolute_positioning_containing_block() bool {
	if !n.is_box() {
		return false
	}
	if n.is_viewport() {
		return true
	}
	// https://github.com/w3c/fxtf-drafts/issues/307#issuecomment-499612420
	// foreignObject establishes the containing block for positioned descendants.
	if n.is_svg_foreign_object_box() {
		return true
	}
	return n.computed_values_establish_absolute_positioning_containing_block()
}

pub fn (n &Node) establishes_a_fixed_positioning_containing_block() bool {
	if !n.is_box() {
		return false
	}
	if n.is_svg_foreign_object_box() {
		return true
	}
	computed := n.computed_values()
	will_change := computed.will_change()
	if computed.transformations().len > 0 || will_change.has_property(.transform) {
		return true
	}
	if computed.translate() != none || will_change.has_property(.translate) {
		return true
	}
	if computed.rotate() != none || will_change.has_property(.rotate) {
		return true
	}
	if computed.scale() != none || will_change.has_property(.scale) {
		return true
	}
	if computed.perspective() != none || will_change.has_property(.perspective) {
		return true
	}
	if (computed.filter().has_filters() || will_change.has_property(.filter))
		&& !n.is_root_element() {
		return true
	}
	if (computed.backdrop_filter().has_filters()
		|| will_change.has_property(.backdrop_filter)) && !n.is_root_element() {
		return true
	}
	if n.has_layout_containment() || n.has_paint_containment()
		|| will_change.has_property(.contain) {
		return true
	}
	if computed.transform_style() == .preserve_3d
		|| will_change.has_property(.transform_style) {
		return true
	}
	if (computed.backface_visibility() == .hidden
		|| will_change.has_property(.backface_visibility)) && n.is_transformable()
		&& n.participates_in_a_3d_rendering_context() {
		return true
	}
	return false
}

fn nearest_ancestor_capable_of_forming_a_containing_block(node &Node) ?&Box {
	mut ancestor := node.parent()
	for {
		candidate := ancestor or { return none }
		if candidate.is_block_container() || candidate.display().is_flex_inside()
			|| candidate.display().is_grid_inside() || candidate.is_replaced_box_with_children() {
			return candidate.as_box() or { panic('containing-block candidate must be a Box') }
		}
		ancestor = candidate.parent()
	}
	return none
}

fn (n &Node) root_viewport() ?&Viewport {
	mut current := unsafe { n }
	for {
		if viewport := current.as_viewport() {
			return viewport
		}
		current = current.parent() or { return none }
	}
	return none
}

fn find_inline_layout_node_for_dom(root &Node, target &dom.Element) ?&InlineNode {
	if inline := root.as_inline_node() {
		if dom_node := root.dom_node() {
			if voidptr(dom_node) == voidptr(target.as_node()) {
				return inline
			}
		}
	}
	for child in root.children() {
		if found := find_inline_layout_node_for_dom(child, target) {
			return found
		}
	}
	return none
}

struct InlineContainingBlockLookup {
mut:
	nodes map[u64]&InlineNode
}

fn collect_inline_containing_block_nodes(root &Node, mut lookup InlineContainingBlockLookup) {
	if inline := root.as_inline_node() {
		if dom_node := root.dom_node() {
			id := u64(dom_node.unique_id())
			// Inline continuations share a DOM node. Preserve the first pre-order
			// match selected by the original tree search.
			if id !in lookup.nodes {
				lookup.nodes[id] = inline
			}
		}
	}
	for child in root.children() {
		collect_inline_containing_block_nodes(child, mut lookup)
	}
}

fn lookup_inline_containing_block(root &Node, target &dom.Element, lookup &InlineContainingBlockLookup) ?&InlineNode {
	if lookup != unsafe { nil } {
		id := u64(target.as_node().unique_id())
		if id !in lookup.nodes {
			return none
		}
		return unsafe { lookup.nodes[id] }
	}
	return find_inline_layout_node_for_dom(root, target)
}

fn (mut n Node) recompute_inline_abspos_containing_block(lookup &InlineContainingBlockLookup) {
	containing_block := n.containing_block_ or { return }
	containing_dom_node := unsafe { &Node(containing_block) }.dom_node()
	mut dom_ancestor := if generator := n.pseudo_element_generator_ {
		?&dom.Element(generator)
	} else if dom_node := n.dom_node_ {
		dom_node.parent_or_shadow_host_element()
	} else {
		?&dom.Element(none)
	}
	viewport := n.root_viewport() or { return }
	root := unsafe { &Node(viewport) }
	for dom_ancestor != none {
		candidate := dom_ancestor or { break }
		if containing_dom := containing_dom_node {
			if voidptr(candidate.as_node()) == voidptr(containing_dom) {
				break
			}
		}
		if inline := lookup_inline_containing_block(root, candidate, lookup) {
			inline_node := unsafe { &Node(inline) }
			computed := inline_node.computed_values()
			will_change := computed.will_change()
			inline_establishes_cb := inline_node.is_positioned()
				|| will_change.has_property(.position) || computed.filter().has_filters()
				|| will_change.has_property(.filter)
				|| computed.backdrop_filter().has_filters()
				|| will_change.has_property(.backdrop_filter)
			if inline_establishes_cb {
				n.inline_containing_block_ = inline
				return
			}
		}
		dom_ancestor = candidate.as_node().parent_or_shadow_host_element()
	}
}

// Node::recompute_containing_block().
pub fn (mut n Node) recompute_containing_block() {
	n.recompute_containing_block_with_inline_lookup(unsafe { nil })
}

fn (mut n Node) recompute_containing_block_with_inline_lookup(lookup &InlineContainingBlockLookup) {
	n.inline_containing_block_ = none
	if n.is_text_node() {
		n.containing_block_ = nearest_ancestor_capable_of_forming_a_containing_block(n)
		return
	}
	position := n.computed_values().position()
	if position == .absolute {
		mut ancestor := n.parent()
		for {
			candidate := ancestor or {
				n.containing_block_ = none
				return
			}

			if candidate.establishes_an_absolute_positioning_containing_block() {
				n.containing_block_ = candidate.as_box()
				n.recompute_inline_abspos_containing_block(lookup)
				return
			}
			ancestor = candidate.parent()
		}
		return
	}
	if position == .fixed {
		mut ancestor := n.parent()
		for {
			candidate := ancestor or {
				viewport := n.root_viewport() or {
					n.containing_block_ = none
					return
				}
				n.containing_block_ = unsafe { &Box(viewport) }
				return
			}

			if candidate.establishes_a_fixed_positioning_containing_block() {
				n.containing_block_ = candidate.as_box()
				return
			}
			ancestor = candidate.parent()
		}
		return
	}
	n.containing_block_ = nearest_ancestor_capable_of_forming_a_containing_block(n)
}

pub fn (n &Node) static_position_containing_block() ?&Box {
	return nearest_ancestor_capable_of_forming_a_containing_block(n)
}

pub fn (n &Node) non_anonymous_containing_block() ?&Box {
	mut containing_block := n.containing_block_ or { return none }
	for containing_block.is_anonymous() {
		containing_block = containing_block.containing_block() or { return none }
	}
	return containing_block
}

pub fn recompute_containing_blocks(root &Node) {
	// DOM-side layout handles are attached after geometry is computed, so
	// upstream's direct DOM-to-inline lookup is not available during a rebuild.
	// Index the current tree once instead of searching it for every ancestor.
	viewport_root := if viewport := root.root_viewport() { unsafe { &Node(viewport) } } else { root }
	mut lookup := InlineContainingBlockLookup{}
	collect_inline_containing_block_nodes(viewport_root, mut lookup)
	recompute_containing_blocks_with_inline_lookup(root, &lookup)
}

fn recompute_containing_blocks_with_inline_lookup(root &Node, lookup &InlineContainingBlockLookup) {
	recompute_containing_blocks_preorder(root, lookup,
		nearest_ancestor_capable_of_forming_a_containing_block(root))
}

fn recompute_containing_blocks_preorder(root &Node, lookup &InlineContainingBlockLookup,
	nearest ?&Box) {
	mut mutable_root := unsafe { &Node(root) }
	if root.is_text_node() || root.computed_values().position() !in [.absolute, .fixed] {
		mutable_root.inline_containing_block_ = none
		mutable_root.containing_block_ = nearest
	} else {
		mutable_root.recompute_containing_block_with_inline_lookup(lookup)
	}
	mut child_nearest := nearest
	if root.is_block_container() || root.display().is_flex_inside()
		|| root.display().is_grid_inside() || root.is_replaced_box_with_children() {
		child_nearest = root.as_box() or { panic('containing-block candidate must be a Box') }
	}
	for child in root.children() {
		if parent := child.parent() {
			if voidptr(parent) == voidptr(root) {
				recompute_containing_blocks_preorder(child, lookup, child_nearest)
				continue
			}
		}
		// Preserve the standalone API for a staged move whose old child vector
		// still contains the node: its actual parent determines its containing box.
		recompute_containing_blocks_with_inline_lookup(child, lookup)
	}
}

// --- NodeWithStyle (Layout/Node.h) ---
//
// A layout node that has a computed style. As in C++, the layout-facing values
// are resolved once when the style is applied.
@[heap]
pub struct NodeWithStyle {
	Node
pub mut:
	computed_values_  &css.ComputedValues = unsafe { nil }
	list_style_image_ ?css.StyleValue
	image_observers_  []&ImageObserver
	layout_index_     u32
	// The index of the last layout tree before reindexing; a rebuild shifts
	// the indices after each insertion (line_box_equality.v).
	previous_layout_index_ u32
mut:
	inherited_style_proof_ &css.LayoutInheritanceProof = unsafe { nil }
}

fn materialize_list_style_image(computed_values &css.ComputedProperties, document &dom.Document) ?css.StyleValue {
	mut value := computed_values.typed_property_value(.list_style_image) or { return none }
	if !value.is_abstract_image() {
		return none
	}
	match mut value {
		css.ImageStyleValue {
			mut mutable_document := unsafe { &dom.Document(document) }
			value.load_any_resources(mut mutable_document)
		}
		css.ImageSetStyleValue {
			mut mutable_document := unsafe { &dom.Document(document) }
			value.load_any_resources(mut mutable_document, document.device_pixels_per_css_pixel())
		}
		else {}
	}
	return value
}

pub fn NodeWithStyle.new(document &dom.Document, dom_node ?&dom.Node, computed_values &css.ComputedProperties) &NodeWithStyle {
	values := computed_values_in_layout_coordinates(computed_values, document)
	if node := dom_node {
		mut mutable_values := unsafe { &css.MutableComputedValues(values) }
		mutable_values.set_list_style_type(computed_values.list_style_type_for_scope(css.style_scope_for_dom_node(node)))
	}
	return &NodeWithStyle{
		Node: Node{
			document_: document
			dom_node_: dom_node
			has_style_: true
			is_body_: if node := dom_node { node.is_html_body_element() } else { false }
		}
		computed_values_: values
		list_style_image_: materialize_list_style_image(computed_values, document)
	}
}

pub fn (n &NodeWithStyle) computed_values() &css.ComputedValues {
	return n.computed_values_
}

pub fn (n &NodeWithStyle) list_style_image() ?css.StyleValue {
	return n.list_style_image_
}

pub fn (n &NodeWithStyle) style_scope() &css.StyleScope {
	if dom_node := n.dom_node_ {
		return css.style_scope_for_dom_node(dom_node)
	}
	if generator := n.pseudo_element_generator_ {
		return css.style_scope_for_dom_node(generator.as_node())
	}
	if parent := n.parent() {
		if styled_parent := parent.as_node_with_style() {
			return styled_parent.style_scope()
		}
	}
	return css.style_scope_for_dom_node(unsafe { &dom.Node(n.document_) })
}

pub fn (mut n NodeWithStyle) set_computed_values(computed_values &css.ComputedProperties) {
	n.computed_values_ = computed_values_in_layout_coordinates(computed_values, n.document_)
	mut mutable_values := unsafe { &css.MutableComputedValues(n.computed_values_) }
	mutable_values.set_list_style_type(computed_values.list_style_type_for_scope(n.style_scope()))
	n.list_style_image_ = materialize_list_style_image(computed_values, n.document_)
}

pub fn (mut n NodeWithStyle) apply_style(computed_style &css.ComputedProperties) {
	n.computed_values_ = computed_values_in_layout_coordinates(computed_style, n.document_)
	mut mutable_values := unsafe { &css.MutableComputedValues(n.computed_values_) }
	mutable_values.set_list_style_type(computed_style.list_style_type_for_scope(n.style_scope()))
	n.list_style_image_ = materialize_list_style_image(computed_style, n.document_)
	n.propagate_style_to_anonymous_wrappers()
	if metrics := unsafe { &Node(n) }.as_node_with_style_and_box_model_metrics() {
		metrics.propagate_style_along_continuation(computed_style)
	}
	n.rebuild_image_observers()
}

fn image_style_value_layout_did_update(target voidptr) {
	observer := unsafe { &ImageObserver(target) }
	mut owner := observer.owner
	owner.image_style_value_did_update()
}

// Layout::NodeWithStyle::ImageObserver has its own registration identity.
// Replacing a slot must not unregister the new slot for the same image.
@[heap]
pub struct ImageObserver {
pub:
	owner &NodeWithStyle
	image css.ImageStyleValue
}

fn ImageObserver.create(owner &NodeWithStyle, image css.ImageStyleValue) &ImageObserver {
	observer := &ImageObserver{owner: owner, image: image}
	image.register_client(css.ImageStyleValueClient{
		target: voidptr(observer)
		did_update: image_style_value_layout_did_update
	})
	return observer
}

fn (mut n NodeWithStyle) image_style_value_did_update() {
	if dom_node := n.dom_node_ {
		mut mutable_node := unsafe { &dom.Node(dom_node) }
		mutable_node.set_needs_repaint(.paint_commands)
	}
	if !n.is_body_ || !n.body_background_is_propagated_to_root() {
		return
	}
	html_element := n.document_.html_element() or { return }
	mut html_node := html_element.as_node()
	html_node.set_needs_repaint(.paint_commands)
}

fn (n &NodeWithStyle) body_background_is_propagated_to_root() bool {
	body := n.document_.body() or { return false }
	body_dom_node := unsafe { &dom.Element(body) }.as_node()
	if dom_node := n.dom_node() {
		if voidptr(dom_node) != voidptr(body_dom_node) {
			return false
		}
	} else {
		return false
	}
	html_element := n.document_.html_element() or { return false }
	html_layout_node := html_element.as_node().unsafe_layout_node() or { return false }
	if html_layout_node.real_layout_handle() == unsafe { nil } {
		return false
	}
	html_node := unsafe { &Node(html_layout_node.real_layout_handle()) }
	html_styled := html_node.as_node_with_style() or { return false }
	return html_styled.computed_values().contain().is_empty()
		&& n.computed_values().contain().is_empty()
		&& html_styled.computed_values().background_layers().len == 0
		&& html_styled.computed_values().background_color().a == 0
}

fn (mut n NodeWithStyle) add_image_observer(image css.ImageStyleValue) {
	n.image_observers_ << ImageObserver.create(&n, image)
}

fn (mut n NodeWithStyle) add_image_observer_for_style_value(value css.StyleValue) {
	match value {
		css.ImageStyleValue {
			n.add_image_observer(value)
		}
		css.ImageSetStyleValue {
			selected := value.selected_image() or { return }
			if selected is css.ImageStyleValue {
				n.add_image_observer(selected)
			}
		}
		else {}
	}
}

fn (mut n NodeWithStyle) rebuild_image_observers() {
	old_observers := n.image_observers_
	n.image_observers_ = []&ImageObserver{}

	if background := n.computed_values_.typed_property_value(.background_image) {
		if list := background.as_value_list() {
			for value in list.values() {
				n.add_image_observer_for_style_value(value)
			}
		} else {
			n.add_image_observer_for_style_value(background)
		}
	}
	if mask := n.computed_values_.typed_property_value(.mask_image) {
		if list := mask.as_value_list() {
			for value in list.values() {
				n.add_image_observer_for_style_value(value)
			}
		} else {
			n.add_image_observer_for_style_value(mask)
		}
	}
	if cursor := n.computed_values_.typed_property_value(.cursor) {
		if list := cursor.as_value_list() {
			for value in list.values() { n.add_cursor_image_observer(value) }
		} else { n.add_cursor_image_observer(cursor) }
	}
	if border_image := n.computed_values_.typed_property_value(.border_image_source) {
		n.add_image_observer_for_style_value(border_image)
	}
	if list_style_image := n.list_style_image_ {
		n.add_image_observer_for_style_value(list_style_image)
	}
	// New clients are registered before any old client is released, preserving
	// the resource when the old and new style share the same underlying image.
	for observer in old_observers {
		observer.image.unregister_client(voidptr(observer))
	}
}

fn (mut n NodeWithStyle) add_cursor_image_observer(value css.StyleValue) {
	if value is css.CursorStyleValue {
		image := value.image().value
		match image {
			css.ImageStyleValue { n.add_image_observer(image) }
			css.ImageSetStyleValue { n.add_image_observer_for_style_value(css.StyleValue(image)) }
			else {}
		}
	}
}

pub fn (mut n NodeWithStyle) clear_image_observers() {
	for observer in n.image_observers_ {
		observer.image.unregister_client(voidptr(observer))
	}
	n.image_observers_ = []&ImageObserver{}
}

fn (mut n NodeWithStyle) propagate_style_to_anonymous_wrappers() {
	node := unsafe { &Node(n) }
	// A table wrapper inherits from its table root, not the other way around.
	if parent := node.parent() {
		if parent.is_table_wrapper() && node.display().is_table_inside() {
			element_style := unsafe { &css.ComputedProperties(n.computed_values_) }
			table_style, wrapper_style := element_style.table_box_and_wrapper_properties()
			n.computed_values_ = computed_values_in_layout_coordinates(table_style, n.document_)
			if wrapper_styled := parent.as_node_with_style() {
				mut mutable_wrapper := unsafe { &NodeWithStyle(wrapper_styled) }
				mutable_wrapper.set_computed_values(wrapper_style)
			}
		}
	}

	for child in node.children() {
		if !child.is_anonymous() || child.is_table_wrapper() {
			continue
		}
		child_styled := child.as_node_with_style() or { continue }
		mut mutable_child := unsafe { &NodeWithStyle(child_styled) }
		mut child_values := unsafe { &css.MutableComputedValues(mutable_child.computed_values_) }
		if !css.layout_inheritance_is_current(mutable_child.inherited_style_proof_,
			child_values, n.computed_values_, n.document_) {
			child_values.inherit_from(n.computed_values_)
			mutable_child.inherited_style_proof_ = css.refresh_layout_inheritance_proof(
				mutable_child.inherited_style_proof_, child_values, n.computed_values_, n.document_)
		}
		mutable_child.propagate_style_to_anonymous_wrappers()
	}
}

pub fn (n &NodeWithStyle) layout_index() u32 {
	return n.layout_index_
}

pub fn (mut n NodeWithStyle) set_layout_index(index u32) {
	n.layout_index_ = index
}

// DOM::Document::update_layout assigns dense indices to every styled node in
// inclusive pre-order before constructing LayoutState. Text nodes intentionally
// do not consume an index because they do not have independent UsedValues.
pub fn assign_layout_indexes(root &Node) u32 {
	mut order := &LayoutTreeOrder{}
	count := assign_layout_indexes_in_subtree(root, 0, mut order)
	order.valid = true
	return count
}

fn assign_layout_indexes_in_subtree(node &Node, starting_index u32, mut order LayoutTreeOrder) u32 {
	// Reindexing a subtree also invalidates the enclosing tree's old ranges.
	node.invalidate_tree_order()
	mut mutable_node := unsafe { &Node(node) }
	mutable_node.tree_order_ = &order
	mutable_node.tree_order_owner_ = voidptr(node)
	mutable_node.tree_order_start_ = order.next_index
	order.next_index++
	mut next_index := starting_index
	if styled := node.as_node_with_style() {
		mut mutable_styled := unsafe { &NodeWithStyle(styled) }
		mutable_styled.previous_layout_index_ = mutable_styled.layout_index_
		mutable_styled.set_layout_index(next_index)
		next_index++
	}
	for child in node.children() {
		next_index = assign_layout_indexes_in_subtree(child, next_index, mut order)
	}
	mutable_node.tree_order_end_ = order.next_index
	return next_index
}

// Cast a &Node to &NodeWithStyle. Layout::Node is abstract in C++ (every concrete layout node is a
// NodeWithStyle or below), so a styled node embeds Node at offset 0 and this reinterpret is valid.
pub fn (n &Node) as_node_with_style() ?&NodeWithStyle {
	if !n.has_style_ {
		return none
	}
	return unsafe { &NodeWithStyle(n) }
}

pub fn (n &Node) as_node_with_style_and_box_model_metrics() ?&NodeWithStyleAndBoxModelMetrics {
	if !n.has_style_ || (!n.is_box_ && !n.is_inline_node_ && !n.is_break_node_) {
		return none
	}
	return unsafe { &NodeWithStyleAndBoxModelMetrics(n) }
}

// --- NodeWithStyleAndBoxModelMetrics (Layout/Node.h) ---
//
// A styled node that participates in the box model. C++ also stores box-model metrics here, but current
// Ladybird keeps the used margin/padding/border values in LayoutState::UsedValues, so this type is thin.
@[heap]
pub struct NodeWithStyleAndBoxModelMetrics {
	NodeWithStyle
pub mut:
	continuation_of_node_ ?&NodeWithStyleAndBoxModelMetrics
}

pub fn (n &NodeWithStyleAndBoxModelMetrics) continuation_of_node() ?&NodeWithStyleAndBoxModelMetrics {
	return n.continuation_of_node_
}

fn is_inline_flow_interrupting_block_with_parent(node &Node, parent &Node) bool {
	// This node remains a layout child of its inline-flow parent. The inline
	// iterator emits it as a block-level item and lays it out between lines.
	parent_display := parent.display()
	if !parent_display.is_inline_outside() || !parent_display.is_flow_inside() {
		return false
	}

	// This node must not be inline itself or out of flow (which gets handled separately).
	if node.display().is_inline_outside() || node.is_out_of_flow() {
		return false
	}

	// This node must not have `display: contents`; interrupting-block handling
	// is delegated to its children.
	if node.display().is_contents() {
		return false
	}

	// Internal table display types and table captions are handled by the table fixup algorithm.
	if node.display().is_internal_table() || node.display().is_table_caption() {
		return false
	}

	// Parent element must not be <foreignObject>.
	if parent_dom_node := parent.dom_node() {
		if parent_element := parent_dom_node.as_element() {
			if parent_element.is_svg_element() && parent_element.local_name() == 'foreignObject' {
				return false
			}
		}
	}

	// Non-root SVG elements and foreign object boxes do not interrupt inline flow.
	if node.is_svg_box() || node.is_svg_foreign_object_box() {
		return false
	}

	// Nested SVG roots do not interrupt inline flow, but a top-level SVG root
	// inside an HTML inline element does.
	if node.is_svg_svg_box() && (parent.is_svg_box() || parent.is_svg_svg_box()) {
		return false
	}

	// Replaced boxes with children (e.g. media elements with shadow DOM controls)
	// have their own formatting context; their children do not interrupt flow.
	if parent.is_replaced_box_with_children() {
		return false
	}

	return true
}

pub fn (n &NodeWithStyleAndBoxModelMetrics) is_inline_flow_interrupting_block() bool {
	node := unsafe { &Node(n) }
	parent := node.parent() or { return false }
	return is_inline_flow_interrupting_block_with_parent(node, parent)
}

pub fn (n &NodeWithStyleAndBoxModelMetrics) propagate_style_along_continuation(computed_style &css.ComputedProperties) {
	mut continuation := n.continuation_of_node()
	for continuation != none {
		current := continuation or { return }
		current_node := unsafe { &Node(current) }
		if !current_node.is_anonymous() {
			mut styled := unsafe { &NodeWithStyle(current) }
			styled.apply_style(computed_style)
			return
		}
		continuation = current.continuation_of_node()
	}
}

// --- InlineNode (Layout/InlineNode.h) : NodeWithStyleAndBoxModelMetrics ---

@[heap]
pub struct InlineNode {
	NodeWithStyleAndBoxModelMetrics
}

pub fn InlineNode.new(document &dom.Document, dom_node ?&dom.Node, computed_values &css.ComputedProperties) &InlineNode {
	return &InlineNode{
		NodeWithStyleAndBoxModelMetrics: NodeWithStyleAndBoxModelMetrics{
			NodeWithStyle: NodeWithStyle{
				Node: Node{
					document_: document
					dom_node_: dom_node
					has_style_: true
					is_inline_node_: true
				}
				computed_values_: computed_values_in_layout_coordinates(computed_values, document)
			}
		}
	}
}

pub fn (n &Node) is_inline_node() bool {
	return n.is_inline_node_
}

pub fn (n &Node) as_inline_node() ?&InlineNode {
	if !n.is_inline_node_ {
		return none
	}
	return unsafe { &InlineNode(n) }
}

// --- BreakNode (Layout/BreakNode.h) : NodeWithStyleAndBoxModelMetrics ---

@[heap]
pub struct BreakNode {
	NodeWithStyleAndBoxModelMetrics
}

pub fn BreakNode.new(document &dom.Document, dom_node &dom.Node, computed_values &css.ComputedProperties) &BreakNode {
	return &BreakNode{
		NodeWithStyleAndBoxModelMetrics: NodeWithStyleAndBoxModelMetrics{
			NodeWithStyle: NodeWithStyle{
				Node: Node{
					document_: document
					dom_node_: dom_node
					has_style_: true
					is_break_node_: true
				}
				computed_values_: computed_values_in_layout_coordinates(computed_values, document)
			}
		}
	}
}

pub fn (n &Node) is_break_node() bool {
	return n.is_break_node_
}

pub fn (n &Node) as_break_node() ?&BreakNode {
	if !n.is_break_node_ {
		return none
	}
	return unsafe { &BreakNode(n) }
}

// --- Box (Layout/Box.h) : NodeWithStyleAndBoxModelMetrics ---
//
// A box in the layout tree. The used geometry (content size, offsets) lives in LayoutState::UsedValues;
// the persistent Box holds intrinsic-size caches (added later), out-of-flow abspos children, and the
// natural (intrinsic) size for replaced elements.
@[heap]
pub struct Box {
	NodeWithStyleAndBoxModelMetrics
pub mut:
	contained_abspos_children_ []&Node
	cached_intrinsic_sizes_    ?&IntrinsicSizes
	natural_size_              css.SizeWithAspectRatio
	has_auto_content_box_size_ bool
	auto_content_box_size_     css.SizeWithAspectRatio
	position_try_state_ ?&PositionTryLayoutState
}

@[heap]
struct IntrinsicHeightOverflow {
mut:
	values map[int]?CSSPixels
}

@[heap]
struct IntrinsicHeightCache {
mut:
	first_width int
	first_value ?CSSPixels
	overflow    &IntrinsicHeightOverflow = unsafe { nil }
}

@[heap]
pub struct IntrinsicSizes {
pub mut:
	min_content_width         ?CSSPixels
	max_content_width         ?CSSPixels
	table_grid_width_measures ?&TableGridIntrinsicWidths
mut:
	font_generation_ u64
	min_content_height_ &IntrinsicHeightCache = unsafe { nil }
	max_content_height_ &IntrinsicHeightCache = unsafe { nil }
}

fn (cache &IntrinsicSizes) height_cache(minimum bool) &IntrinsicHeightCache {
	return if minimum { cache.min_content_height_ } else { cache.max_content_height_ }
}

fn (cache &IntrinsicSizes) has_cached_content_height(minimum bool, width int) bool {
	heights := cache.height_cache(minimum)
	return heights != unsafe { nil } && (heights.first_width == width
		|| (heights.overflow != unsafe { nil } && width in heights.overflow.values))
}

fn (cache &IntrinsicSizes) cached_content_height(minimum bool, width int) ?CSSPixels {
	heights := cache.height_cache(minimum)
	if heights == unsafe { nil } { return none }
	if heights.first_width == width { return heights.first_value }
	if heights.overflow == unsafe { nil } || width !in heights.overflow.values {
		return none
	}
	return unsafe { heights.overflow.values[width] }
}

fn (mut cache IntrinsicSizes) cache_content_height(minimum bool, width int, value ?CSSPixels) {
	persistent := platform.enter_persistent_if(platform.transient_arena_entered())
	defer { platform.leave_persistent(persistent) }
	mut heights := cache.height_cache(minimum)
	if heights == unsafe { nil } {
		heights = &IntrinsicHeightCache{ first_width: width, first_value: value }
		if minimum { cache.min_content_height_ = heights }
		else { cache.max_content_height_ = heights }
		return
	}
	if heights.first_width == width {
		heights.first_value = value
		return
	}
	if heights.overflow == unsafe { nil } {
		heights.overflow = &IntrinsicHeightOverflow{}
	}
	heights.overflow.values[width] = value
}

pub fn Box.new(document &dom.Document, dom_node ?&dom.Node, computed_values &css.ComputedProperties) &Box {
	return &Box{
		NodeWithStyleAndBoxModelMetrics: NodeWithStyleAndBoxModelMetrics{
			NodeWithStyle: NodeWithStyle{
				Node: Node{
					document_: document
					dom_node_: dom_node
					has_style_: true
					is_box_: true
				}
				computed_values_: computed_values_in_layout_coordinates(computed_values, document)
			}
		}
	}
}

pub fn (n &Box) contained_abspos_children() []&Node {
	return n.contained_abspos_children_
}

pub fn (mut n Box) add_contained_abspos_child(child &Node) {
	n.contained_abspos_children_ << child
}

pub fn (mut n Box) clear_contained_abspos_children() {
	n.contained_abspos_children_.clear()
}

pub fn (mut n Box) cached_intrinsic_sizes() &IntrinsicSizes {
	// A loaded face can replace fallback advances without changing this box's
	// computed style or dirty bit. Width and height probes must use one font epoch.
	generation := css.css_style_computer_for(n.document()).font_computer().environment_generation()
	if mut cached := n.cached_intrinsic_sizes_ {
		if cached.font_generation_ == generation { return cached }
		if !disable_intrinsic_font_reuse
			&& intrinsic_fonts_are_unchanged_since(unsafe { &Node(n) }, cached.font_generation_) {
			cached.font_generation_ = generation
			report_intrinsic_font_reuse()
			return cached
		}
	}
	persistent := platform.enter_persistent_if(platform.transient_arena_entered())
	new_cache := &IntrinsicSizes{font_generation_: generation}
	platform.leave_persistent(persistent)
	n.cached_intrinsic_sizes_ = new_cache
	return new_cache
}

pub fn (mut n Box) reset_cached_intrinsic_sizes() {
	n.cached_intrinsic_sizes_ = none
}

pub fn (n &Box) natural_size() css.SizeWithAspectRatio {
	// C++ dispatches this virtual call to VideoBox::natural_size(), whose
	// dimensions are live media metadata rather than constructor-time state.
	// Preserve that behavior even though V represents the hierarchy by
	// embedding concrete boxes in this common record.
	if dom_node := n.dom_node() {
		if element := dom_node.as_element() {
			if element.is_html_element() && element.local_name() == 'video' {
				return unsafe { &VideoBox(n) }.natural_size()
			}
			if n.is_navigable_container_viewport() {
				return unsafe { &NavigableContainerViewport(n) }.natural_size()
			}
		}
	}
	return natural_size_in_layout_coordinates(n.natural_size_, n.document_)
}

pub fn (n &Box) has_auto_content_box_size() bool {
	return n.has_auto_content_box_size_ || chromium_menu_list(unsafe { &Node(n) })
}

pub fn (n &Box) auto_content_box_size() css.SizeWithAspectRatio {
	if unsafe { &Node(n) }.has_size_containment() {
		node := unsafe { &Node(n) }
		return css.SizeWithAspectRatio{
			width: node.explicit_intrinsic_inner_width() or { CSSPixels.new(0) }
			height: node.explicit_intrinsic_inner_height() or { CSSPixels.new(0) }
		}
	}
	if chromium_menu_list(unsafe { &Node(n) }) {
		return chromium_menu_list_auto_size(unsafe { &Node(n) })
	}
	if n.has_auto_content_box_size_ {
		node := unsafe { &Node(n) }
		if node.is_text_input_box() {
			return text_input_auto_content_box_size(node)
		}
		// Font-sized controls compute their auto dimensions from the already
		// projected layout font. Image metadata and fixed replaced defaults,
		// in contrast, are stored in CSS pixels and still need projection.
		if node.is_range_input_box() || node.is_textarea_box() {
			return n.auto_content_box_size_
		}
		return natural_size_in_layout_coordinates(n.auto_content_box_size_, n.document_)
	}
	// Box::compute_auto_content_box_size() falls back to the virtual
	// natural_size() result. In particular, VideoBox metadata is live and is
	// not stored in the embedded Box record.
	return n.natural_size()
}

// Box::preferred_aspect_ratio(). Size containment suppresses natural metrics,
// while `auto <ratio>` uses the natural ratio when one exists and falls back
// to the specified ratio otherwise.
pub fn (n &Box) preferred_aspect_ratio() ?CSSPixelFraction {
	computed_aspect_ratio := n.computed_values().aspect_ratio()
	if !unsafe { &Node(n) }.has_size_containment()
		&& computed_aspect_ratio.use_natural_aspect_ratio_if_available {
		auto_size := n.auto_content_box_size()
		if natural_ratio := auto_size.aspect_ratio {
			return natural_ratio
		}
	}
	ratio := computed_aspect_ratio.preferred_ratio or { return none }
	if ratio.is_degenerate() {
		return none
	}
	fraction := CSSPixelFraction.from_values(ratio.numerator(), ratio.denominator())
	if fraction.numerator().raw_value() == 0 {
		return none
	}
	return fraction
}

pub fn (n &Box) has_preferred_aspect_ratio() bool {
	return n.preferred_aspect_ratio() != none
}

pub fn (n &Node) is_box() bool {
	return n.is_box_
}

pub fn (n &Node) as_box() ?&Box {
	if !n.is_box_ {
		return none
	}
	return unsafe { &Box(n) }
}

// --- BlockContainer (Layout/BlockContainer.h) : Box ---
//
// A box that contains either only block-level boxes or only inline-level boxes (a block container).
@[heap]
pub struct BlockContainer {
	Box
}

pub fn BlockContainer.new(document &dom.Document, dom_node ?&dom.Node, computed_values &css.ComputedProperties) &BlockContainer {
	return BlockContainer.with_resolved_values(document, dom_node, computed_values_in_layout_coordinates(computed_values, document))
}

fn BlockContainer.with_resolved_values(document &dom.Document, dom_node ?&dom.Node, computed_values &css.ComputedValues) &BlockContainer {
	return &BlockContainer{
		Box: Box{
			NodeWithStyleAndBoxModelMetrics: NodeWithStyleAndBoxModelMetrics{
				NodeWithStyle: NodeWithStyle{
					Node: Node{
						document_: document
						dom_node_: dom_node
						has_style_: true
						is_box_: true
						is_block_container_: true
					}
					computed_values_: computed_values
				}
			}
		}
	}
}

pub fn (n &Node) is_block_container() bool {
	return n.is_block_container_
}

pub fn (n &Node) as_block_container() ?&BlockContainer {
	if !n.is_block_container_ {
		return none
	}
	return unsafe { &BlockContainer(n) }
}

// --- ListItemBox (Layout/ListItemBox.h) : BlockContainer ---

@[heap]
pub struct ListItemBox {
	BlockContainer
pub mut:
	marker_ ?&Node
}

pub fn ListItemBox.new(document &dom.Document, dom_node ?&dom.Node, computed_values &css.ComputedProperties) &ListItemBox {
	return &ListItemBox{
		BlockContainer: BlockContainer{
			Box: Box{
				NodeWithStyleAndBoxModelMetrics: NodeWithStyleAndBoxModelMetrics{
					NodeWithStyle: NodeWithStyle{
						Node: Node{
							document_: document
							dom_node_: dom_node
							has_style_: true
							is_box_: true
							is_block_container_: true
							is_list_item_box_: true
						}
						computed_values_: computed_values_in_layout_coordinates(computed_values, document)
					}
				}
			}
		}
	}
}

pub fn (n &Node) is_list_item_box() bool {
	return n.is_list_item_box_
}

pub fn (n &Node) is_replaced_box() bool {
	return n.is_replaced_box_
}

pub fn (n &Node) is_navigable_container_viewport() bool {
	return n.is_navigable_container_viewport_
}

pub fn (n &Node) is_image_box() bool {
	return n.is_image_box_
}

pub fn (n &Node) is_replaced_box_with_children() bool {
	return n.is_replaced_box_ && n.can_have_children()
}

pub fn (n &Node) is_fieldset_box() bool {
	return n.is_fieldset_box_
}

pub fn (n &Node) is_legend_box() bool {
	return n.is_legend_box_
}

pub fn (n &Node) is_textarea_box() bool {
	return n.is_textarea_box_
}

pub fn (n &Node) is_text_input_box() bool {
	return n.is_text_input_box_
}

pub fn (n &Node) is_range_input_box() bool {
	return n.is_range_input_box_
}

pub fn (n &Node) is_table_wrapper() bool {
	return n.is_table_wrapper_
}

pub fn (n &Node) is_list_item_marker_box() bool {
	return n.is_list_item_marker_box_
}

pub fn (n &Node) as_list_item_marker_box() ?&ListItemMarkerBox {
	if !n.is_list_item_marker_box_ {
		return none
	}
	return unsafe { &ListItemMarkerBox(n) }
}

pub fn (n &Node) as_list_item_box() ?&ListItemBox {
	if !n.is_list_item_box_ {
		return none
	}
	return unsafe { &ListItemBox(n) }
}

pub fn (n &ListItemBox) marker() ?&Node {
	return n.marker_
}

pub fn (mut n ListItemBox) set_marker(marker ?&Node) {
	n.marker_ = marker
}

// --- Viewport (Layout/Viewport.h) : BlockContainer ---
//
// The layout tree's root: a block container whose DOM node is the Document itself and whose content box is
// the viewport (initial containing block).
pub struct TextPosition {
pub:
	dom_node     &dom.Text
	start_offset int
}

pub struct TextBlock {
pub:
	text      string
	positions []TextPosition
}

struct ViewportTextBlockBuilder {
mut:
	current_text           string
	current_start_position int
	text_positions         []TextPosition
	text_blocks            []TextBlock
}

@[heap]
pub struct Viewport {
	BlockContainer
mut:
	text_blocks_ ?[]TextBlock
	// Decoded SVG images belong to the committed layout tree, like the paint
	// layers which consume them. Equal resources can share their isolated
	// document and retained layout without keeping documents in a global cache.
	svg_image_documents_ map[string]SVGImageDocumentCacheEntry
	static_svg_backgrounds_ map[string]&StaticSVGBackgroundResource
	paint_svg_sources_ &PaintSVGSourceSession = unsafe { nil }
}

// Viewport(DOM::Document&, ComputedProperties) — its DOM node is the document, per Viewport.cpp.
pub fn Viewport.new(document &dom.Document, computed_values &css.ComputedProperties) &Viewport {
	document_node := unsafe { &dom.Node(document) }
	return &Viewport{
		BlockContainer: BlockContainer{
			Box: Box{
				NodeWithStyleAndBoxModelMetrics: NodeWithStyleAndBoxModelMetrics{
					NodeWithStyle: NodeWithStyle{
						Node: Node{
							document_: document
							dom_node_: document_node
							has_style_: true
							is_box_: true
							is_block_container_: true
							is_viewport_: true
						}
						computed_values_: computed_values_in_layout_coordinates(computed_values, document)
					}
				}
			}
		}
	}
}

pub fn (n &Node) is_viewport() bool {
	return n.is_viewport_
}

pub fn (n &Node) as_viewport() ?&Viewport {
	if !n.is_viewport_ {
		return none
	}
	return unsafe { &Viewport(n) }
}

fn (mut builder ViewportTextBlockBuilder) flush() {
	if builder.current_text.len == 0 {
		return
	}
	builder.text_blocks << TextBlock{
		text: builder.current_text
		positions: builder.text_positions.clone()
	}
	builder.current_start_position = 0
	builder.text_positions.clear()
	builder.current_text = ''
}

fn collect_viewport_text_blocks(node &Node, mut builder ViewportTextBlockBuilder) {
	// Upstream requires a visible paintable. The typed V layout tree is itself the
	// paintable source, so computed visibility is the equivalent visibility test.
	if node.display().is_none() || node.computed_values().visibility() != .visible {
		for child in node.children() {
			collect_viewport_text_blocks(child, mut builder)
		}
		return
	}

	if node.is_box() || node.is_generated_for_pseudo_element() {
		builder.flush()
	} else if text_node := node.as_text_node() {
		if dom_node := text_node.dom_node() {
			if dom_node.is_text() && !dom_node.is_inert() {
				builder.text_positions << TextPosition{
					dom_node: unsafe { &dom.Text(dom_node) }
					start_offset: if builder.text_positions.len == 0 {
						0
					} else {
						builder.current_start_position
					}
				}
				current_text := text_node.text_for_rendering()
				builder.current_start_position += utf16_length_for_line_box(current_text)
				builder.current_text += current_text
			}
		}
	}

	for child in node.children() {
		collect_viewport_text_blocks(child, mut builder)
	}
}

fn (mut viewport Viewport) update_text_blocks() {
	mut builder := ViewportTextBlockBuilder{}
	collect_viewport_text_blocks(unsafe { &Node(&viewport) }, mut builder)
	builder.flush()
	viewport.text_blocks_ = builder.text_blocks
}

pub fn (viewport &Viewport) text_blocks() []TextBlock {
	mut mutable_viewport := unsafe { &Viewport(viewport) }
	if mutable_viewport.text_blocks_ == none {
		mutable_viewport.update_text_blocks()
	}
	return mutable_viewport.text_blocks_ or { []TextBlock{} }
}

pub fn (mut viewport Viewport) invalidate_text_blocks_cache() {
	viewport.text_blocks_ = none
}

// --- TextNode (Layout/TextNode.h) : Node ---
//
// A layout node for a DOM text node. Unlike element boxes it has no independent style (it uses its
// parent's), so it embeds Node directly rather than NodeWithStyle. It holds the whitespace-processed text.
@[heap]
pub struct TextNode {
	Node
mut:
	cached_grapheme_boundaries_ []int
	cached_inline_bidi_processing_ ?bool
pub mut:
	source_text_                  string
	text_for_rendering_           string
	text_for_rendering_valid_     bool
	rendered_text_is_ascii_       bool
	rendered_utf16_length_        int
	font_for_rendering_           ?&platform.Font
	line_segmenter_               &dom.Segmenter = unsafe { nil }
	is_empty_editable_            bool
	produces_line_box_fragment_when_empty_ bool
	retains_empty_generated_fragment_ bool
	cached_inline_chunks_         ?[]TextNodeChunk
	cached_font_environment_generation_ u64
	cached_inline_font_owner_ ?&css.FontCascadeList
	cached_inline_font_style_ voidptr
	cached_inline_font_style_revision_ u64
	cached_utf16_code_units_      ?[]u16
	cached_intrinsic_text_shapes_ []IntrinsicTextShapeCacheEntry
	cached_intrinsic_shape_order_ &IntrinsicTextShapeOrder = unsafe { nil }
	source_range_start_                    int
	source_range_length_                   ?int
	first_letter_                          ?&TextNode
	attach_to_dom_node_                    bool = true
	rendered_text_edits_                   []platform.TextMappingEdit
	rendered_source_length_                int
	safe_break_width_cache_ &platform.SafeBreakWidthCache = unsafe { nil }
}

pub fn (n &TextNode) font_for_rendering() &platform.Font {
	// A lazy @font-face may become available while the first layout pass is
	// shaping this node. Re-resolve through the retained ComputedValues on the
	// stabilization pass instead of returning the fallback cached by that first
	// pass.
	mut mutable_node := unsafe { &TextNode(n) }
	font := n.Node.first_available_font()
	mutable_node.font_for_rendering_ = font
	return font
}

pub fn (n &TextNode) line_segmenter() &dom.Segmenter {
	mut mutable_node := unsafe { &TextNode(n) }
	if mutable_node.line_segmenter_ == unsafe { nil } {
		persistent := platform.enter_persistent_if(platform.transient_arena_entered())
		defer { platform.leave_persistent(persistent) }
		text := n.text_for_rendering()
		if ascii_segmenter := dom.Segmenter.try_create_for_ascii_line(text) {
			mutable_node.line_segmenter_ = ascii_segmenter
		} else {
			mut document := unsafe { &dom.Document(n.Node.document()) }
			mutable_node.line_segmenter_ = document.line_segmenter().clone()
			mutable_node.line_segmenter_.set_segmented_text(text)
		}
	}
	return mutable_node.line_segmenter_
}

pub fn TextNode.new(document &dom.Document, dom_text_node &dom.Node, source_text string) &TextNode {
	mut node := &TextNode{
		Node: Node{
			document_: document
			dom_node_: dom_text_node
			is_text_node_: true
		}
		source_text_: source_text
	}
	node.update_produces_line_box_fragment_when_empty_flag()
	return node
}

// Layout/TextNode.cpp. Synthetic V control editors carry is_empty_editable_
// in place of the upstream FormAssociatedTextControlElement shadow host.
pub fn (mut node TextNode) update_produces_line_box_fragment_when_empty_flag() bool {
	mut produces := node.is_empty_editable_
	if text := node.dom_node() {
		if root := text.root().as_shadow_root() {
			if host := root.host() {
				produces = produces || (host.is_html_element()
					&& host.local_name() in ['input', 'textarea'])
			}
		}
		if parent := text.parent() {
			produces = produces || parent.is_editing_host()
		}
	}
	if node.produces_line_box_fragment_when_empty_ == produces {
		return false
	}
	node.produces_line_box_fragment_when_empty_ = produces
	// The cached chunk list may contain an empty fragment from the old state.
	node.cached_inline_chunks_ = none
	node.cached_intrinsic_text_shapes_.clear()
	return true
}

// GeneratedTextNode is layout-owned and deliberately has no corresponding DOM
// text node. Its pseudo-element generator supplies inherited style context.
pub fn TextNode.new_generated(document &dom.Document, source_text string) &TextNode {
	return &TextNode{
		Node: Node{
			document_: document
			is_text_node_: true
			is_generated_text_node_: true
		}
		source_text_: source_text
		retains_empty_generated_fragment_: source_text.len == 0
	}
}

// Layout::TextNode::text_for_rendering().
pub fn (n &TextNode) text_for_rendering() string {
	mut mutable_node := unsafe { &TextNode(n) }
	if !mutable_node.text_for_rendering_valid_ {
		mutable_node.compute_text_for_rendering()
	}
	return mutable_node.text_for_rendering_
}

pub fn (mut n TextNode) invalidate_text_for_rendering() {
	n.text_for_rendering_valid_ = false
	n.text_for_rendering_ = ''
	n.rendered_text_is_ascii_ = false
	n.rendered_utf16_length_ = 0
	n.cached_inline_bidi_processing_ = none
	n.rendered_text_edits_.clear()
	n.cached_inline_chunks_ = none
	n.cached_font_environment_generation_ = 0
	n.cached_inline_font_owner_ = none
	n.cached_inline_font_style_ = unsafe { nil }
	n.cached_inline_font_style_revision_ = 0
	n.cached_utf16_code_units_ = none
	// Replace the header: existing iterators retain the previous immutable vector.
	n.cached_grapheme_boundaries_ = []int{}
	n.cached_intrinsic_text_shapes_.clear()
	n.line_segmenter_ = unsafe { nil }
}

fn (mut n TextNode) compute_text_for_rendering() {
	n.cached_inline_bidi_processing_ = none
	persistent := platform.enter_persistent_if(platform.transient_arena_entered())
	defer { platform.leave_persistent(persistent) }
	mut text := n.source_text_
	if dom_text := n.dom_node_ {
		if character_data := dom_text.as_character_data() {
			text = character_data.data()
		}
	}
	mut language := ''
	if dom_text := n.dom_node_ {
		if parent_element := dom_text.parent_or_shadow_host_element() {
			language = parent_element.lang() or { '' }
		}
	}
	transform := n.Node.computed_values().text_transform()
	password := if dom_text := n.dom_node_ {
		dom_text.is_text() && unsafe { &dom.Text(dom_text) }.is_password_input()
	} else {
		false
	}
	ascii_case := !password && language == '' && text.is_ascii()
		&& transform in [.uppercase, .lowercase]
	needs_source_units := password || transform == .math_auto
		|| (!ascii_case && transform in [.uppercase, .lowercase, .capitalize])
	source_units := if needs_source_units { utf16_code_units_for_line_box(text) } else { []u16{} }
	source_length := if needs_source_units { source_units.len } else { utf16_length_for_line_box(text) }
	n.rendered_source_length_ = n.source_range_length_ or { source_length }
	mut edits := []platform.TextMappingEdit{}
	if ascii_case {
		// text_transform.rs preserves the no-locale ASCII fast path.
		text = if transform == .uppercase { text.to_upper() } else { text.to_lower() }
	} else if !password && transform in [.uppercase, .lowercase, .capitalize] {
		mapping := match transform {
			.uppercase { platform.TextCaseTransform.uppercase }
			.lowercase { platform.TextCaseTransform.lowercase }
			else { platform.TextCaseTransform.titlecase }
		}

		mapped := platform.transform_text_case_with_edits(source_units, language, mapping)
		text = string_from_utf16_code_units_for_line_box(mapped.units)
		edits = mapped.edits.clone()
	} else {
		text = if password {
			'●'.repeat(text.runes().len)
		} else {
			apply_text_transform_for_text_node(text, transform, language)
		}
		// Rust text_transform.rs::map_code_points records every length change.
		if password || transform == .math_auto {
			mut source_offset := 0
			mut rendered_offset := 0
			for character in string_from_utf16_code_units_for_line_box(source_units).runes() {
				source_count := if u32(character) > 0xffff { 2 } else { 1 }
				mapped := if password {
					rune(0x25cf)
				} else {
					math_auto_italic_code_point(character)
				}
				rendered_count := if u32(mapped) > 0xffff { 2 } else { 1 }
				if source_count != rendered_count {
					edits << platform.TextMappingEdit
					{
						source_offset, source_count, rendered_offset, rendered_count
					}
				}
				source_offset += source_count
				rendered_offset += rendered_count
			}
		}
	}
	// Transform the complete source before slicing for contextual casing.
	if length := n.source_range_length_ {
		source_start := n.source_range_start_
		source_end := source_start + length
		rendered_start := platform.rendered_text_offset_for_source_offset(edits, 0, source_start,
			.start)
		rendered_end := platform.rendered_text_offset_for_source_offset(edits, 0, source_end, .end)
		text = utf16_substring_for_line_box(text, rendered_start, rendered_end - rendered_start)
		mut sliced_edits := []platform.TextMappingEdit{}
		for edit in edits {
			edit_source_end := edit.source_start + edit.source_length
			if edit_source_end <= source_start || edit.source_start >= source_end { continue
			 }
			sliced_source_start := if edit.source_start > source_start {
				edit.source_start
			} else {
				source_start
			}
			sliced_source_end := if edit_source_end < source_end {
				edit_source_end
			} else {
				source_end
			}
			sliced_rendered_start := if edit.rendered_start > rendered_start {
				edit.rendered_start
			} else {
				rendered_start
			}
			edit_rendered_end := edit.rendered_start + edit.rendered_length
			sliced_rendered_end := if edit_rendered_end < rendered_end {
				edit_rendered_end
			} else {
				rendered_end
			}
			if sliced_source_end - sliced_source_start != sliced_rendered_end - sliced_rendered_start {
				sliced_edits << platform.TextMappingEdit
				{
					sliced_source_start, sliced_source_end - sliced_source_start, sliced_rendered_start - rendered_start, sliced_rendered_end - sliced_rendered_start
				}
			}
		}
		edits = sliced_edits.clone()
	}
	n.rendered_text_edits_ = edits.clone()
	white_space_collapse := n.Node.computed_values().white_space_collapse()
	convert_tabs := white_space_collapse in [.collapse, .preserve_breaks, .preserve_spaces]
	convert_newlines := white_space_collapse in [.collapse, .preserve_spaces]
	if (convert_tabs && text.contains('\t')) || (convert_newlines && text.contains('\n')) {
		// Most text needs no whitespace replacement. When it does, the returned
		// string owns one exact buffer instead of a byte vector plus a copy.
		mut bytes := []u8{len:text.len + 1}
		for i, byte in text {
			if (convert_tabs && byte == `\t`) || (convert_newlines && byte == `\n`) {
				bytes[i] = ` `
			} else {
				bytes[i] = byte
			}
		}
		text = unsafe { (&u8(bytes.data)).vstring_with_len(text.len) }
	}
	n.text_for_rendering_ = text
	n.rendered_text_is_ascii_ = text.is_ascii()
	n.rendered_utf16_length_ = if n.rendered_text_is_ascii_ { text.len } else { utf16_length_for_line_box(text) }
	n.text_for_rendering_valid_ = true
}

// Caret projection maps many individual boundaries in the same rendered text.
// Keep its UTF-16 length with that text rather than decoding the complete node
// for each source/rendered offset. Invalidation refreshes both together.
fn (n &TextNode) rendered_utf16_length() int {
	if !n.text_for_rendering_valid_ {
		mut mutable_node := unsafe { &TextNode(n) }
		mutable_node.compute_text_for_rendering()
	}
	return n.rendered_utf16_length_
}

pub fn (n &TextNode) source_offset_for_rendered_text_offset(offset int, boundary platform.TextMappingBoundary) int {
	length := n.rendered_utf16_length()
	clamped := if offset < 0 {
		0
	} else if offset > length {
		length
	} else {
		offset
	}
	return platform.source_offset_for_rendered_text_offset(n.rendered_text_edits_,
		n.source_range_start_, clamped, boundary)
}

pub fn (n &TextNode) rendered_text_offset_for_source_offset(offset int, boundary platform.TextMappingBoundary) int {
	length := n.rendered_utf16_length()
	source_end := n.source_range_start_ + n.rendered_source_length_
	clamped := if offset < n.source_range_start_ {
		n.source_range_start_
	} else if offset > source_end {
		source_end
	} else {
		offset
	}
	mapped := platform.rendered_text_offset_for_source_offset(n.rendered_text_edits_,
		n.source_range_start_, clamped, boundary)
	return if mapped > length { length } else { mapped }
}
pub fn (n &Node) is_text_node() bool {
	return n.is_text_node_
}

pub fn (n &Node) is_generated_text_node() bool {
	return n.is_generated_text_node_
}

pub fn (n &Node) as_text_node() ?&TextNode {
	if !n.is_text_node_ {
		return none
	}
	return unsafe { &TextNode(n) }
}

fn apply_text_transform_for_text_node(text string, transform css.TextTransform, language string) string {
	return match transform {
		.none_, .full_size_kana { text }
		.uppercase { platform.transform_text_case(text, language, .uppercase) }
		.lowercase { platform.transform_text_case(text, language, .lowercase) }
		.capitalize { platform.transform_text_case(text, language, .titlecase) }
		.full_width { text_to_full_width(text) }
		.math_auto { apply_math_auto_text_transform(text) }
	}
}

fn text_to_full_width(text string) string {
	mut result := []rune{}
	for character in text.runes() {
		if character == ` ` {
			result << rune(0x3000)
		} else if character >= rune(0x21) && character <= rune(0x7e) {
			result << rune(int(character) + 0xfee0)
		} else {
			result << character
		}
	}
	return result.string()
}

fn apply_math_auto_text_transform(text string) string {
	mut result := []rune{}
	for character in text.runes() {
		result << math_auto_italic_code_point(character)
	}
	return result.string()
}

fn math_auto_italic_code_point(character rune) rune {
	// Mathematical italic Latin letters are contiguous except lowercase h.
	if character >= `A` && character <= `Z` {
		return rune(0x1d434 + int(character - `A`))
	}
	if character >= `a` && character <= `z` {
		if character == `h` {
			return rune(0x210e)
		}
		return rune(0x1d44e + int(character - `a`))
	}
	// Mathematical italic Greek capitals are contiguous through rho. The
	// mathematical theta symbol occupies the code point between rho and sigma.
	if character >= rune(0x0391) && character <= rune(0x03a1) {
		return rune(0x1d6e2 + int(character - rune(0x0391)))
	}
	if character >= rune(0x03a3) && character <= rune(0x03a9) {
		return rune(0x1d6f4 + int(character - rune(0x03a3)))
	}
	// Greek lowercase letters, including final sigma, are contiguous in both
	// Unicode ranges.
	if character >= rune(0x03b1) && character <= rune(0x03c9) {
		return rune(0x1d6fc + int(character - rune(0x03b1)))
	}
	return match character {
		rune(0x0131) { rune(0x1d6a4) }
		rune(0x0237) { rune(0x1d6a5) }
		rune(0x03f4) { rune(0x1d6f3) }
		rune(0x2207) { rune(0x1d6fb) }
		rune(0x2202) { rune(0x1d715) }
		rune(0x03f5) { rune(0x1d716) }
		rune(0x03d1) { rune(0x1d717) }
		rune(0x03f0) { rune(0x1d718) }
		rune(0x03d5) { rune(0x1d719) }
		rune(0x03f1) { rune(0x1d71a) }
		rune(0x03d6) { rune(0x1d71b) }
		else { character }
	}
}
