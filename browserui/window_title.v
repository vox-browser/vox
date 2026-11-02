module browserui

// Keep build identity in the shared UI policy so every platform and every
// title update uses the metadata embedded in this binary, even after a rebuild.
pub fn window_title(title string) string {
	mut mode := 'dev'
	// Production scripts optimize C directly in collector/prealloc builds,
	// without V's -prod flag. Direct `v -prod` builds are production too.
	$if prod || vox_production ? {
		mode = 'prod'
	}
	label := 'vox [${mode} · built ${@BUILD_DATE} ${@BUILD_TIME} UTC]'
	if title == '' { return label }
	// Sokol copies titles into a 128-byte buffer. Reserve its NUL and the
	// complete build suffix without cutting a UTF-8 character in the page title.
	suffix := ' — ${label}'
	mut end := if title.len > 127 - suffix.len { 127 - suffix.len } else { title.len }
	for end > 0 && end < title.len && title[end] & 0xc0 == 0x80 {
		end--
	}
	return title[..end] + suffix
}
