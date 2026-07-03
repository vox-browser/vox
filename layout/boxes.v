// Copyright (c) 2018-2026, Ladybird contributors
//
// SPDX-License-Identifier: BSD-2-Clause
//
// Translated from Libraries/LibWeb/Layout/*.
// This module is an incremental V port. Functions whose dependencies have not
// been ported yet keep their source signature and comments and return neutral
// stub values so the rest of libweb_v can compile against Layout.

module layout

// ---- Box.h (21 translated function stubs) ----

// Translated from Libraries/LibWeb/Layout/Box.h:31
// Original signature: Box::GC_DECLARE_ALLOCATOR(Box);
pub fn box_h_31_box_gc_declare_allocator() LayoutStub {
	return layout_stub('Box.h:31 Box::GC_DECLARE_ALLOCATOR')
}

// Translated from Libraries/LibWeb/Layout/Box.h:34
// Original signature: Box::Painting::PaintableBox const* paintable_box() const;
pub fn box_h_34_paintable_box() LayoutStub {
	return layout_stub('Box.h:34 paintable_box')
}

// Translated from Libraries/LibWeb/Layout/Box.h:35
// Original signature: Box::Painting::PaintableBox* paintable_box();
pub fn box_h_35_paintable_box() LayoutStub {
	return layout_stub('Box.h:35 paintable_box')
}

// Translated from Libraries/LibWeb/Layout/Box.h:38
// Original signature: Box::virtual CSS::SizeWithAspectRatio natural_size() const
// https://www.w3.org/TR/css-images-3/#natural-dimensions
pub fn box_h_38_natural_size() LayoutStub {
	return layout_stub('Box.h:38 natural_size')
}

// Translated from Libraries/LibWeb/Layout/Box.h:45
// Original signature: Box::CSS::SizeWithAspectRatio auto_content_box_size() const;
// When computed width/height is auto, auto_content_box_size gives the fallback content-box size for
// elements whose used size is determined by natural dimensions, attributes, or defaults other than
// the generic UA fallback (300x150). Any returned aspect ratio comes from natural dimensions (when
// available) or may be computed from fallback sizing. Don't confuse this with the CSS preferred
// aspect ratio.
pub fn box_h_45_auto_content_box_size() LayoutStub {
	return layout_stub('Box.h:45 auto_content_box_size')
}

// Translated from Libraries/LibWeb/Layout/Box.h:46
// Original signature: Box::virtual bool has_auto_content_box_size() const
pub fn box_h_46_has_auto_content_box_size() LayoutStub {
	return layout_stub('Box.h:46 has_auto_content_box_size')
}

// Translated from Libraries/LibWeb/Layout/Box.h:49
// Original signature: Box::Optional<CSSPixelFraction> preferred_aspect_ratio() const;
// https://www.w3.org/TR/css-sizing-4/#preferred-aspect-ratio
pub fn box_h_49_preferred_aspect_ratio() LayoutStub {
	return layout_stub('Box.h:49 preferred_aspect_ratio')
}

// Translated from Libraries/LibWeb/Layout/Box.h:50
// Original signature: Box::bool has_preferred_aspect_ratio() const
pub fn box_h_50_has_preferred_aspect_ratio() LayoutStub {
	return layout_stub('Box.h:50 has_preferred_aspect_ratio')
}

// Translated from Libraries/LibWeb/Layout/Box.h:52
// Original signature: Box::virtual ~Box();
pub fn box_h_52_destroy_box() LayoutStub {
	return layout_stub('Box.h:52 ~Box')
}

// Translated from Libraries/LibWeb/Layout/Box.h:54
// Original signature: Box::virtual void did_set_content_size()
pub fn box_h_54_did_set_content_size() LayoutStub {
	return layout_stub('Box.h:54 did_set_content_size')
}

// Translated from Libraries/LibWeb/Layout/Box.h:56
// Original signature: Box::virtual GC::Ptr<Painting::Paintable> create_paintable() const;
pub fn box_h_56_create_paintable() LayoutStub {
	return layout_stub('Box.h:56 create_paintable')
}

// Translated from Libraries/LibWeb/Layout/Box.h:58
// Original signature: Box::void add_contained_abspos_child(GC::Ref<Node> child)
pub fn box_h_58_add_contained_abspos_child() LayoutStub {
	return layout_stub('Box.h:58 add_contained_abspos_child')
}

// Translated from Libraries/LibWeb/Layout/Box.h:59
// Original signature: Box::void clear_contained_abspos_children()
pub fn box_h_59_clear_contained_abspos_children() LayoutStub {
	return layout_stub('Box.h:59 clear_contained_abspos_children')
}

// Translated from Libraries/LibWeb/Layout/Box.h:60
// Original signature: Box::Vector<GC::Ref<Node>> const& contained_abspos_children() const
pub fn box_h_60_contained_abspos_children() LayoutStub {
	return layout_stub('Box.h:60 contained_abspos_children')
}

// Translated from Libraries/LibWeb/Layout/Box.h:62
// Original signature: Box::virtual void visit_edges(Cell::Visitor&);
pub fn box_h_62_visit_edges() LayoutStub {
	return layout_stub('Box.h:62 visit_edges')
}

// Translated from Libraries/LibWeb/Layout/Box.h:70
// Original signature: Box::void reset_cached_intrinsic_sizes() const
pub fn box_h_70_reset_cached_intrinsic_sizes() LayoutStub {
	return layout_stub('Box.h:70 reset_cached_intrinsic_sizes')
}

// Translated from Libraries/LibWeb/Layout/Box.h:73
// Original signature: Box::Box(DOM::Document&, DOM::Node*, GC::Ref<CSS::ComputedProperties>);
pub fn box_h_73_box_box() LayoutStub {
	return layout_stub('Box.h:73 Box::Box')
}

// Translated from Libraries/LibWeb/Layout/Box.h:74
// Original signature: Box::Box(DOM::Document&, DOM::Node*, NonnullOwnPtr<CSS::ComputedValues>);
pub fn box_h_74_box_box() LayoutStub {
	return layout_stub('Box.h:74 Box::Box')
}

// Translated from Libraries/LibWeb/Layout/Box.h:75
// Original signature: Box::virtual CSS::SizeWithAspectRatio compute_auto_content_box_size() const
pub fn box_h_75_compute_auto_content_box_size() LayoutStub {
	return layout_stub('Box.h:75 compute_auto_content_box_size')
}

// Translated from Libraries/LibWeb/Layout/Box.h:78
// Original signature: Box::virtual bool is_box() const
pub fn box_h_78_is_box() LayoutStub {
	return layout_stub('Box.h:78 is_box')
}

// Translated from Libraries/LibWeb/Layout/Box.h:86
// Original signature: inline bool Node::fast_is<Box>() const
pub fn box_h_86_function() LayoutStub {
	return layout_stub('Box.h:86 function')
}

// ---- Box.cpp (9 translated function stubs) ----

// Translated from Libraries/LibWeb/Layout/Box.cpp:20
// Original signature: Box::Box(DOM::Document& document, DOM::Node* node, GC::Ref<CSS::ComputedProperties> style) : NodeWithStyleAndBoxModelMetrics(document, node, move(style))
pub fn box_cpp_20_box_box() LayoutStub {
	return layout_stub('Box.cpp:20 Box::Box')
}

// Translated from Libraries/LibWeb/Layout/Box.cpp:25
// Original signature: Box::Box(DOM::Document& document, DOM::Node* node, NonnullOwnPtr<CSS::ComputedValues> computed_values) : NodeWithStyleAndBoxModelMetrics(document, node, move(computed_values))
pub fn box_cpp_25_box_box() LayoutStub {
	return layout_stub('Box.cpp:25 Box::Box')
}

// Translated from Libraries/LibWeb/Layout/Box.cpp:30
// Original signature: Box::~Box()
pub fn box_cpp_30_box_destroy_box() LayoutStub {
	return layout_stub('Box.cpp:30 Box::~Box')
}

// Translated from Libraries/LibWeb/Layout/Box.cpp:34
// Original signature: CSS::SizeWithAspectRatio Box::auto_content_box_size() const
// https://drafts.csswg.org/css-contain-2/#containment-size
// Replaced elements must be treated as having a natural width and height of 0 and no natural aspect
// ratio.
pub fn box_cpp_34_box_auto_content_box_size() LayoutStub {
	return layout_stub('Box.cpp:34 Box::auto_content_box_size')
}

// Translated from Libraries/LibWeb/Layout/Box.cpp:45
// Original signature: void Box::visit_edges(Cell::Visitor& visitor)
pub fn box_cpp_45_box_visit_edges() LayoutStub {
	return layout_stub('Box.cpp:45 Box::visit_edges')
}

// Translated from Libraries/LibWeb/Layout/Box.cpp:51
// Original signature: GC::Ptr<Painting::Paintable> Box::create_paintable() const
pub fn box_cpp_51_box_create_paintable() LayoutStub {
	return layout_stub('Box.cpp:51 Box::create_paintable')
}

// Translated from Libraries/LibWeb/Layout/Box.cpp:56
// Original signature: Painting::PaintableBox* Box::paintable_box()
pub fn box_cpp_56_box_paintable_box() LayoutStub {
	return layout_stub('Box.cpp:56 Box::paintable_box')
}

// Translated from Libraries/LibWeb/Layout/Box.cpp:61
// Original signature: Painting::PaintableBox const* Box::paintable_box() const
pub fn box_cpp_61_box_paintable_box() LayoutStub {
	return layout_stub('Box.cpp:61 Box::paintable_box')
}

// Translated from Libraries/LibWeb/Layout/Box.cpp:66
// Original signature: Optional<CSSPixelFraction> Box::preferred_aspect_ratio() const
// https://www.w3.org/TR/css-contain-2/#containment-size
// ratio.is_degenerate() operates on doubles while CSSPixelFraction uses CSSPixels, so we need to check again
// here.
pub fn box_cpp_66_box_preferred_aspect_ratio() LayoutStub {
	return layout_stub('Box.cpp:66 Box::preferred_aspect_ratio')
}

// ---- BlockContainer.h (8 translated function stubs) ----

// Translated from Libraries/LibWeb/Layout/BlockContainer.h:17
// Original signature: BlockContainer::GC_DECLARE_ALLOCATOR(BlockContainer);
pub fn block_container_h_17_block_container_gc_declare_allocator() LayoutStub {
	return layout_stub('BlockContainer.h:17 BlockContainer::GC_DECLARE_ALLOCATOR')
}

// Translated from Libraries/LibWeb/Layout/BlockContainer.h:20
// Original signature: BlockContainer::BlockContainer(DOM::Document&, DOM::Node*, GC::Ref<CSS::ComputedProperties>);
pub fn block_container_h_20_block_container_block_container() LayoutStub {
	return layout_stub('BlockContainer.h:20 BlockContainer::BlockContainer')
}

// Translated from Libraries/LibWeb/Layout/BlockContainer.h:21
// Original signature: BlockContainer::BlockContainer(DOM::Document&, DOM::Node*, NonnullOwnPtr<CSS::ComputedValues>);
pub fn block_container_h_21_block_container_block_container() LayoutStub {
	return layout_stub('BlockContainer.h:21 BlockContainer::BlockContainer')
}

// Translated from Libraries/LibWeb/Layout/BlockContainer.h:22
// Original signature: BlockContainer::virtual ~BlockContainer();
pub fn block_container_h_22_destroy_block_container() LayoutStub {
	return layout_stub('BlockContainer.h:22 ~BlockContainer')
}

// Translated from Libraries/LibWeb/Layout/BlockContainer.h:24
// Original signature: BlockContainer::Painting::PaintableWithLines const* paintable_with_lines() const;
pub fn block_container_h_24_paintable_with_lines() LayoutStub {
	return layout_stub('BlockContainer.h:24 paintable_with_lines')
}

// Translated from Libraries/LibWeb/Layout/BlockContainer.h:26
// Original signature: BlockContainer::virtual GC::Ptr<Painting::Paintable> create_paintable() const;
pub fn block_container_h_26_create_paintable() LayoutStub {
	return layout_stub('BlockContainer.h:26 create_paintable')
}

