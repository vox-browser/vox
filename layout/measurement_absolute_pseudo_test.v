module layout

import css
import dom
import html
import platform

fn absolute_pseudo_probe_expect(value bool) {
	assert value
}

// Self-contained geometry oracle: compare live cache replay with an unpooled
// layout after producer scratch retirement, including static and final abspos.
fn absolute_pseudo_probe_document(kind string, contents string, rules string) &dom.Document {
	mut document := html.parse_document('<!doctype html><main><section id="root" style="display:${kind};position:relative;grid-template-columns:[start] 1fr [middle] 2fr [end];gap:7px;align-items:start;${rules}">${contents}<p>Wrapping alpha beta gamma 😀 á words for retained lines.</p></section></main>')
	document.enable_native_storage()
	mut owner := document.enter_native_storage()
	_ = layout_document_typed_in_viewport(document, 500, 400)
	owner.finish()
	return document
}

fn absolute_pseudo_probe_geometry(state &LayoutState, root &Node) []f64 {
	mut result := []f64{}
	absolute_pseudo_probe_collect_geometry(state, root, mut result)
	return result
}

fn absolute_pseudo_probe_collect_geometry(state &LayoutState, node &Node, mut result []f64) {
	if styled := node.as_node_with_style() {
		if used := state.try_get(styled) {
			result << [used.content_width().to_double(), used.content_height().to_double(),
				f64(used.has_definite_width()), f64(used.has_definite_height()),
				used.offset.x().to_double(), used.offset.y().to_double(), used.margin_left.to_double(),
				used.margin_right.to_double(), used.margin_top.to_double(),
				used.margin_bottom.to_double(), used.padding_left.to_double(),
				used.padding_right.to_double(), used.padding_top.to_double(),
				used.padding_bottom.to_double(), used.inset_left.to_double(),
				used.inset_right.to_double(), used.inset_top.to_double(),
				used.inset_bottom.to_double()]
			for values in [used.grid_template_columns(), used.grid_template_rows()] {
				result << f64(values.len)
				for value in values { result << value.to_double() }
			}
			for basis in [used.relative_inset_basis_width(), used.relative_inset_basis_height()] {
				if value := basis {
					result << [f64(1), value.to_double()]
				} else {
					result << f64(0)
				}
			}
			if rare := used.rare_ {
				if position := rare.static_position_rect_ {
					rect := position.rect
					result << [f64(1), rect.x.to_double(), rect.y.to_double(), rect.width.to_double(),
						rect.height.to_double(), f64(position.horizontal_alignment),
						f64(position.vertical_alignment)]
				} else {
					result << f64(0)
				}
				if rect := rare.abspos_containing_block_rect_ {
					result << [f64(1), rect.x.to_double(), rect.y.to_double(), rect.width.to_double(),
						rect.height.to_double()]
				} else {
					result << f64(0)
				}
			} else {
				result << [f64(0), f64(0)]
			}
			result << f64(used.line_boxes.len)
			for line in used.line_boxes {
				result << [line.width().to_double(), line.height().to_double(),
					line.baseline().to_double(), f64(line.fragments_.len)]
				for fragment in line.fragments_ {
					result << [f64(fragment.start()), f64(fragment.length_in_code_units()),
						fragment.offset().x().to_double(), fragment.offset().y().to_double(),
						fragment.inline_length().to_double()]
					if run := fragment.glyph_run() {
						result << f64(run.glyphs().len)
						for glyph in run.glyphs() {
							result << [f64(glyph.code_point), f64(glyph.glyph_index),
								f64(glyph.position.x), f64(glyph.position.y), f64(glyph.advance),
								f64(glyph.offset_x), f64(glyph.length_in_code_units),
								f64(glyph.should_paint)]
						}
					} else {
						result << f64(0)
					}
				}
			}
		}
	}
	result << f64(node.child_count())
	for child in node.children() {
		absolute_pseudo_probe_collect_geometry(state, child, mut result)
	}
}

// Compare both pre-absolute static records and final absolute geometry to a
// separate unpooled full algorithm. Preserve scalar/glyph data before retiring
// the producer arena, and exercise committed consumption as well as probes.

fn absolute_pseudo_probe_compare(mut source LayoutState, root &Node, width int, height int,
	committed bool) bool {
	return absolute_pseudo_probe_compare_with_parent(mut source, root, width, height, committed, 500, 300)
}

