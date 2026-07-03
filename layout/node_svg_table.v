// Copyright (c) 2018-2026, Ladybird contributors
//
// SPDX-License-Identifier: BSD-2-Clause
//
// Translated from Libraries/LibWeb/Layout/*.
// This module is an incremental V port. Functions whose dependencies have not
// been ported yet keep their source signature and comments and return neutral
// stub values so the rest of libweb_v can compile against Layout.

module layout

// ---- Node.h (147 translated function stubs) ----

// Translated from Libraries/LibWeb/Layout/Node.h:41
// Original signature: Node::virtual ~Node();
pub fn node_h_41_destroy_node() LayoutStub {
	return layout_stub('Node.h:41 ~Node')
}

// Translated from Libraries/LibWeb/Layout/Node.h:43
// Original signature: Node::bool is_anonymous() const;
pub fn node_h_43_is_anonymous() LayoutStub {
	return layout_stub('Node.h:43 is_anonymous')
}

// Translated from Libraries/LibWeb/Layout/Node.h:44
// Original signature: Node::DOM::Node const* dom_node() const;
pub fn node_h_44_dom_node() LayoutStub {
	return layout_stub('Node.h:44 dom_node')
}

// Translated from Libraries/LibWeb/Layout/Node.h:45
// Original signature: Node::DOM::Node* dom_node();
pub fn node_h_45_dom_node() LayoutStub {
	return layout_stub('Node.h:45 dom_node')
}

// Translated from Libraries/LibWeb/Layout/Node.h:47
// Original signature: Node::DOM::Element const* pseudo_element_generator() const;
pub fn node_h_47_pseudo_element_generator() LayoutStub {
	return layout_stub('Node.h:47 pseudo_element_generator')
}

// Translated from Libraries/LibWeb/Layout/Node.h:48
// Original signature: Node::DOM::Element* pseudo_element_generator();
pub fn node_h_48_pseudo_element_generator() LayoutStub {
	return layout_stub('Node.h:48 pseudo_element_generator')
}

// Translated from Libraries/LibWeb/Layout/Node.h:50
// Original signature: Node::bool needs_layout_update() const
pub fn node_h_50_needs_layout_update() LayoutStub {
	return layout_stub('Node.h:50 needs_layout_update')
}

// Translated from Libraries/LibWeb/Layout/Node.h:51
// Original signature: Node::void set_needs_layout_update(DOM::SetNeedsLayoutReason);
pub fn node_h_51_set_needs_layout_update() LayoutStub {
	return layout_stub('Node.h:51 set_needs_layout_update')
}

// Translated from Libraries/LibWeb/Layout/Node.h:52
// Original signature: Node::void reset_needs_layout_update()
pub fn node_h_52_reset_needs_layout_update() LayoutStub {
	return layout_stub('Node.h:52 reset_needs_layout_update')
}

// Translated from Libraries/LibWeb/Layout/Node.h:54
// Original signature: Node::bool is_generated_for_pseudo_element() const
pub fn node_h_54_is_generated_for_pseudo_element() LayoutStub {
	return layout_stub('Node.h:54 is_generated_for_pseudo_element')
}

// Translated from Libraries/LibWeb/Layout/Node.h:55
// Original signature: Node::Optional<CSS::PseudoElement> generated_for_pseudo_element() const
pub fn node_h_55_generated_for_pseudo_element() LayoutStub {
	return layout_stub('Node.h:55 generated_for_pseudo_element')
}

// Translated from Libraries/LibWeb/Layout/Node.h:56
// Original signature: Node::bool is_generated_for_before_pseudo_element() const
pub fn node_h_56_is_generated_for_before_pseudo_element() LayoutStub {
	return layout_stub('Node.h:56 is_generated_for_before_pseudo_element')
}

// Translated from Libraries/LibWeb/Layout/Node.h:57
// Original signature: Node::bool is_generated_for_after_pseudo_element() const
pub fn node_h_57_is_generated_for_after_pseudo_element() LayoutStub {
	return layout_stub('Node.h:57 is_generated_for_after_pseudo_element')
}

// Translated from Libraries/LibWeb/Layout/Node.h:58
// Original signature: Node::bool is_generated_for_backdrop_pseudo_element() const
pub fn node_h_58_is_generated_for_backdrop_pseudo_element() LayoutStub {
	return layout_stub('Node.h:58 is_generated_for_backdrop_pseudo_element')
}

// Translated from Libraries/LibWeb/Layout/Node.h:67
// Original signature: Node::Painting::Paintable* first_paintable()
pub fn node_h_67_first_paintable() LayoutStub {
	return layout_stub('Node.h:67 first_paintable')
}

// Translated from Libraries/LibWeb/Layout/Node.h:68
// Original signature: Node::Painting::Paintable const* first_paintable() const
pub fn node_h_68_first_paintable() LayoutStub {
	return layout_stub('Node.h:68 first_paintable')
}

// Translated from Libraries/LibWeb/Layout/Node.h:69
// Original signature: Node::PaintableList& paintables()
pub fn node_h_69_paintables() LayoutStub {
	return layout_stub('Node.h:69 paintables')
}

// Translated from Libraries/LibWeb/Layout/Node.h:70
// Original signature: Node::PaintableList const& paintables() const
pub fn node_h_70_paintables() LayoutStub {
	return layout_stub('Node.h:70 paintables')
}

// Translated from Libraries/LibWeb/Layout/Node.h:71
// Original signature: Node::void add_paintable(GC::Ptr<Painting::Paintable>);
pub fn node_h_71_add_paintable() LayoutStub {
	return layout_stub('Node.h:71 add_paintable')
}

// Translated from Libraries/LibWeb/Layout/Node.h:72
// Original signature: Node::void clear_paintables();
pub fn node_h_72_clear_paintables() LayoutStub {
	return layout_stub('Node.h:72 clear_paintables')
}

// Translated from Libraries/LibWeb/Layout/Node.h:74
// Original signature: Node::virtual GC::Ptr<Painting::Paintable> create_paintable() const;
pub fn node_h_74_create_paintable() LayoutStub {
	return layout_stub('Node.h:74 create_paintable')
}

// Translated from Libraries/LibWeb/Layout/Node.h:76
// Original signature: Node::DOM::Document& document();
pub fn node_h_76_document() LayoutStub {
	return layout_stub('Node.h:76 document')
}

// Translated from Libraries/LibWeb/Layout/Node.h:77
// Original signature: Node::DOM::Document const& document() const;
pub fn node_h_77_document() LayoutStub {
	return layout_stub('Node.h:77 document')
}

// Translated from Libraries/LibWeb/Layout/Node.h:79
// Original signature: Node::GC::Ptr<HTML::Navigable> navigable() const;
pub fn node_h_79_navigable() LayoutStub {
	return layout_stub('Node.h:79 navigable')
}

// Translated from Libraries/LibWeb/Layout/Node.h:81
// Original signature: Node::Viewport const& root() const;
pub fn node_h_81_root() LayoutStub {
	return layout_stub('Node.h:81 root')
}

// Translated from Libraries/LibWeb/Layout/Node.h:82
// Original signature: Node::Viewport& root();
pub fn node_h_82_root() LayoutStub {
	return layout_stub('Node.h:82 root')
}

// Translated from Libraries/LibWeb/Layout/Node.h:84
// Original signature: Node::bool is_root_element() const;
pub fn node_h_84_is_root_element() LayoutStub {
	return layout_stub('Node.h:84 is_root_element')
}

// Translated from Libraries/LibWeb/Layout/Node.h:86
// Original signature: Node::String debug_description() const;
pub fn node_h_86_debug_description() LayoutStub {
	return layout_stub('Node.h:86 debug_description')
}

// Translated from Libraries/LibWeb/Layout/Node.h:88
// Original signature: Node::bool has_style() const
pub fn node_h_88_has_style() LayoutStub {
	return layout_stub('Node.h:88 has_style')
}

// Translated from Libraries/LibWeb/Layout/Node.h:89
// Original signature: Node::bool has_style_or_parent_with_style() const;
pub fn node_h_89_has_style_or_parent_with_style() LayoutStub {
	return layout_stub('Node.h:89 has_style_or_parent_with_style')
}

// Translated from Libraries/LibWeb/Layout/Node.h:91
// Original signature: Node::virtual bool can_have_children() const
pub fn node_h_91_can_have_children() LayoutStub {
	return layout_stub('Node.h:91 can_have_children')
}

// Translated from Libraries/LibWeb/Layout/Node.h:93
// Original signature: Node::CSS::Display display() const;
pub fn node_h_93_display() LayoutStub {
	return layout_stub('Node.h:93 display')
}

// Translated from Libraries/LibWeb/Layout/Node.h:94
// Original signature: Node::CSS::Display display_before_box_type_transformation() const;
pub fn node_h_94_display_before_box_type_transformation() LayoutStub {
	return layout_stub('Node.h:94 display_before_box_type_transformation')
}

// Translated from Libraries/LibWeb/Layout/Node.h:96
// Original signature: Node::bool is_inline() const;
pub fn node_h_96_is_inline() LayoutStub {
	return layout_stub('Node.h:96 is_inline')
}

// Translated from Libraries/LibWeb/Layout/Node.h:97
// Original signature: Node::bool is_inline_block() const;
pub fn node_h_97_is_inline_block() LayoutStub {
	return layout_stub('Node.h:97 is_inline_block')
}

// Translated from Libraries/LibWeb/Layout/Node.h:98
// Original signature: Node::bool is_inline_table() const;
pub fn node_h_98_is_inline_table() LayoutStub {
	return layout_stub('Node.h:98 is_inline_table')
}

// Translated from Libraries/LibWeb/Layout/Node.h:100
// Original signature: Node::bool is_atomic_inline() const;
pub fn node_h_100_is_atomic_inline() LayoutStub {
	return layout_stub('Node.h:100 is_atomic_inline')
}

// Translated from Libraries/LibWeb/Layout/Node.h:102
// Original signature: Node::bool is_out_of_flow(FormattingContext const&) const;
pub fn node_h_102_is_out_of_flow() LayoutStub {
	return layout_stub('Node.h:102 is_out_of_flow')
}

// Translated from Libraries/LibWeb/Layout/Node.h:105
// Original signature: Node::virtual bool is_box() const
// These are used to optimize hot is<T> variants for some classes where dynamic_cast is too slow.
pub fn node_h_105_is_box() LayoutStub {
	return layout_stub('Node.h:105 is_box')
}

// Translated from Libraries/LibWeb/Layout/Node.h:106
// Original signature: Node::virtual bool is_block_container() const
pub fn node_h_106_is_block_container() LayoutStub {
	return layout_stub('Node.h:106 is_block_container')
}

// Translated from Libraries/LibWeb/Layout/Node.h:107
// Original signature: Node::virtual bool is_inline_node() const
pub fn node_h_107_is_inline_node() LayoutStub {
	return layout_stub('Node.h:107 is_inline_node')
}

// Translated from Libraries/LibWeb/Layout/Node.h:108
// Original signature: Node::virtual bool is_break_node() const
pub fn node_h_108_is_break_node() LayoutStub {
	return layout_stub('Node.h:108 is_break_node')
}

// Translated from Libraries/LibWeb/Layout/Node.h:109
// Original signature: Node::virtual bool is_text_node() const
pub fn node_h_109_is_text_node() LayoutStub {
	return layout_stub('Node.h:109 is_text_node')
}

// Translated from Libraries/LibWeb/Layout/Node.h:110
// Original signature: Node::virtual bool is_viewport() const
pub fn node_h_110_is_viewport() LayoutStub {
	return layout_stub('Node.h:110 is_viewport')
}

// Translated from Libraries/LibWeb/Layout/Node.h:111
// Original signature: Node::virtual bool is_svg_box() const
pub fn node_h_111_is_svg_box() LayoutStub {
	return layout_stub('Node.h:111 is_svg_box')
}

// Translated from Libraries/LibWeb/Layout/Node.h:112
// Original signature: Node::virtual bool is_svg_geometry_box() const
pub fn node_h_112_is_svg_geometry_box() LayoutStub {
	return layout_stub('Node.h:112 is_svg_geometry_box')
}

// Translated from Libraries/LibWeb/Layout/Node.h:113
// Original signature: Node::virtual bool is_svg_clip_box() const
pub fn node_h_113_is_svg_clip_box() LayoutStub {
	return layout_stub('Node.h:113 is_svg_clip_box')
}

// Translated from Libraries/LibWeb/Layout/Node.h:114
// Original signature: Node::virtual bool is_svg_mask_box() const
pub fn node_h_114_is_svg_mask_box() LayoutStub {
	return layout_stub('Node.h:114 is_svg_mask_box')
}

// Translated from Libraries/LibWeb/Layout/Node.h:115
// Original signature: Node::virtual bool is_svg_pattern_box() const
pub fn node_h_115_is_svg_pattern_box() LayoutStub {
	return layout_stub('Node.h:115 is_svg_pattern_box')
}

// Translated from Libraries/LibWeb/Layout/Node.h:116
// Original signature: Node::virtual bool is_svg_svg_box() const
pub fn node_h_116_is_svg_svg_box() LayoutStub {
	return layout_stub('Node.h:116 is_svg_svg_box')
}

// Translated from Libraries/LibWeb/Layout/Node.h:117
// Original signature: Node::virtual bool is_svg_graphics_box() const
pub fn node_h_117_is_svg_graphics_box() LayoutStub {
	return layout_stub('Node.h:117 is_svg_graphics_box')
}

// Translated from Libraries/LibWeb/Layout/Node.h:118
// Original signature: Node::virtual bool is_svg_foreign_object_box() const
pub fn node_h_118_is_svg_foreign_object_box() LayoutStub {
	return layout_stub('Node.h:118 is_svg_foreign_object_box')
}

// Translated from Libraries/LibWeb/Layout/Node.h:119
// Original signature: Node::virtual bool is_label() const
pub fn node_h_119_is_label() LayoutStub {
	return layout_stub('Node.h:119 is_label')
}

// Translated from Libraries/LibWeb/Layout/Node.h:120
// Original signature: Node::virtual bool is_replaced_box() const
pub fn node_h_120_is_replaced_box() LayoutStub {
	return layout_stub('Node.h:120 is_replaced_box')
}

// Translated from Libraries/LibWeb/Layout/Node.h:121
// Original signature: Node::virtual bool is_textarea_box() const
pub fn node_h_121_is_textarea_box() LayoutStub {
	return layout_stub('Node.h:121 is_textarea_box')
}

// Translated from Libraries/LibWeb/Layout/Node.h:122
// Original signature: Node::virtual bool is_list_item_box() const
pub fn node_h_122_is_list_item_box() LayoutStub {
	return layout_stub('Node.h:122 is_list_item_box')
}

// Translated from Libraries/LibWeb/Layout/Node.h:123
// Original signature: Node::virtual bool is_list_item_marker_box() const
pub fn node_h_123_is_list_item_marker_box() LayoutStub {
	return layout_stub('Node.h:123 is_list_item_marker_box')
}

// Translated from Libraries/LibWeb/Layout/Node.h:124
// Original signature: Node::virtual bool is_fieldset_box() const
pub fn node_h_124_is_fieldset_box() LayoutStub {
	return layout_stub('Node.h:124 is_fieldset_box')
}

// Translated from Libraries/LibWeb/Layout/Node.h:125
// Original signature: Node::virtual bool is_legend_box() const
pub fn node_h_125_is_legend_box() LayoutStub {
	return layout_stub('Node.h:125 is_legend_box')
}