// Translated from Libraries/LibWeb/Layout/BlockContainer.h:29
// Original signature: BlockContainer::virtual bool is_block_container() const
pub fn block_container_h_29_is_block_container() LayoutStub {
	return layout_stub('BlockContainer.h:29 is_block_container')
}

// Translated from Libraries/LibWeb/Layout/BlockContainer.h:33
// Original signature: inline bool Node::fast_is<BlockContainer>() const
pub fn block_container_h_33_function() LayoutStub {
	return layout_stub('BlockContainer.h:33 function')
}

// ---- BlockContainer.cpp (5 translated function stubs) ----

// Translated from Libraries/LibWeb/Layout/BlockContainer.cpp:14
// Original signature: BlockContainer::BlockContainer(DOM::Document& document, DOM::Node* node, GC::Ref<CSS::ComputedProperties> style) : Box(document, node, move(style))
pub fn block_container_cpp_14_block_container_block_container() LayoutStub {
	return layout_stub('BlockContainer.cpp:14 BlockContainer::BlockContainer')
}

// Translated from Libraries/LibWeb/Layout/BlockContainer.cpp:19
// Original signature: BlockContainer::BlockContainer(DOM::Document& document, DOM::Node* node, NonnullOwnPtr<CSS::ComputedValues> computed_values) : Box(document, node, move(computed_values))
pub fn block_container_cpp_19_block_container_block_container() LayoutStub {
	return layout_stub('BlockContainer.cpp:19 BlockContainer::BlockContainer')
}

// Translated from Libraries/LibWeb/Layout/BlockContainer.cpp:24
// Original signature: BlockContainer::~BlockContainer() = default;
pub fn block_container_cpp_24_block_container_destroy_block_container() LayoutStub {
	return layout_stub('BlockContainer.cpp:24 BlockContainer::~BlockContainer')
}

// Translated from Libraries/LibWeb/Layout/BlockContainer.cpp:26
// Original signature: Painting::PaintableWithLines const* BlockContainer::paintable_with_lines() const
pub fn block_container_cpp_26_block_container_paintable_with_lines() LayoutStub {
	return layout_stub('BlockContainer.cpp:26 BlockContainer::paintable_with_lines')
}

// Translated from Libraries/LibWeb/Layout/BlockContainer.cpp:31
// Original signature: GC::Ptr<Painting::Paintable> BlockContainer::create_paintable() const
pub fn block_container_cpp_31_block_container_create_paintable() LayoutStub {
	return layout_stub('BlockContainer.cpp:31 BlockContainer::create_paintable')
}

// ---- ReplacedBox.h (8 translated function stubs) ----

// Translated from Libraries/LibWeb/Layout/ReplacedBox.h:18
// Original signature: ReplacedBox::ReplacedBox(DOM::Document&, GC::Ptr<DOM::Element>, GC::Ref<CSS::ComputedProperties>);
pub fn replaced_box_h_18_replaced_box_replaced_box() LayoutStub {
	return layout_stub('ReplacedBox.h:18 ReplacedBox::ReplacedBox')
}

// Translated from Libraries/LibWeb/Layout/ReplacedBox.h:19
// Original signature: ReplacedBox::virtual ~ReplacedBox();
pub fn replaced_box_h_19_destroy_replaced_box() LayoutStub {
	return layout_stub('ReplacedBox.h:19 ~ReplacedBox')
}

// Translated from Libraries/LibWeb/Layout/ReplacedBox.h:21
// Original signature: ReplacedBox::GC::Ptr<DOM::Element const> dom_node() const
pub fn replaced_box_h_21_dom_node() LayoutStub {
	return layout_stub('ReplacedBox.h:21 dom_node')
}

// Translated from Libraries/LibWeb/Layout/ReplacedBox.h:22
// Original signature: ReplacedBox::GC::Ptr<DOM::Element> dom_node()
pub fn replaced_box_h_22_dom_node() LayoutStub {
	return layout_stub('ReplacedBox.h:22 dom_node')
}

// Translated from Libraries/LibWeb/Layout/ReplacedBox.h:24
// Original signature: ReplacedBox::virtual bool can_have_children() const
pub fn replaced_box_h_24_can_have_children() LayoutStub {
	return layout_stub('ReplacedBox.h:24 can_have_children')
}

// Translated from Libraries/LibWeb/Layout/ReplacedBox.h:27
// Original signature: ReplacedBox::virtual bool is_replaced_box() const
pub fn replaced_box_h_27_is_replaced_box() LayoutStub {
	return layout_stub('ReplacedBox.h:27 is_replaced_box')
}

// Translated from Libraries/LibWeb/Layout/ReplacedBox.h:28
// Original signature: ReplacedBox::virtual bool has_auto_content_box_size() const
pub fn replaced_box_h_28_has_auto_content_box_size() LayoutStub {
	return layout_stub('ReplacedBox.h:28 has_auto_content_box_size')
}

// Translated from Libraries/LibWeb/Layout/ReplacedBox.h:32
// Original signature: inline bool Node::fast_is<ReplacedBox>() const
pub fn replaced_box_h_32_function() LayoutStub {
	return layout_stub('ReplacedBox.h:32 function')
}

// ---- ReplacedBox.cpp (2 translated function stubs) ----

// Translated from Libraries/LibWeb/Layout/ReplacedBox.cpp:14
// Original signature: ReplacedBox::ReplacedBox(DOM::Document& document, GC::Ptr<DOM::Element> element, GC::Ref<CSS::ComputedProperties> style) : Box(document, element, move(style))
pub fn replaced_box_cpp_14_replaced_box_replaced_box() LayoutStub {
	return layout_stub('ReplacedBox.cpp:14 ReplacedBox::ReplacedBox')
}

// Translated from Libraries/LibWeb/Layout/ReplacedBox.cpp:19
// Original signature: ReplacedBox::~ReplacedBox() = default;
pub fn replaced_box_cpp_19_replaced_box_destroy_replaced_box() LayoutStub {
	return layout_stub('ReplacedBox.cpp:19 ReplacedBox::~ReplacedBox')
}

// ---- AudioBox.h (7 translated function stubs) ----

// Translated from Libraries/LibWeb/Layout/AudioBox.h:17
// Original signature: AudioBox::GC_DECLARE_ALLOCATOR(AudioBox);
pub fn audio_box_h_17_audio_box_gc_declare_allocator() LayoutStub {
	return layout_stub('AudioBox.h:17 AudioBox::GC_DECLARE_ALLOCATOR')
}

// Translated from Libraries/LibWeb/Layout/AudioBox.h:20
// Original signature: AudioBox::HTML::HTMLAudioElement& dom_node();
pub fn audio_box_h_20_dom_node() LayoutStub {
	return layout_stub('AudioBox.h:20 dom_node')
}

// Translated from Libraries/LibWeb/Layout/AudioBox.h:21
// Original signature: AudioBox::HTML::HTMLAudioElement const& dom_node() const;
pub fn audio_box_h_21_dom_node() LayoutStub {
	return layout_stub('AudioBox.h:21 dom_node')
}

// Translated from Libraries/LibWeb/Layout/AudioBox.h:23
// Original signature: AudioBox::virtual bool can_have_children() const;
pub fn audio_box_h_23_can_have_children() LayoutStub {
	return layout_stub('AudioBox.h:23 can_have_children')
}

// Translated from Libraries/LibWeb/Layout/AudioBox.h:25
// Original signature: AudioBox::virtual GC::Ptr<Painting::Paintable> create_paintable() const;
pub fn audio_box_h_25_create_paintable() LayoutStub {
	return layout_stub('AudioBox.h:25 create_paintable')
}

// Translated from Libraries/LibWeb/Layout/AudioBox.h:30
// Original signature: AudioBox::virtual bool has_auto_content_box_size() const
// Treat the audio element as if it was not a replaced element, sizing based on its content.
// Thus, it can fit to the shadow DOM controls, instead of having a hardcoded height.
pub fn audio_box_h_30_has_auto_content_box_size() LayoutStub {
	return layout_stub('AudioBox.h:30 has_auto_content_box_size')
}

// Translated from Libraries/LibWeb/Layout/AudioBox.h:31
// Original signature: AudioBox::AudioBox(DOM::Document&, DOM::Element&, GC::Ref<CSS::ComputedProperties>);
pub fn audio_box_h_31_audio_box_audio_box() LayoutStub {
	return layout_stub('AudioBox.h:31 AudioBox::AudioBox')
}

// ---- AudioBox.cpp (5 translated function stubs) ----

// Translated from Libraries/LibWeb/Layout/AudioBox.cpp:15
// Original signature: AudioBox::AudioBox(DOM::Document& document, DOM::Element& element, GC::Ref<CSS::ComputedProperties> style) : ReplacedBox(document, element, style)
pub fn audio_box_cpp_15_audio_box_audio_box() LayoutStub {
	return layout_stub('AudioBox.cpp:15 AudioBox::AudioBox')
}

// Translated from Libraries/LibWeb/Layout/AudioBox.cpp:20
// Original signature: HTML::HTMLAudioElement& AudioBox::dom_node()
pub fn audio_box_cpp_20_audio_box_dom_node() LayoutStub {
	return layout_stub('AudioBox.cpp:20 AudioBox::dom_node')
}

// Translated from Libraries/LibWeb/Layout/AudioBox.cpp:25
// Original signature: HTML::HTMLAudioElement const& AudioBox::dom_node() const
pub fn audio_box_cpp_25_audio_box_dom_node() LayoutStub {
	return layout_stub('AudioBox.cpp:25 AudioBox::dom_node')
}

// Translated from Libraries/LibWeb/Layout/AudioBox.cpp:30
// Original signature: bool AudioBox::can_have_children() const
// If we allow children when controls are disabled, innerText may be non-empty.
pub fn audio_box_cpp_30_audio_box_can_have_children() LayoutStub {
	return layout_stub('AudioBox.cpp:30 AudioBox::can_have_children')
}

// Translated from Libraries/LibWeb/Layout/AudioBox.cpp:36
// Original signature: GC::Ptr<Painting::Paintable> AudioBox::create_paintable() const
pub fn audio_box_cpp_36_audio_box_create_paintable() LayoutStub {
	return layout_stub('AudioBox.cpp:36 AudioBox::create_paintable')
}

// ---- CanvasBox.h (6 translated function stubs) ----

// Translated from Libraries/LibWeb/Layout/CanvasBox.h:16
// Original signature: CanvasBox::GC_DECLARE_ALLOCATOR(CanvasBox);
pub fn canvas_box_h_16_canvas_box_gc_declare_allocator() LayoutStub {
	return layout_stub('CanvasBox.h:16 CanvasBox::GC_DECLARE_ALLOCATOR')
}

// Translated from Libraries/LibWeb/Layout/CanvasBox.h:19
// Original signature: CanvasBox::CanvasBox(DOM::Document&, HTML::HTMLCanvasElement&, GC::Ref<CSS::ComputedProperties>);
pub fn canvas_box_h_19_canvas_box_canvas_box() LayoutStub {
	return layout_stub('CanvasBox.h:19 CanvasBox::CanvasBox')
}

// Translated from Libraries/LibWeb/Layout/CanvasBox.h:20
// Original signature: CanvasBox::virtual ~CanvasBox();
pub fn canvas_box_h_20_destroy_canvas_box() LayoutStub {
	return layout_stub('CanvasBox.h:20 ~CanvasBox')
}

// Translated from Libraries/LibWeb/Layout/CanvasBox.h:22
// Original signature: CanvasBox::HTML::HTMLCanvasElement const& dom_node() const
pub fn canvas_box_h_22_dom_node() LayoutStub {
	return layout_stub('CanvasBox.h:22 dom_node')
}

// Translated from Libraries/LibWeb/Layout/CanvasBox.h:24
// Original signature: CanvasBox::virtual GC::Ptr<Painting::Paintable> create_paintable() const;
pub fn canvas_box_h_24_create_paintable() LayoutStub {
	return layout_stub('CanvasBox.h:24 create_paintable')
}

// Translated from Libraries/LibWeb/Layout/CanvasBox.h:27
// Original signature: CanvasBox::virtual CSS::SizeWithAspectRatio compute_auto_content_box_size() const;
pub fn canvas_box_h_27_compute_auto_content_box_size() LayoutStub {
	return layout_stub('CanvasBox.h:27 compute_auto_content_box_size')
}

