// Copyright (c) 2018-2026, Ladybird contributors
//
// SPDX-License-Identifier: BSD-2-Clause
//
// Translated from Libraries/LibWeb/Layout/*.
// This module is an incremental V port. Functions whose dependencies have not
// been ported yet keep their source signature and comments and return neutral
// stub values so the rest of libweb_v can compile against Layout.

module layout

// ---- TreeBuilder.h (19 translated function stubs) ----

// Translated from Libraries/LibWeb/Layout/TreeBuilder.h:16
// Original signature: TreeBuilder::TreeBuilder();
pub fn tree_builder_h_16_tree_builder_tree_builder() LayoutStub {
	return layout_stub('TreeBuilder.h:16 TreeBuilder::TreeBuilder')
}

// Translated from Libraries/LibWeb/Layout/TreeBuilder.h:18
// Original signature: TreeBuilder::GC::Ptr<Layout::Node> build(DOM::Node&);
pub fn tree_builder_h_18_build() LayoutStub {
	return layout_stub('TreeBuilder.h:18 build')
}

// Translated from Libraries/LibWeb/Layout/TreeBuilder.h:28
// Original signature: TreeBuilder::i32 calculate_list_item_index(DOM::Node&);
pub fn tree_builder_h_28_calculate_list_item_index() LayoutStub {
	return layout_stub('TreeBuilder.h:28 calculate_list_item_index')
}

// Translated from Libraries/LibWeb/Layout/TreeBuilder.h:30
// Original signature: TreeBuilder::void update_layout_tree_before_children(DOM::Node&, GC::Ref<Layout::Node>, Context&, bool element_has_content_visibility_hidden);
pub fn tree_builder_h_30_update_layout_tree_before_children() LayoutStub {
	return layout_stub('TreeBuilder.h:30 update_layout_tree_before_children')
}

// Translated from Libraries/LibWeb/Layout/TreeBuilder.h:31
// Original signature: TreeBuilder::void update_layout_tree_after_children(DOM::Node&, GC::Ref<Layout::Node>, Context&, bool element_has_content_visibility_hidden);
pub fn tree_builder_h_31_update_layout_tree_after_children() LayoutStub {
	return layout_stub('TreeBuilder.h:31 update_layout_tree_after_children')
}

// Translated from Libraries/LibWeb/Layout/TreeBuilder.h:32
// Original signature: TreeBuilder::void wrap_in_button_layout_tree_if_needed(DOM::Node&, GC::Ref<Layout::Node>);
pub fn tree_builder_h_32_wrap_in_button_layout_tree_if_needed() LayoutStub {
	return layout_stub('TreeBuilder.h:32 wrap_in_button_layout_tree_if_needed')
}

// Translated from Libraries/LibWeb/Layout/TreeBuilder.h:37
// Original signature: TreeBuilder::void update_layout_tree(DOM::Node&, Context&, MustCreateSubtree);
pub fn tree_builder_h_37_update_layout_tree() LayoutStub {
	return layout_stub('TreeBuilder.h:37 update_layout_tree')
}

// Translated from Libraries/LibWeb/Layout/TreeBuilder.h:39
// Original signature: TreeBuilder::void push_parent(Layout::NodeWithStyle& node)
pub fn tree_builder_h_39_push_parent() LayoutStub {
	return layout_stub('TreeBuilder.h:39 push_parent')
}

// Translated from Libraries/LibWeb/Layout/TreeBuilder.h:40
// Original signature: TreeBuilder::void pop_parent()
pub fn tree_builder_h_40_pop_parent() LayoutStub {
	return layout_stub('TreeBuilder.h:40 pop_parent')
}

// Translated from Libraries/LibWeb/Layout/TreeBuilder.h:43
// Original signature: TreeBuilder::void for_each_in_tree_with_internal_display(NodeWithStyle& root, Callback);
pub fn tree_builder_h_43_for_each_in_tree_with_internal_display() LayoutStub {
	return layout_stub('TreeBuilder.h:43 for_each_in_tree_with_internal_display')
}

// Translated from Libraries/LibWeb/Layout/TreeBuilder.h:46
// Original signature: TreeBuilder::void for_each_in_tree_with_inside_display(NodeWithStyle& root, Callback);
pub fn tree_builder_h_46_for_each_in_tree_with_inside_display() LayoutStub {
	return layout_stub('TreeBuilder.h:46 for_each_in_tree_with_inside_display')
}