// Translated from Libraries/LibWeb/Layout/Node.h:126
// Original signature: Node::virtual bool is_table_wrapper() const
pub fn node_h_126_is_table_wrapper() LayoutStub {
	return layout_stub('Node.h:126 is_table_wrapper')
}

// Translated from Libraries/LibWeb/Layout/Node.h:127
// Original signature: Node::virtual bool is_node_with_style() const
pub fn node_h_127_is_node_with_style() LayoutStub {
	return layout_stub('Node.h:127 is_node_with_style')
}

// Translated from Libraries/LibWeb/Layout/Node.h:128
// Original signature: Node::virtual bool is_node_with_style_and_box_model_metrics() const
pub fn node_h_128_is_node_with_style_and_box_model_metrics() LayoutStub {
	return layout_stub('Node.h:128 is_node_with_style_and_box_model_metrics')
}

// Translated from Libraries/LibWeb/Layout/Node.h:130
// Original signature: Node::bool is_replaced_box_with_children() const
pub fn node_h_130_is_replaced_box_with_children() LayoutStub {
	return layout_stub('Node.h:130 is_replaced_box_with_children')
}

// Translated from Libraries/LibWeb/Layout/Node.h:133
// Original signature: Node::bool fast_is() const = delete;
pub fn node_h_133_fast_is() LayoutStub {
	return layout_stub('Node.h:133 fast_is')
}

// Translated from Libraries/LibWeb/Layout/Node.h:135
// Original signature: Node::bool is_floating() const;
pub fn node_h_135_is_floating() LayoutStub {
	return layout_stub('Node.h:135 is_floating')
}

// Translated from Libraries/LibWeb/Layout/Node.h:136
// Original signature: Node::bool is_positioned() const;
pub fn node_h_136_is_positioned() LayoutStub {
	return layout_stub('Node.h:136 is_positioned')
}

// Translated from Libraries/LibWeb/Layout/Node.h:137
// Original signature: Node::bool is_absolutely_positioned() const;
pub fn node_h_137_is_absolutely_positioned() LayoutStub {
	return layout_stub('Node.h:137 is_absolutely_positioned')
}

// Translated from Libraries/LibWeb/Layout/Node.h:138
// Original signature: Node::bool is_fixed_position() const;
pub fn node_h_138_is_fixed_position() LayoutStub {
	return layout_stub('Node.h:138 is_fixed_position')
}

// Translated from Libraries/LibWeb/Layout/Node.h:139
// Original signature: Node::bool is_sticky_position() const;
pub fn node_h_139_is_sticky_position() LayoutStub {
	return layout_stub('Node.h:139 is_sticky_position')
}

// Translated from Libraries/LibWeb/Layout/Node.h:141
// Original signature: Node::bool is_flex_item() const
pub fn node_h_141_is_flex_item() LayoutStub {
	return layout_stub('Node.h:141 is_flex_item')
}

// Translated from Libraries/LibWeb/Layout/Node.h:142
// Original signature: Node::void set_flex_item(bool b)
pub fn node_h_142_set_flex_item() LayoutStub {
	return layout_stub('Node.h:142 set_flex_item')
}

// Translated from Libraries/LibWeb/Layout/Node.h:144
// Original signature: Node::bool is_grid_item() const
pub fn node_h_144_is_grid_item() LayoutStub {
	return layout_stub('Node.h:144 is_grid_item')
}

// Translated from Libraries/LibWeb/Layout/Node.h:145
// Original signature: Node::void set_grid_item(bool b)
pub fn node_h_145_set_grid_item() LayoutStub {
	return layout_stub('Node.h:145 set_grid_item')
}

// Translated from Libraries/LibWeb/Layout/Node.h:147
// Original signature: Node::[[nodiscard]] GC::Ptr<Box const> containing_block() const
pub fn node_h_147_containing_block() LayoutStub {
	return layout_stub('Node.h:147 containing_block')
}

// Translated from Libraries/LibWeb/Layout/Node.h:148
// Original signature: Node::[[nodiscard]] GC::Ptr<Box> containing_block()
pub fn node_h_148_containing_block() LayoutStub {
	return layout_stub('Node.h:148 containing_block')
}

// Translated from Libraries/LibWeb/Layout/Node.h:155
// Original signature: Node::[[nodiscard]] GC::Ptr<InlineNode const> inline_containing_block_if_applicable() const
// Returns the inline node that actually establishes the containing block for this absolutely
// positioned element, if applicable. This is needed because m_containing_block can only hold
// a Box*, but CSS allows inline elements (like a <span> with position:relative) to establish
// containing blocks for their absolutely positioned descendants.
// See the large FIXME comment in FormattingContext.cpp for full context.
pub fn node_h_155_inline_containing_block_if_applicable() LayoutStub {
	return layout_stub('Node.h:155 inline_containing_block_if_applicable')
}

// Translated from Libraries/LibWeb/Layout/Node.h:157
// Original signature: Node::void recompute_containing_block(Badge<DOM::Document>);
pub fn node_h_157_recompute_containing_block() LayoutStub {
	return layout_stub('Node.h:157 recompute_containing_block')
}

// Translated from Libraries/LibWeb/Layout/Node.h:159
// Original signature: Node::[[nodiscard]] Box const* static_position_containing_block() const;
pub fn node_h_159_static_position_containing_block() LayoutStub {
	return layout_stub('Node.h:159 static_position_containing_block')
}

// Translated from Libraries/LibWeb/Layout/Node.h:160
// Original signature: Node::[[nodiscard]] Box* static_position_containing_block()
pub fn node_h_160_static_position_containing_block() LayoutStub {
	return layout_stub('Node.h:160 static_position_containing_block')
}

// Translated from Libraries/LibWeb/Layout/Node.h:166
// Original signature: Node::Box const* non_anonymous_containing_block() const;
// Closest non-anonymous ancestor box, to be used when resolving percentage values.
// Anonymous block boxes are ignored when resolving percentage values that would refer to it:
// the closest non-anonymous ancestor box is used instead.
// https://www.w3.org/TR/CSS22/visuren.html#anonymous-block-level
pub fn node_h_166_non_anonymous_containing_block() LayoutStub {
	return layout_stub('Node.h:166 non_anonymous_containing_block')
}

// Translated from Libraries/LibWeb/Layout/Node.h:168
// Original signature: Node::bool establishes_stacking_context() const;
pub fn node_h_168_establishes_stacking_context() LayoutStub {
	return layout_stub('Node.h:168 establishes_stacking_context')
}

// Translated from Libraries/LibWeb/Layout/Node.h:170
// Original signature: Node::bool computed_values_establish_absolute_positioning_containing_block() const;
pub fn node_h_170_computed_values_establish_absolute_positioning_containing_block() LayoutStub {
	return layout_stub('Node.h:170 computed_values_establish_absolute_positioning_containing_block')
}

// Translated from Libraries/LibWeb/Layout/Node.h:171
// Original signature: Node::bool establishes_an_absolute_positioning_containing_block() const;
pub fn node_h_171_establishes_an_absolute_positioning_containing_block() LayoutStub {
	return layout_stub('Node.h:171 establishes_an_absolute_positioning_containing_block')
}

// Translated from Libraries/LibWeb/Layout/Node.h:172
// Original signature: Node::bool establishes_a_fixed_positioning_containing_block() const;
pub fn node_h_172_establishes_a_fixed_positioning_containing_block() LayoutStub {
	return layout_stub('Node.h:172 establishes_a_fixed_positioning_containing_block')
}

// Translated from Libraries/LibWeb/Layout/Node.h:174
// Original signature: Node::Gfx::Font const& first_available_font() const;
pub fn node_h_174_first_available_font() LayoutStub {
	return layout_stub('Node.h:174 first_available_font')
}

// Translated from Libraries/LibWeb/Layout/Node.h:175
// Original signature: Node::Gfx::Font const& font(DisplayListRecordingContext&) const;
pub fn node_h_175_font() LayoutStub {
	return layout_stub('Node.h:175 font')
}

// Translated from Libraries/LibWeb/Layout/Node.h:176
// Original signature: Node::Gfx::Font const& font(float scale_factor) const;
pub fn node_h_176_font() LayoutStub {
	return layout_stub('Node.h:176 font')
}

// Translated from Libraries/LibWeb/Layout/Node.h:178
// Original signature: Node::CSS::ImmutableComputedValues const& computed_values() const;
pub fn node_h_178_computed_values() LayoutStub {
	return layout_stub('Node.h:178 computed_values')
}

// Translated from Libraries/LibWeb/Layout/Node.h:180
// Original signature: Node::NodeWithStyle* parent();
pub fn node_h_180_parent() LayoutStub {
	return layout_stub('Node.h:180 parent')
}

// Translated from Libraries/LibWeb/Layout/Node.h:181
// Original signature: Node::NodeWithStyle const* parent() const;
pub fn node_h_181_parent() LayoutStub {
	return layout_stub('Node.h:181 parent')
}

// Translated from Libraries/LibWeb/Layout/Node.h:183
// Original signature: Node::void inserted_into(Node&)
pub fn node_h_183_inserted_into() LayoutStub {
	return layout_stub('Node.h:183 inserted_into')
}

// Translated from Libraries/LibWeb/Layout/Node.h:184
// Original signature: Node::void removed_from(Node&)
pub fn node_h_184_removed_from() LayoutStub {
	return layout_stub('Node.h:184 removed_from')
}

// Translated from Libraries/LibWeb/Layout/Node.h:185
// Original signature: Node::void children_changed()
pub fn node_h_185_children_changed() LayoutStub {
	return layout_stub('Node.h:185 children_changed')
}

// Translated from Libraries/LibWeb/Layout/Node.h:187
// Original signature: Node::bool children_are_inline() const
pub fn node_h_187_children_are_inline() LayoutStub {
	return layout_stub('Node.h:187 children_are_inline')
}

// Translated from Libraries/LibWeb/Layout/Node.h:188
// Original signature: Node::void set_children_are_inline(bool value)
pub fn node_h_188_set_children_are_inline() LayoutStub {
	return layout_stub('Node.h:188 set_children_are_inline')
}

// Translated from Libraries/LibWeb/Layout/Node.h:190
// Original signature: Node::u32 initial_quote_nesting_level() const
pub fn node_h_190_initial_quote_nesting_level() LayoutStub {
	return layout_stub('Node.h:190 initial_quote_nesting_level')
}

// Translated from Libraries/LibWeb/Layout/Node.h:191
// Original signature: Node::void set_initial_quote_nesting_level(u32 value)
pub fn node_h_191_set_initial_quote_nesting_level() LayoutStub {
	return layout_stub('Node.h:191 set_initial_quote_nesting_level')
}

// Translated from Libraries/LibWeb/Layout/Node.h:195
// Original signature: Node::bool is_out_of_flow() const
// An element is called out of flow if it is floated, absolutely positioned, or is the root element.
// https://www.w3.org/TR/CSS22/visuren.html#positioning-scheme
pub fn node_h_195_is_out_of_flow() LayoutStub {
	return layout_stub('Node.h:195 is_out_of_flow')
}

// Translated from Libraries/LibWeb/Layout/Node.h:199
// Original signature: Node::bool is_in_flow() const
// An element is called in-flow if it is not out-of-flow.
// https://www.w3.org/TR/CSS22/visuren.html#positioning-scheme
pub fn node_h_199_is_in_flow() LayoutStub {
	return layout_stub('Node.h:199 is_in_flow')
}

// Translated from Libraries/LibWeb/Layout/Node.h:211
// Original signature: Node::CSS::UserSelect user_select_used_value() const;
// https://drafts.csswg.org/css-ui/#propdef-user-select
pub fn node_h_211_user_select_used_value() LayoutStub {
	return layout_stub('Node.h:211 user_select_used_value')
}

// Translated from Libraries/LibWeb/Layout/Node.h:214
// Original signature: Node::bool has_size_containment() const;
// https://drafts.csswg.org/css-contain-2/#containment-types
pub fn node_h_214_has_size_containment() LayoutStub {
	return layout_stub('Node.h:214 has_size_containment')
}

// Translated from Libraries/LibWeb/Layout/Node.h:215
// Original signature: Node::bool has_inline_size_containment() const;
pub fn node_h_215_has_inline_size_containment() LayoutStub {
	return layout_stub('Node.h:215 has_inline_size_containment')
}

// Translated from Libraries/LibWeb/Layout/Node.h:216
// Original signature: Node::bool has_layout_containment() const;
pub fn node_h_216_has_layout_containment() LayoutStub {
	return layout_stub('Node.h:216 has_layout_containment')
}

// Translated from Libraries/LibWeb/Layout/Node.h:217
// Original signature: Node::bool has_style_containment() const;
pub fn node_h_217_has_style_containment() LayoutStub {
	return layout_stub('Node.h:217 has_style_containment')
}

// Translated from Libraries/LibWeb/Layout/Node.h:218
// Original signature: Node::bool has_paint_containment() const;
pub fn node_h_218_has_paint_containment() LayoutStub {
	return layout_stub('Node.h:218 has_paint_containment')
}

// Translated from Libraries/LibWeb/Layout/Node.h:220
// Original signature: Node::[[nodiscard]] bool has_been_wrapped_in_table_wrapper() const
pub fn node_h_220_has_been_wrapped_in_table_wrapper() LayoutStub {
	return layout_stub('Node.h:220 has_been_wrapped_in_table_wrapper')
}

// Translated from Libraries/LibWeb/Layout/Node.h:221
// Original signature: Node::void set_has_been_wrapped_in_table_wrapper(bool value)
pub fn node_h_221_set_has_been_wrapped_in_table_wrapper() LayoutStub {
	return layout_stub('Node.h:221 set_has_been_wrapped_in_table_wrapper')
}

// Translated from Libraries/LibWeb/Layout/Node.h:224
// Original signature: Node::Node(DOM::Document&, DOM::Node*);
pub fn node_h_224_node_node() LayoutStub {
	return layout_stub('Node.h:224 Node::Node')
}

// Translated from Libraries/LibWeb/Layout/Node.h:226
// Original signature: Node::virtual void visit_edges(Cell::Visitor&);
pub fn node_h_226_visit_edges() LayoutStub {
	return layout_stub('Node.h:226 visit_edges')
}

// Translated from Libraries/LibWeb/Layout/Node.h:266
// Original signature: NodeWithStyle::virtual ~NodeWithStyle() = default;
pub fn node_h_266_destroy_node_with_style() LayoutStub {
	return layout_stub('Node.h:266 ~NodeWithStyle')
}

// Translated from Libraries/LibWeb/Layout/Node.h:268
// Original signature: NodeWithStyle::CSS::ImmutableComputedValues const& computed_values() const
pub fn node_h_268_computed_values() LayoutStub {
	return layout_stub('Node.h:268 computed_values')
}

// Translated from Libraries/LibWeb/Layout/Node.h:269
// Original signature: NodeWithStyle::CSS::MutableComputedValues& mutable_computed_values()
pub fn node_h_269_mutable_computed_values() LayoutStub {
	return layout_stub('Node.h:269 mutable_computed_values')
}

// Translated from Libraries/LibWeb/Layout/Node.h:271
// Original signature: NodeWithStyle::void apply_style(CSS::ComputedProperties const&);
pub fn node_h_271_apply_style() LayoutStub {
	return layout_stub('Node.h:271 apply_style')
}

// Translated from Libraries/LibWeb/Layout/Node.h:273
// Original signature: NodeWithStyle::Gfx::Font const& first_available_font() const;
pub fn node_h_273_first_available_font() LayoutStub {
	return layout_stub('Node.h:273 first_available_font')
}