// ---- CanvasBox.cpp (4 translated function stubs) ----

// Translated from Libraries/LibWeb/Layout/CanvasBox.cpp:14
// Original signature: CanvasBox::CanvasBox(DOM::Document& document, HTML::HTMLCanvasElement& element, GC::Ref<CSS::ComputedProperties> style) : ReplacedBox(document, element, move(style))
pub fn canvas_box_cpp_14_canvas_box_canvas_box() LayoutStub {
	return layout_stub('CanvasBox.cpp:14 CanvasBox::CanvasBox')
}

// Translated from Libraries/LibWeb/Layout/CanvasBox.cpp:19
// Original signature: CanvasBox::~CanvasBox() = default;
pub fn canvas_box_cpp_19_canvas_box_destroy_canvas_box() LayoutStub {
	return layout_stub('CanvasBox.cpp:19 CanvasBox::~CanvasBox')
}

// Translated from Libraries/LibWeb/Layout/CanvasBox.cpp:21
// Original signature: CSS::SizeWithAspectRatio CanvasBox::compute_auto_content_box_size() const
pub fn canvas_box_cpp_21_canvas_box_compute_auto_content_box_size() LayoutStub {
	return layout_stub('CanvasBox.cpp:21 CanvasBox::compute_auto_content_box_size')
}

// Translated from Libraries/LibWeb/Layout/CanvasBox.cpp:30
// Original signature: GC::Ptr<Painting::Paintable> CanvasBox::create_paintable() const
pub fn canvas_box_cpp_30_canvas_box_create_paintable() LayoutStub {
	return layout_stub('CanvasBox.cpp:30 CanvasBox::create_paintable')
}

// ---- CheckBox.h (5 translated function stubs) ----

// Translated from Libraries/LibWeb/Layout/CheckBox.h:16
// Original signature: CheckBox::GC_DECLARE_ALLOCATOR(CheckBox);
pub fn check_box_h_16_check_box_gc_declare_allocator() LayoutStub {
	return layout_stub('CheckBox.h:16 CheckBox::GC_DECLARE_ALLOCATOR')
}

// Translated from Libraries/LibWeb/Layout/CheckBox.h:19
// Original signature: CheckBox::CheckBox(DOM::Document&, HTML::HTMLInputElement&, GC::Ref<CSS::ComputedProperties>);
pub fn check_box_h_19_check_box_check_box() LayoutStub {
	return layout_stub('CheckBox.h:19 CheckBox::CheckBox')
}

// Translated from Libraries/LibWeb/Layout/CheckBox.h:20
// Original signature: CheckBox::virtual ~CheckBox();
pub fn check_box_h_20_destroy_check_box() LayoutStub {
	return layout_stub('CheckBox.h:20 ~CheckBox')
}

// Translated from Libraries/LibWeb/Layout/CheckBox.h:23
// Original signature: CheckBox::virtual CSS::SizeWithAspectRatio compute_auto_content_box_size() const
pub fn check_box_h_23_compute_auto_content_box_size() LayoutStub {
	return layout_stub('CheckBox.h:23 compute_auto_content_box_size')
}

// Translated from Libraries/LibWeb/Layout/CheckBox.h:24
// Original signature: CheckBox::virtual GC::Ptr<Painting::Paintable> create_paintable() const;
pub fn check_box_h_24_create_paintable() LayoutStub {
	return layout_stub('CheckBox.h:24 create_paintable')
}

// ---- CheckBox.cpp (3 translated function stubs) ----

// Translated from Libraries/LibWeb/Layout/CheckBox.cpp:16
// Original signature: CheckBox::CheckBox(DOM::Document& document, HTML::HTMLInputElement& element, GC::Ref<CSS::ComputedProperties> style) : ReplacedBox(document, element, move(style))
pub fn check_box_cpp_16_check_box_check_box() LayoutStub {
	return layout_stub('CheckBox.cpp:16 CheckBox::CheckBox')
}

// Translated from Libraries/LibWeb/Layout/CheckBox.cpp:21
// Original signature: CheckBox::~CheckBox() = default;
pub fn check_box_cpp_21_check_box_destroy_check_box() LayoutStub {
	return layout_stub('CheckBox.cpp:21 CheckBox::~CheckBox')
}

// Translated from Libraries/LibWeb/Layout/CheckBox.cpp:23
// Original signature: GC::Ptr<Painting::Paintable> CheckBox::create_paintable() const
pub fn check_box_cpp_23_check_box_create_paintable() LayoutStub {
	return layout_stub('CheckBox.cpp:23 CheckBox::create_paintable')
}

// ---- RadioButton.h (5 translated function stubs) ----

// Translated from Libraries/LibWeb/Layout/RadioButton.h:16
// Original signature: RadioButton::GC_DECLARE_ALLOCATOR(RadioButton);
pub fn radio_button_h_16_radio_button_gc_declare_allocator() LayoutStub {
	return layout_stub('RadioButton.h:16 RadioButton::GC_DECLARE_ALLOCATOR')
}

// Translated from Libraries/LibWeb/Layout/RadioButton.h:19
// Original signature: RadioButton::RadioButton(DOM::Document&, HTML::HTMLInputElement&, GC::Ref<CSS::ComputedProperties>);
pub fn radio_button_h_19_radio_button_radio_button() LayoutStub {
	return layout_stub('RadioButton.h:19 RadioButton::RadioButton')
}

// Translated from Libraries/LibWeb/Layout/RadioButton.h:20
// Original signature: RadioButton::virtual ~RadioButton();
pub fn radio_button_h_20_destroy_radio_button() LayoutStub {
	return layout_stub('RadioButton.h:20 ~RadioButton')
}

// Translated from Libraries/LibWeb/Layout/RadioButton.h:23
// Original signature: RadioButton::CSS::SizeWithAspectRatio compute_auto_content_box_size() const
pub fn radio_button_h_23_compute_auto_content_box_size() LayoutStub {
	return layout_stub('RadioButton.h:23 compute_auto_content_box_size')
}

// Translated from Libraries/LibWeb/Layout/RadioButton.h:24
// Original signature: RadioButton::virtual GC::Ptr<Painting::Paintable> create_paintable() const;
pub fn radio_button_h_24_create_paintable() LayoutStub {
	return layout_stub('RadioButton.h:24 create_paintable')
}

// ---- RadioButton.cpp (3 translated function stubs) ----

// Translated from Libraries/LibWeb/Layout/RadioButton.cpp:17
// Original signature: RadioButton::RadioButton(DOM::Document& document, HTML::HTMLInputElement& element, GC::Ref<CSS::ComputedProperties> style) : ReplacedBox(document, element, move(style))
pub fn radio_button_cpp_17_radio_button_radio_button() LayoutStub {
	return layout_stub('RadioButton.cpp:17 RadioButton::RadioButton')
}

// Translated from Libraries/LibWeb/Layout/RadioButton.cpp:22
// Original signature: RadioButton::~RadioButton() = default;
pub fn radio_button_cpp_22_radio_button_destroy_radio_button() LayoutStub {
	return layout_stub('RadioButton.cpp:22 RadioButton::~RadioButton')
}

// Translated from Libraries/LibWeb/Layout/RadioButton.cpp:24
// Original signature: GC::Ptr<Painting::Paintable> RadioButton::create_paintable() const
pub fn radio_button_cpp_24_radio_button_create_paintable() LayoutStub {
	return layout_stub('RadioButton.cpp:24 RadioButton::create_paintable')
}

// ---- VideoBox.h (7 translated function stubs) ----

// Translated from Libraries/LibWeb/Layout/VideoBox.h:16
// Original signature: VideoBox::GC_DECLARE_ALLOCATOR(VideoBox);
pub fn video_box_h_16_video_box_gc_declare_allocator() LayoutStub {
	return layout_stub('VideoBox.h:16 VideoBox::GC_DECLARE_ALLOCATOR')
}

// Translated from Libraries/LibWeb/Layout/VideoBox.h:19
// Original signature: VideoBox::HTML::HTMLVideoElement& dom_node();
pub fn video_box_h_19_dom_node() LayoutStub {
	return layout_stub('VideoBox.h:19 dom_node')
}

// Translated from Libraries/LibWeb/Layout/VideoBox.h:20
// Original signature: VideoBox::HTML::HTMLVideoElement const& dom_node() const;
pub fn video_box_h_20_dom_node() LayoutStub {
	return layout_stub('VideoBox.h:20 dom_node')
}

// Translated from Libraries/LibWeb/Layout/VideoBox.h:22
// Original signature: VideoBox::virtual bool can_have_children() const;
pub fn video_box_h_22_can_have_children() LayoutStub {
	return layout_stub('VideoBox.h:22 can_have_children')
}

// Translated from Libraries/LibWeb/Layout/VideoBox.h:24
// Original signature: VideoBox::virtual GC::Ptr<Painting::Paintable> create_paintable() const;
pub fn video_box_h_24_create_paintable() LayoutStub {
	return layout_stub('VideoBox.h:24 create_paintable')
}

// Translated from Libraries/LibWeb/Layout/VideoBox.h:27
// Original signature: VideoBox::VideoBox(DOM::Document&, DOM::Element&, GC::Ref<CSS::ComputedProperties>);
pub fn video_box_h_27_video_box_video_box() LayoutStub {
	return layout_stub('VideoBox.h:27 VideoBox::VideoBox')
}

// Translated from Libraries/LibWeb/Layout/VideoBox.h:28
// Original signature: VideoBox::virtual CSS::SizeWithAspectRatio natural_size() const;
pub fn video_box_h_28_natural_size() LayoutStub {
	return layout_stub('VideoBox.h:28 natural_size')
}

// ---- VideoBox.cpp (6 translated function stubs) ----

// Translated from Libraries/LibWeb/Layout/VideoBox.cpp:15
// Original signature: VideoBox::VideoBox(DOM::Document& document, DOM::Element& element, GC::Ref<CSS::ComputedProperties> style) : ReplacedBox(document, element, style)
pub fn video_box_cpp_15_video_box_video_box() LayoutStub {
	return layout_stub('VideoBox.cpp:15 VideoBox::VideoBox')
}

// Translated from Libraries/LibWeb/Layout/VideoBox.cpp:20
// Original signature: HTML::HTMLVideoElement& VideoBox::dom_node()
pub fn video_box_cpp_20_video_box_dom_node() LayoutStub {
	return layout_stub('VideoBox.cpp:20 VideoBox::dom_node')
}

// Translated from Libraries/LibWeb/Layout/VideoBox.cpp:25
// Original signature: HTML::HTMLVideoElement const& VideoBox::dom_node() const
pub fn video_box_cpp_25_video_box_dom_node() LayoutStub {
	return layout_stub('VideoBox.cpp:25 VideoBox::dom_node')
}

// Translated from Libraries/LibWeb/Layout/VideoBox.cpp:30
// Original signature: bool VideoBox::can_have_children() const
// If we allow children when controls are disabled, innerText may be non-empty.
pub fn video_box_cpp_30_video_box_can_have_children() LayoutStub {
	return layout_stub('VideoBox.cpp:30 VideoBox::can_have_children')
}

// Translated from Libraries/LibWeb/Layout/VideoBox.cpp:36
// Original signature: CSS::SizeWithAspectRatio VideoBox::natural_size() const
pub fn video_box_cpp_36_video_box_natural_size() LayoutStub {
	return layout_stub('VideoBox.cpp:36 VideoBox::natural_size')
}

// Translated from Libraries/LibWeb/Layout/VideoBox.cpp:45
// Original signature: GC::Ptr<Painting::Paintable> VideoBox::create_paintable() const
pub fn video_box_cpp_45_video_box_create_paintable() LayoutStub {
	return layout_stub('VideoBox.cpp:45 VideoBox::create_paintable')
}

// ---- ImageBox.h (10 translated function stubs) ----

// Translated from Libraries/LibWeb/Layout/ImageBox.h:16
// Original signature: ImageBox::GC_DECLARE_ALLOCATOR(ImageBox);
pub fn image_box_h_16_image_box_gc_declare_allocator() LayoutStub {
	return layout_stub('ImageBox.h:16 ImageBox::GC_DECLARE_ALLOCATOR')
}

