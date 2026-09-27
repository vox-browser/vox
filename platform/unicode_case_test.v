module platform

fn test_transform_text_case_honors_turkish_language() {
	assert transform_text_case('istanbul', 'en', .uppercase) == 'ISTANBUL'
	assert transform_text_case('istanbul', 'tr', .uppercase) == 'İSTANBUL'
	assert transform_text_case('I I', 'tr', .lowercase) == 'ı ı'
}

fn test_transform_text_case_titlecase_preserves_existing_trailing_case() {
	assert transform_text_case('istanbul MIXED', 'tr', .titlecase) == 'İstanbul MIXED'
}