// Translated from Libraries/LibWeb/Layout/Node.h:274
// Original signature: NodeWithStyle::Vector<CSS::BackgroundLayerData> const& background_layers() const
pub fn node_h_274_background_layers() LayoutStub {
	return layout_stub('Node.h:274 background_layers')
}

// Translated from Libraries/LibWeb/Layout/Node.h:275
// Original signature: NodeWithStyle::CSS::AbstractImageStyleValue const* list_style_image() const
pub fn node_h_275_list_style_image() LayoutStub {
	return layout_stub('Node.h:275 list_style_image')
}

// Translated from Libraries/LibWeb/Layout/Node.h:277
// Original signature: NodeWithStyle::GC::Ref<NodeWithStyle> create_anonymous_wrapper() const;
pub fn node_h_277_create_anonymous_wrapper() LayoutStub {
	return layout_stub('Node.h:277 create_anonymous_wrapper')
}

// Translated from Libraries/LibWeb/Layout/Node.h:279
// Original signature: NodeWithStyle::void transfer_table_box_computed_values_to_wrapper_computed_values(CSS::ComputedValues& wrapper_computed_values);
pub fn node_h_279_transfer_table_box_computed_values_to_wrapper_computed_values() LayoutStub {
	return layout_stub('Node.h:279 transfer_table_box_computed_values_to_wrapper_computed_values')
}

// Translated from Libraries/LibWeb/Layout/Node.h:281
// Original signature: NodeWithStyle::bool is_body() const
pub fn node_h_281_is_body() LayoutStub {
	return layout_stub('Node.h:281 is_body')
}

// Translated from Libraries/LibWeb/Layout/Node.h:282
// Original signature: NodeWithStyle::bool is_scroll_container() const;
pub fn node_h_282_is_scroll_container() LayoutStub {
	return layout_stub('Node.h:282 is_scroll_container')
}

// Translated from Libraries/LibWeb/Layout/Node.h:284
// Original signature: NodeWithStyle::virtual void visit_edges(Cell::Visitor& visitor);
pub fn node_h_284_visit_edges() LayoutStub {
	return layout_stub('Node.h:284 visit_edges')
}

// Translated from Libraries/LibWeb/Layout/Node.h:286
// Original signature: NodeWithStyle::void set_computed_values(NonnullOwnPtr<CSS::ComputedValues>);
pub fn node_h_286_set_computed_values() LayoutStub {
	return layout_stub('Node.h:286 set_computed_values')
}

// Translated from Libraries/LibWeb/Layout/Node.h:288
// Original signature: NodeWithStyle::u32 layout_index() const
pub fn node_h_288_layout_index() LayoutStub {
	return layout_stub('Node.h:288 layout_index')
}

// Translated from Libraries/LibWeb/Layout/Node.h:289
// Original signature: NodeWithStyle::void set_layout_index(u32 index)
pub fn node_h_289_set_layout_index() LayoutStub {
	return layout_stub('Node.h:289 set_layout_index')
}

// Translated from Libraries/LibWeb/Layout/Node.h:292
// Original signature: NodeWithStyle::NodeWithStyle(DOM::Document&, DOM::Node*, GC::Ref<CSS::ComputedProperties>);
pub fn node_h_292_node_with_style_node_with_style() LayoutStub {
	return layout_stub('Node.h:292 NodeWithStyle::NodeWithStyle')
}

// Translated from Libraries/LibWeb/Layout/Node.h:293
// Original signature: NodeWithStyle::NodeWithStyle(DOM::Document&, DOM::Node*, NonnullOwnPtr<CSS::ComputedValues>);
pub fn node_h_293_node_with_style_node_with_style() LayoutStub {
	return layout_stub('Node.h:293 NodeWithStyle::NodeWithStyle')
}

// Translated from Libraries/LibWeb/Layout/Node.h:296
// Original signature: NodeWithStyle::virtual bool is_node_with_style() const
pub fn node_h_296_is_node_with_style() LayoutStub {
	return layout_stub('Node.h:296 is_node_with_style')
}

// Translated from Libraries/LibWeb/Layout/Node.h:298
// Original signature: NodeWithStyle::void reset_table_box_computed_values_used_by_wrapper_to_init_values();
pub fn node_h_298_reset_table_box_computed_values_used_by_wrapper_to_init_values() LayoutStub {
	return layout_stub('Node.h:298 reset_table_box_computed_values_used_by_wrapper_to_init_values')
}

// Translated from Libraries/LibWeb/Layout/Node.h:299
// Original signature: NodeWithStyle::void propagate_non_inherit_values(NodeWithStyle& target_node) const;
pub fn node_h_299_propagate_non_inherit_values() LayoutStub {
	return layout_stub('Node.h:299 propagate_non_inherit_values')
}

// Translated from Libraries/LibWeb/Layout/Node.h:300
// Original signature: NodeWithStyle::void propagate_style_to_anonymous_wrappers();
pub fn node_h_300_propagate_style_to_anonymous_wrappers() LayoutStub {
	return layout_stub('Node.h:300 propagate_style_to_anonymous_wrappers')
}

// Translated from Libraries/LibWeb/Layout/Node.h:308
// Original signature: inline bool Node::fast_is<NodeWithStyle>() const
pub fn node_h_308_function() LayoutStub {
	return layout_stub('Node.h:308 function')
}

// Translated from Libraries/LibWeb/Layout/Node.h:314
// Original signature: NodeWithStyleAndBoxModelMetrics::GC::Ptr<NodeWithStyleAndBoxModelMetrics> continuation_of_node() const
pub fn node_h_314_continuation_of_node() LayoutStub {
	return layout_stub('Node.h:314 continuation_of_node')
}

// Translated from Libraries/LibWeb/Layout/Node.h:315
// Original signature: NodeWithStyleAndBoxModelMetrics::void set_continuation_of_node(Badge<TreeBuilder>, GC::Ptr<NodeWithStyleAndBoxModelMetrics> node)
pub fn node_h_315_set_continuation_of_node() LayoutStub {
	return layout_stub('Node.h:315 set_continuation_of_node')
}

// Translated from Libraries/LibWeb/Layout/Node.h:317
// Original signature: NodeWithStyleAndBoxModelMetrics::bool should_create_inline_continuation() const;
pub fn node_h_317_should_create_inline_continuation() LayoutStub {
	return layout_stub('Node.h:317 should_create_inline_continuation')
}

// Translated from Libraries/LibWeb/Layout/Node.h:319
// Original signature: NodeWithStyleAndBoxModelMetrics::void propagate_style_along_continuation(CSS::ComputedProperties const&) const;
pub fn node_h_319_propagate_style_along_continuation() LayoutStub {
	return layout_stub('Node.h:319 propagate_style_along_continuation')
}

// Translated from Libraries/LibWeb/Layout/Node.h:321
// Original signature: NodeWithStyleAndBoxModelMetrics::virtual void visit_edges(Cell::Visitor& visitor);
pub fn node_h_321_visit_edges() LayoutStub {
	return layout_stub('Node.h:321 visit_edges')
}

// Translated from Libraries/LibWeb/Layout/Node.h:335
// Original signature: NodeWithStyleAndBoxModelMetrics::virtual bool is_node_with_style_and_box_model_metrics() const
pub fn node_h_335_is_node_with_style_and_box_model_metrics() LayoutStub {
	return layout_stub('Node.h:335 is_node_with_style_and_box_model_metrics')
}

// Translated from Libraries/LibWeb/Layout/Node.h:341
// Original signature: inline bool Node::fast_is<NodeWithStyleAndBoxModelMetrics>() const
pub fn node_h_341_function() LayoutStub {
	return layout_stub('Node.h:341 function')
}

// Translated from Libraries/LibWeb/Layout/Node.h:343
// Original signature: inline bool Node::has_style_or_parent_with_style() const
pub fn node_h_343_node_has_style_or_parent_with_style() LayoutStub {
	return layout_stub('Node.h:343 Node::has_style_or_parent_with_style')
}

// Translated from Libraries/LibWeb/Layout/Node.h:348
// Original signature: inline Gfx::Font const& Node::first_available_font() const
pub fn node_h_348_node_first_available_font() LayoutStub {
	return layout_stub('Node.h:348 Node::first_available_font')
}

// Translated from Libraries/LibWeb/Layout/Node.h:356
// Original signature: inline Gfx::Font const& Node::font(DisplayListRecordingContext& context) const
pub fn node_h_356_node_font() LayoutStub {
	return layout_stub('Node.h:356 Node::font')
}

// Translated from Libraries/LibWeb/Layout/Node.h:361
// Original signature: inline Gfx::Font const& Node::font(float scale_factor) const
pub fn node_h_361_node_font() LayoutStub {
	return layout_stub('Node.h:361 Node::font')
}

// Translated from Libraries/LibWeb/Layout/Node.h:367
// Original signature: inline CSS::ImmutableComputedValues const& Node::computed_values() const
pub fn node_h_367_node_computed_values() LayoutStub {
	return layout_stub('Node.h:367 Node::computed_values')
}

// Translated from Libraries/LibWeb/Layout/Node.h:376
// Original signature: inline NodeWithStyle const* Node::parent() const
pub fn node_h_376_node_parent() LayoutStub {
	return layout_stub('Node.h:376 Node::parent')
}

// Translated from Libraries/LibWeb/Layout/Node.h:381
// Original signature: inline NodeWithStyle* Node::parent()
pub fn node_h_381_node_parent() LayoutStub {
	return layout_stub('Node.h:381 Node::parent')
}

// Translated from Libraries/LibWeb/Layout/Node.h:386
// Original signature: inline Gfx::Font const& NodeWithStyle::first_available_font() const
// https://drafts.csswg.org/css-fonts/#first-available-font
// First font for which the character U+0020 (space) is not excluded by a unicode-range
pub fn node_h_386_node_with_style_first_available_font() LayoutStub {
	return layout_stub('Node.h:386 NodeWithStyle::first_available_font')
}

// Translated from Libraries/LibWeb/Layout/Node.h:393
// Original signature: bool overflow_value_makes_box_a_scroll_container(CSS::Overflow overflow);
pub fn node_h_393_overflow_value_makes_box_a_scroll_container() LayoutStub {
	return layout_stub('Node.h:393 overflow_value_makes_box_a_scroll_container')
}

// ---- Node.cpp (60 translated function stubs) ----

// Translated from Libraries/LibWeb/Layout/Node.cpp:43
// Original signature: Node::Node(DOM::Document& document, DOM::Node* node) : m_dom_node(node ? *node : document) , m_anonymous(node == nullptr)
pub fn node_cpp_43_node_node() LayoutStub {
	return layout_stub('Node.cpp:43 Node::Node')
}

// Translated from Libraries/LibWeb/Layout/Node.cpp:51
// Original signature: Node::~Node() = default;
pub fn node_cpp_51_node_destroy_node() LayoutStub {
	return layout_stub('Node.cpp:51 Node::~Node')
}

// Translated from Libraries/LibWeb/Layout/Node.cpp:53
// Original signature: void Node::visit_edges(Cell::Visitor& visitor)
pub fn node_cpp_53_node_visit_edges() LayoutStub {
	return layout_stub('Node.cpp:53 Node::visit_edges')
}

// Translated from Libraries/LibWeb/Layout/Node.cpp:67
// Original signature: bool Node::is_out_of_flow(FormattingContext const& formatting_context) const
// https://www.w3.org/TR/css-display-3/#out-of-flow
// A layout node is out of flow if either:
// 1. It is floated (which requires that floating is not inhibited).
// 2. It is "absolutely positioned".
pub fn node_cpp_67_node_is_out_of_flow() LayoutStub {
	return layout_stub('Node.cpp:67 Node::is_out_of_flow')
}

// Translated from Libraries/LibWeb/Layout/Node.cpp:86
// Original signature: bool Node::computed_values_establish_absolute_positioning_containing_block() const
// https://drafts.csswg.org/css-position-3/#absolute-positioning-containing-block
// Checks if the computed values of this node would establish an absolute positioning
// containing block. This is separate from establishes_an_absolute_positioning_containing_block()
// because that function also checks is<Box>, but we need these checks for inline elements too.
// https://drafts.csswg.org/css-will-change/#will-change
// If any non-initial value of a property would cause the element to generate a containing block for absolutely
// positioned elements, specifying that property in will-change must cause the element to generate a containing
// block for absolutely positioned elements.
// https://drafts.csswg.org/css-position/#position-property
// Values other than 'static' make the box a positioned box, and cause it to establish an absolute positioning
// containing block for its descendants.
// https://drafts.csswg.org/css-transforms-1/#propdef-transform
// Any computed value other than none for the transform affects containing block and stacking context
// https://drafts.csswg.org/css-transforms-2/#propdef-perspective
// The use of this property with any value other than 'none' establishes a stacking context. It also establishes
// a containing block for all descendants, just like the 'transform' property does.
// https://drafts.csswg.org/filter-effects-1/#FilterProperty
// A value other than none for the filter property results in the creation of a containing block for absolute and
// fixed positioned descendants, unless the element it applies to is a document root element in the current
// browsing context.
// https://drafts.csswg.org/filter-effects-2/#BackdropFilterProperty
// A computed value of other than none results in the creation of both a stacking context and a containing block
// for absolute and fixed position descendants, unless the element it applies to is a document root element in
// the
// current browsing context.
// https://drafts.csswg.org/css-contain-2/#containment-types
// 4. The layout containment box establishes an absolute positioning containing block and a fixed positioning
// containing block.
// 4. The paint containment box establishes an absolute positioning containing block and a fixed positioning
// https://drafts.csswg.org/css-transforms-2/#transform-style-property
// A computed value of 'preserve-3d' for 'transform-style' on a transformable element establishes both a
// stacking context and a containing block for all descendants.
// FIXME: Check that the element is a transformable element.
// https://drafts.csswg.org/css-view-transitions-1/#snapshot-containing-block-concept
// FIXME: The snapshot containing block is considered to be an absolute positioning containing block and a fixed
// positioning containing block for ::view-transition and its descendants.
pub fn node_cpp_86_node_computed_values_establish_absolute_positioning_containing_block() LayoutStub {
	return layout_stub('Node.cpp:86 Node::computed_values_establish_absolute_positioning_containing_block')
}

// Translated from Libraries/LibWeb/Layout/Node.cpp:158
// Original signature: bool Node::establishes_an_absolute_positioning_containing_block() const
// https://drafts.csswg.org/css-position-3/#absolute-positioning-containing-block
// https://github.com/w3c/fxtf-drafts/issues/307#issuecomment-499612420
// foreignObject establishes a containing block for absolutely and fixed positioned elements.
pub fn node_cpp_158_node_establishes_an_absolute_positioning_containing_block() LayoutStub {
	return layout_stub('Node.cpp:158 Node::establishes_an_absolute_positioning_containing_block')
}

