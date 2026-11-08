module main

import os
import url

const disable_github_image_layout_batching = os.getenv('VOX_DISABLE_GITHUB_IMAGE_LAYOUT_BATCHING') != ''
const github_image_layout_diagnostics = os.getenv('VOX_GITHUB_IMAGE_LAYOUT_DIAGNOSTICS') != ''

fn site_batches_image_completion_layout(address string) bool {
	parsed := url.parse(address) or { return false }
	if parsed.scheme !in ['http', 'https'] { return false }
	host := parsed.host or { return false }
	return host.serialize().trim_right('.').to_lower() == 'github.com'
}

// A GitHub repository starts many images alongside its module bootstrap.
// Apply their results and load events now, but let the current frame adopt
// geometry after the remaining resource/script callbacks have also run.
// Synchronous author geometry queries still use Document.update_layout().
fn (mut app BrowserApp) defer_site_image_completion_layout() bool {
	if disable_github_image_layout_batching || app.document == unsafe { nil }
		|| !site_batches_image_completion_layout(app.document.url.serialize()) {
		return false
	}
	deferred := app.defer_javascript_layout_to_current_frame()
	if deferred && github_image_layout_diagnostics {
		eprintln('Vox site optimization: deferred GitHub image-completion layout to frame end')
	}
	return deferred
}
