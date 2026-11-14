module layout

import dom
import html

fn measurement_reuse_check_full_rebuild(mut document dom.Document) {
	before := (document.record_display_list() or { panic('missing paint') }).dump()
	document.set_needs_full_layout_tree_update(true)
	document.update_layout(.debugging)
	assert (document.record_display_list() or { panic('missing full paint') }).dump() == before
}

fn measurement_reuse_document(stable string, row_style string) &dom.Document {
	// The body measures <main>, which measures the row; the row's items are
	// laid out in normal mode inside those measurements.
	return html.parse_document('<!doctype html><style>body{display:flex;flex-direction:column;margin:0}main{display:flex;flex-direction:column}.row{display:flex;${row_style}}.row>div{flex:1}</style><body><main><div class="row"><div><p id="changed">first</p></div><div id="stable">${stable}</div></div><footer>tail</footer></main></body>')
}

// Clean items below a changed path are restored inside the measurements of
// that path, and the result paints like a complete layout.
fn test_measurements_restore_clean_items_of_a_changed_row() {
	for stable in ['<p>stable text</p><ul><li>one</li><li>two</li></ul>',
		'<table><tbody><tr><td>cell</td><td>next</td></tr></tbody></table>',
		'<div style="display:flex"><span>a</span><b>b</b></div><p>below</p>'] {
		for row_style in ['', 'align-items:flex-start', 'flex-wrap:wrap'] {
			mut document := measurement_reuse_document(stable, row_style)
			defer { document.finalize() }
			_ = layout_document_typed_in_viewport(document, 400, 300)
			mut changed := document.get_element_by_id('changed')?
			mut restored := u64(0)
			for index in 0 .. 4 {
				last_before, first_before, _ := measurement_subtree_reuse_statistics()
				if index % 2 == 0 {
					changed.set_inner_html('line ${index}<br>second line') or { panic(err) }
				} else {
					changed.set_inner_html('short ${index}') or { panic(err) }
				}
				document.update_layout(.debugging)
				last_after, first_after, _ := measurement_subtree_reuse_statistics()
				restored += (last_after - last_before) + (first_after - first_before)
				measurement_reuse_check_full_rebuild(mut document)
			}
			assert restored > 0, '${stable} ${row_style}'
		}
	}
}

// A stretched item is laid out twice. Its first record answers measurements
// only while the box reports the baselines of that first call; an item whose
// content moves with its stretched height keeps the complete measurement.
fn test_stretched_items_keep_a_first_record_with_matching_baselines() {
	for stable in ['<p>stable text</p>',
		'<div style="display:flex;flex-direction:column;justify-content:flex-end;height:100%"><p>pushed down</p></div>'] {
		mut document := measurement_reuse_document(stable, '')
		defer { document.finalize() }
		_ = layout_document_typed_in_viewport(document, 400, 300)
		mut changed := document.get_element_by_id('changed')?
		_, _, kept_before := measurement_subtree_reuse_statistics()
		for index in 0 .. 4 {
			// The changed column is taller than the stable one, which stretches.
			changed.set_inner_html('line ${index}<br>second<br>third<br>fourth') or { panic(err) }
			document.update_layout(.debugging)
			measurement_reuse_check_full_rebuild(mut document)
		}
		_, _, kept_after := measurement_subtree_reuse_statistics()
		assert kept_after > kept_before, stable
	}
}

// Changes inside a restored item are measured and painted.
fn test_changed_items_are_measured_again() {
	mut document := measurement_reuse_document('<p id="inner">stable text</p>', '')
	defer { document.finalize() }
	_ = layout_document_typed_in_viewport(document, 400, 300)
	mut changed := document.get_element_by_id('changed')?
	changed.set_inner_html('first change') or { panic(err) }
	document.update_layout(.debugging)
	mut inner := document.get_element_by_id('inner')?
	inner.set_inner_html('now<br>three<br>lines') or { panic(err) }
	document.update_layout(.debugging)
	painted := (document.record_display_list() or { panic('missing paint') }).dump()
	assert painted.contains('three')
	measurement_reuse_check_full_rebuild(mut document)
	changed.set_inner_html('second change') or { panic(err) }
	document.update_layout(.debugging)
	measurement_reuse_check_full_rebuild(mut document)
}