// Translated from Libraries/LibWeb/Layout/Node.cpp:175
// Original signature: bool Node::establishes_a_fixed_positioning_containing_block() const
// https://drafts.csswg.org/css-position-3/#fixed-positioning-containing-block
// https://drafts.csswg.org/css-will-change/#will-change
// If any non-initial value of a property would cause the element to generate a containing block for fixed
// positioned elements, specifying that property in will-change must cause the element to generate a containing
// block for fixed positioned elements.
// https://drafts.csswg.org/css-transforms-1/#propdef-transform
// Any computed value other than none for the transform affects containing block and stacking context
// https://drafts.csswg.org/css-transforms-2/#propdef-perspective
// The use of this property with any value other than 'none' establishes a stacking context. It also establishes
// a containing block for all descendants, just like the 'transform' property does.
// https://drafts.csswg.org/filter-effects-1/#FilterProperty
// A value other than none for the filter property results in the creation of a containing block for absolute and
// fixed positioned descendants, unless the element it applies to is a document root element in the current
// browsing context.
// https://drafts.csswg.org/filter-effects-2/#BackdropFilterProperty
// A computed value of other than none results in the creation of both a stacking context and a containing block
// for absolute and fixed position descendants, unless the element it applies to is a document root element in
// the
// current browsing context.
// https://drafts.csswg.org/css-contain-2/#containment-types
// 4. The layout containment box establishes an absolute positioning containing block and a fixed positioning
// containing block.
// 4. The paint containment box establishes an absolute positioning containing block and a fixed positioning
// https://drafts.csswg.org/css-transforms-2/#transform-style-property
// A computed value of 'preserve-3d' for 'transform-style' on a transformable element establishes both a
// stacking context and a containing block for all descendants.
// FIXME: Check that the element is a transformable element.
// https://drafts.csswg.org/css-view-transitions-1/#snapshot-containing-block-concept
// FIXME: The snapshot containing block is considered to be an absolute positioning containing block and a fixed
// positioning containing block for ::view-transition and its descendants.
pub fn node_cpp_175_node_establishes_a_fixed_positioning_containing_block() LayoutStub {
	return layout_stub('Node.cpp:175 Node::establishes_a_fixed_positioning_containing_block')
}

// Translated from Libraries/LibWeb/Layout/Node.cpp:243
// Original signature: static GC::Ptr<Box> nearest_ancestor_capable_of_forming_a_containing_block(Node& node)
pub fn node_cpp_243_nearest_ancestor_capable_of_forming_a_containing_block() LayoutStub {
	return layout_stub('Node.cpp:243 nearest_ancestor_capable_of_forming_a_containing_block')
}

// Translated from Libraries/LibWeb/Layout/Node.cpp:256
// Original signature: void Node::recompute_containing_block(Badge<DOM::Document>)
// Reset the inline containing block - we'll set it below if applicable.
// https://drafts.csswg.org/css-position-3/#absolute-cb
// FIXME: Containing block handling for absolutely positioned elements needs architectural improvements.
// The CSS specification defines the containing block as a *rectangle*, not a box. For most cases,
// this rectangle is derived from the padding box of the nearest positioned ancestor Box. However,
// when the positioned ancestor is an *inline* element (e.g., a <span> with position: relative),
// the containing block rectangle should be the bounding box of that inline's fragments.
// Currently, m_containing_block is typed as Box*, which cannot represent inline elements.
// The proper fix would be to:
// 1. Separate the concept of "the node that establishes the containing block" from "the containing
// block rectangle".
// 2. Store a reference to the establishing node (which could be InlineNode or Box).
// 3. Compute the containing block rectangle on demand based on the establishing node's type.
// For now, we use a workaround: check if there's an inline element with position:relative (or
// other containing-block-establishing properties) between this node and its containing_block()
// in the DOM tree. If found, store it in m_inline_containing_block_if_applicable.
// We check the DOM tree here (rather than the layout tree) because when a block element is inside
// an inline element, the layout tree restructures so the block becomes a sibling of the inline.
// But the CSS containing block relationship is based on the DOM structure.
// For pseudo-elements, we need to start from the generating element itself, since it may
// be the inline containing block. For regular elements, start from parent_element().
// Stop if we reach the DOM node of the containing block.
// NB: Called during containing block recomputation as part of layout.
// Check if this DOM element has an InlineNode in the layout tree.
// Check if this inline establishes an absolute positioning containing block.
// https://drafts.csswg.org/css-position-3/#fixed-cb
// The containing block is established by the nearest ancestor box that establishes an fixed positioning
// containing block, with the bounds of the containing block determined identically to the absolute positioning
// containing block.
// If no ancestor establishes one, the box's fixed positioning containing block is the initial fixed containing
// block:
// - in continuous media, the layout viewport (whose size matches the dynamic viewport size); as a result,
// fixed boxes do not move when the document is scrolled.
// FIXME: - in paged media, the page area of each page; fixed positioned boxes are thus replicated on every
// page. (They are fixed with respect to the page box only, and are not affected by being seen through a
// viewport; as in the case of print preview, for example.)
pub fn node_cpp_256_node_recompute_containing_block() LayoutStub {
	return layout_stub('Node.cpp:256 Node::recompute_containing_block')
}

// Translated from Libraries/LibWeb/Layout/Node.cpp:356
// Original signature: Box const* Node::static_position_containing_block() const
// returns containing block this node would have had if its position was static
pub fn node_cpp_356_node_static_position_containing_block() LayoutStub {
	return layout_stub('Node.cpp:356 Node::static_position_containing_block')
}

// Translated from Libraries/LibWeb/Layout/Node.cpp:361
// Original signature: Box const* Node::non_anonymous_containing_block() const
pub fn node_cpp_361_node_non_anonymous_containing_block() LayoutStub {
	return layout_stub('Node.cpp:361 Node::non_anonymous_containing_block')
}

// Translated from Libraries/LibWeb/Layout/Node.cpp:373
// Original signature: bool Node::establishes_stacking_context() const
// https://developer.mozilla.org/en-US/docs/Web/CSS/CSS_Positioning/Understanding_z_index/The_stacking_context
// NOTE: While MDN is not authoritative, there isn't a single convenient location
// in the CSS specifications where the rules for stacking contexts is described.
// That's why the "spec link" here points to MDN.
// We make a stacking context for the viewport. Painting and hit testing starts from here.
// Root element of the document (<html>).
// https://drafts.csswg.org/css-will-change/#will-change
// If any non-initial value of a property would create a stacking context on the element, specifying that
// property
// in will-change must create a stacking context on the element.
// Element with a position value absolute or relative and z-index value other than auto.
// Element with a position value fixed or sticky.
// Element that is a child of a flex container, with z-index value other than auto.
// Element that is a child of a grid container, with z-index value other than auto.
// https://drafts.fxtf.org/filter-effects/#FilterProperty
// https://drafts.fxtf.org/filter-effects-2/#backdrop-filter-operation
// A computed value of other than none results in the creation of both a stacking context
// [CSS21] and a Containing Block for absolute and fixed position descendants, unless the
// element it applies to is a document root element in the current browsing context.
// Spec Note: This rule works in the same way as for the filter property.
// Element with any of the following properties with value other than none:
// - transform
// - filter
// - backdrop-filter
// - perspective
// - clip-path
// - mask / mask-image / mask-border
// https://drafts.fxtf.org/compositing/#propdef-isolation
// For CSS, setting isolation to isolate will turn the element into a stacking context.
// https://drafts.csswg.org/css-contain-2/#containment-types
// 5. The layout containment box creates a stacking context.
// 3. The paint containment box creates a stacking context.
// https://drafts.fxtf.org/compositing/#mix-blend-mode
// Applying a blendmode other than normal to the element must establish a new stacking context.
// https://drafts.csswg.org/css-view-transitions-1/#named-and-transitioning
// Elements captured in a view transition during a view transition or whose view-transition-name computed value
// is
// not 'none' (at any time):
// - Form a stacking context.
// https://drafts.csswg.org/css-transforms-2/#propdef-perspective
// The use of this property with any value other than 'none' establishes a stacking context.
// https://drafts.csswg.org/css-transforms-2/#transform-style-property
// A computed value of 'preserve-3d' for 'transform-style' on a transformable element establishes both a
// stacking context and a containing block for all descendants.
// FIXME: Check that the element is a transformable element.
pub fn node_cpp_373_node_establishes_stacking_context() LayoutStub {
	return layout_stub('Node.cpp:373 Node::establishes_stacking_context')
}

// Translated from Libraries/LibWeb/Layout/Node.cpp:506
// Original signature: GC::Ptr<HTML::Navigable> Node::navigable() const
pub fn node_cpp_506_node_navigable() LayoutStub {
	return layout_stub('Node.cpp:506 Node::navigable')
}

// Translated from Libraries/LibWeb/Layout/Node.cpp:511
// Original signature: Viewport const& Node::root() const
// NB: Called during layout, which is in progress.
pub fn node_cpp_511_node_root() LayoutStub {
	return layout_stub('Node.cpp:511 Node::root')
}

// Translated from Libraries/LibWeb/Layout/Node.cpp:518
// Original signature: Viewport& Node::root()
// NB: Called during layout, which is in progress.
pub fn node_cpp_518_node_root() LayoutStub {
	return layout_stub('Node.cpp:518 Node::root')
}

// Translated from Libraries/LibWeb/Layout/Node.cpp:525
// Original signature: bool Node::is_floating() const
// flex-items don't float.
pub fn node_cpp_525_node_is_floating() LayoutStub {
	return layout_stub('Node.cpp:525 Node::is_floating')
}

// Translated from Libraries/LibWeb/Layout/Node.cpp:535
// Original signature: bool Node::is_positioned() const
pub fn node_cpp_535_node_is_positioned() LayoutStub {
	return layout_stub('Node.cpp:535 Node::is_positioned')
}

// Translated from Libraries/LibWeb/Layout/Node.cpp:540
// Original signature: bool Node::is_absolutely_positioned() const
pub fn node_cpp_540_node_is_absolutely_positioned() LayoutStub {
	return layout_stub('Node.cpp:540 Node::is_absolutely_positioned')
}

// Translated from Libraries/LibWeb/Layout/Node.cpp:548
// Original signature: bool Node::is_fixed_position() const
pub fn node_cpp_548_node_is_fixed_position() LayoutStub {
	return layout_stub('Node.cpp:548 Node::is_fixed_position')
}

// Translated from Libraries/LibWeb/Layout/Node.cpp:556
// Original signature: bool Node::is_sticky_position() const
pub fn node_cpp_556_node_is_sticky_position() LayoutStub {
	return layout_stub('Node.cpp:556 Node::is_sticky_position')
}

// Translated from Libraries/LibWeb/Layout/Node.cpp:564
// Original signature: NodeWithStyle::NodeWithStyle(DOM::Document& document, DOM::Node* node, GC::Ref<CSS::ComputedProperties> computed_style) : Node(document, node) , m_computed_values(make<CSS::ComputedValues>())
pub fn node_cpp_564_node_with_style_node_with_style() LayoutStub {
	return layout_stub('Node.cpp:564 NodeWithStyle::NodeWithStyle')
}

// Translated from Libraries/LibWeb/Layout/Node.cpp:573
// Original signature: NodeWithStyle::NodeWithStyle(DOM::Document& document, DOM::Node* node, NonnullOwnPtr<CSS::ComputedValues> computed_values) : Node(document, node) , m_computed_values(move(computed_values))
pub fn node_cpp_573_node_with_style_node_with_style() LayoutStub {
	return layout_stub('Node.cpp:573 NodeWithStyle::NodeWithStyle')
}

// Translated from Libraries/LibWeb/Layout/Node.cpp:581
// Original signature: void NodeWithStyle::visit_edges(Visitor& visitor)
pub fn node_cpp_581_node_with_style_visit_edges() LayoutStub {
	return layout_stub('Node.cpp:581 NodeWithStyle::visit_edges')
}

// Translated from Libraries/LibWeb/Layout/Node.cpp:593
// Original signature: void NodeWithStyle::apply_style(CSS::ComputedProperties const& computed_style)
// NOTE: color-scheme must be set first to ensure system colors can be resolved correctly.
// NOTE: We have to be careful that font-related properties get set in the right order.
// m_font is used by Length::to_px() when resolving sizes against this layout node.
// That's why it has to be set before everything else.
// NOTE: color must be set after color-scheme to ensure currentColor can be resolved in other properties (e.g.
// background-color).
// NOTE: color must be set after font_size as `CalculatedStyleValue`s can rely on it being set for resolving
// lengths.
// NOTE: Currently there are still discussions about `accentColor` and `currentColor` interactions, so the line
// below might need changing in the future
// NOTE: This color resolution context must be created after we set color above so that currentColor resolves
// correctly
// FIXME: We should resolve colors to their absolute forms at compute time (i.e. by implementing the relevant
// absolutized methods)
// FIXME: The default text decoration color value is `currentcolor`, but since we can't resolve that easily,
// we just manually grab the value from `color`. This makes it dependent on `color` being
// specified first, so it's far from ideal.
// FIXME: The default border color value is `currentcolor`, but since we can't resolve that easily,
// If the border-style corresponding to a given border-width is none or hidden, then the used width is 0.
// https://drafts.csswg.org/css-backgrounds/#border-width
// FIXME: Interpolation can cause negative values - we clamp here but should instead clamp as part of
// interpolation
// FIXME: Support calc()
// FIXME: Interpolation can cause negative values - we clamp here but should instead clamp as part of
// interpolation.
// FIXME: Converting to pixels isn't really correct - values should be in "user units"
// https://svgwg.org/svg2-draft/coords.html#TermUserUnits
// FIXME: We should actually support more than one mask image rather than just using the first
// https://drafts.csswg.org/css-sizing-4/#aspect-ratio
// If the <ratio> is degenerate, the property instead behaves as auto.
pub fn node_cpp_593_node_with_style_apply_style() LayoutStub {
	return layout_stub('Node.cpp:593 NodeWithStyle::apply_style')
}

// Translated from Libraries/LibWeb/Layout/Node.cpp:991
// Original signature: void NodeWithStyle::propagate_non_inherit_values(NodeWithStyle& target_node) const
// NOTE: These properties are not inherited, but we still have to propagate them to anonymous wrappers.
pub fn node_cpp_991_node_with_style_propagate_non_inherit_values() LayoutStub {
	return layout_stub('Node.cpp:991 NodeWithStyle::propagate_non_inherit_values')
}

// Translated from Libraries/LibWeb/Layout/Node.cpp:1000
// Original signature: void NodeWithStyle::propagate_style_to_anonymous_wrappers()
// Update the style of any anonymous wrappers that inherit from this node.
// FIXME: This is pretty hackish. It would be nicer if they shared the inherited style
// data structure somehow, so this wasn't necessary.
// If this is a `display:table` box with an anonymous wrapper parent,
// the parent inherits style from *this* node, not the other way around.
// Propagate style to all anonymous children (except table wrappers!)
pub fn node_cpp_1000_node_with_style_propagate_style_to_anonymous_wrappers() LayoutStub {
	return layout_stub('Node.cpp:1000 NodeWithStyle::propagate_style_to_anonymous_wrappers')
}

// Translated from Libraries/LibWeb/Layout/Node.cpp:1025
// Original signature: bool Node::is_root_element() const
pub fn node_cpp_1025_node_is_root_element() LayoutStub {
	return layout_stub('Node.cpp:1025 Node::is_root_element')
}

// Translated from Libraries/LibWeb/Layout/Node.cpp:1032
// Original signature: String Node::debug_description() const
pub fn node_cpp_1032_node_debug_description() LayoutStub {
	return layout_stub('Node.cpp:1032 Node::debug_description')
}

// Translated from Libraries/LibWeb/Layout/Node.cpp:1051
// Original signature: CSS::Display Node::display() const
// NOTE: No style means this is dumb text content.
pub fn node_cpp_1051_node_display() LayoutStub {
	return layout_stub('Node.cpp:1051 Node::display')
}

// Translated from Libraries/LibWeb/Layout/Node.cpp:1061
// Original signature: CSS::Display Node::display_before_box_type_transformation() const
pub fn node_cpp_1061_node_display_before_box_type_transformation() LayoutStub {
	return layout_stub('Node.cpp:1061 Node::display_before_box_type_transformation')
}

// Translated from Libraries/LibWeb/Layout/Node.cpp:1070
// Original signature: bool Node::is_inline() const
pub fn node_cpp_1070_node_is_inline() LayoutStub {
	return layout_stub('Node.cpp:1070 Node::is_inline')
}