// Translated from Libraries/LibWeb/Layout/ImageBox.h:19
// Original signature: ImageBox::ImageBox(DOM::Document&, GC::Ptr<DOM::Element>, GC::Ref<CSS::ComputedProperties>, ImageProvider const&);
pub fn image_box_h_19_image_box_image_box() LayoutStub {
	return layout_stub('ImageBox.h:19 ImageBox::ImageBox')
}

// Translated from Libraries/LibWeb/Layout/ImageBox.h:20
// Original signature: ImageBox::virtual ~ImageBox();
pub fn image_box_h_20_destroy_image_box() LayoutStub {
	return layout_stub('ImageBox.h:20 ~ImageBox')
}

// Translated from Libraries/LibWeb/Layout/ImageBox.h:22
// Original signature: ImageBox::bool renders_as_alt_text() const;
pub fn image_box_h_22_renders_as_alt_text() LayoutStub {
	return layout_stub('ImageBox.h:22 renders_as_alt_text')
}

// Translated from Libraries/LibWeb/Layout/ImageBox.h:24
// Original signature: ImageBox::virtual GC::Ptr<Painting::Paintable> create_paintable() const;
pub fn image_box_h_24_create_paintable() LayoutStub {
	return layout_stub('ImageBox.h:24 create_paintable')
}

// Translated from Libraries/LibWeb/Layout/ImageBox.h:26
// Original signature: ImageBox::auto const& image_provider() const
pub fn image_box_h_26_image_provider() LayoutStub {
	return layout_stub('ImageBox.h:26 image_provider')
}

// Translated from Libraries/LibWeb/Layout/ImageBox.h:27
// Original signature: ImageBox::auto& image_provider()
pub fn image_box_h_27_image_provider() LayoutStub {
	return layout_stub('ImageBox.h:27 image_provider')
}

// Translated from Libraries/LibWeb/Layout/ImageBox.h:29
// Original signature: ImageBox::void dom_node_did_update_alt_text(Badge<ImageProvider>);
pub fn image_box_h_29_dom_node_did_update_alt_text() LayoutStub {
	return layout_stub('ImageBox.h:29 dom_node_did_update_alt_text')
}

// Translated from Libraries/LibWeb/Layout/ImageBox.h:32
// Original signature: ImageBox::virtual void visit_edges(Visitor&);
pub fn image_box_h_32_visit_edges() LayoutStub {
	return layout_stub('ImageBox.h:32 visit_edges')
}

// Translated from Libraries/LibWeb/Layout/ImageBox.h:33
// Original signature: ImageBox::virtual CSS::SizeWithAspectRatio natural_size() const;
pub fn image_box_h_33_natural_size() LayoutStub {
	return layout_stub('ImageBox.h:33 natural_size')
}

// ---- ImageBox.cpp (7 translated function stubs) ----

// Translated from Libraries/LibWeb/Layout/ImageBox.cpp:18
// Original signature: ImageBox::ImageBox(DOM::Document& document, GC::Ptr<DOM::Element> element, GC::Ref<CSS::ComputedProperties> style, ImageProvider const& image_provider) : ReplacedBox(document, element, move(style)) , m_image_provider(image_provider)
pub fn image_box_cpp_18_image_box_image_box() LayoutStub {
	return layout_stub('ImageBox.cpp:18 ImageBox::ImageBox')
}

// Translated from Libraries/LibWeb/Layout/ImageBox.cpp:24
// Original signature: ImageBox::~ImageBox() = default;
pub fn image_box_cpp_24_image_box_destroy_image_box() LayoutStub {
	return layout_stub('ImageBox.cpp:24 ImageBox::~ImageBox')
}

// Translated from Libraries/LibWeb/Layout/ImageBox.cpp:26
// Original signature: void ImageBox::visit_edges(JS::Cell::Visitor& visitor)
pub fn image_box_cpp_26_image_box_visit_edges() LayoutStub {
	return layout_stub('ImageBox.cpp:26 ImageBox::visit_edges')
}

// Translated from Libraries/LibWeb/Layout/ImageBox.cpp:32
// Original signature: CSS::SizeWithAspectRatio ImageBox::natural_size() const
pub fn image_box_cpp_32_image_box_natural_size() LayoutStub {
	return layout_stub('ImageBox.cpp:32 ImageBox::natural_size')
}

// Translated from Libraries/LibWeb/Layout/ImageBox.cpp:62
// Original signature: void ImageBox::dom_node_did_update_alt_text(Badge<ImageProvider>)
pub fn image_box_cpp_62_image_box_dom_node_did_update_alt_text() LayoutStub {
	return layout_stub('ImageBox.cpp:62 ImageBox::dom_node_did_update_alt_text')
}

// Translated from Libraries/LibWeb/Layout/ImageBox.cpp:67
// Original signature: bool ImageBox::renders_as_alt_text() const
pub fn image_box_cpp_67_image_box_renders_as_alt_text() LayoutStub {
	return layout_stub('ImageBox.cpp:67 ImageBox::renders_as_alt_text')
}

// Translated from Libraries/LibWeb/Layout/ImageBox.cpp:72
// Original signature: GC::Ptr<Painting::Paintable> ImageBox::create_paintable() const
pub fn image_box_cpp_72_image_box_create_paintable() LayoutStub {
	return layout_stub('ImageBox.cpp:72 ImageBox::create_paintable')
}

// ---- ImageProvider.h (15 translated function stubs) ----

// Translated from Libraries/LibWeb/Layout/ImageProvider.h:18
// Original signature: ImageProvider::virtual ~ImageProvider()
pub fn image_provider_h_18_destroy_image_provider() LayoutStub {
	return layout_stub('ImageProvider.h:18 ~ImageProvider')
}

// Translated from Libraries/LibWeb/Layout/ImageProvider.h:20
// Original signature: ImageProvider::virtual bool is_image_available() const = 0;
pub fn image_provider_h_20_is_image_available() LayoutStub {
	return layout_stub('ImageProvider.h:20 is_image_available')
}

// Translated from Libraries/LibWeb/Layout/ImageProvider.h:22
// Original signature: ImageProvider::virtual size_t current_frame_index() const = 0;
pub fn image_provider_h_22_current_frame_index() LayoutStub {
	return layout_stub('ImageProvider.h:22 current_frame_index')
}

// Translated from Libraries/LibWeb/Layout/ImageProvider.h:24
// Original signature: ImageProvider::virtual GC::Ptr<HTML::DecodedImageData> decoded_image_data() const = 0;
pub fn image_provider_h_24_decoded_image_data() LayoutStub {
	return layout_stub('ImageProvider.h:24 decoded_image_data')
}

// Translated from Libraries/LibWeb/Layout/ImageProvider.h:26
// Original signature: ImageProvider::virtual Optional<CSSPixels> intrinsic_width() const = 0;
pub fn image_provider_h_26_intrinsic_width() LayoutStub {
	return layout_stub('ImageProvider.h:26 intrinsic_width')
}

// Translated from Libraries/LibWeb/Layout/ImageProvider.h:27
// Original signature: ImageProvider::virtual Optional<CSSPixels> intrinsic_height() const = 0;
pub fn image_provider_h_27_intrinsic_height() LayoutStub {
	return layout_stub('ImageProvider.h:27 intrinsic_height')
}

// Translated from Libraries/LibWeb/Layout/ImageProvider.h:28
// Original signature: ImageProvider::Optional<CSSPixelSize> intrinsic_size() const;
pub fn image_provider_h_28_intrinsic_size() LayoutStub {
	return layout_stub('ImageProvider.h:28 intrinsic_size')
}

// Translated from Libraries/LibWeb/Layout/ImageProvider.h:29
// Original signature: ImageProvider::virtual Optional<CSSPixelFraction> intrinsic_aspect_ratio() const = 0;
pub fn image_provider_h_29_intrinsic_aspect_ratio() LayoutStub {
	return layout_stub('ImageProvider.h:29 intrinsic_aspect_ratio')
}

// Translated from Libraries/LibWeb/Layout/ImageProvider.h:31
// Original signature: ImageProvider::virtual RefPtr<Gfx::ImmutableBitmap> current_image_bitmap() const;
pub fn image_provider_h_31_current_image_bitmap() LayoutStub {
	return layout_stub('ImageProvider.h:31 current_image_bitmap')
}

// Translated from Libraries/LibWeb/Layout/ImageProvider.h:32
// Original signature: ImageProvider::virtual RefPtr<Gfx::ImmutableBitmap> current_image_bitmap_sized(Gfx::IntSize) const = 0;
pub fn image_provider_h_32_current_image_bitmap_sized() LayoutStub {
	return layout_stub('ImageProvider.h:32 current_image_bitmap_sized')
}

// Translated from Libraries/LibWeb/Layout/ImageProvider.h:34
// Original signature: ImageProvider::virtual RefPtr<Gfx::ImmutableBitmap> default_image_bitmap() const;
pub fn image_provider_h_34_default_image_bitmap() LayoutStub {
	return layout_stub('ImageProvider.h:34 default_image_bitmap')
}

// Translated from Libraries/LibWeb/Layout/ImageProvider.h:35
// Original signature: ImageProvider::virtual RefPtr<Gfx::ImmutableBitmap> default_image_bitmap_sized(Gfx::IntSize) const;
pub fn image_provider_h_35_default_image_bitmap_sized() LayoutStub {
	return layout_stub('ImageProvider.h:35 default_image_bitmap_sized')
}

// Translated from Libraries/LibWeb/Layout/ImageProvider.h:37
// Original signature: ImageProvider::virtual void set_visible_in_viewport(bool) = 0;
pub fn image_provider_h_37_set_visible_in_viewport() LayoutStub {
	return layout_stub('ImageProvider.h:37 set_visible_in_viewport')
}

// Translated from Libraries/LibWeb/Layout/ImageProvider.h:45
// Original signature: ImageProvider::virtual GC::Ptr<DOM::Element const> to_html_element() const = 0;
pub fn image_provider_h_45_to_html_element() LayoutStub {
	return layout_stub('ImageProvider.h:45 to_html_element')
}

// Translated from Libraries/LibWeb/Layout/ImageProvider.h:46
// Original signature: ImageProvider::static void did_update_alt_text(ImageBox&);
pub fn image_provider_h_46_did_update_alt_text() LayoutStub {
	return layout_stub('ImageProvider.h:46 did_update_alt_text')
}

// ---- ImageProvider.cpp (5 translated function stubs) ----

// Translated from Libraries/LibWeb/Layout/ImageProvider.cpp:13
// Original signature: void ImageProvider::did_update_alt_text(ImageBox& layout_node)
pub fn image_provider_cpp_13_image_provider_did_update_alt_text() LayoutStub {
	return layout_stub('ImageProvider.cpp:13 ImageProvider::did_update_alt_text')
}

// Translated from Libraries/LibWeb/Layout/ImageProvider.cpp:18
// Original signature: Optional<CSSPixelSize> ImageProvider::intrinsic_size() const
pub fn image_provider_cpp_18_image_provider_intrinsic_size() LayoutStub {
	return layout_stub('ImageProvider.cpp:18 ImageProvider::intrinsic_size')
}

// Translated from Libraries/LibWeb/Layout/ImageProvider.cpp:28
// Original signature: RefPtr<Gfx::ImmutableBitmap> ImageProvider::current_image_bitmap() const
pub fn image_provider_cpp_28_image_provider_current_image_bitmap() LayoutStub {
	return layout_stub('ImageProvider.cpp:28 ImageProvider::current_image_bitmap')
}

// Translated from Libraries/LibWeb/Layout/ImageProvider.cpp:33
// Original signature: RefPtr<Gfx::ImmutableBitmap> ImageProvider::default_image_bitmap() const
pub fn image_provider_cpp_33_image_provider_default_image_bitmap() LayoutStub {
	return layout_stub('ImageProvider.cpp:33 ImageProvider::default_image_bitmap')
}

// Translated from Libraries/LibWeb/Layout/ImageProvider.cpp:38
// Original signature: RefPtr<Gfx::ImmutableBitmap> ImageProvider::default_image_bitmap_sized(Gfx::IntSize size) const
// Defer to the current image by default.
pub fn image_provider_cpp_38_image_provider_default_image_bitmap_sized() LayoutStub {
	return layout_stub('ImageProvider.cpp:38 ImageProvider::default_image_bitmap_sized')
}

