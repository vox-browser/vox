module layout

import html

fn test_static_submit_and_reset_defaults_apply_only_when_value_is_absent() {
	mut document := html.parse_document('<!doctype html><style>
		body{margin:0}input{display:block;width:150px;height:25px}
	</style><input type="submit"><input type="submit" value="">
	<input type="reset"><input type="reset" value="">
	<input type="button"><input type="button" value="named">')
	mut root := layout_document_typed_in_viewport(document, 300, 300)
	labels := root.paint_commands().filter(it.kind == 'draw_text' && it.text != '').map(it.text)
	assert labels == ['Submit', 'Reset', 'named']
}