// Translated from Libraries/LibWeb/Layout/Node.cpp:1075
// Original signature: bool Node::is_inline_block() const
pub fn node_cpp_1075_node_is_inline_block() LayoutStub {
	return layout_stub('Node.cpp:1075 Node::is_inline_block')
}

// Translated from Libraries/LibWeb/Layout/Node.cpp:1081
// Original signature: bool Node::is_inline_table() const
pub fn node_cpp_1081_node_is_inline_table() LayoutStub {
	return layout_stub('Node.cpp:1081 Node::is_inline_table')
}

// Translated from Libraries/LibWeb/Layout/Node.cpp:1087
// Original signature: bool Node::is_atomic_inline() const
pub fn node_cpp_1087_node_is_atomic_inline() LayoutStub {
	return layout_stub('Node.cpp:1087 Node::is_atomic_inline')
}

// Translated from Libraries/LibWeb/Layout/Node.cpp:1095
// Original signature: GC::Ref<NodeWithStyle> NodeWithStyle::create_anonymous_wrapper() const
// CSS 2.2 9.2.1.1 creates anonymous block boxes, but 9.4.1 states inline-block creates a BFC.
// Set wrapper to inline-block to participate correctly in the IFC within the parent inline-block.
pub fn node_cpp_1095_node_with_style_create_anonymous_wrapper() LayoutStub {
	return layout_stub('Node.cpp:1095 NodeWithStyle::create_anonymous_wrapper')
}

// Translated from Libraries/LibWeb/Layout/Node.cpp:1108
// Original signature: void NodeWithStyle::set_computed_values(NonnullOwnPtr<CSS::ComputedValues> computed_values)
pub fn node_cpp_1108_node_with_style_set_computed_values() LayoutStub {
	return layout_stub('Node.cpp:1108 NodeWithStyle::set_computed_values')
}

// Translated from Libraries/LibWeb/Layout/Node.cpp:1113
// Original signature: void NodeWithStyle::reset_table_box_computed_values_used_by_wrapper_to_init_values()
// AD-HOC:
// To match other browsers, z-index needs to be moved to the wrapper box as well,
// even if the spec does not mention that: https://github.com/w3c/csswg-drafts/issues/11689
// Note that there may be more properties that need to be added to this list.
pub fn node_cpp_1113_node_with_style_reset_table_box_computed_values_used_by_wrapper_to_init_values() LayoutStub {
	return layout_stub('Node.cpp:1113 NodeWithStyle::reset_table_box_computed_values_used_by_wrapper_to_init_values')
}

// Translated from Libraries/LibWeb/Layout/Node.cpp:1130
// Original signature: void NodeWithStyle::transfer_table_box_computed_values_to_wrapper_computed_values(CSS::ComputedValues& wrapper_computed_values)
// The computed values of properties 'position', 'float', 'margin-*', 'top', 'right', 'bottom', and 'left' on the
// table element are used on the table wrapper box and not the table box;
// all other values of non-inheritable properties are used on the table box and not the table wrapper box.
// (Where the table element's values are not used on the table and table wrapper boxes, the initial values are
// used instead.)
// AD-HOC:
// To match other browsers, z-index needs to be moved to the wrapper box as well,
// even if the spec does not mention that: https://github.com/w3c/csswg-drafts/issues/11689
// Note that there may be more properties that need to be added to this list.
pub fn node_cpp_1130_node_with_style_transfer_table_box_computed_values_to_wrapper_computed_values() LayoutStub {
	return layout_stub('Node.cpp:1130 NodeWithStyle::transfer_table_box_computed_values_to_wrapper_computed_values')
}

// Translated from Libraries/LibWeb/Layout/Node.cpp:1154
// Original signature: bool overflow_value_makes_box_a_scroll_container(CSS::Overflow overflow)
pub fn node_cpp_1154_overflow_value_makes_box_a_scroll_container() LayoutStub {
	return layout_stub('Node.cpp:1154 overflow_value_makes_box_a_scroll_container')
}

// Translated from Libraries/LibWeb/Layout/Node.cpp:1168
// Original signature: bool NodeWithStyle::is_scroll_container() const
// NOTE: This isn't in the spec, but we want the viewport to behave like a scroll container.
pub fn node_cpp_1168_node_with_style_is_scroll_container() LayoutStub {
	return layout_stub('Node.cpp:1168 NodeWithStyle::is_scroll_container')
}

// Translated from Libraries/LibWeb/Layout/Node.cpp:1178
// Original signature: void Node::add_paintable(GC::Ptr<Painting::Paintable> paintable)
pub fn node_cpp_1178_node_add_paintable() LayoutStub {
	return layout_stub('Node.cpp:1178 Node::add_paintable')
}

// Translated from Libraries/LibWeb/Layout/Node.cpp:1185
// Original signature: void Node::clear_paintables()
pub fn node_cpp_1185_node_clear_paintables() LayoutStub {
	return layout_stub('Node.cpp:1185 Node::clear_paintables')
}

// Translated from Libraries/LibWeb/Layout/Node.cpp:1190
// Original signature: GC::Ptr<Painting::Paintable> Node::create_paintable() const
pub fn node_cpp_1190_node_create_paintable() LayoutStub {
	return layout_stub('Node.cpp:1190 Node::create_paintable')
}

// Translated from Libraries/LibWeb/Layout/Node.cpp:1195
// Original signature: bool Node::is_anonymous() const
pub fn node_cpp_1195_node_is_anonymous() LayoutStub {
	return layout_stub('Node.cpp:1195 Node::is_anonymous')
}

// Translated from Libraries/LibWeb/Layout/Node.cpp:1200
// Original signature: DOM::Node const* Node::dom_node() const
pub fn node_cpp_1200_node_dom_node() LayoutStub {
	return layout_stub('Node.cpp:1200 Node::dom_node')
}

// Translated from Libraries/LibWeb/Layout/Node.cpp:1207
// Original signature: DOM::Node* Node::dom_node()
pub fn node_cpp_1207_node_dom_node() LayoutStub {
	return layout_stub('Node.cpp:1207 Node::dom_node')
}

// Translated from Libraries/LibWeb/Layout/Node.cpp:1214
// Original signature: DOM::Element const* Node::pseudo_element_generator() const
pub fn node_cpp_1214_node_pseudo_element_generator() LayoutStub {
	return layout_stub('Node.cpp:1214 Node::pseudo_element_generator')
}

// Translated from Libraries/LibWeb/Layout/Node.cpp:1220
// Original signature: DOM::Element* Node::pseudo_element_generator()
pub fn node_cpp_1220_node_pseudo_element_generator() LayoutStub {
	return layout_stub('Node.cpp:1220 Node::pseudo_element_generator')
}

// Translated from Libraries/LibWeb/Layout/Node.cpp:1226
// Original signature: DOM::Document& Node::document()
pub fn node_cpp_1226_node_document() LayoutStub {
	return layout_stub('Node.cpp:1226 Node::document')
}

// Translated from Libraries/LibWeb/Layout/Node.cpp:1231
// Original signature: DOM::Document const& Node::document() const
pub fn node_cpp_1231_node_document() LayoutStub {
	return layout_stub('Node.cpp:1231 Node::document')
}

// Translated from Libraries/LibWeb/Layout/Node.cpp:1237
// Original signature: CSS::UserSelect Node::user_select_used_value() const
// https://drafts.csswg.org/css-ui/#propdef-user-select
// The used value is the same as the computed value, except:
// 1. on editable elements where the used value is always 'contain' regardless of the computed value
// 2. when the computed value is 'auto', in which case the used value is one of the other values as defined below
// For the purpose of this specification, an editable element is either an editing host or a mutable form control
// with
// textual content, such as textarea.
// FIXME: Check if this needs to exclude input elements with types such as color or range, and if so, which ones
// exactly.
// The used value of 'auto' is determined as follows:
// - On the '::before' and '::after' pseudo-elements, the used value is 'none'
// - If the element is an editable element, the used value is 'contain'
// NOTE: We already handled this above.
// - Otherwise, if the used value of user-select on the parent of this element is 'all', the used value is 'all'
// - Otherwise, if the used value of user-select on the parent of this element is 'none', the used value is
// 'none'
// - Otherwise, the used value is 'text'
pub fn node_cpp_1237_node_user_select_used_value() LayoutStub {
	return layout_stub('Node.cpp:1237 Node::user_select_used_value')
}

// Translated from Libraries/LibWeb/Layout/Node.cpp:1286
// Original signature: bool Node::has_size_containment() const
// https://drafts.csswg.org/css-contain-2/#containment-size
// However, giving an element size containment has no effect if any of the following are true:
// - if the element does not generate a principal box (as is the case with 'display: contents' or 'display:
// none')
// Note: This is the principal box
// - if its inner display type is 'table'
// - if its principal box is an internal table box
// - if its principal box is an internal ruby box or a non-atomic inline-level box
// FIXME: Implement this.
pub fn node_cpp_1286_node_has_size_containment() LayoutStub {
	return layout_stub('Node.cpp:1286 Node::has_size_containment')
}

// Translated from Libraries/LibWeb/Layout/Node.cpp:1313
// Original signature: bool Node::has_inline_size_containment() const
// https://drafts.csswg.org/css-contain-2/#containment-inline-size
// Giving an element inline-size containment has no effect if any of the following are true:
// - if the element does not generate a principal box (as is the case with 'display: contents' or 'display:
// none')
// Note: This is the principal box
// - if its inner display type is 'table'
// - if its principal box is an internal table box
// - if its principal box is an internal ruby box or a non-atomic inline-level box
// FIXME: Implement this.
pub fn node_cpp_1313_node_has_inline_size_containment() LayoutStub {
	return layout_stub('Node.cpp:1313 Node::has_inline_size_containment')
}

// Translated from Libraries/LibWeb/Layout/Node.cpp:1340
// Original signature: bool Node::has_layout_containment() const
// https://drafts.csswg.org/css-contain-2/#containment-layout
// However, giving an element layout containment has no effect if any of the following are true:
// - if the element does not generate a principal box (as is the case with 'display: contents' or 'display:
// none')
// Note: This is the principal box
// - if its principal box is an internal table box other than 'table-cell'
// - if its principal box is an internal ruby box or a non-atomic inline-level box
// FIXME: Implement this.
// https://drafts.csswg.org/css-contain-2/#valdef-content-visibility-auto
// Changes the used value of the 'contain' property so as to turn on layout containment, style containment, and
// paint containment for the element.
pub fn node_cpp_1340_node_has_layout_containment() LayoutStub {
	return layout_stub('Node.cpp:1340 Node::has_layout_containment')
}

// Translated from Libraries/LibWeb/Layout/Node.cpp:1366
// Original signature: bool Node::has_style_containment() const
// https://drafts.csswg.org/css-contain-2/#containment-style
// However, giving an element style containment has no effect if any of the following are true:
// - if the element does not generate a principal box (as is the case with 'display: contents' or 'display:
// none')
// Note: This is the principal box
// https://drafts.csswg.org/css-contain-2/#valdef-content-visibility-auto
// Changes the used value of the 'contain' property so as to turn on layout containment, style containment, and
// paint containment for the element.
pub fn node_cpp_1366_node_has_style_containment() LayoutStub {
	return layout_stub('Node.cpp:1366 Node::has_style_containment')
}

// Translated from Libraries/LibWeb/Layout/Node.cpp:1388
// Original signature: bool Node::has_paint_containment() const
// https://drafts.csswg.org/css-contain-2/#containment-paint
// However, giving an element paint containment has no effect if any of the following are true:
// - if the element does not generate a principal box (as is the case with 'display: contents' or 'display:
// none')
// Note: This is the principal box
// - if its principal box is an internal table box other than 'table-cell'
// - if its principal box is an internal ruby box or a non-atomic inline-level box
// FIXME: Implement this
// https://drafts.csswg.org/css-contain-2/#valdef-content-visibility-auto
// Changes the used value of the 'contain' property so as to turn on layout containment, style containment, and
// paint containment for the element.
pub fn node_cpp_1388_node_has_paint_containment() LayoutStub {
	return layout_stub('Node.cpp:1388 Node::has_paint_containment')
}

// Translated from Libraries/LibWeb/Layout/Node.cpp:1414
// Original signature: bool NodeWithStyleAndBoxModelMetrics::should_create_inline_continuation() const
// This node must have an inline parent.
// This node must not be inline itself or out of flow (which gets handled separately).
// This node must not have `display: contents`; inline continuation gets handled by its children.
// Internal table display types and table captions are handled by the table fixup algorithm.
// Parent element must not be <foreignObject>
// Non-root SVG elements and foreign object boxes should never be split.
// Nested SVG roots should never be split, but a top-level SVG root inside an HTML inline element should be.
// Replaced boxes with children (e.g. media elements with shadow DOM controls)
// have their own formatting context; don't split them.
pub fn node_cpp_1414_node_with_style_and_box_model_metrics_should_create_inline_continuation() LayoutStub {
	return layout_stub('Node.cpp:1414 NodeWithStyleAndBoxModelMetrics::should_create_inline_continuation')
}

// Translated from Libraries/LibWeb/Layout/Node.cpp:1455
// Original signature: void NodeWithStyleAndBoxModelMetrics::propagate_style_along_continuation(CSS::ComputedProperties const& computed_style) const
pub fn node_cpp_1455_node_with_style_and_box_model_metrics_propagate_style_along_continuation() LayoutStub {
	return layout_stub('Node.cpp:1455 NodeWithStyleAndBoxModelMetrics::propagate_style_along_continuation')
}

// Translated from Libraries/LibWeb/Layout/Node.cpp:1464
// Original signature: void NodeWithStyleAndBoxModelMetrics::visit_edges(Cell::Visitor& visitor)
pub fn node_cpp_1464_node_with_style_and_box_model_metrics_visit_edges() LayoutStub {
	return layout_stub('Node.cpp:1464 NodeWithStyleAndBoxModelMetrics::visit_edges')
}

// Translated from Libraries/LibWeb/Layout/Node.cpp:1470
// Original signature: void Node::set_needs_layout_update(DOM::SetNeedsLayoutReason reason)
// NOTE: We check some conditions here to avoid debug spam in documents that don't do layout.
// Mark any anonymous children generated by this node for layout update.
// NOTE: if this node generated an anonymous parent, all ancestors are indiscriminately marked below.
// Reset intrinsic size caches for ancestors up to abspos or SVG root boundary.
// Absolutely positioned elements don't contribute to ancestor intrinsic sizes,
// so changes inside an abspos box don't require resetting ancestor caches.
// SVG root elements have intrinsic sizes determined solely by their own attributes
// (width, height, viewBox), not by their children, so the same logic applies.
pub fn node_cpp_1470_node_set_needs_layout_update() LayoutStub {
	return layout_stub('Node.cpp:1470 Node::set_needs_layout_update')
}

// ---- SVGBox.h (7 translated function stubs) ----

// Translated from Libraries/LibWeb/Layout/SVGBox.h:17
// Original signature: SVGBox::GC_DECLARE_ALLOCATOR(SVGBox);
pub fn svg_box_h_17_svg_box_gc_declare_allocator() LayoutStub {
	return layout_stub('SVGBox.h:17 SVGBox::GC_DECLARE_ALLOCATOR')
}

// Translated from Libraries/LibWeb/Layout/SVGBox.h:20
// Original signature: SVGBox::SVGBox(DOM::Document&, SVG::SVGElement&, GC::Ref<CSS::ComputedProperties>);
pub fn svg_box_h_20_svg_box_svg_box() LayoutStub {
	return layout_stub('SVGBox.h:20 SVGBox::SVGBox')
}