// ---- NavigableContainerViewport.h (8 translated function stubs) ----

// Translated from Libraries/LibWeb/Layout/NavigableContainerViewport.h:16
// Original signature: NavigableContainerViewport::GC_DECLARE_ALLOCATOR(NavigableContainerViewport);
pub fn navigable_container_viewport_h_16_navigable_container_viewport_gc_declare_allocator() LayoutStub {
	return layout_stub('NavigableContainerViewport.h:16 NavigableContainerViewport::GC_DECLARE_ALLOCATOR')
}

// Translated from Libraries/LibWeb/Layout/NavigableContainerViewport.h:19
// Original signature: NavigableContainerViewport::NavigableContainerViewport(DOM::Document&, HTML::NavigableContainer&, GC::Ref<CSS::ComputedProperties>);
pub fn navigable_container_viewport_h_19_navigable_container_viewport_navigable_container_viewport() LayoutStub {
	return layout_stub('NavigableContainerViewport.h:19 NavigableContainerViewport::NavigableContainerViewport')
}

// Translated from Libraries/LibWeb/Layout/NavigableContainerViewport.h:20
// Original signature: NavigableContainerViewport::virtual ~NavigableContainerViewport();
pub fn navigable_container_viewport_h_20_destroy_navigable_container_viewport() LayoutStub {
	return layout_stub('NavigableContainerViewport.h:20 ~NavigableContainerViewport')
}

// Translated from Libraries/LibWeb/Layout/NavigableContainerViewport.h:22
// Original signature: NavigableContainerViewport::[[nodiscard]] HTML::NavigableContainer const& dom_node() const
pub fn navigable_container_viewport_h_22_dom_node() LayoutStub {
	return layout_stub('NavigableContainerViewport.h:22 dom_node')
}

// Translated from Libraries/LibWeb/Layout/NavigableContainerViewport.h:23
// Original signature: NavigableContainerViewport::[[nodiscard]] HTML::NavigableContainer& dom_node()
pub fn navigable_container_viewport_h_23_dom_node() LayoutStub {
	return layout_stub('NavigableContainerViewport.h:23 dom_node')
}

// Translated from Libraries/LibWeb/Layout/NavigableContainerViewport.h:25
// Original signature: NavigableContainerViewport::virtual GC::Ptr<Painting::Paintable> create_paintable() const;
pub fn navigable_container_viewport_h_25_create_paintable() LayoutStub {
	return layout_stub('NavigableContainerViewport.h:25 create_paintable')
}

// Translated from Libraries/LibWeb/Layout/NavigableContainerViewport.h:28
// Original signature: NavigableContainerViewport::virtual CSS::SizeWithAspectRatio natural_size() const;
pub fn navigable_container_viewport_h_28_natural_size() LayoutStub {
	return layout_stub('NavigableContainerViewport.h:28 natural_size')
}

// Translated from Libraries/LibWeb/Layout/NavigableContainerViewport.h:29
// Original signature: NavigableContainerViewport::virtual void did_set_content_size();
pub fn navigable_container_viewport_h_29_did_set_content_size() LayoutStub {
	return layout_stub('NavigableContainerViewport.h:29 did_set_content_size')
}

// ---- NavigableContainerViewport.cpp (5 translated function stubs) ----

// Translated from Libraries/LibWeb/Layout/NavigableContainerViewport.cpp:20
// Original signature: NavigableContainerViewport::NavigableContainerViewport(DOM::Document& document, HTML::NavigableContainer& element, GC::Ref<CSS::ComputedProperties> style) : ReplacedBox(document, element, move(style))
pub fn navigable_container_viewport_cpp_20_navigable_container_viewport_navigable_container_viewport() LayoutStub {
	return layout_stub('NavigableContainerViewport.cpp:20 NavigableContainerViewport::NavigableContainerViewport')
}

// Translated from Libraries/LibWeb/Layout/NavigableContainerViewport.cpp:25
// Original signature: NavigableContainerViewport::~NavigableContainerViewport() = default;
pub fn navigable_container_viewport_cpp_25_navigable_container_viewport_destroy_navigable_container_viewport() LayoutStub {
	return layout_stub('NavigableContainerViewport.cpp:25 NavigableContainerViewport::~NavigableContainerViewport')
}

// Translated from Libraries/LibWeb/Layout/NavigableContainerViewport.cpp:27
// Original signature: CSS::SizeWithAspectRatio NavigableContainerViewport::natural_size() const
pub fn navigable_container_viewport_cpp_27_navigable_container_viewport_natural_size() LayoutStub {
	return layout_stub('NavigableContainerViewport.cpp:27 NavigableContainerViewport::natural_size')
}

// Translated from Libraries/LibWeb/Layout/NavigableContainerViewport.cpp:43
// Original signature: void NavigableContainerViewport::did_set_content_size()
pub fn navigable_container_viewport_cpp_43_navigable_container_viewport_did_set_content_size() LayoutStub {
	return layout_stub('NavigableContainerViewport.cpp:43 NavigableContainerViewport::did_set_content_size')
}

// Translated from Libraries/LibWeb/Layout/NavigableContainerViewport.cpp:51
// Original signature: GC::Ptr<Painting::Paintable> NavigableContainerViewport::create_paintable() const
pub fn navigable_container_viewport_cpp_51_navigable_container_viewport_create_paintable() LayoutStub {
	return layout_stub('NavigableContainerViewport.cpp:51 NavigableContainerViewport::create_paintable')
}

// ---- FieldSetBox.h (8 translated function stubs) ----

// Translated from Libraries/LibWeb/Layout/FieldSetBox.h:18
// Original signature: FieldSetBox::GC_DECLARE_ALLOCATOR(FieldSetBox);
pub fn field_set_box_h_18_field_set_box_gc_declare_allocator() LayoutStub {
	return layout_stub('FieldSetBox.h:18 FieldSetBox::GC_DECLARE_ALLOCATOR')
}

// Translated from Libraries/LibWeb/Layout/FieldSetBox.h:21
// Original signature: FieldSetBox::FieldSetBox(DOM::Document&, DOM::Element&, GC::Ref<CSS::ComputedProperties>);
pub fn field_set_box_h_21_field_set_box_field_set_box() LayoutStub {
	return layout_stub('FieldSetBox.h:21 FieldSetBox::FieldSetBox')
}

// Translated from Libraries/LibWeb/Layout/FieldSetBox.h:22
// Original signature: FieldSetBox::virtual ~FieldSetBox();
pub fn field_set_box_h_22_destroy_field_set_box() LayoutStub {
	return layout_stub('FieldSetBox.h:22 ~FieldSetBox')
}

// Translated from Libraries/LibWeb/Layout/FieldSetBox.h:24
// Original signature: FieldSetBox::DOM::Element& dom_node()
pub fn field_set_box_h_24_dom_node() LayoutStub {
	return layout_stub('FieldSetBox.h:24 dom_node')
}

// Translated from Libraries/LibWeb/Layout/FieldSetBox.h:25
// Original signature: FieldSetBox::DOM::Element const& dom_node() const
pub fn field_set_box_h_25_dom_node() LayoutStub {
	return layout_stub('FieldSetBox.h:25 dom_node')
}

// Translated from Libraries/LibWeb/Layout/FieldSetBox.h:27
// Original signature: FieldSetBox::GC::Ptr<LegendBox const> rendered_legend() const;
pub fn field_set_box_h_27_rendered_legend() LayoutStub {
	return layout_stub('FieldSetBox.h:27 rendered_legend')
}

// Translated from Libraries/LibWeb/Layout/FieldSetBox.h:28
// Original signature: FieldSetBox::virtual GC::Ptr<Painting::Paintable> create_paintable() const;
pub fn field_set_box_h_28_create_paintable() LayoutStub {
	return layout_stub('FieldSetBox.h:28 create_paintable')
}

// Translated from Libraries/LibWeb/Layout/FieldSetBox.h:38
// Original signature: inline bool Node::fast_is<FieldSetBox>() const
pub fn field_set_box_h_38_function() LayoutStub {
	return layout_stub('FieldSetBox.h:38 function')
}

// ---- FieldSetBox.cpp (4 translated function stubs) ----

// Translated from Libraries/LibWeb/Layout/FieldSetBox.cpp:15
// Original signature: FieldSetBox::FieldSetBox(DOM::Document& document, DOM::Element& element, GC::Ref<CSS::ComputedProperties> style) : BlockContainer(document, &element, style)
pub fn field_set_box_cpp_15_field_set_box_field_set_box() LayoutStub {
	return layout_stub('FieldSetBox.cpp:15 FieldSetBox::FieldSetBox')
}

// Translated from Libraries/LibWeb/Layout/FieldSetBox.cpp:20
// Original signature: FieldSetBox::~FieldSetBox() = default;
pub fn field_set_box_cpp_20_field_set_box_destroy_field_set_box() LayoutStub {
	return layout_stub('FieldSetBox.cpp:20 FieldSetBox::~FieldSetBox')
}

// Translated from Libraries/LibWeb/Layout/FieldSetBox.cpp:22
// Original signature: GC::Ptr<LegendBox const> FieldSetBox::rendered_legend() const
// https://html.spec.whatwg.org/multipage/rendering.html#rendered-legend
// If the element's box has a child box that matches the conditions in the list below, then the first such child
// box
// is the 'fieldset' element's rendered legend:
// The child is a legend element.
// The child's used value of 'float' is 'none'.
// The child's used value of 'position' is not 'absolute' or 'fixed'.
pub fn field_set_box_cpp_22_field_set_box_rendered_legend() LayoutStub {
	return layout_stub('FieldSetBox.cpp:22 FieldSetBox::rendered_legend')
}

// Translated from Libraries/LibWeb/Layout/FieldSetBox.cpp:40
// Original signature: GC::Ptr<Painting::Paintable> FieldSetBox::create_paintable() const
pub fn field_set_box_cpp_40_field_set_box_create_paintable() LayoutStub {
	return layout_stub('FieldSetBox.cpp:40 FieldSetBox::create_paintable')
}

// ---- LegendBox.h (6 translated function stubs) ----

// Translated from Libraries/LibWeb/Layout/LegendBox.h:16
// Original signature: LegendBox::GC_DECLARE_ALLOCATOR(LegendBox);
pub fn legend_box_h_16_legend_box_gc_declare_allocator() LayoutStub {
	return layout_stub('LegendBox.h:16 LegendBox::GC_DECLARE_ALLOCATOR')
}

// Translated from Libraries/LibWeb/Layout/LegendBox.h:19
// Original signature: LegendBox::LegendBox(DOM::Document&, DOM::Element&, GC::Ref<CSS::ComputedProperties>);
pub fn legend_box_h_19_legend_box_legend_box() LayoutStub {
	return layout_stub('LegendBox.h:19 LegendBox::LegendBox')
}

// Translated from Libraries/LibWeb/Layout/LegendBox.h:20
// Original signature: LegendBox::virtual ~LegendBox();
pub fn legend_box_h_20_destroy_legend_box() LayoutStub {
	return layout_stub('LegendBox.h:20 ~LegendBox')
}

// Translated from Libraries/LibWeb/Layout/LegendBox.h:22
// Original signature: LegendBox::DOM::Element& dom_node()
pub fn legend_box_h_22_dom_node() LayoutStub {
	return layout_stub('LegendBox.h:22 dom_node')
}

// Translated from Libraries/LibWeb/Layout/LegendBox.h:23
// Original signature: LegendBox::DOM::Element const& dom_node() const
pub fn legend_box_h_23_dom_node() LayoutStub {
	return layout_stub('LegendBox.h:23 dom_node')
}

// Translated from Libraries/LibWeb/Layout/LegendBox.h:33
// Original signature: inline bool Node::fast_is<LegendBox>() const
pub fn legend_box_h_33_function() LayoutStub {
	return layout_stub('LegendBox.h:33 function')
}

// ---- LegendBox.cpp (2 translated function stubs) ----

