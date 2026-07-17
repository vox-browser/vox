// Copyright (c) 2018-2026, Ladybird contributors
//
// SPDX-License-Identifier: BSD-2-Clause
//
// Translated from Libraries/LibWeb/Layout/*.
// This module is an incremental V port. Functions whose dependencies have not
// been ported yet keep their source signature and comments and return neutral
// stub values so the rest of libweb_v can compile against Layout.

module layout

import css
import dom

pub const translated_layout_source_file_count = 101
pub const translated_layout_function_count = 1698

pub type CSSPixels = css.CSSPixels
pub type CSSPixelPoint = css.CSSPixelPoint
pub type CSSPixelRect = css.CSSPixelRect
pub type CSSPixelSize = css.CSSPixelSize
pub type CSSPixelFraction = css.CSSPixelFraction

pub struct LayoutStub {
pub mut:
	source string
}

pub fn layout_stub(source string) LayoutStub {
	return LayoutStub{
		source: source
	}
}

pub enum LayoutMode {
	normal
	intrinsic_sizing
}

pub enum AvailableSizeType {
	definite
	indefinite
	min_content
	max_content
}

pub struct AvailableSize {
pub mut:
	type_ AvailableSizeType
	value css.CSSPixels
}

pub fn AvailableSize.make_definite(value css.CSSPixels) AvailableSize {
	return AvailableSize{
		type_: .definite
		value: value
	}
}

pub fn AvailableSize.make_indefinite() AvailableSize {
	return AvailableSize{
		type_: .indefinite
	}
}

pub fn AvailableSize.make_min_content() AvailableSize {
	return AvailableSize{
		type_: .min_content
	}
}

pub fn AvailableSize.make_max_content() AvailableSize {
	return AvailableSize{
		type_: .max_content
	}
}

pub fn (s AvailableSize) is_definite() bool {
	return s.type_ == .definite
}

pub fn (s AvailableSize) is_indefinite() bool {
	return s.type_ == .indefinite
}

pub fn (s AvailableSize) is_min_content() bool {
	return s.type_ == .min_content
}

pub fn (s AvailableSize) is_max_content() bool {
	return s.type_ == .max_content
}

pub fn (s AvailableSize) is_intrinsic_sizing_constraint() bool {
	return s.type_ in [.min_content, .max_content]
}

pub fn (s AvailableSize) to_px_or_zero() css.CSSPixels {
	if !s.is_definite() {
		return css.CSSPixels.new(0)
	}
	return s.value
}

pub fn (s AvailableSize) to_string() string {
	return match s.type_ {
		.definite { '${s.value.to_double():.2f}px' }
		.indefinite { 'indefinite' }
		.min_content { 'min-content' }
		.max_content { 'max-content' }
	}
}

// Comparisons between a CSSPixels length and an AvailableSize, mirroring the free operators in
// Layout/AvailableSpace.h (min-content acts as the smallest possible size, max-content/indefinite as
// the largest).

// Is `px` less than this available size? (C++ operator<(CSSPixels, AvailableSize))
pub fn (s AvailableSize) px_is_less(px css.CSSPixels) bool {
	if s.is_max_content() || s.is_indefinite() {
		return true
	}
	if s.is_min_content() {
		return false
	}
	return px.raw_value() < s.to_px_or_zero().raw_value()
}

// Is `px` greater than this available size? (C++ operator>(CSSPixels, AvailableSize))
pub fn (s AvailableSize) px_is_greater(px css.CSSPixels) bool {
	if s.is_max_content() || s.is_indefinite() {
		return false
	}
	if s.is_min_content() {
		return true
	}
	return px.raw_value() > s.to_px_or_zero().raw_value()
}

// Is this available size less than `px`? (C++ operator<(AvailableSize, CSSPixels))
pub fn (s AvailableSize) is_less_than_px(px css.CSSPixels) bool {
	if s.is_min_content() {
		return true
	}
	if s.is_max_content() || s.is_indefinite() {
		return false
	}
	return s.to_px_or_zero().raw_value() < px.raw_value()
}

