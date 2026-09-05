module dom

fn test_text_directionality_uses_unicode_bidi_properties() {
	document := Document.create(url_about_blank())

	// U+037E is punctuation inside the Greek block, not a strong L character.
	assert document.create_text_node('\u037e').directionality() == none
	// U+0600 is Arabic Number; the following Latin letter is the first strong character.
	assert document.create_text_node('\u0600A').directionality()? == .ltr
	// Adlam is a right-to-left script outside the ranges used by the former approximation.
	assert document.create_text_node('\U0001e900').directionality()? == .rtl
}