// Translated from Libraries/LibWeb/Layout/LegendBox.cpp:13
// Original signature: LegendBox::LegendBox(DOM::Document& document, DOM::Element& element, GC::Ref<CSS::ComputedProperties> style) : BlockContainer(document, &element, move(style))
pub fn legend_box_cpp_13_legend_box_legend_box() LayoutStub {
	return layout_stub('LegendBox.cpp:13 LegendBox::LegendBox')
}

// Translated from Libraries/LibWeb/Layout/LegendBox.cpp:18
// Original signature: LegendBox::~LegendBox() = default;
pub fn legend_box_cpp_18_legend_box_destroy_legend_box() LayoutStub {
	return layout_stub('LegendBox.cpp:18 LegendBox::~LegendBox')
}

// ---- ListItemBox.h (10 translated function stubs) ----

// Translated from Libraries/LibWeb/Layout/ListItemBox.h:16
// Original signature: ListItemBox::GC_DECLARE_ALLOCATOR(ListItemBox);
pub fn list_item_box_h_16_list_item_box_gc_declare_allocator() LayoutStub {
	return layout_stub('ListItemBox.h:16 ListItemBox::GC_DECLARE_ALLOCATOR')
}

// Translated from Libraries/LibWeb/Layout/ListItemBox.h:19
// Original signature: ListItemBox::ListItemBox(DOM::Document&, DOM::Element*, GC::Ref<CSS::ComputedProperties>);
pub fn list_item_box_h_19_list_item_box_list_item_box() LayoutStub {
	return layout_stub('ListItemBox.h:19 ListItemBox::ListItemBox')
}

// Translated from Libraries/LibWeb/Layout/ListItemBox.h:20
// Original signature: ListItemBox::virtual ~ListItemBox();
pub fn list_item_box_h_20_destroy_list_item_box() LayoutStub {
	return layout_stub('ListItemBox.h:20 ~ListItemBox')
}

// Translated from Libraries/LibWeb/Layout/ListItemBox.h:22
// Original signature: ListItemBox::DOM::Element& dom_node()
pub fn list_item_box_h_22_dom_node() LayoutStub {
	return layout_stub('ListItemBox.h:22 dom_node')
}

// Translated from Libraries/LibWeb/Layout/ListItemBox.h:23
// Original signature: ListItemBox::DOM::Element const& dom_node() const
pub fn list_item_box_h_23_dom_node() LayoutStub {
	return layout_stub('ListItemBox.h:23 dom_node')
}

// Translated from Libraries/LibWeb/Layout/ListItemBox.h:25
// Original signature: ListItemBox::ListItemMarkerBox const* marker() const
pub fn list_item_box_h_25_marker() LayoutStub {
	return layout_stub('ListItemBox.h:25 marker')
}

// Translated from Libraries/LibWeb/Layout/ListItemBox.h:26
// Original signature: ListItemBox::void set_marker(GC::Ptr<ListItemMarkerBox>);
pub fn list_item_box_h_26_set_marker() LayoutStub {
	return layout_stub('ListItemBox.h:26 set_marker')
}

// Translated from Libraries/LibWeb/Layout/ListItemBox.h:29
// Original signature: ListItemBox::virtual bool is_list_item_box() const
pub fn list_item_box_h_29_is_list_item_box() LayoutStub {
	return layout_stub('ListItemBox.h:29 is_list_item_box')
}

// Translated from Libraries/LibWeb/Layout/ListItemBox.h:31
// Original signature: ListItemBox::virtual void visit_edges(Cell::Visitor&);
pub fn list_item_box_h_31_visit_edges() LayoutStub {
	return layout_stub('ListItemBox.h:31 visit_edges')
}

// Translated from Libraries/LibWeb/Layout/ListItemBox.h:37
// Original signature: inline bool Node::fast_is<ListItemBox>() const
pub fn list_item_box_h_37_function() LayoutStub {
	return layout_stub('ListItemBox.h:37 function')
}

// ---- ListItemBox.cpp (4 translated function stubs) ----

// Translated from Libraries/LibWeb/Layout/ListItemBox.cpp:15
// Original signature: ListItemBox::ListItemBox(DOM::Document& document, DOM::Element* element, GC::Ref<CSS::ComputedProperties> style) : Layout::BlockContainer(document, element, move(style))
pub fn list_item_box_cpp_15_list_item_box_list_item_box() LayoutStub {
	return layout_stub('ListItemBox.cpp:15 ListItemBox::ListItemBox')
}

// Translated from Libraries/LibWeb/Layout/ListItemBox.cpp:20
// Original signature: ListItemBox::~ListItemBox() = default;
pub fn list_item_box_cpp_20_list_item_box_destroy_list_item_box() LayoutStub {
	return layout_stub('ListItemBox.cpp:20 ListItemBox::~ListItemBox')
}

// Translated from Libraries/LibWeb/Layout/ListItemBox.cpp:22
// Original signature: void ListItemBox::visit_edges(Cell::Visitor& visitor)
pub fn list_item_box_cpp_22_list_item_box_visit_edges() LayoutStub {
	return layout_stub('ListItemBox.cpp:22 ListItemBox::visit_edges')
}

// Translated from Libraries/LibWeb/Layout/ListItemBox.cpp:28
// Original signature: void ListItemBox::set_marker(GC::Ptr<ListItemMarkerBox> marker)
pub fn list_item_box_cpp_28_list_item_box_set_marker() LayoutStub {
	return layout_stub('ListItemBox.cpp:28 ListItemBox::set_marker')
}

// ---- ListItemMarkerBox.h (13 translated function stubs) ----

// Translated from Libraries/LibWeb/Layout/ListItemMarkerBox.h:17
// Original signature: ListItemMarkerBox::GC_DECLARE_ALLOCATOR(ListItemMarkerBox);
pub fn list_item_marker_box_h_17_list_item_marker_box_gc_declare_allocator() LayoutStub {
	return layout_stub('ListItemMarkerBox.h:17 ListItemMarkerBox::GC_DECLARE_ALLOCATOR')
}

// Translated from Libraries/LibWeb/Layout/ListItemMarkerBox.h:20
// Original signature: ListItemMarkerBox::static bool counter_style_is_rendered_with_custom_image(RefPtr<CSS::CounterStyle const> const& counter_style);
pub fn list_item_marker_box_h_20_counter_style_is_rendered_with_custom_image() LayoutStub {
	return layout_stub('ListItemMarkerBox.h:20 counter_style_is_rendered_with_custom_image')
}

// Translated from Libraries/LibWeb/Layout/ListItemMarkerBox.h:22
// Original signature: ListItemMarkerBox::explicit ListItemMarkerBox(DOM::Document&, CSS::ListStyleType, CSS::ListStylePosition, GC::Ref<DOM::Element>, GC::Ref<CSS::ComputedProperties>);
pub fn list_item_marker_box_h_22_list_item_marker_box() LayoutStub {
	return layout_stub('ListItemMarkerBox.h:22 ListItemMarkerBox')
}

// Translated from Libraries/LibWeb/Layout/ListItemMarkerBox.h:23
// Original signature: ListItemMarkerBox::virtual ~ListItemMarkerBox();
pub fn list_item_marker_box_h_23_destroy_list_item_marker_box() LayoutStub {
	return layout_stub('ListItemMarkerBox.h:23 ~ListItemMarkerBox')
}

// Translated from Libraries/LibWeb/Layout/ListItemMarkerBox.h:25
// Original signature: ListItemMarkerBox::Optional<String> text() const;
pub fn list_item_marker_box_h_25_text() LayoutStub {
	return layout_stub('ListItemMarkerBox.h:25 text')
}

// Translated from Libraries/LibWeb/Layout/ListItemMarkerBox.h:27
// Original signature: ListItemMarkerBox::virtual GC::Ptr<Painting::Paintable> create_paintable() const;
pub fn list_item_marker_box_h_27_create_paintable() LayoutStub {
	return layout_stub('ListItemMarkerBox.h:27 create_paintable')
}

// Translated from Libraries/LibWeb/Layout/ListItemMarkerBox.h:29
// Original signature: ListItemMarkerBox::CSS::ListStyleType const& list_style_type() const
pub fn list_item_marker_box_h_29_list_style_type() LayoutStub {
	return layout_stub('ListItemMarkerBox.h:29 list_style_type')
}

// Translated from Libraries/LibWeb/Layout/ListItemMarkerBox.h:30
// Original signature: ListItemMarkerBox::CSS::ListStylePosition list_style_position() const
pub fn list_item_marker_box_h_30_list_style_position() LayoutStub {
	return layout_stub('ListItemMarkerBox.h:30 list_style_position')
}

// Translated from Libraries/LibWeb/Layout/ListItemMarkerBox.h:32
// Original signature: ListItemMarkerBox::CSSPixels relative_size() const;
pub fn list_item_marker_box_h_32_relative_size() LayoutStub {
	return layout_stub('ListItemMarkerBox.h:32 relative_size')
}

// Translated from Libraries/LibWeb/Layout/ListItemMarkerBox.h:35
// Original signature: ListItemMarkerBox::virtual void visit_edges(Cell::Visitor&);
pub fn list_item_marker_box_h_35_visit_edges() LayoutStub {
	return layout_stub('ListItemMarkerBox.h:35 visit_edges')
}

// Translated from Libraries/LibWeb/Layout/ListItemMarkerBox.h:37
// Original signature: ListItemMarkerBox::virtual bool is_list_item_marker_box() const
pub fn list_item_marker_box_h_37_is_list_item_marker_box() LayoutStub {
	return layout_stub('ListItemMarkerBox.h:37 is_list_item_marker_box')
}

// Translated from Libraries/LibWeb/Layout/ListItemMarkerBox.h:38
// Original signature: ListItemMarkerBox::virtual bool can_have_children() const
pub fn list_item_marker_box_h_38_can_have_children() LayoutStub {
	return layout_stub('ListItemMarkerBox.h:38 can_have_children')
}

// Translated from Libraries/LibWeb/Layout/ListItemMarkerBox.h:46
// Original signature: inline bool Node::fast_is<ListItemMarkerBox>() const
pub fn list_item_marker_box_h_46_function() LayoutStub {
	return layout_stub('ListItemMarkerBox.h:46 function')
}

// ---- ListItemMarkerBox.cpp (7 translated function stubs) ----

// Translated from Libraries/LibWeb/Layout/ListItemMarkerBox.cpp:17
// Original signature: ListItemMarkerBox::ListItemMarkerBox(DOM::Document& document, CSS::ListStyleType style_type, CSS::ListStylePosition style_position, GC::Ref<DOM::Element> list_item_element, GC::Ref<CSS::ComputedProperties> style) : Box(document, nullptr, move(style)) , m_list_style_type(style_type) , m_list_style_position(style_position) , m_list_item_element(list_item_element)
pub fn list_item_marker_box_cpp_17_list_item_marker_box_list_item_marker_box() LayoutStub {
	return layout_stub('ListItemMarkerBox.cpp:17 ListItemMarkerBox::ListItemMarkerBox')
}

// Translated from Libraries/LibWeb/Layout/ListItemMarkerBox.cpp:25
// Original signature: ListItemMarkerBox::~ListItemMarkerBox() = default;
pub fn list_item_marker_box_cpp_25_list_item_marker_box_destroy_list_item_marker_box() LayoutStub {
	return layout_stub('ListItemMarkerBox.cpp:25 ListItemMarkerBox::~ListItemMarkerBox')
}

// Translated from Libraries/LibWeb/Layout/ListItemMarkerBox.cpp:27
// Original signature: bool ListItemMarkerBox::counter_style_is_rendered_with_custom_image(RefPtr<CSS::CounterStyle const> const& counter_style)
// https://drafts.csswg.org/css-counter-styles-3/#simple-symbolic
// When used in list-style-type, a UA may instead render these styles using a UA-generated image or a UA-chosen
// font
// instead of rendering the specified character in the element's own font. If using an image, it must look
// similar
// to the character, and must be sized to attractively fill a 1em by 1em square.
pub fn list_item_marker_box_cpp_27_list_item_marker_box_counter_style_is_rendered_with_custom_image() LayoutStub {
	return layout_stub('ListItemMarkerBox.cpp:27 ListItemMarkerBox::counter_style_is_rendered_with_custom_image')
}