// Translated from Libraries/LibWeb/Layout/TreeBuilder.h:48
// Original signature: TreeBuilder::void fixup_tables(NodeWithStyle& root);
pub fn tree_builder_h_48_fixup_tables() LayoutStub {
	return layout_stub('TreeBuilder.h:48 fixup_tables')
}

// Translated from Libraries/LibWeb/Layout/TreeBuilder.h:49
// Original signature: TreeBuilder::void remove_irrelevant_boxes(NodeWithStyle& root);
pub fn tree_builder_h_49_remove_irrelevant_boxes() LayoutStub {
	return layout_stub('TreeBuilder.h:49 remove_irrelevant_boxes')
}

// Translated from Libraries/LibWeb/Layout/TreeBuilder.h:50
// Original signature: TreeBuilder::void generate_missing_child_wrappers(NodeWithStyle& root);
pub fn tree_builder_h_50_generate_missing_child_wrappers() LayoutStub {
	return layout_stub('TreeBuilder.h:50 generate_missing_child_wrappers')
}

// Translated from Libraries/LibWeb/Layout/TreeBuilder.h:51
// Original signature: TreeBuilder::Vector<GC::Root<Box>> generate_missing_parents(NodeWithStyle& root);
pub fn tree_builder_h_51_generate_missing_parents() LayoutStub {
	return layout_stub('TreeBuilder.h:51 generate_missing_parents')
}

// Translated from Libraries/LibWeb/Layout/TreeBuilder.h:52
// Original signature: TreeBuilder::void missing_cells_fixup(Vector<GC::Root<Box>> const&);
pub fn tree_builder_h_52_missing_cells_fixup() LayoutStub {
	return layout_stub('TreeBuilder.h:52 missing_cells_fixup')
}

// Translated from Libraries/LibWeb/Layout/TreeBuilder.h:58
// Original signature: TreeBuilder::void insert_node_into_inline_or_block_ancestor(Layout::Node&, CSS::Display, AppendOrPrepend);
pub fn tree_builder_h_58_insert_node_into_inline_or_block_ancestor() LayoutStub {
	return layout_stub('TreeBuilder.h:58 insert_node_into_inline_or_block_ancestor')
}

// Translated from Libraries/LibWeb/Layout/TreeBuilder.h:59
// Original signature: TreeBuilder::GC::Ptr<NodeWithStyle> create_pseudo_element_if_needed(DOM::Element&, CSS::PseudoElement, Optional<AppendOrPrepend>);
pub fn tree_builder_h_59_create_pseudo_element_if_needed() LayoutStub {
	return layout_stub('TreeBuilder.h:59 create_pseudo_element_if_needed')
}

// Translated from Libraries/LibWeb/Layout/TreeBuilder.h:60
// Original signature: TreeBuilder::void restructure_block_node_in_inline_parent(NodeWithStyleAndBoxModelMetrics&);
pub fn tree_builder_h_60_restructure_block_node_in_inline_parent() LayoutStub {
	return layout_stub('TreeBuilder.h:60 restructure_block_node_in_inline_parent')
}

// ---- TreeBuilder.cpp (44 translated function stubs) ----

// Translated from Libraries/LibWeb/Layout/TreeBuilder.cpp:45
// Original signature: TreeBuilder::TreeBuilder() = default;
pub fn tree_builder_cpp_45_tree_builder_tree_builder() LayoutStub {
	return layout_stub('TreeBuilder.cpp:45 TreeBuilder::TreeBuilder')
}

// Translated from Libraries/LibWeb/Layout/TreeBuilder.cpp:47
// Original signature: static bool has_inline_or_in_flow_block_children(Layout::Node const& layout_node)
pub fn tree_builder_cpp_47_has_inline_or_in_flow_block_children() LayoutStub {
	return layout_stub('TreeBuilder.cpp:47 has_inline_or_in_flow_block_children')
}

// Translated from Libraries/LibWeb/Layout/TreeBuilder.cpp:56
// Original signature: static bool has_in_flow_block_children(Layout::Node const& layout_node)
pub fn tree_builder_cpp_56_has_in_flow_block_children() LayoutStub {
	return layout_stub('TreeBuilder.cpp:56 has_in_flow_block_children')
}

// Translated from Libraries/LibWeb/Layout/TreeBuilder.cpp:72
// Original signature: static Layout::Node& insertion_parent_for_inline_node(Layout::NodeWithStyle& layout_parent)
// The insertion_parent_for_*() functions maintain the invariant that the in-flow children of
// block-level boxes must be either all block-level or all inline-level.
// Parent has block-level children, insert into an anonymous wrapper block (and create it first if needed)
pub fn tree_builder_cpp_72_insertion_parent_for_inline_node() LayoutStub {
	return layout_stub('TreeBuilder.cpp:72 insertion_parent_for_inline_node')
}

