module encoding

fn test_utf_8_aliases() {
	assert get_an_encoding('utf-8')? == 'UTF-8'
	assert get_an_encoding('utf8')? == 'UTF-8'
	assert get_an_encoding('unicode-1-1-utf-8')? == 'UTF-8'
	assert get_an_encoding('x-unicode20utf8')? == 'UTF-8'
}

fn test_ascii_case_insensitive() {
	assert get_an_encoding('UTF-8')? == 'UTF-8'
	assert get_an_encoding('Utf8')? == 'UTF-8'
	assert get_an_encoding('LATIN1')? == 'windows-1252'
	assert get_an_encoding('Shift_JIS')? == 'Shift_JIS'
}

fn test_whitespace_is_trimmed() {
	// Leading/trailing ASCII whitespace (tab, LF, FF, CR, space) is removed before matching.
	assert get_an_encoding('  utf-8  ')? == 'UTF-8'
	assert get_an_encoding('\t\n\x0c\r utf-8 \t\n\x0c\r')? == 'UTF-8'
	// Internal whitespace is not trimmed, so it does not match.
	assert get_an_encoding('ut f-8') == none
}

fn test_windows_1252_family() {
	// The windows-1252 group folds in ascii, latin1, iso-8859-1, us-ascii, etc.
	assert get_an_encoding('ascii')? == 'windows-1252'
	assert get_an_encoding('iso-8859-1')? == 'windows-1252'
	assert get_an_encoding('us-ascii')? == 'windows-1252'
	assert get_an_encoding('windows-1252')? == 'windows-1252'
}

fn test_legacy_multibyte_encodings() {
	assert get_an_encoding('gbk')? == 'GBK'
	assert get_an_encoding('gb18030')? == 'gb18030'
	assert get_an_encoding('big5')? == 'Big5'
	assert get_an_encoding('euc-jp')? == 'EUC-JP'
	assert get_an_encoding('shift_jis')? == 'Shift_JIS'
	assert get_an_encoding('euc-kr')? == 'EUC-KR'
	assert get_an_encoding('korean')? == 'EUC-KR'
}

fn test_replacement_and_utf16_and_user_defined() {
	assert get_an_encoding('iso-2022-kr')? == 'replacement'
	assert get_an_encoding('hz-gb-2312')? == 'replacement'
	assert get_an_encoding('utf-16')? == 'UTF-16LE'
	assert get_an_encoding('utf-16le')? == 'UTF-16LE'
	assert get_an_encoding('utf-16be')? == 'UTF-16BE'
	assert get_an_encoding('unicode')? == 'UTF-16LE'
	assert get_an_encoding('x-user-defined')? == 'x-user-defined'
}

fn test_koi8_r_ordering_is_preserved() {
	// "koi8-r" appears in both the KOI8-R group and the later koi8-r group; the earlier match wins.
	assert get_an_encoding('koi8-r')? == 'KOI8-R'
	// "koi8r" is only in the later group.
	assert get_an_encoding('koi8r')? == 'koi8-r'
	assert get_an_encoding('koi8-u')? == 'KOI8-U'
}

fn test_unknown_label_is_none() {
	assert get_an_encoding('not-an-encoding') == none
	assert get_an_encoding('') == none
	assert get_an_encoding('utf-9') == none
}