// Translated from Libraries/LibWeb/Layout/ListItemMarkerBox.cpp:42
// Original signature: Optional<String> ListItemMarkerBox::text() const
// https://drafts.csswg.org/css-lists-3/#text-markers
// none
// The element has no marker string.
// <counter-style>
// Specifies the element's marker string as the value of the list-item counter represented using the
// specified <counter-style>. Specifically, the marker string is the result of generating a counter
// representation of the list-item counter value using the specified <counter-style>, prefixed by the prefix
// of the <counter-style>, and followed by the suffix of the <counter-style>. If the specified
// <counter-style> does not exist, decimal is assumed.
// NB: Fallback to decimal if the counter style does not exist is handled within
// generate_a_counter_representation()
// <string>
// The element's marker string is the specified <string>.
pub fn list_item_marker_box_cpp_42_list_item_marker_box_text() LayoutStub {
	return layout_stub('ListItemMarkerBox.cpp:42 ListItemMarkerBox::text')
}

// Translated from Libraries/LibWeb/Layout/ListItemMarkerBox.cpp:78
// Original signature: GC::Ptr<Painting::Paintable> ListItemMarkerBox::create_paintable() const
pub fn list_item_marker_box_cpp_78_list_item_marker_box_create_paintable() LayoutStub {
	return layout_stub('ListItemMarkerBox.cpp:78 ListItemMarkerBox::create_paintable')
}

// Translated from Libraries/LibWeb/Layout/ListItemMarkerBox.cpp:83
// Original signature: CSSPixels ListItemMarkerBox::relative_size() const
// https://drafts.csswg.org/css-counter-styles-3/#simple-symbolic
// NB: The spec allows us to render some predefined symbol counter styles using a UA-generated image instead of
// text, it instructs us to size these in order to attractively fit within a 1em x 1em square. We mimic Firefox
// and generally use a size of 0.35em, except for disclosure open/closed styles which use a size of 0.5em.
pub fn list_item_marker_box_cpp_83_list_item_marker_box_relative_size() LayoutStub {
	return layout_stub('ListItemMarkerBox.cpp:83 ListItemMarkerBox::relative_size')
}

// Translated from Libraries/LibWeb/Layout/ListItemMarkerBox.cpp:112
// Original signature: void ListItemMarkerBox::visit_edges(Cell::Visitor& visitor)
pub fn list_item_marker_box_cpp_112_list_item_marker_box_visit_edges() LayoutStub {
	return layout_stub('ListItemMarkerBox.cpp:112 ListItemMarkerBox::visit_edges')
}

// ---- TableWrapper.h (6 translated function stubs) ----

// Translated from Libraries/LibWeb/Layout/TableWrapper.h:15
// Original signature: TableWrapper::GC_DECLARE_ALLOCATOR(TableWrapper);
pub fn table_wrapper_h_15_table_wrapper_gc_declare_allocator() LayoutStub {
	return layout_stub('TableWrapper.h:15 TableWrapper::GC_DECLARE_ALLOCATOR')
}

// Translated from Libraries/LibWeb/Layout/TableWrapper.h:18
// Original signature: TableWrapper::TableWrapper(DOM::Document&, DOM::Node*, GC::Ref<CSS::ComputedProperties>);
pub fn table_wrapper_h_18_table_wrapper_table_wrapper() LayoutStub {
	return layout_stub('TableWrapper.h:18 TableWrapper::TableWrapper')
}

// Translated from Libraries/LibWeb/Layout/TableWrapper.h:19
// Original signature: TableWrapper::TableWrapper(DOM::Document&, DOM::Node*, NonnullOwnPtr<CSS::ComputedValues>);
pub fn table_wrapper_h_19_table_wrapper_table_wrapper() LayoutStub {
	return layout_stub('TableWrapper.h:19 TableWrapper::TableWrapper')
}

// Translated from Libraries/LibWeb/Layout/TableWrapper.h:20
// Original signature: TableWrapper::virtual ~TableWrapper();
pub fn table_wrapper_h_20_destroy_table_wrapper() LayoutStub {
	return layout_stub('TableWrapper.h:20 ~TableWrapper')
}

// Translated from Libraries/LibWeb/Layout/TableWrapper.h:23
// Original signature: TableWrapper::virtual bool is_table_wrapper() const
pub fn table_wrapper_h_23_is_table_wrapper() LayoutStub {
	return layout_stub('TableWrapper.h:23 is_table_wrapper')
}

// Translated from Libraries/LibWeb/Layout/TableWrapper.h:27
// Original signature: inline bool Node::fast_is<TableWrapper>() const
pub fn table_wrapper_h_27_function() LayoutStub {
	return layout_stub('TableWrapper.h:27 function')
}

// ---- TableWrapper.cpp (3 translated function stubs) ----

// Translated from Libraries/LibWeb/Layout/TableWrapper.cpp:13
// Original signature: TableWrapper::TableWrapper(DOM::Document& document, DOM::Node* node, GC::Ref<CSS::ComputedProperties> style) : BlockContainer(document, node, move(style))
pub fn table_wrapper_cpp_13_table_wrapper_table_wrapper() LayoutStub {
	return layout_stub('TableWrapper.cpp:13 TableWrapper::TableWrapper')
}

// Translated from Libraries/LibWeb/Layout/TableWrapper.cpp:18
// Original signature: TableWrapper::TableWrapper(DOM::Document& document, DOM::Node* node, NonnullOwnPtr<CSS::ComputedValues> computed_values) : BlockContainer(document, node, move(computed_values))
pub fn table_wrapper_cpp_18_table_wrapper_table_wrapper() LayoutStub {
	return layout_stub('TableWrapper.cpp:18 TableWrapper::TableWrapper')
}

// Translated from Libraries/LibWeb/Layout/TableWrapper.cpp:23
// Original signature: TableWrapper::~TableWrapper() = default;
pub fn table_wrapper_cpp_23_table_wrapper_destroy_table_wrapper() LayoutStub {
	return layout_stub('TableWrapper.cpp:23 TableWrapper::~TableWrapper')
}

// ---- Viewport.h (11 translated function stubs) ----

// Translated from Libraries/LibWeb/Layout/Viewport.h:16
// Original signature: Viewport::GC_DECLARE_ALLOCATOR(Viewport);
pub fn viewport_h_16_viewport_gc_declare_allocator() LayoutStub {
	return layout_stub('Viewport.h:16 Viewport::GC_DECLARE_ALLOCATOR')
}

// Translated from Libraries/LibWeb/Layout/Viewport.h:19
// Original signature: Viewport::explicit Viewport(DOM::Document&, GC::Ref<CSS::ComputedProperties>);
pub fn viewport_h_19_viewport() LayoutStub {
	return layout_stub('Viewport.h:19 Viewport')
}

// Translated from Libraries/LibWeb/Layout/Viewport.h:20
// Original signature: Viewport::virtual ~Viewport();
pub fn viewport_h_20_destroy_viewport() LayoutStub {
	return layout_stub('Viewport.h:20 ~Viewport')
}

// Translated from Libraries/LibWeb/Layout/Viewport.h:30
// Original signature: Viewport::Vector<TextBlock> const& text_blocks();
pub fn viewport_h_30_text_blocks() LayoutStub {
	return layout_stub('Viewport.h:30 text_blocks')
}

// Translated from Libraries/LibWeb/Layout/Viewport.h:31
// Original signature: Viewport::void invalidate_text_blocks_cache()
pub fn viewport_h_31_invalidate_text_blocks_cache() LayoutStub {
	return layout_stub('Viewport.h:31 invalidate_text_blocks_cache')
}

// Translated from Libraries/LibWeb/Layout/Viewport.h:33
// Original signature: Viewport::DOM::Document const& dom_node() const;
pub fn viewport_h_33_dom_node() LayoutStub {
	return layout_stub('Viewport.h:33 dom_node')
}

// Translated from Libraries/LibWeb/Layout/Viewport.h:35
// Original signature: Viewport::virtual void visit_edges(Visitor&);
pub fn viewport_h_35_visit_edges() LayoutStub {
	return layout_stub('Viewport.h:35 visit_edges')
}

// Translated from Libraries/LibWeb/Layout/Viewport.h:38
// Original signature: Viewport::virtual GC::Ptr<Painting::Paintable> create_paintable() const;
pub fn viewport_h_38_create_paintable() LayoutStub {
	return layout_stub('Viewport.h:38 create_paintable')
}

// Translated from Libraries/LibWeb/Layout/Viewport.h:40
// Original signature: Viewport::void update_text_blocks();
pub fn viewport_h_40_update_text_blocks() LayoutStub {
	return layout_stub('Viewport.h:40 update_text_blocks')
}

// Translated from Libraries/LibWeb/Layout/Viewport.h:42
// Original signature: Viewport::virtual bool is_viewport() const
pub fn viewport_h_42_is_viewport() LayoutStub {
	return layout_stub('Viewport.h:42 is_viewport')
}

// Translated from Libraries/LibWeb/Layout/Viewport.h:48
// Original signature: inline bool Node::fast_is<Viewport>() const
pub fn viewport_h_48_function() LayoutStub {
	return layout_stub('Viewport.h:48 function')
}

// ---- Viewport.cpp (7 translated function stubs) ----

// Translated from Libraries/LibWeb/Layout/Viewport.cpp:20
// Original signature: Viewport::Viewport(DOM::Document& document, GC::Ref<CSS::ComputedProperties> style) : BlockContainer(document, &document, move(style))
pub fn viewport_cpp_20_viewport_viewport() LayoutStub {
	return layout_stub('Viewport.cpp:20 Viewport::Viewport')
}

// Translated from Libraries/LibWeb/Layout/Viewport.cpp:25
// Original signature: Viewport::~Viewport() = default;
pub fn viewport_cpp_25_viewport_destroy_viewport() LayoutStub {
	return layout_stub('Viewport.cpp:25 Viewport::~Viewport')
}

// Translated from Libraries/LibWeb/Layout/Viewport.cpp:27
// Original signature: DOM::Document const& Viewport::dom_node() const
pub fn viewport_cpp_27_viewport_dom_node() LayoutStub {
	return layout_stub('Viewport.cpp:27 Viewport::dom_node')
}

// Translated from Libraries/LibWeb/Layout/Viewport.cpp:32
// Original signature: GC::Ptr<Painting::Paintable> Viewport::create_paintable() const
pub fn viewport_cpp_32_viewport_create_paintable() LayoutStub {
	return layout_stub('Viewport.cpp:32 Viewport::create_paintable')
}

// Translated from Libraries/LibWeb/Layout/Viewport.cpp:37
// Original signature: void Viewport::visit_edges(Visitor& visitor)
pub fn viewport_cpp_37_viewport_visit_edges() LayoutStub {
	return layout_stub('Viewport.cpp:37 Viewport::visit_edges')
}

// Translated from Libraries/LibWeb/Layout/Viewport.cpp:49
// Original signature: Vector<Viewport::TextBlock> const& Viewport::text_blocks()
pub fn viewport_cpp_49_viewport_text_blocks() LayoutStub {
	return layout_stub('Viewport.cpp:49 Viewport::text_blocks')
}

// Translated from Libraries/LibWeb/Layout/Viewport.cpp:57
// Original signature: void Viewport::update_text_blocks()
// https://html.spec.whatwg.org/multipage/interaction.html#inert-subtrees
// When a node is inert:
// - The user agent should ignore the node for the purposes of find-in-page.
pub fn viewport_cpp_57_viewport_update_text_blocks() LayoutStub {
	return layout_stub('Viewport.cpp:57 Viewport::update_text_blocks')
}

// ---- BreakNode.h (7 translated function stubs) ----

// Translated from Libraries/LibWeb/Layout/BreakNode.h:16
// Original signature: BreakNode::GC_DECLARE_ALLOCATOR(BreakNode);
pub fn break_node_h_16_break_node_gc_declare_allocator() LayoutStub {
	return layout_stub('BreakNode.h:16 BreakNode::GC_DECLARE_ALLOCATOR')
}

// Translated from Libraries/LibWeb/Layout/BreakNode.h:19
// Original signature: BreakNode::BreakNode(DOM::Document&, HTML::HTMLBRElement&, GC::Ref<CSS::ComputedProperties>);
pub fn break_node_h_19_break_node_break_node() LayoutStub {
	return layout_stub('BreakNode.h:19 BreakNode::BreakNode')
}