// Translated from Libraries/LibWeb/Layout/TreeBuilder.cpp:103
// Original signature: static Layout::Node& insertion_parent_for_block_node(Layout::NodeWithStyle& layout_parent, Layout::Node& layout_node)
// Inline is fine for in-flow block children; we'll maintain the (non-)inline invariant after insertion.
// Make sure we're not inserting into an inline node, since those do not support block nodes.
// If the parent block has no children, insert this block into parent.
// If the block is out-of-flow and is not a pseudo element,
// And the parent's last child is an anonymous block, join that anonymous block.
// Otherwise, insert this block into parent.
// If the parent block has block-level children, insert this block into parent.
// Parent block has inline-level children (our siblings); wrap these siblings into an anonymous wrapper block.
// Then it's safe to insert this block into parent.
pub fn tree_builder_cpp_103_insertion_parent_for_block_node() LayoutStub {
	return layout_stub('TreeBuilder.cpp:103 insertion_parent_for_block_node')
}

// Translated from Libraries/LibWeb/Layout/TreeBuilder.cpp:155
// Original signature: void TreeBuilder::insert_node_into_inline_or_block_ancestor(Layout::Node& node, CSS::Display display, AppendOrPrepend mode)
// Find the nearest ancestor that can host the node.
// Out-of-flow nodes cannot be hosted in inline flow nodes.
// After inserting an inline-level box into a parent, mark the parent as having inline children.
// After inserting an in-flow block-level box into a parent, mark the parent as having non-inline children.
pub fn tree_builder_cpp_155_tree_builder_insert_node_into_inline_or_block_ancestor() LayoutStub {
	return layout_stub('TreeBuilder.cpp:155 TreeBuilder::insert_node_into_inline_or_block_ancestor')
}

// Translated from Libraries/LibWeb/Layout/TreeBuilder.cpp:199
// Original signature: GC_CELL(GeneratedContentImageProvider, GC::Cell);
pub fn tree_builder_cpp_199_gc_cell() LayoutStub {
	return layout_stub('TreeBuilder.cpp:199 GC_CELL')
}

// Translated from Libraries/LibWeb/Layout/TreeBuilder.cpp:209
// Original signature: Base::finalize();
pub fn tree_builder_cpp_209_base_finalize() LayoutStub {
	return layout_stub('TreeBuilder.cpp:209 Base::finalize')
}

// Translated from Libraries/LibWeb/Layout/TreeBuilder.cpp:219
// Original signature: virtual RefPtr<Gfx::ImmutableBitmap> current_image_bitmap_sized(Gfx::IntSize size) const
pub fn tree_builder_cpp_219_current_image_bitmap_sized() LayoutStub {
	return layout_stub('TreeBuilder.cpp:219 current_image_bitmap_sized')
}

// Translated from Libraries/LibWeb/Layout/TreeBuilder.cpp:227
// Original signature: virtual GC::Ptr<DOM::Element const> to_html_element() const
pub fn tree_builder_cpp_227_to_html_element() LayoutStub {
	return layout_stub('TreeBuilder.cpp:227 to_html_element')
}

// Translated from Libraries/LibWeb/Layout/TreeBuilder.cpp:229
// Original signature: static GC::Ref<GeneratedContentImageProvider> create(GC::Heap& heap, NonnullRefPtr<CSS::ImageStyleValue> image)
pub fn tree_builder_cpp_229_create() LayoutStub {
	return layout_stub('TreeBuilder.cpp:229 create')
}

// Translated from Libraries/LibWeb/Layout/TreeBuilder.cpp:234
// Original signature: void set_layout_node(GC::Ref<Layout::Node> layout_node)
pub fn tree_builder_cpp_234_set_layout_node() LayoutStub {
	return layout_stub('TreeBuilder.cpp:234 set_layout_node')
}

// Translated from Libraries/LibWeb/Layout/TreeBuilder.cpp:240
// Original signature: virtual GC::Ptr<HTML::DecodedImageData> decoded_image_data() const
pub fn tree_builder_cpp_240_decoded_image_data() LayoutStub {
	return layout_stub('TreeBuilder.cpp:240 decoded_image_data')
}