// Translated from Libraries/LibWeb/Layout/SVGBox.h:21
// Original signature: SVGBox::virtual ~SVGBox() = default;
pub fn svg_box_h_21_destroy_svg_box() LayoutStub {
	return layout_stub('SVGBox.h:21 ~SVGBox')
}

// Translated from Libraries/LibWeb/Layout/SVGBox.h:23
// Original signature: SVGBox::SVG::SVGElement& dom_node()
pub fn svg_box_h_23_dom_node() LayoutStub {
	return layout_stub('SVGBox.h:23 dom_node')
}

// Translated from Libraries/LibWeb/Layout/SVGBox.h:24
// Original signature: SVGBox::SVG::SVGElement const& dom_node() const
pub fn svg_box_h_24_dom_node() LayoutStub {
	return layout_stub('SVGBox.h:24 dom_node')
}

// Translated from Libraries/LibWeb/Layout/SVGBox.h:27
// Original signature: SVGBox::virtual bool is_svg_box() const
pub fn svg_box_h_27_is_svg_box() LayoutStub {
	return layout_stub('SVGBox.h:27 is_svg_box')
}

// Translated from Libraries/LibWeb/Layout/SVGBox.h:31
// Original signature: inline bool Node::fast_is<SVGBox>() const
pub fn svg_box_h_31_function() LayoutStub {
	return layout_stub('SVGBox.h:31 function')
}

// ---- SVGBox.cpp (1 translated function stubs) ----

// Translated from Libraries/LibWeb/Layout/SVGBox.cpp:13
// Original signature: SVGBox::SVGBox(DOM::Document& document, SVG::SVGElement& element, GC::Ref<CSS::ComputedProperties> style) : Box(document, &element, move(style))
pub fn svg_box_cpp_13_svg_box_svg_box() LayoutStub {
	return layout_stub('SVGBox.cpp:13 SVGBox::SVGBox')
}

// ---- SVGGraphicsBox.h (8 translated function stubs) ----

// Translated from Libraries/LibWeb/Layout/SVGGraphicsBox.h:18
// Original signature: SVGGraphicsBox::GC_DECLARE_ALLOCATOR(SVGGraphicsBox);
pub fn svg_graphics_box_h_18_svg_graphics_box_gc_declare_allocator() LayoutStub {
	return layout_stub('SVGGraphicsBox.h:18 SVGGraphicsBox::GC_DECLARE_ALLOCATOR')
}

// Translated from Libraries/LibWeb/Layout/SVGGraphicsBox.h:21
// Original signature: SVGGraphicsBox::SVGGraphicsBox(DOM::Document&, SVG::SVGGraphicsElement&, GC::Ref<CSS::ComputedProperties>);
pub fn svg_graphics_box_h_21_svg_graphics_box_svg_graphics_box() LayoutStub {
	return layout_stub('SVGGraphicsBox.h:21 SVGGraphicsBox::SVGGraphicsBox')
}

// Translated from Libraries/LibWeb/Layout/SVGGraphicsBox.h:22
// Original signature: SVGGraphicsBox::virtual ~SVGGraphicsBox() = default;
pub fn svg_graphics_box_h_22_destroy_svg_graphics_box() LayoutStub {
	return layout_stub('SVGGraphicsBox.h:22 ~SVGGraphicsBox')
}

// Translated from Libraries/LibWeb/Layout/SVGGraphicsBox.h:24
// Original signature: SVGGraphicsBox::SVG::SVGGraphicsElement& dom_node()
pub fn svg_graphics_box_h_24_dom_node() LayoutStub {
	return layout_stub('SVGGraphicsBox.h:24 dom_node')
}

// Translated from Libraries/LibWeb/Layout/SVGGraphicsBox.h:25
// Original signature: SVGGraphicsBox::SVG::SVGGraphicsElement const& dom_node() const
pub fn svg_graphics_box_h_25_dom_node() LayoutStub {
	return layout_stub('SVGGraphicsBox.h:25 dom_node')
}

// Translated from Libraries/LibWeb/Layout/SVGGraphicsBox.h:27
// Original signature: SVGGraphicsBox::virtual GC::Ptr<Painting::Paintable> create_paintable() const;
pub fn svg_graphics_box_h_27_create_paintable() LayoutStub {
	return layout_stub('SVGGraphicsBox.h:27 create_paintable')
}

// Translated from Libraries/LibWeb/Layout/SVGGraphicsBox.h:30
// Original signature: SVGGraphicsBox::virtual bool is_svg_graphics_box() const
pub fn svg_graphics_box_h_30_is_svg_graphics_box() LayoutStub {
	return layout_stub('SVGGraphicsBox.h:30 is_svg_graphics_box')
}

// Translated from Libraries/LibWeb/Layout/SVGGraphicsBox.h:34
// Original signature: inline bool Node::fast_is<SVGGraphicsBox>() const
pub fn svg_graphics_box_h_34_function() LayoutStub {
	return layout_stub('SVGGraphicsBox.h:34 function')
}

// ---- SVGGraphicsBox.cpp (2 translated function stubs) ----

// Translated from Libraries/LibWeb/Layout/SVGGraphicsBox.cpp:15
// Original signature: SVGGraphicsBox::SVGGraphicsBox(DOM::Document& document, SVG::SVGGraphicsElement& element, GC::Ref<CSS::ComputedProperties> style) : SVGBox(document, element, style)
pub fn svg_graphics_box_cpp_15_svg_graphics_box_svg_graphics_box() LayoutStub {
	return layout_stub('SVGGraphicsBox.cpp:15 SVGGraphicsBox::SVGGraphicsBox')
}

// Translated from Libraries/LibWeb/Layout/SVGGraphicsBox.cpp:20
// Original signature: GC::Ptr<Painting::Paintable> SVGGraphicsBox::create_paintable() const
pub fn svg_graphics_box_cpp_20_svg_graphics_box_create_paintable() LayoutStub {
	return layout_stub('SVGGraphicsBox.cpp:20 SVGGraphicsBox::create_paintable')
}

// ---- SVGGeometryBox.h (8 translated function stubs) ----

// Translated from Libraries/LibWeb/Layout/SVGGeometryBox.h:17
// Original signature: SVGGeometryBox::GC_DECLARE_ALLOCATOR(SVGGeometryBox);
pub fn svg_geometry_box_h_17_svg_geometry_box_gc_declare_allocator() LayoutStub {
	return layout_stub('SVGGeometryBox.h:17 SVGGeometryBox::GC_DECLARE_ALLOCATOR')
}

// Translated from Libraries/LibWeb/Layout/SVGGeometryBox.h:20
// Original signature: SVGGeometryBox::SVGGeometryBox(DOM::Document&, SVG::SVGGeometryElement&, GC::Ref<CSS::ComputedProperties>);
pub fn svg_geometry_box_h_20_svg_geometry_box_svg_geometry_box() LayoutStub {
	return layout_stub('SVGGeometryBox.h:20 SVGGeometryBox::SVGGeometryBox')
}

// Translated from Libraries/LibWeb/Layout/SVGGeometryBox.h:21
// Original signature: SVGGeometryBox::virtual ~SVGGeometryBox() = default;
pub fn svg_geometry_box_h_21_destroy_svg_geometry_box() LayoutStub {
	return layout_stub('SVGGeometryBox.h:21 ~SVGGeometryBox')
}

// Translated from Libraries/LibWeb/Layout/SVGGeometryBox.h:23
// Original signature: SVGGeometryBox::SVG::SVGGeometryElement& dom_node()
pub fn svg_geometry_box_h_23_dom_node() LayoutStub {
	return layout_stub('SVGGeometryBox.h:23 dom_node')
}

// Translated from Libraries/LibWeb/Layout/SVGGeometryBox.h:24
// Original signature: SVGGeometryBox::SVG::SVGGeometryElement const& dom_node() const
pub fn svg_geometry_box_h_24_dom_node() LayoutStub {
	return layout_stub('SVGGeometryBox.h:24 dom_node')
}

// Translated from Libraries/LibWeb/Layout/SVGGeometryBox.h:26
// Original signature: SVGGeometryBox::virtual GC::Ptr<Painting::Paintable> create_paintable() const;
pub fn svg_geometry_box_h_26_create_paintable() LayoutStub {
	return layout_stub('SVGGeometryBox.h:26 create_paintable')
}

// Translated from Libraries/LibWeb/Layout/SVGGeometryBox.h:29
// Original signature: SVGGeometryBox::virtual bool is_svg_geometry_box() const
pub fn svg_geometry_box_h_29_is_svg_geometry_box() LayoutStub {
	return layout_stub('SVGGeometryBox.h:29 is_svg_geometry_box')
}

// Translated from Libraries/LibWeb/Layout/SVGGeometryBox.h:33
// Original signature: inline bool Node::fast_is<SVGGeometryBox>() const
pub fn svg_geometry_box_h_33_function() LayoutStub {
	return layout_stub('SVGGeometryBox.h:33 function')
}

// ---- SVGGeometryBox.cpp (2 translated function stubs) ----

// Translated from Libraries/LibWeb/Layout/SVGGeometryBox.cpp:17
// Original signature: SVGGeometryBox::SVGGeometryBox(DOM::Document& document, SVG::SVGGeometryElement& element, GC::Ref<CSS::ComputedProperties> style) : SVGGraphicsBox(document, element, style)
pub fn svg_geometry_box_cpp_17_svg_geometry_box_svg_geometry_box() LayoutStub {
	return layout_stub('SVGGeometryBox.cpp:17 SVGGeometryBox::SVGGeometryBox')
}

// Translated from Libraries/LibWeb/Layout/SVGGeometryBox.cpp:22
// Original signature: GC::Ptr<Painting::Paintable> SVGGeometryBox::create_paintable() const
pub fn svg_geometry_box_cpp_22_svg_geometry_box_create_paintable() LayoutStub {
	return layout_stub('SVGGeometryBox.cpp:22 SVGGeometryBox::create_paintable')
}

// ---- SVGClipBox.h (8 translated function stubs) ----

// Translated from Libraries/LibWeb/Layout/SVGClipBox.h:17
// Original signature: SVGClipBox::GC_DECLARE_ALLOCATOR(SVGClipBox);
pub fn svg_clip_box_h_17_svg_clip_box_gc_declare_allocator() LayoutStub {
	return layout_stub('SVGClipBox.h:17 SVGClipBox::GC_DECLARE_ALLOCATOR')
}

// Translated from Libraries/LibWeb/Layout/SVGClipBox.h:20
// Original signature: SVGClipBox::SVGClipBox(DOM::Document&, SVG::SVGClipPathElement&, GC::Ref<CSS::ComputedProperties>);
pub fn svg_clip_box_h_20_svg_clip_box_svg_clip_box() LayoutStub {
	return layout_stub('SVGClipBox.h:20 SVGClipBox::SVGClipBox')
}

// Translated from Libraries/LibWeb/Layout/SVGClipBox.h:21
// Original signature: SVGClipBox::virtual ~SVGClipBox() = default;
pub fn svg_clip_box_h_21_destroy_svg_clip_box() LayoutStub {
	return layout_stub('SVGClipBox.h:21 ~SVGClipBox')
}

// Translated from Libraries/LibWeb/Layout/SVGClipBox.h:23
// Original signature: SVGClipBox::SVG::SVGClipPathElement& dom_node()
pub fn svg_clip_box_h_23_dom_node() LayoutStub {
	return layout_stub('SVGClipBox.h:23 dom_node')
}

// Translated from Libraries/LibWeb/Layout/SVGClipBox.h:24
// Original signature: SVGClipBox::SVG::SVGClipPathElement const& dom_node() const
pub fn svg_clip_box_h_24_dom_node() LayoutStub {
	return layout_stub('SVGClipBox.h:24 dom_node')
}

// Translated from Libraries/LibWeb/Layout/SVGClipBox.h:26
// Original signature: SVGClipBox::virtual GC::Ptr<Painting::Paintable> create_paintable() const;
pub fn svg_clip_box_h_26_create_paintable() LayoutStub {
	return layout_stub('SVGClipBox.h:26 create_paintable')
}

// Translated from Libraries/LibWeb/Layout/SVGClipBox.h:29
// Original signature: SVGClipBox::virtual bool is_svg_clip_box() const
pub fn svg_clip_box_h_29_is_svg_clip_box() LayoutStub {
	return layout_stub('SVGClipBox.h:29 is_svg_clip_box')
}

// Translated from Libraries/LibWeb/Layout/SVGClipBox.h:33
// Original signature: inline bool Node::fast_is<SVGClipBox>() const
pub fn svg_clip_box_h_33_function() LayoutStub {
	return layout_stub('SVGClipBox.h:33 function')
}

// ---- SVGClipBox.cpp (2 translated function stubs) ----

// Translated from Libraries/LibWeb/Layout/SVGClipBox.cpp:15
// Original signature: SVGClipBox::SVGClipBox(DOM::Document& document, SVG::SVGClipPathElement& element, GC::Ref<CSS::ComputedProperties> style) : SVGBox(document, element, style)
pub fn svg_clip_box_cpp_15_svg_clip_box_svg_clip_box() LayoutStub {
	return layout_stub('SVGClipBox.cpp:15 SVGClipBox::SVGClipBox')
}

// Translated from Libraries/LibWeb/Layout/SVGClipBox.cpp:20
// Original signature: GC::Ptr<Painting::Paintable> SVGClipBox::create_paintable() const
pub fn svg_clip_box_cpp_20_svg_clip_box_create_paintable() LayoutStub {
	return layout_stub('SVGClipBox.cpp:20 SVGClipBox::create_paintable')
}

// ---- SVGForeignObjectBox.h (8 translated function stubs) ----

// Translated from Libraries/LibWeb/Layout/SVGForeignObjectBox.h:18
// Original signature: SVGForeignObjectBox::GC_DECLARE_ALLOCATOR(SVGForeignObjectBox);
pub fn svg_foreign_object_box_h_18_svg_foreign_object_box_gc_declare_allocator() LayoutStub {
	return layout_stub('SVGForeignObjectBox.h:18 SVGForeignObjectBox::GC_DECLARE_ALLOCATOR')
}

// Translated from Libraries/LibWeb/Layout/SVGForeignObjectBox.h:21
// Original signature: SVGForeignObjectBox::SVGForeignObjectBox(DOM::Document&, SVG::SVGForeignObjectElement&, GC::Ref<CSS::ComputedProperties>);
pub fn svg_foreign_object_box_h_21_svg_foreign_object_box_svg_foreign_object_box() LayoutStub {
	return layout_stub('SVGForeignObjectBox.h:21 SVGForeignObjectBox::SVGForeignObjectBox')
}

// Translated from Libraries/LibWeb/Layout/SVGForeignObjectBox.h:22
// Original signature: SVGForeignObjectBox::virtual ~SVGForeignObjectBox() = default;
pub fn svg_foreign_object_box_h_22_destroy_svg_foreign_object_box() LayoutStub {
	return layout_stub('SVGForeignObjectBox.h:22 ~SVGForeignObjectBox')
}

// Translated from Libraries/LibWeb/Layout/SVGForeignObjectBox.h:24
// Original signature: SVGForeignObjectBox::SVG::SVGForeignObjectElement& dom_node()
pub fn svg_foreign_object_box_h_24_dom_node() LayoutStub {
	return layout_stub('SVGForeignObjectBox.h:24 dom_node')
}

// Translated from Libraries/LibWeb/Layout/SVGForeignObjectBox.h:25
// Original signature: SVGForeignObjectBox::SVG::SVGForeignObjectElement const& dom_node() const
pub fn svg_foreign_object_box_h_25_dom_node() LayoutStub {
	return layout_stub('SVGForeignObjectBox.h:25 dom_node')
}

