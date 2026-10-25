module layout

import html

// An intrinsic-width measurement can choose different line metrics from the
// final cell width. It must not add that difference to the laid-out row.
fn test_chromium_table_footer_uses_final_width_content_height() {
	$if !macos {
		return
	}
	mut document := html.parse_document('<style>
		body{margin:0}td{font:10pt Verdana,Geneva,sans-serif}
		.small{font-size:8pt}input{font:10pt monospace}
	</style><table width="870" cellspacing="0" cellpadding="0"><tr><td id="footer">
		<img height="10" width="0"><table width="100%" cellspacing="0" cellpadding="1"><tr><td bgcolor="#ff6600"></td></tr></table><br>
		<center><a>Consider applying for the next batch! <u>Applications</u> are open.</a></center><br>
		<center><span class="small">Guidelines | FAQ | Lists | API | Security | Legal | Apply | Contact</span><br><br>
		<form>Search: <input type="text" size="17"></form></center>
	</td></tr></table>')
	defer { document.finalize() }
	document.set_font_rendering_policy(.chromium)
	run_document_layout(document, 1024, 768) or { panic('layout') }
	footer := document.get_element_by_id('footer') or { panic('footer') }
	assert footer.get_bounding_client_rect().height == 123.328125
}