// Translated from Libraries/LibWeb/Layout/TreeBuilder.cpp:246
// Original signature: GeneratedContentImageProvider(NonnullRefPtr<CSS::ImageStyleValue> image) : Client(image) , m_image(move(image))
pub fn tree_builder_cpp_246_generated_content_image_provider() LayoutStub {
	return layout_stub('TreeBuilder.cpp:246 GeneratedContentImageProvider')
}

// Translated from Libraries/LibWeb/Layout/TreeBuilder.cpp:254
// Original signature: Base::visit_edges(visitor);
pub fn tree_builder_cpp_254_base_visit_edges() LayoutStub {
	return layout_stub('TreeBuilder.cpp:254 Base::visit_edges')
}

// Translated from Libraries/LibWeb/Layout/TreeBuilder.cpp:261
// Original signature: ImageProvider::image_provider_visit_edges(visitor);
pub fn tree_builder_cpp_261_image_provider_image_provider_visit_edges() LayoutStub {
	return layout_stub('TreeBuilder.cpp:261 ImageProvider::image_provider_visit_edges')
}

// Translated from Libraries/LibWeb/Layout/TreeBuilder.cpp:265
// Original signature: virtual void image_style_value_did_update(CSS::ImageStyleValue&)
pub fn tree_builder_cpp_265_image_style_value_did_update() LayoutStub {
	return layout_stub('TreeBuilder.cpp:265 image_style_value_did_update')
}

// Translated from Libraries/LibWeb/Layout/TreeBuilder.cpp:276
// Original signature: GC::Ptr<NodeWithStyle> TreeBuilder::create_pseudo_element_if_needed(DOM::Element& element, CSS::PseudoElement pseudo_element, Optional<AppendOrPrepend> insertion_mode)
// ::before and ::after only exist if they have content. `content: normal` computes to `none` for them.
// We also don't create them if they are `display: none`.
// For ::marker with content or display 'none' -- do nothing.
// For ::marker with content 'normal', create the marker pseudo-element from a ListItemMarkerBox
// FIXME: This + ListItemBox + ListItemMarkerBox will disappear once ::marker pseudo-elements with 'normal'
// content
// are rendered using the special list-item counter.
// See: https://github.com/LadybirdBrowser/ladybird/issues/4782
// NB: Called during layout tree construction.
// https://www.w3.org/TR/css-lists-3/#content-property
// "::marker does not generate a box" when list-style-type is 'none' and there's no marker image. Custom
// ::marker content is already excluded by the outer condition checking for Type::Normal.
// FIXME: This code actually computes style for element::marker, and shouldn't for element::pseudo::marker
// FIXME: Support counters on element::pseudo::marker
// Now that we have counters, we can compute the content for real. Which is silly.
// FIXME: Handle images, and multiple values
pub fn tree_builder_cpp_276_tree_builder_create_pseudo_element_if_needed() LayoutStub {
	return layout_stub('TreeBuilder.cpp:276 TreeBuilder::create_pseudo_element_if_needed')
}

// Translated from Libraries/LibWeb/Layout/TreeBuilder.cpp:431
// Original signature: void TreeBuilder::restructure_block_node_in_inline_parent(NodeWithStyleAndBoxModelMetrics& node)
// Block nodes inside inline nodes are allowed, but to maintain the invariant that either all layout children are
// inline or non-inline, we need to rearrange the tree a bit. All inline ancestors up to the node we've inserted
// are
// wrapped in an anonymous block, which is inserted into the nearest non-inline ancestor. We then recreate the
// inline
// ancestors in another anonymous block inserted after the node so we can continue adding children.
// Effectively, we try to turn this:
// InlineNode 1
// TextNode 1
// InlineNode N
// TextNode N
// BlockContainer (node)
// Into this:
// BlockContainer (anonymous "before")
// BlockContainer (anonymous "middle") continuation
// BlockContainer (anonymous "after")
// InlineNode 1 continuation
// To be able to reconstruct their relation after restructuring, layout nodes keep track of their continuation.
// The
// top-most inline node of the "after" wrapper points to the "middle" wrapper, which points to the top-most
// inline node
// of the "before" wrapper. All other inline nodes in the "after" wrapper point to their counterparts in the
// "before"
// wrapper, to make it easier to create the right paintables since a DOM::Node only has a single Layout::Node.
// Appending then continues in the "after" tree. If a new block node is then inserted, we can reuse the "middle"
// wrapper
// if no inline siblings exist for node or its ancestors, and leave the existing "after" wrapper alone.
// Otherwise, we
// create new wrappers and extend the continuation chain.
// Inspired by: https://webkit.org/blog/115/webcore-rendering-ii-blocks-and-inlines/
// Mark parent as inline again
// Find nearest ancestor that establishes a BFC (block container) and is not display: contents or anonymous.
// Find the topmost inline ancestor.
// We need to host the topmost inline ancestor and its previous siblings in an anonymous "before" wrapper. If an
// inline wrapper does not already exist, we create a new one and add it to the nearest block ancestor.
// If we are part of an existing continuation and all inclusive ancestors have no previous siblings, we can reuse
// the existing middle wrapper. Otherwiser, we create a new middle wrapper to contain the block node and add it
// to
// the nearest block ancestor.
// Move the block node to the middle wrapper.
// If we need a new continuation, recreate inline ancestors in another anonymous block so we can continue adding
// new
// nodes. We don't need to do this if we are within an existing continuation and there were no previous siblings
// in
// any inclusive ancestor of node in the after wrapper.
// The topmost inline ancestor points to the middle wrapper, which in turns points to the original node.
// We need all other inline nodes to point to their original node so we can walk the continuation chain
// in LayoutState and create the right paintables.
// Replace the node in the ancestor stack with the new node.
// Stop recreating nodes when we've reached node's parent.
pub fn tree_builder_cpp_431_tree_builder_restructure_block_node_in_inline_parent() LayoutStub {
	return layout_stub('TreeBuilder.cpp:431 TreeBuilder::restructure_block_node_in_inline_parent')
}