// Translated from Libraries/LibWeb/Layout/SVGForeignObjectBox.h:27
// Original signature: SVGForeignObjectBox::virtual GC::Ptr<Painting::Paintable> create_paintable() const;
pub fn svg_foreign_object_box_h_27_create_paintable() LayoutStub {
	return layout_stub('SVGForeignObjectBox.h:27 create_paintable')
}

// Translated from Libraries/LibWeb/Layout/SVGForeignObjectBox.h:30
// Original signature: SVGForeignObjectBox::virtual bool is_svg_foreign_object_box() const
pub fn svg_foreign_object_box_h_30_is_svg_foreign_object_box() LayoutStub {
	return layout_stub('SVGForeignObjectBox.h:30 is_svg_foreign_object_box')
}

// Translated from Libraries/LibWeb/Layout/SVGForeignObjectBox.h:34
// Original signature: inline bool Node::fast_is<SVGForeignObjectBox>() const
pub fn svg_foreign_object_box_h_34_function() LayoutStub {
	return layout_stub('SVGForeignObjectBox.h:34 function')
}

// ---- SVGForeignObjectBox.cpp (2 translated function stubs) ----

// Translated from Libraries/LibWeb/Layout/SVGForeignObjectBox.cpp:15
// Original signature: SVGForeignObjectBox::SVGForeignObjectBox(DOM::Document& document, SVG::SVGForeignObjectElement& element, GC::Ref<CSS::ComputedProperties> style) : BlockContainer(document, &element, style)
pub fn svg_foreign_object_box_cpp_15_svg_foreign_object_box_svg_foreign_object_box() LayoutStub {
	return layout_stub('SVGForeignObjectBox.cpp:15 SVGForeignObjectBox::SVGForeignObjectBox')
}

// Translated from Libraries/LibWeb/Layout/SVGForeignObjectBox.cpp:20
// Original signature: GC::Ptr<Painting::Paintable> SVGForeignObjectBox::create_paintable() const
pub fn svg_foreign_object_box_cpp_20_svg_foreign_object_box_create_paintable() LayoutStub {
	return layout_stub('SVGForeignObjectBox.cpp:20 SVGForeignObjectBox::create_paintable')
}

// ---- SVGImageBox.h (6 translated function stubs) ----

// Translated from Libraries/LibWeb/Layout/SVGImageBox.h:17
// Original signature: SVGImageBox::GC_DECLARE_ALLOCATOR(SVGImageBox);
pub fn svg_image_box_h_17_svg_image_box_gc_declare_allocator() LayoutStub {
	return layout_stub('SVGImageBox.h:17 SVGImageBox::GC_DECLARE_ALLOCATOR')
}

// Translated from Libraries/LibWeb/Layout/SVGImageBox.h:20
// Original signature: SVGImageBox::SVGImageBox(DOM::Document&, SVG::SVGGraphicsElement&, GC::Ref<CSS::ComputedProperties>);
pub fn svg_image_box_h_20_svg_image_box_svg_image_box() LayoutStub {
	return layout_stub('SVGImageBox.h:20 SVGImageBox::SVGImageBox')
}

// Translated from Libraries/LibWeb/Layout/SVGImageBox.h:21
// Original signature: SVGImageBox::virtual ~SVGImageBox() = default;
pub fn svg_image_box_h_21_destroy_svg_image_box() LayoutStub {
	return layout_stub('SVGImageBox.h:21 ~SVGImageBox')
}

// Translated from Libraries/LibWeb/Layout/SVGImageBox.h:23
// Original signature: SVGImageBox::SVG::SVGImageElement& dom_node()
pub fn svg_image_box_h_23_dom_node() LayoutStub {
	return layout_stub('SVGImageBox.h:23 dom_node')
}

// Translated from Libraries/LibWeb/Layout/SVGImageBox.h:24
// Original signature: SVGImageBox::SVG::SVGImageElement const& dom_node() const
pub fn svg_image_box_h_24_dom_node() LayoutStub {
	return layout_stub('SVGImageBox.h:24 dom_node')
}

// Translated from Libraries/LibWeb/Layout/SVGImageBox.h:26
// Original signature: SVGImageBox::virtual GC::Ptr<Painting::Paintable> create_paintable() const;
pub fn svg_image_box_h_26_create_paintable() LayoutStub {
	return layout_stub('SVGImageBox.h:26 create_paintable')
}

// ---- SVGImageBox.cpp (2 translated function stubs) ----

// Translated from Libraries/LibWeb/Layout/SVGImageBox.cpp:16
// Original signature: SVGImageBox::SVGImageBox(DOM::Document& document, SVG::SVGGraphicsElement& element, GC::Ref<CSS::ComputedProperties> style) : SVGGraphicsBox(document, element, style)
pub fn svg_image_box_cpp_16_svg_image_box_svg_image_box() LayoutStub {
	return layout_stub('SVGImageBox.cpp:16 SVGImageBox::SVGImageBox')
}

// Translated from Libraries/LibWeb/Layout/SVGImageBox.cpp:21
// Original signature: GC::Ptr<Painting::Paintable> SVGImageBox::create_paintable() const
pub fn svg_image_box_cpp_21_svg_image_box_create_paintable() LayoutStub {
	return layout_stub('SVGImageBox.cpp:21 SVGImageBox::create_paintable')
}

// ---- SVGMaskBox.h (8 translated function stubs) ----

// Translated from Libraries/LibWeb/Layout/SVGMaskBox.h:17
// Original signature: SVGMaskBox::GC_DECLARE_ALLOCATOR(SVGMaskBox);
pub fn svg_mask_box_h_17_svg_mask_box_gc_declare_allocator() LayoutStub {
	return layout_stub('SVGMaskBox.h:17 SVGMaskBox::GC_DECLARE_ALLOCATOR')
}

// Translated from Libraries/LibWeb/Layout/SVGMaskBox.h:20
// Original signature: SVGMaskBox::SVGMaskBox(DOM::Document&, SVG::SVGMaskElement&, GC::Ref<CSS::ComputedProperties>);
pub fn svg_mask_box_h_20_svg_mask_box_svg_mask_box() LayoutStub {
	return layout_stub('SVGMaskBox.h:20 SVGMaskBox::SVGMaskBox')
}

// Translated from Libraries/LibWeb/Layout/SVGMaskBox.h:21
// Original signature: SVGMaskBox::virtual ~SVGMaskBox() = default;
pub fn svg_mask_box_h_21_destroy_svg_mask_box() LayoutStub {
	return layout_stub('SVGMaskBox.h:21 ~SVGMaskBox')
}

// Translated from Libraries/LibWeb/Layout/SVGMaskBox.h:23
// Original signature: SVGMaskBox::virtual bool is_svg_mask_box() const
pub fn svg_mask_box_h_23_is_svg_mask_box() LayoutStub {
	return layout_stub('SVGMaskBox.h:23 is_svg_mask_box')
}

// Translated from Libraries/LibWeb/Layout/SVGMaskBox.h:25
// Original signature: SVGMaskBox::SVG::SVGMaskElement& dom_node()
pub fn svg_mask_box_h_25_dom_node() LayoutStub {
	return layout_stub('SVGMaskBox.h:25 dom_node')
}

// Translated from Libraries/LibWeb/Layout/SVGMaskBox.h:26
// Original signature: SVGMaskBox::SVG::SVGMaskElement const& dom_node() const
pub fn svg_mask_box_h_26_dom_node() LayoutStub {
	return layout_stub('SVGMaskBox.h:26 dom_node')
}

// Translated from Libraries/LibWeb/Layout/SVGMaskBox.h:28
// Original signature: SVGMaskBox::virtual GC::Ptr<Painting::Paintable> create_paintable() const;
pub fn svg_mask_box_h_28_create_paintable() LayoutStub {
	return layout_stub('SVGMaskBox.h:28 create_paintable')
}

// Translated from Libraries/LibWeb/Layout/SVGMaskBox.h:32
// Original signature: inline bool Node::fast_is<SVGMaskBox>() const
pub fn svg_mask_box_h_32_function() LayoutStub {
	return layout_stub('SVGMaskBox.h:32 function')
}

// ---- SVGMaskBox.cpp (2 translated function stubs) ----

// Translated from Libraries/LibWeb/Layout/SVGMaskBox.cpp:15
// Original signature: SVGMaskBox::SVGMaskBox(DOM::Document& document, SVG::SVGMaskElement& element, GC::Ref<CSS::ComputedProperties> style) : SVGGraphicsBox(document, element, style)
pub fn svg_mask_box_cpp_15_svg_mask_box_svg_mask_box() LayoutStub {
	return layout_stub('SVGMaskBox.cpp:15 SVGMaskBox::SVGMaskBox')
}

// Translated from Libraries/LibWeb/Layout/SVGMaskBox.cpp:20
// Original signature: GC::Ptr<Painting::Paintable> SVGMaskBox::create_paintable() const
pub fn svg_mask_box_cpp_20_svg_mask_box_create_paintable() LayoutStub {
	return layout_stub('SVGMaskBox.cpp:20 SVGMaskBox::create_paintable')
}

// ---- SVGPatternBox.h (8 translated function stubs) ----

// Translated from Libraries/LibWeb/Layout/SVGPatternBox.h:16
// Original signature: SVGPatternBox::GC_DECLARE_ALLOCATOR(SVGPatternBox);
pub fn svg_pattern_box_h_16_svg_pattern_box_gc_declare_allocator() LayoutStub {
	return layout_stub('SVGPatternBox.h:16 SVGPatternBox::GC_DECLARE_ALLOCATOR')
}

// Translated from Libraries/LibWeb/Layout/SVGPatternBox.h:19
// Original signature: SVGPatternBox::SVGPatternBox(DOM::Document&, SVG::SVGPatternElement&, GC::Ref<CSS::ComputedProperties>);
pub fn svg_pattern_box_h_19_svg_pattern_box_svg_pattern_box() LayoutStub {
	return layout_stub('SVGPatternBox.h:19 SVGPatternBox::SVGPatternBox')
}

// Translated from Libraries/LibWeb/Layout/SVGPatternBox.h:20
// Original signature: SVGPatternBox::virtual ~SVGPatternBox() = default;
pub fn svg_pattern_box_h_20_destroy_svg_pattern_box() LayoutStub {
	return layout_stub('SVGPatternBox.h:20 ~SVGPatternBox')
}

// Translated from Libraries/LibWeb/Layout/SVGPatternBox.h:22
// Original signature: SVGPatternBox::SVG::SVGPatternElement& dom_node()
pub fn svg_pattern_box_h_22_dom_node() LayoutStub {
	return layout_stub('SVGPatternBox.h:22 dom_node')
}

// Translated from Libraries/LibWeb/Layout/SVGPatternBox.h:23
// Original signature: SVGPatternBox::SVG::SVGPatternElement const& dom_node() const
pub fn svg_pattern_box_h_23_dom_node() LayoutStub {
	return layout_stub('SVGPatternBox.h:23 dom_node')
}

// Translated from Libraries/LibWeb/Layout/SVGPatternBox.h:25
// Original signature: SVGPatternBox::virtual GC::Ptr<Painting::Paintable> create_paintable() const;
pub fn svg_pattern_box_h_25_create_paintable() LayoutStub {
	return layout_stub('SVGPatternBox.h:25 create_paintable')
}

// Translated from Libraries/LibWeb/Layout/SVGPatternBox.h:28
// Original signature: SVGPatternBox::virtual bool is_svg_pattern_box() const
pub fn svg_pattern_box_h_28_is_svg_pattern_box() LayoutStub {
	return layout_stub('SVGPatternBox.h:28 is_svg_pattern_box')
}

// Translated from Libraries/LibWeb/Layout/SVGPatternBox.h:32
// Original signature: inline bool Node::fast_is<SVGPatternBox>() const
pub fn svg_pattern_box_h_32_function() LayoutStub {
	return layout_stub('SVGPatternBox.h:32 function')
}

// ---- SVGPatternBox.cpp (2 translated function stubs) ----

// Translated from Libraries/LibWeb/Layout/SVGPatternBox.cpp:14
// Original signature: SVGPatternBox::SVGPatternBox(DOM::Document& document, SVG::SVGPatternElement& element, GC::Ref<CSS::ComputedProperties> style) : SVGBox(document, element, style)
pub fn svg_pattern_box_cpp_14_svg_pattern_box_svg_pattern_box() LayoutStub {
	return layout_stub('SVGPatternBox.cpp:14 SVGPatternBox::SVGPatternBox')
}

// Translated from Libraries/LibWeb/Layout/SVGPatternBox.cpp:19
// Original signature: GC::Ptr<Painting::Paintable> SVGPatternBox::create_paintable() const
pub fn svg_pattern_box_cpp_19_svg_pattern_box_create_paintable() LayoutStub {
	return layout_stub('SVGPatternBox.cpp:19 SVGPatternBox::create_paintable')
}

// ---- SVGSVGBox.h (10 translated function stubs) ----

// Translated from Libraries/LibWeb/Layout/SVGSVGBox.h:16
// Original signature: SVGSVGBox::GC_DECLARE_ALLOCATOR(SVGSVGBox);
pub fn svgsvg_box_h_16_svgsvg_box_gc_declare_allocator() LayoutStub {
	return layout_stub('SVGSVGBox.h:16 SVGSVGBox::GC_DECLARE_ALLOCATOR')
}

// Translated from Libraries/LibWeb/Layout/SVGSVGBox.h:19
// Original signature: SVGSVGBox::SVGSVGBox(DOM::Document&, SVG::SVGSVGElement&, GC::Ref<CSS::ComputedProperties>);
pub fn svgsvg_box_h_19_svgsvg_box_svgsvg_box() LayoutStub {
	return layout_stub('SVGSVGBox.h:19 SVGSVGBox::SVGSVGBox')
}

// Translated from Libraries/LibWeb/Layout/SVGSVGBox.h:20
// Original signature: SVGSVGBox::virtual ~SVGSVGBox() = default;
pub fn svgsvg_box_h_20_destroy_svgsvg_box() LayoutStub {
	return layout_stub('SVGSVGBox.h:20 ~SVGSVGBox')
}

// Translated from Libraries/LibWeb/Layout/SVGSVGBox.h:22
// Original signature: SVGSVGBox::SVG::SVGSVGElement& dom_node()
pub fn svgsvg_box_h_22_dom_node() LayoutStub {
	return layout_stub('SVGSVGBox.h:22 dom_node')
}

// Translated from Libraries/LibWeb/Layout/SVGSVGBox.h:23
// Original signature: SVGSVGBox::SVG::SVGSVGElement const& dom_node() const
pub fn svgsvg_box_h_23_dom_node() LayoutStub {
	return layout_stub('SVGSVGBox.h:23 dom_node')
}

// Translated from Libraries/LibWeb/Layout/SVGSVGBox.h:25
// Original signature: SVGSVGBox::virtual bool can_have_children() const
pub fn svgsvg_box_h_25_can_have_children() LayoutStub {
	return layout_stub('SVGSVGBox.h:25 can_have_children')
}

// Translated from Libraries/LibWeb/Layout/SVGSVGBox.h:27
// Original signature: SVGSVGBox::virtual GC::Ptr<Painting::Paintable> create_paintable() const;
pub fn svgsvg_box_h_27_create_paintable() LayoutStub {
	return layout_stub('SVGSVGBox.h:27 create_paintable')
}