// Translated from Libraries/LibWeb/Layout/BreakNode.h:20
// Original signature: BreakNode::virtual ~BreakNode();
pub fn break_node_h_20_destroy_break_node() LayoutStub {
	return layout_stub('BreakNode.h:20 ~BreakNode')
}

// Translated from Libraries/LibWeb/Layout/BreakNode.h:22
// Original signature: BreakNode::HTML::HTMLBRElement const& dom_node() const
pub fn break_node_h_22_dom_node() LayoutStub {
	return layout_stub('BreakNode.h:22 dom_node')
}

// Translated from Libraries/LibWeb/Layout/BreakNode.h:25
// Original signature: BreakNode::virtual bool is_break_node() const
pub fn break_node_h_25_is_break_node() LayoutStub {
	return layout_stub('BreakNode.h:25 is_break_node')
}

// Translated from Libraries/LibWeb/Layout/BreakNode.h:26
// Original signature: BreakNode::virtual bool can_have_children() const
pub fn break_node_h_26_can_have_children() LayoutStub {
	return layout_stub('BreakNode.h:26 can_have_children')
}

// Translated from Libraries/LibWeb/Layout/BreakNode.h:30
// Original signature: inline bool Node::fast_is<BreakNode>() const
pub fn break_node_h_30_function() LayoutStub {
	return layout_stub('BreakNode.h:30 function')
}

// ---- BreakNode.cpp (2 translated function stubs) ----

// Translated from Libraries/LibWeb/Layout/BreakNode.cpp:15
// Original signature: BreakNode::BreakNode(DOM::Document& document, HTML::HTMLBRElement& element, GC::Ref<CSS::ComputedProperties> style) : Layout::NodeWithStyleAndBoxModelMetrics(document, &element, move(style))
pub fn break_node_cpp_15_break_node_break_node() LayoutStub {
	return layout_stub('BreakNode.cpp:15 BreakNode::BreakNode')
}

// Translated from Libraries/LibWeb/Layout/BreakNode.cpp:20
// Original signature: BreakNode::~BreakNode() = default;
pub fn break_node_cpp_20_break_node_destroy_break_node() LayoutStub {
	return layout_stub('BreakNode.cpp:20 BreakNode::~BreakNode')
}

// ---- InlineNode.h (6 translated function stubs) ----

// Translated from Libraries/LibWeb/Layout/InlineNode.h:15
// Original signature: InlineNode::GC_DECLARE_ALLOCATOR(InlineNode);
pub fn inline_node_h_15_inline_node_gc_declare_allocator() LayoutStub {
	return layout_stub('InlineNode.h:15 InlineNode::GC_DECLARE_ALLOCATOR')
}

// Translated from Libraries/LibWeb/Layout/InlineNode.h:18
// Original signature: InlineNode::InlineNode(DOM::Document&, DOM::Element*, GC::Ref<CSS::ComputedProperties>);
pub fn inline_node_h_18_inline_node_inline_node() LayoutStub {
	return layout_stub('InlineNode.h:18 InlineNode::InlineNode')
}

// Translated from Libraries/LibWeb/Layout/InlineNode.h:19
// Original signature: InlineNode::virtual ~InlineNode();
pub fn inline_node_h_19_destroy_inline_node() LayoutStub {
	return layout_stub('InlineNode.h:19 ~InlineNode')
}

// Translated from Libraries/LibWeb/Layout/InlineNode.h:21
// Original signature: InlineNode::GC::Ptr<Painting::PaintableWithLines> create_paintable_for_line_with_index(size_t line_index) const;
pub fn inline_node_h_21_create_paintable_for_line_with_index() LayoutStub {
	return layout_stub('InlineNode.h:21 create_paintable_for_line_with_index')
}

// Translated from Libraries/LibWeb/Layout/InlineNode.h:24
// Original signature: InlineNode::virtual bool is_inline_node() const
pub fn inline_node_h_24_is_inline_node() LayoutStub {
	return layout_stub('InlineNode.h:24 is_inline_node')
}

// Translated from Libraries/LibWeb/Layout/InlineNode.h:28
// Original signature: inline bool Node::fast_is<InlineNode>() const
pub fn inline_node_h_28_function() LayoutStub {
	return layout_stub('InlineNode.h:28 function')
}

// ---- InlineNode.cpp (3 translated function stubs) ----

// Translated from Libraries/LibWeb/Layout/InlineNode.cpp:19
// Original signature: InlineNode::InlineNode(DOM::Document& document, DOM::Element* element, GC::Ref<CSS::ComputedProperties> style) : Layout::NodeWithStyleAndBoxModelMetrics(document, element, move(style))
pub fn inline_node_cpp_19_inline_node_inline_node() LayoutStub {
	return layout_stub('InlineNode.cpp:19 InlineNode::InlineNode')
}

// Translated from Libraries/LibWeb/Layout/InlineNode.cpp:24
// Original signature: InlineNode::~InlineNode() = default;
pub fn inline_node_cpp_24_inline_node_destroy_inline_node() LayoutStub {
	return layout_stub('InlineNode.cpp:24 InlineNode::~InlineNode')
}

// Translated from Libraries/LibWeb/Layout/InlineNode.cpp:26
// Original signature: GC::Ptr<Painting::PaintableWithLines> InlineNode::create_paintable_for_line_with_index(size_t line_index) const
pub fn inline_node_cpp_26_inline_node_create_paintable_for_line_with_index() LayoutStub {
	return layout_stub('InlineNode.cpp:26 InlineNode::create_paintable_for_line_with_index')
}

// ---- TextAreaBox.h (7 translated function stubs) ----

// Translated from Libraries/LibWeb/Layout/TextAreaBox.h:16
// Original signature: TextAreaBox::GC_DECLARE_ALLOCATOR(TextAreaBox);
pub fn text_area_box_h_16_text_area_box_gc_declare_allocator() LayoutStub {
	return layout_stub('TextAreaBox.h:16 TextAreaBox::GC_DECLARE_ALLOCATOR')
}

// Translated from Libraries/LibWeb/Layout/TextAreaBox.h:19
// Original signature: TextAreaBox::TextAreaBox(DOM::Document&, GC::Ptr<DOM::Element>, GC::Ref<CSS::ComputedProperties>);
pub fn text_area_box_h_19_text_area_box_text_area_box() LayoutStub {
	return layout_stub('TextAreaBox.h:19 TextAreaBox::TextAreaBox')
}

// Translated from Libraries/LibWeb/Layout/TextAreaBox.h:21
// Original signature: TextAreaBox::HTML::HTMLTextAreaElement const& dom_node() const
pub fn text_area_box_h_21_dom_node() LayoutStub {
	return layout_stub('TextAreaBox.h:21 dom_node')
}

// Translated from Libraries/LibWeb/Layout/TextAreaBox.h:23
// Original signature: TextAreaBox::virtual ~TextAreaBox() = default;
pub fn text_area_box_h_23_destroy_text_area_box() LayoutStub {
	return layout_stub('TextAreaBox.h:23 ~TextAreaBox')
}

// Translated from Libraries/LibWeb/Layout/TextAreaBox.h:26
// Original signature: TextAreaBox::virtual CSS::SizeWithAspectRatio compute_auto_content_box_size() const;
pub fn text_area_box_h_26_compute_auto_content_box_size() LayoutStub {
	return layout_stub('TextAreaBox.h:26 compute_auto_content_box_size')
}

// Translated from Libraries/LibWeb/Layout/TextAreaBox.h:27
// Original signature: TextAreaBox::virtual bool has_auto_content_box_size() const
pub fn text_area_box_h_27_has_auto_content_box_size() LayoutStub {
	return layout_stub('TextAreaBox.h:27 has_auto_content_box_size')
}

// Translated from Libraries/LibWeb/Layout/TextAreaBox.h:28
// Original signature: TextAreaBox::virtual bool is_textarea_box() const
pub fn text_area_box_h_28_is_textarea_box() LayoutStub {
	return layout_stub('TextAreaBox.h:28 is_textarea_box')
}

// ---- TextAreaBox.cpp (2 translated function stubs) ----

// Translated from Libraries/LibWeb/Layout/TextAreaBox.cpp:13
// Original signature: TextAreaBox::TextAreaBox(DOM::Document& document, GC::Ptr<DOM::Element> element, GC::Ref<CSS::ComputedProperties> style) : BlockContainer(document, element, move(style))
pub fn text_area_box_cpp_13_text_area_box_text_area_box() LayoutStub {
	return layout_stub('TextAreaBox.cpp:13 TextAreaBox::TextAreaBox')
}

// Translated from Libraries/LibWeb/Layout/TextAreaBox.cpp:18
// Original signature: CSS::SizeWithAspectRatio TextAreaBox::compute_auto_content_box_size() const
pub fn text_area_box_cpp_18_text_area_box_compute_auto_content_box_size() LayoutStub {
	return layout_stub('TextAreaBox.cpp:18 TextAreaBox::compute_auto_content_box_size')
}

// ---- TextInputBox.h (6 translated function stubs) ----

// Translated from Libraries/LibWeb/Layout/TextInputBox.h:16
// Original signature: TextInputBox::GC_DECLARE_ALLOCATOR(TextInputBox);
pub fn text_input_box_h_16_text_input_box_gc_declare_allocator() LayoutStub {
	return layout_stub('TextInputBox.h:16 TextInputBox::GC_DECLARE_ALLOCATOR')
}

// Translated from Libraries/LibWeb/Layout/TextInputBox.h:19
// Original signature: TextInputBox::TextInputBox(DOM::Document&, GC::Ptr<DOM::Element>, GC::Ref<CSS::ComputedProperties>);
pub fn text_input_box_h_19_text_input_box_text_input_box() LayoutStub {
	return layout_stub('TextInputBox.h:19 TextInputBox::TextInputBox')
}

// Translated from Libraries/LibWeb/Layout/TextInputBox.h:21
// Original signature: TextInputBox::HTML::HTMLInputElement const& dom_node() const
pub fn text_input_box_h_21_dom_node() LayoutStub {
	return layout_stub('TextInputBox.h:21 dom_node')
}

// Translated from Libraries/LibWeb/Layout/TextInputBox.h:23
// Original signature: TextInputBox::virtual ~TextInputBox() = default;
pub fn text_input_box_h_23_destroy_text_input_box() LayoutStub {
	return layout_stub('TextInputBox.h:23 ~TextInputBox')
}

// Translated from Libraries/LibWeb/Layout/TextInputBox.h:26
// Original signature: TextInputBox::virtual CSS::SizeWithAspectRatio compute_auto_content_box_size() const;
pub fn text_input_box_h_26_compute_auto_content_box_size() LayoutStub {
	return layout_stub('TextInputBox.h:26 compute_auto_content_box_size')
}

// Translated from Libraries/LibWeb/Layout/TextInputBox.h:27
// Original signature: TextInputBox::virtual bool has_auto_content_box_size() const
pub fn text_input_box_h_27_has_auto_content_box_size() LayoutStub {
	return layout_stub('TextInputBox.h:27 has_auto_content_box_size')
}

// ---- TextInputBox.cpp (2 translated function stubs) ----

// Translated from Libraries/LibWeb/Layout/TextInputBox.cpp:13
// Original signature: TextInputBox::TextInputBox(DOM::Document& document, GC::Ptr<DOM::Element> element, GC::Ref<CSS::ComputedProperties> style) : BlockContainer(document, element, move(style))
pub fn text_input_box_cpp_13_text_input_box_text_input_box() LayoutStub {
	return layout_stub('TextInputBox.cpp:13 TextInputBox::TextInputBox')
}

// Translated from Libraries/LibWeb/Layout/TextInputBox.cpp:18
// Original signature: CSS::SizeWithAspectRatio TextInputBox::compute_auto_content_box_size() const
// AD-HOC: 2px is inline shadow DOM padding in HTMLInputElement::create_text_input_shadow_tree()
pub fn text_input_box_cpp_18_text_input_box_compute_auto_content_box_size() LayoutStub {
	return layout_stub('TextInputBox.cpp:18 TextInputBox::compute_auto_content_box_size')
}
