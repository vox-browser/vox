module main

fn browser_window_title(title string) string {
	if title == '' { return 'vox' }
	// Sokol copies titles into a 128-byte buffer before passing them to the
	// platform. Leave room for its NUL and the suffix without splitting UTF-8:
	// Cocoa rejects the nil NSString produced by an incomplete character.
	suffix := ' — vox'
	mut end := if title.len > 127 - suffix.len { 127 - suffix.len } else { title.len }
	for end > 0 && end < title.len && title[end] & 0xc0 == 0x80 {
		end--
	}
	return title[..end] + suffix
}