pub struct AvailableSpace {
pub mut:
	width  AvailableSize
	height AvailableSize
}

pub fn AvailableSpace.new(width AvailableSize, height AvailableSize) AvailableSpace {
	return AvailableSpace{
		width:  width
		height: height
	}
}

pub fn (s AvailableSpace) to_string() string {
	return 'AvailableSpace(width: ${s.width.to_string()}, height: ${s.height.to_string()})'
}

pub struct SizeWithAspectRatio {
pub mut:
	width        css.CSSPixels
	height       css.CSSPixels
	aspect_ratio ?css.CSSPixelFraction
}

pub struct StaticPositionRect {
pub mut:
	rect css.CSSPixelRect
}

pub enum FormattingContextType {
	block
	inline_
	flex
	grid
	table
	svg
	replaced_with_children
	internal_replaced
	internal_dummy
}

pub fn formatting_context_type_name(type_ FormattingContextType) string {
	return match type_ {
		.block { 'BFC' }
		.inline_ { 'IFC' }
		.flex { 'FFC' }
		.grid { 'GFC' }
		.table { 'TFC' }
		.svg { 'SVG' }
		.replaced_with_children { 'Replaced, with children' }
		.internal_replaced { 'Replaced' }
		.internal_dummy { 'Dummy' }
	}
}

@[heap]
pub struct LayoutNode {
pub mut:
	stub     LayoutStub
	dom_node ?&dom.Node
}

@[heap]
pub struct AbsposAxisMode {
pub mut:
	stub LayoutStub
}

@[heap]
pub struct AbsposContainingBlockInfo {
pub mut:
	stub LayoutStub
}

@[heap]
pub struct Alignment {
pub mut:
	stub LayoutStub
}

@[heap]
pub struct AppendOrPrepend {
pub mut:
	stub LayoutStub
}

@[heap]
pub struct AudioBox {
pub mut:
	stub LayoutStub
}

@[heap]
pub struct AxisAgnosticAvailableSpace {
pub mut:
	stub LayoutStub
}

@[heap]
pub struct Base {
pub mut:
	stub LayoutStub
}

@[heap]
pub struct BaseWidthGetter {
pub mut:
	stub LayoutStub
}

@[heap]
pub struct BeforeOrAfterInsideLayout {
pub mut:
	stub LayoutStub
}

@[heap]
pub struct BlockContainer {
pub mut:
	stub LayoutStub
}

@[heap]
pub struct BlockFormattingContext {
pub mut:
	stub LayoutStub
}

@[heap]
pub struct BlockMarginState {
pub mut:
	stub LayoutStub
}

@[heap]
pub struct BorderConflictFinder {
pub mut:
	stub LayoutStub
}

@[heap]
pub struct Box {
pub mut:
	stub LayoutStub
}

@[heap]
pub struct BreakNode {
pub mut:
	stub LayoutStub
}

@[heap]
pub struct CanvasBox {
pub mut:
	stub LayoutStub
}

@[heap]
pub struct Cell {
pub mut:
	stub LayoutStub
}

@[heap]
pub struct CheckBox {
pub mut:
	stub LayoutStub
}

@[heap]
pub struct Chunk {
pub mut:
	stub LayoutStub
}

@[heap]
pub struct ChunkIterator {
pub mut:
	stub LayoutStub
}

@[heap]
pub struct Column {
pub mut:
	stub LayoutStub
}

@[heap]
pub struct ColumnFilter {
pub mut:
	stub LayoutStub
}

@[heap]
pub struct ConflictingEdge {
pub mut:
	stub LayoutStub
}

@[heap]
pub struct ConflictingSide {
pub mut:
	stub LayoutStub
}

@[heap]
pub struct Context {
pub mut:
	stub LayoutStub
}

@[heap]
pub struct DidIntroduceClearance {
pub mut:
	stub LayoutStub
}

@[heap]
pub struct DirectionAgnosticMargins {
pub mut:
	stub LayoutStub
}

@[heap]
pub struct ExtraBoxMetrics {
pub mut:
	stub LayoutStub
}