fn absolute_pseudo_probe_seed_static_parent(mut state LayoutState, root &Node, width int, height int) {
	if !root.is_absolutely_positioned() { return }
	static_parent := root.static_position_containing_block() or { return }
	styled := unsafe { &NodeWithStyle(static_parent) }
	if _ := state.try_get(styled) {
		return
	} else {
		mut outside := LayoutState.new()
		mut values := outside.get_mutable(styled)
		values.set_content_width(CSSPixels.new(width))
		values.set_content_height(CSSPixels.new(height))
		values.offset = css.CSSPixelPoint.from_values(33, 41)
		_ = state.populate_node_from(mut outside, styled)
	}
}

fn absolute_pseudo_probe_compare_with_parent(mut source LayoutState, root &Node, width int,
	height int, committed bool, parent_width int, parent_height int) bool {
	styled := root.as_node_with_style() or { panic('style') }
	space := AvailableSpace.new(AvailableSize.make_definite(CSSPixels.new(width)),
		if height > 0 {
			AvailableSize.make_definite(CSSPixels.new(height))
		} else {
			AvailableSize.make_indefinite()
		})
	mut probe := source.new_measurement_for_subtree(styled)
	if committed { probe.subtree_root = none }
	mut used := absolute_pseudo_probe_image_prepare(mut probe, root, width, height)
	parent := root.containing_block() or { panic('containing') }
	mut parent_used := probe.get_mutable(unsafe { &NodeWithStyle(parent) })
	parent_used.set_content_width(CSSPixels.new(parent_width))
	parent_used.set_content_height(CSSPixels.new(parent_height))
	resolve_box_model_edges(root.computed_values(), mut used, f64(parent_width))
	absolute_pseudo_probe_seed_static_parent(mut probe, root, parent_width, parent_height)
	if root.is_absolutely_positioned() {
		used.set_static_position_rect(StaticPositionRect{ rect: css.CSSPixelRect.new(19, 23, 0, 0) })
	}
	actual := absolute_pseudo_probe_image_run(mut probe, root, mut used, space, true)
	mut retained := platform.enter_retained_allocations()
	before := absolute_pseudo_probe_geometry(probe, root)
	retained.finish()
	mut reused := false
	key := u64(voidptr(root))
	mut snapshots := []RetainedBlockValues{}
	if root.display().is_grid_inside() {
		for entry in source.measurement_chunk_pool_.grid_measurements_[key] or { []&GridMeasurementLayout{} } {
			snapshots << entry.values
		}
	} else {
		for entry in source.measurement_chunk_pool_.flex_measurements_[key] or { []&FlexMeasurementLayout{} } {
			snapshots << entry.values
		}
	}
	for entry in snapshots {
		if entry.values.line_boxes.len == 0 { continue }
		if current := probe.try_get(entry.node) {
			if current.line_boxes.data == entry.values.line_boxes.data { reused = true }
		}
	}
	layout_absolutely_positioned_descendants(mut probe, root)
	retained = platform.enter_retained_allocations()
	after := absolute_pseudo_probe_geometry(probe, root)
	retained.finish()
	// A consumer modifying final absolute/static records must detach rare data
	// just as it detaches retained line/glyph arrays.
	for entry in snapshots {
		if _ := entry.values.rare_ {} else { continue }
		mut writable := probe.get_mutable(entry.node)
		writable.set_static_position_rect(StaticPositionRect{ rect: css.CSSPixelRect.new(999, 999, 1, 1) })
		if rare := entry.values.rare_ {
			if position := rare.static_position_rect_ {
				absolute_pseudo_probe_expect(position.rect.x != CSSPixels.new(999))
			}
		}
	}
	probe.release_measurement()
	gc_collect()
	mut oracle := LayoutState.new_for_subtree(styled)
	if committed { oracle.subtree_root = none }
	mut expected := absolute_pseudo_probe_image_prepare(mut oracle, root, width, height)
	mut oracle_parent := oracle.get_mutable(unsafe { &NodeWithStyle(parent) })
	oracle_parent.set_content_width(CSSPixels.new(parent_width))
	oracle_parent.set_content_height(CSSPixels.new(parent_height))
	resolve_box_model_edges(root.computed_values(), mut expected, f64(parent_width))
	absolute_pseudo_probe_seed_static_parent(mut oracle, root, parent_width, parent_height)
	if root.is_absolutely_positioned() {
		expected.set_static_position_rect(StaticPositionRect{ rect: css.CSSPixelRect.new(19, 23, 0, 0) })
	}
	absolute_pseudo_probe_expect(actual == absolute_pseudo_probe_image_run(mut oracle, root, mut expected, space, false))
	absolute_pseudo_probe_expect(before == absolute_pseudo_probe_geometry(oracle, root))
	layout_absolutely_positioned_descendants(mut oracle, root)
	absolute_pseudo_probe_expect(after == absolute_pseudo_probe_geometry(oracle, root))
	oracle.release_measurement()
	return reused
}

