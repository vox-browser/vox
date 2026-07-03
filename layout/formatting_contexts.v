// Copyright (c) 2018-2026, Ladybird contributors
//
// SPDX-License-Identifier: BSD-2-Clause
//
// Translated from Libraries/LibWeb/Layout/*.
// This module is an incremental V port. Functions whose dependencies have not
// been ported yet keep their source signature and comments and return neutral
// stub values so the rest of libweb_v can compile against Layout.

module layout

// ---- FormattingContext.h (62 translated function stubs) ----

// Translated from Libraries/LibWeb/Layout/FormattingContext.h:64
// Original signature: FormattingContext::virtual ~FormattingContext();
pub fn formatting_context_h_64_destroy_formatting_context() LayoutStub {
	return layout_stub('FormattingContext.h:64 ~FormattingContext')
}

// Translated from Libraries/LibWeb/Layout/FormattingContext.h:103
// Original signature: FormattingContext::virtual void run(AvailableSpace const&) = 0;
pub fn formatting_context_h_103_run() LayoutStub {
	return layout_stub('FormattingContext.h:103 run')
}

// Translated from Libraries/LibWeb/Layout/FormattingContext.h:106
// Original signature: FormattingContext::virtual CSSPixels automatic_content_width() const = 0;
// These functions return the automatic content dimensions of the context's root box.
pub fn formatting_context_h_106_automatic_content_width() LayoutStub {
	return layout_stub('FormattingContext.h:106 automatic_content_width')
}

// Translated from Libraries/LibWeb/Layout/FormattingContext.h:107
// Original signature: FormattingContext::virtual CSSPixels automatic_content_height() const = 0;
pub fn formatting_context_h_107_automatic_content_height() LayoutStub {
	return layout_stub('FormattingContext.h:107 automatic_content_height')
}

// Translated from Libraries/LibWeb/Layout/FormattingContext.h:109
// Original signature: FormattingContext::Box const& context_box() const
pub fn formatting_context_h_109_context_box() LayoutStub {
	return layout_stub('FormattingContext.h:109 context_box')
}

// Translated from Libraries/LibWeb/Layout/FormattingContext.h:111
// Original signature: FormattingContext::FormattingContext* parent()
pub fn formatting_context_h_111_parent() LayoutStub {
	return layout_stub('FormattingContext.h:111 parent')
}

// Translated from Libraries/LibWeb/Layout/FormattingContext.h:112
// Original signature: FormattingContext::FormattingContext const* parent() const
pub fn formatting_context_h_112_parent() LayoutStub {
	return layout_stub('FormattingContext.h:112 parent')
}

// Translated from Libraries/LibWeb/Layout/FormattingContext.h:114
// Original signature: FormattingContext::Type type() const
pub fn formatting_context_h_114_type() LayoutStub {
	return layout_stub('FormattingContext.h:114 type')
}

// Translated from Libraries/LibWeb/Layout/FormattingContext.h:116
// Original signature: FormattingContext::virtual bool inhibits_floating() const
pub fn formatting_context_h_116_inhibits_floating() LayoutStub {
	return layout_stub('FormattingContext.h:116 inhibits_floating')
}

// Translated from Libraries/LibWeb/Layout/FormattingContext.h:118
// Original signature: FormattingContext::[[nodiscard]] static Optional<Type> formatting_context_type_created_by_box(Box const&);
pub fn formatting_context_h_118_formatting_context_type_created_by_box() LayoutStub {
	return layout_stub('FormattingContext.h:118 formatting_context_type_created_by_box')
}

// Translated from Libraries/LibWeb/Layout/FormattingContext.h:120
// Original signature: FormattingContext::static bool creates_block_formatting_context(Box const&);
pub fn formatting_context_h_120_creates_block_formatting_context() LayoutStub {
	return layout_stub('FormattingContext.h:120 creates_block_formatting_context')
}

// Translated from Libraries/LibWeb/Layout/FormattingContext.h:122
// Original signature: FormattingContext::CSSPixels compute_table_box_width_inside_table_wrapper(Box const&, AvailableSpace const&);
pub fn formatting_context_h_122_compute_table_box_width_inside_table_wrapper() LayoutStub {
	return layout_stub('FormattingContext.h:122 compute_table_box_width_inside_table_wrapper')
}

// Translated from Libraries/LibWeb/Layout/FormattingContext.h:123
// Original signature: FormattingContext::CSSPixels compute_table_box_height_inside_table_wrapper(Box const&, AvailableSpace const&);
pub fn formatting_context_h_123_compute_table_box_height_inside_table_wrapper() LayoutStub {
	return layout_stub('FormattingContext.h:123 compute_table_box_height_inside_table_wrapper')
}

// Translated from Libraries/LibWeb/Layout/FormattingContext.h:125
// Original signature: FormattingContext::CSSPixels compute_width_for_replaced_element(Box const&, AvailableSpace const&) const;
pub fn formatting_context_h_125_compute_width_for_replaced_element() LayoutStub {
	return layout_stub('FormattingContext.h:125 compute_width_for_replaced_element')
}

// Translated from Libraries/LibWeb/Layout/FormattingContext.h:126
// Original signature: FormattingContext::CSSPixels compute_height_for_replaced_element(Box const&, AvailableSpace const&) const;
pub fn formatting_context_h_126_compute_height_for_replaced_element() LayoutStub {
	return layout_stub('FormattingContext.h:126 compute_height_for_replaced_element')
}

// Translated from Libraries/LibWeb/Layout/FormattingContext.h:128
// Original signature: FormattingContext::OwnPtr<FormattingContext> create_independent_formatting_context_if_needed(LayoutState&, LayoutMode, Box const& child_box);
pub fn formatting_context_h_128_create_independent_formatting_context_if_needed() LayoutStub {
	return layout_stub('FormattingContext.h:128 create_independent_formatting_context_if_needed')
}

// Translated from Libraries/LibWeb/Layout/FormattingContext.h:129
// Original signature: FormattingContext::NonnullOwnPtr<FormattingContext> create_independent_formatting_context(LayoutState&, LayoutMode, Box const& child_box);
pub fn formatting_context_h_129_create_independent_formatting_context() LayoutStub {
	return layout_stub('FormattingContext.h:129 create_independent_formatting_context')
}

// Translated from Libraries/LibWeb/Layout/FormattingContext.h:131
// Original signature: FormattingContext::virtual void parent_context_did_dimension_child_root_box()
pub fn formatting_context_h_131_parent_context_did_dimension_child_root_box() LayoutStub {
	return layout_stub('FormattingContext.h:131 parent_context_did_dimension_child_root_box')
}

// Translated from Libraries/LibWeb/Layout/FormattingContext.h:133
// Original signature: FormattingContext::CSSPixels calculate_min_content_width(Layout::Box const&) const;
pub fn formatting_context_h_133_calculate_min_content_width() LayoutStub {
	return layout_stub('FormattingContext.h:133 calculate_min_content_width')
}

// Translated from Libraries/LibWeb/Layout/FormattingContext.h:134
// Original signature: FormattingContext::CSSPixels calculate_max_content_width(Layout::Box const&) const;
pub fn formatting_context_h_134_calculate_max_content_width() LayoutStub {
	return layout_stub('FormattingContext.h:134 calculate_max_content_width')
}

// Translated from Libraries/LibWeb/Layout/FormattingContext.h:135
// Original signature: FormattingContext::CSSPixels calculate_min_content_height(Layout::Box const&, CSSPixels width) const;
pub fn formatting_context_h_135_calculate_min_content_height() LayoutStub {
	return layout_stub('FormattingContext.h:135 calculate_min_content_height')
}

// Translated from Libraries/LibWeb/Layout/FormattingContext.h:136
// Original signature: FormattingContext::CSSPixels calculate_max_content_height(Layout::Box const&, CSSPixels width) const;
pub fn formatting_context_h_136_calculate_max_content_height() LayoutStub {
	return layout_stub('FormattingContext.h:136 calculate_max_content_height')
}

// Translated from Libraries/LibWeb/Layout/FormattingContext.h:138
// Original signature: FormattingContext::CSSPixels calculate_fit_content_height(Layout::Box const&, AvailableSpace const&) const;
pub fn formatting_context_h_138_calculate_fit_content_height() LayoutStub {
	return layout_stub('FormattingContext.h:138 calculate_fit_content_height')
}

// Translated from Libraries/LibWeb/Layout/FormattingContext.h:139
// Original signature: FormattingContext::CSSPixels calculate_fit_content_width(Layout::Box const&, AvailableSpace const&) const;
pub fn formatting_context_h_139_calculate_fit_content_width() LayoutStub {
	return layout_stub('FormattingContext.h:139 calculate_fit_content_width')
}

// Translated from Libraries/LibWeb/Layout/FormattingContext.h:141
// Original signature: FormattingContext::CSSPixels calculate_inner_width(Layout::Box const&, AvailableSize const&, CSS::Size const& width) const;
pub fn formatting_context_h_141_calculate_inner_width() LayoutStub {
	return layout_stub('FormattingContext.h:141 calculate_inner_width')
}

// Translated from Libraries/LibWeb/Layout/FormattingContext.h:142
// Original signature: FormattingContext::[[nodiscard]] CSSPixels calculate_inner_height(Box const&, AvailableSpace const&, CSS::Size const& height) const;
pub fn formatting_context_h_142_calculate_inner_height() LayoutStub {
	return layout_stub('FormattingContext.h:142 calculate_inner_height')
}

// Translated from Libraries/LibWeb/Layout/FormattingContext.h:144
// Original signature: FormattingContext::virtual CSSPixels greatest_child_width(Box const&) const;
pub fn formatting_context_h_144_greatest_child_width() LayoutStub {
	return layout_stub('FormattingContext.h:144 greatest_child_width')
}

// Translated from Libraries/LibWeb/Layout/FormattingContext.h:146
// Original signature: FormattingContext::[[nodiscard]] CSSPixelRect absolute_content_rect(Box const&) const;
pub fn formatting_context_h_146_absolute_content_rect() LayoutStub {
	return layout_stub('FormattingContext.h:146 absolute_content_rect')
}

// Translated from Libraries/LibWeb/Layout/FormattingContext.h:147
// Original signature: FormattingContext::[[nodiscard]] CSSPixelRect margin_box_rect_in_ancestor_coordinate_space(Box const&, Box const& ancestor_box) const;
pub fn formatting_context_h_147_margin_box_rect_in_ancestor_coordinate_space() LayoutStub {
	return layout_stub('FormattingContext.h:147 margin_box_rect_in_ancestor_coordinate_space')
}

// Translated from Libraries/LibWeb/Layout/FormattingContext.h:148
// Original signature: FormattingContext::[[nodiscard]] CSSPixelRect margin_box_rect_in_ancestor_coordinate_space(LayoutState::UsedValues const&, Box const& ancestor_box) const;
pub fn formatting_context_h_148_margin_box_rect_in_ancestor_coordinate_space() LayoutStub {
	return layout_stub('FormattingContext.h:148 margin_box_rect_in_ancestor_coordinate_space')
}

// Translated from Libraries/LibWeb/Layout/FormattingContext.h:149
// Original signature: FormattingContext::[[nodiscard]] CSSPixelRect content_box_rect(Box const&) const;
pub fn formatting_context_h_149_content_box_rect() LayoutStub {
	return layout_stub('FormattingContext.h:149 content_box_rect')
}

// Translated from Libraries/LibWeb/Layout/FormattingContext.h:150
// Original signature: FormattingContext::[[nodiscard]] CSSPixelRect content_box_rect(LayoutState::UsedValues const&) const;
pub fn formatting_context_h_150_content_box_rect() LayoutStub {
	return layout_stub('FormattingContext.h:150 content_box_rect')
}

// Translated from Libraries/LibWeb/Layout/FormattingContext.h:151
// Original signature: FormattingContext::[[nodiscard]] CSSPixelRect content_box_rect_in_ancestor_coordinate_space(LayoutState::UsedValues const&, Box const& ancestor_box) const;
pub fn formatting_context_h_151_content_box_rect_in_ancestor_coordinate_space() LayoutStub {
	return layout_stub('FormattingContext.h:151 content_box_rect_in_ancestor_coordinate_space')
}

// Translated from Libraries/LibWeb/Layout/FormattingContext.h:152
// Original signature: FormattingContext::[[nodiscard]] CSSPixels box_baseline(Box const&) const;
pub fn formatting_context_h_152_box_baseline() LayoutStub {
	return layout_stub('FormattingContext.h:152 box_baseline')
}

// Translated from Libraries/LibWeb/Layout/FormattingContext.h:153
// Original signature: FormattingContext::[[nodiscard]] CSSPixels containing_block_width_for(NodeWithStyleAndBoxModelMetrics const&) const;
pub fn formatting_context_h_153_containing_block_width_for() LayoutStub {
	return layout_stub('FormattingContext.h:153 containing_block_width_for')
}

// Translated from Libraries/LibWeb/Layout/FormattingContext.h:155
// Original signature: FormattingContext::[[nodiscard]] CSSPixels calculate_stretch_fit_width(Box const&, AvailableSize const&) const;
pub fn formatting_context_h_155_calculate_stretch_fit_width() LayoutStub {
	return layout_stub('FormattingContext.h:155 calculate_stretch_fit_width')
}

// Translated from Libraries/LibWeb/Layout/FormattingContext.h:156
// Original signature: FormattingContext::[[nodiscard]] CSSPixels calculate_stretch_fit_height(Box const&, AvailableSize const&) const;
pub fn formatting_context_h_156_calculate_stretch_fit_height() LayoutStub {
	return layout_stub('FormattingContext.h:156 calculate_stretch_fit_height')
}

// Translated from Libraries/LibWeb/Layout/FormattingContext.h:158
// Original signature: FormattingContext::bool can_skip_is_anonymous_text_run(Box&);
pub fn formatting_context_h_158_can_skip_is_anonymous_text_run() LayoutStub {
	return layout_stub('FormattingContext.h:158 can_skip_is_anonymous_text_run')
}

// Translated from Libraries/LibWeb/Layout/FormattingContext.h:160
// Original signature: FormattingContext::void compute_inset(NodeWithStyleAndBoxModelMetrics const&, CSSPixelSize containing_block_size);
pub fn formatting_context_h_160_compute_inset() LayoutStub {
	return layout_stub('FormattingContext.h:160 compute_inset')
}

// Translated from Libraries/LibWeb/Layout/FormattingContext.h:163
// Original signature: FormattingContext::FormattingContext(Type, LayoutMode, LayoutState&, Box const&, FormattingContext* parent = nullptr);
pub fn formatting_context_h_163_formatting_context_formatting_context() LayoutStub {
	return layout_stub('FormattingContext.h:163 FormattingContext::FormattingContext')
}

// Translated from Libraries/LibWeb/Layout/FormattingContext.h:165
// Original signature: FormattingContext::[[nodiscard]] bool should_treat_width_as_auto(Box const&, AvailableSpace const&) const;
pub fn formatting_context_h_165_should_treat_width_as_auto() LayoutStub {
	return layout_stub('FormattingContext.h:165 should_treat_width_as_auto')
}

// Translated from Libraries/LibWeb/Layout/FormattingContext.h:166
// Original signature: FormattingContext::[[nodiscard]] bool should_treat_height_as_auto(Box const&, AvailableSpace const&) const;
pub fn formatting_context_h_166_should_treat_height_as_auto() LayoutStub {
	return layout_stub('FormattingContext.h:166 should_treat_height_as_auto')
}

// Translated from Libraries/LibWeb/Layout/FormattingContext.h:168
// Original signature: FormattingContext::[[nodiscard]] bool should_treat_max_width_as_none(Box const&, AvailableSize const&) const;
pub fn formatting_context_h_168_should_treat_max_width_as_none() LayoutStub {
	return layout_stub('FormattingContext.h:168 should_treat_max_width_as_none')
}

// Translated from Libraries/LibWeb/Layout/FormattingContext.h:169
// Original signature: FormattingContext::[[nodiscard]] bool should_treat_max_height_as_none(Box const&, AvailableSize const&) const;
pub fn formatting_context_h_169_should_treat_max_height_as_none() LayoutStub {
	return layout_stub('FormattingContext.h:169 should_treat_max_height_as_none')
}

// Translated from Libraries/LibWeb/Layout/FormattingContext.h:171
// Original signature: FormattingContext::[[nodiscard]] bool box_is_sized_as_replaced_element(Box const&, AvailableSpace const&) const;
pub fn formatting_context_h_171_box_is_sized_as_replaced_element() LayoutStub {
	return layout_stub('FormattingContext.h:171 box_is_sized_as_replaced_element')
}

// Translated from Libraries/LibWeb/Layout/FormattingContext.h:173
// Original signature: FormattingContext::OwnPtr<FormattingContext> layout_inside(Box const&, LayoutMode, AvailableSpace const&);
pub fn formatting_context_h_173_layout_inside() LayoutStub {
	return layout_stub('FormattingContext.h:173 layout_inside')
}

// Translated from Libraries/LibWeb/Layout/FormattingContext.h:197
// Original signature: FormattingContext::CSSPixels tentative_width_for_replaced_element(Box const&, CSS::Size const& computed_width, AvailableSpace const&) const;
pub fn formatting_context_h_197_tentative_width_for_replaced_element() LayoutStub {
	return layout_stub('FormattingContext.h:197 tentative_width_for_replaced_element')
}

// Translated from Libraries/LibWeb/Layout/FormattingContext.h:198
// Original signature: FormattingContext::CSSPixels tentative_height_for_replaced_element(Box const&, CSS::Size const& computed_height, AvailableSpace const&) const;
pub fn formatting_context_h_198_tentative_height_for_replaced_element() LayoutStub {
	return layout_stub('FormattingContext.h:198 tentative_height_for_replaced_element')
}

// Translated from Libraries/LibWeb/Layout/FormattingContext.h:199
// Original signature: FormattingContext::CSSPixels compute_auto_height_for_block_formatting_context_root(Box const&) const;
pub fn formatting_context_h_199_compute_auto_height_for_block_formatting_context_root() LayoutStub {
	return layout_stub('FormattingContext.h:199 compute_auto_height_for_block_formatting_context_root')
}

// Translated from Libraries/LibWeb/Layout/FormattingContext.h:201
// Original signature: FormattingContext::[[nodiscard]] CSSPixelSize solve_replaced_size_constraint(CSSPixels input_width, CSSPixels input_height, Box const&, AvailableSpace const&) const;
pub fn formatting_context_h_201_solve_replaced_size_constraint() LayoutStub {
	return layout_stub('FormattingContext.h:201 solve_replaced_size_constraint')
}

// Translated from Libraries/LibWeb/Layout/FormattingContext.h:203
// Original signature: FormattingContext::ShrinkToFitResult calculate_shrink_to_fit_widths(Box const&);
pub fn formatting_context_h_203_calculate_shrink_to_fit_widths() LayoutStub {
	return layout_stub('FormattingContext.h:203 calculate_shrink_to_fit_widths')
}

// Translated from Libraries/LibWeb/Layout/FormattingContext.h:205
// Original signature: FormattingContext::void layout_absolutely_positioned_element(Box const&, AbsposContainingBlockInfo const&);
pub fn formatting_context_h_205_layout_absolutely_positioned_element() LayoutStub {
	return layout_stub('FormattingContext.h:205 layout_absolutely_positioned_element')
}

// Translated from Libraries/LibWeb/Layout/FormattingContext.h:206
// Original signature: FormattingContext::void layout_absolutely_positioned_children();
pub fn formatting_context_h_206_layout_absolutely_positioned_children() LayoutStub {
	return layout_stub('FormattingContext.h:206 layout_absolutely_positioned_children')
}

// Translated from Libraries/LibWeb/Layout/FormattingContext.h:207
// Original signature: FormattingContext::virtual AbsposContainingBlockInfo resolve_abspos_containing_block_info(Box const&);
pub fn formatting_context_h_207_resolve_abspos_containing_block_info() LayoutStub {
	return layout_stub('FormattingContext.h:207 resolve_abspos_containing_block_info')
}

// Translated from Libraries/LibWeb/Layout/FormattingContext.h:208
// Original signature: FormattingContext::void compute_width_for_absolutely_positioned_element(Box const&, AvailableSpace const&);
pub fn formatting_context_h_208_compute_width_for_absolutely_positioned_element() LayoutStub {
	return layout_stub('FormattingContext.h:208 compute_width_for_absolutely_positioned_element')
}

// Translated from Libraries/LibWeb/Layout/FormattingContext.h:209
// Original signature: FormattingContext::void compute_width_for_absolutely_positioned_non_replaced_element(Box const&, AvailableSpace const&);
pub fn formatting_context_h_209_compute_width_for_absolutely_positioned_non_replaced_element() LayoutStub {
	return layout_stub('FormattingContext.h:209 compute_width_for_absolutely_positioned_non_replaced_element')
}

// Translated from Libraries/LibWeb/Layout/FormattingContext.h:210
// Original signature: FormattingContext::void compute_width_for_absolutely_positioned_replaced_element(Box const&, AvailableSpace const&);
pub fn formatting_context_h_210_compute_width_for_absolutely_positioned_replaced_element() LayoutStub {
	return layout_stub('FormattingContext.h:210 compute_width_for_absolutely_positioned_replaced_element')
}

// Translated from Libraries/LibWeb/Layout/FormattingContext.h:216
// Original signature: FormattingContext::void compute_height_for_absolutely_positioned_element(Box const&, AvailableSpace const&, BeforeOrAfterInsideLayout);
pub fn formatting_context_h_216_compute_height_for_absolutely_positioned_element() LayoutStub {
	return layout_stub('FormattingContext.h:216 compute_height_for_absolutely_positioned_element')
}

// Translated from Libraries/LibWeb/Layout/FormattingContext.h:217
// Original signature: FormattingContext::void compute_height_for_absolutely_positioned_non_replaced_element(Box const&, AvailableSpace const&, BeforeOrAfterInsideLayout);
pub fn formatting_context_h_217_compute_height_for_absolutely_positioned_non_replaced_element() LayoutStub {
	return layout_stub('FormattingContext.h:217 compute_height_for_absolutely_positioned_non_replaced_element')
}

// Translated from Libraries/LibWeb/Layout/FormattingContext.h:218
// Original signature: FormattingContext::void compute_height_for_absolutely_positioned_replaced_element(Box const&, AvailableSpace const&, BeforeOrAfterInsideLayout);
pub fn formatting_context_h_218_compute_height_for_absolutely_positioned_replaced_element() LayoutStub {
	return layout_stub('FormattingContext.h:218 compute_height_for_absolutely_positioned_replaced_element')
}

// Translated from Libraries/LibWeb/Layout/FormattingContext.h:220
// Original signature: FormattingContext::[[nodiscard]] Optional<CSSPixels> compute_auto_height_for_absolutely_positioned_element(Box const&, AvailableSpace const&, BeforeOrAfterInsideLayout) const;
pub fn formatting_context_h_220_compute_auto_height_for_absolutely_positioned_element() LayoutStub {
	return layout_stub('FormattingContext.h:220 compute_auto_height_for_absolutely_positioned_element')
}

// Translated from Libraries/LibWeb/Layout/FormattingContext.h:222
// Original signature: FormattingContext::[[nodiscard]] Box const* box_child_to_derive_baseline_from(Box const&) const;
pub fn formatting_context_h_222_box_child_to_derive_baseline_from() LayoutStub {
	return layout_stub('FormattingContext.h:222 box_child_to_derive_baseline_from')
}

// ---- FormattingContext.cpp (57 translated function stubs) ----

// Translated from Libraries/LibWeb/Layout/FormattingContext.cpp:27
// Original signature: FormattingContext::FormattingContext(Type type, LayoutMode layout_mode, LayoutState& state, Box const& context_box, FormattingContext* parent) : m_type(type) , m_layout_mode(layout_mode) , m_parent(parent) , m_context_box(context_box) , m_state(state)
pub fn formatting_context_cpp_27_formatting_context_formatting_context() LayoutStub {
	return layout_stub('FormattingContext.cpp:27 FormattingContext::FormattingContext')
}

// Translated from Libraries/LibWeb/Layout/FormattingContext.cpp:36
// Original signature: FormattingContext::~FormattingContext() = default;
pub fn formatting_context_cpp_36_formatting_context_destroy_formatting_context() LayoutStub {
	return layout_stub('FormattingContext.cpp:36 FormattingContext::~FormattingContext')
}

// Translated from Libraries/LibWeb/Layout/FormattingContext.cpp:39
// Original signature: bool FormattingContext::creates_block_formatting_context(Box const& box)
// https://developer.mozilla.org/en-US/docs/Web/Guide/CSS/Block_formatting_context
// NOTE: Replaced elements never create a BFC.
// AD-HOC: We create a BFC for SVG foreignObject.
// display: table
// display: flex
// display: grid
// NOTE: This function uses MDN as a reference, not because it's authoritative,
// but because they've gathered all the conditions in one convenient location.
// The root element of the document (<html>).
// Floats (elements where float isn't none).
// Absolutely positioned elements (elements where position is absolute or fixed).
// Inline-blocks (elements with display: inline-block).
// Table cells (elements with display: table-cell, which is the default for HTML table cells).
// Table captions (elements with display: table-caption, which is the default for HTML table captions).
// FIXME: Anonymous table cells implicitly created by the elements with display: table, table-row, table-row-
// group, table-header-group, table-footer-group
// (which is the default for HTML tables, table rows, table bodies, table headers, and table footers,
// respectively), or inline-table.
// Block elements where overflow has a value other than visible and clip.
// display: flow-root.
// https://drafts.csswg.org/css-contain-2/#containment-types
// 1. The layout containment box establishes an independent formatting context.
// 4. The paint containment box establishes an independent formatting context.
// Flex items (direct children of the element with display: flex or inline-flex) if they are neither flex nor
// grid nor table containers themselves.
// Grid items (direct children of the element with display: grid or inline-grid) if they are neither flex nor
// grid nor table containers themselves.
// https://drafts.csswg.org/css-multicol-2/#the-multi-column-model
// An element whose 'column-width', 'column-count', or 'column-height' property is not 'auto' establishes a
// multi-
// column container (or multicol container for short), and therefore acts as a container for multi-column layout.
// FIXME: Maybe add column-height, depending on the resolution for https://github.com/w3c/csswg-
// drafts/issues/12688
// FIXME: column-span: all should always create a new formatting context, even when the column-span: all element
// isn't contained by a multicol container (Spec change, Chrome bug).
// https://html.spec.whatwg.org/multipage/rendering.html#the-fieldset-and-legend-elements
// The fieldset element, when it generates a CSS box, is expected to act as follows:
// The element is expected to establish a new block formatting context.
pub fn formatting_context_cpp_39_formatting_context_creates_block_formatting_context() LayoutStub {
	return layout_stub('FormattingContext.cpp:39 FormattingContext::creates_block_formatting_context')
}

// Translated from Libraries/LibWeb/Layout/FormattingContext.cpp:141
// Original signature: Optional<FormattingContext::Type> FormattingContext::formatting_context_type_created_by_box(Box const& box)
// FIXME: We should create a MathML-specific formatting context here, but for now use a BFC, so _something_ is
// displayed
// The box is a block container that doesn't create its own BFC.
// It will be formatted by the containing BFC.
// HACK: Instead of crashing, create a dummy formatting context that does nothing.
// FIXME: We need this for <math> elements
pub fn formatting_context_cpp_141_formatting_context_formatting_context_type_created_by_box() LayoutStub {
	return layout_stub('FormattingContext.cpp:141 FormattingContext::formatting_context_type_created_by_box')
}

// Translated from Libraries/LibWeb/Layout/FormattingContext.cpp:192
// Original signature: : FormattingContext(Type::InternalReplaced, layout_mode, state, box)
pub fn formatting_context_cpp_192_function() LayoutStub {
	return layout_stub('FormattingContext.cpp:192 function')
}

// Translated from Libraries/LibWeb/Layout/FormattingContext.cpp:203
// Original signature: : FormattingContext(Type::InternalDummy, layout_mode, state, box)
pub fn formatting_context_cpp_203_function() LayoutStub {
	return layout_stub('FormattingContext.cpp:203 function')
}

// Translated from Libraries/LibWeb/Layout/FormattingContext.cpp:211
// Original signature: OwnPtr<FormattingContext> FormattingContext::create_independent_formatting_context_if_needed(LayoutState& state, LayoutMode layout_mode, Box const& child_box)
// IFC should always be created by a parent BFC directly.
pub fn formatting_context_cpp_211_formatting_context_create_independent_formatting_context_if_needed() LayoutStub {
	return layout_stub('FormattingContext.cpp:211 FormattingContext::create_independent_formatting_context_if_needed')
}

// Translated from Libraries/LibWeb/Layout/FormattingContext.cpp:243
// Original signature: NonnullOwnPtr<FormattingContext> FormattingContext::create_independent_formatting_context(LayoutState& state, LayoutMode layout_mode, Box const& child_box)
// HACK: Instead of crashing in scenarios that assume the formatting context can be created, create a dummy
// formatting context that does nothing.
pub fn formatting_context_cpp_243_formatting_context_create_independent_formatting_context() LayoutStub {
	return layout_stub('FormattingContext.cpp:243 FormattingContext::create_independent_formatting_context')
}

// Translated from Libraries/LibWeb/Layout/FormattingContext.cpp:256
// Original signature: OwnPtr<FormattingContext> FormattingContext::layout_inside(Box const& child_box, LayoutMode layout_mode, AvailableSpace const& available_space)
// OPTIMIZATION: If we're doing intrinsic sizing and `child_box` has definite size in both axes,
// we don't need to layout its insides. The size is resolvable without learning
// the metrics of whatever's inside the box.
pub fn formatting_context_cpp_256_formatting_context_layout_inside() LayoutStub {
	return layout_stub('FormattingContext.cpp:256 FormattingContext::layout_inside')
}

// Translated from Libraries/LibWeb/Layout/FormattingContext.cpp:284
// Original signature: CSSPixels FormattingContext::greatest_child_width(Box const& box) const
pub fn formatting_context_cpp_284_formatting_context_greatest_child_width() LayoutStub {
	return layout_stub('FormattingContext.cpp:284 FormattingContext::greatest_child_width')
}

// Translated from Libraries/LibWeb/Layout/FormattingContext.cpp:301
// Original signature: FormattingContext::ShrinkToFitResult FormattingContext::calculate_shrink_to_fit_widths(Box const& box)
pub fn formatting_context_cpp_301_formatting_context_calculate_shrink_to_fit_widths() LayoutStub {
	return layout_stub('FormattingContext.cpp:301 FormattingContext::calculate_shrink_to_fit_widths')
}

// Translated from Libraries/LibWeb/Layout/FormattingContext.cpp:309
// Original signature: CSSPixelSize FormattingContext::solve_replaced_size_constraint(CSSPixels input_width, CSSPixels input_height, Box const& box, AvailableSpace const& available_space) const
// 10.4 Minimum and maximum widths: 'min-width' and 'max-width'
// https://www.w3.org/TR/CSS22/visudet.html#min-max-widths
// These are from the "Constraint Violation" table in spec, but reordered so that each condition is
// interpreted as mutually exclusive to any other.
pub fn formatting_context_cpp_309_formatting_context_solve_replaced_size_constraint() LayoutStub {
	return layout_stub('FormattingContext.cpp:309 FormattingContext::solve_replaced_size_constraint')
}

// Translated from Libraries/LibWeb/Layout/FormattingContext.cpp:364
// Original signature: Optional<CSSPixels> FormattingContext::compute_auto_height_for_absolutely_positioned_element(Box const& box, AvailableSpace const& available_space, BeforeOrAfterInsideLayout before_or_after_inside_layout) const
// NOTE: CSS 2.2 tells us to use the "auto height for block formatting context roots" here.
// That's fine as long as the box is a BFC root.
// NOTE: For anything else, we use the fit-content height.
// This should eventually be replaced by the new absolute positioning model:
// https://www.w3.org/TR/css-position-3/#abspos-layout
pub fn formatting_context_cpp_364_formatting_context_compute_auto_height_for_absolutely_positioned_element() LayoutStub {
	return layout_stub('FormattingContext.cpp:364 FormattingContext::compute_auto_height_for_absolutely_positioned_element')
}

// Translated from Libraries/LibWeb/Layout/FormattingContext.cpp:381
// Original signature: CSSPixels FormattingContext::compute_auto_height_for_block_formatting_context_root(Box const& root) const
// https://www.w3.org/TR/CSS22/visudet.html#root-height
// 10.6.7 'Auto' heights for block formatting context roots
// If it only has inline-level children, the height is the distance between
// the top content edge and the bottom of the bottommost line box.
// If it has block-level children, the height is the distance between
// the top margin-edge of the topmost block-level child box
// and the bottom margin-edge of the bottommost block-level child box.
// NOTE: The top margin edge of the topmost block-level child box is the same as the top content edge of the root
// box.
// Absolutely positioned children are ignored,
// and relatively positioned boxes are considered without their offset.
// Note that the child box may be an anonymous block box.
// FIXME: This doesn't look right.
// In addition, if the element has any floating descendants
// whose bottom margin edge is below the element's bottom content edge,
// then the height is increased to include those edges.
// NOTE: Floating box coordinates are relative to their own containing block,
// which may or may not be the BFC root.
pub fn formatting_context_cpp_381_formatting_context_compute_auto_height_for_block_formatting_context_root() LayoutStub {
	return layout_stub('FormattingContext.cpp:381 FormattingContext::compute_auto_height_for_block_formatting_context_root')
}

// Translated from Libraries/LibWeb/Layout/FormattingContext.cpp:441
// Original signature: CSSPixels FormattingContext::compute_table_box_width_inside_table_wrapper(Box const& box, AvailableSpace const& available_space)
// 17.5.2 Table width algorithms: the 'table-layout' property
// https://www.w3.org/TR/CSS22/tables.html#width-layout
// Table wrapper width should be equal to width of table box it contains
// If 'margin-left', or 'margin-right' are computed as 'auto', their used value is '0'.
// table-wrapper can't have borders or paddings but it might have margin taken from table-root.
pub fn formatting_context_cpp_441_formatting_context_compute_table_box_width_inside_table_wrapper() LayoutStub {
	return layout_stub('FormattingContext.cpp:441 FormattingContext::compute_table_box_width_inside_table_wrapper')
}

// Translated from Libraries/LibWeb/Layout/FormattingContext.cpp:485
// Original signature: CSSPixels FormattingContext::compute_table_box_height_inside_table_wrapper(Box const& box, AvailableSpace const& available_space)
// 17.5.3 Table height algorithms
// https://www.w3.org/TR/CSS22/tables.html#height-layout
// Table wrapper height should be equal to height of table box it contains
// If 'margin-top', or 'margin-bottom' are computed as 'auto', their used value is '0'.
// table-wrapper can't have borders or paddings but it might have margin taken from table-root.
pub fn formatting_context_cpp_485_formatting_context_compute_table_box_height_inside_table_wrapper() LayoutStub {
	return layout_stub('FormattingContext.cpp:485 FormattingContext::compute_table_box_height_inside_table_wrapper')
}

// Translated from Libraries/LibWeb/Layout/FormattingContext.cpp:523
// Original signature: CSSPixels FormattingContext::tentative_width_for_replaced_element(Box const& box, CSS::Size const& computed_width, AvailableSpace const& available_space) const
// 10.3.2 Inline, replaced elements, https://www.w3.org/TR/CSS22/visudet.html#inline-replaced-width
// Treat percentages of indefinite containing block widths as 0 (the initial width).
// If 'height' and 'width' both have computed values of 'auto' and the element also has an intrinsic width,
// then that intrinsic width is the used value of 'width'.
// If 'height' and 'width' both have computed values of 'auto' and the element has no intrinsic width,
// but does have an intrinsic height and intrinsic ratio;
// or if 'width' has a computed value of 'auto',
// 'height' has some other computed value, and the element does have an intrinsic ratio; then the used value of
// 'width' is:
// (used height) * (intrinsic ratio)
// If 'height' and 'width' both have computed values of 'auto' and the element has an intrinsic ratio but no
// intrinsic height or width,
// then the used value of 'width' is undefined in CSS 2.2. However, it is suggested that, if the containing
// block's width does not itself
// depend on the replaced element's width, then the used value of 'width' is calculated from the constraint
// equation used for block-level,
// non-replaced elements in normal flow.
// Otherwise, if 'width' has a computed value of 'auto', and the element has an intrinsic width, then that
// intrinsic width is the used value of 'width'.
// Otherwise, if 'width' has a computed value of 'auto', but none of the conditions above are met, then the used
// value of 'width' becomes 300px.
// If 300px is too wide to fit the device, UAs should use the width of the largest rectangle that has a 2:1 ratio
// and fits the device instead.
pub fn formatting_context_cpp_523_formatting_context_tentative_width_for_replaced_element() LayoutStub {
	return layout_stub('FormattingContext.cpp:523 FormattingContext::tentative_width_for_replaced_element')
}

// Translated from Libraries/LibWeb/Layout/FormattingContext.cpp:575
// Original signature: void FormattingContext::compute_width_for_absolutely_positioned_element(Box const& box, AvailableSpace const& available_space)
pub fn formatting_context_cpp_575_formatting_context_compute_width_for_absolutely_positioned_element() LayoutStub {
	return layout_stub('FormattingContext.cpp:575 FormattingContext::compute_width_for_absolutely_positioned_element')
}

// Translated from Libraries/LibWeb/Layout/FormattingContext.cpp:583
// Original signature: void FormattingContext::compute_height_for_absolutely_positioned_element(Box const& box, AvailableSpace const& available_space, BeforeOrAfterInsideLayout before_or_after_inside_layout)
pub fn formatting_context_cpp_583_formatting_context_compute_height_for_absolutely_positioned_element() LayoutStub {
	return layout_stub('FormattingContext.cpp:583 FormattingContext::compute_height_for_absolutely_positioned_element')
}

// Translated from Libraries/LibWeb/Layout/FormattingContext.cpp:591
// Original signature: CSSPixels FormattingContext::compute_width_for_replaced_element(Box const& box, AvailableSpace const& available_space) const
// 10.3.4 Block-level, replaced elements in normal flow...
// 10.3.2 Inline, replaced elements
// 1. The tentative used width is calculated (without 'min-width' and 'max-width')
// 2. If the tentative used width is greater than 'max-width', the rules above are applied again,
// but this time using the computed value of 'max-width' as the computed value for 'width'.
// 3. If the resulting width is smaller than 'min-width', the rules above are applied again,
// but this time using the value of 'min-width' as the computed value for 'width'.
pub fn formatting_context_cpp_591_formatting_context_compute_width_for_replaced_element() LayoutStub {
	return layout_stub('FormattingContext.cpp:591 FormattingContext::compute_width_for_replaced_element')
}

// Translated from Libraries/LibWeb/Layout/FormattingContext.cpp:633
// Original signature: CSSPixels FormattingContext::tentative_height_for_replaced_element(Box const& box, CSS::Size const& computed_height, AvailableSpace const& available_space) const
// 10.6.2 Inline replaced elements, block-level replaced elements in normal flow, 'inline-block' replaced
// elements in normal flow and floating replaced elements
// https://www.w3.org/TR/CSS22/visudet.html#inline-replaced-height
// If 'height' and 'width' both have computed values of 'auto' and the element also has
// an intrinsic height, then that intrinsic height is the used value of 'height'.
// Otherwise, if 'height' has a computed value of 'auto', and the element has an intrinsic ratio then the used
// value of 'height' is:
// (used width) / (intrinsic ratio)
// Otherwise, if 'height' has a computed value of 'auto', and the element has an intrinsic height, then that
// intrinsic height is the used value of 'height'.
// Otherwise, if 'height' has a computed value of 'auto', but none of the conditions above are met,
// then the used value of 'height' must be set to the height of the largest rectangle that has a 2:1 ratio, has a
// height not greater than 150px,
// and has a width not greater than the device width.
// FIXME: Handle cases when available_space is not definite.
pub fn formatting_context_cpp_633_formatting_context_tentative_height_for_replaced_element() LayoutStub {
	return layout_stub('FormattingContext.cpp:633 FormattingContext::tentative_height_for_replaced_element')
}

// Translated from Libraries/LibWeb/Layout/FormattingContext.cpp:661
// Original signature: CSSPixels FormattingContext::compute_height_for_replaced_element(Box const& box, AvailableSpace const& available_space) const
// 10.6.2 Inline replaced elements
// 10.6.4 Block-level replaced elements in normal flow
// 10.6.6 Floating replaced elements
// 10.6.10 'inline-block' replaced elements in normal flow
// 1. The tentative used height is calculated (without 'min-height' and 'max-height')
// However, for replaced elements with both 'width' and 'height' computed as 'auto',
// use the algorithm under 'Minimum and maximum widths'
// https://www.w3.org/TR/CSS22/visudet.html#min-max-widths
// to find the used width and height.
// NOTE: This is a special case where calling tentative_width_for_replaced_element() would call us right back,
// and we'd end up in an infinite loop. So we need to handle this case separately.
// 2. If this tentative height is greater than 'max-height', the rules above are applied again,
// but this time using the value of 'max-height' as the computed value for 'height'.
// 3. If the resulting height is smaller than 'min-height', the rules above are applied again,
// but this time using the value of 'min-height' as the computed value for 'height'.
pub fn formatting_context_cpp_661_formatting_context_compute_height_for_replaced_element() LayoutStub {
	return layout_stub('FormattingContext.cpp:661 FormattingContext::compute_height_for_replaced_element')
}

// Translated from Libraries/LibWeb/Layout/FormattingContext.cpp:714
// Original signature: void FormattingContext::compute_width_for_absolutely_positioned_non_replaced_element(Box const& box, AvailableSpace const& available_space)
// If all three of 'left', 'width', and 'right' are 'auto':
// First set any 'auto' values for 'margin-left' and 'margin-right' to 0.
// Then, if the 'direction' property of the element establishing the static-position containing block
// is 'ltr' set 'left' to the static position and apply rule number three below;
// otherwise, set 'right' to the static position and apply rule number one below.
// NOTE: As with compute_height_for_absolutely_positioned_non_replaced_element, we actually apply these
// steps in the opposite order since the static position may depend on the width of the box.
// If none of the three is auto:
// If both margin-left and margin-right are auto,
// solve the equation under the extra constraint that the two margins get equal values
// FIXME: unless this would make them negative, in which case when direction of the containing block is ltr
// (rtl), set margin-left (margin-right) to 0 and solve for margin-right (margin-left).
// If one of margin-left or margin-right is auto, solve the equation for that value.
// If the values are over-constrained, ignore the value for left
// (in case the direction property of the containing block is rtl)
// or right (in case direction is ltr) and solve for that value.
// NOTE: At this point we *are* over-constrained since none of margin-left, left, width, right, or margin-right
// are auto.
// FIXME: Check direction.
// 1. 'left' and 'width' are 'auto' and 'right' is not 'auto',
// then the width is shrink-to-fit. Then solve for 'left'
// 2. 'left' and 'right' are 'auto' and 'width' is not 'auto',
// then if the 'direction' property of the element establishing
// the static-position containing block is 'ltr' set 'left'
// to the static position, otherwise set 'right' to the static position.
// Then solve for 'left' (if 'direction is 'rtl') or 'right' (if 'direction' is 'ltr').
// FIXME: Check direction
// 3. 'width' and 'right' are 'auto' and 'left' is not 'auto',
// then the width is shrink-to-fit. Then solve for 'right'
// 4. 'left' is 'auto', 'width' and 'right' are not 'auto', then solve for 'left'
// 5. 'width' is 'auto', 'left' and 'right' are not 'auto', then solve for 'width'
// 6. 'right' is 'auto', 'left' and 'width' are not 'auto', then solve for 'right'
// 1. The tentative used width is calculated (without 'min-width' and 'max-width')
// 2. The tentative used width is greater than 'max-width', the rules above are applied again,
// but this time using the computed value of 'max-width' as the computed value for 'width'.
// 3. If the resulting width is smaller than 'min-width', the rules above are applied again,
// but this time using the value of 'min-width' as the computed value for 'width'.
pub fn formatting_context_cpp_714_formatting_context_compute_width_for_absolutely_positioned_non_replaced_eleme() LayoutStub {
	return layout_stub('FormattingContext.cpp:714 FormattingContext::compute_width_for_absolutely_positioned_non_replaced_element')
}

// Translated from Libraries/LibWeb/Layout/FormattingContext.cpp:895
// Original signature: void FormattingContext::compute_width_for_absolutely_positioned_replaced_element(Box const& box, AvailableSpace const& available_space)
// https://drafts.csswg.org/css2/#abs-replaced-width
// 10.3.8 Absolutely positioned, replaced elements
// In this case, section 10.3.7 applies up through and including the constraint equation,
// but the rest of section 10.3.7 is replaced by the following rules:
// 1. The used value of 'width' is determined as for inline replaced elements.
// If 'margin-left' or 'margin-right' is specified as 'auto' its used value is determined by the rules below.
// 2. If both 'left' and 'right' have the value 'auto', then if the 'direction' property of the
// element establishing the static-position containing block is 'ltr', set 'left' to the static
// position; else if 'direction' is 'rtl', set 'right' to the static position.
// 3. If 'left' or 'right' are 'auto', replace any 'auto' on 'margin-left' or 'margin-right' with '0'.
// 4. If at this point both 'margin-left' and 'margin-right' are still 'auto', solve the equation
// under the extra constraint that the two margins must get equal values, unless this would make
// them negative, in which case when the direction of the containing block is 'ltr' ('rtl'),
// set 'margin-left' ('margin-right') to zero and solve for 'margin-right' ('margin-left').
// 5. If at this point there is an 'auto' left, solve the equation for that value.
// 6. If at this point the values are over-constrained, ignore the value for either 'left'
// (in case the 'direction' property of the containing block is 'rtl') or 'right'
// (in case 'direction' is 'ltr') and solve for that value.
pub fn formatting_context_cpp_895_formatting_context_compute_width_for_absolutely_positioned_replaced_element() LayoutStub {
	return layout_stub('FormattingContext.cpp:895 FormattingContext::compute_width_for_absolutely_positioned_replaced_element')
}

// Translated from Libraries/LibWeb/Layout/FormattingContext.cpp:979
// Original signature: void FormattingContext::compute_height_for_absolutely_positioned_non_replaced_element(Box const& box, AvailableSpace const& available_space, BeforeOrAfterInsideLayout before_or_after_inside_layout)
// https://drafts.csswg.org/css-position-3/#abs-non-replaced-height
// 5.3. The Height Of Absolutely Positioned, Non-Replaced Elements
// For absolutely positioned elements, the used values of the vertical dimensions must satisfy this constraint:
// top + margin-top + border-top-width + padding-top + height + padding-bottom + border-bottom-width + margin-
// bottom + bottom = height of containing block
// NOTE: This function is called twice: both before and after inside layout.
// In the before pass, if it turns out we need the automatic height of the box, we abort these steps.
// This allows the box to retain an indefinite height from the perspective of inside layout.
// Reset values that may have been modified by a previous call (when re-solving for min/max-height).
// If all three of top, height, and bottom are auto:
// First set any auto values for margin-top and margin-bottom to 0,
// then set top to the static position,
// and finally apply rule number three below.
// NOTE: We actually perform these two steps in the opposite order,
// because the static position may depend on the height of the box (due to alignment properties).
// If none of the three are auto:
// If both margin-top and margin-bottom are auto,
// solve the equation under the extra constraint that the two margins get equal values.
// If one of margin-top or margin-bottom is auto,
// solve the equation for that value.
// If the values are over-constrained,
// ignore the value for bottom and solve for that value.
// Otherwise,
// set auto values for margin-top and margin-bottom to 0,
// and pick one of the following six rules that apply.
// 1. If top and height are auto and bottom is not auto,
// then the height is based on the Auto heights for block formatting context roots,
// and solve for top.
// 2. If top and bottom are auto and height is not auto,
// then solve for bottom.
// 3. If height and bottom are auto and top is not auto,
// and solve for bottom.
// 4. If top is auto, height and bottom are not auto,
// then solve for top.
// 5. If height is auto, top and bottom are not auto,
// then solve for height.
// 6. If bottom is auto, top and height are not auto,
// Compute the height based on box type and CSS properties:
// https://www.w3.org/TR/css-sizing-3/#box-sizing
// If the tentative used height is greater than 'max-height', the rules above are applied again,
// but this time using the computed value of 'max-height' as the computed value for 'height'.
// If the resulting height is smaller than 'min-height', the rules above are applied again,
// but this time using the value of 'min-height' as the computed value for 'height'.
// For the before-inside-layout pass where height is still auto, apply min-max as a simple clamp.
// NOTE: The following is not directly part of any spec, but this is where we resolve
// the final used values for vertical margin/border/padding.
// do not set calculated insets or margins on the first pass, there will be a second pass
pub fn formatting_context_cpp_979_formatting_context_compute_height_for_absolutely_positioned_non_replaced_elem() LayoutStub {
	return layout_stub('FormattingContext.cpp:979 FormattingContext::compute_height_for_absolutely_positioned_non_replaced_element')
}

// Translated from Libraries/LibWeb/Layout/FormattingContext.cpp:1259
// Original signature: static Optional<CSSPixelRect> compute_inline_containing_block_rect(InlineNode const& inline_node, Box const& abspos_containing_block, LayoutState const& state)
// Computes the bounding box rectangle of an inline node's fragments.
// The rectangle is in the coordinate space of the inline's nearest block container ancestor.
// Returns the padding box rect (since containing blocks are formed by padding edges).
// Find the block container that holds this inline's fragments.
// Iterate through all line boxes and their fragments to find those belonging to this inline.
// A fragment belongs to an inline if the inline is an ancestor of the fragment's layout node.
// Check if this fragment belongs to the inline node (inline is ancestor of fragment's node).
// Expand the bounding rect by the inline's padding to get the padding box.
// Per CSS, the containing block is formed by the padding edge.
// The fragment offsets are relative to block_container. We need to translate the rect
// to be in the coordinate system of the abspos element's containing_block.
// Walk from block_container up to abspos_containing_block, accumulating offsets.
pub fn formatting_context_cpp_1259_compute_inline_containing_block_rect() LayoutStub {
	return layout_stub('FormattingContext.cpp:1259 compute_inline_containing_block_rect')
}

// Translated from Libraries/LibWeb/Layout/FormattingContext.cpp:1332
// Original signature: AbsposContainingBlockInfo FormattingContext::resolve_abspos_containing_block_info(Box const& box)
// Per-axis mode: auto+auto insets -> static position, otherwise -> inset from rect
// Check if there's an inline element that should be the real containing block.
// Normal case: padding box of the actual containing block.
pub fn formatting_context_cpp_1332_formatting_context_resolve_abspos_containing_block_info() LayoutStub {
	return layout_stub('FormattingContext.cpp:1332 FormattingContext::resolve_abspos_containing_block_info')
}

// Translated from Libraries/LibWeb/Layout/FormattingContext.cpp:1364
// Original signature: void FormattingContext::layout_absolutely_positioned_children()
pub fn formatting_context_cpp_1364_formatting_context_layout_absolutely_positioned_children() LayoutStub {
	return layout_stub('FormattingContext.cpp:1364 FormattingContext::layout_absolutely_positioned_children')
}

// Translated from Libraries/LibWeb/Layout/FormattingContext.cpp:1375
// Original signature: void FormattingContext::layout_absolutely_positioned_element(Box const& box, AbsposContainingBlockInfo const& containing_block_info)
// SVG elements cannot be absolutely positioned.
// The size of the containing block of an abspos box is always definite from the perspective of the abspos box.
// Since abspos boxes are laid out last, we can mark the containing block as having definite sizes at this point.
// The border computed values are not changed by the compute_height & width calculations below.
// The spec only adjusts and computes sizes, insets and margins.
// NOTE: We compute height before *and* after doing inside layout.
// This is done so that inside layout can resolve percentage heights.
// In some situations, e.g with non-auto top & bottom values, the height can be determined early.
// If the box width and/or height is fixed and/or or resolved from inset properties,
// mark the size as being definite (since layout was not required to resolve it, per CSS-SIZING-3).
// NOTE: BFC is special, as their abspos auto height depends on performing inside layout.
// For other formatting contexts, the height we've resolved early is good.
// See FormattingContext::compute_auto_height_for_absolutely_positioned_element()
// for the special-casing of BFC roots.
// Apply grid alignment for auto inset axes
// Horizontal axis
// Vertical axis
pub fn formatting_context_cpp_1375_formatting_context_layout_absolutely_positioned_element() LayoutStub {
	return layout_stub('FormattingContext.cpp:1375 FormattingContext::layout_absolutely_positioned_element')
}

// Translated from Libraries/LibWeb/Layout/FormattingContext.cpp:1515
// Original signature: void FormattingContext::compute_height_for_absolutely_positioned_replaced_element(Box const& box, AvailableSpace const& available_space, BeforeOrAfterInsideLayout before_or_after_inside_layout)
// 10.6.5 Absolutely positioned, replaced elements
// This situation is similar to 10.6.4, except that the element has an intrinsic height.
// The used value of 'height' is determined as for inline replaced elements.
// If 'margin-top' or 'margin-bottom' is specified as 'auto' its used value is determined by the rules below.
// 2. If both 'top' and 'bottom' have the value 'auto', replace 'top' with the element's static position.
// 3. If 'bottom' is 'auto', replace any 'auto' on 'margin-top' or 'margin-bottom' with '0'.
// 4. If at this point both 'margin-top' and 'margin-bottom' are still 'auto',
// solve the equation under the extra constraint that the two margins must get equal values.
// 5. If at this point there is an 'auto' left, solve the equation for that value.
// 6. If at this point the values are over-constrained, ignore the value for 'bottom' and solve for that value.
// do not set calculated insets or margins on the first pass, there will be a second pass
pub fn formatting_context_cpp_1515_formatting_context_compute_height_for_absolutely_positioned_replaced_element() LayoutStub {
	return layout_stub('FormattingContext.cpp:1515 FormattingContext::compute_height_for_absolutely_positioned_replaced_element')
}

// Translated from Libraries/LibWeb/Layout/FormattingContext.cpp:1592
// Original signature: void FormattingContext::compute_inset(NodeWithStyleAndBoxModelMetrics const& box, CSSPixelSize containing_block_size)
// https://www.w3.org/TR/css-position-3/#relpos-insets
// If opposing inset properties in an axis both compute to auto (their initial values),
// their used values are zero (i.e., the boxes stay in their original position in that axis).
// If only one is auto, its used value becomes the negation of the other, and the box is shifted by the specified
// amount.
// If neither is auto, the position is over-constrained; (with respect to the writing mode of its containing
// block)
// the computed end side value is ignored, and its used value becomes the negation of the start side.
// NOTE: Percentage heights resolve against the containing block's used height. If the containing block's height
// is
// indefinite, percentage insets behave as auto.
// FIXME: Respect the containing block's writing-mode.
pub fn formatting_context_cpp_1592_formatting_context_compute_inset() LayoutStub {
	return layout_stub('FormattingContext.cpp:1592 FormattingContext::compute_inset')
}

// Translated from Libraries/LibWeb/Layout/FormattingContext.cpp:1645
// Original signature: CSSPixels FormattingContext::calculate_fit_content_width(Layout::Box const& box, AvailableSpace const& available_space) const
// https://drafts.csswg.org/css-sizing-3/#fit-content-size
// If the available space in a given axis is definite, equal to clamp(min-content size, stretch-fit size,
// max-content size) (i.e. max(min-content size, min(max-content size, stretch-fit size))).
// When sizing under a min-content constraint, equal to the min-content size.
// Otherwise, equal to the max-content size in that axis.
pub fn formatting_context_cpp_1645_formatting_context_calculate_fit_content_width() LayoutStub {
	return layout_stub('FormattingContext.cpp:1645 FormattingContext::calculate_fit_content_width')
}

// Translated from Libraries/LibWeb/Layout/FormattingContext.cpp:1664
// Original signature: CSSPixels FormattingContext::calculate_fit_content_height(Layout::Box const& box, AvailableSpace const& available_space) const
// https://drafts.csswg.org/css-sizing-3/#fit-content-size
// If the available space in a given axis is definite,
// equal to clamp(min-content size, stretch-fit size, max-content size)
// (i.e. max(min-content size, min(max-content size, stretch-fit size))).
// When sizing under a min-content constraint, equal to the min-content size.
// Otherwise, equal to the max-content size in that axis.
pub fn formatting_context_cpp_1664_formatting_context_calculate_fit_content_height() LayoutStub {
	return layout_stub('FormattingContext.cpp:1664 FormattingContext::calculate_fit_content_height')
}

// Translated from Libraries/LibWeb/Layout/FormattingContext.cpp:1683
// Original signature: CSSPixels FormattingContext::calculate_min_content_width(Layout::Box const& box) const
// https://www.w3.org/TR/css-sizing-3/#replaced-percentage-min-contribution
// NOTE: If the box is replaced, a cyclic percentage in the value of any max size property or
// preferred size property (width/max-width/height/max-height), is resolved against zero
// when calculating the min-content contribution in the corresponding axis.
// FIXME: If the box also has a preferred aspect ratio, then this min-content contribution is
// floored by any <length-percentage> minimum size from the opposite axis-resolving any
// such percentage against zero-transferred through the preferred aspect ratio.
// Boxes with no children have zero intrinsic width.
pub fn formatting_context_cpp_1683_formatting_context_calculate_min_content_width() LayoutStub {
	return layout_stub('FormattingContext.cpp:1683 FormattingContext::calculate_min_content_width')
}

// Translated from Libraries/LibWeb/Layout/FormattingContext.cpp:1730
// Original signature: CSSPixels FormattingContext::calculate_max_content_width(Layout::Box const& box) const
// Boxes with no children have zero intrinsic width.
pub fn formatting_context_cpp_1730_formatting_context_calculate_max_content_width() LayoutStub {
	return layout_stub('FormattingContext.cpp:1730 FormattingContext::calculate_max_content_width')
}

// Translated from Libraries/LibWeb/Layout/FormattingContext.cpp:1774
// Original signature: CSSPixels FormattingContext::calculate_min_content_height(Layout::Box const& box, CSSPixels width) const
// https://www.w3.org/TR/css-sizing-3/#min-content-block-size
// For block containers, tables, and inline boxes, this is equivalent to the max-content block size.
// Boxes with no children have zero intrinsic height.
pub fn formatting_context_cpp_1774_formatting_context_calculate_min_content_height() LayoutStub {
	return layout_stub('FormattingContext.cpp:1774 FormattingContext::calculate_min_content_height')
}

// Translated from Libraries/LibWeb/Layout/FormattingContext.cpp:1811
// Original signature: CSSPixels FormattingContext::calculate_max_content_height(Layout::Box const& box, CSSPixels width) const
// Boxes with no children have zero intrinsic height.
pub fn formatting_context_cpp_1811_formatting_context_calculate_max_content_height() LayoutStub {
	return layout_stub('FormattingContext.cpp:1811 FormattingContext::calculate_max_content_height')
}

// Translated from Libraries/LibWeb/Layout/FormattingContext.cpp:1844
// Original signature: CSSPixels FormattingContext::calculate_inner_width(Layout::Box const& box, AvailableSize const& available_width, CSS::Size const& width) const
pub fn formatting_context_cpp_1844_formatting_context_calculate_inner_width() LayoutStub {
	return layout_stub('FormattingContext.cpp:1844 FormattingContext::calculate_inner_width')
}

// Translated from Libraries/LibWeb/Layout/FormattingContext.cpp:1873
// Original signature: CSSPixels FormattingContext::calculate_inner_height(Box const& box, AvailableSpace const& available_space, CSS::Size const& height) const
// NOTE: Percentage heights are resolved against the containing block's used height,
// not the available space height. The containing block's height must be definite
// for percentage resolution to work (otherwise should_treat_height_as_auto
// should have returned true and we wouldn't be here).
// NOTE: We only do this when available space height is indefinite. If it's definite,
// we trust that the caller has set it up correctly (e.g., grid/flex items get
// their cell/area size as available space).
// https://quirks.spec.whatwg.org/#the-percentage-height-calculation-quirk
// In quirks mode, walk up to find an ancestor with explicit height or the viewport.
// NOTE: Flex/grid items resolve percentage heights against their container, not via quirk.
pub fn formatting_context_cpp_1873_formatting_context_calculate_inner_height() LayoutStub {
	return layout_stub('FormattingContext.cpp:1873 FormattingContext::calculate_inner_height')
}

// Translated from Libraries/LibWeb/Layout/FormattingContext.cpp:1938
// Original signature: CSSPixels FormattingContext::containing_block_width_for(NodeWithStyleAndBoxModelMetrics const& node) const
pub fn formatting_context_cpp_1938_formatting_context_containing_block_width_for() LayoutStub {
	return layout_stub('FormattingContext.cpp:1938 FormattingContext::containing_block_width_for')
}

// Translated from Libraries/LibWeb/Layout/FormattingContext.cpp:1953
// Original signature: CSSPixels FormattingContext::calculate_stretch_fit_width(Box const& box, AvailableSize const& available_width) const
// https://drafts.csswg.org/css-sizing-3/#stretch-fit-size
// The size a box would take if its outer size filled the available space in the given axis;
// in other words, the stretch fit into the available space, if that is definite.
// Undefined if the available space is indefinite.
pub fn formatting_context_cpp_1953_formatting_context_calculate_stretch_fit_width() LayoutStub {
	return layout_stub('FormattingContext.cpp:1953 FormattingContext::calculate_stretch_fit_width')
}

// Translated from Libraries/LibWeb/Layout/FormattingContext.cpp:1973
// Original signature: CSSPixels FormattingContext::calculate_stretch_fit_height(Box const& box, AvailableSize const& available_height) const
// https://drafts.csswg.org/css-sizing-3/#stretch-fit-size
// The size a box would take if its outer size filled the available space in the given axis;
// in other words, the stretch fit into the available space, if that is definite.
// Undefined if the available space is indefinite.
pub fn formatting_context_cpp_1973_formatting_context_calculate_stretch_fit_height() LayoutStub {
	return layout_stub('FormattingContext.cpp:1973 FormattingContext::calculate_stretch_fit_height')
}

// Translated from Libraries/LibWeb/Layout/FormattingContext.cpp:1988
// Original signature: bool FormattingContext::should_treat_width_as_auto(Box const& box, AvailableSpace const& available_space) const
// https://drafts.csswg.org/css-sizing-3/#cyclic-percentage-contribution
// AD-HOC: If the box has a preferred aspect ratio and an intrinsic keyword for width...
// If the box has no natural height to resolve the aspect ratio, we treat the width as auto.
// If the box has definite height, we can resolve the width through the aspect ratio.
pub fn formatting_context_cpp_1988_formatting_context_should_treat_width_as_auto() LayoutStub {
	return layout_stub('FormattingContext.cpp:1988 FormattingContext::should_treat_width_as_auto')
}

// Translated from Libraries/LibWeb/Layout/FormattingContext.cpp:2015
// Original signature: bool FormattingContext::should_treat_height_as_auto(Box const& box, AvailableSpace const& available_space) const
// https://drafts.csswg.org/css-sizing-3/#cyclic-percentage-contribution
// https://www.w3.org/TR/CSS22/visudet.html#the-height-property
// If the height of the containing block is not specified explicitly (i.e., it depends on
// content height), and this element is not absolutely positioned, the percentage value
// is treated as 'auto'.
// https://quirks.spec.whatwg.org/#the-percentage-height-calculation-quirk
// In quirks mode, percentage heights can resolve even without explicit containing block
// height. The quirk applies to DOM elements only (not anonymous boxes), and excludes
// table-related display types.
// Flex/grid items resolve percentage heights against their container, not via quirk.
// The quirk should not apply inside user agent shadow trees.
// NOTE: Anonymous blocks inherit height definiteness from their containing block.
// However, anonymous table cells are proper containing blocks with their own
// height semantics, so we must not walk past them.
// AD-HOC: If the box has a preferred aspect ratio and an intrinsic keyword for height...
// If the box has no natural width to resolve the aspect ratio, we treat the height as auto.
// If the box has definite width, we can resolve the height through the aspect ratio.
pub fn formatting_context_cpp_2015_formatting_context_should_treat_height_as_auto() LayoutStub {
	return layout_stub('FormattingContext.cpp:2015 FormattingContext::should_treat_height_as_auto')
}

// Translated from Libraries/LibWeb/Layout/FormattingContext.cpp:2087
// Original signature: bool FormattingContext::can_skip_is_anonymous_text_run(Box& box)
pub fn formatting_context_cpp_2087_formatting_context_can_skip_is_anonymous_text_run() LayoutStub {
	return layout_stub('FormattingContext.cpp:2087 FormattingContext::can_skip_is_anonymous_text_run')
}

// Translated from Libraries/LibWeb/Layout/FormattingContext.cpp:2104
// Original signature: CSSPixelRect FormattingContext::absolute_content_rect(Box const& box) const
pub fn formatting_context_cpp_2104_formatting_context_absolute_content_rect() LayoutStub {
	return layout_stub('FormattingContext.cpp:2104 FormattingContext::absolute_content_rect')
}

// Translated from Libraries/LibWeb/Layout/FormattingContext.cpp:2113
// Original signature: Box const* FormattingContext::box_child_to_derive_baseline_from(Box const& box) const
// Find the last in-flow child that has a baseline (either directly via line boxes, or via its descendants).
pub fn formatting_context_cpp_2113_formatting_context_box_child_to_derive_baseline_from() LayoutStub {
	return layout_stub('FormattingContext.cpp:2113 FormattingContext::box_child_to_derive_baseline_from')
}

// Translated from Libraries/LibWeb/Layout/FormattingContext.cpp:2132
// Original signature: CSSPixels FormattingContext::box_baseline(Box const& box) const
// https://drafts.csswg.org/css2/#propdef-vertical-align
// Top: Align the top of the aligned subtree with the top of the line box.
// Middle: Align the vertical midpoint of the box with the baseline of the parent box plus half the x-height of
// the parent.
// Bottom: Align the bottom of the aligned subtree with the bottom of the line box.
// TextTop: Align the top of the box with the top of the parent's content area (see 10.6.1).
// TextBottom: Align the bottom of the box with the bottom of the parent's content area (see 10.6.1).
// The baseline of an 'inline-block' is the baseline of its last line box in the normal flow, unless it has
// either
// no in-flow line boxes or if its 'overflow' property has a computed value other than 'visible', in which case
// the
// baseline is the bottom margin edge.
// NB: This overflow exception only applies to inline-block, not to inline-flex or inline-grid containers, which
// always derive their baselines from their content per CSS Align and the respective Flexbox/Grid specs.
// Derive baseline from block children if the box is flex/grid inside or has visible overflow.
// AD-HOC: We also derive baseline from children for <input> elements. Per the HTML spec, inputs have
// `overflow: clip !important`, so CSS2 says to use bottom margin edge. However, the internal shadow tree
// baseline should determine the control's baseline for proper alignment with adjacent text.
// https://html.spec.whatwg.org/multipage/rendering.html#form-controls
// If none of the children have a baseline set, the bottom margin edge of the box is used.
pub fn formatting_context_cpp_2132_formatting_context_box_baseline() LayoutStub {
	return layout_stub('FormattingContext.cpp:2132 FormattingContext::box_baseline')
}

// Translated from Libraries/LibWeb/Layout/FormattingContext.cpp:2195
// Original signature: [[nodiscard]] static CSSPixelRect margin_box_rect(LayoutState::UsedValues const& used_values)
pub fn formatting_context_cpp_2195_margin_box_rect() LayoutStub {
	return layout_stub('FormattingContext.cpp:2195 margin_box_rect')
}

// Translated from Libraries/LibWeb/Layout/FormattingContext.cpp:2209
// Original signature: CSSPixelRect FormattingContext::content_box_rect(Box const& box) const
pub fn formatting_context_cpp_2209_formatting_context_content_box_rect() LayoutStub {
	return layout_stub('FormattingContext.cpp:2209 FormattingContext::content_box_rect')
}

// Translated from Libraries/LibWeb/Layout/FormattingContext.cpp:2214
// Original signature: CSSPixelRect FormattingContext::content_box_rect(LayoutState::UsedValues const& used_values) const
pub fn formatting_context_cpp_2214_formatting_context_content_box_rect() LayoutStub {
	return layout_stub('FormattingContext.cpp:2214 FormattingContext::content_box_rect')
}

// Translated from Libraries/LibWeb/Layout/FormattingContext.cpp:2219
// Original signature: CSSPixelRect FormattingContext::content_box_rect_in_ancestor_coordinate_space(LayoutState::UsedValues const& used_values, Box const& ancestor_box) const
// If we get here, ancestor_box was not a containing block ancestor of `box`!
pub fn formatting_context_cpp_2219_formatting_context_content_box_rect_in_ancestor_coordinate_space() LayoutStub {
	return layout_stub('FormattingContext.cpp:2219 FormattingContext::content_box_rect_in_ancestor_coordinate_space')
}

// Translated from Libraries/LibWeb/Layout/FormattingContext.cpp:2231
// Original signature: CSSPixelRect FormattingContext::margin_box_rect_in_ancestor_coordinate_space(LayoutState::UsedValues const& used_values, Box const& ancestor_box) const
// If we get here, ancestor_box was not a containing block ancestor of `box`!
pub fn formatting_context_cpp_2231_formatting_context_margin_box_rect_in_ancestor_coordinate_space() LayoutStub {
	return layout_stub('FormattingContext.cpp:2231 FormattingContext::margin_box_rect_in_ancestor_coordinate_space')
}

// Translated from Libraries/LibWeb/Layout/FormattingContext.cpp:2243
// Original signature: CSSPixelRect FormattingContext::margin_box_rect_in_ancestor_coordinate_space(Box const& box, Box const& ancestor_box) const
pub fn formatting_context_cpp_2243_formatting_context_margin_box_rect_in_ancestor_coordinate_space() LayoutStub {
	return layout_stub('FormattingContext.cpp:2243 FormattingContext::margin_box_rect_in_ancestor_coordinate_space')
}

// Translated from Libraries/LibWeb/Layout/FormattingContext.cpp:2248
// Original signature: bool FormattingContext::box_is_sized_as_replaced_element(Box const& box, AvailableSpace const& available_space) const
// When a box has a preferred aspect ratio, its automatic sizes are calculated the same as for a
// replaced element with a natural aspect ratio and no natural size in that axis, see e.g. CSS2 ?10
// and CSS Flexible Box Model Level 1 ?9.2.
// https://www.w3.org/TR/css-sizing-4/#aspect-ratio-automatic
// From CSS2:
// If height and width both have computed values of auto and the element has an intrinsic ratio but no intrinsic
// height or width,
// then the used value of width is undefined in CSS 2.
// However, it is suggested that, if the containing block's width does not itself depend on the replaced
// element's width,
// then the used value of width is calculated from the constraint equation used for block-level, non-replaced
// elements in normal flow.
// AD-HOC: If box has preferred aspect ratio but width and height are not specified, then we should
// size it as a normal box to match other browsers.
pub fn formatting_context_cpp_2248_formatting_context_box_is_sized_as_replaced_element() LayoutStub {
	return layout_stub('FormattingContext.cpp:2248 FormattingContext::box_is_sized_as_replaced_element')
}

// Translated from Libraries/LibWeb/Layout/FormattingContext.cpp:2280
// Original signature: bool FormattingContext::should_treat_max_width_as_none(Box const& box, AvailableSize const& available_width) const
// https://drafts.csswg.org/css-sizing-3/#cyclic-percentage-contribution
pub fn formatting_context_cpp_2280_formatting_context_should_treat_max_width_as_none() LayoutStub {
	return layout_stub('FormattingContext.cpp:2280 FormattingContext::should_treat_max_width_as_none')
}

// Translated from Libraries/LibWeb/Layout/FormattingContext.cpp:2314
// Original signature: bool FormattingContext::should_treat_max_height_as_none(Box const& box, AvailableSize const& available_height) const
// https://www.w3.org/TR/CSS22/visudet.html#min-max-heights
// If the height of the containing block is not specified explicitly (i.e., it depends on content height),
// and this element is not absolutely positioned, the percentage value is treated as '0' (for 'min-height')
// or 'none' (for 'max-height').
pub fn formatting_context_cpp_2314_formatting_context_should_treat_max_height_as_none() LayoutStub {
	return layout_stub('FormattingContext.cpp:2314 FormattingContext::should_treat_max_height_as_none')
}

// ---- BlockFormattingContext.h (44 translated function stubs) ----

// Translated from Libraries/LibWeb/Layout/BlockFormattingContext.h:22
// Original signature: BlockFormattingContext::explicit BlockFormattingContext(LayoutState&, LayoutMode layout_mode, BlockContainer const&, FormattingContext* parent);
pub fn block_formatting_context_h_22_block_formatting_context() LayoutStub {
	return layout_stub('BlockFormattingContext.h:22 BlockFormattingContext')
}

// Translated from Libraries/LibWeb/Layout/BlockFormattingContext.h:23
// Original signature: BlockFormattingContext::~BlockFormattingContext();
pub fn block_formatting_context_h_23_block_formatting_context_destroy_block_formatting_context() LayoutStub {
	return layout_stub('BlockFormattingContext.h:23 BlockFormattingContext::~BlockFormattingContext')
}

// Translated from Libraries/LibWeb/Layout/BlockFormattingContext.h:25
// Original signature: BlockFormattingContext::virtual void run(AvailableSpace const&);
pub fn block_formatting_context_h_25_run() LayoutStub {
	return layout_stub('BlockFormattingContext.h:25 run')
}

// Translated from Libraries/LibWeb/Layout/BlockFormattingContext.h:26
// Original signature: BlockFormattingContext::virtual CSSPixels automatic_content_width() const;
pub fn block_formatting_context_h_26_automatic_content_width() LayoutStub {
	return layout_stub('BlockFormattingContext.h:26 automatic_content_width')
}

// Translated from Libraries/LibWeb/Layout/BlockFormattingContext.h:27
// Original signature: BlockFormattingContext::virtual CSSPixels automatic_content_height() const;
pub fn block_formatting_context_h_27_automatic_content_height() LayoutStub {
	return layout_stub('BlockFormattingContext.h:27 automatic_content_height')
}

// Translated from Libraries/LibWeb/Layout/BlockFormattingContext.h:29
// Original signature: BlockFormattingContext::auto const& left_side_floats() const
pub fn block_formatting_context_h_29_left_side_floats() LayoutStub {
	return layout_stub('BlockFormattingContext.h:29 left_side_floats')
}

// Translated from Libraries/LibWeb/Layout/BlockFormattingContext.h:30
// Original signature: BlockFormattingContext::auto const& right_side_floats() const
pub fn block_formatting_context_h_30_right_side_floats() LayoutStub {
	return layout_stub('BlockFormattingContext.h:30 right_side_floats')
}

// Translated from Libraries/LibWeb/Layout/BlockFormattingContext.h:32
// Original signature: BlockFormattingContext::bool box_should_avoid_floats_because_it_establishes_fc(Box const&);
pub fn block_formatting_context_h_32_box_should_avoid_floats_because_it_establishes_fc() LayoutStub {
	return layout_stub('BlockFormattingContext.h:32 box_should_avoid_floats_because_it_establishes_fc')
}

// Translated from Libraries/LibWeb/Layout/BlockFormattingContext.h:33
// Original signature: BlockFormattingContext::void compute_width(Box const&, AvailableSpace const&);
pub fn block_formatting_context_h_33_compute_width() LayoutStub {
	return layout_stub('BlockFormattingContext.h:33 compute_width')
}

// Translated from Libraries/LibWeb/Layout/BlockFormattingContext.h:34
// Original signature: BlockFormattingContext::void avoid_float_intrusions(Box const&, AvailableSpace const&);
pub fn block_formatting_context_h_34_avoid_float_intrusions() LayoutStub {
	return layout_stub('BlockFormattingContext.h:34 avoid_float_intrusions')
}

// Translated from Libraries/LibWeb/Layout/BlockFormattingContext.h:37
// Original signature: BlockFormattingContext::BlockContainer const& root() const
// https://www.w3.org/TR/css-display/#block-formatting-context-root
pub fn block_formatting_context_h_37_root() LayoutStub {
	return layout_stub('BlockFormattingContext.h:37 root')
}

// Translated from Libraries/LibWeb/Layout/BlockFormattingContext.h:39
// Original signature: BlockFormattingContext::virtual void parent_context_did_dimension_child_root_box();
pub fn block_formatting_context_h_39_parent_context_did_dimension_child_root_box() LayoutStub {
	return layout_stub('BlockFormattingContext.h:39 parent_context_did_dimension_child_root_box')
}

// Translated from Libraries/LibWeb/Layout/BlockFormattingContext.h:41
// Original signature: BlockFormattingContext::void resolve_used_height_if_not_treated_as_auto(Box const&, AvailableSpace const&);
pub fn block_formatting_context_h_41_resolve_used_height_if_not_treated_as_auto() LayoutStub {
	return layout_stub('BlockFormattingContext.h:41 resolve_used_height_if_not_treated_as_auto')
}

// Translated from Libraries/LibWeb/Layout/BlockFormattingContext.h:42
// Original signature: BlockFormattingContext::void resolve_used_height_if_treated_as_auto(Box const&, AvailableSpace const&, FormattingContext const* box_formatting_context = nullptr);
pub fn block_formatting_context_h_42_resolve_used_height_if_treated_as_auto() LayoutStub {
	return layout_stub('BlockFormattingContext.h:42 resolve_used_height_if_treated_as_auto')
}

// Translated from Libraries/LibWeb/Layout/BlockFormattingContext.h:57
// Original signature: BlockFormattingContext::SpaceUsedAndContainingMarginForFloats space_used_and_containing_margin_for_floats(CSSPixels y) const;
pub fn block_formatting_context_h_57_space_used_and_containing_margin_for_floats() LayoutStub {
	return layout_stub('BlockFormattingContext.h:57 space_used_and_containing_margin_for_floats')
}

// Translated from Libraries/LibWeb/Layout/BlockFormattingContext.h:58
// Original signature: BlockFormattingContext::[[nodiscard]] SpaceUsedByFloats intrusion_by_floats_into_box(Box const&, CSSPixels y_in_box) const;
pub fn block_formatting_context_h_58_intrusion_by_floats_into_box() LayoutStub {
	return layout_stub('BlockFormattingContext.h:58 intrusion_by_floats_into_box')
}

// Translated from Libraries/LibWeb/Layout/BlockFormattingContext.h:59
// Original signature: BlockFormattingContext::[[nodiscard]] SpaceUsedByFloats intrusion_by_floats_into_box(LayoutState::UsedValues const&, CSSPixels y_in_box) const;
pub fn block_formatting_context_h_59_intrusion_by_floats_into_box() LayoutStub {
	return layout_stub('BlockFormattingContext.h:59 intrusion_by_floats_into_box')
}

// Translated from Libraries/LibWeb/Layout/BlockFormattingContext.h:61
// Original signature: BlockFormattingContext::virtual CSSPixels greatest_child_width(Box const&) const;
pub fn block_formatting_context_h_61_greatest_child_width() LayoutStub {
	return layout_stub('BlockFormattingContext.h:61 greatest_child_width')
}

// Translated from Libraries/LibWeb/Layout/BlockFormattingContext.h:63
// Original signature: BlockFormattingContext::void layout_floating_box(Box const& child, BlockContainer const& containing_block, AvailableSpace const&, CSSPixels y, LineBuilder* = nullptr);
pub fn block_formatting_context_h_63_layout_floating_box() LayoutStub {
	return layout_stub('BlockFormattingContext.h:63 layout_floating_box')
}

// Translated from Libraries/LibWeb/Layout/BlockFormattingContext.h:65
// Original signature: BlockFormattingContext::void layout_block_level_box(Box const&, BlockContainer const&, CSSPixels& bottom_of_lowest_margin_box, AvailableSpace const&);
pub fn block_formatting_context_h_65_layout_block_level_box() LayoutStub {
	return layout_stub('BlockFormattingContext.h:65 layout_block_level_box')
}

// Translated from Libraries/LibWeb/Layout/BlockFormattingContext.h:67
// Original signature: BlockFormattingContext::void resolve_vertical_box_model_metrics(Box const&, CSSPixels width_of_containing_block);
pub fn block_formatting_context_h_67_resolve_vertical_box_model_metrics() LayoutStub {
	return layout_stub('BlockFormattingContext.h:67 resolve_vertical_box_model_metrics')
}

// Translated from Libraries/LibWeb/Layout/BlockFormattingContext.h:68
// Original signature: BlockFormattingContext::void resolve_horizontal_box_model_metrics(Box const&, CSSPixels width_of_containing_block);
pub fn block_formatting_context_h_68_resolve_horizontal_box_model_metrics() LayoutStub {
	return layout_stub('BlockFormattingContext.h:68 resolve_horizontal_box_model_metrics')
}

// Translated from Libraries/LibWeb/Layout/BlockFormattingContext.h:75
// Original signature: BlockFormattingContext::[[nodiscard]] DidIntroduceClearance clear_floating_boxes(Node const& child_box, Optional<InlineFormattingContext&> inline_formatting_context);
pub fn block_formatting_context_h_75_clear_floating_boxes() LayoutStub {
	return layout_stub('BlockFormattingContext.h:75 clear_floating_boxes')
}

// Translated from Libraries/LibWeb/Layout/BlockFormattingContext.h:77
// Original signature: BlockFormattingContext::void reset_margin_state()
pub fn block_formatting_context_h_77_reset_margin_state() LayoutStub {
	return layout_stub('BlockFormattingContext.h:77 reset_margin_state')
}

// Translated from Libraries/LibWeb/Layout/BlockFormattingContext.h:96
// Original signature: BlockFormattingContext::Optional<FloatingBox&> last_inserted_float()
pub fn block_formatting_context_h_96_last_inserted_float() LayoutStub {
	return layout_stub('BlockFormattingContext.h:96 last_inserted_float')
}

// Translated from Libraries/LibWeb/Layout/BlockFormattingContext.h:99
// Original signature: BlockFormattingContext::CSSPixels compute_auto_height_for_block_level_element(Box const&, AvailableSpace const&);
pub fn block_formatting_context_h_99_compute_auto_height_for_block_level_element() LayoutStub {
	return layout_stub('BlockFormattingContext.h:99 compute_auto_height_for_block_level_element')
}

// Translated from Libraries/LibWeb/Layout/BlockFormattingContext.h:101
// Original signature: BlockFormattingContext::void compute_width_for_floating_box(Box const&, AvailableSpace const&);
pub fn block_formatting_context_h_101_compute_width_for_floating_box() LayoutStub {
	return layout_stub('BlockFormattingContext.h:101 compute_width_for_floating_box')
}

// Translated from Libraries/LibWeb/Layout/BlockFormattingContext.h:103
// Original signature: BlockFormattingContext::void compute_width_for_block_level_replaced_element_in_normal_flow(Box const&, AvailableSpace const&);
pub fn block_formatting_context_h_103_compute_width_for_block_level_replaced_element_in_normal_flow() LayoutStub {
	return layout_stub('BlockFormattingContext.h:103 compute_width_for_block_level_replaced_element_in_normal_flow')
}

// Translated from Libraries/LibWeb/Layout/BlockFormattingContext.h:105
// Original signature: BlockFormattingContext::void layout_viewport(AvailableSpace const&);
pub fn block_formatting_context_h_105_layout_viewport() LayoutStub {
	return layout_stub('BlockFormattingContext.h:105 layout_viewport')
}

// Translated from Libraries/LibWeb/Layout/BlockFormattingContext.h:107
// Original signature: BlockFormattingContext::void layout_block_level_children(BlockContainer const&, AvailableSpace const&);
pub fn block_formatting_context_h_107_layout_block_level_children() LayoutStub {
	return layout_stub('BlockFormattingContext.h:107 layout_block_level_children')
}

// Translated from Libraries/LibWeb/Layout/BlockFormattingContext.h:108
// Original signature: BlockFormattingContext::void layout_inline_children(BlockContainer const&, AvailableSpace const&);
pub fn block_formatting_context_h_108_layout_inline_children() LayoutStub {
	return layout_stub('BlockFormattingContext.h:108 layout_inline_children')
}

// Translated from Libraries/LibWeb/Layout/BlockFormattingContext.h:109
// Original signature: BlockFormattingContext::void layout_fieldset_with_rendered_legend(FieldSetBox const&, AvailableSpace const&);
pub fn block_formatting_context_h_109_layout_fieldset_with_rendered_legend() LayoutStub {
	return layout_stub('BlockFormattingContext.h:109 layout_fieldset_with_rendered_legend')
}

// Translated from Libraries/LibWeb/Layout/BlockFormattingContext.h:111
// Original signature: BlockFormattingContext::void place_block_level_element_in_normal_flow_horizontally(Box const& child_box, AvailableSpace const&);
pub fn block_formatting_context_h_111_place_block_level_element_in_normal_flow_horizontally() LayoutStub {
	return layout_stub('BlockFormattingContext.h:111 place_block_level_element_in_normal_flow_horizontally')
}

// Translated from Libraries/LibWeb/Layout/BlockFormattingContext.h:112
// Original signature: BlockFormattingContext::void place_block_level_element_in_normal_flow_vertically(Box const&, CSSPixels y);
pub fn block_formatting_context_h_112_place_block_level_element_in_normal_flow_vertically() LayoutStub {
	return layout_stub('BlockFormattingContext.h:112 place_block_level_element_in_normal_flow_vertically')
}

// Translated from Libraries/LibWeb/Layout/BlockFormattingContext.h:114
// Original signature: BlockFormattingContext::void ensure_sizes_correct_for_left_offset_calculation(ListItemBox const&);
pub fn block_formatting_context_h_114_ensure_sizes_correct_for_left_offset_calculation() LayoutStub {
	return layout_stub('BlockFormattingContext.h:114 ensure_sizes_correct_for_left_offset_calculation')
}

// Translated from Libraries/LibWeb/Layout/BlockFormattingContext.h:115
// Original signature: BlockFormattingContext::void layout_list_item_marker(ListItemBox const&, CSSPixels const& left_space_before_list_item_elements_formatted);
pub fn block_formatting_context_h_115_layout_list_item_marker() LayoutStub {
	return layout_stub('BlockFormattingContext.h:115 layout_list_item_marker')
}

// Translated from Libraries/LibWeb/Layout/BlockFormattingContext.h:117
// Original signature: BlockFormattingContext::void measure_scrollable_overflow(Box const&, CSSPixels& bottom_edge, CSSPixels& right_edge) const;
pub fn block_formatting_context_h_117_measure_scrollable_overflow() LayoutStub {
	return layout_stub('BlockFormattingContext.h:117 measure_scrollable_overflow')
}

// Translated from Libraries/LibWeb/Layout/BlockFormattingContext.h:120
// Original signature: BlockFormattingContext::Optional<int> determine_used_value_for_column_count(CSSPixels const& U) const;
// https://drafts.csswg.org/css-multicol/#pseudo-algorithm
pub fn block_formatting_context_h_120_determine_used_value_for_column_count() LayoutStub {
	return layout_stub('BlockFormattingContext.h:120 determine_used_value_for_column_count')
}

// Translated from Libraries/LibWeb/Layout/BlockFormattingContext.h:121
// Original signature: BlockFormattingContext::CSSPixels determine_used_value_for_column_width(CSSPixels const& U, int N) const;
pub fn block_formatting_context_h_121_determine_used_value_for_column_width() LayoutStub {
	return layout_stub('BlockFormattingContext.h:121 determine_used_value_for_column_width')
}

// Translated from Libraries/LibWeb/Layout/BlockFormattingContext.h:124
// Original signature: BlockFormattingContext::CSSPixels get_column_width_used_value_for_multicol(CSSPixels const& U) const;
// https://drafts.csswg.org/css-multicol-2/#cw
pub fn block_formatting_context_h_124_get_column_width_used_value_for_multicol() LayoutStub {
	return layout_stub('BlockFormattingContext.h:124 get_column_width_used_value_for_multicol')
}

// Translated from Libraries/LibWeb/Layout/BlockFormattingContext.h:126
// Original signature: BlockFormattingContext::CSSPixels get_column_gap_used_value_for_multicol(CSSPixels const& U) const;
// https://www.w3.org/TR/css-align-3/#column-row-gap
pub fn block_formatting_context_h_126_get_column_gap_used_value_for_multicol() LayoutStub {
	return layout_stub('BlockFormattingContext.h:126 get_column_gap_used_value_for_multicol')
}

// Translated from Libraries/LibWeb/Layout/BlockFormattingContext.h:203
// Original signature: BlockMarginState::bool box_last_in_flow_child_margin_bottom_collapsed() const
pub fn block_formatting_context_h_203_box_last_in_flow_child_margin_bottom_collapsed() LayoutStub {
	return layout_stub('BlockFormattingContext.h:203 box_last_in_flow_child_margin_bottom_collapsed')
}

// Translated from Libraries/LibWeb/Layout/BlockFormattingContext.h:204
// Original signature: BlockMarginState::void set_box_last_in_flow_child_margin_bottom_collapsed(bool v)
pub fn block_formatting_context_h_204_set_box_last_in_flow_child_margin_bottom_collapsed() LayoutStub {
	return layout_stub('BlockFormattingContext.h:204 set_box_last_in_flow_child_margin_bottom_collapsed')
}

// Translated from Libraries/LibWeb/Layout/BlockFormattingContext.h:209
// Original signature: BlockMarginState::Function<void(CSSPixels)> m_block_container_y_position_update_callback;
pub fn block_formatting_context_h_209_void() LayoutStub {
	return layout_stub('BlockFormattingContext.h:209 void')
}

// ---- BlockFormattingContext.cpp (37 translated function stubs) ----

// Translated from Libraries/LibWeb/Layout/BlockFormattingContext.cpp:34
// Original signature: BlockFormattingContext::BlockFormattingContext(LayoutState& state, LayoutMode layout_mode, BlockContainer const& root, FormattingContext* parent) : FormattingContext(Type::Block, layout_mode, state, root, parent)
pub fn block_formatting_context_cpp_34_block_formatting_context_block_formatting_context() LayoutStub {
	return layout_stub('BlockFormattingContext.cpp:34 BlockFormattingContext::BlockFormattingContext')
}

// Translated from Libraries/LibWeb/Layout/BlockFormattingContext.cpp:39
// Original signature: BlockFormattingContext::~BlockFormattingContext()
// HACK: The parent formatting context never notified us after assigning dimensions to our root box.
// Pretend that it did anyway, to make sure absolutely positioned children get laid out.
// FIXME: Get rid of this hack once parent contexts behave properly.
pub fn block_formatting_context_cpp_39_block_formatting_context_destroy_block_formatting_context() LayoutStub {
	return layout_stub('BlockFormattingContext.cpp:39 BlockFormattingContext::~BlockFormattingContext')
}

// Translated from Libraries/LibWeb/Layout/BlockFormattingContext.cpp:49
// Original signature: CSSPixels BlockFormattingContext::automatic_content_width() const
pub fn block_formatting_context_cpp_49_block_formatting_context_automatic_content_width() LayoutStub {
	return layout_stub('BlockFormattingContext.cpp:49 BlockFormattingContext::automatic_content_width')
}

// Translated from Libraries/LibWeb/Layout/BlockFormattingContext.cpp:56
// Original signature: CSSPixels BlockFormattingContext::automatic_content_height() const
pub fn block_formatting_context_cpp_56_block_formatting_context_automatic_content_height() LayoutStub {
	return layout_stub('BlockFormattingContext.cpp:56 BlockFormattingContext::automatic_content_height')
}

// Translated from Libraries/LibWeb/Layout/BlockFormattingContext.cpp:61
// Original signature: static bool margins_collapse_through(Box const& box, LayoutState& state)
// https://drafts.csswg.org/css2/#adjoining-margins
// Two margins are adjoining if and only if:
// - both belong to in-flow block-level boxes that participate in the same block formatting context
// NB: Yes, we're dealing with one and the same box here.
// - no line boxes, no clearance, no padding and no border separate them (Note that certain zero-height line
// boxes
// (see 9.4.2) are ignored for this purpose.)
// NB: Border and padding are handled further down.
// - both belong to vertically-adjacent box edges, i.e. form one of the following pairs:
// - top and bottom margins of a box that does not establish a new block formatting context and that has zero
// computed 'min-height', zero or 'auto' computed 'height', and no in-flow children
// NB: This should take care of the height and min-height constraints.
// ( also see https://github.com/w3c/csswg-drafts/pull/13699#issuecomment-4103045370 for spec ambiguity )
// https://drafts.csswg.org/css-sizing-4/#aspect-ratio-margin-collapse
// FIXME: For the purpose of margin collapsing (CSS 2 ?8.3.1 Collapsing margins), if the block axis is the
// ratio-dependent axis, it is not considered to have a computed block-size of auto.
// AD-HOC: The "and no in-flow children" above is wrong. (see https://github.com/w3c/csswg-drafts/pull/13699 )
pub fn block_formatting_context_cpp_61_margins_collapse_through() LayoutStub {
	return layout_stub('BlockFormattingContext.cpp:61 margins_collapse_through')
}

// Translated from Libraries/LibWeb/Layout/BlockFormattingContext.cpp:100
// Original signature: void BlockFormattingContext::run(AvailableSpace const& available_space)
// https://drafts.csswg.org/css-multicol-2/#the-multi-column-model
// FIXME: Do multi-column layout.
// Fieldsets without a rendered legend skip collapsed margin assignment.
// Assign collapsed margin left after children layout of formatting context to the last child box
pub fn block_formatting_context_cpp_100_block_formatting_context_run() LayoutStub {
	return layout_stub('BlockFormattingContext.cpp:100 BlockFormattingContext::run')
}

// Translated from Libraries/LibWeb/Layout/BlockFormattingContext.cpp:144
// Original signature: void BlockFormattingContext::parent_context_did_dimension_child_root_box()
// Left-side floats: offset_from_edge is from left edge (0) to left content edge of floating_box.
// Right-side floats: offset_from_edge is from right edge (float_containing_block_width) to the left content edge
// of floating_box.
pub fn block_formatting_context_cpp_144_block_formatting_context_parent_context_did_dimension_child_root_box() LayoutStub {
	return layout_stub('BlockFormattingContext.cpp:144 BlockFormattingContext::parent_context_did_dimension_child_root_box')
}

// Translated from Libraries/LibWeb/Layout/BlockFormattingContext.cpp:162
// Original signature: bool BlockFormattingContext::box_should_avoid_floats_because_it_establishes_fc(Box const& box)
// https://drafts.csswg.org/css2/#floats
// The border box of a table, a block-level replaced element, or an element in the normal flow that establishes
// a new block formatting context (such as an element with 'overflow' other than 'visible') must not overlap the
// margin box of any floats in the same block formatting context as the element itself. If necessary,
// implementations should clear the said element by placing it below any preceding floats, but may place it
// adjacent to such floats if there is sufficient space. They may even make the border box of said element
// narrower than defined by section 10.3.3. CSS2 does not define when a UA may put said element next to the
// float or by how much said element may become narrower.
// https://drafts.csswg.org/css-flexbox/#flex-containers
// A flex container establishes a new flex formatting context for its contents. This is the same as establishing
// a block formatting context, except that flex layout is used instead of block layout. For example, floats do
// not intrude into the flex container, and the flex container's margins do not collapse with the margins of its
// contents.
// https://drafts.csswg.org/css-grid/#grid-containers
// A grid container that is not a subgrid establishes an independent grid formatting context for its contents.
// This is the same as establishing an independent block formatting context, except that grid layout is used
// instead of block layout: floats do not intrude into the grid container, and the grid container's margins do
// not collapse with the margins of its contents.
pub fn block_formatting_context_cpp_162_block_formatting_context_box_should_avoid_floats_because_it_establishes() LayoutStub {
	return layout_stub('BlockFormattingContext.cpp:162 BlockFormattingContext::box_should_avoid_floats_because_it_establishes_fc')
}

// Translated from Libraries/LibWeb/Layout/BlockFormattingContext.cpp:190
// Original signature: void BlockFormattingContext::compute_width(Box const& box, AvailableSpace const& available_space)
// Certain formatting contexts do not allow float intrusions, so reduce the available space for them.
// 10.3.6 Floating, replaced elements:
// https://www.w3.org/TR/CSS22/visudet.html#float-replaced-width
// 10.3.5 Floating, non-replaced elements:
// https://www.w3.org/TR/CSS22/visudet.html#float-width
// NOTE: If we are calculating the min-content or max-content width of this box,
// and the width should be treated as auto, then we can simply return here,
// as the preferred width and min/max constraints are irrelevant for intrinsic sizing.
// 10.3.3 Block-level, non-replaced elements in normal flow
// If 'width' is not 'auto' and 'border-left-width' + 'padding-left' + 'width' + 'padding-right' +
// 'border-right-width' (plus any of 'margin-left' or 'margin-right' that are not 'auto') is larger than the
// width of the containing block, then any 'auto' values for 'margin-left' or 'margin-right' are, for the
// following rules, treated as zero.
// 10.3.3 cont'd.
// margin_left.is_auto() && margin_right.is_auto()
// NOTE: Replaced elements had their width calculated independently above.
// We use that width as the input here to ensure that margins get resolved.
// https://html.spec.whatwg.org/multipage/rendering.html#button-layout
// If the computed value of 'inline-size' is 'auto', then the used value is the fit-content inline size.
// 1. The tentative used width is calculated (without 'min-width' and 'max-width')
// 2. The tentative used width is greater than 'max-width', the rules above are applied again,
// but this time using the computed value of 'max-width' as the computed value for 'width'.
// 3. If the resulting width is smaller than 'min-width', the rules above are applied again,
// but this time using the value of 'min-width' as the computed value for 'width'.
pub fn block_formatting_context_cpp_190_block_formatting_context_compute_width() LayoutStub {
	return layout_stub('BlockFormattingContext.cpp:190 BlockFormattingContext::compute_width')
}

// Translated from Libraries/LibWeb/Layout/BlockFormattingContext.cpp:354
// Original signature: void BlockFormattingContext::avoid_float_intrusions(Box const& box, AvailableSpace const& available_space)
// https://drafts.csswg.org/css2/#floats
// If necessary, implementations should clear the said element by placing it below any preceding floats, but may
// place it adjacent to such floats if there is sufficient space.
pub fn block_formatting_context_cpp_354_block_formatting_context_avoid_float_intrusions() LayoutStub {
	return layout_stub('BlockFormattingContext.cpp:354 BlockFormattingContext::avoid_float_intrusions')
}

// Translated from Libraries/LibWeb/Layout/BlockFormattingContext.cpp:393
// Original signature: void BlockFormattingContext::compute_width_for_floating_box(Box const& box, AvailableSpace const& available_space)
// 10.3.5 Floating, non-replaced elements
// If 'margin-left', or 'margin-right' are computed as 'auto', their used value is '0'.
// If 'width' is computed as 'auto', the used value is the "shrink-to-fit" width.
// Find the available width: in this case, this is the width of the containing
// block minus the used values of 'margin-left', 'border-left-width', 'padding-left',
// 'padding-right', 'border-right-width', 'margin-right', and the widths of any relevant scroll bars.
// Then the shrink-to-fit width is: min(max(preferred minimum width, available width), preferred width).
// Fold the formula for shrink-to-fit width for indefinite and max-content available width.
// Fold the formula for shrink-to-fit width for min-content available width.
// 1. The tentative used width is calculated (without 'min-width' and 'max-width')
// 2. The tentative used width is greater than 'max-width', the rules above are applied again,
// but this time using the computed value of 'max-width' as the computed value for 'width'.
// 3. If the resulting width is smaller than 'min-width', the rules above are applied again,
// but this time using the value of 'min-width' as the computed value for 'width'.
pub fn block_formatting_context_cpp_393_block_formatting_context_compute_width_for_floating_box() LayoutStub {
	return layout_stub('BlockFormattingContext.cpp:393 BlockFormattingContext::compute_width_for_floating_box')
}

// Translated from Libraries/LibWeb/Layout/BlockFormattingContext.cpp:466
// Original signature: void BlockFormattingContext::compute_width_for_block_level_replaced_element_in_normal_flow(Box const& box, AvailableSpace const& available_space)
// 10.3.6 Floating, replaced elements
// 10.3.4 Block-level, replaced elements in normal flow
// The used value of 'width' is determined as for inline replaced elements. Then the rules for
// non-replaced block-level elements are applied to determine the margins.
// If 'margin-left', or 'margin-right' are computed as 'auto', their used value is '0'.
pub fn block_formatting_context_cpp_466_block_formatting_context_compute_width_for_block_level_replaced_element() LayoutStub {
	return layout_stub('BlockFormattingContext.cpp:466 BlockFormattingContext::compute_width_for_block_level_replaced_element_in_normal_flow')
}

// Translated from Libraries/LibWeb/Layout/BlockFormattingContext.cpp:493
// Original signature: void BlockFormattingContext::resolve_used_height_if_not_treated_as_auto(Box const& box, AvailableSpace const& available_space)
pub fn block_formatting_context_cpp_493_block_formatting_context_resolve_used_height_if_not_treated_as_auto() LayoutStub {
	return layout_stub('BlockFormattingContext.cpp:493 BlockFormattingContext::resolve_used_height_if_not_treated_as_auto')
}

// Translated from Libraries/LibWeb/Layout/BlockFormattingContext.cpp:518
// Original signature: void BlockFormattingContext::resolve_used_height_if_treated_as_auto(Box const& box, AvailableSpace const& available_space, FormattingContext const* box_formatting_context)
// 3.6. The html element fills the viewport quirk
// https://quirks.spec.whatwg.org/#the-html-element-fills-the-viewport-quirk
// FIXME: Handle vertical writing mode.
// 1. Let margins be sum of the used values of the margin-left and margin-right properties of element
// if element has a vertical writing mode, otherwise let margins be the sum of the used values of
// the margin-top and margin-bottom properties of element.
// 2. Let size be the size of the initial containing block in the block flow direction minus margins.
// 3. Return the bigger value of size and the normal border box size the element would have
// according to the CSS specification.
// NOTE: The height of the root element when affected by this quirk is considered to be definite.
// 3.7. The body element fills the html element quirk
// https://quirks.spec.whatwg.org/#the-body-element-fills-the-html-element-quirk
// The element body must additionally meet the following conditions:
// - The computed value of the 'position' property of element is neither 'absolute' nor 'fixed'.
// - The computed value of the 'float' property of element is 'none'.
// - Element is not an inline-level element.
// - Element is not a multi-column spanning element.
// NON-STANDARD: We don't check column-span since no browser actually excludes it.
// 2. Let size be the size of element's parent element's content box in the block flow direction minus margins.
pub fn block_formatting_context_cpp_518_block_formatting_context_resolve_used_height_if_treated_as_auto() LayoutStub {
	return layout_stub('BlockFormattingContext.cpp:518 BlockFormattingContext::resolve_used_height_if_treated_as_auto')
}

// Translated from Libraries/LibWeb/Layout/BlockFormattingContext.cpp:604
// Original signature: void BlockFormattingContext::layout_inline_children(BlockContainer const& block_container, AvailableSpace const& available_space)
// NOTE: min-width or max-width for boxes with inline children can only be applied after inside layout
// is done and width of box content is known
// https://www.w3.org/TR/css-sizing-3/#sizing-values
// Percentages are resolved against the width/height, as appropriate, of the box's containing block.
pub fn block_formatting_context_cpp_604_block_formatting_context_layout_inline_children() LayoutStub {
	return layout_stub('BlockFormattingContext.cpp:604 BlockFormattingContext::layout_inline_children')
}

// Translated from Libraries/LibWeb/Layout/BlockFormattingContext.cpp:652
// Original signature: CSSPixels BlockFormattingContext::compute_auto_height_for_block_level_element(Box const& box, AvailableSpace const& available_space)
// https://drafts.csswg.org/css-flexbox-1/#algo-main-container
// NOTE: The automatic block size of a block-level flex container is its max-content size.
// https://www.w3.org/TR/css-grid-2/#intrinsic-sizes
// In both inline and block formatting contexts, the grid container's auto block size is its
// max-content size.
// https://www.w3.org/TR/CSS22/visudet.html#normal-block
// 10.6.3 Block-level non-replaced elements in normal flow when 'overflow' computes to 'visible'
// The element's height is the distance from its top content edge to the first applicable of the following:
// 1. the bottom edge of the last line box, if the box establishes a inline formatting context with one or more
// lines
// 2. the bottom edge of the bottom (possibly collapsed) margin of its last in-flow child, if the child's bottom
// margin does not collapse with the element's bottom margin
// 3. the bottom border edge of the last in-flow child whose top margin doesn't collapse with the element's
// bottom margin
// NOTE: Markers are not in-flow, but for list items that contain only floats (or are otherwise empty),
// the marker's line-height determines the list item's height. This ensures proper vertical stacking
// of list items and alignment with their floated content.
// If no in-flow children were found but there's a marker, use the marker's line-height.
// AD-HOC: Contenteditable elements must have a minimum height (line-height) when empty, to remain clickable and
// usable for text input, even though this is not specified.
// See: https://github.com/w3c/editing/issues/70.
// 4. zero, otherwise
pub fn block_formatting_context_cpp_652_block_formatting_context_compute_auto_height_for_block_level_element() LayoutStub {
	return layout_stub('BlockFormattingContext.cpp:652 BlockFormattingContext::compute_auto_height_for_block_level_element')
}

// Translated from Libraries/LibWeb/Layout/BlockFormattingContext.cpp:730
// Original signature: static CSSPixels containing_block_height_to_resolve_percentage_in_quirks_mode(Box const& box, LayoutState const& state)
// https://quirks.spec.whatwg.org/#the-percentage-height-calculation-quirk
// 1. Let element be the nearest ancestor containing block of element, if there is one.
// Otherwise, return the initial containing block.
// 2. If element has a computed value of the display property that is table-cell, then return a
// UA-defined value.
// FIXME: Likely UA-defined value should not be 0.
// 3. If element has a computed value of the height property that is not auto, then return element.
// 4. If element has a computed value of the position property that is absolute, or if element is a
// not a block container or a table wrapper box, then return element.
// 5. Jump to the first step.
pub fn block_formatting_context_cpp_730_containing_block_height_to_resolve_percentage_in_quirks_mode() LayoutStub {
	return layout_stub('BlockFormattingContext.cpp:730 containing_block_height_to_resolve_percentage_in_quirks_mode')
}

// Translated from Libraries/LibWeb/Layout/BlockFormattingContext.cpp:772
// Original signature: void BlockFormattingContext::layout_block_level_box(Box const& box, BlockContainer const& block_container, CSSPixels& bottom_of_lowest_margin_box, AvailableSpace const& available_space)
// FIXME: This is a heuristic approximation. Ideally, originally-inline abspos
// elements would have their static position determined by the IFC that
// laid out the surrounding inline content, but our architecture currently
// routes all abspos elements through the BFC as block-level children.
// When the previous sibling is the anonymous wrapper that contains the
// inline content this element would have been part of, use that wrapper's
// y-offset as a rough approximation of the correct static position.
// NOTE: ListItemMarkerBoxes are placed by their corresponding ListItemBox.
// NOTE: In quirks mode, the html element's height matches the viewport so it can be treated as definite
// NOTE: It is possible to encounter SVGMaskBox nodes while doing layout of formatting context established by
// <foreignObject> with a mask.
// We should skip and let SVGFormattingContext take care of them.
// If first child margin top will collapse with margin-top of containing block then margin-top of child is 0
// https://quirks.spec.whatwg.org/#the-percentage-height-calculation-quirk
// In quirks mode, for the purpose of calculating the height of an element, if the
// computed value of the position property of element is relative or static, the specified value
// for the height property of element is a <percentage>, and element does not have a computed
// value of the display property that is table-row, table-row-group, table-header-group,
// table-footer-group, table-cell or table-caption, the containing block of element must be
// calculated using the following algorithm, aborting on the first step that returns a value:
// NOTE: Flex containers with `auto` height are treated as `max-content`, so we can compute their height early.
// This monster basically means: "a ListItemBox that does not have specified content in the ::marker pseudo-
// element".
// This happens for ::marker with content 'normal'.
// FIXME: We currently so not support ListItemBox-es generated by pseudo-elements. We will need to, eventually.
// Before we insert the children of a list item we need to know the location of the marker.
// If we do not do this then left-floating elements inside the list item will push the marker to the right,
// in some cases even causing it to overlap with the non-floating content of the list.
// We need to ensure that our height and width are final before we calculate our left offset.
// Otherwise, the y at which we calculate the intrusion by floats might be incorrect.
// Margins of elements that establish new formatting contexts do not collapse with their in-flow children
// This box establishes a new formatting context. Pass control to it.
// For boxes with auto height but non-auto min-height, we need to determine if the content height is less than
// min-height. If so, we run layout with min-height as the available height.
// Populate the entire containing block chain: the throwaway BFC may encounter abspos
// elements whose containing block is an ancestor above `box`. We stop when the source
// state lacks an entry, which happens when it is itself a nested throwaway state.
// This box participates in the current block container's flow.
// margin-top of block container can't collapse with it's children if it has non zero border or padding
// margin-top of block container can be updated during children layout hence it's final y position yet to be
// determined
// Tables already set their height during the independent formatting context run. When multi-line text cells are
// involved, using different
// available space here than during the independent formatting context run can result in different line breaks
// and thus a different height.
// Now that our children are formatted we place the ListItemBox with the left space we remembered.
// The marker pseudo-element will be created from a ListItemMarkerBox
// Otherwise, it will be a dealt with as a generic pseudo-element with the content of the ::marker pseudo-
// element.
pub fn block_formatting_context_cpp_772_block_formatting_context_layout_block_level_box() LayoutStub {
	return layout_stub('BlockFormattingContext.cpp:772 BlockFormattingContext::layout_block_level_box')
}

// Translated from Libraries/LibWeb/Layout/BlockFormattingContext.cpp:997
// Original signature: void BlockFormattingContext::layout_block_level_children(BlockContainer const& block_container, AvailableSpace const& available_space)
// NOTE: Min and max constraints are not applied to a box that is being sized as intrinsic because
// according to css-sizing-3 spec:
// The min-content size of a box in each axis is the size it would have if it was a float given an
// auto size in that axis (and no minimum or maximum size in that axis) and if its containing block
// was zero-sized in that axis.
pub fn block_formatting_context_cpp_997_block_formatting_context_layout_block_level_children() LayoutStub {
	return layout_stub('BlockFormattingContext.cpp:997 BlockFormattingContext::layout_block_level_children')
}

// Translated from Libraries/LibWeb/Layout/BlockFormattingContext.cpp:1038
// Original signature: void BlockFormattingContext::layout_fieldset_with_rendered_legend(FieldSetBox const& fieldset_box, AvailableSpace const& available_space)
// https://html.spec.whatwg.org/multipage/rendering.html#the-fieldset-and-legend-elements
// Lay out the legend to determine its dimensions.
// If the computed value of 'inline-size' is 'auto', then the used value is the fit-content inline size.
// The space allocated for the element's border on the block-start side is expected to be the element's
// 'border-block-start-width' or the rendered legend's margin box size in the fieldset's block-flow direction,
// whichever is greater.
// Lay out non-legend children below the legend accommodation.
// The element is expected to be positioned in the block-flow direction such that its border box is centered over
// the border on the block-start side of the fieldset element.
// FIXME: Take writing modes into consideration.
pub fn block_formatting_context_cpp_1038_block_formatting_context_layout_fieldset_with_rendered_legend() LayoutStub {
	return layout_stub('BlockFormattingContext.cpp:1038 BlockFormattingContext::layout_fieldset_with_rendered_legend')
}

// Translated from Libraries/LibWeb/Layout/BlockFormattingContext.cpp:1105
// Original signature: void BlockFormattingContext::resolve_vertical_box_model_metrics(Box const& box, CSSPixels width_of_containing_block)
pub fn block_formatting_context_cpp_1105_block_formatting_context_resolve_vertical_box_model_metrics() LayoutStub {
	return layout_stub('BlockFormattingContext.cpp:1105 BlockFormattingContext::resolve_vertical_box_model_metrics')
}

// Translated from Libraries/LibWeb/Layout/BlockFormattingContext.cpp:1118
// Original signature: void BlockFormattingContext::resolve_horizontal_box_model_metrics(Box const& box, CSSPixels width_of_containing_block)
pub fn block_formatting_context_cpp_1118_block_formatting_context_resolve_horizontal_box_model_metrics() LayoutStub {
	return layout_stub('BlockFormattingContext.cpp:1118 BlockFormattingContext::resolve_horizontal_box_model_metrics')
}

// Translated from Libraries/LibWeb/Layout/BlockFormattingContext.cpp:1131
// Original signature: BlockFormattingContext::DidIntroduceClearance BlockFormattingContext::clear_floating_boxes(Node const& child_box, Optional<InlineFormattingContext&> inline_formatting_context)
// NOTE: Floating boxes are globally relevant within this BFC, *but* their offset coordinates
// are relative to their containing block.
// This means that we have to first convert to a root-space Y coordinate before clearing,
// and then convert back to a local Y coordinate when assigning the cleared offset to
// the `child_box` layout state.
// First, find the lowest margin box edge on this float side and calculate the Y offset just below it.
// Then, convert the clearance Y to a coordinate relative to the containing block of `child_box`.
// FIXME: Honor writing-mode, direction and text-orientation.
pub fn block_formatting_context_cpp_1131_block_formatting_context_clear_floating_boxes() LayoutStub {
	return layout_stub('BlockFormattingContext.cpp:1131 BlockFormattingContext::clear_floating_boxes')
}

// Translated from Libraries/LibWeb/Layout/BlockFormattingContext.cpp:1179
// Original signature: void BlockFormattingContext::place_block_level_element_in_normal_flow_vertically(Box const& child_box, CSSPixels y)
pub fn block_formatting_context_cpp_1179_block_formatting_context_place_block_level_element_in_normal_flow_vert() LayoutStub {
	return layout_stub('BlockFormattingContext.cpp:1179 BlockFormattingContext::place_block_level_element_in_normal_flow_vertically')
}

// Translated from Libraries/LibWeb/Layout/BlockFormattingContext.cpp:1191
// Original signature: void BlockFormattingContext::place_block_level_element_in_normal_flow_horizontally(Box const& child_box, AvailableSpace const& available_space)
// Since this box has a FC, it should avoid floats which means we cannot have its border box overlap with any
// float's margin box. We start off at the right-most border of the floats, and if this box' margin-left is not
// auto, we must overlap that margin with the floats as far as possible.
// All non-anonymous containing blocks that are ancestors of the child box, but are not ancestors of the left
// float box, might have left margins set that overlap with the used float space.
// Subtracting the left margin here because left and right margins need to be swapped when aligning to the right
pub fn block_formatting_context_cpp_1191_block_formatting_context_place_block_level_element_in_normal_flow_hori() LayoutStub {
	return layout_stub('BlockFormattingContext.cpp:1191 BlockFormattingContext::place_block_level_element_in_normal_flow_horizontally')
}

// Translated from Libraries/LibWeb/Layout/BlockFormattingContext.cpp:1235
// Original signature: void BlockFormattingContext::layout_viewport(AvailableSpace const& available_space)
// NOTE: If we are laying out a standalone SVG document, we give it some special treatment:
// The root <svg> container gets the same size as the viewport,
// and we call directly into the SVG layout code from here.
pub fn block_formatting_context_cpp_1235_block_formatting_context_layout_viewport() LayoutStub {
	return layout_stub('BlockFormattingContext.cpp:1235 BlockFormattingContext::layout_viewport')
}

// Translated from Libraries/LibWeb/Layout/BlockFormattingContext.cpp:1254
// Original signature: void BlockFormattingContext::layout_floating_box(Box const& box, BlockContainer const& block_container, AvailableSpace const& available_space, CSSPixels y, LineBuilder* line_builder)
// NOTE: Flex containers with `auto` height are treated as `max-content`, so we can compute their height early.
// First we place the box normally (to get the right y coordinate.)
// If we have a LineBuilder, we're in the middle of inline layout, otherwise this is block layout.
// Then we float it to the left or right.
// This is the first floating box on this side. Go all the way to the edge.
// NOTE: If we're in inline layout, the LineBuilder has already provided the right Y offset.
// In block layout, we adjust by the side's current Y offset here.
// Walk all currently tracked floats on the side we're floating towards.
// We're looking for the innermost preceding float that intersects vertically with `box`.
// We found a preceding float that intersects vertically with the current float.
// Now we need to find out if there's enough inline-axis space to stack them next to each other.
// One of three things happened:
// - This box does not touch another floating box.
// - We ran out of horizontal space on this "float line", and need to break.
// - This box has clearance.
// Either way, we float this box all the way to the edge.
// Also, forget all previous boxes floated to this side while since they're no longer relevant.
// FIXME: It's annoying that we have different behavior for inline vs block here.
// Find a way to unify the behavior so we don't need to branch here.
// NOTE: We don't set the X position here, that happens later, once we know the root block width.
// See parent_context_did_dimension_child_root_box() for that logic.
// Next, float to the left and/or right
// FIXME: Honor writing-mode, direction and text-orientation.
pub fn block_formatting_context_cpp_1254_block_formatting_context_layout_floating_box() LayoutStub {
	return layout_stub('BlockFormattingContext.cpp:1254 BlockFormattingContext::layout_floating_box')
}

// Translated from Libraries/LibWeb/Layout/BlockFormattingContext.cpp:1424
// Original signature: void BlockFormattingContext::ensure_sizes_correct_for_left_offset_calculation(ListItemBox const& list_item_box)
// If an image is used, the marker's dimensions are the same as the image.
// Text markers use text metrics to determine their width; other markers use square dimensions.
// FIXME: Use per-code-point fonts to measure text.
pub fn block_formatting_context_cpp_1424_block_formatting_context_ensure_sizes_correct_for_left_offset_calculat() LayoutStub {
	return layout_stub('BlockFormattingContext.cpp:1424 BlockFormattingContext::ensure_sizes_correct_for_left_offset_calculation')
}

// Translated from Libraries/LibWeb/Layout/BlockFormattingContext.cpp:1454
// Original signature: void BlockFormattingContext::layout_list_item_marker(ListItemBox const& list_item_box, CSSPixels const& left_space_before_list_item_elements_formatted)
// Text markers fit snug against the list item; non-text position themselves at 50% of the font size.
pub fn block_formatting_context_cpp_1454_block_formatting_context_layout_list_item_marker() LayoutStub {
	return layout_stub('BlockFormattingContext.cpp:1454 BlockFormattingContext::layout_list_item_marker')
}

// Translated from Libraries/LibWeb/Layout/BlockFormattingContext.cpp:1486
// Original signature: BlockFormattingContext::SpaceUsedAndContainingMarginForFloats BlockFormattingContext::space_used_and_containing_margin_for_floats(CSSPixels y) const
// NOTE: The floating box is *not* in the final horizontal position yet, but the size and vertical position is
// valid.
pub fn block_formatting_context_cpp_1486_block_formatting_context_space_used_and_containing_margin_for_floats() LayoutStub {
	return layout_stub('BlockFormattingContext.cpp:1486 BlockFormattingContext::space_used_and_containing_margin_for_floats')
}

// Translated from Libraries/LibWeb/Layout/BlockFormattingContext.cpp:1528
// Original signature: FormattingContext::SpaceUsedByFloats BlockFormattingContext::intrusion_by_floats_into_box(Box const& box, CSSPixels y_in_box) const
pub fn block_formatting_context_cpp_1528_block_formatting_context_intrusion_by_floats_into_box() LayoutStub {
	return layout_stub('BlockFormattingContext.cpp:1528 BlockFormattingContext::intrusion_by_floats_into_box')
}

// Translated from Libraries/LibWeb/Layout/BlockFormattingContext.cpp:1533
// Original signature: FormattingContext::SpaceUsedByFloats BlockFormattingContext::intrusion_by_floats_into_box(LayoutState::UsedValues const& box_used_values, CSSPixels y_in_box) const
// NOTE: Floats are relative to the BFC root box, not necessarily the containing block of this IFC.
// If we did not match a right float, the right_total_containing_margin will be 0 (as its never set). Since no
// floats means
// no intrusion we would instead want it to be exactly equal to
// offset_from_containing_block_chain_margins_between_here_and_root.
// Since this is not the case we have to explicitly handle this case.
pub fn block_formatting_context_cpp_1533_block_formatting_context_intrusion_by_floats_into_box() LayoutStub {
	return layout_stub('BlockFormattingContext.cpp:1533 BlockFormattingContext::intrusion_by_floats_into_box')
}

// Translated from Libraries/LibWeb/Layout/BlockFormattingContext.cpp:1562
// Original signature: CSSPixels BlockFormattingContext::greatest_child_width(Box const& box) const
// Similar to FormattingContext::greatest_child_width()
// but this one takes floats into account!
// NOTE: Floats directly affect the automatic size of their containing block, but only indirectly anything above
// in the tree.
pub fn block_formatting_context_cpp_1562_block_formatting_context_greatest_child_width() LayoutStub {
	return layout_stub('BlockFormattingContext.cpp:1562 BlockFormattingContext::greatest_child_width')
}

// Translated from Libraries/LibWeb/Layout/BlockFormattingContext.cpp:1604
// Original signature: Optional<int> BlockFormattingContext::determine_used_value_for_column_count(CSSPixels const& U) const
// https://drafts.csswg.org/css-multicol/#pseudo-algorithm
// The pseudo-algorithm below determines the used values for column-count (N) and column-width (W). There is
// one other variable in the pseudo-algorithm: U is the used width of the multi-column container.
// (01)  if ((column-width = auto) and (column-count = auto)) then
// not a multicol container
// (03)  if column-width = auto then
// (04)      N := column-count
// (05)  else if column-count = auto then
// (06)      N := max(1,
// (07)        floor((U + column-gap)/(column-width + column-gap)))
// (08)  else
// (09)      N := min(column-count, max(1,
// (10)        floor((U + column-gap)/(column-width + column-gap))))
pub fn block_formatting_context_cpp_1604_block_formatting_context_determine_used_value_for_column_count() LayoutStub {
	return layout_stub('BlockFormattingContext.cpp:1604 BlockFormattingContext::determine_used_value_for_column_count')
}

// Translated from Libraries/LibWeb/Layout/BlockFormattingContext.cpp:1634
// Original signature: CSSPixels BlockFormattingContext::determine_used_value_for_column_width(CSSPixels const& U, int N) const
// (11)  W := max(0, (U + column-gap)/N - column-gap)
pub fn block_formatting_context_cpp_1634_block_formatting_context_determine_used_value_for_column_width() LayoutStub {
	return layout_stub('BlockFormattingContext.cpp:1634 BlockFormattingContext::determine_used_value_for_column_width')
}

// Translated from Libraries/LibWeb/Layout/BlockFormattingContext.cpp:1642
// Original signature: CSSPixels BlockFormattingContext::get_column_width_used_value_for_multicol(CSSPixels const& U) const
// https://drafts.csswg.org/css-multicol-2/#cw
// Used values will be clamped to a minimum of '1px'.
pub fn block_formatting_context_cpp_1642_block_formatting_context_get_column_width_used_value_for_multicol() LayoutStub {
	return layout_stub('BlockFormattingContext.cpp:1642 BlockFormattingContext::get_column_width_used_value_for_multicol')
}

// Translated from Libraries/LibWeb/Layout/BlockFormattingContext.cpp:1649
// Original signature: CSSPixels BlockFormattingContext::get_column_gap_used_value_for_multicol(CSSPixels const& U) const
// https://www.w3.org/TR/css-align-3/#column-row-gap
// The 'normal' represents a used value of '1em' on multi-column containers
pub fn block_formatting_context_cpp_1649_block_formatting_context_get_column_gap_used_value_for_multicol() LayoutStub {
	return layout_stub('BlockFormattingContext.cpp:1649 BlockFormattingContext::get_column_gap_used_value_for_multicol')
}

// ---- InlineFormattingContext.h (18 translated function stubs) ----

// Translated from Libraries/LibWeb/Layout/InlineFormattingContext.h:18
// Original signature: InlineFormattingContext::InlineFormattingContext(LayoutState&, LayoutMode, BlockContainer const& containing_block, LayoutState::UsedValues& containing_block_used_values, BlockFormattingContext& parent);
pub fn inline_formatting_context_h_18_inline_formatting_context_inline_formatting_context() LayoutStub {
	return layout_stub('InlineFormattingContext.h:18 InlineFormattingContext::InlineFormattingContext')
}

// Translated from Libraries/LibWeb/Layout/InlineFormattingContext.h:19
// Original signature: InlineFormattingContext::~InlineFormattingContext();
pub fn inline_formatting_context_h_19_inline_formatting_context_destroy_inline_formatting_context() LayoutStub {
	return layout_stub('InlineFormattingContext.h:19 InlineFormattingContext::~InlineFormattingContext')
}

// Translated from Libraries/LibWeb/Layout/InlineFormattingContext.h:21
// Original signature: InlineFormattingContext::BlockFormattingContext& parent();
pub fn inline_formatting_context_h_21_parent() LayoutStub {
	return layout_stub('InlineFormattingContext.h:21 parent')
}

// Translated from Libraries/LibWeb/Layout/InlineFormattingContext.h:22
// Original signature: InlineFormattingContext::BlockFormattingContext const& parent() const;
pub fn inline_formatting_context_h_22_parent() LayoutStub {
	return layout_stub('InlineFormattingContext.h:22 parent')
}

// Translated from Libraries/LibWeb/Layout/InlineFormattingContext.h:24
// Original signature: InlineFormattingContext::BlockContainer const& containing_block() const
pub fn inline_formatting_context_h_24_containing_block() LayoutStub {
	return layout_stub('InlineFormattingContext.h:24 containing_block')
}

// Translated from Libraries/LibWeb/Layout/InlineFormattingContext.h:26
// Original signature: InlineFormattingContext::virtual void run(AvailableSpace const&);
pub fn inline_formatting_context_h_26_run() LayoutStub {
	return layout_stub('InlineFormattingContext.h:26 run')
}

// Translated from Libraries/LibWeb/Layout/InlineFormattingContext.h:27
// Original signature: InlineFormattingContext::virtual CSSPixels automatic_content_height() const;
pub fn inline_formatting_context_h_27_automatic_content_height() LayoutStub {
	return layout_stub('InlineFormattingContext.h:27 automatic_content_height')
}

// Translated from Libraries/LibWeb/Layout/InlineFormattingContext.h:28
// Original signature: InlineFormattingContext::virtual CSSPixels automatic_content_width() const;
pub fn inline_formatting_context_h_28_automatic_content_width() LayoutStub {
	return layout_stub('InlineFormattingContext.h:28 automatic_content_width')
}

// Translated from Libraries/LibWeb/Layout/InlineFormattingContext.h:29
// Original signature: InlineFormattingContext::StaticPositionRect calculate_static_position_rect(Box const&) const;
pub fn inline_formatting_context_h_29_calculate_static_position_rect() LayoutStub {
	return layout_stub('InlineFormattingContext.h:29 calculate_static_position_rect')
}

// Translated from Libraries/LibWeb/Layout/InlineFormattingContext.h:31
// Original signature: InlineFormattingContext::void dimension_box_on_line(Box const&, LayoutMode);
pub fn inline_formatting_context_h_31_dimension_box_on_line() LayoutStub {
	return layout_stub('InlineFormattingContext.h:31 dimension_box_on_line')
}

// Translated from Libraries/LibWeb/Layout/InlineFormattingContext.h:33
// Original signature: InlineFormattingContext::CSSPixels leftmost_inline_offset_at(CSSPixels y) const;
pub fn inline_formatting_context_h_33_leftmost_inline_offset_at() LayoutStub {
	return layout_stub('InlineFormattingContext.h:33 leftmost_inline_offset_at')
}

// Translated from Libraries/LibWeb/Layout/InlineFormattingContext.h:34
// Original signature: InlineFormattingContext::AvailableSize available_space_for_line(CSSPixels y) const;
pub fn inline_formatting_context_h_34_available_space_for_line() LayoutStub {
	return layout_stub('InlineFormattingContext.h:34 available_space_for_line')
}

// Translated from Libraries/LibWeb/Layout/InlineFormattingContext.h:35
// Original signature: InlineFormattingContext::bool any_floats_intrude_at_block_offset(CSSPixels block_offset) const;
pub fn inline_formatting_context_h_35_any_floats_intrude_at_block_offset() LayoutStub {
	return layout_stub('InlineFormattingContext.h:35 any_floats_intrude_at_block_offset')
}

// Translated from Libraries/LibWeb/Layout/InlineFormattingContext.h:36
// Original signature: InlineFormattingContext::bool can_fit_new_line_at_block_offset(CSSPixels block_offset) const;
pub fn inline_formatting_context_h_36_can_fit_new_line_at_block_offset() LayoutStub {
	return layout_stub('InlineFormattingContext.h:36 can_fit_new_line_at_block_offset')
}

// Translated from Libraries/LibWeb/Layout/InlineFormattingContext.h:38
// Original signature: InlineFormattingContext::CSSPixels vertical_float_clearance() const;
pub fn inline_formatting_context_h_38_vertical_float_clearance() LayoutStub {
	return layout_stub('InlineFormattingContext.h:38 vertical_float_clearance')
}

// Translated from Libraries/LibWeb/Layout/InlineFormattingContext.h:39
// Original signature: InlineFormattingContext::void set_vertical_float_clearance(CSSPixels);
pub fn inline_formatting_context_h_39_set_vertical_float_clearance() LayoutStub {
	return layout_stub('InlineFormattingContext.h:39 set_vertical_float_clearance')
}

// Translated from Libraries/LibWeb/Layout/InlineFormattingContext.h:42
// Original signature: InlineFormattingContext::void generate_line_boxes();
pub fn inline_formatting_context_h_42_generate_line_boxes() LayoutStub {
	return layout_stub('InlineFormattingContext.h:42 generate_line_boxes')
}

// Translated from Libraries/LibWeb/Layout/InlineFormattingContext.h:43
// Original signature: InlineFormattingContext::void apply_justification_to_fragments(CSS::TextJustify, LineBox&, bool is_last_line);
pub fn inline_formatting_context_h_43_apply_justification_to_fragments() LayoutStub {
	return layout_stub('InlineFormattingContext.h:43 apply_justification_to_fragments')
}

// ---- InlineFormattingContext.cpp (17 translated function stubs) ----

// Translated from Libraries/LibWeb/Layout/InlineFormattingContext.cpp:19
// Original signature: InlineFormattingContext::InlineFormattingContext( LayoutState& state, LayoutMode layout_mode, BlockContainer const& containing_block, LayoutState::UsedValues& containing_block_used_values, BlockFormattingContext& parent) : FormattingContext(Type::Inline, layout_mode, state, containing_block, &parent) , m_containing_block_used_values(containing_block_used_values)
pub fn inline_formatting_context_cpp_19_inline_formatting_context_inline_formatting_context() LayoutStub {
	return layout_stub('InlineFormattingContext.cpp:19 InlineFormattingContext::InlineFormattingContext')
}

// Translated from Libraries/LibWeb/Layout/InlineFormattingContext.cpp:30
// Original signature: InlineFormattingContext::~InlineFormattingContext() = default;
pub fn inline_formatting_context_cpp_30_inline_formatting_context_destroy_inline_formatting_context() LayoutStub {
	return layout_stub('InlineFormattingContext.cpp:30 InlineFormattingContext::~InlineFormattingContext')
}

// Translated from Libraries/LibWeb/Layout/InlineFormattingContext.cpp:32
// Original signature: BlockFormattingContext& InlineFormattingContext::parent()
pub fn inline_formatting_context_cpp_32_inline_formatting_context_parent() LayoutStub {
	return layout_stub('InlineFormattingContext.cpp:32 InlineFormattingContext::parent')
}

// Translated from Libraries/LibWeb/Layout/InlineFormattingContext.cpp:37
// Original signature: BlockFormattingContext const& InlineFormattingContext::parent() const
pub fn inline_formatting_context_cpp_37_inline_formatting_context_parent() LayoutStub {
	return layout_stub('InlineFormattingContext.cpp:37 InlineFormattingContext::parent')
}

// Translated from Libraries/LibWeb/Layout/InlineFormattingContext.cpp:42
// Original signature: CSSPixels InlineFormattingContext::leftmost_inline_offset_at(CSSPixels y) const
// NOTE: Floats are relative to the BFC root box, not necessarily the containing block of this IFC.
// If there's no float box to take into account, we start at the left edge of the containing block.
// If the left edge of the containing block is to the right of the rightmost left-side float, start placing
// inline
// content at the left edge of the containing block.
// The left edge of the containing block is to the left of the rightmost left-side float.
// We adjust the inline content insertion point by the overlap between the containing block and the float.
pub fn inline_formatting_context_cpp_42_inline_formatting_context_leftmost_inline_offset_at() LayoutStub {
	return layout_stub('InlineFormattingContext.cpp:42 InlineFormattingContext::leftmost_inline_offset_at')
}

// Translated from Libraries/LibWeb/Layout/InlineFormattingContext.cpp:64
// Original signature: AvailableSize InlineFormattingContext::available_space_for_line(CSSPixels y) const
pub fn inline_formatting_context_cpp_64_inline_formatting_context_available_space_for_line() LayoutStub {
	return layout_stub('InlineFormattingContext.cpp:64 InlineFormattingContext::available_space_for_line')
}

// Translated from Libraries/LibWeb/Layout/InlineFormattingContext.cpp:73
// Original signature: CSSPixels InlineFormattingContext::automatic_content_width() const
pub fn inline_formatting_context_cpp_73_inline_formatting_context_automatic_content_width() LayoutStub {
	return layout_stub('InlineFormattingContext.cpp:73 InlineFormattingContext::automatic_content_width')
}

// Translated from Libraries/LibWeb/Layout/InlineFormattingContext.cpp:78
// Original signature: CSSPixels InlineFormattingContext::automatic_content_height() const
pub fn inline_formatting_context_cpp_78_inline_formatting_context_automatic_content_height() LayoutStub {
	return layout_stub('InlineFormattingContext.cpp:78 InlineFormattingContext::automatic_content_height')
}

// Translated from Libraries/LibWeb/Layout/InlineFormattingContext.cpp:83
// Original signature: void InlineFormattingContext::run(AvailableSpace const& available_space)
// NOTE: We ask the parent BFC to calculate the automatic content width of this IFC.
// This ensures that any floated boxes are taken into account.
pub fn inline_formatting_context_cpp_83_inline_formatting_context_run() LayoutStub {
	return layout_stub('InlineFormattingContext.cpp:83 InlineFormattingContext::run')
}

// Translated from Libraries/LibWeb/Layout/InlineFormattingContext.cpp:101
// Original signature: void InlineFormattingContext::dimension_box_on_line(Box const& box, LayoutMode layout_mode)
// Any box that has simple flow inside should have generated line box fragments already.
// NOTE: We can't resolve percentages yet. We'll have to wait until after inner layout.
// NOTE: Flex containers with `auto` height are treated as `max-content`, so we can compute their height early.
// FIXME: (10.6.6) If 'height' is 'auto', the height depends on the element's descendants per 10.6.7.
pub fn inline_formatting_context_cpp_101_inline_formatting_context_dimension_box_on_line() LayoutStub {
	return layout_stub('InlineFormattingContext.cpp:101 InlineFormattingContext::dimension_box_on_line')
}

// Translated from Libraries/LibWeb/Layout/InlineFormattingContext.cpp:201
// Original signature: void InlineFormattingContext::apply_justification_to_fragments(CSS::TextJustify text_justify, LineBox& line_box, bool is_last_line)
// FIXME: These two cases currently fall back to auto, handle them as well.
// https://www.w3.org/TR/css-text-3/#text-align-property
// Unless otherwise specified by text-align-last, the last line before a forced break or the end of the block is
// start-aligned.
// FIXME: Support text-align-last.
// This is the amount that each fragment will be offset by. If a whitespace
// fragment is shorter than the justified space width, it increases to push
// subsequent fragments, and decreases to pull them back otherwise.
pub fn inline_formatting_context_cpp_201_inline_formatting_context_apply_justification_to_fragments() LayoutStub {
	return layout_stub('InlineFormattingContext.cpp:201 InlineFormattingContext::apply_justification_to_fragments')
}

// Translated from Libraries/LibWeb/Layout/InlineFormattingContext.cpp:247
// Original signature: void InlineFormattingContext::generate_line_boxes()
// NOTE: When we ignore collapsible whitespace chunks at the start of a line,
// we have to remember how much start margin, border and padding that chunk had
// in the inline axis, so that we can add it to the first non-whitespace chunk.
// Ignore collapsible whitespace chunks at the start of line, and if the last fragment already ends in
// whitespace.
// Calculation of static position for absolute boxes is delayed until trailing whitespaces are removed.
// Even if this introduces clearance, we do NOT reset the margin state, because that is clearance
// between floats and does not contribute to the height of the Inline Formatting Context.
// If we're in a whitespace-collapsing context, we can simply check the flag.
// In whitespace-preserving contexts (white-space: pre*), we have to check manually.
// If whitespace caused us to break, don't put it on the next line.
// Record that the previous line has trailing whitespace for text selection.
// We may need to do an ellipsis if the text is too long for the container
// NOTE: We compute whether we need to truncate the text with an ellipsis based on the width of the
// text node EXCLUSIVE of trailing collapsible whitespace, this is because that trailing
// collapsible whitespace is removed later when we trim the line-boxes anyway.
// Note that this relies on the assumption that this text node is the last in this linebox (as
// there is only one text-node per line box when we have text-wrap: nowrap)
// Do the ellipsis
pub fn inline_formatting_context_cpp_247_inline_formatting_context_generate_line_boxes() LayoutStub {
	return layout_stub('InlineFormattingContext.cpp:247 InlineFormattingContext::generate_line_boxes')
}

// Translated from Libraries/LibWeb/Layout/InlineFormattingContext.cpp:471
// Original signature: bool InlineFormattingContext::any_floats_intrude_at_block_offset(CSSPixels block_offset) const
// FIXME: Respect inline direction.
pub fn inline_formatting_context_cpp_471_inline_formatting_context_any_floats_intrude_at_block_offset() LayoutStub {
	return layout_stub('InlineFormattingContext.cpp:471 InlineFormattingContext::any_floats_intrude_at_block_offset')
}

// Translated from Libraries/LibWeb/Layout/InlineFormattingContext.cpp:480
// Original signature: bool InlineFormattingContext::can_fit_new_line_at_block_offset(CSSPixels block_offset) const
// FIXME: Respect inline direction.
pub fn inline_formatting_context_cpp_480_inline_formatting_context_can_fit_new_line_at_block_offset() LayoutStub {
	return layout_stub('InlineFormattingContext.cpp:480 InlineFormattingContext::can_fit_new_line_at_block_offset')
}

// Translated from Libraries/LibWeb/Layout/InlineFormattingContext.cpp:507
// Original signature: CSSPixels InlineFormattingContext::vertical_float_clearance() const
pub fn inline_formatting_context_cpp_507_inline_formatting_context_vertical_float_clearance() LayoutStub {
	return layout_stub('InlineFormattingContext.cpp:507 InlineFormattingContext::vertical_float_clearance')
}

// Translated from Libraries/LibWeb/Layout/InlineFormattingContext.cpp:512
// Original signature: void InlineFormattingContext::set_vertical_float_clearance(CSSPixels vertical_float_clearance)
pub fn inline_formatting_context_cpp_512_inline_formatting_context_set_vertical_float_clearance() LayoutStub {
	return layout_stub('InlineFormattingContext.cpp:512 InlineFormattingContext::set_vertical_float_clearance')
}

// Translated from Libraries/LibWeb/Layout/InlineFormattingContext.cpp:517
// Original signature: StaticPositionRect InlineFormattingContext::calculate_static_position_rect(Box const& box) const
// We're calculating the position for an absolutely positioned box with a previous sibling in an IFC.
// We need to position the box...
// ...below the last fragment of this sibling, if the display-outside value (before box type transformation) is
// block.
// ...at the top right corner of the last fragment of this sibling otherwise.
// Display-outside value is block => position below
// Display-outside value is not block => position to the right
pub fn inline_formatting_context_cpp_517_inline_formatting_context_calculate_static_position_rect() LayoutStub {
	return layout_stub('InlineFormattingContext.cpp:517 InlineFormattingContext::calculate_static_position_rect')
}

// ---- FlexFormattingContext.h (101 translated function stubs) ----

// Translated from Libraries/LibWeb/Layout/FlexFormattingContext.h:16
// Original signature: FlexFormattingContext::FlexFormattingContext(LayoutState&, LayoutMode, Box const& flex_container, FormattingContext* parent);
pub fn flex_formatting_context_h_16_flex_formatting_context_flex_formatting_context() LayoutStub {
	return layout_stub('FlexFormattingContext.h:16 FlexFormattingContext::FlexFormattingContext')
}

// Translated from Libraries/LibWeb/Layout/FlexFormattingContext.h:17
// Original signature: FlexFormattingContext::~FlexFormattingContext();
pub fn flex_formatting_context_h_17_flex_formatting_context_destroy_flex_formatting_context() LayoutStub {
	return layout_stub('FlexFormattingContext.h:17 FlexFormattingContext::~FlexFormattingContext')
}

// Translated from Libraries/LibWeb/Layout/FlexFormattingContext.h:19
// Original signature: FlexFormattingContext::virtual bool inhibits_floating() const
pub fn flex_formatting_context_h_19_inhibits_floating() LayoutStub {
	return layout_stub('FlexFormattingContext.h:19 inhibits_floating')
}

// Translated from Libraries/LibWeb/Layout/FlexFormattingContext.h:21
// Original signature: FlexFormattingContext::virtual void run(AvailableSpace const&);
pub fn flex_formatting_context_h_21_run() LayoutStub {
	return layout_stub('FlexFormattingContext.h:21 run')
}

// Translated from Libraries/LibWeb/Layout/FlexFormattingContext.h:22
// Original signature: FlexFormattingContext::virtual CSSPixels automatic_content_width() const;
pub fn flex_formatting_context_h_22_automatic_content_width() LayoutStub {
	return layout_stub('FlexFormattingContext.h:22 automatic_content_width')
}

// Translated from Libraries/LibWeb/Layout/FlexFormattingContext.h:23
// Original signature: FlexFormattingContext::virtual CSSPixels automatic_content_height() const;
pub fn flex_formatting_context_h_23_automatic_content_height() LayoutStub {
	return layout_stub('FlexFormattingContext.h:23 automatic_content_height')
}

// Translated from Libraries/LibWeb/Layout/FlexFormattingContext.h:25
// Original signature: FlexFormattingContext::Box const& flex_container() const
pub fn flex_formatting_context_h_25_flex_container() LayoutStub {
	return layout_stub('FlexFormattingContext.h:25 flex_container')
}

// Translated from Libraries/LibWeb/Layout/FlexFormattingContext.h:27
// Original signature: FlexFormattingContext::StaticPositionRect calculate_static_position_rect(Box const&) const;
pub fn flex_formatting_context_h_27_calculate_static_position_rect() LayoutStub {
	return layout_stub('FlexFormattingContext.h:27 calculate_static_position_rect')
}

// Translated from Libraries/LibWeb/Layout/FlexFormattingContext.h:30
// Original signature: FlexFormattingContext::[[nodiscard]] bool should_treat_main_size_as_auto(Box const&) const;
pub fn flex_formatting_context_h_30_should_treat_main_size_as_auto() LayoutStub {
	return layout_stub('FlexFormattingContext.h:30 should_treat_main_size_as_auto')
}

// Translated from Libraries/LibWeb/Layout/FlexFormattingContext.h:31
// Original signature: FlexFormattingContext::[[nodiscard]] bool should_treat_cross_size_as_auto(Box const&) const;
pub fn flex_formatting_context_h_31_should_treat_cross_size_as_auto() LayoutStub {
	return layout_stub('FlexFormattingContext.h:31 should_treat_cross_size_as_auto')
}

// Translated from Libraries/LibWeb/Layout/FlexFormattingContext.h:33
// Original signature: FlexFormattingContext::[[nodiscard]] bool should_treat_main_max_size_as_none(Box const&) const;
pub fn flex_formatting_context_h_33_should_treat_main_max_size_as_none() LayoutStub {
	return layout_stub('FlexFormattingContext.h:33 should_treat_main_max_size_as_none')
}

// Translated from Libraries/LibWeb/Layout/FlexFormattingContext.h:34
// Original signature: FlexFormattingContext::[[nodiscard]] bool should_treat_cross_max_size_as_none(Box const&) const;
pub fn flex_formatting_context_h_34_should_treat_cross_max_size_as_none() LayoutStub {
	return layout_stub('FlexFormattingContext.h:34 should_treat_cross_max_size_as_none')
}

// Translated from Libraries/LibWeb/Layout/FlexFormattingContext.h:36
// Original signature: FlexFormattingContext::[[nodiscard]] CSSPixels adjust_main_size_through_aspect_ratio_for_cross_size_min_max_constraints(Box const&, CSSPixels main_size, CSS::Size const& min_cross_size, CSS::Size const& max_cross_size) const;
pub fn flex_formatting_context_h_36_adjust_main_size_through_aspect_ratio_for_cross_size_min_max_constraints() LayoutStub {
	return layout_stub('FlexFormattingContext.h:36 adjust_main_size_through_aspect_ratio_for_cross_size_min_max_constraints')
}

// Translated from Libraries/LibWeb/Layout/FlexFormattingContext.h:37
// Original signature: FlexFormattingContext::[[nodiscard]] CSSPixels adjust_cross_size_through_aspect_ratio_for_main_size_min_max_constraints(Box const&, CSSPixels cross_size, CSS::Size const& min_main_size, CSS::Size const& max_main_size) const;
pub fn flex_formatting_context_h_37_adjust_cross_size_through_aspect_ratio_for_main_size_min_max_constraints() LayoutStub {
	return layout_stub('FlexFormattingContext.h:37 adjust_cross_size_through_aspect_ratio_for_main_size_min_max_constraints')
}

// Translated from Libraries/LibWeb/Layout/FlexFormattingContext.h:39
// Original signature: FlexFormattingContext::[[nodiscard]] CSSPixels calculate_main_size_from_cross_size_and_aspect_ratio(CSSPixels cross_size, CSSPixelFraction aspect_ratio) const;
pub fn flex_formatting_context_h_39_calculate_main_size_from_cross_size_and_aspect_ratio() LayoutStub {
	return layout_stub('FlexFormattingContext.h:39 calculate_main_size_from_cross_size_and_aspect_ratio')
}

// Translated from Libraries/LibWeb/Layout/FlexFormattingContext.h:40
// Original signature: FlexFormattingContext::[[nodiscard]] CSSPixels calculate_cross_size_from_main_size_and_aspect_ratio(CSSPixels main_size, CSSPixelFraction aspect_ratio) const;
pub fn flex_formatting_context_h_40_calculate_cross_size_from_main_size_and_aspect_ratio() LayoutStub {
	return layout_stub('FlexFormattingContext.h:40 calculate_cross_size_from_main_size_and_aspect_ratio')
}

// Translated from Libraries/LibWeb/Layout/FlexFormattingContext.h:42
// Original signature: FlexFormattingContext::void dump_items() const;
pub fn flex_formatting_context_h_42_dump_items() LayoutStub {
	return layout_stub('FlexFormattingContext.h:42 dump_items')
}

// Translated from Libraries/LibWeb/Layout/FlexFormattingContext.h:65
// Original signature: FlexItem::CSSPixels hypothetical_cross_size_with_margins()
pub fn flex_formatting_context_h_65_hypothetical_cross_size_with_margins() LayoutStub {
	return layout_stub('FlexFormattingContext.h:65 hypothetical_cross_size_with_margins')
}

// Translated from Libraries/LibWeb/Layout/FlexFormattingContext.h:119
// Original signature: FlexLine::double sum_of_flex_factor_of_unfrozen_items() const;
pub fn flex_formatting_context_h_119_sum_of_flex_factor_of_unfrozen_items() LayoutStub {
	return layout_stub('FlexFormattingContext.h:119 sum_of_flex_factor_of_unfrozen_items')
}

// Translated from Libraries/LibWeb/Layout/FlexFormattingContext.h:120
// Original signature: FlexLine::double sum_of_scaled_flex_shrink_factor_of_unfrozen_items() const;
pub fn flex_formatting_context_h_120_sum_of_scaled_flex_shrink_factor_of_unfrozen_items() LayoutStub {
	return layout_stub('FlexFormattingContext.h:120 sum_of_scaled_flex_shrink_factor_of_unfrozen_items')
}

// Translated from Libraries/LibWeb/Layout/FlexFormattingContext.h:123
// Original signature: FlexFormattingContext::CSSPixels main_gap() const;
pub fn flex_formatting_context_h_123_main_gap() LayoutStub {
	return layout_stub('FlexFormattingContext.h:123 main_gap')
}

// Translated from Libraries/LibWeb/Layout/FlexFormattingContext.h:124
// Original signature: FlexFormattingContext::CSSPixels cross_gap() const;
pub fn flex_formatting_context_h_124_cross_gap() LayoutStub {
	return layout_stub('FlexFormattingContext.h:124 cross_gap')
}

// Translated from Libraries/LibWeb/Layout/FlexFormattingContext.h:125
// Original signature: FlexFormattingContext::[[nodiscard]] bool has_definite_main_size(LayoutState::UsedValues const&) const;
pub fn flex_formatting_context_h_125_has_definite_main_size() LayoutStub {
	return layout_stub('FlexFormattingContext.h:125 has_definite_main_size')
}

// Translated from Libraries/LibWeb/Layout/FlexFormattingContext.h:126
// Original signature: FlexFormattingContext::[[nodiscard]] bool has_definite_cross_size(LayoutState::UsedValues const&) const;
pub fn flex_formatting_context_h_126_has_definite_cross_size() LayoutStub {
	return layout_stub('FlexFormattingContext.h:126 has_definite_cross_size')
}

// Translated from Libraries/LibWeb/Layout/FlexFormattingContext.h:127
// Original signature: FlexFormattingContext::[[nodiscard]] bool has_definite_main_size(FlexItem const& item) const
pub fn flex_formatting_context_h_127_has_definite_main_size() LayoutStub {
	return layout_stub('FlexFormattingContext.h:127 has_definite_main_size')
}

// Translated from Libraries/LibWeb/Layout/FlexFormattingContext.h:128
// Original signature: FlexFormattingContext::[[nodiscard]] bool has_definite_cross_size(FlexItem const& item) const
pub fn flex_formatting_context_h_128_has_definite_cross_size() LayoutStub {
	return layout_stub('FlexFormattingContext.h:128 has_definite_cross_size')
}

// Translated from Libraries/LibWeb/Layout/FlexFormattingContext.h:130
// Original signature: FlexFormattingContext::[[nodiscard]] CSSPixels inner_main_size(LayoutState::UsedValues const&) const;
pub fn flex_formatting_context_h_130_inner_main_size() LayoutStub {
	return layout_stub('FlexFormattingContext.h:130 inner_main_size')
}

// Translated from Libraries/LibWeb/Layout/FlexFormattingContext.h:131
// Original signature: FlexFormattingContext::[[nodiscard]] CSSPixels inner_cross_size(LayoutState::UsedValues const&) const;
pub fn flex_formatting_context_h_131_inner_cross_size() LayoutStub {
	return layout_stub('FlexFormattingContext.h:131 inner_cross_size')
}

// Translated from Libraries/LibWeb/Layout/FlexFormattingContext.h:132
// Original signature: FlexFormattingContext::[[nodiscard]] CSSPixels inner_main_size(FlexItem const& item) const
pub fn flex_formatting_context_h_132_inner_main_size() LayoutStub {
	return layout_stub('FlexFormattingContext.h:132 inner_main_size')
}

// Translated from Libraries/LibWeb/Layout/FlexFormattingContext.h:133
// Original signature: FlexFormattingContext::[[nodiscard]] CSSPixels inner_cross_size(FlexItem const& item) const
pub fn flex_formatting_context_h_133_inner_cross_size() LayoutStub {
	return layout_stub('FlexFormattingContext.h:133 inner_cross_size')
}

// Translated from Libraries/LibWeb/Layout/FlexFormattingContext.h:134
// Original signature: FlexFormattingContext::bool has_main_min_size(Box const&) const;
pub fn flex_formatting_context_h_134_has_main_min_size() LayoutStub {
	return layout_stub('FlexFormattingContext.h:134 has_main_min_size')
}

// Translated from Libraries/LibWeb/Layout/FlexFormattingContext.h:135
// Original signature: FlexFormattingContext::bool has_cross_min_size(Box const&) const;
pub fn flex_formatting_context_h_135_has_cross_min_size() LayoutStub {
	return layout_stub('FlexFormattingContext.h:135 has_cross_min_size')
}

// Translated from Libraries/LibWeb/Layout/FlexFormattingContext.h:136
// Original signature: FlexFormattingContext::CSSPixels specified_main_max_size(FlexItem const&) const;
pub fn flex_formatting_context_h_136_specified_main_max_size() LayoutStub {
	return layout_stub('FlexFormattingContext.h:136 specified_main_max_size')
}

// Translated from Libraries/LibWeb/Layout/FlexFormattingContext.h:137
// Original signature: FlexFormattingContext::CSSPixels specified_cross_max_size(FlexItem const&) const;
pub fn flex_formatting_context_h_137_specified_cross_max_size() LayoutStub {
	return layout_stub('FlexFormattingContext.h:137 specified_cross_max_size')
}

// Translated from Libraries/LibWeb/Layout/FlexFormattingContext.h:138
// Original signature: FlexFormattingContext::bool is_cross_auto(Box const&) const;
pub fn flex_formatting_context_h_138_is_cross_auto() LayoutStub {
	return layout_stub('FlexFormattingContext.h:138 is_cross_auto')
}

// Translated from Libraries/LibWeb/Layout/FlexFormattingContext.h:139
// Original signature: FlexFormattingContext::CSSPixels specified_main_min_size(FlexItem const&) const;
pub fn flex_formatting_context_h_139_specified_main_min_size() LayoutStub {
	return layout_stub('FlexFormattingContext.h:139 specified_main_min_size')
}

// Translated from Libraries/LibWeb/Layout/FlexFormattingContext.h:140
// Original signature: FlexFormattingContext::CSSPixels specified_cross_min_size(FlexItem const&) const;
pub fn flex_formatting_context_h_140_specified_cross_min_size() LayoutStub {
	return layout_stub('FlexFormattingContext.h:140 specified_cross_min_size')
}

// Translated from Libraries/LibWeb/Layout/FlexFormattingContext.h:141
// Original signature: FlexFormattingContext::CSSPixels calculate_inner_flex_container_cross_min_size() const;
pub fn flex_formatting_context_h_141_calculate_inner_flex_container_cross_min_size() LayoutStub {
	return layout_stub('FlexFormattingContext.h:141 calculate_inner_flex_container_cross_min_size')
}

// Translated from Libraries/LibWeb/Layout/FlexFormattingContext.h:142
// Original signature: FlexFormattingContext::CSSPixels calculate_inner_flex_container_cross_max_size() const;
pub fn flex_formatting_context_h_142_calculate_inner_flex_container_cross_max_size() LayoutStub {
	return layout_stub('FlexFormattingContext.h:142 calculate_inner_flex_container_cross_max_size')
}

// Translated from Libraries/LibWeb/Layout/FlexFormattingContext.h:143
// Original signature: FlexFormattingContext::bool has_main_max_size(Box const&) const;
pub fn flex_formatting_context_h_143_has_main_max_size() LayoutStub {
	return layout_stub('FlexFormattingContext.h:143 has_main_max_size')
}

// Translated from Libraries/LibWeb/Layout/FlexFormattingContext.h:144
// Original signature: FlexFormattingContext::bool has_cross_max_size(Box const&) const;
pub fn flex_formatting_context_h_144_has_cross_max_size() LayoutStub {
	return layout_stub('FlexFormattingContext.h:144 has_cross_max_size')
}

// Translated from Libraries/LibWeb/Layout/FlexFormattingContext.h:145
// Original signature: FlexFormattingContext::CSSPixels automatic_minimum_size(FlexItem const&) const;
pub fn flex_formatting_context_h_145_automatic_minimum_size() LayoutStub {
	return layout_stub('FlexFormattingContext.h:145 automatic_minimum_size')
}

// Translated from Libraries/LibWeb/Layout/FlexFormattingContext.h:146
// Original signature: FlexFormattingContext::CSSPixels content_based_minimum_size(FlexItem const&) const;
pub fn flex_formatting_context_h_146_content_based_minimum_size() LayoutStub {
	return layout_stub('FlexFormattingContext.h:146 content_based_minimum_size')
}

// Translated from Libraries/LibWeb/Layout/FlexFormattingContext.h:147
// Original signature: FlexFormattingContext::Optional<CSSPixels> specified_size_suggestion(FlexItem const&) const;
pub fn flex_formatting_context_h_147_specified_size_suggestion() LayoutStub {
	return layout_stub('FlexFormattingContext.h:147 specified_size_suggestion')
}

// Translated from Libraries/LibWeb/Layout/FlexFormattingContext.h:148
// Original signature: FlexFormattingContext::Optional<CSSPixels> transferred_size_suggestion(FlexItem const&) const;
pub fn flex_formatting_context_h_148_transferred_size_suggestion() LayoutStub {
	return layout_stub('FlexFormattingContext.h:148 transferred_size_suggestion')
}

// Translated from Libraries/LibWeb/Layout/FlexFormattingContext.h:149
// Original signature: FlexFormattingContext::CSSPixels content_size_suggestion(FlexItem const&) const;
pub fn flex_formatting_context_h_149_content_size_suggestion() LayoutStub {
	return layout_stub('FlexFormattingContext.h:149 content_size_suggestion')
}

// Translated from Libraries/LibWeb/Layout/FlexFormattingContext.h:150
// Original signature: FlexFormattingContext::CSS::Size const& computed_main_size(Box const&) const;
pub fn flex_formatting_context_h_150_computed_main_size() LayoutStub {
	return layout_stub('FlexFormattingContext.h:150 computed_main_size')
}

// Translated from Libraries/LibWeb/Layout/FlexFormattingContext.h:151
// Original signature: FlexFormattingContext::CSS::Size const& computed_main_min_size(Box const&) const;
pub fn flex_formatting_context_h_151_computed_main_min_size() LayoutStub {
	return layout_stub('FlexFormattingContext.h:151 computed_main_min_size')
}

// Translated from Libraries/LibWeb/Layout/FlexFormattingContext.h:152
// Original signature: FlexFormattingContext::CSS::Size const& computed_main_max_size(Box const&) const;
pub fn flex_formatting_context_h_152_computed_main_max_size() LayoutStub {
	return layout_stub('FlexFormattingContext.h:152 computed_main_max_size')
}

// Translated from Libraries/LibWeb/Layout/FlexFormattingContext.h:153
// Original signature: FlexFormattingContext::CSS::Size const& computed_cross_size(Box const&) const;
pub fn flex_formatting_context_h_153_computed_cross_size() LayoutStub {
	return layout_stub('FlexFormattingContext.h:153 computed_cross_size')
}

// Translated from Libraries/LibWeb/Layout/FlexFormattingContext.h:154
// Original signature: FlexFormattingContext::CSS::Size const& computed_cross_min_size(Box const&) const;
pub fn flex_formatting_context_h_154_computed_cross_min_size() LayoutStub {
	return layout_stub('FlexFormattingContext.h:154 computed_cross_min_size')
}

// Translated from Libraries/LibWeb/Layout/FlexFormattingContext.h:155
// Original signature: FlexFormattingContext::CSS::Size const& computed_cross_max_size(Box const&) const;
pub fn flex_formatting_context_h_155_computed_cross_max_size() LayoutStub {
	return layout_stub('FlexFormattingContext.h:155 computed_cross_max_size')
}

// Translated from Libraries/LibWeb/Layout/FlexFormattingContext.h:157
// Original signature: FlexFormattingContext::CSSPixels get_pixel_width(FlexItem const&, CSS::Size const&) const;
pub fn flex_formatting_context_h_157_get_pixel_width() LayoutStub {
	return layout_stub('FlexFormattingContext.h:157 get_pixel_width')
}

// Translated from Libraries/LibWeb/Layout/FlexFormattingContext.h:158
// Original signature: FlexFormattingContext::CSSPixels get_pixel_height(FlexItem const&, CSS::Size const&) const;
pub fn flex_formatting_context_h_158_get_pixel_height() LayoutStub {
	return layout_stub('FlexFormattingContext.h:158 get_pixel_height')
}

// Translated from Libraries/LibWeb/Layout/FlexFormattingContext.h:160
// Original signature: FlexFormattingContext::bool flex_item_is_stretched(FlexItem const&) const;
pub fn flex_formatting_context_h_160_flex_item_is_stretched() LayoutStub {
	return layout_stub('FlexFormattingContext.h:160 flex_item_is_stretched')
}

// Translated from Libraries/LibWeb/Layout/FlexFormattingContext.h:162
// Original signature: FlexFormattingContext::void set_main_size(Box const&, CSSPixels size);
pub fn flex_formatting_context_h_162_set_main_size() LayoutStub {
	return layout_stub('FlexFormattingContext.h:162 set_main_size')
}

// Translated from Libraries/LibWeb/Layout/FlexFormattingContext.h:163
// Original signature: FlexFormattingContext::void set_cross_size(Box const&, CSSPixels size);
pub fn flex_formatting_context_h_163_set_cross_size() LayoutStub {
	return layout_stub('FlexFormattingContext.h:163 set_cross_size')
}

// Translated from Libraries/LibWeb/Layout/FlexFormattingContext.h:164
// Original signature: FlexFormattingContext::void set_main_size(FlexItem&, CSSPixels size);
pub fn flex_formatting_context_h_164_set_main_size() LayoutStub {
	return layout_stub('FlexFormattingContext.h:164 set_main_size')
}

// Translated from Libraries/LibWeb/Layout/FlexFormattingContext.h:165
// Original signature: FlexFormattingContext::void set_cross_size(FlexItem&, CSSPixels size);
pub fn flex_formatting_context_h_165_set_cross_size() LayoutStub {
	return layout_stub('FlexFormattingContext.h:165 set_cross_size')
}

// Translated from Libraries/LibWeb/Layout/FlexFormattingContext.h:166
// Original signature: FlexFormattingContext::void set_offset(FlexItem&, CSSPixels main_offset, CSSPixels cross_offset);
pub fn flex_formatting_context_h_166_set_offset() LayoutStub {
	return layout_stub('FlexFormattingContext.h:166 set_offset')
}

// Translated from Libraries/LibWeb/Layout/FlexFormattingContext.h:168
// Original signature: FlexFormattingContext::void set_main_axis_first_margin(FlexItem&, CSSPixels margin);
pub fn flex_formatting_context_h_168_set_main_axis_first_margin() LayoutStub {
	return layout_stub('FlexFormattingContext.h:168 set_main_axis_first_margin')
}

// Translated from Libraries/LibWeb/Layout/FlexFormattingContext.h:169
// Original signature: FlexFormattingContext::void set_main_axis_second_margin(FlexItem&, CSSPixels margin);
pub fn flex_formatting_context_h_169_set_main_axis_second_margin() LayoutStub {
	return layout_stub('FlexFormattingContext.h:169 set_main_axis_second_margin')
}

// Translated from Libraries/LibWeb/Layout/FlexFormattingContext.h:171
// Original signature: FlexFormattingContext::void set_has_definite_main_size(FlexItem&);
pub fn flex_formatting_context_h_171_set_has_definite_main_size() LayoutStub {
	return layout_stub('FlexFormattingContext.h:171 set_has_definite_main_size')
}

// Translated from Libraries/LibWeb/Layout/FlexFormattingContext.h:172
// Original signature: FlexFormattingContext::void set_has_definite_cross_size(FlexItem&);
pub fn flex_formatting_context_h_172_set_has_definite_cross_size() LayoutStub {
	return layout_stub('FlexFormattingContext.h:172 set_has_definite_cross_size')
}

// Translated from Libraries/LibWeb/Layout/FlexFormattingContext.h:174
// Original signature: FlexFormattingContext::void copy_dimensions_from_flex_items_to_boxes();
pub fn flex_formatting_context_h_174_copy_dimensions_from_flex_items_to_boxes() LayoutStub {
	return layout_stub('FlexFormattingContext.h:174 copy_dimensions_from_flex_items_to_boxes')
}

// Translated from Libraries/LibWeb/Layout/FlexFormattingContext.h:176
// Original signature: FlexFormattingContext::void generate_anonymous_flex_items();
pub fn flex_formatting_context_h_176_generate_anonymous_flex_items() LayoutStub {
	return layout_stub('FlexFormattingContext.h:176 generate_anonymous_flex_items')
}

// Translated from Libraries/LibWeb/Layout/FlexFormattingContext.h:178
// Original signature: FlexFormattingContext::void determine_available_space_for_items(AvailableSpace const&);
pub fn flex_formatting_context_h_178_determine_available_space_for_items() LayoutStub {
	return layout_stub('FlexFormattingContext.h:178 determine_available_space_for_items')
}

// Translated from Libraries/LibWeb/Layout/FlexFormattingContext.h:180
// Original signature: FlexFormattingContext::void determine_flex_base_size(FlexItem&);
pub fn flex_formatting_context_h_180_determine_flex_base_size() LayoutStub {
	return layout_stub('FlexFormattingContext.h:180 determine_flex_base_size')
}

// Translated from Libraries/LibWeb/Layout/FlexFormattingContext.h:182
// Original signature: FlexFormattingContext::void collect_flex_items_into_flex_lines();
pub fn flex_formatting_context_h_182_collect_flex_items_into_flex_lines() LayoutStub {
	return layout_stub('FlexFormattingContext.h:182 collect_flex_items_into_flex_lines')
}

// Translated from Libraries/LibWeb/Layout/FlexFormattingContext.h:184
// Original signature: FlexFormattingContext::void resolve_flexible_lengths();
pub fn flex_formatting_context_h_184_resolve_flexible_lengths() LayoutStub {
	return layout_stub('FlexFormattingContext.h:184 resolve_flexible_lengths')
}

// Translated from Libraries/LibWeb/Layout/FlexFormattingContext.h:185
// Original signature: FlexFormattingContext::void resolve_flexible_lengths_for_line(FlexLine&);
pub fn flex_formatting_context_h_185_resolve_flexible_lengths_for_line() LayoutStub {
	return layout_stub('FlexFormattingContext.h:185 resolve_flexible_lengths_for_line')
}

// Translated from Libraries/LibWeb/Layout/FlexFormattingContext.h:187
// Original signature: FlexFormattingContext::void resolve_cross_axis_auto_margins();
pub fn flex_formatting_context_h_187_resolve_cross_axis_auto_margins() LayoutStub {
	return layout_stub('FlexFormattingContext.h:187 resolve_cross_axis_auto_margins')
}

// Translated from Libraries/LibWeb/Layout/FlexFormattingContext.h:189
// Original signature: FlexFormattingContext::void determine_hypothetical_cross_size_of_item(FlexItem&);
pub fn flex_formatting_context_h_189_determine_hypothetical_cross_size_of_item() LayoutStub {
	return layout_stub('FlexFormattingContext.h:189 determine_hypothetical_cross_size_of_item')
}

// Translated from Libraries/LibWeb/Layout/FlexFormattingContext.h:191
// Original signature: FlexFormattingContext::void calculate_cross_size_of_each_flex_line();
pub fn flex_formatting_context_h_191_calculate_cross_size_of_each_flex_line() LayoutStub {
	return layout_stub('FlexFormattingContext.h:191 calculate_cross_size_of_each_flex_line')
}

// Translated from Libraries/LibWeb/Layout/FlexFormattingContext.h:193
// Original signature: FlexFormattingContext::void handle_align_content_stretch();
pub fn flex_formatting_context_h_193_handle_align_content_stretch() LayoutStub {
	return layout_stub('FlexFormattingContext.h:193 handle_align_content_stretch')
}

// Translated from Libraries/LibWeb/Layout/FlexFormattingContext.h:195
// Original signature: FlexFormattingContext::CSS::AlignItems alignment_for_item(Box const&) const;
pub fn flex_formatting_context_h_195_alignment_for_item() LayoutStub {
	return layout_stub('FlexFormattingContext.h:195 alignment_for_item')
}

// Translated from Libraries/LibWeb/Layout/FlexFormattingContext.h:197
// Original signature: FlexFormattingContext::void determine_used_cross_size_of_each_flex_item();
pub fn flex_formatting_context_h_197_determine_used_cross_size_of_each_flex_item() LayoutStub {
	return layout_stub('FlexFormattingContext.h:197 determine_used_cross_size_of_each_flex_item')
}

// Translated from Libraries/LibWeb/Layout/FlexFormattingContext.h:199
// Original signature: FlexFormattingContext::void distribute_any_remaining_free_space();
pub fn flex_formatting_context_h_199_distribute_any_remaining_free_space() LayoutStub {
	return layout_stub('FlexFormattingContext.h:199 distribute_any_remaining_free_space')
}

// Translated from Libraries/LibWeb/Layout/FlexFormattingContext.h:201
// Original signature: FlexFormattingContext::void align_all_flex_items_along_the_cross_axis();
pub fn flex_formatting_context_h_201_align_all_flex_items_along_the_cross_axis() LayoutStub {
	return layout_stub('FlexFormattingContext.h:201 align_all_flex_items_along_the_cross_axis')
}

// Translated from Libraries/LibWeb/Layout/FlexFormattingContext.h:203
// Original signature: FlexFormattingContext::void resolve_baseline_aligned_items();
pub fn flex_formatting_context_h_203_resolve_baseline_aligned_items() LayoutStub {
	return layout_stub('FlexFormattingContext.h:203 resolve_baseline_aligned_items')
}

// Translated from Libraries/LibWeb/Layout/FlexFormattingContext.h:205
// Original signature: FlexFormattingContext::void align_all_flex_lines();
pub fn flex_formatting_context_h_205_align_all_flex_lines() LayoutStub {
	return layout_stub('FlexFormattingContext.h:205 align_all_flex_lines')
}

// Translated from Libraries/LibWeb/Layout/FlexFormattingContext.h:207
// Original signature: FlexFormattingContext::bool is_row_layout() const
pub fn flex_formatting_context_h_207_is_row_layout() LayoutStub {
	return layout_stub('FlexFormattingContext.h:207 is_row_layout')
}

// Translated from Libraries/LibWeb/Layout/FlexFormattingContext.h:208
// Original signature: FlexFormattingContext::bool is_single_line() const
pub fn flex_formatting_context_h_208_is_single_line() LayoutStub {
	return layout_stub('FlexFormattingContext.h:208 is_single_line')
}

// Translated from Libraries/LibWeb/Layout/FlexFormattingContext.h:209
// Original signature: FlexFormattingContext::bool is_direction_reverse() const;
pub fn flex_formatting_context_h_209_is_direction_reverse() LayoutStub {
	return layout_stub('FlexFormattingContext.h:209 is_direction_reverse')
}

// Translated from Libraries/LibWeb/Layout/FlexFormattingContext.h:210
// Original signature: FlexFormattingContext::void populate_specified_margins(FlexItem&, CSS::FlexDirection) const;
pub fn flex_formatting_context_h_210_populate_specified_margins() LayoutStub {
	return layout_stub('FlexFormattingContext.h:210 populate_specified_margins')
}

// Translated from Libraries/LibWeb/Layout/FlexFormattingContext.h:212
// Original signature: FlexFormattingContext::void determine_intrinsic_size_of_flex_container();
pub fn flex_formatting_context_h_212_determine_intrinsic_size_of_flex_container() LayoutStub {
	return layout_stub('FlexFormattingContext.h:212 determine_intrinsic_size_of_flex_container')
}

// Translated from Libraries/LibWeb/Layout/FlexFormattingContext.h:213
// Original signature: FlexFormattingContext::[[nodiscard]] CSSPixels calculate_intrinsic_main_size_of_flex_container();
pub fn flex_formatting_context_h_213_calculate_intrinsic_main_size_of_flex_container() LayoutStub {
	return layout_stub('FlexFormattingContext.h:213 calculate_intrinsic_main_size_of_flex_container')
}

// Translated from Libraries/LibWeb/Layout/FlexFormattingContext.h:214
// Original signature: FlexFormattingContext::[[nodiscard]] CSSPixels calculate_intrinsic_cross_size_of_flex_container();
pub fn flex_formatting_context_h_214_calculate_intrinsic_cross_size_of_flex_container() LayoutStub {
	return layout_stub('FlexFormattingContext.h:214 calculate_intrinsic_cross_size_of_flex_container')
}

// Translated from Libraries/LibWeb/Layout/FlexFormattingContext.h:216
// Original signature: FlexFormattingContext::[[nodiscard]] CSSPixels calculate_cross_min_content_contribution(FlexItem const&, bool resolve_percentage_min_max_sizes) const;
pub fn flex_formatting_context_h_216_calculate_cross_min_content_contribution() LayoutStub {
	return layout_stub('FlexFormattingContext.h:216 calculate_cross_min_content_contribution')
}

// Translated from Libraries/LibWeb/Layout/FlexFormattingContext.h:217
// Original signature: FlexFormattingContext::[[nodiscard]] CSSPixels calculate_cross_max_content_contribution(FlexItem const&, bool resolve_percentage_min_max_sizes) const;
pub fn flex_formatting_context_h_217_calculate_cross_max_content_contribution() LayoutStub {
	return layout_stub('FlexFormattingContext.h:217 calculate_cross_max_content_contribution')
}

// Translated from Libraries/LibWeb/Layout/FlexFormattingContext.h:218
// Original signature: FlexFormattingContext::[[nodiscard]] CSSPixels calculate_main_min_content_contribution(FlexItem const&) const;
pub fn flex_formatting_context_h_218_calculate_main_min_content_contribution() LayoutStub {
	return layout_stub('FlexFormattingContext.h:218 calculate_main_min_content_contribution')
}

// Translated from Libraries/LibWeb/Layout/FlexFormattingContext.h:219
// Original signature: FlexFormattingContext::[[nodiscard]] CSSPixels calculate_main_max_content_contribution(FlexItem const&) const;
pub fn flex_formatting_context_h_219_calculate_main_max_content_contribution() LayoutStub {
	return layout_stub('FlexFormattingContext.h:219 calculate_main_max_content_contribution')
}

// Translated from Libraries/LibWeb/Layout/FlexFormattingContext.h:221
// Original signature: FlexFormattingContext::[[nodiscard]] CSSPixels calculate_min_content_main_size(FlexItem const&) const;
pub fn flex_formatting_context_h_221_calculate_min_content_main_size() LayoutStub {
	return layout_stub('FlexFormattingContext.h:221 calculate_min_content_main_size')
}

// Translated from Libraries/LibWeb/Layout/FlexFormattingContext.h:222
// Original signature: FlexFormattingContext::[[nodiscard]] CSSPixels calculate_max_content_main_size(FlexItem const&) const;
pub fn flex_formatting_context_h_222_calculate_max_content_main_size() LayoutStub {
	return layout_stub('FlexFormattingContext.h:222 calculate_max_content_main_size')
}

// Translated from Libraries/LibWeb/Layout/FlexFormattingContext.h:223
// Original signature: FlexFormattingContext::[[nodiscard]] CSSPixels calculate_min_content_cross_size(FlexItem const&) const;
pub fn flex_formatting_context_h_223_calculate_min_content_cross_size() LayoutStub {
	return layout_stub('FlexFormattingContext.h:223 calculate_min_content_cross_size')
}

// Translated from Libraries/LibWeb/Layout/FlexFormattingContext.h:224
// Original signature: FlexFormattingContext::[[nodiscard]] CSSPixels calculate_max_content_cross_size(FlexItem const&) const;
pub fn flex_formatting_context_h_224_calculate_max_content_cross_size() LayoutStub {
	return layout_stub('FlexFormattingContext.h:224 calculate_max_content_cross_size')
}

// Translated from Libraries/LibWeb/Layout/FlexFormattingContext.h:226
// Original signature: FlexFormattingContext::[[nodiscard]] CSSPixels calculate_fit_content_main_size(FlexItem const&) const;
pub fn flex_formatting_context_h_226_calculate_fit_content_main_size() LayoutStub {
	return layout_stub('FlexFormattingContext.h:226 calculate_fit_content_main_size')
}

// Translated from Libraries/LibWeb/Layout/FlexFormattingContext.h:227
// Original signature: FlexFormattingContext::[[nodiscard]] CSSPixels calculate_fit_content_cross_size(FlexItem const&) const;
pub fn flex_formatting_context_h_227_calculate_fit_content_cross_size() LayoutStub {
	return layout_stub('FlexFormattingContext.h:227 calculate_fit_content_cross_size')
}

// Translated from Libraries/LibWeb/Layout/FlexFormattingContext.h:229
// Original signature: FlexFormattingContext::[[nodiscard]] CSSPixels calculate_width_to_use_when_determining_intrinsic_height_of_item(FlexItem const&) const;
pub fn flex_formatting_context_h_229_calculate_width_to_use_when_determining_intrinsic_height_of_item() LayoutStub {
	return layout_stub('FlexFormattingContext.h:229 calculate_width_to_use_when_determining_intrinsic_height_of_item')
}

// Translated from Libraries/LibWeb/Layout/FlexFormattingContext.h:231
// Original signature: FlexFormattingContext::virtual void parent_context_did_dimension_child_root_box();
pub fn flex_formatting_context_h_231_parent_context_did_dimension_child_root_box() LayoutStub {
	return layout_stub('FlexFormattingContext.h:231 parent_context_did_dimension_child_root_box')
}

// Translated from Libraries/LibWeb/Layout/FlexFormattingContext.h:233
// Original signature: FlexFormattingContext::CSS::FlexBasis used_flex_basis_for_item(FlexItem const&) const;
pub fn flex_formatting_context_h_233_used_flex_basis_for_item() LayoutStub {
	return layout_stub('FlexFormattingContext.h:233 used_flex_basis_for_item')
}

// ---- FlexFormattingContext.cpp (93 translated function stubs) ----

// Translated from Libraries/LibWeb/Layout/FlexFormattingContext.cpp:19
// Original signature: CSSPixels FlexFormattingContext::get_pixel_width(FlexItem const& item, CSS::Size const& size) const
pub fn flex_formatting_context_cpp_19_flex_formatting_context_get_pixel_width() LayoutStub {
	return layout_stub('FlexFormattingContext.cpp:19 FlexFormattingContext::get_pixel_width')
}

// Translated from Libraries/LibWeb/Layout/FlexFormattingContext.cpp:24
// Original signature: CSSPixels FlexFormattingContext::get_pixel_height(FlexItem const& item, CSS::Size const& size) const
// NOTE: In a row layout, after we've determined the main size, we use that as the available width for any
// intrinsic sizing layout needed to resolve the height.
pub fn flex_formatting_context_cpp_24_flex_formatting_context_get_pixel_height() LayoutStub {
	return layout_stub('FlexFormattingContext.cpp:24 FlexFormattingContext::get_pixel_height')
}

// Translated from Libraries/LibWeb/Layout/FlexFormattingContext.cpp:37
// Original signature: FlexFormattingContext::FlexFormattingContext(LayoutState& state, LayoutMode layout_mode, Box const& flex_container, FormattingContext* parent) : FormattingContext(Type::Flex, layout_mode, state, flex_container, parent) , m_flex_container_state(m_state.get_mutable(flex_container)) , m_flex_direction(flex_container.computed_values().flex_direction())
pub fn flex_formatting_context_cpp_37_flex_formatting_context_flex_formatting_context() LayoutStub {
	return layout_stub('FlexFormattingContext.cpp:37 FlexFormattingContext::FlexFormattingContext')
}

// Translated from Libraries/LibWeb/Layout/FlexFormattingContext.cpp:44
// Original signature: FlexFormattingContext::~FlexFormattingContext() = default;
pub fn flex_formatting_context_cpp_44_flex_formatting_context_destroy_flex_formatting_context() LayoutStub {
	return layout_stub('FlexFormattingContext.cpp:44 FlexFormattingContext::~FlexFormattingContext')
}

// Translated from Libraries/LibWeb/Layout/FlexFormattingContext.cpp:46
// Original signature: CSSPixels FlexFormattingContext::automatic_content_width() const
pub fn flex_formatting_context_cpp_46_flex_formatting_context_automatic_content_width() LayoutStub {
	return layout_stub('FlexFormattingContext.cpp:46 FlexFormattingContext::automatic_content_width')
}

// Translated from Libraries/LibWeb/Layout/FlexFormattingContext.cpp:51
// Original signature: CSSPixels FlexFormattingContext::automatic_content_height() const
pub fn flex_formatting_context_cpp_51_flex_formatting_context_automatic_content_height() LayoutStub {
	return layout_stub('FlexFormattingContext.cpp:51 FlexFormattingContext::automatic_content_height')
}

// Translated from Libraries/LibWeb/Layout/FlexFormattingContext.cpp:56
// Original signature: void FlexFormattingContext::run(AvailableSpace const& available_space)
// This implements https://www.w3.org/TR/css-flexbox-1/#layout-algorithm
// OPTIMIZATION: If we're in intrinsic sizing layout, but the flex container is not the
// box being measured, we can skip everything here.
// The parent formatting context has already figured out our size anyway.
// 1. Generate anonymous flex items
// 2. Determine the available main and cross space for the flex items
// https://drafts.csswg.org/css-flexbox-1/#definite-sizes
// 3. If a single-line flex container has a definite cross size,
// the automatic preferred outer cross size of any stretched flex items is the flex container's inner cross size
// (clamped to the flex item's min and max cross size) and is considered definite.
// 3. Determine the flex base size and hypothetical main size of each item
// OPTIMIZATION: We try to avoid calculating the "automatic minimum size" if possible,
// since it may require expensive intrinsic sizing layout.
// If this is a single-line flex container and the sum of flex bases sizes
// won't exceed the available space in the main axis, we know the layout
// algorithm won't have to shrink anything, thus not needing the minimum size.
// OPTIMIZATION: Skip automatic_minimum_size calculation when we can prove it won't affect the result.
// We compute:
// hypothetical_main_size = clamp(flex_base_size, automatic_minimum_size, max_size)
// For non-replaced elements without aspect ratio, the spec defines:
// automatic_minimum_size = content_based_minimum_size
// content_based_minimum_size = min(content_size_suggestion, specified_size_suggestion)
// This means:
// automatic_minimum_size <= specified_size_suggestion (when specified exists).
// .              So if flex_base_size == specified_size_suggestion, then automatic_minimum_size <=
// flex_base_size,
// and the lower clamp becomes a no-op. We can substitute 0 and get the same result.
// .              We exclude: scroll containers (content can overflow, different behavior), replaced elements
// (use
// different formula with intrinsic sizes), and items with aspect-ratio (transferred_size_suggestion
// complicates the calculation).
// The hypothetical main size is the item's flex base size clamped according to its used min and max main sizes
// (and flooring the content box size at zero).
// We're computing intrinsic size for the flex container. This happens at the end of run().
// 4. Determine the main size of the flex container
// Determine the main size of the flex container using the rules of the formatting context in which it
// participates.
// NOTE: The automatic block size of a block-level flex container is its max-content size.
// NOTE: We've already handled this in the parent formatting context.
// Specifically, all formatting contexts will have assigned width & height to the flex container
// before this formatting context runs.
// 5. Collect flex items into flex lines:
// After this step no additional items are to be added to flex_lines or any of its items!
// 6. Resolve the flexible lengths
// Cross Size Determination
// 7. Determine the hypothetical cross size of each item
// 8. Calculate the cross size of each flex line.
// 9. Handle 'align-content: stretch'.
// 10. Collapse visibility:collapse items.
// FIXME: This
// 11. Determine the used cross size of each flex item.
// 12. Distribute any remaining free space.
// 13. Resolve cross-axis auto margins.
// 14. Align all flex items along the cross-axis
// 15. Determine the flex container's used cross size
// NOTE: This is handled by the parent formatting context.
// 4. Once the cross size of a flex line has been determined,
// the cross sizes of items in auto-sized flex containers are also considered definite for the purpose of layout.
// 16. Align all flex lines (per align-content)
// We're computing intrinsic size for the flex container.
// This is a normal layout (not intrinsic sizing).
// AD-HOC: Finally, layout the inside of all flex items.
pub fn flex_formatting_context_cpp_56_flex_formatting_context_run() LayoutStub {
	return layout_stub('FlexFormattingContext.cpp:56 FlexFormattingContext::run')
}

// Translated from Libraries/LibWeb/Layout/FlexFormattingContext.cpp:246
// Original signature: void FlexFormattingContext::parent_context_did_dimension_child_root_box()
pub fn flex_formatting_context_cpp_246_flex_formatting_context_parent_context_did_dimension_child_root_box() LayoutStub {
	return layout_stub('FlexFormattingContext.cpp:246 FlexFormattingContext::parent_context_did_dimension_child_root_box')
}

// Translated from Libraries/LibWeb/Layout/FlexFormattingContext.cpp:262
// Original signature: bool FlexFormattingContext::is_direction_reverse() const
// https://www.w3.org/TR/css-flexbox-1/#flex-direction-property
pub fn flex_formatting_context_cpp_262_flex_formatting_context_is_direction_reverse() LayoutStub {
	return layout_stub('FlexFormattingContext.cpp:262 FlexFormattingContext::is_direction_reverse')
}

// Translated from Libraries/LibWeb/Layout/FlexFormattingContext.cpp:274
// Original signature: void FlexFormattingContext::populate_specified_margins(FlexItem& item, CSS::FlexDirection flex_direction) const
// FIXME: This should also take reverse-ness into account
pub fn flex_formatting_context_cpp_274_flex_formatting_context_populate_specified_margins() LayoutStub {
	return layout_stub('FlexFormattingContext.cpp:274 FlexFormattingContext::populate_specified_margins')
}

// Translated from Libraries/LibWeb/Layout/FlexFormattingContext.cpp:328
// Original signature: void FlexFormattingContext::generate_anonymous_flex_items()
// https://www.w3.org/TR/css-flexbox-1/#flex-items
// More like, sift through the already generated items.
// After this step no items are to be added or removed from flex_items!
// It holds every item we need to consider and there should be nothing in the following
// calculations that could change that.
// This is particularly important since we take references to the items stored in flex_items
// later, whose addresses won't be stable if we added or removed any items.
// Skip any "out-of-flow" children
pub fn flex_formatting_context_cpp_328_flex_formatting_context_generate_anonymous_flex_items() LayoutStub {
	return layout_stub('FlexFormattingContext.cpp:328 FlexFormattingContext::generate_anonymous_flex_items')
}

// Translated from Libraries/LibWeb/Layout/FlexFormattingContext.cpp:375
// Original signature: bool FlexFormattingContext::has_definite_main_size(LayoutState::UsedValues const& used_values) const
pub fn flex_formatting_context_cpp_375_flex_formatting_context_has_definite_main_size() LayoutStub {
	return layout_stub('FlexFormattingContext.cpp:375 FlexFormattingContext::has_definite_main_size')
}

// Translated from Libraries/LibWeb/Layout/FlexFormattingContext.cpp:380
// Original signature: CSSPixels FlexFormattingContext::inner_main_size(LayoutState::UsedValues const& used_values) const
pub fn flex_formatting_context_cpp_380_flex_formatting_context_inner_main_size() LayoutStub {
	return layout_stub('FlexFormattingContext.cpp:380 FlexFormattingContext::inner_main_size')
}

// Translated from Libraries/LibWeb/Layout/FlexFormattingContext.cpp:385
// Original signature: CSSPixels FlexFormattingContext::inner_cross_size(LayoutState::UsedValues const& used_values) const
pub fn flex_formatting_context_cpp_385_flex_formatting_context_inner_cross_size() LayoutStub {
	return layout_stub('FlexFormattingContext.cpp:385 FlexFormattingContext::inner_cross_size')
}

// Translated from Libraries/LibWeb/Layout/FlexFormattingContext.cpp:390
// Original signature: bool FlexFormattingContext::has_main_min_size(Box const& box) const
pub fn flex_formatting_context_cpp_390_flex_formatting_context_has_main_min_size() LayoutStub {
	return layout_stub('FlexFormattingContext.cpp:390 FlexFormattingContext::has_main_min_size')
}

// Translated from Libraries/LibWeb/Layout/FlexFormattingContext.cpp:396
// Original signature: bool FlexFormattingContext::has_cross_min_size(Box const& box) const
pub fn flex_formatting_context_cpp_396_flex_formatting_context_has_cross_min_size() LayoutStub {
	return layout_stub('FlexFormattingContext.cpp:396 FlexFormattingContext::has_cross_min_size')
}

// Translated from Libraries/LibWeb/Layout/FlexFormattingContext.cpp:402
// Original signature: bool FlexFormattingContext::has_definite_cross_size(LayoutState::UsedValues const& used_values) const
pub fn flex_formatting_context_cpp_402_flex_formatting_context_has_definite_cross_size() LayoutStub {
	return layout_stub('FlexFormattingContext.cpp:402 FlexFormattingContext::has_definite_cross_size')
}

// Translated from Libraries/LibWeb/Layout/FlexFormattingContext.cpp:407
// Original signature: CSSPixels FlexFormattingContext::specified_main_min_size(FlexItem const& item) const
pub fn flex_formatting_context_cpp_407_flex_formatting_context_specified_main_min_size() LayoutStub {
	return layout_stub('FlexFormattingContext.cpp:407 FlexFormattingContext::specified_main_min_size')
}

// Translated from Libraries/LibWeb/Layout/FlexFormattingContext.cpp:414
// Original signature: CSSPixels FlexFormattingContext::specified_cross_min_size(FlexItem const& item) const
pub fn flex_formatting_context_cpp_414_flex_formatting_context_specified_cross_min_size() LayoutStub {
	return layout_stub('FlexFormattingContext.cpp:414 FlexFormattingContext::specified_cross_min_size')
}

// Translated from Libraries/LibWeb/Layout/FlexFormattingContext.cpp:421
// Original signature: CSSPixels FlexFormattingContext::calculate_inner_flex_container_cross_min_size() const
pub fn flex_formatting_context_cpp_421_flex_formatting_context_calculate_inner_flex_container_cross_min_size() LayoutStub {
	return layout_stub('FlexFormattingContext.cpp:421 FlexFormattingContext::calculate_inner_flex_container_cross_min_size')
}

// Translated from Libraries/LibWeb/Layout/FlexFormattingContext.cpp:428
// Original signature: CSSPixels FlexFormattingContext::calculate_inner_flex_container_cross_max_size() const
pub fn flex_formatting_context_cpp_428_flex_formatting_context_calculate_inner_flex_container_cross_max_size() LayoutStub {
	return layout_stub('FlexFormattingContext.cpp:428 FlexFormattingContext::calculate_inner_flex_container_cross_max_size')
}

// Translated from Libraries/LibWeb/Layout/FlexFormattingContext.cpp:435
// Original signature: bool FlexFormattingContext::has_main_max_size(Box const& box) const
pub fn flex_formatting_context_cpp_435_flex_formatting_context_has_main_max_size() LayoutStub {
	return layout_stub('FlexFormattingContext.cpp:435 FlexFormattingContext::has_main_max_size')
}

// Translated from Libraries/LibWeb/Layout/FlexFormattingContext.cpp:440
// Original signature: bool FlexFormattingContext::has_cross_max_size(Box const& box) const
pub fn flex_formatting_context_cpp_440_flex_formatting_context_has_cross_max_size() LayoutStub {
	return layout_stub('FlexFormattingContext.cpp:440 FlexFormattingContext::has_cross_max_size')
}

// Translated from Libraries/LibWeb/Layout/FlexFormattingContext.cpp:445
// Original signature: CSSPixels FlexFormattingContext::specified_main_max_size(FlexItem const& item) const
pub fn flex_formatting_context_cpp_445_flex_formatting_context_specified_main_max_size() LayoutStub {
	return layout_stub('FlexFormattingContext.cpp:445 FlexFormattingContext::specified_main_max_size')
}

// Translated from Libraries/LibWeb/Layout/FlexFormattingContext.cpp:452
// Original signature: CSSPixels FlexFormattingContext::specified_cross_max_size(FlexItem const& item) const
pub fn flex_formatting_context_cpp_452_flex_formatting_context_specified_cross_max_size() LayoutStub {
	return layout_stub('FlexFormattingContext.cpp:452 FlexFormattingContext::specified_cross_max_size')
}

// Translated from Libraries/LibWeb/Layout/FlexFormattingContext.cpp:459
// Original signature: bool FlexFormattingContext::is_cross_auto(Box const& box) const
pub fn flex_formatting_context_cpp_459_flex_formatting_context_is_cross_auto() LayoutStub {
	return layout_stub('FlexFormattingContext.cpp:459 FlexFormattingContext::is_cross_auto')
}

// Translated from Libraries/LibWeb/Layout/FlexFormattingContext.cpp:465
// Original signature: void FlexFormattingContext::set_has_definite_main_size(FlexItem& item)
pub fn flex_formatting_context_cpp_465_flex_formatting_context_set_has_definite_main_size() LayoutStub {
	return layout_stub('FlexFormattingContext.cpp:465 FlexFormattingContext::set_has_definite_main_size')
}

// Translated from Libraries/LibWeb/Layout/FlexFormattingContext.cpp:473
// Original signature: void FlexFormattingContext::set_has_definite_cross_size(FlexItem& item)
pub fn flex_formatting_context_cpp_473_flex_formatting_context_set_has_definite_cross_size() LayoutStub {
	return layout_stub('FlexFormattingContext.cpp:473 FlexFormattingContext::set_has_definite_cross_size')
}

// Translated from Libraries/LibWeb/Layout/FlexFormattingContext.cpp:481
// Original signature: void FlexFormattingContext::set_main_size(Box const& box, CSSPixels size)
pub fn flex_formatting_context_cpp_481_flex_formatting_context_set_main_size() LayoutStub {
	return layout_stub('FlexFormattingContext.cpp:481 FlexFormattingContext::set_main_size')
}

// Translated from Libraries/LibWeb/Layout/FlexFormattingContext.cpp:489
// Original signature: void FlexFormattingContext::set_cross_size(Box const& box, CSSPixels size)
pub fn flex_formatting_context_cpp_489_flex_formatting_context_set_cross_size() LayoutStub {
	return layout_stub('FlexFormattingContext.cpp:489 FlexFormattingContext::set_cross_size')
}

// Translated from Libraries/LibWeb/Layout/FlexFormattingContext.cpp:497
// Original signature: void FlexFormattingContext::set_main_size(FlexItem& item, CSSPixels size)
pub fn flex_formatting_context_cpp_497_flex_formatting_context_set_main_size() LayoutStub {
	return layout_stub('FlexFormattingContext.cpp:497 FlexFormattingContext::set_main_size')
}

// Translated from Libraries/LibWeb/Layout/FlexFormattingContext.cpp:505
// Original signature: void FlexFormattingContext::set_cross_size(FlexItem& item, CSSPixels size)
pub fn flex_formatting_context_cpp_505_flex_formatting_context_set_cross_size() LayoutStub {
	return layout_stub('FlexFormattingContext.cpp:505 FlexFormattingContext::set_cross_size')
}

// Translated from Libraries/LibWeb/Layout/FlexFormattingContext.cpp:513
// Original signature: void FlexFormattingContext::set_offset(FlexItem& item, CSSPixels main_offset, CSSPixels cross_offset)
pub fn flex_formatting_context_cpp_513_flex_formatting_context_set_offset() LayoutStub {
	return layout_stub('FlexFormattingContext.cpp:513 FlexFormattingContext::set_offset')
}

// Translated from Libraries/LibWeb/Layout/FlexFormattingContext.cpp:521
// Original signature: void FlexFormattingContext::set_main_axis_first_margin(FlexItem& item, CSSPixels margin)
pub fn flex_formatting_context_cpp_521_flex_formatting_context_set_main_axis_first_margin() LayoutStub {
	return layout_stub('FlexFormattingContext.cpp:521 FlexFormattingContext::set_main_axis_first_margin')
}

// Translated from Libraries/LibWeb/Layout/FlexFormattingContext.cpp:530
// Original signature: void FlexFormattingContext::set_main_axis_second_margin(FlexItem& item, CSSPixels margin)
pub fn flex_formatting_context_cpp_530_flex_formatting_context_set_main_axis_second_margin() LayoutStub {
	return layout_stub('FlexFormattingContext.cpp:530 FlexFormattingContext::set_main_axis_second_margin')
}

// Translated from Libraries/LibWeb/Layout/FlexFormattingContext.cpp:540
// Original signature: void FlexFormattingContext::determine_available_space_for_items(AvailableSpace const& available_space)
// https://drafts.csswg.org/css-flexbox-1/#algo-available
pub fn flex_formatting_context_cpp_540_flex_formatting_context_determine_available_space_for_items() LayoutStub {
	return layout_stub('FlexFormattingContext.cpp:540 FlexFormattingContext::determine_available_space_for_items')
}

// Translated from Libraries/LibWeb/Layout/FlexFormattingContext.cpp:558
// Original signature: CSS::FlexBasis FlexFormattingContext::used_flex_basis_for_item(FlexItem const& item) const
// https://drafts.csswg.org/css-flexbox-1/#propdef-flex-basis
// https://drafts.csswg.org/css-flexbox-1/#valdef-flex-basis-auto
// When specified on a flex item, the auto keyword retrieves the value of the main size property as the used
// flex-basis.
// If that value is itself auto, then the used value is content.
// For example, percentage values of flex-basis are resolved against the flex item's containing block
// (i.e. its flex container); and if that containing block's size is indefinite,
// the used value for flex-basis is content.
pub fn flex_formatting_context_cpp_558_flex_formatting_context_used_flex_basis_for_item() LayoutStub {
	return layout_stub('FlexFormattingContext.cpp:558 FlexFormattingContext::used_flex_basis_for_item')
}

// Translated from Libraries/LibWeb/Layout/FlexFormattingContext.cpp:587
// Original signature: CSSPixels FlexFormattingContext::calculate_main_size_from_cross_size_and_aspect_ratio(CSSPixels cross_size, CSSPixelFraction aspect_ratio) const
pub fn flex_formatting_context_cpp_587_flex_formatting_context_calculate_main_size_from_cross_size_and_aspect_r() LayoutStub {
	return layout_stub('FlexFormattingContext.cpp:587 FlexFormattingContext::calculate_main_size_from_cross_size_and_aspect_ratio')
}

// Translated from Libraries/LibWeb/Layout/FlexFormattingContext.cpp:594
// Original signature: CSSPixels FlexFormattingContext::calculate_cross_size_from_main_size_and_aspect_ratio(CSSPixels main_size, CSSPixelFraction aspect_ratio) const
pub fn flex_formatting_context_cpp_594_flex_formatting_context_calculate_cross_size_from_main_size_and_aspect_r() LayoutStub {
	return layout_stub('FlexFormattingContext.cpp:594 FlexFormattingContext::calculate_cross_size_from_main_size_and_aspect_ratio')
}

// Translated from Libraries/LibWeb/Layout/FlexFormattingContext.cpp:603
// Original signature: CSSPixels FlexFormattingContext::adjust_main_size_through_aspect_ratio_for_cross_size_min_max_constraints(Box const& box, CSSPixels main_size, CSS::Size const& min_cross_size, CSS::Size const& max_cross_size) const
// This function takes a size in the main axis and adjusts it according to the aspect ratio of the box
// if the min/max constraints in the cross axis forces us to come up with a new main axis size.
pub fn flex_formatting_context_cpp_603_flex_formatting_context_adjust_main_size_through_aspect_ratio_for_cross_() LayoutStub {
	return layout_stub('FlexFormattingContext.cpp:603 FlexFormattingContext::adjust_main_size_through_aspect_ratio_for_cross_size_min_max_constraints')
}

// Translated from Libraries/LibWeb/Layout/FlexFormattingContext.cpp:618
// Original signature: CSSPixels FlexFormattingContext::adjust_cross_size_through_aspect_ratio_for_main_size_min_max_constraints(Box const& box, CSSPixels cross_size, CSS::Size const& min_main_size, CSS::Size const& max_main_size) const
pub fn flex_formatting_context_cpp_618_flex_formatting_context_adjust_cross_size_through_aspect_ratio_for_main_() LayoutStub {
	return layout_stub('FlexFormattingContext.cpp:618 FlexFormattingContext::adjust_cross_size_through_aspect_ratio_for_main_size_min_max_constraints')
}

// Translated from Libraries/LibWeb/Layout/FlexFormattingContext.cpp:634
// Original signature: void FlexFormattingContext::determine_flex_base_size(FlexItem& item)
// https://drafts.csswg.org/css-flexbox-1/#algo-main-item
// A. If the item has a definite used flex basis, that's the flex base size.
// AD-HOC: If we're sizing the flex container under a min-content constraint in the main axis,
// non-replaced flex items resolve percentages in the main axis to 0.
// https://drafts.csswg.org/css-sizing-3/#cyclic-percentage-contribution
// B. If the flex item has ...
// - an intrinsic aspect ratio,
// - a used flex basis of content, and
// - a definite cross size,
// flex_base_size is calculated from definite cross size and intrinsic aspect ratio
// AD-HOC: Mark that we resolved the main size from the aspect ratio,
// so that we can mark the item as having definite main size after resolving flexible lengths.
// C. If the used flex basis is content or depends on its available space,
// and the flex container is being sized under a min-content or max-content constraint
// (e.g. when performing automatic table layout [CSS21]), size the item under that constraint.
// The flex base size is the item's resulting main size.
// D. Otherwise, if the used flex basis is content or depends on its available space,
// the available main size is infinite, and the flex item's inline axis is parallel to the main axis,
// lay the item out using the rules for a box in an orthogonal flow [CSS3-WRITING-MODES].
// The flex base size is the item's max-content main size.
// FIXME: && main_size is infinite && inline axis is parallel to the main axis
// Use rules for a flex_container in orthogonal flow
// E. Otherwise, size the item into the available space using its used flex basis in place of its main size,
// treating a value of content as max-content. If a cross size is needed to determine the main size
// (e.g. when the flex item's main size is in its block axis) and the flex item's cross size is auto and not
// definite,
// in this calculation use fit-content as the flex item's cross size.
// NOTE: If the flex item has a definite main size, just use that as the flex base size.
// NOTE: There's a fundamental problem with many CSS specifications in that they neglect to mention
// which width to provide when calculating the intrinsic height of a box in various situations.
// Spec bug: https://github.com/w3c/csswg-drafts/issues/2890
// NOTE: This is one of many situations where that causes trouble: if this is a flex column layout,
// we may need to calculate the intrinsic height of a flex item. This requires a width, but a
// width won't be determined until later on in the flex layout algorithm.
// In the specific case above (E), the spec mentions using `fit-content` in place of `auto`
// if "a cross size is needed to determine the main size", so that's exactly what we do.
// NOTE: Finding a suitable width for intrinsic height determination actually happens elsewhere,
// in the various helpers that calculate the intrinsic sizes of a flex item,
// e.g. calculate_min_content_main_size().
// AD-HOC: This is not mentioned in the spec, but if the item has an aspect ratio, we may need
// to adjust the main size in these ways:
// - using stretch-fit main size if the flex basis is indefinite, there is no
// intrinsic size and no cross size to resolve the ratio against.
// - in response to cross size min/max constraints.
// NOTE: We don't clamp the main size until we have them for all items.
pub fn flex_formatting_context_cpp_634_flex_formatting_context_determine_flex_base_size() LayoutStub {
	return layout_stub('FlexFormattingContext.cpp:634 FlexFormattingContext::determine_flex_base_size')
}

// Translated from Libraries/LibWeb/Layout/FlexFormattingContext.cpp:783
// Original signature: CSSPixels FlexFormattingContext::automatic_minimum_size(FlexItem const& item) const
// https://drafts.csswg.org/css-flexbox-1/#min-size-auto
// To provide a more reasonable default minimum size for flex items,
// the used value of a main axis automatic minimum size on a flex item that is not a scroll container is its
// content-based minimum size;
// for scroll containers the automatic minimum size is zero, as usual.
pub fn flex_formatting_context_cpp_783_flex_formatting_context_automatic_minimum_size() LayoutStub {
	return layout_stub('FlexFormattingContext.cpp:783 FlexFormattingContext::automatic_minimum_size')
}

// Translated from Libraries/LibWeb/Layout/FlexFormattingContext.cpp:794
// Original signature: Optional<CSSPixels> FlexFormattingContext::specified_size_suggestion(FlexItem const& item) const
// https://drafts.csswg.org/css-flexbox-1/#specified-size-suggestion
// If the item's preferred main size is definite and not automatic,
// then the specified size suggestion is that size. It is otherwise undefined.
// NOTE: We use get_pixel_{width,height} to ensure that CSS box-sizing is respected.
pub fn flex_formatting_context_cpp_794_flex_formatting_context_specified_size_suggestion() LayoutStub {
	return layout_stub('FlexFormattingContext.cpp:794 FlexFormattingContext::specified_size_suggestion')
}

// Translated from Libraries/LibWeb/Layout/FlexFormattingContext.cpp:806
// Original signature: CSSPixels FlexFormattingContext::content_size_suggestion(FlexItem const& item) const
// https://drafts.csswg.org/css-flexbox-1/#content-size-suggestion
pub fn flex_formatting_context_cpp_806_flex_formatting_context_content_size_suggestion() LayoutStub {
	return layout_stub('FlexFormattingContext.cpp:806 FlexFormattingContext::content_size_suggestion')
}

// Translated from Libraries/LibWeb/Layout/FlexFormattingContext.cpp:818
// Original signature: Optional<CSSPixels> FlexFormattingContext::transferred_size_suggestion(FlexItem const& item) const
// https://drafts.csswg.org/css-flexbox-1/#transferred-size-suggestion
// If the item has a preferred aspect ratio and its preferred cross size is definite,
// then the transferred size suggestion is that size
// (clamped by its minimum and maximum cross sizes if they are definite), converted through the aspect ratio.
// It is otherwise undefined.
pub fn flex_formatting_context_cpp_818_flex_formatting_context_transferred_size_suggestion() LayoutStub {
	return layout_stub('FlexFormattingContext.cpp:818 FlexFormattingContext::transferred_size_suggestion')
}

// Translated from Libraries/LibWeb/Layout/FlexFormattingContext.cpp:837
// Original signature: CSSPixels FlexFormattingContext::content_based_minimum_size(FlexItem const& item) const
// https://drafts.csswg.org/css-flexbox-1/#content-based-minimum-size
// The content-based minimum size of a flex item differs depending on whether the flex item is replaced or not:
// -> For replaced elements
// Use the smaller of the content size suggestion and the transferred size suggestion (if one exists),
// capped by the specified size suggestion (if one exists).
// -> For non-replaced elements
// Use the larger of the content size suggestion and the transferred size suggestion (if one exists),
// In either case, the size is clamped by the maximum main size if it's definite.
pub fn flex_formatting_context_cpp_837_flex_formatting_context_content_based_minimum_size() LayoutStub {
	return layout_stub('FlexFormattingContext.cpp:837 FlexFormattingContext::content_based_minimum_size')
}

// Translated from Libraries/LibWeb/Layout/FlexFormattingContext.cpp:878
// Original signature: void FlexFormattingContext::collect_flex_items_into_flex_lines()
// https://www.w3.org/TR/css-flexbox-1/#algo-line-break
// If the flex container is single-line, collect all the flex items into a single flex line.
// Otherwise, starting from the first uncollected item, collect consecutive items one by one
// until the first time that the next collected item would not fit into the flex container's inner main size
// (or until a forced break is encountered, see ?10 Fragmenting Flex Layout).
// If the very first uncollected item wouldn't fit, collect just it into the line.
// For this step, the size of a flex item is its outer hypothetical main size. (Note: This can be negative.)
// Repeat until all flex items have been collected into flex lines.
// CSS-FLEXBOX-2: Account for gap between flex items.
pub fn flex_formatting_context_cpp_878_flex_formatting_context_collect_flex_items_into_flex_lines() LayoutStub {
	return layout_stub('FlexFormattingContext.cpp:878 FlexFormattingContext::collect_flex_items_into_flex_lines')
}

// Translated from Libraries/LibWeb/Layout/FlexFormattingContext.cpp:927
// Original signature: void FlexFormattingContext::resolve_flexible_lengths_for_line(FlexLine& line)
// https://drafts.csswg.org/css-flexbox-1/#resolve-flexible-lengths
// AD-HOC: The spec tells us to use the "flex container's inner main size" in this algorithm,
// but that doesn't work when we're sizing under a max-content constraint.
// In that case, there is effectively infinite size available in the main axis,
// but the inner main size has not been assigned yet.
// We solve this by calculating our own "available main size" here, which is essentially
// infinity under max-content, 0 under min-content, and the inner main size otherwise.
// 1. Determine the used flex factor.
// Sum the outer hypothetical main sizes of all items on the line.
// If the sum is less than the flex container's inner main size,
// use the flex grow factor for the rest of this algorithm; otherwise, use the flex shrink factor
// CSS-FLEXBOX-2: Account for gap between flex items.
// AD-HOC: Note that we're using our own "available main size" explained above
// instead of the flex container's inner main size.
// 2. Each item in the flex line has a target main size, initially set to its flex base size.
// Each item is initially unfrozen and may become frozen.
// 3. Size inflexible items.
// Freeze, setting its target main size to its hypothetical main size...
// - any item that has a flex factor of zero
// - if using the flex grow factor: any item that has a flex base size greater than its hypothetical main size
// - if using the flex shrink factor: any item that has a flex base size smaller than its hypothetical main size
// 4. Calculate initial free space
// Sum the outer sizes of all items on the line, and subtract this from the flex container's inner main size.
// For frozen items, use their outer target main size; for other items, use their outer flex base size.
// AD-HOC: If the container is sized under max-content constraints, then remaining_free_space won't have
// a value to avoid leaking an infinite value into layout calculations.
// 5. Loop
// a. Check for flexible items.
// If all the flex items on the line are frozen, exit this loop.
// b. Calculate the remaining free space as for initial free space, above.
// If the sum of the unfrozen flex items' flex factors is less than one, multiply the initial free space by this
// sum.
// If the magnitude of this value is less than the magnitude of the remaining free space, use this as the
// remaining free space.
// AD-HOC: We allow the remaining free space to be infinite, but we can't let infinity
// leak into the layout geometry, so we treat infinity as zero when used in arithmetic.
// c. If the remaining free space is non-zero, distribute it proportional to the flex factors:
// If using the flex grow factor
// For every unfrozen item on the line,
// find the ratio of the item's flex grow factor to the sum of the flex grow factors of all unfrozen items on the
// line.
// Set the item's target main size to its flex base size plus a fraction of the remaining free space proportional
// to the ratio.
// If using the flex shrink factor
// For every unfrozen item on the line, multiply its flex shrink factor by its inner flex base size, and note
// this as its scaled flex shrink factor.
// Find the ratio of the item's scaled flex shrink factor to the sum of the scaled flex shrink factors of all
// unfrozen items on the line.
// Set the item's target main size to its flex base size minus a fraction of the absolute value of the remaining
// free space proportional to the ratio.
// (Note this may result in a negative inner main size; it will be corrected in the next step.)
// d. Fix min/max violations.
// Clamp each non-frozen item's target main size by its used min and max main sizes and floor its content-box
// size at zero.
// If the item's target main size was made smaller by this, it's a max violation.
// If the item's target main size was made larger by this, it's a min violation.
// e. Freeze over-flexed items.
// The total violation is the sum of the adjustments from the previous step ?(clamped size - unclamped size).
// If the total violation is:
// Zero
// Freeze all items.
// Positive
// Freeze all the items with min violations.
// Negative
// Freeze all the items with max violations.
// NOTE: This freezes at least one item, ensuring that the loop makes progress and eventually terminates.
// f. Return to the start of this loop.
// NOTE: Calculate the remaining free space once again here, since it's needed later when aligning items.
// 6. Set each item's used main size to its target main size.
// https://drafts.csswg.org/css-flexbox-1/#definite-sizes
// 1. If the flex container has a definite main size, then the post-flexing main sizes of its flex items are
// treated as definite.
// 2. If a flex item's flex basis is definite, then its post-flexing main size is also definite.
// AD-HOC: 3. If a flex item's main size was resolved from its intrinsic aspect ratio, then its post-flexing main
// size is also definite.
pub fn flex_formatting_context_cpp_927_flex_formatting_context_resolve_flexible_lengths_for_line() LayoutStub {
	return layout_stub('FlexFormattingContext.cpp:927 FlexFormattingContext::resolve_flexible_lengths_for_line')
}

// Translated from Libraries/LibWeb/Layout/FlexFormattingContext.cpp:1159
// Original signature: void FlexFormattingContext::resolve_flexible_lengths()
// https://drafts.csswg.org/css-flexbox-1/#resolve-flexible-lengths
pub fn flex_formatting_context_cpp_1159_flex_formatting_context_resolve_flexible_lengths() LayoutStub {
	return layout_stub('FlexFormattingContext.cpp:1159 FlexFormattingContext::resolve_flexible_lengths')
}

// Translated from Libraries/LibWeb/Layout/FlexFormattingContext.cpp:1167
// Original signature: void FlexFormattingContext::determine_hypothetical_cross_size_of_item(FlexItem& item)
// https://drafts.csswg.org/css-flexbox/#hypothetical-cross-size
// Determine the hypothetical cross size of each item by performing layout as if it were an in-flow block-level
// box
// with the used main size and the given available space, treating auto as fit-content.
// If we have a definite cross size, this is easy! No need to perform layout, we can just use it as-is.
// "... treating auto as fit-content"
pub fn flex_formatting_context_cpp_1167_flex_formatting_context_determine_hypothetical_cross_size_of_item() LayoutStub {
	return layout_stub('FlexFormattingContext.cpp:1167 FlexFormattingContext::determine_hypothetical_cross_size_of_item')
}

// Translated from Libraries/LibWeb/Layout/FlexFormattingContext.cpp:1218
// Original signature: void FlexFormattingContext::calculate_cross_size_of_each_flex_line()
// https://www.w3.org/TR/css-flexbox-1/#algo-cross-line
// If the flex container is single-line and has a definite cross size, the cross size of the flex line is the
// flex container's inner cross size.
// Otherwise, for each flex line:
// FIXME: 1. Collect all the flex items whose inline-axis is parallel to the main-axis, whose align-self is
// baseline,
// and whose cross-axis margins are both non-auto. Find the largest of the distances between each item's baseline
// and its hypothetical outer cross-start edge, and the largest of the distances between each item's baseline
// and its hypothetical outer cross-end edge, and sum these two values.
// 2. Among all the items not collected by the previous step, find the largest outer hypothetical cross size.
// 3. The used cross-size of the flex line is the largest of the numbers found in the previous two steps and
// zero.
// If the flex container is single-line, then clamp the line's cross-size to be within the container's computed
// min and max cross sizes.
// Note that if CSS 2.1's definition of min/max-width/height applied more generally, this behavior would fall out
// automatically.
// AD-HOC: We don't do this when the flex container is being sized under a min-content or max-content constraint.
pub fn flex_formatting_context_cpp_1218_flex_formatting_context_calculate_cross_size_of_each_flex_line() LayoutStub {
	return layout_stub('FlexFormattingContext.cpp:1218 FlexFormattingContext::calculate_cross_size_of_each_flex_line')
}

// Translated from Libraries/LibWeb/Layout/FlexFormattingContext.cpp:1258
// Original signature: void FlexFormattingContext::determine_used_cross_size_of_each_flex_item()
// https://www.w3.org/TR/css-flexbox-1/#algo-stretch
// If a flex item has align-self: stretch, its computed cross size property is auto,
// and neither of its cross-axis margins are auto, the used outer cross size is the used cross size of its flex
// line,
// clamped according to the item's used min and max cross sizes.
// Otherwise, the used cross size is the item's hypothetical cross size.
pub fn flex_formatting_context_cpp_1258_flex_formatting_context_determine_used_cross_size_of_each_flex_item() LayoutStub {
	return layout_stub('FlexFormattingContext.cpp:1258 FlexFormattingContext::determine_used_cross_size_of_each_flex_item')
}

// Translated from Libraries/LibWeb/Layout/FlexFormattingContext.cpp:1290
// Original signature: void FlexFormattingContext::distribute_any_remaining_free_space()
// https://www.w3.org/TR/css-flexbox-1/#algo-main-align
// 12.1.
// CSS-FLEXBOX-2: Account for gap between flex items.
// 12.2.
// For reverse, we use FlexRegionRenderCursor::Right
// to indicate the cursor offset is the end and render backwards
// Otherwise the cursor offset is the 'start' of the region or initial offset
// CSS-FLEXBOX-2: Account for gap between items.
pub fn flex_formatting_context_cpp_1290_flex_formatting_context_distribute_any_remaining_free_space() LayoutStub {
	return layout_stub('FlexFormattingContext.cpp:1290 FlexFormattingContext::distribute_any_remaining_free_space')
}

// Translated from Libraries/LibWeb/Layout/FlexFormattingContext.cpp:1495
// Original signature: void FlexFormattingContext::dump_items() const
pub fn flex_formatting_context_cpp_1495_flex_formatting_context_dump_items() LayoutStub {
	return layout_stub('FlexFormattingContext.cpp:1495 FlexFormattingContext::dump_items')
}

// Translated from Libraries/LibWeb/Layout/FlexFormattingContext.cpp:1507
// Original signature: CSS::AlignItems FlexFormattingContext::alignment_for_item(Box const& box) const
pub fn flex_formatting_context_cpp_1507_flex_formatting_context_alignment_for_item() LayoutStub {
	return layout_stub('FlexFormattingContext.cpp:1507 FlexFormattingContext::alignment_for_item')
}

// Translated from Libraries/LibWeb/Layout/FlexFormattingContext.cpp:1541
// Original signature: void FlexFormattingContext::align_all_flex_items_along_the_cross_axis()
// FIXME: Take better care of margins
// https://drafts.csswg.org/css-flexbox/#flex-wrap-property
// When flex-wrap is wrap-reverse, the cross-start and cross-end directions are swapped.
// https://drafts.csswg.org/css-flexbox-1/#valdef-align-items-baseline
// NB: Baseline-aligned items are initially placed at the cross-start edge (like flex-start). Their
// positions are adjusted after layout in resolve_baseline_aligned_items().
// FIXME: 'start', 'flex-start' and 'self-start' have subtly different behavior.
// The same goes for the end values.
// https://drafts.csswg.org/css-flexbox/#align-items-property
// The flex item's margin box is centered in the cross axis within the line
pub fn flex_formatting_context_cpp_1541_flex_formatting_context_align_all_flex_items_along_the_cross_axis() LayoutStub {
	return layout_stub('FlexFormattingContext.cpp:1541 FlexFormattingContext::align_all_flex_items_along_the_cross_axis')
}

// Translated from Libraries/LibWeb/Layout/FlexFormattingContext.cpp:1589
// Original signature: void FlexFormattingContext::resolve_baseline_aligned_items()
// https://drafts.csswg.org/css-flexbox-1/#valdef-align-items-baseline
// all participating flex items on the line are aligned such that their baselines align, and the item with the
// largest distance between its baseline and its cross-start margin edge is placed flush against the cross-start
// edge of the line.
// NB: This runs after layout_inside() so that line boxes are available for baseline computation.
pub fn flex_formatting_context_cpp_1589_flex_formatting_context_resolve_baseline_aligned_items() LayoutStub {
	return layout_stub('FlexFormattingContext.cpp:1589 FlexFormattingContext::resolve_baseline_aligned_items')
}

// Translated from Libraries/LibWeb/Layout/FlexFormattingContext.cpp:1620
// Original signature: void FlexFormattingContext::align_all_flex_lines()
// https://drafts.csswg.org/css-flexbox-1/#algo-line-align
// Align all flex lines per align-content.
// For single-line flex containers, we only need to center the line along the cross axis.
// CSS-FLEXBOX-2: Account for gap between flex lines.
// If the leftover free-space is negative this value is identical to center.
// The spacing between the first/last lines and the flex container edges is half the size of the spacing between
// flex lines.
// The spacing between the first/last lines and the flex container edges is the size of the spacing between flex
// lines.
pub fn flex_formatting_context_cpp_1620_flex_formatting_context_align_all_flex_lines() LayoutStub {
	return layout_stub('FlexFormattingContext.cpp:1620 FlexFormattingContext::align_all_flex_lines')
}

// Translated from Libraries/LibWeb/Layout/FlexFormattingContext.cpp:1772
// Original signature: void FlexFormattingContext::copy_dimensions_from_flex_items_to_boxes()
pub fn flex_formatting_context_cpp_1772_flex_formatting_context_copy_dimensions_from_flex_items_to_boxes() LayoutStub {
	return layout_stub('FlexFormattingContext.cpp:1772 FlexFormattingContext::copy_dimensions_from_flex_items_to_boxes')
}

// Translated from Libraries/LibWeb/Layout/FlexFormattingContext.cpp:1794
// Original signature: void FlexFormattingContext::determine_intrinsic_size_of_flex_container()
// https://drafts.csswg.org/css-flexbox-1/#intrinsic-sizes
pub fn flex_formatting_context_cpp_1794_flex_formatting_context_determine_intrinsic_size_of_flex_container() LayoutStub {
	return layout_stub('FlexFormattingContext.cpp:1794 FlexFormattingContext::determine_intrinsic_size_of_flex_container')
}

// Translated from Libraries/LibWeb/Layout/FlexFormattingContext.cpp:1807
// Original signature: CSSPixels FlexFormattingContext::calculate_intrinsic_main_size_of_flex_container()
// https://drafts.csswg.org/css-flexbox-1/#intrinsic-main-sizes
// The min-content main size of a single-line flex container is calculated identically to the max-content main
// size,
// except that the flex items' min-content contributions are used instead of their max-content contributions.
// However, for a multi-line container, it is simply the largest min-content contribution of all the non-
// collapsed flex items in the flex container.
// FIXME: Skip collapsed flex items.
// The max-content main size of a flex container is, fundamentally, the smallest size the flex container
// can take such that when flex layout is run with that container size, each flex item ends up at least
// as large as its max-content contribution, to the extent allowed by the items' flexibility.
// It is calculated, considering only non-collapsed flex items, by:
// 1. For each flex item, subtract its outer flex base size from its max-content contribution size.
// If that result is positive, divide it by the item's flex grow factor if the flex grow factor is >= 1,
// or multiply it by the flex grow factor if the flex grow factor is < 1; if the result is negative,
// divide it by the item's scaled flex shrink factor (if dividing by zero, treat the result as negative
// infinity).
// This is the item's desired flex fraction.
// 2. Place all flex items into lines of infinite length.
// FIXME: Honor breaking requests.
// Within each line, find the greatest (most positive) desired flex fraction among all the flex items.
// This is the line's chosen flex fraction.
// 3. If the chosen flex fraction is positive, and the sum of the line's flex grow factors is less than 1,
// divide the chosen flex fraction by that sum.
// If the chosen flex fraction is negative, and the sum of the line's flex shrink factors is less than 1,
// multiply the chosen flex fraction by that sum.
// 4. Add each item's flex base size to the product of its flex grow factor (scaled flex shrink factor, if
// shrinking)
// and the chosen flex fraction, then clamp that result by the max main size floored by the min main size.
// NOTE: The spec doesn't mention anything about the *outer* size here, but if we don't add the margin box,
// flex items with non-zero padding/border/margin in the main axis end up overflowing the container.
// CSS-FLEXBOX-2: Account for gap between flex items.
// 5. The flex container's max-content size is the largest sum (among all the lines) of the afore-calculated
// sizes of all items within a single line.
pub fn flex_formatting_context_cpp_1807_flex_formatting_context_calculate_intrinsic_main_size_of_flex_container() LayoutStub {
	return layout_stub('FlexFormattingContext.cpp:1807 FlexFormattingContext::calculate_intrinsic_main_size_of_flex_container')
}

// Translated from Libraries/LibWeb/Layout/FlexFormattingContext.cpp:1935
// Original signature: CSSPixels FlexFormattingContext::calculate_intrinsic_cross_size_of_flex_container()
// https://drafts.csswg.org/css-flexbox-1/#intrinsic-cross-sizes
// The min-content/max-content cross size of a single-line flex container
// is the largest min-content contribution/max-content contribution (respectively) of its flex items.
// row multi-line flex container cross-size
// The min-content/max-content cross size is the sum of the flex line cross sizes resulting from
// sizing the flex container under a cross-axis min-content constraint/max-content constraint (respectively).
// NOTE: We fall through to the ad-hoc section below.
// column multi-line flex container cross-size
// The min-content cross size is the largest min-content contribution among all of its flex items.
// The max-content cross size is the sum of the flex line cross sizes resulting from
// sizing the flex container under a cross-axis max-content constraint,
// using the largest max-content cross-size contribution among the flex items
// as the available space in the cross axis for each of the flex items during layout.
// CSS-FLEXBOX-2: Account for gap between flex lines.
pub fn flex_formatting_context_cpp_1935_flex_formatting_context_calculate_intrinsic_cross_size_of_flex_containe() LayoutStub {
	return layout_stub('FlexFormattingContext.cpp:1935 FlexFormattingContext::calculate_intrinsic_cross_size_of_flex_container')
}

// Translated from Libraries/LibWeb/Layout/FlexFormattingContext.cpp:2004
// Original signature: CSSPixels FlexFormattingContext::calculate_main_min_content_contribution(FlexItem const& item) const
// https://drafts.csswg.org/css-flexbox-1/#intrinsic-item-contributions
// The main-size min-content contribution of a flex item is the larger of its outer min-content size and outer
// preferred size if that is not auto, clamped by its min/max main size.
pub fn flex_formatting_context_cpp_2004_flex_formatting_context_calculate_main_min_content_contribution() LayoutStub {
	return layout_stub('FlexFormattingContext.cpp:2004 FlexFormattingContext::calculate_main_min_content_contribution')
}

// Translated from Libraries/LibWeb/Layout/FlexFormattingContext.cpp:2024
// Original signature: CSSPixels FlexFormattingContext::calculate_main_max_content_contribution(FlexItem const& item) const
// https://drafts.csswg.org/css-flexbox-1/#intrinsic-item-contributions
// The main-size max-content contribution of a flex item is
// the larger of its outer max-content size and outer preferred size if that is not auto,
// clamped by its min/max main size.
pub fn flex_formatting_context_cpp_2024_flex_formatting_context_calculate_main_max_content_contribution() LayoutStub {
	return layout_stub('FlexFormattingContext.cpp:2024 FlexFormattingContext::calculate_main_max_content_contribution')
}

// Translated from Libraries/LibWeb/Layout/FlexFormattingContext.cpp:2044
// Original signature: bool FlexFormattingContext::should_treat_main_size_as_auto(Box const& box) const
pub fn flex_formatting_context_cpp_2044_flex_formatting_context_should_treat_main_size_as_auto() LayoutStub {
	return layout_stub('FlexFormattingContext.cpp:2044 FlexFormattingContext::should_treat_main_size_as_auto')
}

// Translated from Libraries/LibWeb/Layout/FlexFormattingContext.cpp:2051
// Original signature: bool FlexFormattingContext::should_treat_cross_size_as_auto(Box const& box) const
pub fn flex_formatting_context_cpp_2051_flex_formatting_context_should_treat_cross_size_as_auto() LayoutStub {
	return layout_stub('FlexFormattingContext.cpp:2051 FlexFormattingContext::should_treat_cross_size_as_auto')
}

// Translated from Libraries/LibWeb/Layout/FlexFormattingContext.cpp:2058
// Original signature: bool FlexFormattingContext::should_treat_main_max_size_as_none(Box const& box) const
pub fn flex_formatting_context_cpp_2058_flex_formatting_context_should_treat_main_max_size_as_none() LayoutStub {
	return layout_stub('FlexFormattingContext.cpp:2058 FlexFormattingContext::should_treat_main_max_size_as_none')
}

// Translated from Libraries/LibWeb/Layout/FlexFormattingContext.cpp:2065
// Original signature: bool FlexFormattingContext::should_treat_cross_max_size_as_none(Box const& box) const
pub fn flex_formatting_context_cpp_2065_flex_formatting_context_should_treat_cross_max_size_as_none() LayoutStub {
	return layout_stub('FlexFormattingContext.cpp:2065 FlexFormattingContext::should_treat_cross_max_size_as_none')
}

// Translated from Libraries/LibWeb/Layout/FlexFormattingContext.cpp:2072
// Original signature: CSSPixels FlexFormattingContext::calculate_cross_min_content_contribution(FlexItem const& item, bool resolve_percentage_min_max_sizes) const
pub fn flex_formatting_context_cpp_2072_flex_formatting_context_calculate_cross_min_content_contribution() LayoutStub {
	return layout_stub('FlexFormattingContext.cpp:2072 FlexFormattingContext::calculate_cross_min_content_contribution')
}

// Translated from Libraries/LibWeb/Layout/FlexFormattingContext.cpp:2095
// Original signature: CSSPixels FlexFormattingContext::calculate_cross_max_content_contribution(FlexItem const& item, bool resolve_percentage_min_max_sizes) const
pub fn flex_formatting_context_cpp_2095_flex_formatting_context_calculate_cross_max_content_contribution() LayoutStub {
	return layout_stub('FlexFormattingContext.cpp:2095 FlexFormattingContext::calculate_cross_max_content_contribution')
}

// Translated from Libraries/LibWeb/Layout/FlexFormattingContext.cpp:2118
// Original signature: CSSPixels FlexFormattingContext::calculate_width_to_use_when_determining_intrinsic_height_of_item(FlexItem const& item) const
// We can resolve percentage min/max-width if the available width is definite.
pub fn flex_formatting_context_cpp_2118_flex_formatting_context_calculate_width_to_use_when_determining_intrins() LayoutStub {
	return layout_stub('FlexFormattingContext.cpp:2118 FlexFormattingContext::calculate_width_to_use_when_determining_intrinsic_height_of_item')
}

// Translated from Libraries/LibWeb/Layout/FlexFormattingContext.cpp:2142
// Original signature: CSSPixels FlexFormattingContext::calculate_min_content_main_size(FlexItem const& item) const
pub fn flex_formatting_context_cpp_2142_flex_formatting_context_calculate_min_content_main_size() LayoutStub {
	return layout_stub('FlexFormattingContext.cpp:2142 FlexFormattingContext::calculate_min_content_main_size')
}

// Translated from Libraries/LibWeb/Layout/FlexFormattingContext.cpp:2154
// Original signature: CSSPixels FlexFormattingContext::calculate_max_content_main_size(FlexItem const& item) const
pub fn flex_formatting_context_cpp_2154_flex_formatting_context_calculate_max_content_main_size() LayoutStub {
	return layout_stub('FlexFormattingContext.cpp:2154 FlexFormattingContext::calculate_max_content_main_size')
}

// Translated from Libraries/LibWeb/Layout/FlexFormattingContext.cpp:2166
// Original signature: CSSPixels FlexFormattingContext::calculate_fit_content_main_size(FlexItem const& item) const
pub fn flex_formatting_context_cpp_2166_flex_formatting_context_calculate_fit_content_main_size() LayoutStub {
	return layout_stub('FlexFormattingContext.cpp:2166 FlexFormattingContext::calculate_fit_content_main_size')
}

// Translated from Libraries/LibWeb/Layout/FlexFormattingContext.cpp:2173
// Original signature: CSSPixels FlexFormattingContext::calculate_fit_content_cross_size(FlexItem const& item) const
pub fn flex_formatting_context_cpp_2173_flex_formatting_context_calculate_fit_content_cross_size() LayoutStub {
	return layout_stub('FlexFormattingContext.cpp:2173 FlexFormattingContext::calculate_fit_content_cross_size')
}

// Translated from Libraries/LibWeb/Layout/FlexFormattingContext.cpp:2180
// Original signature: CSSPixels FlexFormattingContext::calculate_min_content_cross_size(FlexItem const& item) const
pub fn flex_formatting_context_cpp_2180_flex_formatting_context_calculate_min_content_cross_size() LayoutStub {
	return layout_stub('FlexFormattingContext.cpp:2180 FlexFormattingContext::calculate_min_content_cross_size')
}

// Translated from Libraries/LibWeb/Layout/FlexFormattingContext.cpp:2192
// Original signature: CSSPixels FlexFormattingContext::calculate_max_content_cross_size(FlexItem const& item) const
pub fn flex_formatting_context_cpp_2192_flex_formatting_context_calculate_max_content_cross_size() LayoutStub {
	return layout_stub('FlexFormattingContext.cpp:2192 FlexFormattingContext::calculate_max_content_cross_size')
}

// Translated from Libraries/LibWeb/Layout/FlexFormattingContext.cpp:2205
// Original signature: bool FlexFormattingContext::flex_item_is_stretched(FlexItem const& item) const
// https://drafts.csswg.org/css-flexbox-1/#stretched
// If the cross size property of the flex item computes to auto, and neither of the cross-axis margins are auto,
// the flex item is stretched.
pub fn flex_formatting_context_cpp_2205_flex_formatting_context_flex_item_is_stretched() LayoutStub {
	return layout_stub('FlexFormattingContext.cpp:2205 FlexFormattingContext::flex_item_is_stretched')
}

// Translated from Libraries/LibWeb/Layout/FlexFormattingContext.cpp:2215
// Original signature: CSS::Size const& FlexFormattingContext::computed_main_size(Box const& box) const
pub fn flex_formatting_context_cpp_2215_flex_formatting_context_computed_main_size() LayoutStub {
	return layout_stub('FlexFormattingContext.cpp:2215 FlexFormattingContext::computed_main_size')
}

// Translated from Libraries/LibWeb/Layout/FlexFormattingContext.cpp:2220
// Original signature: CSS::Size const& FlexFormattingContext::computed_main_min_size(Box const& box) const
pub fn flex_formatting_context_cpp_2220_flex_formatting_context_computed_main_min_size() LayoutStub {
	return layout_stub('FlexFormattingContext.cpp:2220 FlexFormattingContext::computed_main_min_size')
}

// Translated from Libraries/LibWeb/Layout/FlexFormattingContext.cpp:2225
// Original signature: CSS::Size const& FlexFormattingContext::computed_main_max_size(Box const& box) const
pub fn flex_formatting_context_cpp_2225_flex_formatting_context_computed_main_max_size() LayoutStub {
	return layout_stub('FlexFormattingContext.cpp:2225 FlexFormattingContext::computed_main_max_size')
}

// Translated from Libraries/LibWeb/Layout/FlexFormattingContext.cpp:2230
// Original signature: CSS::Size const& FlexFormattingContext::computed_cross_size(Box const& box) const
pub fn flex_formatting_context_cpp_2230_flex_formatting_context_computed_cross_size() LayoutStub {
	return layout_stub('FlexFormattingContext.cpp:2230 FlexFormattingContext::computed_cross_size')
}

// Translated from Libraries/LibWeb/Layout/FlexFormattingContext.cpp:2235
// Original signature: CSS::Size const& FlexFormattingContext::computed_cross_min_size(Box const& box) const
pub fn flex_formatting_context_cpp_2235_flex_formatting_context_computed_cross_min_size() LayoutStub {
	return layout_stub('FlexFormattingContext.cpp:2235 FlexFormattingContext::computed_cross_min_size')
}

// Translated from Libraries/LibWeb/Layout/FlexFormattingContext.cpp:2240
// Original signature: CSS::Size const& FlexFormattingContext::computed_cross_max_size(Box const& box) const
pub fn flex_formatting_context_cpp_2240_flex_formatting_context_computed_cross_max_size() LayoutStub {
	return layout_stub('FlexFormattingContext.cpp:2240 FlexFormattingContext::computed_cross_max_size')
}

// Translated from Libraries/LibWeb/Layout/FlexFormattingContext.cpp:2246
// Original signature: void FlexFormattingContext::resolve_cross_axis_auto_margins()
// https://drafts.csswg.org/css-flexbox-1/#algo-cross-margins
// If a flex item has auto cross-axis margins:
// If its outer cross size (treating those auto margins as zero) is less than the cross size of its flex line,
// distribute the difference in those sizes equally to the auto margins.
// FIXME: Otherwise, if the block-start or inline-start margin (whichever is in the cross axis) is auto, set it
// to zero.
// Set the opposite margin so that the outer cross size of the item equals the cross size of its flex line.
pub fn flex_formatting_context_cpp_2246_flex_formatting_context_resolve_cross_axis_auto_margins() LayoutStub {
	return layout_stub('FlexFormattingContext.cpp:2246 FlexFormattingContext::resolve_cross_axis_auto_margins')
}

// Translated from Libraries/LibWeb/Layout/FlexFormattingContext.cpp:2276
// Original signature: void FlexFormattingContext::handle_align_content_stretch()
// https://drafts.csswg.org/css-flexbox-1/#algo-line-stretch
// If the flex container has a definite cross size,
// align-content is stretch,
// and the sum of the flex lines' cross sizes is less than the flex container's inner cross size,
// CSS-FLEXBOX-2: Account for gap between flex lines.
// increase the cross size of each flex line by equal amounts
// such that the sum of their cross sizes exactly equals the flex container's inner cross size.
pub fn flex_formatting_context_cpp_2276_flex_formatting_context_handle_align_content_stretch() LayoutStub {
	return layout_stub('FlexFormattingContext.cpp:2276 FlexFormattingContext::handle_align_content_stretch')
}

// Translated from Libraries/LibWeb/Layout/FlexFormattingContext.cpp:2307
// Original signature: StaticPositionRect FlexFormattingContext::calculate_static_position_rect(Box const& box) const
// https://drafts.csswg.org/css-flexbox-1/#abspos-items
// The cross-axis edges of the static-position rectangle of an absolutely-positioned child
// of a flex container are the content edges of the flex container.
// FIXME: Implement this
// Fallthrough
// The main-axis edges of the static-position rectangle are where the margin edges of the child
// would be positioned if it were the sole flex item in the flex container,
// assuming both the child and the flex container were fixed-size boxes of their used size.
// (For this purpose, auto margins are treated as zero.
pub fn flex_formatting_context_cpp_2307_flex_formatting_context_calculate_static_position_rect() LayoutStub {
	return layout_stub('FlexFormattingContext.cpp:2307 FlexFormattingContext::calculate_static_position_rect')
}

// Translated from Libraries/LibWeb/Layout/FlexFormattingContext.cpp:2379
// Original signature: double FlexFormattingContext::FlexLine::sum_of_flex_factor_of_unfrozen_items() const
pub fn flex_formatting_context_cpp_2379_flex_formatting_context_flex_line_sum_of_flex_factor_of_unfrozen_items() LayoutStub {
	return layout_stub('FlexFormattingContext.cpp:2379 FlexFormattingContext::FlexLine::sum_of_flex_factor_of_unfrozen_items')
}

// Translated from Libraries/LibWeb/Layout/FlexFormattingContext.cpp:2389
// Original signature: double FlexFormattingContext::FlexLine::sum_of_scaled_flex_shrink_factor_of_unfrozen_items() const
pub fn flex_formatting_context_cpp_2389_flex_formatting_context_flex_line_sum_of_scaled_flex_shrink_factor_of_u() LayoutStub {
	return layout_stub('FlexFormattingContext.cpp:2389 FlexFormattingContext::FlexLine::sum_of_scaled_flex_shrink_factor_of_unfrozen_items')
}

// Translated from Libraries/LibWeb/Layout/FlexFormattingContext.cpp:2399
// Original signature: static CSSPixels gap_to_px(Variant<CSS::LengthPercentage, CSS::NormalGap> const& gap, Layout::Node const& grid_container, CSSPixels reference_value)
pub fn flex_formatting_context_cpp_2399_gap_to_px() LayoutStub {
	return layout_stub('FlexFormattingContext.cpp:2399 gap_to_px')
}

// Translated from Libraries/LibWeb/Layout/FlexFormattingContext.cpp:2406
// Original signature: CSSPixels FlexFormattingContext::main_gap() const
pub fn flex_formatting_context_cpp_2406_flex_formatting_context_main_gap() LayoutStub {
	return layout_stub('FlexFormattingContext.cpp:2406 FlexFormattingContext::main_gap')
}

// Translated from Libraries/LibWeb/Layout/FlexFormattingContext.cpp:2413
// Original signature: CSSPixels FlexFormattingContext::cross_gap() const
pub fn flex_formatting_context_cpp_2413_flex_formatting_context_cross_gap() LayoutStub {
	return layout_stub('FlexFormattingContext.cpp:2413 FlexFormattingContext::cross_gap')
}

// ---- GridFormattingContext.h (76 translated function stubs) ----

// Translated from Libraries/LibWeb/Layout/GridFormattingContext.h:58
// Original signature: GridItem::[[nodiscard]] int gap_adjusted_row() const;
pub fn grid_formatting_context_h_58_gap_adjusted_row() LayoutStub {
	return layout_stub('GridFormattingContext.h:58 gap_adjusted_row')
}

// Translated from Libraries/LibWeb/Layout/GridFormattingContext.h:59
// Original signature: GridItem::[[nodiscard]] int gap_adjusted_column() const;
pub fn grid_formatting_context_h_59_gap_adjusted_column() LayoutStub {
	return layout_stub('GridFormattingContext.h:59 gap_adjusted_column')
}

// Translated from Libraries/LibWeb/Layout/GridFormattingContext.h:131
// Original signature: OccupationGrid::OccupationGrid()
pub fn grid_formatting_context_h_131_occupation_grid_occupation_grid() LayoutStub {
	return layout_stub('GridFormattingContext.h:131 OccupationGrid::OccupationGrid')
}

// Translated from Libraries/LibWeb/Layout/GridFormattingContext.h:133
// Original signature: OccupationGrid::void set_occupied(int column_start, int column_end, int row_start, int row_end);
pub fn grid_formatting_context_h_133_set_occupied() LayoutStub {
	return layout_stub('GridFormattingContext.h:133 set_occupied')
}

// Translated from Libraries/LibWeb/Layout/GridFormattingContext.h:145
// Original signature: OccupationGrid::void set_max_column_index(size_t max_column_index)
pub fn grid_formatting_context_h_145_set_max_column_index() LayoutStub {
	return layout_stub('GridFormattingContext.h:145 set_max_column_index')
}

// Translated from Libraries/LibWeb/Layout/GridFormattingContext.h:147
// Original signature: OccupationGrid::int min_column_index() const
pub fn grid_formatting_context_h_147_min_column_index() LayoutStub {
	return layout_stub('GridFormattingContext.h:147 min_column_index')
}

// Translated from Libraries/LibWeb/Layout/GridFormattingContext.h:148
// Original signature: OccupationGrid::int max_column_index() const
pub fn grid_formatting_context_h_148_max_column_index() LayoutStub {
	return layout_stub('GridFormattingContext.h:148 max_column_index')
}

// Translated from Libraries/LibWeb/Layout/GridFormattingContext.h:149
// Original signature: OccupationGrid::int min_row_index() const
pub fn grid_formatting_context_h_149_min_row_index() LayoutStub {
	return layout_stub('GridFormattingContext.h:149 min_row_index')
}

// Translated from Libraries/LibWeb/Layout/GridFormattingContext.h:150
// Original signature: OccupationGrid::int max_row_index() const
pub fn grid_formatting_context_h_150_max_row_index() LayoutStub {
	return layout_stub('GridFormattingContext.h:150 max_row_index')
}

// Translated from Libraries/LibWeb/Layout/GridFormattingContext.h:152
// Original signature: OccupationGrid::bool is_occupied(int column_index, int row_index) const;
pub fn grid_formatting_context_h_152_is_occupied() LayoutStub {
	return layout_stub('GridFormattingContext.h:152 is_occupied')
}

// Translated from Libraries/LibWeb/Layout/GridFormattingContext.h:153
// Original signature: OccupationGrid::bool is_area_occupied(int column_start, int row_start, int column_span, int row_span) const;
pub fn grid_formatting_context_h_153_is_area_occupied() LayoutStub {
	return layout_stub('GridFormattingContext.h:153 is_area_occupied')
}

// Translated from Libraries/LibWeb/Layout/GridFormattingContext.h:155
// Original signature: OccupationGrid::FoundUnoccupiedPlace find_unoccupied_place(GridDimension dimension, int& column_index, int& row_index, int column_span, int row_span) const;
pub fn grid_formatting_context_h_155_find_unoccupied_place() LayoutStub {
	return layout_stub('GridFormattingContext.h:155 find_unoccupied_place')
}

// Translated from Libraries/LibWeb/Layout/GridFormattingContext.h:168
// Original signature: GridFormattingContext::explicit GridFormattingContext(LayoutState&, LayoutMode, Box const& grid_container, FormattingContext* parent);
pub fn grid_formatting_context_h_168_grid_formatting_context() LayoutStub {
	return layout_stub('GridFormattingContext.h:168 GridFormattingContext')
}

// Translated from Libraries/LibWeb/Layout/GridFormattingContext.h:169
// Original signature: GridFormattingContext::~GridFormattingContext();
pub fn grid_formatting_context_h_169_grid_formatting_context_destroy_grid_formatting_context() LayoutStub {
	return layout_stub('GridFormattingContext.h:169 GridFormattingContext::~GridFormattingContext')
}

// Translated from Libraries/LibWeb/Layout/GridFormattingContext.h:171
// Original signature: GridFormattingContext::virtual bool inhibits_floating() const
pub fn grid_formatting_context_h_171_inhibits_floating() LayoutStub {
	return layout_stub('GridFormattingContext.h:171 inhibits_floating')
}

// Translated from Libraries/LibWeb/Layout/GridFormattingContext.h:173
// Original signature: GridFormattingContext::virtual void run(AvailableSpace const& available_space);
pub fn grid_formatting_context_h_173_run() LayoutStub {
	return layout_stub('GridFormattingContext.h:173 run')
}

// Translated from Libraries/LibWeb/Layout/GridFormattingContext.h:174
// Original signature: GridFormattingContext::virtual CSSPixels automatic_content_width() const;
pub fn grid_formatting_context_h_174_automatic_content_width() LayoutStub {
	return layout_stub('GridFormattingContext.h:174 automatic_content_width')
}

// Translated from Libraries/LibWeb/Layout/GridFormattingContext.h:175
// Original signature: GridFormattingContext::virtual CSSPixels automatic_content_height() const;
pub fn grid_formatting_context_h_175_automatic_content_height() LayoutStub {
	return layout_stub('GridFormattingContext.h:175 automatic_content_height')
}

// Translated from Libraries/LibWeb/Layout/GridFormattingContext.h:176
// Original signature: GridFormattingContext::StaticPositionRect calculate_static_position_rect(Box const&) const;
pub fn grid_formatting_context_h_176_calculate_static_position_rect() LayoutStub {
	return layout_stub('GridFormattingContext.h:176 calculate_static_position_rect')
}

// Translated from Libraries/LibWeb/Layout/GridFormattingContext.h:178
// Original signature: GridFormattingContext::Box const& grid_container() const
pub fn grid_formatting_context_h_178_grid_container() LayoutStub {
	return layout_stub('GridFormattingContext.h:178 grid_container')
}

// Translated from Libraries/LibWeb/Layout/GridFormattingContext.h:181
// Original signature: GridFormattingContext::Alignment alignment_for_item(Box const& box, GridDimension dimension) const;
pub fn grid_formatting_context_h_181_alignment_for_item() LayoutStub {
	return layout_stub('GridFormattingContext.h:181 alignment_for_item')
}

// Translated from Libraries/LibWeb/Layout/GridFormattingContext.h:183
// Original signature: GridFormattingContext::void resolve_items_box_metrics(GridDimension dimension);
pub fn grid_formatting_context_h_183_resolve_items_box_metrics() LayoutStub {
	return layout_stub('GridFormattingContext.h:183 resolve_items_box_metrics')
}

// Translated from Libraries/LibWeb/Layout/GridFormattingContext.h:187
// Original signature: GridFormattingContext::bool is_auto_positioned_track(CSS::GridTrackPlacement const&, CSS::GridTrackPlacement const&) const;
pub fn grid_formatting_context_h_187_is_auto_positioned_track() LayoutStub {
	return layout_stub('GridFormattingContext.h:187 is_auto_positioned_track')
}

// Translated from Libraries/LibWeb/Layout/GridFormattingContext.h:207
// Original signature: GridTrack::static GridTrack create_from_definition(CSS::ExplicitGridTrack const& definition, bool is_auto_fit);
pub fn grid_formatting_context_h_207_create_from_definition() LayoutStub {
	return layout_stub('GridFormattingContext.h:207 create_from_definition')
}

// Translated from Libraries/LibWeb/Layout/GridFormattingContext.h:208
// Original signature: GridTrack::static GridTrack create_auto();
pub fn grid_formatting_context_h_208_create_auto() LayoutStub {
	return layout_stub('GridFormattingContext.h:208 create_auto')
}

// Translated from Libraries/LibWeb/Layout/GridFormattingContext.h:209
// Original signature: GridTrack::static GridTrack create_gap(CSSPixels size);
pub fn grid_formatting_context_h_209_create_gap() LayoutStub {
	return layout_stub('GridFormattingContext.h:209 create_gap')
}

// Translated from Libraries/LibWeb/Layout/GridFormattingContext.h:215
// Original signature: GridFormattingContext::void init_grid_lines(GridDimension);
pub fn grid_formatting_context_h_215_init_grid_lines() LayoutStub {
	return layout_stub('GridFormattingContext.h:215 init_grid_lines')
}

// Translated from Libraries/LibWeb/Layout/GridFormattingContext.h:301
// Original signature: GridFormattingContext::void determine_grid_container_height();
pub fn grid_formatting_context_h_301_determine_grid_container_height() LayoutStub {
	return layout_stub('GridFormattingContext.h:301 determine_grid_container_height')
}

// Translated from Libraries/LibWeb/Layout/GridFormattingContext.h:302
// Original signature: GridFormattingContext::void determine_intrinsic_size_of_grid_container(AvailableSpace const& available_space);
pub fn grid_formatting_context_h_302_determine_intrinsic_size_of_grid_container() LayoutStub {
	return layout_stub('GridFormattingContext.h:302 determine_intrinsic_size_of_grid_container')
}

// Translated from Libraries/LibWeb/Layout/GridFormattingContext.h:304
// Original signature: GridFormattingContext::virtual AbsposContainingBlockInfo resolve_abspos_containing_block_info(Box const&);
pub fn grid_formatting_context_h_304_resolve_abspos_containing_block_info() LayoutStub {
	return layout_stub('GridFormattingContext.h:304 resolve_abspos_containing_block_info')
}

// Translated from Libraries/LibWeb/Layout/GridFormattingContext.h:305
// Original signature: GridFormattingContext::virtual void parent_context_did_dimension_child_root_box();
pub fn grid_formatting_context_h_305_parent_context_did_dimension_child_root_box() LayoutStub {
	return layout_stub('GridFormattingContext.h:305 parent_context_did_dimension_child_root_box')
}

// Translated from Libraries/LibWeb/Layout/GridFormattingContext.h:307
// Original signature: GridFormattingContext::void resolve_grid_item_sizes(GridDimension dimension);
pub fn grid_formatting_context_h_307_resolve_grid_item_sizes() LayoutStub {
	return layout_stub('GridFormattingContext.h:307 resolve_grid_item_sizes')
}

// Translated from Libraries/LibWeb/Layout/GridFormattingContext.h:309
// Original signature: GridFormattingContext::void resolve_track_spacing(GridDimension dimension);
pub fn grid_formatting_context_h_309_resolve_track_spacing() LayoutStub {
	return layout_stub('GridFormattingContext.h:309 resolve_track_spacing')
}

// Translated from Libraries/LibWeb/Layout/GridFormattingContext.h:311
// Original signature: GridFormattingContext::AvailableSize get_free_space(AvailableSpace const&, GridDimension) const;
pub fn grid_formatting_context_h_311_get_free_space() LayoutStub {
	return layout_stub('GridFormattingContext.h:311 get_free_space')
}

// Translated from Libraries/LibWeb/Layout/GridFormattingContext.h:313
// Original signature: GridFormattingContext::Optional<int> get_nth_line_index_by_line_name(GridDimension dimension, String const&, int line_number);
pub fn grid_formatting_context_h_313_get_nth_line_index_by_line_name() LayoutStub {
	return layout_stub('GridFormattingContext.h:313 get_nth_line_index_by_line_name')
}

// Translated from Libraries/LibWeb/Layout/GridFormattingContext.h:314
// Original signature: GridFormattingContext::CSSPixels resolve_definite_track_size(CSS::GridSize const&, AvailableSpace const&) const;
pub fn grid_formatting_context_h_314_resolve_definite_track_size() LayoutStub {
	return layout_stub('GridFormattingContext.h:314 resolve_definite_track_size')
}

// Translated from Libraries/LibWeb/Layout/GridFormattingContext.h:315
// Original signature: GridFormattingContext::int count_of_repeated_auto_fill_or_fit_tracks(GridDimension, CSS::ExplicitGridTrack const& repeated_track);
pub fn grid_formatting_context_h_315_count_of_repeated_auto_fill_or_fit_tracks() LayoutStub {
	return layout_stub('GridFormattingContext.h:315 count_of_repeated_auto_fill_or_fit_tracks')
}

// Translated from Libraries/LibWeb/Layout/GridFormattingContext.h:317
// Original signature: GridFormattingContext::void build_grid_areas();
pub fn grid_formatting_context_h_317_build_grid_areas() LayoutStub {
	return layout_stub('GridFormattingContext.h:317 build_grid_areas')
}

// Translated from Libraries/LibWeb/Layout/GridFormattingContext.h:324
// Original signature: GridFormattingContext::PlacementPosition resolve_grid_position(Box const& child_box, GridDimension dimension);
pub fn grid_formatting_context_h_324_resolve_grid_position() LayoutStub {
	return layout_stub('GridFormattingContext.h:324 resolve_grid_position')
}

// Translated from Libraries/LibWeb/Layout/GridFormattingContext.h:325
// Original signature: GridFormattingContext::size_t resolve_grid_span(Box const& child_box, GridDimension dimension) const;
pub fn grid_formatting_context_h_325_resolve_grid_span() LayoutStub {
	return layout_stub('GridFormattingContext.h:325 resolve_grid_span')
}

// Translated from Libraries/LibWeb/Layout/GridFormattingContext.h:327
// Original signature: GridFormattingContext::void place_grid_items();
pub fn grid_formatting_context_h_327_place_grid_items() LayoutStub {
	return layout_stub('GridFormattingContext.h:327 place_grid_items')
}

// Translated from Libraries/LibWeb/Layout/GridFormattingContext.h:328
// Original signature: GridFormattingContext::void place_item_with_row_and_column_position(Box const& child_box);
pub fn grid_formatting_context_h_328_place_item_with_row_and_column_position() LayoutStub {
	return layout_stub('GridFormattingContext.h:328 place_item_with_row_and_column_position')
}

// Translated from Libraries/LibWeb/Layout/GridFormattingContext.h:329
// Original signature: GridFormattingContext::void place_item_with_row_position(Box const& child_box);
pub fn grid_formatting_context_h_329_place_item_with_row_position() LayoutStub {
	return layout_stub('GridFormattingContext.h:329 place_item_with_row_position')
}

// Translated from Libraries/LibWeb/Layout/GridFormattingContext.h:330
// Original signature: GridFormattingContext::void place_item_with_column_position(Box const& child_box, int& auto_placement_cursor_row);
pub fn grid_formatting_context_h_330_place_item_with_column_position() LayoutStub {
	return layout_stub('GridFormattingContext.h:330 place_item_with_column_position')
}

// Translated from Libraries/LibWeb/Layout/GridFormattingContext.h:331
// Original signature: GridFormattingContext::void place_item_with_no_declared_position(Box const& child_box, int& auto_placement_cursor_column, int& auto_placement_cursor_row);
pub fn grid_formatting_context_h_331_place_item_with_no_declared_position() LayoutStub {
	return layout_stub('GridFormattingContext.h:331 place_item_with_no_declared_position')
}

// Translated from Libraries/LibWeb/Layout/GridFormattingContext.h:332
// Original signature: GridFormattingContext::void record_grid_placement(GridItem);
pub fn grid_formatting_context_h_332_record_grid_placement() LayoutStub {
	return layout_stub('GridFormattingContext.h:332 record_grid_placement')
}

// Translated from Libraries/LibWeb/Layout/GridFormattingContext.h:334
// Original signature: GridFormattingContext::void initialize_grid_tracks_from_definition(GridDimension);
pub fn grid_formatting_context_h_334_initialize_grid_tracks_from_definition() LayoutStub {
	return layout_stub('GridFormattingContext.h:334 initialize_grid_tracks_from_definition')
}

// Translated from Libraries/LibWeb/Layout/GridFormattingContext.h:335
// Original signature: GridFormattingContext::void initialize_grid_tracks_for_columns_and_rows();
pub fn grid_formatting_context_h_335_initialize_grid_tracks_for_columns_and_rows() LayoutStub {
	return layout_stub('GridFormattingContext.h:335 initialize_grid_tracks_for_columns_and_rows')
}

// Translated from Libraries/LibWeb/Layout/GridFormattingContext.h:336
// Original signature: GridFormattingContext::void initialize_gap_tracks(AvailableSpace const&);
pub fn grid_formatting_context_h_336_initialize_gap_tracks() LayoutStub {
	return layout_stub('GridFormattingContext.h:336 initialize_gap_tracks')
}

// Translated from Libraries/LibWeb/Layout/GridFormattingContext.h:338
// Original signature: GridFormattingContext::void collapse_auto_fit_tracks_if_needed(GridDimension);
pub fn grid_formatting_context_h_338_collapse_auto_fit_tracks_if_needed() LayoutStub {
	return layout_stub('GridFormattingContext.h:338 collapse_auto_fit_tracks_if_needed')
}

// Translated from Libraries/LibWeb/Layout/GridFormattingContext.h:347
// Original signature: GridFormattingContext::void distribute_extra_space_across_spanned_tracks_base_size(GridDimension dimension, CSSPixels item_size_contribution, SpaceDistributionPhase phase, Vector<GridTrack&>& spanned_tracks, Match matcher);
pub fn grid_formatting_context_h_347_distribute_extra_space_across_spanned_tracks_base_size() LayoutStub {
	return layout_stub('GridFormattingContext.h:347 distribute_extra_space_across_spanned_tracks_base_size')
}

// Translated from Libraries/LibWeb/Layout/GridFormattingContext.h:350
// Original signature: GridFormattingContext::void distribute_extra_space_across_spanned_tracks_growth_limit(CSSPixels item_size_contribution, Vector<GridTrack&>& spanned_tracks, Match matcher);
pub fn grid_formatting_context_h_350_distribute_extra_space_across_spanned_tracks_growth_limit() LayoutStub {
	return layout_stub('GridFormattingContext.h:350 distribute_extra_space_across_spanned_tracks_growth_limit')
}

// Translated from Libraries/LibWeb/Layout/GridFormattingContext.h:352
// Original signature: GridFormattingContext::void initialize_track_sizes(GridDimension);
pub fn grid_formatting_context_h_352_initialize_track_sizes() LayoutStub {
	return layout_stub('GridFormattingContext.h:352 initialize_track_sizes')
}

// Translated from Libraries/LibWeb/Layout/GridFormattingContext.h:353
// Original signature: GridFormattingContext::void resolve_intrinsic_track_sizes(GridDimension);
pub fn grid_formatting_context_h_353_resolve_intrinsic_track_sizes() LayoutStub {
	return layout_stub('GridFormattingContext.h:353 resolve_intrinsic_track_sizes')
}

// Translated from Libraries/LibWeb/Layout/GridFormattingContext.h:354
// Original signature: GridFormattingContext::void increase_sizes_to_accommodate_spanning_items_crossing_content_sized_tracks(GridDimension, size_t span);
pub fn grid_formatting_context_h_354_increase_sizes_to_accommodate_spanning_items_crossing_content_sized_tracks() LayoutStub {
	return layout_stub('GridFormattingContext.h:354 increase_sizes_to_accommodate_spanning_items_crossing_content_sized_tracks')
}

// Translated from Libraries/LibWeb/Layout/GridFormattingContext.h:355
// Original signature: GridFormattingContext::void increase_sizes_to_accommodate_spanning_items_crossing_flexible_tracks(GridDimension);
pub fn grid_formatting_context_h_355_increase_sizes_to_accommodate_spanning_items_crossing_flexible_tracks() LayoutStub {
	return layout_stub('GridFormattingContext.h:355 increase_sizes_to_accommodate_spanning_items_crossing_flexible_tracks')
}

// Translated from Libraries/LibWeb/Layout/GridFormattingContext.h:356
// Original signature: GridFormattingContext::void maximize_tracks_using_available_size(AvailableSpace const& available_space, GridDimension dimension);
pub fn grid_formatting_context_h_356_maximize_tracks_using_available_size() LayoutStub {
	return layout_stub('GridFormattingContext.h:356 maximize_tracks_using_available_size')
}

// Translated from Libraries/LibWeb/Layout/GridFormattingContext.h:357
// Original signature: GridFormattingContext::void maximize_tracks(GridDimension);
pub fn grid_formatting_context_h_357_maximize_tracks() LayoutStub {
	return layout_stub('GridFormattingContext.h:357 maximize_tracks')
}

// Translated from Libraries/LibWeb/Layout/GridFormattingContext.h:358
// Original signature: GridFormattingContext::void expand_flexible_tracks(GridDimension);
pub fn grid_formatting_context_h_358_expand_flexible_tracks() LayoutStub {
	return layout_stub('GridFormattingContext.h:358 expand_flexible_tracks')
}

// Translated from Libraries/LibWeb/Layout/GridFormattingContext.h:359
// Original signature: GridFormattingContext::void stretch_auto_tracks(GridDimension);
pub fn grid_formatting_context_h_359_stretch_auto_tracks() LayoutStub {
	return layout_stub('GridFormattingContext.h:359 stretch_auto_tracks')
}

// Translated from Libraries/LibWeb/Layout/GridFormattingContext.h:360
// Original signature: GridFormattingContext::void run_track_sizing(GridDimension);
pub fn grid_formatting_context_h_360_run_track_sizing() LayoutStub {
	return layout_stub('GridFormattingContext.h:360 run_track_sizing')
}

// Translated from Libraries/LibWeb/Layout/GridFormattingContext.h:362
// Original signature: GridFormattingContext::CSSPixels calculate_grid_container_maximum_size(GridDimension) const;
pub fn grid_formatting_context_h_362_calculate_grid_container_maximum_size() LayoutStub {
	return layout_stub('GridFormattingContext.h:362 calculate_grid_container_maximum_size')
}

// Translated from Libraries/LibWeb/Layout/GridFormattingContext.h:364
// Original signature: GridFormattingContext::CSSPixels calculate_min_content_size(GridItem const&, GridDimension) const;
pub fn grid_formatting_context_h_364_calculate_min_content_size() LayoutStub {
	return layout_stub('GridFormattingContext.h:364 calculate_min_content_size')
}

// Translated from Libraries/LibWeb/Layout/GridFormattingContext.h:365
// Original signature: GridFormattingContext::CSSPixels calculate_max_content_size(GridItem const&, GridDimension) const;
pub fn grid_formatting_context_h_365_calculate_max_content_size() LayoutStub {
	return layout_stub('GridFormattingContext.h:365 calculate_max_content_size')
}

// Translated from Libraries/LibWeb/Layout/GridFormattingContext.h:367
// Original signature: GridFormattingContext::CSSPixels calculate_min_content_contribution(GridItem const&, GridDimension) const;
pub fn grid_formatting_context_h_367_calculate_min_content_contribution() LayoutStub {
	return layout_stub('GridFormattingContext.h:367 calculate_min_content_contribution')
}

// Translated from Libraries/LibWeb/Layout/GridFormattingContext.h:368
// Original signature: GridFormattingContext::CSSPixels calculate_max_content_contribution(GridItem const&, GridDimension) const;
pub fn grid_formatting_context_h_368_calculate_max_content_contribution() LayoutStub {
	return layout_stub('GridFormattingContext.h:368 calculate_max_content_contribution')
}

// Translated from Libraries/LibWeb/Layout/GridFormattingContext.h:370
// Original signature: GridFormattingContext::CSSPixels calculate_limited_min_content_contribution(GridItem const&, GridDimension) const;
pub fn grid_formatting_context_h_370_calculate_limited_min_content_contribution() LayoutStub {
	return layout_stub('GridFormattingContext.h:370 calculate_limited_min_content_contribution')
}

// Translated from Libraries/LibWeb/Layout/GridFormattingContext.h:371
// Original signature: GridFormattingContext::CSSPixels calculate_limited_max_content_contribution(GridItem const&, GridDimension) const;
pub fn grid_formatting_context_h_371_calculate_limited_max_content_contribution() LayoutStub {
	return layout_stub('GridFormattingContext.h:371 calculate_limited_max_content_contribution')
}

// Translated from Libraries/LibWeb/Layout/GridFormattingContext.h:373
// Original signature: GridFormattingContext::CSSPixels containing_block_size_for_item(GridItem const&, GridDimension) const;
pub fn grid_formatting_context_h_373_containing_block_size_for_item() LayoutStub {
	return layout_stub('GridFormattingContext.h:373 containing_block_size_for_item')
}

// Translated from Libraries/LibWeb/Layout/GridFormattingContext.h:375
// Original signature: GridFormattingContext::CSSPixelRect get_grid_area_rect(GridItem const&) const;
pub fn grid_formatting_context_h_375_get_grid_area_rect() LayoutStub {
	return layout_stub('GridFormattingContext.h:375 get_grid_area_rect')
}

// Translated from Libraries/LibWeb/Layout/GridFormattingContext.h:377
// Original signature: GridFormattingContext::CSSPixels content_size_suggestion(GridItem const&, GridDimension) const;
pub fn grid_formatting_context_h_377_content_size_suggestion() LayoutStub {
	return layout_stub('GridFormattingContext.h:377 content_size_suggestion')
}

// Translated from Libraries/LibWeb/Layout/GridFormattingContext.h:378
// Original signature: GridFormattingContext::Optional<CSSPixels> specified_size_suggestion(GridItem const&, GridDimension) const;
pub fn grid_formatting_context_h_378_specified_size_suggestion() LayoutStub {
	return layout_stub('GridFormattingContext.h:378 specified_size_suggestion')
}

// Translated from Libraries/LibWeb/Layout/GridFormattingContext.h:379
// Original signature: GridFormattingContext::Optional<CSSPixels> transferred_size_suggestion(GridItem const&, GridDimension) const;
pub fn grid_formatting_context_h_379_transferred_size_suggestion() LayoutStub {
	return layout_stub('GridFormattingContext.h:379 transferred_size_suggestion')
}

// Translated from Libraries/LibWeb/Layout/GridFormattingContext.h:380
// Original signature: GridFormattingContext::CSSPixels content_based_minimum_size(GridItem const&, GridDimension) const;
pub fn grid_formatting_context_h_380_content_based_minimum_size() LayoutStub {
	return layout_stub('GridFormattingContext.h:380 content_based_minimum_size')
}

// Translated from Libraries/LibWeb/Layout/GridFormattingContext.h:381
// Original signature: GridFormattingContext::CSSPixels automatic_minimum_size(GridItem const&, GridDimension) const;
pub fn grid_formatting_context_h_381_automatic_minimum_size() LayoutStub {
	return layout_stub('GridFormattingContext.h:381 automatic_minimum_size')
}

// Translated from Libraries/LibWeb/Layout/GridFormattingContext.h:382
// Original signature: GridFormattingContext::CSSPixels calculate_minimum_contribution(GridItem const&, GridDimension) const;
pub fn grid_formatting_context_h_382_calculate_minimum_contribution() LayoutStub {
	return layout_stub('GridFormattingContext.h:382 calculate_minimum_contribution')
}

// ---- GridFormattingContext.cpp (74 translated function stubs) ----

// Translated from Libraries/LibWeb/Layout/GridFormattingContext.cpp:16
// Original signature: static CSSPixels gap_to_px(Variant<CSS::LengthPercentage, CSS::NormalGap> const& gap, Layout::Node const& grid_container, CSSPixels reference_value)
pub fn grid_formatting_context_cpp_16_gap_to_px() LayoutStub {
	return layout_stub('GridFormattingContext.cpp:16 gap_to_px')
}

// Translated from Libraries/LibWeb/Layout/GridFormattingContext.cpp:23
// Original signature: static Alignment to_alignment(CSS::JustifyContent value)
pub fn grid_formatting_context_cpp_23_to_alignment() LayoutStub {
	return layout_stub('GridFormattingContext.cpp:23 to_alignment')
}

// Translated from Libraries/LibWeb/Layout/GridFormattingContext.cpp:53
// Original signature: static Alignment to_alignment(CSS::JustifyItems value)
pub fn grid_formatting_context_cpp_53_to_alignment() LayoutStub {
	return layout_stub('GridFormattingContext.cpp:53 to_alignment')
}

// Translated from Libraries/LibWeb/Layout/GridFormattingContext.cpp:91
// Original signature: static Alignment to_alignment(CSS::AlignContent value)
pub fn grid_formatting_context_cpp_91_to_alignment() LayoutStub {
	return layout_stub('GridFormattingContext.cpp:91 to_alignment')
}

// Translated from Libraries/LibWeb/Layout/GridFormattingContext.cpp:119
// Original signature: static Alignment to_alignment(CSS::AlignItems value)
pub fn grid_formatting_context_cpp_119_to_alignment() LayoutStub {
	return layout_stub('GridFormattingContext.cpp:119 to_alignment')
}

// Translated from Libraries/LibWeb/Layout/GridFormattingContext.cpp:151
// Original signature: GridFormattingContext::GridTrack GridFormattingContext::GridTrack::create_from_definition(CSS::ExplicitGridTrack const& definition, bool is_auto_fit = false)
// NOTE: repeat() is expected to be expanded beforehand.
// https://drafts.csswg.org/css-grid-2/#algo-terms
// min track sizing function:
// If the track was sized with a minmax() function, this is the first argument to that function.
// If the track was sized with a <flex> value or fit-content() function, auto. Otherwise, the track's sizing
// function.
pub fn grid_formatting_context_cpp_151_grid_formatting_context_grid_track_create_from_definition() LayoutStub {
	return layout_stub('GridFormattingContext.cpp:151 GridFormattingContext::GridTrack::create_from_definition')
}

// Translated from Libraries/LibWeb/Layout/GridFormattingContext.cpp:181
// Original signature: GridFormattingContext::GridTrack GridFormattingContext::GridTrack::create_auto()
pub fn grid_formatting_context_cpp_181_grid_formatting_context_grid_track_create_auto() LayoutStub {
	return layout_stub('GridFormattingContext.cpp:181 GridFormattingContext::GridTrack::create_auto')
}

// Translated from Libraries/LibWeb/Layout/GridFormattingContext.cpp:189
// Original signature: GridFormattingContext::GridTrack GridFormattingContext::GridTrack::create_gap(CSSPixels size)
pub fn grid_formatting_context_cpp_189_grid_formatting_context_grid_track_create_gap() LayoutStub {
	return layout_stub('GridFormattingContext.cpp:189 GridFormattingContext::GridTrack::create_gap')
}

// Translated from Libraries/LibWeb/Layout/GridFormattingContext.cpp:199
// Original signature: GridFormattingContext::GridFormattingContext(LayoutState& state, LayoutMode layout_mode, Box const& grid_container, FormattingContext* parent) : FormattingContext(Type::Grid, layout_mode, state, grid_container, parent) , m_grid_container_used_values(state.get_mutable(grid_container))
pub fn grid_formatting_context_cpp_199_grid_formatting_context_grid_formatting_context() LayoutStub {
	return layout_stub('GridFormattingContext.cpp:199 GridFormattingContext::GridFormattingContext')
}

// Translated from Libraries/LibWeb/Layout/GridFormattingContext.cpp:205
// Original signature: GridFormattingContext::~GridFormattingContext() = default;
pub fn grid_formatting_context_cpp_205_grid_formatting_context_destroy_grid_formatting_context() LayoutStub {
	return layout_stub('GridFormattingContext.cpp:205 GridFormattingContext::~GridFormattingContext')
}

// Translated from Libraries/LibWeb/Layout/GridFormattingContext.cpp:207
// Original signature: CSSPixels GridFormattingContext::resolve_definite_track_size(CSS::GridSize const& grid_size, AvailableSpace const& available_space) const
pub fn grid_formatting_context_cpp_207_grid_formatting_context_resolve_definite_track_size() LayoutStub {
	return layout_stub('GridFormattingContext.cpp:207 GridFormattingContext::resolve_definite_track_size')
}

// Translated from Libraries/LibWeb/Layout/GridFormattingContext.cpp:213
// Original signature: int GridFormattingContext::count_of_repeated_auto_fill_or_fit_tracks(GridDimension dimension, CSS::ExplicitGridTrack const& repeated_track)
// https://www.w3.org/TR/css-grid-2/#auto-repeat
// 7.2.3.2. Repeat-to-fill: auto-fill and auto-fit repetitions
// On a subgridded axis, the auto-fill keyword is only valid once per <line-name-list>, and repeats
// enough times for the name list to match the subgrid's specified grid span (falling back to 0 if
// the span is already fulfilled).
// Otherwise on a standalone axis, when auto-fill is given as the repetition number
// If the grid container has a definite size or max size in the relevant axis, then the number of
// repetitions is the largest possible positive integer that does not cause the grid to overflow the
// content box of its grid container
// (treating each track as its max track sizing function if that is definite or its minimum track sizing
// function otherwise, flooring the max track sizing function by the min track sizing function if both
// are definite, and taking gap into account)
// Otherwise, if the grid container has a definite min size in the relevant axis, the number of repetitions is
// the
// smallest possible positive integer that fulfills that minimum requirement
// NOTE: Gap size is added to free space to compensate for the fact that the last track does not have a gap
// If any number of repetitions would overflow, then 1 repetition.
// Otherwise, the specified track list repeats only once.
// For the purpose of finding the number of auto-repeated tracks in a standalone axis, the UA must
// floor the track size to a UA-specified value to avoid division by zero. It is suggested that this
// floor be 1px.
pub fn grid_formatting_context_cpp_213_grid_formatting_context_count_of_repeated_auto_fill_or_fit_tracks() LayoutStub {
	return layout_stub('GridFormattingContext.cpp:213 GridFormattingContext::count_of_repeated_auto_fill_or_fit_tracks')
}

// Translated from Libraries/LibWeb/Layout/GridFormattingContext.cpp:277
// Original signature: GridFormattingContext::PlacementPosition GridFormattingContext::resolve_grid_position(Box const& child_box, GridDimension dimension)
// FIXME: If a name is given as a <custom-ident>, only lines with that name are counted. If not enough lines with
// that name exist, all implicit grid lines on the side of the explicit grid corresponding to the search
// direction are assumed to have that name for the purpose of counting this span.
// FIXME: Remove me once have implemented spans overflowing into negative indexes, e.g., grid-row: span 2 / 1
// If the placement contains two spans, remove the one contributed by the end grid-placement
// property.
pub fn grid_formatting_context_cpp_277_grid_formatting_context_resolve_grid_position() LayoutStub {
	return layout_stub('GridFormattingContext.cpp:277 GridFormattingContext::resolve_grid_position')
}

// Translated from Libraries/LibWeb/Layout/GridFormattingContext.cpp:372
// Original signature: size_t GridFormattingContext::resolve_grid_span(Box const& child_box, GridDimension dimension) const
pub fn grid_formatting_context_cpp_372_grid_formatting_context_resolve_grid_span() LayoutStub {
	return layout_stub('GridFormattingContext.cpp:372 GridFormattingContext::resolve_grid_span')
}

// Translated from Libraries/LibWeb/Layout/GridFormattingContext.cpp:387
// Original signature: void GridFormattingContext::place_item_with_row_and_column_position(Box const& child_box)
pub fn grid_formatting_context_cpp_387_grid_formatting_context_place_item_with_row_and_column_position() LayoutStub {
	return layout_stub('GridFormattingContext.cpp:387 GridFormattingContext::place_item_with_row_and_column_position')
}

// Translated from Libraries/LibWeb/Layout/GridFormattingContext.cpp:406
// Original signature: void GridFormattingContext::place_item_with_row_position(Box const& child_box)
pub fn grid_formatting_context_cpp_406_grid_formatting_context_place_item_with_row_position() LayoutStub {
	return layout_stub('GridFormattingContext.cpp:406 GridFormattingContext::place_item_with_row_position')
}

// Translated from Libraries/LibWeb/Layout/GridFormattingContext.cpp:436
// Original signature: void GridFormattingContext::place_item_with_column_position(Box const& child_box, int& auto_placement_cursor_row)
// Increment the cursor's row position until a value is found where the grid item does not
// overlap any occupied grid cells (creating new rows in the implicit grid as necessary).
pub fn grid_formatting_context_cpp_436_grid_formatting_context_place_item_with_column_position() LayoutStub {
	return layout_stub('GridFormattingContext.cpp:436 GridFormattingContext::place_item_with_column_position')
}

// Translated from Libraries/LibWeb/Layout/GridFormattingContext.cpp:461
// Original signature: FoundUnoccupiedPlace OccupationGrid::find_unoccupied_place(GridDimension dimension, int& column_index, int& row_index, int column_span, int row_span) const
// Row-flow: columns are the inner (minor) axis, rows are the outer (major) axis.
// Column-flow: rows are the inner (minor) axis, columns are the outer (major) axis.
pub fn grid_formatting_context_cpp_461_occupation_grid_find_unoccupied_place() LayoutStub {
	return layout_stub('GridFormattingContext.cpp:461 OccupationGrid::find_unoccupied_place')
}

// Translated from Libraries/LibWeb/Layout/GridFormattingContext.cpp:492
// Original signature: void GridFormattingContext::place_item_with_no_declared_position(Box const& child_box, int& auto_placement_cursor_column, int& auto_placement_cursor_row)
// 4.1.2.1. Increment the column position of the auto-placement cursor until either this item's grid
// area does not overlap any occupied grid cells, or the cursor's column position, plus the item's
// column span, overflow the number of columns in the implicit grid, as determined earlier in this
// algorithm.
// 4.1.2.2. If a non-overlapping position was found in the previous step, set the item's row-start
// and column-start lines to the cursor's position. Otherwise, increment the auto-placement cursor's
// row position (creating new rows in the implicit grid as necessary), set its column position to the
// start-most column line in the implicit grid, and return to the previous step.
pub fn grid_formatting_context_cpp_492_grid_formatting_context_place_item_with_no_declared_position() LayoutStub {
	return layout_stub('GridFormattingContext.cpp:492 GridFormattingContext::place_item_with_no_declared_position')
}

// Translated from Libraries/LibWeb/Layout/GridFormattingContext.cpp:537
// Original signature: void GridFormattingContext::record_grid_placement(GridItem grid_item)
pub fn grid_formatting_context_cpp_537_grid_formatting_context_record_grid_placement() LayoutStub {
	return layout_stub('GridFormattingContext.cpp:537 GridFormattingContext::record_grid_placement')
}

// Translated from Libraries/LibWeb/Layout/GridFormattingContext.cpp:543
// Original signature: void GridFormattingContext::initialize_grid_tracks_from_definition(GridDimension dimension)
pub fn grid_formatting_context_cpp_543_grid_formatting_context_initialize_grid_tracks_from_definition() LayoutStub {
	return layout_stub('GridFormattingContext.cpp:543 GridFormattingContext::initialize_grid_tracks_from_definition')
}

// Translated from Libraries/LibWeb/Layout/GridFormattingContext.cpp:572
// Original signature: void GridFormattingContext::initialize_grid_tracks_for_columns_and_rows()
// NOTE: If there are implicit tracks created by items with negative indexes they should prepend explicitly
// defined tracks
pub fn grid_formatting_context_cpp_572_grid_formatting_context_initialize_grid_tracks_for_columns_and_rows() LayoutStub {
	return layout_stub('GridFormattingContext.cpp:572 GridFormattingContext::initialize_grid_tracks_for_columns_and_rows')
}

// Translated from Libraries/LibWeb/Layout/GridFormattingContext.cpp:632
// Original signature: void GridFormattingContext::initialize_gap_tracks(AvailableSpace const& available_space)
// https://www.w3.org/TR/css-grid-2/#gutters
// 11.1. Gutters: the row-gap, column-gap, and gap properties
// For the purpose of track sizing, each gutter is treated as an extra, empty, fixed-size track of the specified
// size, which is spanned by any grid items that span across its corresponding grid line.
pub fn grid_formatting_context_cpp_632_grid_formatting_context_initialize_gap_tracks() LayoutStub {
	return layout_stub('GridFormattingContext.cpp:632 GridFormattingContext::initialize_gap_tracks')
}

// Translated from Libraries/LibWeb/Layout/GridFormattingContext.cpp:675
// Original signature: void GridFormattingContext::initialize_track_sizes(GridDimension dimension)
// https://www.w3.org/TR/css-grid-2/#algo-init
// 12.4. Initialize Track Sizes
// Initialize each track's base size and growth limit.
// Normalize fit-content tracks with unresolvable percentage arguments to max-content,
// since the percentage cannot be resolved against an indefinite available size.
// In all cases, if the growth limit is less than the base size, increase the growth limit to match
// the base size.
pub fn grid_formatting_context_cpp_675_grid_formatting_context_initialize_track_sizes() LayoutStub {
	return layout_stub('GridFormattingContext.cpp:675 GridFormattingContext::initialize_track_sizes')
}

// Translated from Libraries/LibWeb/Layout/GridFormattingContext.cpp:724
// Original signature: void GridFormattingContext::resolve_intrinsic_track_sizes(GridDimension dimension)
// https://www.w3.org/TR/css-grid-2/#algo-content
// 12.5. Resolve Intrinsic Track Sizes
// This step resolves intrinsic track sizing functions to absolute lengths. First it resolves those
// sizes based on items that are contained wholly within a single track. Then it gradually adds in
// the space requirements of items that span multiple tracks, evenly distributing the extra space
// across those tracks insofar as possible.
// FIXME: 1. Shim baseline-aligned items so their intrinsic size contributions reflect their baseline alignment.
// 2. Size tracks to fit non-spanning items:
// 3. Increase sizes to accommodate spanning items crossing content-sized tracks: Next, consider the
// items with a span of 2 that do not span a track with a flexible sizing function.
// Repeat incrementally for items with greater spans until all items have been considered.
// 4. Increase sizes to accommodate spanning items crossing flexible tracks: Next, repeat the previous
// step instead considering (together, rather than grouped by span size) all items that do span a
// track with a flexible sizing function while
// 5. If any track still has an infinite growth limit (because, for example, it had no items placed in
// it or it is a flexible track), set its growth limit to its base size.
pub fn grid_formatting_context_cpp_724_grid_formatting_context_resolve_intrinsic_track_sizes() LayoutStub {
	return layout_stub('GridFormattingContext.cpp:724 GridFormattingContext::resolve_intrinsic_track_sizes')
}

// Translated from Libraries/LibWeb/Layout/GridFormattingContext.cpp:765
// Original signature: void GridFormattingContext::distribute_extra_space_across_spanned_tracks_base_size(GridDimension dimension, CSSPixels item_size_contribution, SpaceDistributionPhase phase, Vector<GridTrack&>& spanned_tracks, Match matcher)
// 1. Find the space to distribute:
// Subtract the corresponding size of every spanned track from the item's size contribution to find the item's
// remaining size contribution.
// 2. Distribute space up to limits:
// Find the item-incurred increase for each spanned track with an affected size by: distributing the space
// equally among such tracks, freezing a track's item-incurred increase as its affected size + item-incurred
// increase reaches its limit
// 3. Distribute space beyond limits
// If space remains after all tracks are frozen, unfreeze and continue to
// distribute space to the item-incurred increase of...
// when accommodating minimum contributions or accommodating min-content contributions: any affected track
// that happens to also have an intrinsic max track sizing function
// if there are no such tracks, then all affected tracks.
// when accommodating max-content contributions into base sizes: any affected track that happens to also have
// a max-content max track sizing function;
// 4. For each affected track, if the track's item-incurred increase is larger than the track's planned increase
// set the track's planned increase to that value.
pub fn grid_formatting_context_cpp_765_grid_formatting_context_distribute_extra_space_across_spanned_tracks_bas() LayoutStub {
	return layout_stub('GridFormattingContext.cpp:765 GridFormattingContext::distribute_extra_space_across_spanned_tracks_base_size')
}

// Translated from Libraries/LibWeb/Layout/GridFormattingContext.cpp:865
// Original signature: void GridFormattingContext::distribute_extra_space_across_spanned_tracks_growth_limit(CSSPixels item_size_contribution, Vector<GridTrack&>& spanned_tracks, Match matcher)
// 1. Find the space to distribute:
// Subtract the corresponding size of every spanned track from the item's size contribution to find the item's
// remaining size contribution.
// 2. Distribute space up to limits:
// Find the item-incurred increase for each spanned track with an affected size by: distributing the space
// equally among such tracks, freezing a track's item-incurred increase as its affected size + item-incurred
// increase reaches its limit
// For growth limits, the limit is infinity if it is marked as infinitely growable, and equal to the
// growth limit otherwise.
// FIXME: 3. Distribute space beyond limits
// 4. For each affected track, if the track's item-incurred increase is larger than the track's planned increase
// set the track's planned increase to that value.
pub fn grid_formatting_context_cpp_865_grid_formatting_context_distribute_extra_space_across_spanned_tracks_gro() LayoutStub {
	return layout_stub('GridFormattingContext.cpp:865 GridFormattingContext::distribute_extra_space_across_spanned_tracks_growth_limit')
}

// Translated from Libraries/LibWeb/Layout/GridFormattingContext.cpp:933
// Original signature: void GridFormattingContext::increase_sizes_to_accommodate_spanning_items_crossing_content_sized_tracks(GridDimension dimension, size_t span)
// 1. For intrinsic minimums: First increase the base size of tracks with an intrinsic min track sizing
// function by distributing extra space as needed to accommodate these items' minimum contributions.
// If the grid container is being sized under a min- or max-content constraint, use the items' limited
// min-content contributions in place of their minimum contributions here.
// 2. For content-based minimums: Next continue to increase the base size of tracks with a min track
// sizing function of min-content or max-content by distributing extra space as needed to account for
// these items' min-content contributions.
// 3. For max-content minimums: Next, if the grid container is being sized under a max-content constraint,
// continue to increase the base size of tracks with a min track sizing function of auto or max-content by
// distributing extra space as needed to account for these items' limited max-content contributions.
// 4. If at this point any track's growth limit is now less than its base size, increase its growth limit to
// match its base size.
// 5. For intrinsic maximums: Next increase the growth limit of tracks with an intrinsic max track sizing
// If the affected size is an infinite growth limit, set it to the track's base size plus the planned increase.
// Mark any tracks whose growth limit changed from infinite to finite in this step as infinitely growable
// for the next step.
// 6. For max-content maximums: Lastly continue to increase the growth limit of tracks with a max track
// sizing function of max-content by distributing extra space as needed to account for these items' max-
// content contributions. However, limit the growth of any fit-content() tracks by their fit-content() argument.
pub fn grid_formatting_context_cpp_933_grid_formatting_context_increase_sizes_to_accommodate_spanning_items_cro() LayoutStub {
	return layout_stub('GridFormattingContext.cpp:933 GridFormattingContext::increase_sizes_to_accommodate_spanning_items_crossing_content_sized_tracks')
}

// Translated from Libraries/LibWeb/Layout/GridFormattingContext.cpp:1051
// Original signature: void GridFormattingContext::increase_sizes_to_accommodate_spanning_items_crossing_flexible_tracks(GridDimension dimension)
// https://www.w3.org/TR/css-grid-1/#algo-spanning-flex-items
// 11.5.4. Increase sizes to accommodate spanning items crossing flexible tracks
// If the grid container is being sized under a min- or max-content constraint, use the items' limited
// min-content contributions in place of their minimum contributions here.
// NB: Subtract the space already accounted for by non-flexible spanned tracks (sized in 11.5.3), since only
// the remaining contribution needs to be distributed among flexible tracks.
// Distributing space to flexible tracks:
// - If the sum of the flexible sizing functions of all flexible tracks spanned by the item is greater
// than or equal to one, distributing space to such tracks according to the ratios of their flexible
// sizing functions rather than distributing space equally.
// - If the sum is less than one, distributing that proportion of space according to the ratios of their
// flexible sizing functions and the rest equally.
// FIXME: Handle 0 < total_flex < 1 case separately per spec.
// If at this point any track's growth limit is now less than its base size, increase its growth limit to match
// its base size.
pub fn grid_formatting_context_cpp_1051_grid_formatting_context_increase_sizes_to_accommodate_spanning_items_cr() LayoutStub {
	return layout_stub('GridFormattingContext.cpp:1051 GridFormattingContext::increase_sizes_to_accommodate_spanning_items_crossing_flexible_tracks')
}

// Translated from Libraries/LibWeb/Layout/GridFormattingContext.cpp:1125
// Original signature: void GridFormattingContext::maximize_tracks_using_available_size(AvailableSpace const& available_space, GridDimension dimension)
// https://www.w3.org/TR/css-grid-2/#algo-grow-tracks
// 12.6. Maximize Tracks
// For the purpose of this step: if sizing the grid container under a max-content constraint, the
// free space is infinite; if sizing under a min-content constraint, the free space is zero.
// If the free space is positive, distribute it equally to the base sizes of all tracks, freezing
// tracks as they reach their growth limits (and continuing to grow the unfrozen tracks as needed).
pub fn grid_formatting_context_cpp_1125_grid_formatting_context_maximize_tracks_using_available_size() LayoutStub {
	return layout_stub('GridFormattingContext.cpp:1125 GridFormattingContext::maximize_tracks_using_available_size')
}

// Translated from Libraries/LibWeb/Layout/GridFormattingContext.cpp:1173
// Original signature: void GridFormattingContext::maximize_tracks(GridDimension dimension)
// https://www.w3.org/TR/css-grid-2/#algo-grow-tracks
// 12.6. Maximize Tracks
// If this would cause the grid to be larger than the grid container's inner size as limited by its
// max-width/height, then redo this step, treating the available grid space as equal to the grid
// container's inner size when it's sized to its max-width/height.
pub fn grid_formatting_context_cpp_1173_grid_formatting_context_maximize_tracks() LayoutStub {
	return layout_stub('GridFormattingContext.cpp:1173 GridFormattingContext::maximize_tracks')
}

// Translated from Libraries/LibWeb/Layout/GridFormattingContext.cpp:1215
// Original signature: void GridFormattingContext::expand_flexible_tracks(GridDimension dimension)
// https://drafts.csswg.org/css-grid/#algo-flex-tracks
// 12.7. Expand Flexible Tracks
// This step sizes flexible tracks using the largest value it can assign to an fr without exceeding
// the available space.
// FIXME: This should ideally take a Span, as that is more idomatic, but Span does not yet support holding
// references
// https://www.w3.org/TR/css-grid-2/#algo-find-fr-size
// 1. Let leftover space be the space to fill minus the base sizes of the non-flexible grid tracks.
// 2. Let flex factor sum be the sum of the flex factors of the flexible tracks.
// If this value is less than 1, set it to 1 instead.
// 3. Let the hypothetical fr size be the leftover space divided by the flex factor sum.
// 4. If the product of the hypothetical fr size and a flexible track's flex factor is less than the track's
// base size, restart this algorithm treating all such tracks as inflexible.
// 5. Return the hypothetical fr size.
// First, find the grid's used flex fraction:
// If the free space is zero or if sizing the grid container under a min-content constraint:
// The used flex fraction is zero.
// Otherwise, if the free space is a definite length:
// The used flex fraction is the result of finding the size of an fr using all of the grid tracks and a space
// to fill of the available grid space.
// Otherwise, if the free space is an indefinite length:
// The used flex fraction is the maximum of:
// For each flexible track, if the flexible track's flex factor is greater than one, the result of dividing
// the track's base size by its flex factor; otherwise, the track's base size.
// For each grid item that crosses a flexible track, the result of finding the size of an fr using all the
// grid tracks that the item crosses and a space to fill of the item's max-content contribution.
// For each flexible track, if the product of the used flex fraction and the track's flex factor is greater than
// the track's base size, set its base size to that product.
pub fn grid_formatting_context_cpp_1215_grid_formatting_context_expand_flexible_tracks() LayoutStub {
	return layout_stub('GridFormattingContext.cpp:1215 GridFormattingContext::expand_flexible_tracks')
}

// Translated from Libraries/LibWeb/Layout/GridFormattingContext.cpp:1332
// Original signature: void GridFormattingContext::stretch_auto_tracks(GridDimension dimension)
// https://www.w3.org/TR/css-grid-2/#algo-stretch
// 12.8. Stretch auto Tracks
// This step expands tracks that have an auto max track sizing function by dividing any remaining positive,
// definite free space equally amongst them. If the free space is indefinite, but the grid container has a
// definite min-width/height, use that size to calculate the free space for this step instead.
pub fn grid_formatting_context_cpp_1332_grid_formatting_context_stretch_auto_tracks() LayoutStub {
	return layout_stub('GridFormattingContext.cpp:1332 GridFormattingContext::stretch_auto_tracks')
}

// Translated from Libraries/LibWeb/Layout/GridFormattingContext.cpp:1373
// Original signature: void GridFormattingContext::run_track_sizing(GridDimension dimension)
// https://www.w3.org/TR/css-grid-2/#algo-track-sizing
// 12.3. Track Sizing Algorithm
// 1. Initialize Track Sizes
// 2. Resolve Intrinsic Track Sizes
// 3. Maximize Tracks
// 4. Expand Flexible Tracks
// 5. Expand Stretched auto Tracks
// If calculating the layout of a grid item in this step depends on the available space in the block
// axis, assume the available space that it would have if any row with a definite max track sizing
// function had that size and all other rows were infinite. If both the grid container and all
// tracks have definite sizes, also apply align-content to find the final effective size of any gaps
// spanned by such items; otherwise ignore the effects of track alignment in this estimation.
pub fn grid_formatting_context_cpp_1373_grid_formatting_context_run_track_sizing() LayoutStub {
	return layout_stub('GridFormattingContext.cpp:1373 GridFormattingContext::run_track_sizing')
}

// Translated from Libraries/LibWeb/Layout/GridFormattingContext.cpp:1402
// Original signature: void GridFormattingContext::build_grid_areas()
// https://www.w3.org/TR/css-grid-2/#implicitly-assigned-line-name
// 7.3.2. Implicitly-Assigned Line Names
// The grid-template-areas property generates implicitly-assigned line names from the named grid areas in the
// template. For each named grid area foo, four implicitly-assigned line names are created: two named foo-start,
// naming the row-start and column-start lines of the named grid area, and two named foo-end, naming the row-end
// and column-end lines of the named grid area.
pub fn grid_formatting_context_cpp_1402_grid_formatting_context_build_grid_areas() LayoutStub {
	return layout_stub('GridFormattingContext.cpp:1402 GridFormattingContext::build_grid_areas')
}

// Translated from Libraries/LibWeb/Layout/GridFormattingContext.cpp:1434
// Original signature: void GridFormattingContext::place_grid_items()
// https://drafts.csswg.org/css-grid/#overview-placement
// 2.2. Placing Items
// The contents of the grid container are organized into individual grid items (analogous to
// flex items), which are then assigned to predefined areas in the grid. They can be explicitly
// placed using coordinates through the grid-placement properties or implicitly placed into
// empty areas using auto-placement.
// https://drafts.csswg.org/css-grid/#auto-placement-algo
// 8.5. Grid Item Placement Algorithm
// FIXME: 0. Generate anonymous grid items
// 1. Position anything that's not auto-positioned.
// 2. Process the items locked to a given row.
// 3. Determine the columns in the implicit grid.
// NOTE: "implicit grid" here is the same as the m_occupation_grid
// 3.1. Start with the columns from the explicit grid.
// NOTE: Done in step 1.
// 3.2. Among all the items with a definite column position (explicitly positioned items, items
// positioned in the previous step, and items not yet positioned but with a definite column) add
// columns to the beginning and end of the implicit grid as necessary to accommodate those items.
// NOTE: "Explicitly positioned items" and "items positioned in the previous step" done in step 1
// and 2, respectively. Adding columns for "items not yet positioned but with a definite column"
// will be done in step 4.
// 3.3. If the largest column span among all the items without a definite column position is larger
// than the width of the implicit grid, add columns to the end of the implicit grid to accommodate
// that column span.
// 4. Position the remaining grid items.
// For each grid item that hasn't been positioned by the previous steps, in order-modified document
// order:
// 4.1.1 / 4.2.1: Item with definite column position.
// Dense: reset row cursor to start of implicit grid.
// Sparse: if column moved backward, bump row.
// 4.1.2 / 4.2.2: Item with auto position in both axes.
// Dense: reset cursor to start of implicit grid.
// NOTE: When final implicit grid sizes are known, we can offset their positions so leftmost grid track has 0
// index.
pub fn grid_formatting_context_cpp_1434_grid_formatting_context_place_grid_items() LayoutStub {
	return layout_stub('GridFormattingContext.cpp:1434 GridFormattingContext::place_grid_items')
}

// Translated from Libraries/LibWeb/Layout/GridFormattingContext.cpp:1580
// Original signature: void GridFormattingContext::determine_grid_container_height()
pub fn grid_formatting_context_cpp_1580_grid_formatting_context_determine_grid_container_height() LayoutStub {
	return layout_stub('GridFormattingContext.cpp:1580 GridFormattingContext::determine_grid_container_height')
}

// Translated from Libraries/LibWeb/Layout/GridFormattingContext.cpp:1588
// Original signature: Alignment GridFormattingContext::alignment_for_item(Box const& box, GridDimension dimension) const
pub fn grid_formatting_context_cpp_1588_grid_formatting_context_alignment_for_item() LayoutStub {
	return layout_stub('GridFormattingContext.cpp:1588 GridFormattingContext::alignment_for_item')
}

// Translated from Libraries/LibWeb/Layout/GridFormattingContext.cpp:1658
// Original signature: void GridFormattingContext::resolve_grid_item_sizes(GridDimension dimension)
// Auto margins absorb positive free space prior to alignment via the box alignment properties.
// OPTIMIZATION: For auto-sized items with stretch/normal alignment and no auto margins, the item stretches
// to fill the containing block. We can compute this directly without the expensive
// calculate_fit_content_width/height calls that trigger intrinsic sizing.
// NB: When the item has a preferred aspect ratio and a definite width, resolve the
// height through the aspect ratio instead of using fit-content sizing, which would
// incorrectly use the available width (grid area width) instead of the item's width.
pub fn grid_formatting_context_cpp_1658_grid_formatting_context_resolve_grid_item_sizes() LayoutStub {
	return layout_stub('GridFormattingContext.cpp:1658 GridFormattingContext::resolve_grid_item_sizes')
}

// Translated from Libraries/LibWeb/Layout/GridFormattingContext.cpp:1811
// Original signature: void GridFormattingContext::resolve_track_spacing(GridDimension dimension)
pub fn grid_formatting_context_cpp_1811_grid_formatting_context_resolve_track_spacing() LayoutStub {
	return layout_stub('GridFormattingContext.cpp:1811 GridFormattingContext::resolve_track_spacing')
}

// Translated from Libraries/LibWeb/Layout/GridFormattingContext.cpp:1864
// Original signature: void GridFormattingContext::resolve_items_box_metrics(GridDimension dimension)
pub fn grid_formatting_context_cpp_1864_grid_formatting_context_resolve_items_box_metrics() LayoutStub {
	return layout_stub('GridFormattingContext.cpp:1864 GridFormattingContext::resolve_items_box_metrics')
}

// Translated from Libraries/LibWeb/Layout/GridFormattingContext.cpp:1892
// Original signature: void GridFormattingContext::collapse_auto_fit_tracks_if_needed(GridDimension dimension)
// https://www.w3.org/TR/css-grid-2/#auto-repeat
// The auto-fit keyword behaves the same as auto-fill, except that after grid item placement any
// empty repeated tracks are collapsed. An empty track is one with no in-flow grid items placed into
// or spanning across it. (This can result in all tracks being collapsed, if they're all empty.)
// NOTE: A collapsed track is treated as having a fixed track sizing function of 0px
pub fn grid_formatting_context_cpp_1892_grid_formatting_context_collapse_auto_fit_tracks_if_needed() LayoutStub {
	return layout_stub('GridFormattingContext.cpp:1892 GridFormattingContext::collapse_auto_fit_tracks_if_needed')
}

// Translated from Libraries/LibWeb/Layout/GridFormattingContext.cpp:1911
// Original signature: CSSPixelRect GridFormattingContext::get_grid_area_rect(GridItem const& grid_item) const
// https://www.w3.org/TR/css-grid-2/#abspos-items
// Instead of auto-placement, an auto value for a grid-placement property contributes a special line to the
// placement whose position
// is that of the corresponding padding edge of the grid container (the padding edge of the scrollable area, if
// the grid container
// overflows). These lines become the first and last lines (0th and -0th) of the augmented grid used for
// positioning absolutely-positioned items.
pub fn grid_formatting_context_cpp_1911_grid_formatting_context_get_grid_area_rect() LayoutStub {
	return layout_stub('GridFormattingContext.cpp:1911 GridFormattingContext::get_grid_area_rect')
}

// Translated from Libraries/LibWeb/Layout/GridFormattingContext.cpp:2030
// Original signature: void GridFormattingContext::run(AvailableSpace const& available_space)
// OPTIMIZATION: If we're in intrinsic sizing layout, but the grid container is not the
// box being measured, we can skip everything here.
// The parent formatting context has already figured out our size anyway.
// NOTE: We store explicit grid sizes to later use in determining the position of items with negative index.
// NOTE: As the containing blocks of grid items are created by implicit grid areas that are not present in the
// layout tree, the initial value of has_definite_width/height computed by LayoutState::UsedValues::set_node
// will be incorrect for anything other (auto, percentage, calculated) than fixed lengths.
// Therefor, it becomes necessary to reset this value to indefinite.
// TODO: Handle this in LayoutState::UsedValues::set_node
// Do the first pass of resolving grid items box metrics to compute values that are independent of a track width
// Do the second pass of resolving box metrics to compute values that depend on a track width
// Once the sizes of column tracks, which determine the widths of the grid areas forming the containing blocks
// for grid items, ara calculated, it becomes possible to determine the final widths of the grid items.
// Do the first pass of resolving grid items box metrics to compute values that are independent of a track height
// Do the second pass of resolving box metrics to compute values that depend on a track height
// getComputedStyle() needs to return the resolved values of grid-template-columns and grid-template-rows
// so they need to be saved in the state, and then assigned to paintables in LayoutState::commit()
pub fn grid_formatting_context_cpp_2030_grid_formatting_context_run() LayoutStub {
	return layout_stub('GridFormattingContext.cpp:2030 GridFormattingContext::run')
}

// Translated from Libraries/LibWeb/Layout/GridFormattingContext.cpp:2154
// Original signature: AbsposContainingBlockInfo GridFormattingContext::resolve_abspos_containing_block_info(Box const& box)
// https://www.w3.org/TR/css-grid-2/#abspos-items
// NOTE: Grid areas form containing blocks for abspos elements, but
// `Node::containing_block()` is not aware of that. Therefore, we need to
// find the closest grid item ancestor in order to identify grid area it belongs to.
// NOTE: If abspos box is contained by in-flow grid item its grid position is already determined.
// Grid always uses InsetFromRect - alignment handles auto inset cases
pub fn grid_formatting_context_cpp_2154_grid_formatting_context_resolve_abspos_containing_block_info() LayoutStub {
	return layout_stub('GridFormattingContext.cpp:2154 GridFormattingContext::resolve_abspos_containing_block_info')
}

// Translated from Libraries/LibWeb/Layout/GridFormattingContext.cpp:2204
// Original signature: void GridFormattingContext::parent_context_did_dimension_child_root_box()
pub fn grid_formatting_context_cpp_2204_grid_formatting_context_parent_context_did_dimension_child_root_box() LayoutStub {
	return layout_stub('GridFormattingContext.cpp:2204 GridFormattingContext::parent_context_did_dimension_child_root_box')
}

// Translated from Libraries/LibWeb/Layout/GridFormattingContext.cpp:2219
// Original signature: void GridFormattingContext::determine_intrinsic_size_of_grid_container(AvailableSpace const& available_space)
// https://www.w3.org/TR/css-grid-1/#intrinsic-sizes
// The max-content size (min-content size) of a grid container is the sum of the grid container's track sizes
// (including gutters) in the appropriate axis, when the grid is sized under a max-content constraint (min-
// content constraint).
pub fn grid_formatting_context_cpp_2219_grid_formatting_context_determine_intrinsic_size_of_grid_container() LayoutStub {
	return layout_stub('GridFormattingContext.cpp:2219 GridFormattingContext::determine_intrinsic_size_of_grid_container')
}

// Translated from Libraries/LibWeb/Layout/GridFormattingContext.cpp:2242
// Original signature: CSSPixels GridFormattingContext::automatic_content_width() const
pub fn grid_formatting_context_cpp_2242_grid_formatting_context_automatic_content_width() LayoutStub {
	return layout_stub('GridFormattingContext.cpp:2242 GridFormattingContext::automatic_content_width')
}

// Translated from Libraries/LibWeb/Layout/GridFormattingContext.cpp:2247
// Original signature: CSSPixels GridFormattingContext::automatic_content_height() const
pub fn grid_formatting_context_cpp_2247_grid_formatting_context_automatic_content_height() LayoutStub {
	return layout_stub('GridFormattingContext.cpp:2247 GridFormattingContext::automatic_content_height')
}

// Translated from Libraries/LibWeb/Layout/GridFormattingContext.cpp:2252
// Original signature: bool GridFormattingContext::is_auto_positioned_track(CSS::GridTrackPlacement const& grid_track_start, CSS::GridTrackPlacement const& grid_track_end) const
pub fn grid_formatting_context_cpp_2252_grid_formatting_context_is_auto_positioned_track() LayoutStub {
	return layout_stub('GridFormattingContext.cpp:2252 GridFormattingContext::is_auto_positioned_track')
}

// Translated from Libraries/LibWeb/Layout/GridFormattingContext.cpp:2257
// Original signature: AvailableSize GridFormattingContext::get_free_space(AvailableSpace const& available_space, GridDimension dimension) const
// https://www.w3.org/TR/css-grid-2/#algo-terms
// free space: Equal to the available grid space minus the sum of the base sizes of all the grid
// tracks (including gutters), floored at zero. If available grid space is indefinite, the free
// space is indefinite as well.
pub fn grid_formatting_context_cpp_2257_grid_formatting_context_get_free_space() LayoutStub {
	return layout_stub('GridFormattingContext.cpp:2257 GridFormattingContext::get_free_space')
}

// Translated from Libraries/LibWeb/Layout/GridFormattingContext.cpp:2275
// Original signature: Optional<int> GridFormattingContext::get_nth_line_index_by_line_name(GridDimension dimension, String const& line_name, int nth_line)
// FIXME: If not enough lines with the name exist, all implicit grid lines on the side
// of the explicit grid corresponding to the search direction are assumed to have that name for the purpose of
// counting this span.
// Source: https://drafts.csswg.org/css-grid/#line-placement
// https://drafts.csswg.org/css-grid/#line-placement
// Contributes the nth grid line to the grid item's placement.
pub fn grid_formatting_context_cpp_2275_grid_formatting_context_get_nth_line_index_by_line_name() LayoutStub {
	return layout_stub('GridFormattingContext.cpp:2275 GridFormattingContext::get_nth_line_index_by_line_name')
}

// Translated from Libraries/LibWeb/Layout/GridFormattingContext.cpp:2297
// Original signature: void GridFormattingContext::init_grid_lines(GridDimension dimension)
pub fn grid_formatting_context_cpp_2297_grid_formatting_context_init_grid_lines() LayoutStub {
	return layout_stub('GridFormattingContext.cpp:2297 GridFormattingContext::init_grid_lines')
}

// Translated from Libraries/LibWeb/Layout/GridFormattingContext.cpp:2333
// Original signature: void OccupationGrid::set_occupied(int column_start, int column_end, int row_start, int row_end)
pub fn grid_formatting_context_cpp_2333_occupation_grid_set_occupied() LayoutStub {
	return layout_stub('GridFormattingContext.cpp:2333 OccupationGrid::set_occupied')
}

// Translated from Libraries/LibWeb/Layout/GridFormattingContext.cpp:2347
// Original signature: bool OccupationGrid::is_occupied(int column_index, int row_index) const
pub fn grid_formatting_context_cpp_2347_occupation_grid_is_occupied() LayoutStub {
	return layout_stub('GridFormattingContext.cpp:2347 OccupationGrid::is_occupied')
}

// Translated from Libraries/LibWeb/Layout/GridFormattingContext.cpp:2352
// Original signature: bool OccupationGrid::is_area_occupied(int column_start, int row_start, int column_span, int row_span) const
pub fn grid_formatting_context_cpp_2352_occupation_grid_is_area_occupied() LayoutStub {
	return layout_stub('GridFormattingContext.cpp:2352 OccupationGrid::is_area_occupied')
}

// Translated from Libraries/LibWeb/Layout/GridFormattingContext.cpp:2363
// Original signature: int GridItem::gap_adjusted_row() const
pub fn grid_formatting_context_cpp_2363_grid_item_gap_adjusted_row() LayoutStub {
	return layout_stub('GridFormattingContext.cpp:2363 GridItem::gap_adjusted_row')
}

// Translated from Libraries/LibWeb/Layout/GridFormattingContext.cpp:2368
// Original signature: int GridItem::gap_adjusted_column() const
pub fn grid_formatting_context_cpp_2368_grid_item_gap_adjusted_column() LayoutStub {
	return layout_stub('GridFormattingContext.cpp:2368 GridItem::gap_adjusted_column')
}

// Translated from Libraries/LibWeb/Layout/GridFormattingContext.cpp:2373
// Original signature: CSSPixels GridFormattingContext::calculate_grid_container_maximum_size(GridDimension dimension) const
pub fn grid_formatting_context_cpp_2373_grid_formatting_context_calculate_grid_container_maximum_size() LayoutStub {
	return layout_stub('GridFormattingContext.cpp:2373 GridFormattingContext::calculate_grid_container_maximum_size')
}

// Translated from Libraries/LibWeb/Layout/GridFormattingContext.cpp:2381
// Original signature: CSSPixels GridFormattingContext::calculate_min_content_size(GridItem const& item, GridDimension dimension) const
pub fn grid_formatting_context_cpp_2381_grid_formatting_context_calculate_min_content_size() LayoutStub {
	return layout_stub('GridFormattingContext.cpp:2381 GridFormattingContext::calculate_min_content_size')
}

// Translated from Libraries/LibWeb/Layout/GridFormattingContext.cpp:2389
// Original signature: CSSPixels GridFormattingContext::calculate_max_content_size(GridItem const& item, GridDimension dimension) const
pub fn grid_formatting_context_cpp_2389_grid_formatting_context_calculate_max_content_size() LayoutStub {
	return layout_stub('GridFormattingContext.cpp:2389 GridFormattingContext::calculate_max_content_size')
}

// Translated from Libraries/LibWeb/Layout/GridFormattingContext.cpp:2397
// Original signature: CSSPixels GridFormattingContext::containing_block_size_for_item(GridItem const& item, GridDimension dimension) const
pub fn grid_formatting_context_cpp_2397_grid_formatting_context_containing_block_size_for_item() LayoutStub {
	return layout_stub('GridFormattingContext.cpp:2397 GridFormattingContext::containing_block_size_for_item')
}

// Translated from Libraries/LibWeb/Layout/GridFormattingContext.cpp:2406
// Original signature: CSSPixels GridFormattingContext::calculate_min_content_contribution(GridItem const& item, GridDimension dimension) const
// NOTE: Not defined in spec, but matches other browsers: a scroll container's min-content
// width contribution is 0 because its content can overflow and scroll horizontally.
// This does NOT apply to the row dimension - scroll containers must still contribute
// their content height, otherwise grids with height:min-content collapse rows to 0.
pub fn grid_formatting_context_cpp_2406_grid_formatting_context_calculate_min_content_contribution() LayoutStub {
	return layout_stub('GridFormattingContext.cpp:2406 GridFormattingContext::calculate_min_content_contribution')
}

// Translated from Libraries/LibWeb/Layout/GridFormattingContext.cpp:2445
// Original signature: CSSPixels GridFormattingContext::calculate_max_content_contribution(GridItem const& item, GridDimension dimension) const
pub fn grid_formatting_context_cpp_2445_grid_formatting_context_calculate_max_content_contribution() LayoutStub {
	return layout_stub('GridFormattingContext.cpp:2445 GridFormattingContext::calculate_max_content_contribution')
}

// Translated from Libraries/LibWeb/Layout/GridFormattingContext.cpp:2481
// Original signature: CSSPixels GridFormattingContext::calculate_limited_min_content_contribution(GridItem const& item, GridDimension dimension) const
// The limited min-content contribution of an item is its min-content contribution,
// limited by the max track sizing function (which could be the argument to a fit-content() track
// sizing function) if that is fixed and ultimately floored by its minimum contribution.
// FIXME: limit by max track sizing function instead of grid container maximum size
pub fn grid_formatting_context_cpp_2481_grid_formatting_context_calculate_limited_min_content_contribution() LayoutStub {
	return layout_stub('GridFormattingContext.cpp:2481 GridFormattingContext::calculate_limited_min_content_contribution')
}

// Translated from Libraries/LibWeb/Layout/GridFormattingContext.cpp:2512
// Original signature: CSSPixels GridFormattingContext::calculate_limited_max_content_contribution(GridItem const& item, GridDimension dimension) const
// The limited max-content contribution of an item is its max-content contribution,
// limited by the max track sizing function (which could be the argument to a fit-content() track
// sizing function) if that is fixed and ultimately floored by its minimum contribution.
// FIXME: limit by max track sizing function instead of grid container maximum size
pub fn grid_formatting_context_cpp_2512_grid_formatting_context_calculate_limited_max_content_contribution() LayoutStub {
	return layout_stub('GridFormattingContext.cpp:2512 GridFormattingContext::calculate_limited_max_content_contribution')
}

// Translated from Libraries/LibWeb/Layout/GridFormattingContext.cpp:2533
// Original signature: CSSPixels GridFormattingContext::content_size_suggestion(GridItem const& item, GridDimension dimension) const
// The content size suggestion is the min-content size in the relevant axis
// FIXME: clamped, if it has a preferred aspect ratio, by any definite opposite-axis minimum and maximum sizes
// converted through the aspect ratio.
pub fn grid_formatting_context_cpp_2533_grid_formatting_context_content_size_suggestion() LayoutStub {
	return layout_stub('GridFormattingContext.cpp:2533 GridFormattingContext::content_size_suggestion')
}

// Translated from Libraries/LibWeb/Layout/GridFormattingContext.cpp:2541
// Original signature: Optional<CSSPixels> GridFormattingContext::specified_size_suggestion(GridItem const& item, GridDimension dimension) const
// https://www.w3.org/TR/css-grid-1/#specified-size-suggestion
// If the item's preferred size in the relevant axis is definite, then the specified size suggestion is that
// size.
// It is otherwise undefined.
// FIXME: consider margins, padding and borders because it is outer size.
pub fn grid_formatting_context_cpp_2541_grid_formatting_context_specified_size_suggestion() LayoutStub {
	return layout_stub('GridFormattingContext.cpp:2541 GridFormattingContext::specified_size_suggestion')
}

// Translated from Libraries/LibWeb/Layout/GridFormattingContext.cpp:2556
// Original signature: Optional<CSSPixels> GridFormattingContext::transferred_size_suggestion(GridItem const& item, GridDimension dimension) const
// https://www.w3.org/TR/css-grid-2/#transferred-size-suggestion
// If the item has a preferred aspect ratio and its preferred size in the opposite axis is definite, then the
// transferred
// size suggestion is that size (clamped by the opposite-axis minimum and maximum sizes if they are definite),
// converted
// through the aspect ratio. It is otherwise undefined.
// FIXME: Clamp by opposite-axis minimum and maximum sizes if they are definite
pub fn grid_formatting_context_cpp_2556_grid_formatting_context_transferred_size_suggestion() LayoutStub {
	return layout_stub('GridFormattingContext.cpp:2556 GridFormattingContext::transferred_size_suggestion')
}

// Translated from Libraries/LibWeb/Layout/GridFormattingContext.cpp:2576
// Original signature: CSSPixels GridFormattingContext::content_based_minimum_size(GridItem const& item, GridDimension dimension) const
// https://www.w3.org/TR/css-grid-1/#content-based-minimum-size
// The content-based minimum size for a grid item in a given dimension is its specified size suggestion if it
// exists,
// otherwise its transferred size suggestion if that exists,
// else its content size suggestion.
// However, if in a given dimension the grid item spans only grid tracks that have a fixed max track sizing
// function, then
// its specified size suggestion and content size suggestion in that dimension (and its input from this dimension
// to the
// transferred size suggestion in the opposite dimension) are further clamped to less than or equal to the
// stretch fit into
// the grid area's maximum size in that dimension, as represented by the sum of those grid tracks' max track
// sizing functions
// plus any intervening fixed gutters.
// FIXME: Account for intervening fixed gutters.
// In all cases, the size suggestion is additionally clamped by the maximum size in the affected axis, if it's
// definite.
// If the item is a compressible replaced element, and has a definite preferred size or maximum size in the
// relevant axis,
// the size suggestion is capped by those sizes; for this purpose, any indefinite percentages in these sizes are
// resolved
// against zero (and considered definite).
// FIXME: "compressible replaced element" includes more elements than is_replaced_box().
// NOTE: Implements "for this purpose, any indefinite percentages in these sizes are resolved
// against zero (and considered definite)." part.
pub fn grid_formatting_context_cpp_2576_grid_formatting_context_content_based_minimum_size() LayoutStub {
	return layout_stub('GridFormattingContext.cpp:2576 GridFormattingContext::content_based_minimum_size')
}

// Translated from Libraries/LibWeb/Layout/GridFormattingContext.cpp:2639
// Original signature: CSSPixels GridFormattingContext::automatic_minimum_size(GridItem const& item, GridDimension dimension) const
// To provide a more reasonable default minimum size for grid items, the used value of its automatic minimum size
// in a given axis is the content-based minimum size if all of the following are true:
// - it is not a scroll container
// - it spans at least one track in that axis whose min track sizing function is auto
// - if it spans more than one track in that axis, none of those tracks are flexible
// Otherwise, the automatic minimum size is zero, as usual.
pub fn grid_formatting_context_cpp_2639_grid_formatting_context_automatic_minimum_size() LayoutStub {
	return layout_stub('GridFormattingContext.cpp:2639 GridFormattingContext::automatic_minimum_size')
}

// Translated from Libraries/LibWeb/Layout/GridFormattingContext.cpp:2669
// Original signature: CSSPixels GridFormattingContext::calculate_minimum_contribution(GridItem const& item, GridDimension dimension) const
// The minimum contribution of an item is the smallest outer size it can have.
// Specifically, if the item's computed preferred size behaves as auto or depends on the size of its
// containing block in the relevant axis, its minimum contribution is the outer size that would
// result from assuming the item's used minimum size as its preferred size; else the item's minimum
// contribution is its min-content contribution. Because the minimum contribution often depends on
// the size of the item's content, it is considered a type of intrinsic size contribution.
pub fn grid_formatting_context_cpp_2669_grid_formatting_context_calculate_minimum_contribution() LayoutStub {
	return layout_stub('GridFormattingContext.cpp:2669 GridFormattingContext::calculate_minimum_contribution')
}

// Translated from Libraries/LibWeb/Layout/GridFormattingContext.cpp:2704
// Original signature: StaticPositionRect GridFormattingContext::calculate_static_position_rect(Box const& box) const
// Result of this function is only used when containing block is not a grid container.
// If the containing block is a grid container then static position is a grid area rect and
// layout_absolutely_positioned_element() defined for GFC knows how to handle this case.
pub fn grid_formatting_context_cpp_2704_grid_formatting_context_calculate_static_position_rect() LayoutStub {
	return layout_stub('GridFormattingContext.cpp:2704 GridFormattingContext::calculate_static_position_rect')
}

// Translated from Libraries/LibWeb/Layout/GridFormattingContext.cpp:2721
// Original signature: static unsigned hash(Web::Layout::GridPosition const& key)
pub fn grid_formatting_context_cpp_2721_hash() LayoutStub {
	return layout_stub('GridFormattingContext.cpp:2721 hash')
}

// ---- ReplacedWithChildrenFormattingContext.h (5 translated function stubs) ----

// Translated from Libraries/LibWeb/Layout/ReplacedWithChildrenFormattingContext.h:15
// Original signature: ReplacedWithChildrenFormattingContext::explicit ReplacedWithChildrenFormattingContext(LayoutState&, LayoutMode, Box const&, FormattingContext* parent);
pub fn replaced_with_children_formatting_context_h_15_replaced_with_children_formatting_context() LayoutStub {
	return layout_stub('ReplacedWithChildrenFormattingContext.h:15 ReplacedWithChildrenFormattingContext')
}

// Translated from Libraries/LibWeb/Layout/ReplacedWithChildrenFormattingContext.h:17
// Original signature: ReplacedWithChildrenFormattingContext::virtual void run(AvailableSpace const&);
pub fn replaced_with_children_formatting_context_h_17_run() LayoutStub {
	return layout_stub('ReplacedWithChildrenFormattingContext.h:17 run')
}

// Translated from Libraries/LibWeb/Layout/ReplacedWithChildrenFormattingContext.h:18
// Original signature: ReplacedWithChildrenFormattingContext::virtual CSSPixels automatic_content_width() const;
pub fn replaced_with_children_formatting_context_h_18_automatic_content_width() LayoutStub {
	return layout_stub('ReplacedWithChildrenFormattingContext.h:18 automatic_content_width')
}

// Translated from Libraries/LibWeb/Layout/ReplacedWithChildrenFormattingContext.h:19
// Original signature: ReplacedWithChildrenFormattingContext::virtual CSSPixels automatic_content_height() const;
pub fn replaced_with_children_formatting_context_h_19_automatic_content_height() LayoutStub {
	return layout_stub('ReplacedWithChildrenFormattingContext.h:19 automatic_content_height')
}

// Translated from Libraries/LibWeb/Layout/ReplacedWithChildrenFormattingContext.h:20
// Original signature: ReplacedWithChildrenFormattingContext::virtual void parent_context_did_dimension_child_root_box();
pub fn replaced_with_children_formatting_context_h_20_parent_context_did_dimension_child_root_box() LayoutStub {
	return layout_stub('ReplacedWithChildrenFormattingContext.h:20 parent_context_did_dimension_child_root_box')
}

// ---- ReplacedWithChildrenFormattingContext.cpp (5 translated function stubs) ----

// Translated from Libraries/LibWeb/Layout/ReplacedWithChildrenFormattingContext.cpp:12
// Original signature: ReplacedWithChildrenFormattingContext::ReplacedWithChildrenFormattingContext(LayoutState& state, LayoutMode layout_mode, Box const& box, FormattingContext* parent) : FormattingContext(Type::ReplacedWithChildren, layout_mode, state, box, parent)
pub fn replaced_with_children_formatting_context_cpp_12_replaced_with_children_formatting_context_replaced_with() LayoutStub {
	return layout_stub('ReplacedWithChildrenFormattingContext.cpp:12 ReplacedWithChildrenFormattingContext::ReplacedWithChildrenFormattingContext')
}

// Translated from Libraries/LibWeb/Layout/ReplacedWithChildrenFormattingContext.cpp:17
// Original signature: void ReplacedWithChildrenFormattingContext::run(AvailableSpace const& available_space)
// Mark the replaced element as having definite dimensions when the parent FC has
// computed them from intrinsic size, so children with percentage sizes can resolve.
// For height, use the parent-set content height if it's been resolved (e.g. explicit height
// or intrinsic height), otherwise use the available space from the parent formatting context.
// The TreeBuilder wraps shadow DOM children in an anonymous BlockContainer.
// Delegate layout to a BFC for that wrapper.
pub fn replaced_with_children_formatting_context_cpp_17_replaced_with_children_formatting_context_run() LayoutStub {
	return layout_stub('ReplacedWithChildrenFormattingContext.cpp:17 ReplacedWithChildrenFormattingContext::run')
}

// Translated from Libraries/LibWeb/Layout/ReplacedWithChildrenFormattingContext.cpp:61
// Original signature: CSSPixels ReplacedWithChildrenFormattingContext::automatic_content_width() const
pub fn replaced_with_children_formatting_context_cpp_61_replaced_with_children_formatting_context_automatic_con() LayoutStub {
	return layout_stub('ReplacedWithChildrenFormattingContext.cpp:61 ReplacedWithChildrenFormattingContext::automatic_content_width')
}

// Translated from Libraries/LibWeb/Layout/ReplacedWithChildrenFormattingContext.cpp:66
// Original signature: CSSPixels ReplacedWithChildrenFormattingContext::automatic_content_height() const
pub fn replaced_with_children_formatting_context_cpp_66_replaced_with_children_formatting_context_automatic_con() LayoutStub {
	return layout_stub('ReplacedWithChildrenFormattingContext.cpp:66 ReplacedWithChildrenFormattingContext::automatic_content_height')
}

// Translated from Libraries/LibWeb/Layout/ReplacedWithChildrenFormattingContext.cpp:71
// Original signature: void ReplacedWithChildrenFormattingContext::parent_context_did_dimension_child_root_box()
pub fn replaced_with_children_formatting_context_cpp_71_replaced_with_children_formatting_context_parent_contex() LayoutStub {
	return layout_stub('ReplacedWithChildrenFormattingContext.cpp:71 ReplacedWithChildrenFormattingContext::parent_context_did_dimension_child_root_box')
}

// ---- TableFormattingContext.h (62 translated function stubs) ----

// Translated from Libraries/LibWeb/Layout/TableFormattingContext.h:23
// Original signature: TableFormattingContext::explicit TableFormattingContext(LayoutState&, LayoutMode, Box const&, FormattingContext* parent);
pub fn table_formatting_context_h_23_table_formatting_context() LayoutStub {
	return layout_stub('TableFormattingContext.h:23 TableFormattingContext')
}

// Translated from Libraries/LibWeb/Layout/TableFormattingContext.h:24
// Original signature: TableFormattingContext::~TableFormattingContext();
pub fn table_formatting_context_h_24_table_formatting_context_destroy_table_formatting_context() LayoutStub {
	return layout_stub('TableFormattingContext.h:24 TableFormattingContext::~TableFormattingContext')
}

// Translated from Libraries/LibWeb/Layout/TableFormattingContext.h:26
// Original signature: TableFormattingContext::void run_until_width_calculation(AvailableSpace const& available_space);
pub fn table_formatting_context_h_26_run_until_width_calculation() LayoutStub {
	return layout_stub('TableFormattingContext.h:26 run_until_width_calculation')
}

// Translated from Libraries/LibWeb/Layout/TableFormattingContext.h:28
// Original signature: TableFormattingContext::virtual void run(AvailableSpace const&);
pub fn table_formatting_context_h_28_run() LayoutStub {
	return layout_stub('TableFormattingContext.h:28 run')
}

// Translated from Libraries/LibWeb/Layout/TableFormattingContext.h:29
// Original signature: TableFormattingContext::virtual CSSPixels automatic_content_width() const;
pub fn table_formatting_context_h_29_automatic_content_width() LayoutStub {
	return layout_stub('TableFormattingContext.h:29 automatic_content_width')
}

// Translated from Libraries/LibWeb/Layout/TableFormattingContext.h:30
// Original signature: TableFormattingContext::virtual CSSPixels automatic_content_height() const;
pub fn table_formatting_context_h_30_automatic_content_height() LayoutStub {
	return layout_stub('TableFormattingContext.h:30 automatic_content_height')
}

// Translated from Libraries/LibWeb/Layout/TableFormattingContext.h:31
// Original signature: TableFormattingContext::StaticPositionRect calculate_static_position_rect(Box const&) const;
pub fn table_formatting_context_h_31_calculate_static_position_rect() LayoutStub {
	return layout_stub('TableFormattingContext.h:31 calculate_static_position_rect')
}

// Translated from Libraries/LibWeb/Layout/TableFormattingContext.h:33
// Original signature: TableFormattingContext::Box const& table_box() const
pub fn table_formatting_context_h_33_table_box() LayoutStub {
	return layout_stub('TableFormattingContext.h:33 table_box')
}

// Translated from Libraries/LibWeb/Layout/TableFormattingContext.h:39
// Original signature: TableFormattingContext::static bool border_is_less_specific(CSS::BorderData const& a, CSS::BorderData const& b);
pub fn table_formatting_context_h_39_border_is_less_specific() LayoutStub {
	return layout_stub('TableFormattingContext.h:39 border_is_less_specific')
}

// Translated from Libraries/LibWeb/Layout/TableFormattingContext.h:41
// Original signature: TableFormattingContext::virtual void parent_context_did_dimension_child_root_box();
pub fn table_formatting_context_h_41_parent_context_did_dimension_child_root_box() LayoutStub {
	return layout_stub('TableFormattingContext.h:41 parent_context_did_dimension_child_root_box')
}

// Translated from Libraries/LibWeb/Layout/TableFormattingContext.h:44
// Original signature: TableFormattingContext::CSSPixels run_caption_layout(CSS::CaptionSide, AvailableSpace const&);
pub fn table_formatting_context_h_44_run_caption_layout() LayoutStub {
	return layout_stub('TableFormattingContext.h:44 run_caption_layout')
}

// Translated from Libraries/LibWeb/Layout/TableFormattingContext.h:45
// Original signature: TableFormattingContext::CSSPixels compute_capmin();
pub fn table_formatting_context_h_45_compute_capmin() LayoutStub {
	return layout_stub('TableFormattingContext.h:45 compute_capmin')
}

// Translated from Libraries/LibWeb/Layout/TableFormattingContext.h:46
// Original signature: TableFormattingContext::void compute_constrainedness();
pub fn table_formatting_context_h_46_compute_constrainedness() LayoutStub {
	return layout_stub('TableFormattingContext.h:46 compute_constrainedness')
}

// Translated from Libraries/LibWeb/Layout/TableFormattingContext.h:47
// Original signature: TableFormattingContext::void compute_cell_measures();
pub fn table_formatting_context_h_47_compute_cell_measures() LayoutStub {
	return layout_stub('TableFormattingContext.h:47 compute_cell_measures')
}

// Translated from Libraries/LibWeb/Layout/TableFormattingContext.h:48
// Original signature: TableFormattingContext::void compute_outer_content_sizes();
pub fn table_formatting_context_h_48_compute_outer_content_sizes() LayoutStub {
	return layout_stub('TableFormattingContext.h:48 compute_outer_content_sizes')
}

// Translated from Libraries/LibWeb/Layout/TableFormattingContext.h:50
// Original signature: TableFormattingContext::void initialize_table_measures();
pub fn table_formatting_context_h_50_initialize_table_measures() LayoutStub {
	return layout_stub('TableFormattingContext.h:50 initialize_table_measures')
}

// Translated from Libraries/LibWeb/Layout/TableFormattingContext.h:52
// Original signature: TableFormattingContext::void compute_table_measures();
pub fn table_formatting_context_h_52_compute_table_measures() LayoutStub {
	return layout_stub('TableFormattingContext.h:52 compute_table_measures')
}

// Translated from Libraries/LibWeb/Layout/TableFormattingContext.h:54
// Original signature: TableFormattingContext::void compute_intrinsic_percentage(size_t max_cell_span);
pub fn table_formatting_context_h_54_compute_intrinsic_percentage() LayoutStub {
	return layout_stub('TableFormattingContext.h:54 compute_intrinsic_percentage')
}

// Translated from Libraries/LibWeb/Layout/TableFormattingContext.h:55
// Original signature: TableFormattingContext::void compute_table_width();
pub fn table_formatting_context_h_55_compute_table_width() LayoutStub {
	return layout_stub('TableFormattingContext.h:55 compute_table_width')
}

// Translated from Libraries/LibWeb/Layout/TableFormattingContext.h:56
// Original signature: TableFormattingContext::void distribute_width_to_columns();
pub fn table_formatting_context_h_56_distribute_width_to_columns() LayoutStub {
	return layout_stub('TableFormattingContext.h:56 distribute_width_to_columns')
}

// Translated from Libraries/LibWeb/Layout/TableFormattingContext.h:57
// Original signature: TableFormattingContext::void distribute_excess_width_to_columns(CSSPixels available_width);
pub fn table_formatting_context_h_57_distribute_excess_width_to_columns() LayoutStub {
	return layout_stub('TableFormattingContext.h:57 distribute_excess_width_to_columns')
}

// Translated from Libraries/LibWeb/Layout/TableFormattingContext.h:58
// Original signature: TableFormattingContext::void distribute_excess_width_to_columns_fixed_mode(CSSPixels excess_width);
pub fn table_formatting_context_h_58_distribute_excess_width_to_columns_fixed_mode() LayoutStub {
	return layout_stub('TableFormattingContext.h:58 distribute_excess_width_to_columns_fixed_mode')
}

// Translated from Libraries/LibWeb/Layout/TableFormattingContext.h:59
// Original signature: TableFormattingContext::void compute_table_height();
pub fn table_formatting_context_h_59_compute_table_height() LayoutStub {
	return layout_stub('TableFormattingContext.h:59 compute_table_height')
}

// Translated from Libraries/LibWeb/Layout/TableFormattingContext.h:60
// Original signature: TableFormattingContext::void distribute_height_to_rows();
pub fn table_formatting_context_h_60_distribute_height_to_rows() LayoutStub {
	return layout_stub('TableFormattingContext.h:60 distribute_height_to_rows')
}

// Translated from Libraries/LibWeb/Layout/TableFormattingContext.h:61
// Original signature: TableFormattingContext::void position_row_boxes();
pub fn table_formatting_context_h_61_position_row_boxes() LayoutStub {
	return layout_stub('TableFormattingContext.h:61 position_row_boxes')
}

// Translated from Libraries/LibWeb/Layout/TableFormattingContext.h:62
// Original signature: TableFormattingContext::void position_cell_boxes();
pub fn table_formatting_context_h_62_position_cell_boxes() LayoutStub {
	return layout_stub('TableFormattingContext.h:62 position_cell_boxes')
}

// Translated from Libraries/LibWeb/Layout/TableFormattingContext.h:63
// Original signature: TableFormattingContext::void border_conflict_resolution();
pub fn table_formatting_context_h_63_border_conflict_resolution() LayoutStub {
	return layout_stub('TableFormattingContext.h:63 border_conflict_resolution')
}

// Translated from Libraries/LibWeb/Layout/TableFormattingContext.h:64
// Original signature: TableFormattingContext::CSSPixels border_spacing_horizontal() const;
pub fn table_formatting_context_h_64_border_spacing_horizontal() LayoutStub {
	return layout_stub('TableFormattingContext.h:64 border_spacing_horizontal')
}

// Translated from Libraries/LibWeb/Layout/TableFormattingContext.h:65
// Original signature: TableFormattingContext::CSSPixels border_spacing_vertical() const;
pub fn table_formatting_context_h_65_border_spacing_vertical() LayoutStub {
	return layout_stub('TableFormattingContext.h:65 border_spacing_vertical')
}

// Translated from Libraries/LibWeb/Layout/TableFormattingContext.h:66
// Original signature: TableFormattingContext::void finish_grid_initialization(TableGrid const&);
pub fn table_formatting_context_h_66_finish_grid_initialization() LayoutStub {
	return layout_stub('TableFormattingContext.h:66 finish_grid_initialization')
}

// Translated from Libraries/LibWeb/Layout/TableFormattingContext.h:68
// Original signature: TableFormattingContext::CSSPixels compute_columns_total_used_width() const;
pub fn table_formatting_context_h_68_compute_columns_total_used_width() LayoutStub {
	return layout_stub('TableFormattingContext.h:68 compute_columns_total_used_width')
}

// Translated from Libraries/LibWeb/Layout/TableFormattingContext.h:69
// Original signature: TableFormattingContext::void commit_candidate_column_widths(Vector<CSSPixels> const& candidate_widths);
pub fn table_formatting_context_h_69_commit_candidate_column_widths() LayoutStub {
	return layout_stub('TableFormattingContext.h:69 commit_candidate_column_widths')
}

// Translated from Libraries/LibWeb/Layout/TableFormattingContext.h:70
// Original signature: TableFormattingContext::void assign_columns_width_linear_combination(Vector<CSSPixels> const& candidate_widths, CSSPixels available_width);
pub fn table_formatting_context_h_70_assign_columns_width_linear_combination() LayoutStub {
	return layout_stub('TableFormattingContext.h:70 assign_columns_width_linear_combination')
}

// Translated from Libraries/LibWeb/Layout/TableFormattingContext.h:73
// Original signature: TableFormattingContext::bool distribute_excess_width_proportionally_to_base_width(CSSPixels excess_width, ColumnFilter column_filter, BaseWidthGetter base_width_getter);
pub fn table_formatting_context_h_73_distribute_excess_width_proportionally_to_base_width() LayoutStub {
	return layout_stub('TableFormattingContext.h:73 distribute_excess_width_proportionally_to_base_width')
}

// Translated from Libraries/LibWeb/Layout/TableFormattingContext.h:75
// Original signature: TableFormattingContext::bool distribute_excess_width_equally(CSSPixels excess_width, ColumnFilter column_filter);
pub fn table_formatting_context_h_75_distribute_excess_width_equally() LayoutStub {
	return layout_stub('TableFormattingContext.h:75 distribute_excess_width_equally')
}

// Translated from Libraries/LibWeb/Layout/TableFormattingContext.h:77
// Original signature: TableFormattingContext::bool distribute_excess_width_by_intrinsic_percentage(CSSPixels excess_width, ColumnFilter column_filter);
pub fn table_formatting_context_h_77_distribute_excess_width_by_intrinsic_percentage() LayoutStub {
	return layout_stub('TableFormattingContext.h:77 distribute_excess_width_by_intrinsic_percentage')
}

// Translated from Libraries/LibWeb/Layout/TableFormattingContext.h:79
// Original signature: TableFormattingContext::bool use_fixed_mode_layout() const;
pub fn table_formatting_context_h_79_use_fixed_mode_layout() LayoutStub {
	return layout_stub('TableFormattingContext.h:79 use_fixed_mode_layout')
}

// Translated from Libraries/LibWeb/Layout/TableFormattingContext.h:81
// Original signature: TableFormattingContext::CSSPixels table_wrapper_containing_block_width() const;
pub fn table_formatting_context_h_81_table_wrapper_containing_block_width() LayoutStub {
	return layout_stub('TableFormattingContext.h:81 table_wrapper_containing_block_width')
}

// Translated from Libraries/LibWeb/Layout/TableFormattingContext.h:82
// Original signature: TableFormattingContext::CSSPixels table_wrapper_containing_block_height() const;
pub fn table_formatting_context_h_82_table_wrapper_containing_block_height() LayoutStub {
	return layout_stub('TableFormattingContext.h:82 table_wrapper_containing_block_height')
}

// Translated from Libraries/LibWeb/Layout/TableFormattingContext.h:108
// Original signature: TableFormattingContext::static size_t cell_span(Cell const& cell);
pub fn table_formatting_context_h_108_cell_span() LayoutStub {
	return layout_stub('TableFormattingContext.h:108 cell_span')
}

// Translated from Libraries/LibWeb/Layout/TableFormattingContext.h:111
// Original signature: TableFormattingContext::static size_t cell_index(Cell const& cell);
pub fn table_formatting_context_h_111_cell_index() LayoutStub {
	return layout_stub('TableFormattingContext.h:111 cell_index')
}

// Translated from Libraries/LibWeb/Layout/TableFormattingContext.h:114
// Original signature: TableFormattingContext::static CSSPixels cell_min_size(Cell const& cell);
pub fn table_formatting_context_h_114_cell_min_size() LayoutStub {
	return layout_stub('TableFormattingContext.h:114 cell_min_size')
}

// Translated from Libraries/LibWeb/Layout/TableFormattingContext.h:117
// Original signature: TableFormattingContext::static CSSPixels cell_max_size(Cell const& cell);
pub fn table_formatting_context_h_117_cell_max_size() LayoutStub {
	return layout_stub('TableFormattingContext.h:117 cell_max_size')
}

// Translated from Libraries/LibWeb/Layout/TableFormattingContext.h:120
// Original signature: TableFormattingContext::static double cell_percentage_contribution(Cell const& cell);
pub fn table_formatting_context_h_120_cell_percentage_contribution() LayoutStub {
	return layout_stub('TableFormattingContext.h:120 cell_percentage_contribution')
}

// Translated from Libraries/LibWeb/Layout/TableFormattingContext.h:123
// Original signature: TableFormattingContext::static bool cell_has_intrinsic_percentage(Cell const& cell);
pub fn table_formatting_context_h_123_cell_has_intrinsic_percentage() LayoutStub {
	return layout_stub('TableFormattingContext.h:123 cell_has_intrinsic_percentage')
}

// Translated from Libraries/LibWeb/Layout/TableFormattingContext.h:126
// Original signature: TableFormattingContext::void initialize_intrinsic_percentages_from_rows_or_columns();
pub fn table_formatting_context_h_126_initialize_intrinsic_percentages_from_rows_or_columns() LayoutStub {
	return layout_stub('TableFormattingContext.h:126 initialize_intrinsic_percentages_from_rows_or_columns')
}

// Translated from Libraries/LibWeb/Layout/TableFormattingContext.h:129
// Original signature: TableFormattingContext::void initialize_intrinsic_percentages_from_cells();
pub fn table_formatting_context_h_129_initialize_intrinsic_percentages_from_cells() LayoutStub {
	return layout_stub('TableFormattingContext.h:129 initialize_intrinsic_percentages_from_cells')
}

// Translated from Libraries/LibWeb/Layout/TableFormattingContext.h:132
// Original signature: TableFormattingContext::CSSPixels border_spacing();
pub fn table_formatting_context_h_132_border_spacing() LayoutStub {
	return layout_stub('TableFormattingContext.h:132 border_spacing')
}

// Translated from Libraries/LibWeb/Layout/TableFormattingContext.h:135
// Original signature: TableFormattingContext::Vector<RowOrColumn>& table_rows_or_columns();
pub fn table_formatting_context_h_135_table_rows_or_columns() LayoutStub {
	return layout_stub('TableFormattingContext.h:135 table_rows_or_columns')
}

// Translated from Libraries/LibWeb/Layout/TableFormattingContext.h:137
// Original signature: TableFormattingContext::CSSPixels compute_row_content_height(Cell const& cell) const;
pub fn table_formatting_context_h_137_compute_row_content_height() LayoutStub {
	return layout_stub('TableFormattingContext.h:137 compute_row_content_height')
}

// Translated from Libraries/LibWeb/Layout/TableFormattingContext.h:154
// Original signature: TableFormattingContext::static TableFormattingContext::ConflictingEdge const& winning_conflicting_edge(TableFormattingContext::ConflictingEdge const& a, TableFormattingContext::ConflictingEdge const& b);
pub fn table_formatting_context_h_154_winning_conflicting_edge() LayoutStub {
	return layout_stub('TableFormattingContext.h:154 winning_conflicting_edge')
}

// Translated from Libraries/LibWeb/Layout/TableFormattingContext.h:156
// Original signature: TableFormattingContext::static CSS::BorderData const& border_data_conflicting_edge(ConflictingEdge const& conflicting_edge);
pub fn table_formatting_context_h_156_border_data_conflicting_edge() LayoutStub {
	return layout_stub('TableFormattingContext.h:156 border_data_conflicting_edge')
}

// Translated from Libraries/LibWeb/Layout/TableFormattingContext.h:157
// Original signature: TableFormattingContext::static Painting::PaintableBox::BorderDataWithElementKind const border_data_with_element_kind_from_conflicting_edge(ConflictingEdge const& conflicting_edge);
pub fn table_formatting_context_h_157_border_data_with_element_kind_from_conflicting_edge() LayoutStub {
	return layout_stub('TableFormattingContext.h:157 border_data_with_element_kind_from_conflicting_edge')
}

// Translated from Libraries/LibWeb/Layout/TableFormattingContext.h:161
// Original signature: BorderConflictFinder::BorderConflictFinder(TableFormattingContext const* context);
pub fn table_formatting_context_h_161_border_conflict_finder_border_conflict_finder() LayoutStub {
	return layout_stub('TableFormattingContext.h:161 BorderConflictFinder::BorderConflictFinder')
}

// Translated from Libraries/LibWeb/Layout/TableFormattingContext.h:162
// Original signature: BorderConflictFinder::Vector<ConflictingEdge> conflicting_edges(Cell const&, ConflictingSide) const;
pub fn table_formatting_context_h_162_conflicting_edges() LayoutStub {
	return layout_stub('TableFormattingContext.h:162 conflicting_edges')
}

// Translated from Libraries/LibWeb/Layout/TableFormattingContext.h:165
// Original signature: BorderConflictFinder::void collect_conflicting_col_elements();
pub fn table_formatting_context_h_165_collect_conflicting_col_elements() LayoutStub {
	return layout_stub('TableFormattingContext.h:165 collect_conflicting_col_elements')
}

// Translated from Libraries/LibWeb/Layout/TableFormattingContext.h:166
// Original signature: BorderConflictFinder::void collect_conflicting_row_group_elements();
pub fn table_formatting_context_h_166_collect_conflicting_row_group_elements() LayoutStub {
	return layout_stub('TableFormattingContext.h:166 collect_conflicting_row_group_elements')
}

// Translated from Libraries/LibWeb/Layout/TableFormattingContext.h:168
// Original signature: BorderConflictFinder::void collect_cell_conflicting_edges(Vector<ConflictingEdge>&, Cell const&, ConflictingSide) const;
pub fn table_formatting_context_h_168_collect_cell_conflicting_edges() LayoutStub {
	return layout_stub('TableFormattingContext.h:168 collect_cell_conflicting_edges')
}

// Translated from Libraries/LibWeb/Layout/TableFormattingContext.h:169
// Original signature: BorderConflictFinder::void collect_row_conflicting_edges(Vector<ConflictingEdge>&, Cell const&, ConflictingSide) const;
pub fn table_formatting_context_h_169_collect_row_conflicting_edges() LayoutStub {
	return layout_stub('TableFormattingContext.h:169 collect_row_conflicting_edges')
}

// Translated from Libraries/LibWeb/Layout/TableFormattingContext.h:170
// Original signature: BorderConflictFinder::void collect_row_group_conflicting_edges(Vector<ConflictingEdge>&, Cell const&, ConflictingSide) const;
pub fn table_formatting_context_h_170_collect_row_group_conflicting_edges() LayoutStub {
	return layout_stub('TableFormattingContext.h:170 collect_row_group_conflicting_edges')
}

// Translated from Libraries/LibWeb/Layout/TableFormattingContext.h:171
// Original signature: BorderConflictFinder::void collect_column_group_conflicting_edges(Vector<ConflictingEdge>&, Cell const&, ConflictingSide) const;
pub fn table_formatting_context_h_171_collect_column_group_conflicting_edges() LayoutStub {
	return layout_stub('TableFormattingContext.h:171 collect_column_group_conflicting_edges')
}

// Translated from Libraries/LibWeb/Layout/TableFormattingContext.h:172
// Original signature: BorderConflictFinder::void collect_table_box_conflicting_edges(Vector<ConflictingEdge>&, Cell const&, ConflictingSide) const;
pub fn table_formatting_context_h_172_collect_table_box_conflicting_edges() LayoutStub {
	return layout_stub('TableFormattingContext.h:172 collect_table_box_conflicting_edges')
}

// ---- TableFormattingContext.cpp (75 translated function stubs) ----

// Translated from Libraries/LibWeb/Layout/TableFormattingContext.cpp:17
// Original signature: TableFormattingContext::TableFormattingContext(LayoutState& state, LayoutMode layout_mode, Box const& root, FormattingContext* parent) : FormattingContext(Type::Table, layout_mode, state, root, parent)
pub fn table_formatting_context_cpp_17_table_formatting_context_table_formatting_context() LayoutStub {
	return layout_stub('TableFormattingContext.cpp:17 TableFormattingContext::TableFormattingContext')
}

// Translated from Libraries/LibWeb/Layout/TableFormattingContext.cpp:22
// Original signature: TableFormattingContext::~TableFormattingContext() = default;
pub fn table_formatting_context_cpp_22_table_formatting_context_destroy_table_formatting_context() LayoutStub {
	return layout_stub('TableFormattingContext.cpp:22 TableFormattingContext::~TableFormattingContext')
}

// Translated from Libraries/LibWeb/Layout/TableFormattingContext.cpp:24
// Original signature: CSSPixels TableFormattingContext::table_wrapper_containing_block_width() const
pub fn table_formatting_context_cpp_24_table_formatting_context_table_wrapper_containing_block_width() LayoutStub {
	return layout_stub('TableFormattingContext.cpp:24 TableFormattingContext::table_wrapper_containing_block_width')
}

// Translated from Libraries/LibWeb/Layout/TableFormattingContext.cpp:32
// Original signature: CSSPixels TableFormattingContext::table_wrapper_containing_block_height() const
pub fn table_formatting_context_cpp_32_table_formatting_context_table_wrapper_containing_block_height() LayoutStub {
	return layout_stub('TableFormattingContext.cpp:32 TableFormattingContext::table_wrapper_containing_block_height')
}

// Translated from Libraries/LibWeb/Layout/TableFormattingContext.cpp:40
// Original signature: static inline bool is_table_column_group(Box const& box)
pub fn table_formatting_context_cpp_40_is_table_column_group() LayoutStub {
	return layout_stub('TableFormattingContext.cpp:40 is_table_column_group')
}

// Translated from Libraries/LibWeb/Layout/TableFormattingContext.cpp:45
// Original signature: static inline bool is_table_column(Box const& box)
pub fn table_formatting_context_cpp_45_is_table_column() LayoutStub {
	return layout_stub('TableFormattingContext.cpp:45 is_table_column')
}

// Translated from Libraries/LibWeb/Layout/TableFormattingContext.cpp:50
// Original signature: CSSPixels TableFormattingContext::run_caption_layout(CSS::CaptionSide phase, AvailableSpace const& caption_available_space)
// The caption boxes are principal block-level boxes that retain their own content, padding, margin, and border
// areas,
// and are rendered as normal block boxes inside the table wrapper box, as described in
// https://www.w3.org/TR/CSS22/tables.html#model
// FIXME: If caption only has inline children, BlockFormattingContext doesn't resolve the vertical metrics.
// We need to do it manually here.
// Adjust x offset so border-box aligns with the table wrapper.
pub fn table_formatting_context_cpp_50_table_formatting_context_run_caption_layout() LayoutStub {
	return layout_stub('TableFormattingContext.cpp:50 TableFormattingContext::run_caption_layout')
}

// Translated from Libraries/LibWeb/Layout/TableFormattingContext.cpp:98
// Original signature: void TableFormattingContext::compute_constrainedness()
// Definition of constrainedness: https://www.w3.org/TR/css-tables-3/#constrainedness
// NB: The definition uses https://www.w3.org/TR/CSS21/visudet.html#propdef-width for width, which doesn't
// include
// keyword values. The remaining checks can be simplified to checking whether the size is a length.
pub fn table_formatting_context_cpp_98_table_formatting_context_compute_constrainedness() LayoutStub {
	return layout_stub('TableFormattingContext.cpp:98 TableFormattingContext::compute_constrainedness')
}

// Translated from Libraries/LibWeb/Layout/TableFormattingContext.cpp:135
// Original signature: void TableFormattingContext::compute_cell_measures()
// Implements https://www.w3.org/TR/css-tables-3/#computing-cell-measures.
// Implement the collapsing border model https://www.w3.org/TR/CSS22/tables.html#collapsing-borders.
// The outer min-content height of a table-cell is max(min-height, min-content height) adjusted by the cell
// intrinsic offsets.
// The outer min-content width of a table-cell is max(min-width, min-content width) adjusted by the cell
// intrinsic offsets.
// For fixed mode, according to https://www.w3.org/TR/css-tables-3/#computing-column-measures:
// The min-content and max-content width of cells is considered zero unless they are directly specified as a
// length-percentage,
// in which case they are resolved based on the table width (if it is definite, otherwise use 0).
// The tables specification isn't explicit on how to use the height and max-height CSS properties in the outer
// max-content formulas.
// However, during this early phase we don't have enough information to resolve percentage sizes yet and the
// formulas for outer sizes
// in the specification give enough clues to pick defaults in a way that makes sense.
// The outer max-content height of a table-cell in a constrained row is
// max(min-height, height, min-content height, min(max-height, height)) adjusted by the cell intrinsic offsets.
// NB: min(max-height, height) doesn't have any effect here, we can simplify the expression to max(min-height,
// height, min-content height).
// The outer max-content height of a table-cell in a non-constrained row is
// max(min-height, height, min-content height, min(max-height, max-content height)) adjusted by the cell
// intrinsic offsets.
// See the explanation for height and max_height above.
// The outer max-content width of a table-cell in a constrained column is
// max(min-width, width, min-content width, min(max-width, width)) adjusted by the cell intrinsic offsets.
// NB: min(max-width, width) doesn't have any effect here, we can simplify the expression to max(min-width,
// width, min-content width).
// The outer max-content width of a table-cell in a non-constrained column is
// max(min-width, width, min-content width, min(max-width, max-content width)) adjusted by the cell intrinsic
// offsets.
pub fn table_formatting_context_cpp_135_table_formatting_context_compute_cell_measures() LayoutStub {
	return layout_stub('TableFormattingContext.cpp:135 TableFormattingContext::compute_cell_measures')
}

// Translated from Libraries/LibWeb/Layout/TableFormattingContext.cpp:213
// Original signature: void TableFormattingContext::compute_outer_content_sizes()
// The outer min-content width of a table-column or table-column-group is max(min-width, width).
// The outer max-content width of a table-column or table-column-group is max(min-width, min(max-width, width)).
// The outer min-content height of a table-row or table-row-group is max(min-height, height).
// The outer max-content height of a table-row or table-row-group is max(min-height, min(max-height, height)).
pub fn table_formatting_context_cpp_213_table_formatting_context_compute_outer_content_sizes() LayoutStub {
	return layout_stub('TableFormattingContext.cpp:213 TableFormattingContext::compute_outer_content_sizes')
}

// Translated from Libraries/LibWeb/Layout/TableFormattingContext.cpp:248
// Original signature: void TableFormattingContext::initialize_table_measures<TableFormattingContext::Row>()
// https://www.w3.org/TR/css-tables-3/#row-layout makes specified cell height part of the initialization formula
// for row table measures:
// This is done by running the same algorithm as the column measurement, with the span=1 value being initialized
// (for min-content) with
// the largest of the resulting height of the previous row layout, the height specified on the corresponding
// table-row (if any), and
// the largest height specified on cells that span this row only (the algorithm starts by considering cells of
// span 2 on top of that assignment).
pub fn table_formatting_context_cpp_248_function() LayoutStub {
	return layout_stub('TableFormattingContext.cpp:248 function')
}

// Translated from Libraries/LibWeb/Layout/TableFormattingContext.cpp:267
// Original signature: void TableFormattingContext::initialize_table_measures<TableFormattingContext::Column>()
// Implement the following parts of the specification, accounting for fixed layout mode:
// https://www.w3.org/TR/css-tables-3/#min-content-width-of-a-column-based-on-cells-of-span-up-to-1
// https://www.w3.org/TR/css-tables-3/#max-content-width-of-a-column-based-on-cells-of-span-up-to-1
pub fn table_formatting_context_cpp_267_function() LayoutStub {
	return layout_stub('TableFormattingContext.cpp:267 function')
}

// Translated from Libraries/LibWeb/Layout/TableFormattingContext.cpp:281
// Original signature: void TableFormattingContext::compute_intrinsic_percentage(size_t max_cell_span)
// https://www.w3.org/TR/css-tables-3/#intrinsic-percentage-width-of-a-column-based-on-cells-of-span-up-to-1
// Stores intermediate values for intrinsic percentage based on cells of span up to N for the iterative
// algorithm, to store them back at the end of the step.
// https://www.w3.org/TR/css-tables-3/#intrinsic-percentage-width-of-a-column-based-on-cells-of-span-up-to-n-n--1
// 1. Start with the percentage contribution of the cell.
// 2. Subtract the intrinsic percentage width of the column based on cells of span up to N-1 of all columns
// that the cell spans. If this gives a negative result, change it to 0%.
// Compute the sum of the non-spanning max-content sizes of all rows / columns spanned by the cell that have an
// intrinsic percentage
// size of the row / column based on cells of span up to N-1 equal to 0%, to be used in step 3 of the cell
// contribution algorithm.
// If the intrinsic percentage width of a column based on cells of span up to N-1 is greater than 0%, then the
// intrinsic percentage width of
// the column based on cells of span up to N is the same as the intrinsic percentage width of the column based on
// cells of span up to N-1.
// Otherwise, it is the largest of the contributions of the cells in the column whose colSpan is N,
// where the contribution of a cell is the result of taking the following steps:
// 3. Multiply by the ratio of the column's non-spanning max-content width to the sum of the non-spanning max-
// content widths of all
// columns spanned by the cell that have an intrinsic percentage width of the column based on cells of span up to
// N-1 equal to 0%.
// However, if this ratio is undefined because the denominator is zero, instead use the 1 divided by the number
// of columns
// spanned by the cell that have an intrinsic percentage width of the column based on cells of span up to N-1
// equal to zero.
// Clamp total intrinsic percentage to 100%: https://www.w3.org/TR/css-tables-3/#intrinsic-percentage-width-of-a-
// column
pub fn table_formatting_context_cpp_281_table_formatting_context_compute_intrinsic_percentage() LayoutStub {
	return layout_stub('TableFormattingContext.cpp:281 TableFormattingContext::compute_intrinsic_percentage')
}

// Translated from Libraries/LibWeb/Layout/TableFormattingContext.cpp:361
// Original signature: void TableFormattingContext::compute_table_measures()
// Since the intrinsic percentage specification uses non-spanning max-content size for the iterative algorithm,
// run it before we compute the spanning max-content size with its own iterative algorithm for span up to N.
// https://www.w3.org/TR/css-tables-3/#min-content-width-of-a-column-based-on-cells-of-span-up-to-n-n--1
// https://www.w3.org/TR/css-tables-3/#max-content-width-of-a-column-based-on-cells-of-span-up-to-n-n--1
// Define the baseline max-content size as the sum of the max-content sizes based on cells of span up to N-1 of
// all columns that the cell spans.
// Define the baseline border spacing as the sum of the horizontal border-spacing for any columns spanned by the
// cell, other than the one in which the cell originates.
// Add contribution from all rows / columns, since we've weighted the gap to the desired spanned size by the the
// ratio of the max-content size based on cells of span up to N-1 of the row / column to the baseline max-content
// width.
// The contribution of the cell is the sum of:
// the min-content size of the column based on cells of span up to N-1
// the product of:
// - the ratio of:
// - the max-content size of the row / column based on cells of span up to N-1 of the row / column minus the
// min-content size of the row / column based on cells of span up to N-1 of the row / column, to
// - the baseline max-content size minus the baseline min-content size
// or zero if this ratio is undefined, and
// - the outer min-content size of the cell minus the baseline min-content size and the baseline border spacing,
// clamped
// to be at least 0 and at most the difference between the baseline max-content size and the baseline min-content
// size
// - the ratio of the max-content size based on cells of span up to N-1 of the column to the baseline max-content
// size
// - the outer min-content size of the cell minus the baseline max-content size and baseline border spacing, or 0
// if this is negative
// AD-HOC: The spec does not define behavior when baseline is zero. We distribute equally.
// This matches how undefined ratios are handled elsewhere.
// the max-content size of the column based on cells of span up to N-1
// and the product of:
// - the outer max-content size of the cell minus the baseline max-content size and the baseline border spacing,
// or 0 if this is negative
// AD-HOC: The spec does not define behavior when baseline is zero. We distribute equally,
// min-content size of a row / column based on cells of span up to N (N > 1) is
// the largest of the min-content size of the row / column based on cells of span up to N-1 and
// the contributions of the cells in the row / column whose rowSpan / colSpan is N
// max-content size of a row / column based on cells of span up to N (N > 1) is
// the largest of the max-content size based on cells of span up to N-1 and the contributions of
// the cells in the row / column whose rowSpan / colSpan is N
pub fn table_formatting_context_cpp_361_table_formatting_context_compute_table_measures() LayoutStub {
	return layout_stub('TableFormattingContext.cpp:361 TableFormattingContext::compute_table_measures')
}

// Translated from Libraries/LibWeb/Layout/TableFormattingContext.cpp:470
// Original signature: CSSPixels TableFormattingContext::compute_capmin()
// The caption width minimum (CAPMIN) is the largest of the table captions min-content contribution:
// https://drafts.csswg.org/css-tables-3/#computing-the-table-width
pub fn table_formatting_context_cpp_470_table_formatting_context_compute_capmin() LayoutStub {
	return layout_stub('TableFormattingContext.cpp:470 TableFormattingContext::compute_capmin')
}

// Translated from Libraries/LibWeb/Layout/TableFormattingContext.cpp:485
// Original signature: static bool width_is_auto_or_indefinite_percentage(CSS::Size const& width, LayoutState::UsedValues const* containing_block_state)
pub fn table_formatting_context_cpp_485_width_is_auto_or_indefinite_percentage() LayoutStub {
	return layout_stub('TableFormattingContext.cpp:485 width_is_auto_or_indefinite_percentage')
}

// Translated from Libraries/LibWeb/Layout/TableFormattingContext.cpp:496
// Original signature: void TableFormattingContext::compute_table_width()
// https://drafts.csswg.org/css-tables-3/#computing-the-table-width
// Percentages on 'width' and 'height' on the table are relative to the table wrapper box's containing block,
// not the table wrapper box itself.
// Compute undistributable space due to border spacing: https://www.w3.org/TR/css-tables-3/#computing-
// undistributable-space.
// The row/column-grid width minimum (GRIDMIN) width is the sum of the min-content width
// of all the columns plus cell spacing or borders.
// The row/column-grid width maximum (GRIDMAX) width is the sum of the max-content width
// The used min-width of a table is the greater of the resolved min-width, CAPMIN, and GRIDMIN.
// If the table-root has 'width: auto', the used width is the greater of
// min(GRIDMAX, the table's containing block width), the used min-width of the table.
// https://www.w3.org/TR/CSS22/tables.html#auto-table-layout
// A percentage value for a column width is relative to the table width. If the table has 'width: auto',
// a percentage represents a constraint on the column's width, which a UA should try to satisfy.
// If the table-root's width property has a computed value (resolving to
// resolved-table-width) other than auto, the used width is the greater
// of resolved-table-width, and the used min-width of the table.
// Since used_width is content width, we need to subtract the border and padding spacing from the specified width
// for a consistent comparison.
pub fn table_formatting_context_cpp_496_table_formatting_context_compute_table_width() LayoutStub {
	return layout_stub('TableFormattingContext.cpp:496 TableFormattingContext::compute_table_width')
}

// Translated from Libraries/LibWeb/Layout/TableFormattingContext.cpp:583
// Original signature: CSSPixels TableFormattingContext::compute_columns_total_used_width() const
pub fn table_formatting_context_cpp_583_table_formatting_context_compute_columns_total_used_width() LayoutStub {
	return layout_stub('TableFormattingContext.cpp:583 TableFormattingContext::compute_columns_total_used_width')
}

// Translated from Libraries/LibWeb/Layout/TableFormattingContext.cpp:592
// Original signature: static CSSPixels compute_columns_total_candidate_width(Vector<CSSPixels> const& candidate_widths)
pub fn table_formatting_context_cpp_592_compute_columns_total_candidate_width() LayoutStub {
	return layout_stub('TableFormattingContext.cpp:592 compute_columns_total_candidate_width')
}

// Translated from Libraries/LibWeb/Layout/TableFormattingContext.cpp:601
// Original signature: void TableFormattingContext::commit_candidate_column_widths(Vector<CSSPixels> const& candidate_widths)
pub fn table_formatting_context_cpp_601_table_formatting_context_commit_candidate_column_widths() LayoutStub {
	return layout_stub('TableFormattingContext.cpp:601 TableFormattingContext::commit_candidate_column_widths')
}

// Translated from Libraries/LibWeb/Layout/TableFormattingContext.cpp:609
// Original signature: void TableFormattingContext::assign_columns_width_linear_combination(Vector<CSSPixels> const& candidate_widths, CSSPixels available_width)
pub fn table_formatting_context_cpp_609_table_formatting_context_assign_columns_width_linear_combination() LayoutStub {
	return layout_stub('TableFormattingContext.cpp:609 TableFormattingContext::assign_columns_width_linear_combination')
}

// Translated from Libraries/LibWeb/Layout/TableFormattingContext.cpp:624
// Original signature: bool TableFormattingContext::distribute_excess_width_proportionally_to_base_width(CSSPixels excess_width, ColumnFilter column_filter, BaseWidthGetter base_width_getter)
pub fn table_formatting_context_cpp_624_table_formatting_context_distribute_excess_width_proportionally_to_base() LayoutStub {
	return layout_stub('TableFormattingContext.cpp:624 TableFormattingContext::distribute_excess_width_proportionally_to_base_width')
}

// Translated from Libraries/LibWeb/Layout/TableFormattingContext.cpp:647
// Original signature: bool TableFormattingContext::distribute_excess_width_equally(CSSPixels excess_width, ColumnFilter column_filter)
pub fn table_formatting_context_cpp_647_table_formatting_context_distribute_excess_width_equally() LayoutStub {
	return layout_stub('TableFormattingContext.cpp:647 TableFormattingContext::distribute_excess_width_equally')
}

// Translated from Libraries/LibWeb/Layout/TableFormattingContext.cpp:667
// Original signature: bool TableFormattingContext::distribute_excess_width_by_intrinsic_percentage(CSSPixels excess_width, ColumnFilter column_filter)
pub fn table_formatting_context_cpp_667_table_formatting_context_distribute_excess_width_by_intrinsic_percentag() LayoutStub {
	return layout_stub('TableFormattingContext.cpp:667 TableFormattingContext::distribute_excess_width_by_intrinsic_percentage')
}

// Translated from Libraries/LibWeb/Layout/TableFormattingContext.cpp:688
// Original signature: void TableFormattingContext::distribute_width_to_columns()
// Implements https://www.w3.org/TR/css-tables-3/#width-distribution-algorithm
// The total horizontal border spacing is defined for each table:
// - For tables laid out in separated-borders mode containing at least one column, the horizontal component of
// the computed value of the border-spacing property times one plus the number of columns in the table
// - Otherwise, 0
// The assignable table width is the used width of the table minus the total horizontal border spacing (if any).
// This is the width that we will be able to allocate to the columns.
// 1. The min-content sizing-guess is the set of column width assignments where each column is assigned its min-
// content width.
// In fixed mode, the min-content width of percent-columns and auto-columns is considered to be zero:
// https://www.w3.org/TR/css-tables-3/#width-distribution-in-fixed-mode
// 2. The min-content-percentage sizing-guess is the set of column width assignments where:
// - each percent-column is assigned the larger of:
// - its intrinsic percentage width times the assignable width and
// - its min-content width.
// - all other columns are assigned their min-content width.
// If the assignable table width is less than or equal to the max-content sizing-guess, the used widths of the
// columns must be the
// linear combination (with weights adding to 1) of the two consecutive sizing-guesses whose width sums bound the
// available width.
// 3. The min-content-specified sizing-guess is the set of column width assignments where:
// - its min-content width
// - any other column that is constrained is assigned its max-content width
// 4. The max-content sizing-guess is the set of column width assignments where:
// - all other columns are assigned their max-content width.
// Otherwise, the used widths of the columns are the result of starting from the max-content sizing-guess and
// distributing
// the excess width to the columns of the table according to the rules for distributing excess width to columns
// (for used width).
pub fn table_formatting_context_cpp_688_table_formatting_context_distribute_width_to_columns() LayoutStub {
	return layout_stub('TableFormattingContext.cpp:688 TableFormattingContext::distribute_width_to_columns')
}

// Translated from Libraries/LibWeb/Layout/TableFormattingContext.cpp:781
// Original signature: void TableFormattingContext::distribute_excess_width_to_columns(CSSPixels available_width)
// Implements https://www.w3.org/TR/css-tables-3/#distributing-width-to-columns
// 1. If there are non-constrained columns that have originating cells with intrinsic percentage width of 0% and
// with nonzero
// max-content width (aka the columns allowed to grow by this rule), the distributed widths of the columns
// allowed to grow
// by this rule are increased in proportion to max-content width so the total increase adds to the excess width.
// 2. Otherwise, if there are non-constrained columns that have originating cells with intrinsic percentage width
// of 0% (aka the columns
// allowed to grow by this rule, which thanks to the previous rule must have zero max-content width), the
// distributed widths of the
// columns allowed to grow by this rule are increased by equal amounts so the total increase adds to the excess
// width.
// 3. Otherwise, if there are constrained columns with intrinsic percentage width of 0% and with nonzero max-
// content width
// (aka the columns allowed to grow by this rule, which, due to other rules, must have originating cells), the
// distributed widths of the
// columns allowed to grow by this rule are increased in proportion to max-content width so the total increase
// adds to the excess width.
// 4. Otherwise, if there are columns with intrinsic percentage width greater than 0% (aka the columns allowed to
// grow by this rule,
// which, due to other rules, must have originating cells), the distributed widths of the columns allowed to grow
// by this rule are
// increased in proportion to intrinsic percentage width so the total increase adds to the excess width.
// 5. Otherwise, if there is any such column, the distributed widths of all columns that have originating cells
// are increased by equal amounts
// so the total increase adds to the excess width.
// 6. Otherwise, the distributed widths of all columns are increased by equal amounts so the total increase adds
// to the excess width.
pub fn table_formatting_context_cpp_781_table_formatting_context_distribute_excess_width_to_columns() LayoutStub {
	return layout_stub('TableFormattingContext.cpp:781 TableFormattingContext::distribute_excess_width_to_columns')
}

// Translated from Libraries/LibWeb/Layout/TableFormattingContext.cpp:863
// Original signature: void TableFormattingContext::distribute_excess_width_to_columns_fixed_mode(CSSPixels excess_width)
// Implements the fixed mode for https://www.w3.org/TR/css-tables-3/#distributing-width-to-columns.
// If there are any columns with no width specified, the excess width is distributed in equally to such columns
// otherwise, if there are columns with non-zero length widths from the base assignment, the excess width is
// distributed proportionally to width among those columns
// otherwise, if there are columns with non-zero percentage widths from the base assignment, the excess width is
// distributed proportionally to percentage width among those columns
// otherwise, the excess width is distributed equally to the zero-sized columns
pub fn table_formatting_context_cpp_863_table_formatting_context_distribute_excess_width_to_columns_fixed_mode() LayoutStub {
	return layout_stub('TableFormattingContext.cpp:863 TableFormattingContext::distribute_excess_width_to_columns_fixed_mode')
}

// Translated from Libraries/LibWeb/Layout/TableFormattingContext.cpp:884
// Original signature: void TableFormattingContext::compute_table_height()
// First pass of row height calculation:
// First pass of cells layout:
// Compute cell width as specified by https://www.w3.org/TR/css-tables-3/#bounding-box-assignment:
// The position of any table-cell, table-track, or table-track-group box within the table is defined as the
// rectangle whose width/height is the sum of:
// - the widths/heights of all spanned visible columns/rows
// - the horizontal/vertical border-spacing times the amount of spanned visible columns/rows minus one
// FIXME: Account for visibility.
// Implements https://www.w3.org/TR/css-tables-3/#computing-the-table-height
// The minimum height of a row is the maximum of:
// - the computed height (if definite, percentages being considered 0px) of its corresponding table-row (if nay)
// - the computed height of each cell spanning the current row exclusively (if definite, percentages being
// treated as 0px), and
// - the minimum height (ROWMIN) required by the cells spanning the row.
// Note that we've already applied the first rule at the top of the method.
// If the table has a height property with a value other than auto, it is treated as a minimum height for the
// table grid, and will eventually be distributed to the height of the rows if their collective minimum height
// ends up smaller than this number.
// Reference size is the largest of
// - its initial base height and
// - its new base height (the one evaluated during the second layout pass, where percentages used in
// rowgroups/rows/cells' specified heights were resolved according to the table height, instead of
// being ignored as 0px).
// Assign reference size to base size. Later, the reference size might change to a larger value during
// the second pass of rows layout.
// Second pass of rows height calculation:
// At this point, percentage row height can be resolved because the final table height is calculated.
// Second pass cells layout:
// At this point, percentage cell height can be resolved because the final table height is calculated.
pub fn table_formatting_context_cpp_884_table_formatting_context_compute_table_height() LayoutStub {
	return layout_stub('TableFormattingContext.cpp:884 TableFormattingContext::compute_table_height')
}

// Translated from Libraries/LibWeb/Layout/TableFormattingContext.cpp:1046
// Original signature: void TableFormattingContext::distribute_height_to_rows()
// If the table height is equal or smaller than sum of reference sizes, the final height assigned to each row
// will be the weighted mean of the base and the reference size that yields the correct total height.
// Else, if the table owns any "auto-height" row (a row whose size is only determined by its content size and
// none of the specified heights), each non-auto-height row receives its reference height and auto-height rows
// receive their reference size plus some increment which is equal to the height missing to amount to the
// specified table height divided by the amount of such rows.
// Else, all rows receive their reference size plus some increment which is equal to the height missing to
// amount to the specified table height divided by the amount of rows.
// Add undistributable space due to border spacing: https://www.w3.org/TR/css-tables-3/#computing-
// undistributable-space.
pub fn table_formatting_context_cpp_1046_table_formatting_context_distribute_height_to_rows() LayoutStub {
	return layout_stub('TableFormattingContext.cpp:1046 TableFormattingContext::distribute_height_to_rows')
}

// Translated from Libraries/LibWeb/Layout/TableFormattingContext.cpp:1111
// Original signature: void TableFormattingContext::position_row_boxes()
pub fn table_formatting_context_cpp_1111_table_formatting_context_position_row_boxes() LayoutStub {
	return layout_stub('TableFormattingContext.cpp:1111 TableFormattingContext::position_row_boxes')
}

// Translated from Libraries/LibWeb/Layout/TableFormattingContext.cpp:1165
// Original signature: void TableFormattingContext::position_cell_boxes()
// When a table cell is an anonymous wrapper around a flex or grid container (e.g., a <td> with display:flex is
// wrapped in an anonymous table-cell box per CSS Tables 3), the cell should be aligned to the top. This allows
// the flex/grid container to fill the cell and handle alignment of its children via its own properties.
// The following image shows various alignment lines of a row:
// https://www.w3.org/TR/css-tables-3/images/cell-align-explainer.png
// https://drafts.csswg.org/css2/#height-layout
// In the context of tables, values for vertical-align have the following meanings:
// The center of the cell is aligned with the center of the rows it spans.
// The top of the cell box is aligned with the top of the first row it spans.
// The bottom of the cell box is aligned with the bottom of the last row it spans.
// These values do not apply to cells; the cell is aligned at the baseline instead.
// The baseline of the cell is put at the same height as the baseline of the first of the rows it spans.
// Compute cell position as specified by https://www.w3.org/TR/css-tables-3/#bounding-box-assignment:
// left/top location is the sum of:
// - for top: the height reserved for top captions (including margins), if any
// - the padding-left/padding-top and border-left-width/border-top-width of the table
// FIXME: Account for visibility.
pub fn table_formatting_context_cpp_1165_table_formatting_context_position_cell_boxes() LayoutStub {
	return layout_stub('TableFormattingContext.cpp:1165 TableFormattingContext::position_cell_boxes')
}

// Translated from Libraries/LibWeb/Layout/TableFormattingContext.cpp:1243
// Original signature: bool TableFormattingContext::use_fixed_mode_layout() const
// Implements https://www.w3.org/TR/css-tables-3/#in-fixed-mode.
// A table-root is said to be laid out in fixed mode whenever the computed value of the table-layout property is
// equal to fixed, and the
// specified width of the table root is either a <length-percentage>, min-content or fit-content. When the
// specified width is not one of
// those values, or if the computed value of the table-layout property is auto, then the table-root is said to be
// laid out in auto mode.
pub fn table_formatting_context_cpp_1243_table_formatting_context_use_fixed_mode_layout() LayoutStub {
	return layout_stub('TableFormattingContext.cpp:1243 TableFormattingContext::use_fixed_mode_layout')
}

// Translated from Libraries/LibWeb/Layout/TableFormattingContext.cpp:1253
// Original signature: bool TableFormattingContext::border_is_less_specific(CSS::BorderData const& a, CSS::BorderData const& b)
// Implements criteria for steps 1, 2 and 3 of border conflict resolution algorithm, as described in
// https://www.w3.org/TR/CSS22/tables.html#border-conflict-resolution.
// 1. Borders with the 'border-style' of 'hidden' take precedence over all other conflicting borders. Any border
// with this
// value suppresses all borders at this location.
// 2. Borders with a style of 'none' have the lowest priority. Only if the border properties of all the elements
// meeting
// at this edge are 'none' will the border be omitted (but note that 'none' is the default value for the border
// style.)
// 3. If none of the styles are 'hidden' and at least one of them is not 'none', then narrow borders are
// discarded in favor
// of wider ones. If several have the same 'border-width' then styles are preferred in this order: 'double',
// 'solid',
// 'dashed', 'dotted', 'ridge', 'outset', 'groove', and the lowest: 'inset'.
pub fn table_formatting_context_cpp_1253_table_formatting_context_border_is_less_specific() LayoutStub {
	return layout_stub('TableFormattingContext.cpp:1253 TableFormattingContext::border_is_less_specific')
}

// Translated from Libraries/LibWeb/Layout/TableFormattingContext.cpp:1302
// Original signature: CSS::BorderData const& TableFormattingContext::border_data_conflicting_edge(TableFormattingContext::ConflictingEdge const& conflicting_edge)
pub fn table_formatting_context_cpp_1302_table_formatting_context_border_data_conflicting_edge() LayoutStub {
	return layout_stub('TableFormattingContext.cpp:1302 TableFormattingContext::border_data_conflicting_edge')
}

// Translated from Libraries/LibWeb/Layout/TableFormattingContext.cpp:1324
// Original signature: Painting::PaintableBox::BorderDataWithElementKind const TableFormattingContext::border_data_with_element_kind_from_conflicting_edge(ConflictingEdge const& conflicting_edge)
pub fn table_formatting_context_cpp_1324_table_formatting_context_border_data_with_element_kind_from_conflictin() LayoutStub {
	return layout_stub('TableFormattingContext.cpp:1324 TableFormattingContext::border_data_with_element_kind_from_conflicting_edge')
}

// Translated from Libraries/LibWeb/Layout/TableFormattingContext.cpp:1330
// Original signature: TableFormattingContext::ConflictingEdge const& TableFormattingContext::winning_conflicting_edge(TableFormattingContext::ConflictingEdge const& a, TableFormattingContext::ConflictingEdge const& b)
// First check if step 4 of border conflict resolution applies, as described in
// https://www.w3.org/TR/CSS22/tables.html#border-conflict-resolution.
// 4. If border styles differ only in color, then a style set on a cell wins over one on a row, which wins over a
// row group, column, column group and, lastly, table. When two elements of the same type conflict, then the one
// further to the left (if the table's 'direction' is 'ltr'; right, if it is 'rtl') and further to the top wins.
// Here the element kind is the same, thus the coordinates are either both set or not set.
// Apply steps 1, 2 and 3 of the border conflict resolution algorithm.
pub fn table_formatting_context_cpp_1330_table_formatting_context_winning_conflicting_edge() LayoutStub {
	return layout_stub('TableFormattingContext.cpp:1330 TableFormattingContext::winning_conflicting_edge')
}

// Translated from Libraries/LibWeb/Layout/TableFormattingContext.cpp:1367
// Original signature: void TableFormattingContext::border_conflict_resolution()
// Implements border conflict resolution, as described in https://www.w3.org/TR/CSS22/tables.html#border-
// conflict-resolution.
pub fn table_formatting_context_cpp_1367_table_formatting_context_border_conflict_resolution() LayoutStub {
	return layout_stub('TableFormattingContext.cpp:1367 TableFormattingContext::border_conflict_resolution')
}

// Translated from Libraries/LibWeb/Layout/TableFormattingContext.cpp:1435
// Original signature: CSSPixels TableFormattingContext::compute_row_content_height(Cell const& cell) const
// The height of a cell is the sum of all spanned rows, as described in
// https://www.w3.org/TR/css-tables-3/#bounding-box-assignment
// When the row span is greater than 1, the borders of inner rows within the span have to be
// included in the content height of the spanning cell. First top and final bottom borders are
// excluded to be consistent with the handling of row span 1 case above, which uses the content
// height (no top and bottom borders) of the row.
// Compute cell height as specified by https://www.w3.org/TR/css-tables-3/#bounding-box-assignment:
// width/height is the sum of:
// - the widths/heights of all spanned visible columns/rows
// - the horizontal/vertical border-spacing times the amount of spanned visible columns/rows minus one
// FIXME: Account for visibility.
pub fn table_formatting_context_cpp_1435_table_formatting_context_compute_row_content_height() LayoutStub {
	return layout_stub('TableFormattingContext.cpp:1435 TableFormattingContext::compute_row_content_height')
}

// Translated from Libraries/LibWeb/Layout/TableFormattingContext.cpp:1469
// Original signature: TableFormattingContext::BorderConflictFinder::BorderConflictFinder(TableFormattingContext const* context) : m_context(context)
pub fn table_formatting_context_cpp_1469_table_formatting_context_border_conflict_finder_border_conflict_finder() LayoutStub {
	return layout_stub('TableFormattingContext.cpp:1469 TableFormattingContext::BorderConflictFinder::BorderConflictFinder')
}

// Translated from Libraries/LibWeb/Layout/TableFormattingContext.cpp:1476
// Original signature: void TableFormattingContext::BorderConflictFinder::collect_conflicting_col_elements()
pub fn table_formatting_context_cpp_1476_table_formatting_context_border_conflict_finder_collect_conflicting_co() LayoutStub {
	return layout_stub('TableFormattingContext.cpp:1476 TableFormattingContext::BorderConflictFinder::collect_conflicting_col_elements')
}

// Translated from Libraries/LibWeb/Layout/TableFormattingContext.cpp:1497
// Original signature: void TableFormattingContext::BorderConflictFinder::collect_conflicting_row_group_elements()
pub fn table_formatting_context_cpp_1497_table_formatting_context_border_conflict_finder_collect_conflicting_ro() LayoutStub {
	return layout_stub('TableFormattingContext.cpp:1497 TableFormattingContext::BorderConflictFinder::collect_conflicting_row_group_elements')
}

// Translated from Libraries/LibWeb/Layout/TableFormattingContext.cpp:1517
// Original signature: void TableFormattingContext::BorderConflictFinder::collect_cell_conflicting_edges(Vector<ConflictingEdge>& result, Cell const& cell, TableFormattingContext::ConflictingSide edge) const
// Right edge of the cell to the left.
// Left edge of the cell to the right.
// Bottom edge of the cell above.
// Top edge of the cell below.
pub fn table_formatting_context_cpp_1517_table_formatting_context_border_conflict_finder_collect_cell_conflicti() LayoutStub {
	return layout_stub('TableFormattingContext.cpp:1517 TableFormattingContext::BorderConflictFinder::collect_cell_conflicting_edges')
}

// Translated from Libraries/LibWeb/Layout/TableFormattingContext.cpp:1553
// Original signature: void TableFormattingContext::BorderConflictFinder::collect_row_conflicting_edges(Vector<ConflictingEdge>& result, Cell const& cell, TableFormattingContext::ConflictingSide edge) const
// Top edge of the row.
// Bottom edge of the row.
// Bottom edge of the row above.
// Top edge of the row below.
pub fn table_formatting_context_cpp_1553_table_formatting_context_border_conflict_finder_collect_row_conflictin() LayoutStub {
	return layout_stub('TableFormattingContext.cpp:1553 TableFormattingContext::BorderConflictFinder::collect_row_conflicting_edges')
}

// Translated from Libraries/LibWeb/Layout/TableFormattingContext.cpp:1575
// Original signature: void TableFormattingContext::BorderConflictFinder::collect_row_group_conflicting_edges(Vector<ConflictingEdge>& result, Cell const& cell, TableFormattingContext::ConflictingSide edge) const
// Top edge of the row group.
// Bottom edge of the row group above.
// Bottom edge of the row group.
// Top edge of the row group below.
pub fn table_formatting_context_cpp_1575_table_formatting_context_border_conflict_finder_collect_row_group_conf() LayoutStub {
	return layout_stub('TableFormattingContext.cpp:1575 TableFormattingContext::BorderConflictFinder::collect_row_group_conflicting_edges')
}

// Translated from Libraries/LibWeb/Layout/TableFormattingContext.cpp:1602
// Original signature: void TableFormattingContext::BorderConflictFinder::collect_column_group_conflicting_edges(Vector<ConflictingEdge>& result, Cell const& cell, TableFormattingContext::ConflictingSide edge) const
// Left edge of the column group.
// Right edge of the column group to the left.
// Right edge of the column group.
// Left edge of the column group to the right.
pub fn table_formatting_context_cpp_1602_table_formatting_context_border_conflict_finder_collect_column_group_c() LayoutStub {
	return layout_stub('TableFormattingContext.cpp:1602 TableFormattingContext::BorderConflictFinder::collect_column_group_conflicting_edges')
}

// Translated from Libraries/LibWeb/Layout/TableFormattingContext.cpp:1622
// Original signature: void TableFormattingContext::BorderConflictFinder::collect_table_box_conflicting_edges(Vector<ConflictingEdge>& result, Cell const& cell, TableFormattingContext::ConflictingSide edge) const
// Top edge from column group or table. Left and right edges of the column group are handled in
// collect_column_group_conflicting_edges.
// Bottom edge from column group or table. Left and right edges of the column group are handled in
// collect_column_group_conflicting_edges.
// Left edge from row group or table. Top and bottom edges of the row group are handled in
// collect_row_group_conflicting_edges.
// Right edge from row group or table. Top and bottom edges of the row group are handled in
// collect_row_group_conflicting_edges.
pub fn table_formatting_context_cpp_1622_table_formatting_context_border_conflict_finder_collect_table_box_conf() LayoutStub {
	return layout_stub('TableFormattingContext.cpp:1622 TableFormattingContext::BorderConflictFinder::collect_table_box_conflicting_edges')
}

// Translated from Libraries/LibWeb/Layout/TableFormattingContext.cpp:1656
// Original signature: Vector<TableFormattingContext::ConflictingEdge> TableFormattingContext::BorderConflictFinder::conflicting_edges( Cell const& cell, TableFormattingContext::ConflictingSide edge) const
pub fn table_formatting_context_cpp_1656_table_formatting_context_border_conflict_finder_conflicting_edges() LayoutStub {
	return layout_stub('TableFormattingContext.cpp:1656 TableFormattingContext::BorderConflictFinder::conflicting_edges')
}

// Translated from Libraries/LibWeb/Layout/TableFormattingContext.cpp:1668
// Original signature: void TableFormattingContext::finish_grid_initialization(TableGrid const& table_grid)
pub fn table_formatting_context_cpp_1668_table_formatting_context_finish_grid_initialization() LayoutStub {
	return layout_stub('TableFormattingContext.cpp:1668 TableFormattingContext::finish_grid_initialization')
}

// Translated from Libraries/LibWeb/Layout/TableFormattingContext.cpp:1681
// Original signature: void TableFormattingContext::run_until_width_calculation(AvailableSpace const& available_space)
// Determine the number of rows/columns the table requires.
// Compute the minimum width of each column.
// https://www.w3.org/TR/css-tables-3/#row-layout
// Since during row layout the specified heights of cells in the row were ignored and cells that were spanning
// more than one rows
// have not been sized correctly, their height will need to be eventually distributed to the set of rows they
// spanned. This is done
// by running the same algorithm as the column measurement, with the span=1 value being initialized (for min-
// content) with the largest
// of the resulting height of the previous row layout, the height specified on the corresponding table-row (if
// any), and the largest
// height specified on cells that span this row only (the algorithm starts by considering cells of span 2 on top
// of that assignment).
// Compute the width of the table.
pub fn table_formatting_context_cpp_1681_table_formatting_context_run_until_width_calculation() LayoutStub {
	return layout_stub('TableFormattingContext.cpp:1681 TableFormattingContext::run_until_width_calculation')
}

// Translated from Libraries/LibWeb/Layout/TableFormattingContext.cpp:1707
// Original signature: void TableFormattingContext::parent_context_did_dimension_child_root_box()
// FIXME: calculate_static_position_rect() is not aware of how to correctly calculate static position for
// a box nested inside a table, but we need to set some value, so layout_absolutely_positioned_element()
// won't crash trying to access it.
pub fn table_formatting_context_cpp_1707_table_formatting_context_parent_context_did_dimension_child_root_box() LayoutStub {
	return layout_stub('TableFormattingContext.cpp:1707 TableFormattingContext::parent_context_did_dimension_child_root_box')
}

// Translated from Libraries/LibWeb/Layout/TableFormattingContext.cpp:1730
// Original signature: void TableFormattingContext::run(AvailableSpace const& available_space)
// Distribute the width of the table among columns.
// Table captions are positioned between the table margins and its borders (outside the grid box borders) as
// described in
// https://www.w3.org/TR/css-tables-3/#bounding-box-assignment
// A visual representation of this model can be found at https://www.w3.org/TR/css-
// tables-3/images/table_container.png
pub fn table_formatting_context_cpp_1730_table_formatting_context_run() LayoutStub {
	return layout_stub('TableFormattingContext.cpp:1730 TableFormattingContext::run')
}

// Translated from Libraries/LibWeb/Layout/TableFormattingContext.cpp:1770
// Original signature: CSSPixels TableFormattingContext::automatic_content_width() const
pub fn table_formatting_context_cpp_1770_table_formatting_context_automatic_content_width() LayoutStub {
	return layout_stub('TableFormattingContext.cpp:1770 TableFormattingContext::automatic_content_width')
}

// Translated from Libraries/LibWeb/Layout/TableFormattingContext.cpp:1775
// Original signature: CSSPixels TableFormattingContext::automatic_content_height() const
pub fn table_formatting_context_cpp_1775_table_formatting_context_automatic_content_height() LayoutStub {
	return layout_stub('TableFormattingContext.cpp:1775 TableFormattingContext::automatic_content_height')
}

// Translated from Libraries/LibWeb/Layout/TableFormattingContext.cpp:1781
// Original signature: size_t TableFormattingContext::cell_span<TableFormattingContext::Row>(TableFormattingContext::Cell const& cell)
pub fn table_formatting_context_cpp_1781_function() LayoutStub {
	return layout_stub('TableFormattingContext.cpp:1781 function')
}

// Translated from Libraries/LibWeb/Layout/TableFormattingContext.cpp:1787
// Original signature: size_t TableFormattingContext::cell_span<TableFormattingContext::Column>(TableFormattingContext::Cell const& cell)
pub fn table_formatting_context_cpp_1787_function() LayoutStub {
	return layout_stub('TableFormattingContext.cpp:1787 function')
}

// Translated from Libraries/LibWeb/Layout/TableFormattingContext.cpp:1793
// Original signature: size_t TableFormattingContext::cell_index<TableFormattingContext::Row>(TableFormattingContext::Cell const& cell)
pub fn table_formatting_context_cpp_1793_function() LayoutStub {
	return layout_stub('TableFormattingContext.cpp:1793 function')
}

// Translated from Libraries/LibWeb/Layout/TableFormattingContext.cpp:1799
// Original signature: size_t TableFormattingContext::cell_index<TableFormattingContext::Column>(TableFormattingContext::Cell const& cell)
pub fn table_formatting_context_cpp_1799_function() LayoutStub {
	return layout_stub('TableFormattingContext.cpp:1799 function')
}

// Translated from Libraries/LibWeb/Layout/TableFormattingContext.cpp:1805
// Original signature: CSSPixels TableFormattingContext::cell_min_size<TableFormattingContext::Row>(TableFormattingContext::Cell const& cell)
pub fn table_formatting_context_cpp_1805_function() LayoutStub {
	return layout_stub('TableFormattingContext.cpp:1805 function')
}

// Translated from Libraries/LibWeb/Layout/TableFormattingContext.cpp:1811
// Original signature: CSSPixels TableFormattingContext::cell_min_size<TableFormattingContext::Column>(TableFormattingContext::Cell const& cell)
pub fn table_formatting_context_cpp_1811_function() LayoutStub {
	return layout_stub('TableFormattingContext.cpp:1811 function')
}

// Translated from Libraries/LibWeb/Layout/TableFormattingContext.cpp:1817
// Original signature: CSSPixels TableFormattingContext::cell_max_size<TableFormattingContext::Row>(TableFormattingContext::Cell const& cell)
pub fn table_formatting_context_cpp_1817_function() LayoutStub {
	return layout_stub('TableFormattingContext.cpp:1817 function')
}

// Translated from Libraries/LibWeb/Layout/TableFormattingContext.cpp:1823
// Original signature: CSSPixels TableFormattingContext::cell_max_size<TableFormattingContext::Column>(TableFormattingContext::Cell const& cell)
pub fn table_formatting_context_cpp_1823_function() LayoutStub {
	return layout_stub('TableFormattingContext.cpp:1823 function')
}

// Translated from Libraries/LibWeb/Layout/TableFormattingContext.cpp:1829
// Original signature: double TableFormattingContext::cell_percentage_contribution<TableFormattingContext::Row>(TableFormattingContext::Cell const& cell)
// Definition of percentage contribution: https://www.w3.org/TR/css-tables-3/#percentage-contribution
pub fn table_formatting_context_cpp_1829_function() LayoutStub {
	return layout_stub('TableFormattingContext.cpp:1829 function')
}

// Translated from Libraries/LibWeb/Layout/TableFormattingContext.cpp:1839
// Original signature: double TableFormattingContext::cell_percentage_contribution<TableFormattingContext::Column>(TableFormattingContext::Cell const& cell)
// Definition of percentage contribution: https://www.w3.org/TR/css-tables-3/#percentage-contribution
pub fn table_formatting_context_cpp_1839_function() LayoutStub {
	return layout_stub('TableFormattingContext.cpp:1839 function')
}

// Translated from Libraries/LibWeb/Layout/TableFormattingContext.cpp:1849
// Original signature: bool TableFormattingContext::cell_has_intrinsic_percentage<TableFormattingContext::Row>(TableFormattingContext::Cell const& cell)
pub fn table_formatting_context_cpp_1849_function() LayoutStub {
	return layout_stub('TableFormattingContext.cpp:1849 function')
}

// Translated from Libraries/LibWeb/Layout/TableFormattingContext.cpp:1855
// Original signature: bool TableFormattingContext::cell_has_intrinsic_percentage<TableFormattingContext::Column>(TableFormattingContext::Cell const& cell)
pub fn table_formatting_context_cpp_1855_function() LayoutStub {
	return layout_stub('TableFormattingContext.cpp:1855 function')
}

// Translated from Libraries/LibWeb/Layout/TableFormattingContext.cpp:1861
// Original signature: void TableFormattingContext::initialize_intrinsic_percentages_from_rows_or_columns<TableFormattingContext::Row>()
// Definition of percentage contribution: https://www.w3.org/TR/css-tables-3/#percentage-contribution
pub fn table_formatting_context_cpp_1861_function() LayoutStub {
	return layout_stub('TableFormattingContext.cpp:1861 function')
}

// Translated from Libraries/LibWeb/Layout/TableFormattingContext.cpp:1874
// Original signature: void TableFormattingContext::initialize_intrinsic_percentages_from_rows_or_columns<TableFormattingContext::Column>()
// Definition of percentage contribution: https://www.w3.org/TR/css-tables-3/#percentage-contribution
pub fn table_formatting_context_cpp_1874_function() LayoutStub {
	return layout_stub('TableFormattingContext.cpp:1874 function')
}

// Translated from Libraries/LibWeb/Layout/TableFormattingContext.cpp:1893
// Original signature: void TableFormattingContext::initialize_intrinsic_percentages_from_cells()
pub fn table_formatting_context_cpp_1893_table_formatting_context_initialize_intrinsic_percentages_from_cells() LayoutStub {
	return layout_stub('TableFormattingContext.cpp:1893 TableFormattingContext::initialize_intrinsic_percentages_from_cells')
}

// Translated from Libraries/LibWeb/Layout/TableFormattingContext.cpp:1918
// Original signature: CSSPixels TableFormattingContext::border_spacing<TableFormattingContext::Row>()
pub fn table_formatting_context_cpp_1918_function() LayoutStub {
	return layout_stub('TableFormattingContext.cpp:1918 function')
}

// Translated from Libraries/LibWeb/Layout/TableFormattingContext.cpp:1924
// Original signature: CSSPixels TableFormattingContext::border_spacing<TableFormattingContext::Column>()
pub fn table_formatting_context_cpp_1924_function() LayoutStub {
	return layout_stub('TableFormattingContext.cpp:1924 function')
}

// Translated from Libraries/LibWeb/Layout/TableFormattingContext.cpp:1929
// Original signature: CSSPixels TableFormattingContext::border_spacing_horizontal() const
// When a table is laid out in collapsed-borders mode, the border-spacing of the table-root is ignored (as if it
// was set to 0px):
// https://www.w3.org/TR/css-tables-3/#collapsed-style-overrides
pub fn table_formatting_context_cpp_1929_table_formatting_context_border_spacing_horizontal() LayoutStub {
	return layout_stub('TableFormattingContext.cpp:1929 TableFormattingContext::border_spacing_horizontal')
}

// Translated from Libraries/LibWeb/Layout/TableFormattingContext.cpp:1939
// Original signature: CSSPixels TableFormattingContext::border_spacing_vertical() const
// When a table is laid out in collapsed-borders mode, the border-spacing of the table-root is ignored (as if it
// was set to 0px):
// https://www.w3.org/TR/css-tables-3/#collapsed-style-overrides
pub fn table_formatting_context_cpp_1939_table_formatting_context_border_spacing_vertical() LayoutStub {
	return layout_stub('TableFormattingContext.cpp:1939 TableFormattingContext::border_spacing_vertical')
}

// Translated from Libraries/LibWeb/Layout/TableFormattingContext.cpp:1949
// Original signature: StaticPositionRect TableFormattingContext::calculate_static_position_rect(Box const&) const
// FIXME: Implement static position calculation for table descendants instead of always returning a rectangle
// with zero position and size.
pub fn table_formatting_context_cpp_1949_table_formatting_context_calculate_static_position_rect() LayoutStub {
	return layout_stub('TableFormattingContext.cpp:1949 TableFormattingContext::calculate_static_position_rect')
}

// Translated from Libraries/LibWeb/Layout/TableFormattingContext.cpp:1958
// Original signature: Vector<TableFormattingContext::Row>& TableFormattingContext::table_rows_or_columns()
pub fn table_formatting_context_cpp_1958_table_formatting_context_table_rows_or_columns() LayoutStub {
	return layout_stub('TableFormattingContext.cpp:1958 TableFormattingContext::table_rows_or_columns')
}

// Translated from Libraries/LibWeb/Layout/TableFormattingContext.cpp:1964
// Original signature: Vector<TableFormattingContext::Column>& TableFormattingContext::table_rows_or_columns()
pub fn table_formatting_context_cpp_1964_table_formatting_context_table_rows_or_columns() LayoutStub {
	return layout_stub('TableFormattingContext.cpp:1964 TableFormattingContext::table_rows_or_columns')
}

// ---- SVGFormattingContext.h (15 translated function stubs) ----

// Translated from Libraries/LibWeb/Layout/SVGFormattingContext.h:20
// Original signature: SVGFormattingContext::explicit SVGFormattingContext(LayoutState&, LayoutMode, Box const&, FormattingContext* parent, Gfx::AffineTransform parent_viewbox_transform =
pub fn svg_formatting_context_h_20_svg_formatting_context() LayoutStub {
	return layout_stub('SVGFormattingContext.h:20 SVGFormattingContext')
}

// Translated from Libraries/LibWeb/Layout/SVGFormattingContext.h:21
// Original signature: SVGFormattingContext::~SVGFormattingContext();
pub fn svg_formatting_context_h_21_svg_formatting_context_destroy_svg_formatting_context() LayoutStub {
	return layout_stub('SVGFormattingContext.h:21 SVGFormattingContext::~SVGFormattingContext')
}

// Translated from Libraries/LibWeb/Layout/SVGFormattingContext.h:23
// Original signature: SVGFormattingContext::virtual void run(AvailableSpace const&);
pub fn svg_formatting_context_h_23_run() LayoutStub {
	return layout_stub('SVGFormattingContext.h:23 run')
}

// Translated from Libraries/LibWeb/Layout/SVGFormattingContext.h:24
// Original signature: SVGFormattingContext::virtual CSSPixels automatic_content_width() const;
pub fn svg_formatting_context_h_24_automatic_content_width() LayoutStub {
	return layout_stub('SVGFormattingContext.h:24 automatic_content_width')
}

// Translated from Libraries/LibWeb/Layout/SVGFormattingContext.h:25
// Original signature: SVGFormattingContext::virtual CSSPixels automatic_content_height() const;
pub fn svg_formatting_context_h_25_automatic_content_height() LayoutStub {
	return layout_stub('SVGFormattingContext.h:25 automatic_content_height')
}

// Translated from Libraries/LibWeb/Layout/SVGFormattingContext.h:28
// Original signature: SVGFormattingContext::void layout_svg_element(Box const&);
pub fn svg_formatting_context_h_28_layout_svg_element() LayoutStub {
	return layout_stub('SVGFormattingContext.h:28 layout_svg_element')
}

// Translated from Libraries/LibWeb/Layout/SVGFormattingContext.h:29
// Original signature: SVGFormattingContext::void layout_nested_viewport(Box const&);
pub fn svg_formatting_context_h_29_layout_nested_viewport() LayoutStub {
	return layout_stub('SVGFormattingContext.h:29 layout_nested_viewport')
}

// Translated from Libraries/LibWeb/Layout/SVGFormattingContext.h:30
// Original signature: SVGFormattingContext::void layout_container_element(SVGBox const&);
pub fn svg_formatting_context_h_30_layout_container_element() LayoutStub {
	return layout_stub('SVGFormattingContext.h:30 layout_container_element')
}

// Translated from Libraries/LibWeb/Layout/SVGFormattingContext.h:31
// Original signature: SVGFormattingContext::void layout_graphics_element(SVGGraphicsBox const&);
pub fn svg_formatting_context_h_31_layout_graphics_element() LayoutStub {
	return layout_stub('SVGFormattingContext.h:31 layout_graphics_element')
}

// Translated from Libraries/LibWeb/Layout/SVGFormattingContext.h:32
// Original signature: SVGFormattingContext::void layout_path_like_element(SVGGraphicsBox const&);
pub fn svg_formatting_context_h_32_layout_path_like_element() LayoutStub {
	return layout_stub('SVGFormattingContext.h:32 layout_path_like_element')
}

// Translated from Libraries/LibWeb/Layout/SVGFormattingContext.h:33
// Original signature: SVGFormattingContext::void layout_mask_or_clip(SVGBox const&);
pub fn svg_formatting_context_h_33_layout_mask_or_clip() LayoutStub {
	return layout_stub('SVGFormattingContext.h:33 layout_mask_or_clip')
}

// Translated from Libraries/LibWeb/Layout/SVGFormattingContext.h:34
// Original signature: SVGFormattingContext::void layout_image_element(SVGImageBox const& image_box);
pub fn svg_formatting_context_h_34_layout_image_element() LayoutStub {
	return layout_stub('SVGFormattingContext.h:34 layout_image_element')
}

// Translated from Libraries/LibWeb/Layout/SVGFormattingContext.h:36
// Original signature: SVGFormattingContext::[[nodiscard]] Gfx::Path compute_path_for_text(SVGTextBox const&) const;
pub fn svg_formatting_context_h_36_compute_path_for_text() LayoutStub {
	return layout_stub('SVGFormattingContext.h:36 compute_path_for_text')
}

// Translated from Libraries/LibWeb/Layout/SVGFormattingContext.h:37
// Original signature: SVGFormattingContext::[[nodiscard]] Gfx::Path compute_path_for_text_path(SVGTextPathBox const&) const;
pub fn svg_formatting_context_h_37_compute_path_for_text_path() LayoutStub {
	return layout_stub('SVGFormattingContext.h:37 compute_path_for_text_path')
}

// Translated from Libraries/LibWeb/Layout/SVGFormattingContext.h:39
// Original signature: SVGFormattingContext::[[nodiscard]] Gfx::AffineTransform get_parent_svg_transform(SVGGraphicsBox const&) const;
pub fn svg_formatting_context_h_39_get_parent_svg_transform() LayoutStub {
	return layout_stub('SVGFormattingContext.h:39 get_parent_svg_transform')
}

// ---- SVGFormattingContext.cpp (17 translated function stubs) ----

// Translated from Libraries/LibWeb/Layout/SVGFormattingContext.cpp:38
// Original signature: SVGFormattingContext::SVGFormattingContext(LayoutState& state, LayoutMode layout_mode, Box const& box, FormattingContext* parent, Gfx::AffineTransform parent_viewbox_transform) : FormattingContext(Type::SVG, layout_mode, state, box, parent) , m_parent_viewbox_transform(parent_viewbox_transform)
pub fn svg_formatting_context_cpp_38_svg_formatting_context_svg_formatting_context() LayoutStub {
	return layout_stub('SVGFormattingContext.cpp:38 SVGFormattingContext::SVGFormattingContext')
}

// Translated from Libraries/LibWeb/Layout/SVGFormattingContext.cpp:44
// Original signature: SVGFormattingContext::~SVGFormattingContext() = default;
pub fn svg_formatting_context_cpp_44_svg_formatting_context_destroy_svg_formatting_context() LayoutStub {
	return layout_stub('SVGFormattingContext.cpp:44 SVGFormattingContext::~SVGFormattingContext')
}

// Translated from Libraries/LibWeb/Layout/SVGFormattingContext.cpp:46
// Original signature: CSSPixels SVGFormattingContext::automatic_content_width() const
pub fn svg_formatting_context_cpp_46_svg_formatting_context_automatic_content_width() LayoutStub {
	return layout_stub('SVGFormattingContext.cpp:46 SVGFormattingContext::automatic_content_width')
}

// Translated from Libraries/LibWeb/Layout/SVGFormattingContext.cpp:51
// Original signature: CSSPixels SVGFormattingContext::automatic_content_height() const
pub fn svg_formatting_context_cpp_51_svg_formatting_context_automatic_content_height() LayoutStub {
	return layout_stub('SVGFormattingContext.cpp:51 SVGFormattingContext::automatic_content_height')
}

// Translated from Libraries/LibWeb/Layout/SVGFormattingContext.cpp:63
// Original signature: static ViewBoxTransform scale_and_align_viewbox_content(SVG::PreserveAspectRatio const& preserve_aspect_ratio, SVG::ViewBox const& view_box, Gfx::FloatSize viewbox_scale, auto const& svg_box_state)
// https://svgwg.org/svg2-draft/coords.html#PreserveAspectRatioAttribute
// meet (the default) - Scale the graphic such that:
// - aspect ratio is preserved
// - the entire 'viewBox' is visible within the SVG viewport
// - the 'viewBox' is scaled up as much as possible, while still meeting the other criteria
// slice - Scale the graphic such that:
// aspect ratio is preserved
// the entire SVG viewport is covered by the 'viewBox'
// the 'viewBox' is scaled down as much as possible, while still meeting the other criteria
// Handle X alignment:
// Align the <min-x> of the element's 'viewBox' with the smallest X value of the SVG viewport.
// Do not force uniform scaling. Scale the graphic content of the given element non-uniformly
// if necessary such that the element's bounding box exactly matches the SVG viewport rectangle.
// FIXME: None is unimplemented (treat as xMidYMid)
// Align the midpoint X value of the element's 'viewBox' with the midpoint X value of the SVG viewport.
// Align the <min-x>+<width> of the element's 'viewBox' with the maximum X value of the SVG viewport.
// Align the <min-y> of the element's 'viewBox' with the smallest Y value of the SVG viewport.
// Align the midpoint Y value of the element's 'viewBox' with the midpoint Y value of the SVG viewport.
// Align the <min-y>+<height> of the element's 'viewBox' with the maximum Y value of the SVG viewport.
pub fn svg_formatting_context_cpp_63_scale_and_align_viewbox_content() LayoutStub {
	return layout_stub('SVGFormattingContext.cpp:63 scale_and_align_viewbox_content')
}

// Translated from Libraries/LibWeb/Layout/SVGFormattingContext.cpp:160
// Original signature: static bool is_container_element(Node const& node)
// https://svgwg.org/svg2-draft/struct.html#GroupsOverview
pub fn svg_formatting_context_cpp_160_is_container_element() LayoutStub {
	return layout_stub('SVGFormattingContext.cpp:160 is_container_element')
}

// Translated from Libraries/LibWeb/Layout/SVGFormattingContext.cpp:179
// Original signature: void SVGFormattingContext::run(AvailableSpace const& available_space)
// NOTE: SVG doesn't have a "formatting context" in the spec, but this is the most
// obvious way to drive SVG layout in our engine at the moment.
// Overwrite the content width/height with the styled node width/height (from <svg width height ...>)
// NOTE: If a height had not been provided by the svg element, it was set to the height of the container
// (see BlockFormattingContext::layout_viewport)
// FIXME: In SVG 2, length can also be a percentage. We'll need to support that.
// NOTE: We consider all SVG root elements to have definite size in both axes.
// I'm not sure if this is good or bad, but our viewport transform logic depends on it.
// https://svgwg.org/svg2-draft/coords.html#ViewBoxAttribute
// A negative value for <width> or <height> is an error and invalidates the 'viewBox' attribute.
// A value of zero disables rendering of the element.
// FIXME: This should allow just one of width or height to be specified.
// E.g. We should be able to layout <svg width="100%"> where height is unspecified/auto.
// The initial value for preserveAspectRatio is xMidYMid meet.
// This allows mask and clipPath elements to be scaled in the x and y directions independently to match the
// target size.
// NOTE: Calculate viewport dimensions BEFORE scaling the content by m_parent_viewbox_transform.
// For userSpaceOnUse clips (which have no viewBox), we need the unscaled content dimensions,
// not the final pixel dimensions. Otherwise, nested clips compound the scale incorrectly.
// Scale the box of the viewport based on the parent's viewBox transform.
// The viewBox transform is always just a simple scale + offset.
// FIXME: Avoid converting SVG box to floats.
pub fn svg_formatting_context_cpp_179_svg_formatting_context_run() LayoutStub {
	return layout_stub('SVGFormattingContext.cpp:179 SVGFormattingContext::run')
}

// Translated from Libraries/LibWeb/Layout/SVGFormattingContext.cpp:297
// Original signature: void SVGFormattingContext::layout_svg_element(Box const& child)
pub fn svg_formatting_context_cpp_297_svg_formatting_context_layout_svg_element() LayoutStub {
	return layout_stub('SVGFormattingContext.cpp:297 SVGFormattingContext::layout_svg_element')
}

// Translated from Libraries/LibWeb/Layout/SVGFormattingContext.cpp:331
// Original signature: void SVGFormattingContext::layout_nested_viewport(Box const& viewport)
// Layout for a nested SVG viewport.
// https://svgwg.org/svg2-draft/coords.html#EstablishingANewSVGViewport.
// The value auto for width and height on the 'svg' element is treated as 100%.
// https://svgwg.org/svg2-draft/geometry.html#Sizing
// FIXME: Avoid converting SVG box to floats.
pub fn svg_formatting_context_cpp_331_svg_formatting_context_layout_nested_viewport() LayoutStub {
	return layout_stub('SVGFormattingContext.cpp:331 SVGFormattingContext::layout_nested_viewport')
}

// Translated from Libraries/LibWeb/Layout/SVGFormattingContext.cpp:377
// Original signature: Gfx::Path SVGFormattingContext::compute_path_for_text(SVGTextBox const& text_box) const
// FIXME: Use per-code-point fonts.
// https://svgwg.org/svg2-draft/text.html#TextAnchoringProperties
// The rendered characters are aligned such that the start of the resulting rendered text is at the initial
// current text position.
// The rendered characters are shifted such that the geometric middle of the resulting rendered text
// (determined from the initial and final current text position before applying the text-anchor property)
// is at the initial current text position.
// The rendered characters are shifted such that the end of the resulting rendered text (final current text
// position before applying the text-anchor property) is at the initial current text position.
pub fn svg_formatting_context_cpp_377_svg_formatting_context_compute_path_for_text() LayoutStub {
	return layout_stub('SVGFormattingContext.cpp:377 SVGFormattingContext::compute_path_for_text')
}

// Translated from Libraries/LibWeb/Layout/SVGFormattingContext.cpp:418
// Original signature: Gfx::Path SVGFormattingContext::compute_path_for_text_path(SVGTextPathBox const& text_path_box) const
// FIXME: Use per-code-point fonts.
pub fn svg_formatting_context_cpp_418_svg_formatting_context_compute_path_for_text_path() LayoutStub {
	return layout_stub('SVGFormattingContext.cpp:418 SVGFormattingContext::compute_path_for_text_path')
}

// Translated from Libraries/LibWeb/Layout/SVGFormattingContext.cpp:433
// Original signature: void SVGFormattingContext::layout_path_like_element(SVGGraphicsBox const& graphics_box)
// FIXME: Text offsets must be calculated per character. This only applies the first character's offset.
// <text> and <tspan> elements can contain more text elements.
// FIXME: Support <tspan> in <textPath>.
// Stroke increases the path's size by stroke_width/2 per side.
pub fn svg_formatting_context_cpp_433_svg_formatting_context_layout_path_like_element() LayoutStub {
	return layout_stub('SVGFormattingContext.cpp:433 SVGFormattingContext::layout_path_like_element')
}

// Translated from Libraries/LibWeb/Layout/SVGFormattingContext.cpp:478
// Original signature: Gfx::AffineTransform SVGFormattingContext::get_parent_svg_transform(SVGGraphicsBox const& box) const
// Mask/clip boxes are transform boundaries - the target's transform is applied separately at paint time.
pub fn svg_formatting_context_cpp_478_svg_formatting_context_get_parent_svg_transform() LayoutStub {
	return layout_stub('SVGFormattingContext.cpp:478 SVGFormattingContext::get_parent_svg_transform')
}

// Translated from Libraries/LibWeb/Layout/SVGFormattingContext.cpp:493
// Original signature: void SVGFormattingContext::layout_graphics_element(SVGGraphicsBox const& graphics_box)
// https://svgwg.org/svg2-draft/struct.html#Groups
// 5.2. Grouping: the 'g' element
// The 'g' element is a container element for grouping together related graphics elements.
// Assume this is a path-like element.
pub fn svg_formatting_context_cpp_493_svg_formatting_context_layout_graphics_element() LayoutStub {
	return layout_stub('SVGFormattingContext.cpp:493 SVGFormattingContext::layout_graphics_element')
}

// Translated from Libraries/LibWeb/Layout/SVGFormattingContext.cpp:524
// Original signature: void SVGFormattingContext::layout_image_element(SVGImageBox const& image_box)
pub fn svg_formatting_context_cpp_524_svg_formatting_context_layout_image_element() LayoutStub {
	return layout_stub('SVGFormattingContext.cpp:524 SVGFormattingContext::layout_image_element')
}

// Translated from Libraries/LibWeb/Layout/SVGFormattingContext.cpp:542
// Original signature: void SVGFormattingContext::layout_mask_or_clip(SVGBox const& mask_or_clip)
// FIXME: Somehow limit <clipPath> contents to: shape elements, <text>, and <use>.
// https://svgwg.org/svg2-draft/pservers.html#PatternElementPatternContentUnitsAttribute
// Pretend masks/clips are a viewport so we can scale the contents depending on the `contentUnits`.
pub fn svg_formatting_context_cpp_542_svg_formatting_context_layout_mask_or_clip() LayoutStub {
	return layout_stub('SVGFormattingContext.cpp:542 SVGFormattingContext::layout_mask_or_clip')
}

// Translated from Libraries/LibWeb/Layout/SVGFormattingContext.cpp:588
// Original signature: void SVGFormattingContext::layout_container_element(SVGBox const& container)
// Masks/clips/patterns do not change the bounding box of their parents.
pub fn svg_formatting_context_cpp_588_svg_formatting_context_layout_container_element() LayoutStub {
	return layout_stub('SVGFormattingContext.cpp:588 SVGFormattingContext::layout_container_element')
}
