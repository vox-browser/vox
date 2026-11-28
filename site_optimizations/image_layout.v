module main

import dom
import os
import strings

const disable_github_image_layout_batching = os.getenv('VOX_DISABLE_GITHUB_IMAGE_LAYOUT_BATCHING') != ''
const github_image_layout_diagnostics = os.getenv('VOX_GITHUB_IMAGE_LAYOUT_DIAGNOSTICS') != ''

fn site_is_github_http_url(address dom.URL) bool {
	if address.scheme() !in ['http', 'https'] { return false }
	host := address.serialized_host()
	if strings.equal_fold(host, 'github.com') { return true }
	return host.ends_with('.') && strings.equal_fold(host.trim_right('.'), 'github.com')
}

// A GitHub repository starts many images alongside its module bootstrap.
// Apply their results and load events now, but let the current frame adopt
// geometry after the remaining resource/script callbacks have also run.
// Synchronous author geometry queries still use Document.update_layout().
fn (mut app BrowserApp) defer_site_image_completion_layout() bool {
	if disable_github_image_layout_batching || app.document == unsafe { nil }
		|| !site_is_github_http_url(app.document.url) {
		return false
	}
	deferred := app.defer_javascript_layout_to_current_frame()
	if deferred && github_image_layout_diagnostics {
		eprintln('Vox site optimization: deferred GitHub image-completion layout to frame end')
	}
	return deferred
}