fn absolute_pseudo_probe_enabled(kind string) bool {
	return !retain_absolute_measurement_layout && if kind == 'grid' {
		!disable_grid_measurement_reuse
	} else {
		!disable_flex_measurement_reuse
	}
}

fn absolute_pseudo_probe_image_node(document &dom.Document, id string) &Node {
	element := document.get_element_by_id(id) or { panic(id) }
	return unsafe { &Node(element.as_node().unsafe_layout_node() or { panic('layout') }.real_layout_handle()) }
}

fn absolute_pseudo_probe_image_prepare(mut state LayoutState, root &Node, width int, height int) &UsedValues {
	parent := root.containing_block() or { panic('parent') }
	mut ancestors := LayoutState.new()
	mut basis := ancestors.get_mutable(unsafe { &NodeWithStyle(parent) })
	basis.set_content_width(CSSPixels.new(500))
	basis.set_content_height(CSSPixels.new(300))
	basis.set_has_definite_width(true)
	basis.set_has_definite_height(true)
	populate_intrinsic_containing_block_chain(mut state, mut ancestors, root)
	mut used := state.get_mutable(root.as_node_with_style() or { panic('style') })
	used.set_containing_block_used_values(state.get(unsafe { &NodeWithStyle(parent) }))
	used.set_content_width(CSSPixels.new(width))
	used.set_content_height(CSSPixels.new(height))
	used.set_has_definite_width(true)
	used.set_has_definite_height(height > 0)
	used.offset = css.CSSPixelPoint.from_values(11, 13)
	resolve_box_model_edges(root.computed_values(), mut used, 500)
	return used
}

fn absolute_pseudo_probe_image_run(mut state LayoutState, root &Node, mut used UsedValues,
	space AvailableSpace, cached bool) FormattingContextResult {
	if root.display().is_grid_inside() {
		if cached {
			return run_grid_formatting_context_internal(mut state, root, mut used, .normal, space, false)
		}
		return run_uncached_grid_formatting_context_internal(mut state, root, mut used, .normal, space, false)
	}
	if cached {
		return run_flex_formatting_context_with_mode(mut state, root, mut used, .normal, space)
	}
	return run_uncached_flex_formatting_context_with_mode(mut state, root, mut used, .normal, space)
}

fn absolute_pseudo_probe_generated(document &dom.Document, pseudo dom.PseudoElement) &Node {
	element := document.get_element_by_id('host') or { panic('host') }
	subject := dom.AbstractElement.new(element, pseudo)
	styled := subject.unsafe_layout_node() or { panic('pseudo bridge') }
	mirror := styled.layout_node_ or { panic('pseudo layout') }
	return unsafe { &Node(mirror.real_layout_handle()) }
}

