module main

import os

const disable_github_stylesheet_layout_reuse = os.getenv('VOX_DISABLE_GITHUB_STYLESHEET_LAYOUT_REUSE') != ''
const github_stylesheet_layout_diagnostics = os.getenv('VOX_GITHUB_STYLESHEET_LAYOUT_DIAGNOSTICS') != ''

// CSS's property invalidation determines which boxes must be rebuilt. Keeping
// the existing tree lets unaffected GitHub content retain its layout inputs
// while asynchronously installed module styles participate in the full cascade.
fn (mut app BrowserApp) complete_site_stylesheet_update() bool {
	if disable_github_stylesheet_layout_reuse || app.document == unsafe { nil }
		|| app.document.layout_root == unsafe { nil } || app.initial_layout_pending
		|| !site_batches_image_completion_layout(app.document.url.serialize()) {
		return false
	}
	// Installing the link's CSSOM sheet already invalidates matching subjects,
	// inherited descendants and any broad @rule effects. Do not replace that
	// invalidation plan with a whole-document restyle for every lazy chunk.
	if !app.defer_javascript_layout_to_current_frame() {
		app.relayout(app.viewport_width, app.viewport_height + app.chrome_height())
	}
	if github_stylesheet_layout_diagnostics {
		eprintln('Vox site optimization: retained GitHub layout for stylesheet completion')
	}
	return true
}