// Translated from Libraries/LibWeb/Layout/TreeBuilder.cpp:545
// Original signature: static bool is_ignorable_whitespace(Layout::Node const& node)
pub fn tree_builder_cpp_545_is_ignorable_whitespace() LayoutStub {
	return layout_stub('TreeBuilder.cpp:545 is_ignorable_whitespace')
}

// Translated from Libraries/LibWeb/Layout/TreeBuilder.cpp:571
// Original signature: void TreeBuilder::update_layout_tree(DOM::Node& dom_node, TreeBuilder::Context& context, MustCreateSubtree must_create_subtree)
// NB: Called during layout tree construction.
// If we didn't create a layout node for this DOM node,
// go through the DOM tree and remove any old layout & paint nodes since they are now all stale.
// SVGPatternBox, SVGMaskBox, and SVGClipBox are created on behalf of a referencing
// element and attached to that element's layout subtree. Skip them so they survive cleanup of their
// DOM ancestor.
// ::backdrop is a sibling of the element, not a child, so unlike other pseudo-elements, it's not
// automatically discarded when element's layout is recomputed. We must remove it manually.
// TODO: Implement changing element contents with the `content` property.
// Only layout direct uses of SVG masks/clipPaths.
// Decide whether to replace an existing node (partial tree update) or insert a new one appropriately.
// Each element rendered in the top layer has a ::backdrop pseudo-element, for which it is the originating
// element.
// If we're inserting a new element, we can append the ::backdrop node now, before layout_node is appended.
// Otherwise, we need to insert the ::backdrop before old_layout_node so it's behind the layout_node.
// Resolve counters now that we exist in the layout tree.
// For replaced elements with shadow DOM children, wrap the children in an
// anonymous BlockContainer so that a BFC handles their layout.
// This is the same as as<DOM::ParentNode>(dom_node).for_each_child
// Elements in the top layer do not lay out normally based on their position in the document; instead they
// generate boxes as if they were siblings of the root element.
// If we completely finished inserting a block level element into an inline parent, we need to fix up the tree so
// that we can maintain the invariant that all children are either inline or non-inline. We can't do this
// earlier,
// because the restructuring adds new children after this node that become part of the ancestor stack.
// https://www.w3.org/TR/css-contain-2/#containment-style
// Giving an element style containment has the following effects:
// 2. The effects of the 'content' property's 'open-quote', 'close-quote', 'no-open-quote' and 'no-close-quote'
// must
// be scoped to the element's sub-tree.
pub fn tree_builder_cpp_571_tree_builder_update_layout_tree() LayoutStub {
	return layout_stub('TreeBuilder.cpp:571 TreeBuilder::update_layout_tree')
}