// Translated from Libraries/LibWeb/Layout/SVGSVGBox.h:30
// Original signature: SVGSVGBox::virtual CSS::SizeWithAspectRatio natural_size() const;
pub fn svgsvg_box_h_30_natural_size() LayoutStub {
	return layout_stub('SVGSVGBox.h:30 natural_size')
}

// Translated from Libraries/LibWeb/Layout/SVGSVGBox.h:31
// Original signature: SVGSVGBox::virtual bool is_svg_svg_box() const
pub fn svgsvg_box_h_31_is_svg_svg_box() LayoutStub {
	return layout_stub('SVGSVGBox.h:31 is_svg_svg_box')
}

// Translated from Libraries/LibWeb/Layout/SVGSVGBox.h:35
// Original signature: inline bool Node::fast_is<SVGSVGBox>() const
pub fn svgsvg_box_h_35_function() LayoutStub {
	return layout_stub('SVGSVGBox.h:35 function')
}

// ---- SVGSVGBox.cpp (3 translated function stubs) ----

// Translated from Libraries/LibWeb/Layout/SVGSVGBox.cpp:18
// Original signature: SVGSVGBox::SVGSVGBox(DOM::Document& document, SVG::SVGSVGElement& element, GC::Ref<CSS::ComputedProperties> style) : ReplacedBox(document, element, style)
pub fn svgsvg_box_cpp_18_svgsvg_box_svgsvg_box() LayoutStub {
	return layout_stub('SVGSVGBox.cpp:18 SVGSVGBox::SVGSVGBox')
}

// Translated from Libraries/LibWeb/Layout/SVGSVGBox.cpp:23
// Original signature: GC::Ptr<Painting::Paintable> SVGSVGBox::create_paintable() const
pub fn svgsvg_box_cpp_23_svgsvg_box_create_paintable() LayoutStub {
	return layout_stub('SVGSVGBox.cpp:23 SVGSVGBox::create_paintable')
}

// Translated from Libraries/LibWeb/Layout/SVGSVGBox.cpp:28
// Original signature: CSS::SizeWithAspectRatio SVGSVGBox::natural_size() const
pub fn svgsvg_box_cpp_28_svgsvg_box_natural_size() LayoutStub {
	return layout_stub('SVGSVGBox.cpp:28 SVGSVGBox::natural_size')
}

// ---- SVGTextBox.h (7 translated function stubs) ----

// Translated from Libraries/LibWeb/Layout/SVGTextBox.h:17
// Original signature: SVGTextBox::GC_DECLARE_ALLOCATOR(SVGTextBox);
pub fn svg_text_box_h_17_svg_text_box_gc_declare_allocator() LayoutStub {
	return layout_stub('SVGTextBox.h:17 SVGTextBox::GC_DECLARE_ALLOCATOR')
}

// Translated from Libraries/LibWeb/Layout/SVGTextBox.h:20
// Original signature: SVGTextBox::SVGTextBox(DOM::Document&, SVG::SVGTextPositioningElement&, GC::Ref<CSS::ComputedProperties>);
pub fn svg_text_box_h_20_svg_text_box_svg_text_box() LayoutStub {
	return layout_stub('SVGTextBox.h:20 SVGTextBox::SVGTextBox')
}

// Translated from Libraries/LibWeb/Layout/SVGTextBox.h:21
// Original signature: SVGTextBox::virtual ~SVGTextBox() = default;
pub fn svg_text_box_h_21_destroy_svg_text_box() LayoutStub {
	return layout_stub('SVGTextBox.h:21 ~SVGTextBox')
}

// Translated from Libraries/LibWeb/Layout/SVGTextBox.h:23
// Original signature: SVGTextBox::SVG::SVGTextPositioningElement& dom_node()
pub fn svg_text_box_h_23_dom_node() LayoutStub {
	return layout_stub('SVGTextBox.h:23 dom_node')
}

// Translated from Libraries/LibWeb/Layout/SVGTextBox.h:24
// Original signature: SVGTextBox::SVG::SVGTextPositioningElement const& dom_node() const
pub fn svg_text_box_h_24_dom_node() LayoutStub {
	return layout_stub('SVGTextBox.h:24 dom_node')
}

// Translated from Libraries/LibWeb/Layout/SVGTextBox.h:26
// Original signature: SVGTextBox::virtual GC::Ptr<Painting::Paintable> create_paintable() const;
pub fn svg_text_box_h_26_create_paintable() LayoutStub {
	return layout_stub('SVGTextBox.h:26 create_paintable')
}

// Translated from Libraries/LibWeb/Layout/SVGTextBox.h:29
// Original signature: SVGTextBox::CSSPixelPoint viewbox_origin() const;
pub fn svg_text_box_h_29_viewbox_origin() LayoutStub {
	return layout_stub('SVGTextBox.h:29 viewbox_origin')
}

// ---- SVGTextBox.cpp (2 translated function stubs) ----

// Translated from Libraries/LibWeb/Layout/SVGTextBox.cpp:15
// Original signature: SVGTextBox::SVGTextBox(DOM::Document& document, SVG::SVGTextPositioningElement& element, GC::Ref<CSS::ComputedProperties> style) : SVGGraphicsBox(document, element, style)
pub fn svg_text_box_cpp_15_svg_text_box_svg_text_box() LayoutStub {
	return layout_stub('SVGTextBox.cpp:15 SVGTextBox::SVGTextBox')
}

// Translated from Libraries/LibWeb/Layout/SVGTextBox.cpp:20
// Original signature: GC::Ptr<Painting::Paintable> SVGTextBox::create_paintable() const
pub fn svg_text_box_cpp_20_svg_text_box_create_paintable() LayoutStub {
	return layout_stub('SVGTextBox.cpp:20 SVGTextBox::create_paintable')
}

// ---- SVGTextPathBox.h (7 translated function stubs) ----

// Translated from Libraries/LibWeb/Layout/SVGTextPathBox.h:16
// Original signature: SVGTextPathBox::GC_DECLARE_ALLOCATOR(SVGTextPathBox);
pub fn svg_text_path_box_h_16_svg_text_path_box_gc_declare_allocator() LayoutStub {
	return layout_stub('SVGTextPathBox.h:16 SVGTextPathBox::GC_DECLARE_ALLOCATOR')
}

// Translated from Libraries/LibWeb/Layout/SVGTextPathBox.h:19
// Original signature: SVGTextPathBox::SVGTextPathBox(DOM::Document&, SVG::SVGTextPathElement&, GC::Ref<CSS::ComputedProperties>);
pub fn svg_text_path_box_h_19_svg_text_path_box_svg_text_path_box() LayoutStub {
	return layout_stub('SVGTextPathBox.h:19 SVGTextPathBox::SVGTextPathBox')
}

// Translated from Libraries/LibWeb/Layout/SVGTextPathBox.h:20
// Original signature: SVGTextPathBox::virtual ~SVGTextPathBox() = default;
pub fn svg_text_path_box_h_20_destroy_svg_text_path_box() LayoutStub {
	return layout_stub('SVGTextPathBox.h:20 ~SVGTextPathBox')
}

// Translated from Libraries/LibWeb/Layout/SVGTextPathBox.h:22
// Original signature: SVGTextPathBox::SVG::SVGTextPathElement& dom_node()
pub fn svg_text_path_box_h_22_dom_node() LayoutStub {
	return layout_stub('SVGTextPathBox.h:22 dom_node')
}

// Translated from Libraries/LibWeb/Layout/SVGTextPathBox.h:23
// Original signature: SVGTextPathBox::SVG::SVGTextPathElement const& dom_node() const
pub fn svg_text_path_box_h_23_dom_node() LayoutStub {
	return layout_stub('SVGTextPathBox.h:23 dom_node')
}

// Translated from Libraries/LibWeb/Layout/SVGTextPathBox.h:25
// Original signature: SVGTextPathBox::virtual GC::Ptr<Painting::Paintable> create_paintable() const;
pub fn svg_text_path_box_h_25_create_paintable() LayoutStub {
	return layout_stub('SVGTextPathBox.h:25 create_paintable')
}

// Translated from Libraries/LibWeb/Layout/SVGTextPathBox.h:28
// Original signature: SVGTextPathBox::CSSPixelPoint viewbox_origin() const;
pub fn svg_text_path_box_h_28_viewbox_origin() LayoutStub {
	return layout_stub('SVGTextPathBox.h:28 viewbox_origin')
}

// ---- SVGTextPathBox.cpp (2 translated function stubs) ----

// Translated from Libraries/LibWeb/Layout/SVGTextPathBox.cpp:14
// Original signature: SVGTextPathBox::SVGTextPathBox(DOM::Document& document, SVG::SVGTextPathElement& element, GC::Ref<CSS::ComputedProperties> style) : SVGGraphicsBox(document, element, style)
pub fn svg_text_path_box_cpp_14_svg_text_path_box_svg_text_path_box() LayoutStub {
	return layout_stub('SVGTextPathBox.cpp:14 SVGTextPathBox::SVGTextPathBox')
}

// Translated from Libraries/LibWeb/Layout/SVGTextPathBox.cpp:19
// Original signature: GC::Ptr<Painting::Paintable> SVGTextPathBox::create_paintable() const
pub fn svg_text_path_box_cpp_19_svg_text_path_box_create_paintable() LayoutStub {
	return layout_stub('SVGTextPathBox.cpp:19 SVGTextPathBox::create_paintable')
}

// ---- TableGrid.h (4 translated function stubs) ----

// Translated from Libraries/LibWeb/Layout/TableGrid.h:51
// Original signature: TableGrid::static TableGrid calculate_row_column_grid(Box const&, Vector<Cell>&, Vector<Row>&);
// Calculate and return the grid and also rows and cells as output parameters.
pub fn table_grid_h_51_calculate_row_column_grid() LayoutStub {
	return layout_stub('TableGrid.h:51 calculate_row_column_grid')
}

// Translated from Libraries/LibWeb/Layout/TableGrid.h:53
// Original signature: TableGrid::static TableGrid calculate_row_column_grid(Box const& box);
// Overload for callers that don't care about rows and cells (currently the layout tree builder).
pub fn table_grid_h_53_calculate_row_column_grid() LayoutStub {
	return layout_stub('TableGrid.h:53 calculate_row_column_grid')
}

// Translated from Libraries/LibWeb/Layout/TableGrid.h:55
// Original signature: TableGrid::size_t column_count() const
pub fn table_grid_h_55_column_count() LayoutStub {
	return layout_stub('TableGrid.h:55 column_count')
}

// Translated from Libraries/LibWeb/Layout/TableGrid.h:56
// Original signature: TableGrid::HashMap<GridPosition, bool> const& occupancy_grid() const
pub fn table_grid_h_56_occupancy_grid() LayoutStub {
	return layout_stub('TableGrid.h:56 occupancy_grid')
}

// ---- TableGrid.cpp (2 translated function stubs) ----

// Translated from Libraries/LibWeb/Layout/TableGrid.cpp:13
// Original signature: TableGrid TableGrid::calculate_row_column_grid(Box const& box, Vector<Cell>& cells, Vector<Row>& rows)
// Implements https://html.spec.whatwg.org/multipage/tables.html#forming-a-table
// Implements https://html.spec.whatwg.org/multipage/tables.html#algorithm-for-processing-rows
// 1. If yheight is equal to ycurrent, then increase yheight by 1. (ycurrent is never greater than yheight.)
// 2. Let xcurrent be 0.
// FIXME: 3. Run the algorithm for growing downward-growing cells.
// 4. If the tr element being processed has no td or th element children, then increase ycurrent by 1, abort
// this set of steps, and return to the algorithm above.
// NB: The remaining steps already accomplish the same thing in this case.
// 5. Let current cell be the first td or th element child in the tr element being processed.
// NB: This actually applies to children with `display: table-cell`, not just td/th elements.
// 6. Cells: While x_current is less than x_width and the slot with coordinate (x_current, y_current)
// already has a cell assigned to it, increase x_current by 1.
// 7. If xcurrent is equal to xwidth, increase xwidth by 1. (xcurrent is never greater than xwidth.)
// NB: Steps 8 and 9 are implemented in HTMLTableCellElement.col_span() and HTMLTableCellElement.row_spam()
// respectively.
// 10. Let cell grows downward be false.
// 11. If rowspan is zero, then set cell grows downward to true and set rowspan to 1.
// 12. If xwidth < xcurrent+colspan, then let xwidth be xcurrent+colspan.
// 13. If yheight < ycurrent+rowspan, then let yheight be ycurrent+rowspan.
// 14. Let the slots with coordinates (x, y) such that xcurrent <= x < xcurrent+colspan and
// ycurrent <= y < ycurrent+rowspan be covered by a new cell c, anchored at (xcurrent, ycurrent),
// which has width colspan and height rowspan, corresponding to the current cell element.
// If the current cell element is a th element, let this new cell c be a header cell;
// otherwise, let it be a data cell.
// To establish which header cells apply to the current cell element, use the algorithm for
// assigning header cells described in the next section.
// If any of the slots involved already had a cell covering them, then this is a table model error.
// Those slots now have two cells overlapping.
// NB: We don't distinguish between header and data cells here.
// 15. If cell grows downward is true, then add the tuple {c, xcurrent, colspan} to the list of downward-growing
// cells.
// FIXME: Add the tuple.
// 16. Increase xcurrent by colspan.
// NB: Step 17 is handled below, outside of this loop.
// 18. Let current cell be the next td or th element child in the tr element being processed.
// 19. Return to the step labeled cells.
// NB: Handled by the loop.
// 17. If current cell is the last td or th element child in the tr element being processed, then increase
// ycurrent by 1, abort this set of steps, and return to the algorithm above.
// NB: Called during table layout tree construction.
// Clip spans to the end of the table.
pub fn table_grid_cpp_13_table_grid_calculate_row_column_grid() LayoutStub {
	return layout_stub('TableGrid.cpp:13 TableGrid::calculate_row_column_grid')
}

// Translated from Libraries/LibWeb/Layout/TableGrid.cpp:167
// Original signature: TableGrid TableGrid::calculate_row_column_grid(Box const& box)
pub fn table_grid_cpp_167_table_grid_calculate_row_column_grid() LayoutStub {
	return layout_stub('TableGrid.cpp:167 TableGrid::calculate_row_column_grid')
}

// ---- DominantBaseline.h (2 translated function stubs) ----

// Translated from Libraries/LibWeb/Layout/DominantBaseline.h:15
// Original signature: static float dominant_baseline_offset(CSS::BaselineMetric metric, Gfx::FontPixelMetrics const& font_metrics)
// https://drafts.csswg.org/css-inline/#dominant-baseline-property
// FIXME: Read the hanging baseline from the font's BASE table.
// FIXME: Read the ideographic baseline from the font's BASE table.
// FIXME: Read the math baseline from the font's BASE table.
// FIXME: Support text-top and text-bottom.
pub fn dominant_baseline_h_15_dominant_baseline_offset() LayoutStub {
	return layout_stub('DominantBaseline.h:15 dominant_baseline_offset')
}

// Translated from Libraries/LibWeb/Layout/DominantBaseline.h:40
// Original signature: static CSS::BaselineMetric resolve_dominant_baseline_metric(CSS::ComputedValues const& computed_values)
// https://drafts.csswg.org/css-inline/#valdef-dominant-baseline-auto
// Equivalent to alphabetic in horizontal writing modes and in vertical writing modes when text-orientation is
// sideways. Equivalent to central in vertical writing modes when text-orientation is mixed or upright.
// FIXME: Take text-orientation into account once it is implemented.
pub fn dominant_baseline_h_40_resolve_dominant_baseline_metric() LayoutStub {
	return layout_stub('DominantBaseline.h:40 resolve_dominant_baseline_metric')
}