@[heap]
pub struct FieldSetBox {
pub mut:
	stub LayoutStub
}

@[heap]
pub struct FlexFormattingContext {
pub mut:
	stub LayoutStub
}

@[heap]
pub struct FlexFormattingContextFlexLine {
pub mut:
	stub LayoutStub
}

@[heap]
pub struct FlexItem {
pub mut:
	stub LayoutStub
}

@[heap]
pub struct FlexLine {
pub mut:
	stub LayoutStub
}

@[heap]
pub struct FloatSide {
pub mut:
	stub LayoutStub
}

@[heap]
pub struct FloatSideData {
pub mut:
	stub LayoutStub
}

@[heap]
pub struct FloatingBox {
pub mut:
	stub LayoutStub
}

@[heap]
pub struct ForcedBreak {
pub mut:
	stub LayoutStub
}

@[heap]
pub struct FormattingContext {
pub mut:
	stub LayoutStub
}

@[heap]
pub struct FormattingContextTracer {
pub mut:
	stub LayoutStub
}

@[heap]
pub struct FoundUnoccupiedPlace {
pub mut:
	stub LayoutStub
}

@[heap]
pub struct GridDimension {
pub mut:
	stub LayoutStub
}

@[heap]
pub struct GridFormattingContext {
pub mut:
	stub LayoutStub
}

@[heap]
pub struct GridFormattingContextGridTrack {
pub mut:
	stub LayoutStub
}

@[heap]
pub struct GridItem {
pub mut:
	stub LayoutStub
}

@[heap]
pub struct GridPosition {
pub mut:
	stub LayoutStub
}

@[heap]
pub struct GridTrack {
pub mut:
	stub LayoutStub
}

@[heap]
pub struct ImageBox {
pub mut:
	stub LayoutStub
}

@[heap]
pub struct ImageProvider {
pub mut:
	stub LayoutStub
}

@[heap]
pub struct InlineFormattingContext {
pub mut:
	stub LayoutStub
}

@[heap]
pub struct InlineLevelIterator {
pub mut:
	stub LayoutStub
}

@[heap]
pub struct InlineNode {
pub mut:
	stub LayoutStub
}

@[heap]
pub struct IntrinsicSizes {
pub mut:
	stub LayoutStub
}

@[heap]
pub struct Item {
pub mut:
	stub LayoutStub
}

@[heap]
pub struct LayoutState {
pub mut:
	stub LayoutStub
}

@[heap]
pub struct LayoutStateUsedValues {
pub mut:
	stub LayoutStub
}

@[heap]
pub struct LegendBox {
pub mut:
	stub LayoutStub
}

@[heap]
pub struct LineBox {
pub mut:
	stub LayoutStub
}

@[heap]
pub struct LineBoxFragment {
pub mut:
	stub LayoutStub
}

@[heap]
pub struct LineBoxFragmentCoordinate {
pub mut:
	stub LayoutStub
}

@[heap]
pub struct LineBuilder {
pub mut:
	stub LayoutStub
}

@[heap]
pub struct ListItemBox {
pub mut:
	stub LayoutStub
}

@[heap]
pub struct ListItemMarkerBox {
pub mut:
	stub LayoutStub
}

@[heap]
pub struct MustCreateSubtree {
pub mut:
	stub LayoutStub
}

@[heap]
pub struct NavigableContainerViewport {
pub mut:
	stub LayoutStub
}

// The real Layout::Node (base of the layout tree) is defined in layout/node.v.

// The real Layout::NodeWithStyle is defined in layout/node.v.

@[heap]
pub struct NodeWithStyleAndBoxModelMetrics {
pub mut:
	stub LayoutStub
}

@[heap]
pub struct OccupationGrid {
pub mut:
	stub LayoutStub
}

@[heap]
pub struct Page {
pub mut:
	stub LayoutStub
}

@[heap]
pub struct PagedStore {
pub mut:
	stub LayoutStub
}

@[heap]
pub struct PlacementPosition {
pub mut:
	stub LayoutStub
}

@[heap]
pub struct RadioButton {
pub mut:
	stub LayoutStub
}