// Translated from Libraries/LibWeb/Layout/TreeBuilder.cpp:823
// Original signature: void TreeBuilder::wrap_in_button_layout_tree_if_needed(DOM::Node& dom_node, GC::Ref<Layout::Node> layout_node)
// https://html.spec.whatwg.org/multipage/rendering.html#button-layout
// If the element is an input element, or if it is a button element and its computed value for 'display' is not
// 'inline-grid', 'grid', 'inline-flex', or 'flex', then the element's box has a child anonymous button content
// box
// with the following behaviors:
// If the box does not overflow in the vertical axis, then it is centered vertically.
// FIXME: Only apply alignment when box overflows
pub fn tree_builder_cpp_823_tree_builder_wrap_in_button_layout_tree_if_needed() LayoutStub {
	return layout_stub('TreeBuilder.cpp:823 TreeBuilder::wrap_in_button_layout_tree_if_needed')
}

// Translated from Libraries/LibWeb/Layout/TreeBuilder.cpp:866
// Original signature: void TreeBuilder::update_layout_tree_before_children(DOM::Node& dom_node, GC::Ref<Layout::Node> layout_node, TreeBuilder::Context&, bool element_has_content_visibility_hidden)
// Add node for the ::before pseudo-element.
pub fn tree_builder_cpp_866_tree_builder_update_layout_tree_before_children() LayoutStub {
	return layout_stub('TreeBuilder.cpp:866 TreeBuilder::update_layout_tree_before_children')
}

// Translated from Libraries/LibWeb/Layout/TreeBuilder.cpp:878
// Original signature: void TreeBuilder::update_layout_tree_after_children(DOM::Node& dom_node, GC::Ref<Layout::Node> layout_node, TreeBuilder::Context& context, bool element_has_content_visibility_hidden)
// Create the layout tree for the SVG mask/clip paths as a child of the masked element.
// Note: This will create a new subtree for each use of the mask (so there's  not a 1-to-1 mapping
// from DOM node to mask layout node). Each use of a mask may be laid out differently so this
// duplication is necessary.
// Check for reference cycle
// FIXME: Somehow either remove ancestor from the layout tree or mark it as invalid.
// Add nodes for the ::after pseudo-element.
// https://drafts.csswg.org/css-lists-3/#marker-pseudo
// The marker box is generated by the ::marker pseudo-element of a list item as the list item's first child,
// before the ::before pseudo-element (if it exists on the element). It is filled with content as defined
// in ??3.2 Generating Marker Contents.
// NOTE: This happens in update_layout_tree_after_children (and not in ..._before_...), since potential
// block container wrapper children are created after update_layout_tree_before_children.
// https://html.spec.whatwg.org/multipage/rendering.html#the-fieldset-and-legend-elements
// The anonymous fieldset content box is expected to appear after the rendered legend and is expected to contain
// the
// content (including the '::before' and '::after' pseudo-elements) of the fieldset element except for the
// rendered
// legend, if there is one.
// The following properties are expected to inherit from the fieldset element:
// align-content, align-items, border-radius, column-count, column-fill, column-gap, column-rule,
// column-width, flex-direction, flex-wrap, grid (grid-auto-columns, grid-auto-flow, grid-auto-rows,
// grid-column-gap, grid-row-gap, grid-template-areas, grid-template-columns, grid-template-rows),
// justify-content, justify-items, overflow, padding, text-overflow, unicode-bidi
// FIXME: Transfer all of these properties, not just overflow.
pub fn tree_builder_cpp_878_tree_builder_update_layout_tree_after_children() LayoutStub {
	return layout_stub('TreeBuilder.cpp:878 TreeBuilder::update_layout_tree_after_children')
}

// Translated from Libraries/LibWeb/Layout/TreeBuilder.cpp:988
// Original signature: GC::Ptr<Layout::Node> TreeBuilder::build(DOM::Node& dom_node)
// NB: Called during layout tree construction.
pub fn tree_builder_cpp_988_tree_builder_build() LayoutStub {
	return layout_stub('TreeBuilder.cpp:988 TreeBuilder::build')
}

// Translated from Libraries/LibWeb/Layout/TreeBuilder.cpp:1006
// Original signature: void TreeBuilder::for_each_in_tree_with_internal_display(NodeWithStyle& root, Callback callback)
pub fn tree_builder_cpp_1006_tree_builder_for_each_in_tree_with_internal_display() LayoutStub {
	return layout_stub('TreeBuilder.cpp:1006 TreeBuilder::for_each_in_tree_with_internal_display')
}

// Translated from Libraries/LibWeb/Layout/TreeBuilder.cpp:1017
// Original signature: void TreeBuilder::for_each_in_tree_with_inside_display(NodeWithStyle& root, Callback callback)
pub fn tree_builder_cpp_1017_tree_builder_for_each_in_tree_with_inside_display() LayoutStub {
	return layout_stub('TreeBuilder.cpp:1017 TreeBuilder::for_each_in_tree_with_inside_display')
}