fn test_absolute_before_after_measurements_preserve_generated_text_and_static_geometry() {
	for kind in ['grid', 'flex'] {
		for pseudo in [dom.PseudoElement.before, .after] {
			name := if pseudo == .before { 'before' } else { 'after' }
			for content in ['', 'Generated wrapping alpha 😀 á words.'] {
				mut document := absolute_pseudo_probe_document(kind,
					'<style>#host::${name}{content:"${content}";position:absolute;left:10%;top:5%;width:40%;height:25%;padding:3px;border:1px solid}</style><div id="host" style="position:relative">Host content.</div>', '')
				mut owner := document.enter_native_storage()
				defer {
					owner.finish()
					document.finalize()
					document.release_native_storage()
				}
				root := absolute_pseudo_probe_image_node(document, 'root')
				generated := absolute_pseudo_probe_generated(document, pseudo)
				absolute_pseudo_probe_expect(measurement_absolute_descendant_is_reusable(generated) == (!retain_absolute_measurement_layout && !disable_absolute_pseudo_measurements && !disable_static_generated_measurements))
				mut source := LayoutState.new()
				source.enable_measurement_chunk_pool()
				source.measurement_chunk_pool_.scratch_enabled_ = true
				defer { source.release_measurement_chunk_pool() }
				absolute_pseudo_probe_expect(!absolute_pseudo_probe_compare(mut source, root, 180, 160, false))
				absolute_pseudo_probe_expect(!absolute_pseudo_probe_compare(mut source, root, 180, 160, false))
				enabled := absolute_pseudo_probe_enabled(kind) && !disable_absolute_pseudo_measurements && !disable_static_generated_measurements
				for _ in 0 .. 2 {
					absolute_pseudo_probe_expect(absolute_pseudo_probe_compare(mut source, root, 180, 160, false) == enabled)
				}
				absolute_pseudo_probe_expect(absolute_pseudo_probe_compare(mut source, root, 180, 160, true) == (enabled && if kind == 'grid' {
					!disable_committed_grid_measurement_reuse
				} else {
					!disable_committed_flex_measurement_reuse
				}))
				mut inputs := []RetainedInlineInput{}
				mut rejected := map[u64]bool{}
				absolute_pseudo_probe_expect(!collect_retained_block_inputs(root, mut inputs, mut rejected))
			}
		}
	}
}

fn test_absolute_before_after_measurements_validate_live_text_style_and_containing_blocks() {
	for kind in ['grid', 'flex'] {
		for change in ['text', 'inset', 'external-containing-block'] {
			mut document := absolute_pseudo_probe_document(kind,
				'<style>#host::before{content:"Original generated words.";position:absolute;left:4px;top:8px;width:65px}</style><div id="host" style="position:relative">Host.</div>', '')
			mut owner := document.enter_native_storage()
			defer {
				owner.finish()
				document.finalize()
				document.release_native_storage()
			}
			root := absolute_pseudo_probe_image_node(document, 'root')
			generated := absolute_pseudo_probe_generated(document, .before)
			mut source := LayoutState.new()
			source.enable_measurement_chunk_pool()
			source.measurement_chunk_pool_.scratch_enabled_ = true
			defer { source.release_measurement_chunk_pool() }
			absolute_pseudo_probe_expect(!absolute_pseudo_probe_compare(mut source, root, 180, 160, false))
			absolute_pseudo_probe_expect(!absolute_pseudo_probe_compare(mut source, root, 180, 160, false))
			absolute_pseudo_probe_expect(absolute_pseudo_probe_compare(mut source, root, 180, 160, false) == (absolute_pseudo_probe_enabled(kind) && !disable_absolute_pseudo_measurements && !disable_static_generated_measurements))
			if change == 'text' {
				mut text := generated.children()[0].as_text_node()?
				text.source_text_ = 'Changed generated words that wrap differently.'
				text.invalidate_text_for_rendering()
			} else if change == 'external-containing-block' {
				mut node := unsafe { &Node(generated) }
				node.containing_block_ = root.containing_block()
			} else {
				mut style := unsafe { &css.ComputedProperties(generated.computed_values()) }
				value := css.parse_css_value(css.ParsingParams{}, '27px', .left) or { panic('left') }
				style.set_property(.left, value, .no, .no)
			}
			absolute_pseudo_probe_expect(!absolute_pseudo_probe_compare(mut source, root, 180, 160, false))
		}
	}
}

fn test_absolute_before_after_measurements_keep_special_positions_on_full_layout() {
	for rules in ['position:fixed', 'position:sticky;top:2px', 'position:relative;left:2px',
		'position:absolute;left:calc(10% + 2px)', 'position:absolute;left:anchor(--outside left)',
		'position:absolute;position-anchor:--outside'] {
		mut document := absolute_pseudo_probe_document('grid',
			'<style>#host::after{content:"Generated.";${rules}}</style><div id="host">Host.</div>', '')
		mut owner := document.enter_native_storage()
		defer {
			owner.finish()
			document.finalize()
			document.release_native_storage()
		}
		root := absolute_pseudo_probe_image_node(document, 'root')
		mut inputs := []RetainedInlineInput{}
		mut rejected := map[u64]bool{}
		absolute_pseudo_probe_expect(!collect_grid_measurement_inputs(root, mut inputs, mut rejected))
	}
}
