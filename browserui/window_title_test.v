module browserui

import encoding.utf8
import os

fn test_window_title_uses_embedded_build_time_and_build_mode() {
	label := window_title('')
	assert label.ends_with(' · built ${@BUILD_DATE} ${@BUILD_TIME} UTC]')
	assert label.starts_with('vox [prod · built ') || label.starts_with('vox [dev · built ')
	// The focused runs supply the expected mode independently of the compiler
	// condition, covering default dev, explicit production and V's -prod mode.
	if expected := os.getenv_opt('VOX_EXPECT_BUILD_MODE') {
		assert label.starts_with('vox [${expected} · built ')
	}
}

fn test_window_title_preserves_short_titles_and_browser_suffix() {
	label := window_title('')
	assert window_title('Reddit') == 'Reddit — ${label}'
	assert window_title('Привіт 🌍') == 'Привіт 🌍 — ${label}'
}

fn test_window_title_does_not_split_suffix_for_reported_reddit_post() {
	title := 'UA Pov: Close-up footage of Storm Shadow missiles strike targeting Proton electronics facility in Oryol : UkraineRussiaReport'
	assert title.len == 125
	suffix := ' — ${window_title('')}'
	result := window_title(title)
	assert utf8.validate_str(result)
	assert result.len == 127
	assert result == title[..127 - suffix.len] + suffix
}

fn test_window_title_truncates_multibyte_characters_only_at_boundaries() {
	suffix := ' — ${window_title('')}'
	capacity := 127 - suffix.len
	for character in ['é', '中', '🌍'] {
		for prefix_length in capacity - 4 .. capacity + 1 {
			prefix := 'a'.repeat(prefix_length)
			title := prefix + character.repeat(20)
			result := window_title(title)
			assert utf8.validate_str(result)
			assert result.len <= 127
			assert result.ends_with(suffix)
			body := result[..result.len - suffix.len]
			assert title.starts_with(body)
			assert body.len + character.len > capacity
		}
	}
}