// Translated from Libraries/LibWeb/Layout/TreeBuilder.cpp:1028
// Original signature: void TreeBuilder::fixup_tables(NodeWithStyle& root)
// https://drafts.csswg.org/css-tables-3/#fixup-algorithm
pub fn tree_builder_cpp_1028_tree_builder_fixup_tables() LayoutStub {
	return layout_stub('TreeBuilder.cpp:1028 TreeBuilder::fixup_tables')
}

// Translated from Libraries/LibWeb/Layout/TreeBuilder.cpp:1038
// Original signature: void TreeBuilder::remove_irrelevant_boxes(NodeWithStyle& root)
// https://drafts.csswg.org/css-tables-3/#fixup-algorithm
// 1. Remove irrelevant boxes:
// The following boxes are discarded as if they were display:none:
// 1. Children of a table-column.
// 2. Children of a table-column-group which are not a table-column.
// FIXME:
// 3. Anonymous inline boxes which contain only white space and are between two immediate siblings each of which
// is a table-non-root box.
// 4. Anonymous inline boxes which meet all of the following criteria:
// - they contain only white space
// - they are the first and/or last child of a tabular container
// - whose immediate sibling, if any, is a table-non-root box
pub fn tree_builder_cpp_1038_tree_builder_remove_irrelevant_boxes() LayoutStub {
	return layout_stub('TreeBuilder.cpp:1038 TreeBuilder::remove_irrelevant_boxes')
}

// Translated from Libraries/LibWeb/Layout/TreeBuilder.cpp:1072
// Original signature: static bool is_table_track(CSS::Display display)
pub fn tree_builder_cpp_1072_is_table_track() LayoutStub {
	return layout_stub('TreeBuilder.cpp:1072 is_table_track')
}

// Translated from Libraries/LibWeb/Layout/TreeBuilder.cpp:1077
// Original signature: static bool is_table_track_group(CSS::Display display)
// Unless explicitly mentioned otherwise, mentions of table-row-groups in this spec also encompass the
// specialized
// table-header-groups and table-footer-groups.
pub fn tree_builder_cpp_1077_is_table_track_group() LayoutStub {
	return layout_stub('TreeBuilder.cpp:1077 is_table_track_group')
}

// Translated from Libraries/LibWeb/Layout/TreeBuilder.cpp:1087
// Original signature: static bool is_proper_table_child(Node const& node)
pub fn tree_builder_cpp_1087_is_proper_table_child() LayoutStub {
	return layout_stub('TreeBuilder.cpp:1087 is_proper_table_child')
}

// Translated from Libraries/LibWeb/Layout/TreeBuilder.cpp:1093
// Original signature: static bool is_not_proper_table_child(Node const& node)
pub fn tree_builder_cpp_1093_is_not_proper_table_child() LayoutStub {
	return layout_stub('TreeBuilder.cpp:1093 is_not_proper_table_child')
}

// Translated from Libraries/LibWeb/Layout/TreeBuilder.cpp:1100
// Original signature: static bool is_not_table_row(Node const& node)
pub fn tree_builder_cpp_1100_is_not_table_row() LayoutStub {
	return layout_stub('TreeBuilder.cpp:1100 is_not_table_row')
}

// Translated from Libraries/LibWeb/Layout/TreeBuilder.cpp:1107
// Original signature: static bool is_table_column(Node const& node)
pub fn tree_builder_cpp_1107_is_table_column() LayoutStub {
	return layout_stub('TreeBuilder.cpp:1107 is_table_column')
}

// Translated from Libraries/LibWeb/Layout/TreeBuilder.cpp:1112
// Original signature: static bool is_table_cell(Node const& node)
pub fn tree_builder_cpp_1112_is_table_cell() LayoutStub {
	return layout_stub('TreeBuilder.cpp:1112 is_table_cell')
}

// Translated from Libraries/LibWeb/Layout/TreeBuilder.cpp:1117
// Original signature: static bool is_not_table_cell(Node const& node)
pub fn tree_builder_cpp_1117_is_not_table_cell() LayoutStub {
	return layout_stub('TreeBuilder.cpp:1117 is_not_table_cell')
}

// Translated from Libraries/LibWeb/Layout/TreeBuilder.cpp:1124
// Original signature: static bool is_table_row_group_column_group_or_caption(Node const& node)
pub fn tree_builder_cpp_1124_is_table_row_group_column_group_or_caption() LayoutStub {
	return layout_stub('TreeBuilder.cpp:1124 is_table_row_group_column_group_or_caption')
}