@[heap]
pub struct RemoveTrailingWhitespace {
pub mut:
	stub LayoutStub
}

@[heap]
pub struct ReplacedBox {
pub mut:
	stub LayoutStub
}

@[heap]
pub struct ReplacedWithChildrenFormattingContext {
pub mut:
	stub LayoutStub
}

@[heap]
pub struct Row {
pub mut:
	stub LayoutStub
}

@[heap]
pub struct RowGroupInfo {
pub mut:
	stub LayoutStub
}

@[heap]
pub struct RowOrColumn {
pub mut:
	stub LayoutStub
}

@[heap]
pub struct SVGBox {
pub mut:
	stub LayoutStub
}

@[heap]
pub struct SVGClipBox {
pub mut:
	stub LayoutStub
}

@[heap]
pub struct SVGForeignObjectBox {
pub mut:
	stub LayoutStub
}

@[heap]
pub struct SVGFormattingContext {
pub mut:
	stub LayoutStub
}

@[heap]
pub struct SVGGeometryBox {
pub mut:
	stub LayoutStub
}

@[heap]
pub struct SVGGraphicsBox {
pub mut:
	stub LayoutStub
}

@[heap]
pub struct SVGImageBox {
pub mut:
	stub LayoutStub
}

@[heap]
pub struct SVGMaskBox {
pub mut:
	stub LayoutStub
}

@[heap]
pub struct SVGPatternBox {
pub mut:
	stub LayoutStub
}

@[heap]
pub struct SVGSVGBox {
pub mut:
	stub LayoutStub
}

@[heap]
pub struct SVGTextBox {
pub mut:
	stub LayoutStub
}

@[heap]
pub struct SVGTextPathBox {
pub mut:
	stub LayoutStub
}

@[heap]
pub struct ShrinkToFitResult {
pub mut:
	stub LayoutStub
}

@[heap]
pub struct SizeConstraint {
pub mut:
	stub LayoutStub
}

@[heap]
pub struct SpaceDistributionPhase {
pub mut:
	stub LayoutStub
}

@[heap]
pub struct SpaceUsedAndContainingMarginForFloats {
pub mut:
	stub LayoutStub
}

@[heap]
pub struct SpaceUsedByFloats {
pub mut:
	stub LayoutStub
}

@[heap]
pub struct TableDimension {
pub mut:
	stub LayoutStub
}

@[heap]
pub struct TableFormattingContext {
pub mut:
	stub LayoutStub
}

@[heap]
pub struct TableFormattingContextBorderConflictFinder {
pub mut:
	stub LayoutStub
}

@[heap]
pub struct TableGrid {
pub mut:
	stub LayoutStub
}

@[heap]
pub struct TableWrapper {
pub mut:
	stub LayoutStub
}

@[heap]
pub struct TextAreaBox {
pub mut:
	stub LayoutStub
}

@[heap]
pub struct TextBlock {
pub mut:
	stub LayoutStub
}

@[heap]
pub struct TextInputBox {
pub mut:
	stub LayoutStub
}

@[heap]
pub struct TextNode {
pub mut:
	stub LayoutStub
}

@[heap]
pub struct TextNodeChunkIterator {
pub mut:
	stub LayoutStub
}

@[heap]
pub struct TextNodeContext {
pub mut:
	stub LayoutStub
}

@[heap]
pub struct TextPosition {
pub mut:
	stub LayoutStub
}

@[heap]
pub struct Track {
pub mut:
	stub LayoutStub
}

@[heap]
pub struct TrackSize {
pub mut:
	stub LayoutStub
}

@[heap]
pub struct TrackSizingResult {
pub mut:
	stub LayoutStub
}

@[heap]
pub struct TreeBuilder {
pub mut:
	stub LayoutStub
}

@[heap]
pub struct Type {
pub mut:
	stub LayoutStub
}

@[heap]
pub struct UsedValues {
pub mut:
	stub LayoutStub
}

@[heap]
pub struct VideoBox {
pub mut:
	stub LayoutStub
}

@[heap]
pub struct Viewport {
pub mut:
	stub LayoutStub
}