// Translated from Libraries/LibWeb/Layout/TreeBuilder.cpp:1131
// Original signature: static void for_each_sequence_of_consecutive_children_matching(NodeWithStyle& parent, Matcher matcher, Callback callback)
pub fn tree_builder_cpp_1131_for_each_sequence_of_consecutive_children_matching() LayoutStub {
	return layout_stub('TreeBuilder.cpp:1131 for_each_sequence_of_consecutive_children_matching')
}

// Translated from Libraries/LibWeb/Layout/TreeBuilder.cpp:1159
// Original signature: static void wrap_in_anonymous(Vector<GC::Root<Node>>& sequence, Node* nearest_sibling, CSS::Display display)
pub fn tree_builder_cpp_1159_wrap_in_anonymous() LayoutStub {
	return layout_stub('TreeBuilder.cpp:1159 wrap_in_anonymous')
}

// Translated from Libraries/LibWeb/Layout/TreeBuilder.cpp:1179
// Original signature: void TreeBuilder::generate_missing_child_wrappers(NodeWithStyle& root)
// https://drafts.csswg.org/css-tables-3/#fixup-algorithm
// 2. Generate missing child wrappers:
// 1. An anonymous table-row box must be generated around each sequence of consecutive children of a table-root
// box
// which are not proper table child boxes.
// 2. An anonymous table-row box must be generated around each sequence of consecutive children of a table-row-
// group
// box which are not table-row boxes.
// Unless explicitly mentioned otherwise, mentions of table-row-groups in this spec also encompass the
// specialized
// table-header-groups and table-footer-groups.
// 3. An anonymous table-cell box must be generated around each sequence of consecutive children of a table-row
// box
// which are not table-cell boxes.
pub fn tree_builder_cpp_1179_tree_builder_generate_missing_child_wrappers() LayoutStub {
	return layout_stub('TreeBuilder.cpp:1179 TreeBuilder::generate_missing_child_wrappers')
}

// Translated from Libraries/LibWeb/Layout/TreeBuilder.cpp:1220
// Original signature: Vector<GC::Root<Box>> TreeBuilder::generate_missing_parents(NodeWithStyle& root)
// https://drafts.csswg.org/css-tables-3/#fixup-algorithm
// 3. Generate missing parents:
// 1. An anonymous table-row box must be generated around each sequence of consecutive table-cell boxes whose
// parent is not a table-row.
// 2. An anonymous table or inline-table box must be generated around each sequence of consecutive proper table
// child boxes which are misparented.
// If the box's parent is an inline, run-in, or ruby box (or any box that would perform inlinification of
// its children), then an inline-table box must be generated; otherwise it must be a table box.
// FIXME: run-in and ruby boxes
// A table-row is misparented if its parent is neither a table-row-group nor a table-root box.
// A table-column box is misparented if its parent is neither a table-column-group box nor a table-root box.
// A table-row-group, table-column-group, or table-caption box is misparented if its parent is not a table-root
// box.
// 3. An anonymous table-wrapper box must be generated around each table-root.
pub fn tree_builder_cpp_1220_tree_builder_generate_missing_parents() LayoutStub {
	return layout_stub('TreeBuilder.cpp:1220 TreeBuilder::generate_missing_parents')
}

// Translated from Libraries/LibWeb/Layout/TreeBuilder.cpp:1305
// Original signature: static void fixup_row(Box& row_box, TableGrid const& table_grid, size_t row_index)
// Ensure that the cell (with zero content height) will have the same height as the row by setting vertical-align
// to middle.
pub fn tree_builder_cpp_1305_fixup_row() LayoutStub {
	return layout_stub('TreeBuilder.cpp:1305 fixup_row')
}

// Translated from Libraries/LibWeb/Layout/TreeBuilder.cpp:1322
// Original signature: void TreeBuilder::missing_cells_fixup(Vector<GC::Root<Box>> const& table_root_boxes)
// https://drafts.csswg.org/css-tables-3/#missing-cells-fixup
// Once the amount of columns in a table is known, any table-row box must be modified such that it owns enough
// cells to fill all the columns of the table, when taking spans into account. New table-cell anonymous boxes
// must
// be appended to its rows content until this condition is met.
pub fn tree_builder_cpp_1322_tree_builder_missing_cells_fixup() LayoutStub {
	return layout_stub('TreeBuilder.cpp:1322 TreeBuilder::missing_cells_fixup')
}
