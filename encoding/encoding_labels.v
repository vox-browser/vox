// Copyright (c) 2024, the SerenityOS developers.
//
// SPDX-License-Identifier: BSD-2-Clause

// Translation of TextCodec::get_standardized_encoding (LibTextCodec/Decoder.cpp) — the Encoding spec's
// "get an encoding" operation: trim ASCII whitespace from a label and, if it is an ASCII case-insensitive
// match for one of the table's labels, return the corresponding encoding name; otherwise none.
//
// The table (and its ordering) mirrors upstream exactly, including the non-standard extra "koi8-r"/"koi8r"
// group placed after the KOI8-R group, so a first-match-wins lookup of "koi8-r" yields "KOI8-R".
// https://encoding.spec.whatwg.org/#concept-encoding-get
module encoding

struct EncodingLabelGroup {
	labels []string
	name   string
}

// The label table. Labels are lowercase (matched ASCII case-insensitively); names are the canonical
// encoding names returned verbatim.
const encoding_label_table = [
	EncodingLabelGroup{
		labels: ['unicode-1-1-utf-8', 'unicode11utf8', 'unicode20utf8', 'utf-8', 'utf8',
			'x-unicode20utf8']
		name:   'UTF-8'
	},
	EncodingLabelGroup{
		labels: ['866', 'cp866', 'csibm866', 'ibm866']
		name:   'IBM866'
	},
	EncodingLabelGroup{
		labels: ['csisolatin2', 'iso-8859-2', 'iso-ir-101', 'iso8859-2', 'iso88592', 'iso_8859-2',
			'iso_8859-2:1987', 'l2', 'latin2']
		name:   'ISO-8859-2'
	},
	EncodingLabelGroup{
		labels: ['csisolatin3', 'iso-8859-3', 'iso-ir-109', 'iso8859-3', 'iso88593', 'iso_8859-3',
			'iso_8859-3:1988', 'l3', 'latin3']
		name:   'ISO-8859-3'
	},
	EncodingLabelGroup{
		labels: ['csisolatin4', 'iso-8859-4', 'iso-ir-110', 'iso8859-4', 'iso88594', 'iso_8859-4',
			'iso_8859-4:1988', 'l4', 'latin4']
		name:   'ISO-8859-4'
	},
	EncodingLabelGroup{
		labels: ['csisolatincyrillic', 'cyrillic', 'iso-8859-5', 'iso-ir-144', 'iso8859-5',
			'iso88595', 'iso_8859-5', 'iso_8859-5:1988']
		name:   'ISO-8859-5'
	},
	EncodingLabelGroup{
		labels: ['arabic', 'asmo-708', 'csiso88596e', 'csiso88596i', 'csisolatinarabic', 'ecma-114',
			'iso-8859-6', 'iso-8859-6-e', 'iso-8859-6-i', 'iso-ir-127', 'iso8859-6', 'iso88596',
			'iso_8859-6', 'iso_8859-6:1987']
		name:   'ISO-8859-6'
	},
	EncodingLabelGroup{
		labels: ['csisolatingreek', 'ecma-118', 'elot_928', 'greek', 'greek8', 'iso-8859-7',
			'iso-ir-126', 'iso8859-7', 'iso88597', 'iso_8859-7', 'iso_8859-7:1987', 'sun_eu_greek']
		name:   'ISO-8859-7'
	},
	EncodingLabelGroup{
		labels: ['csiso88598e', 'csisolatinhebrew', 'hebrew', 'iso-8859-8', 'iso-8859-8-e',
			'iso-ir-138', 'iso8859-8', 'iso88598', 'iso_8859-8', 'iso_8859-8:1988', 'visual']
		name:   'ISO-8859-8'
	},
	EncodingLabelGroup{
		labels: ['csiso88598i', 'iso-8859-8-i', 'logical']
		name:   'ISO-8859-8-I'
	},
	EncodingLabelGroup{
		labels: ['csisolatin6', 'iso-8859-10', 'iso-ir-157', 'iso8859-10', 'iso885910', 'l6',
			'latin6']
		name:   'ISO-8859-10'
	},
	EncodingLabelGroup{
		labels: ['iso-8859-13', 'iso8859-13', 'iso885913']
		name:   'ISO-8859-13'
	},
	EncodingLabelGroup{
		labels: ['iso-8859-14', 'iso8859-14', 'iso885914']
		name:   'ISO-8859-14'
	},
	EncodingLabelGroup{
		labels: ['csisolatin9', 'iso-8859-15', 'iso8859-15', 'iso885915', 'iso_8859-15', 'l9']
		name:   'ISO-8859-15'
	},
	EncodingLabelGroup{
		labels: ['iso-8859-16']
		name:   'ISO-8859-16'
	},
	EncodingLabelGroup{
		labels: ['cskoi8r', 'koi', 'koi8', 'koi8-r', 'koi8_r']
		name:   'KOI8-R'
	},
	EncodingLabelGroup{
		labels: ['koi8-ru', 'koi8-u']
		name:   'KOI8-U'
	},
	EncodingLabelGroup{
		labels: ['csmacintosh', 'mac', 'macintosh', 'x-mac-roman']
		name:   'macintosh'
	},
	EncodingLabelGroup{
		labels: ['pdfdocencoding']
		name:   'PDFDocEncoding'
	},
	EncodingLabelGroup{
		labels: ['dos-874', 'iso-8859-11', 'iso8859-11', 'iso885911', 'tis-620', 'windows-874']
		name:   'windows-874'
	},
	EncodingLabelGroup{
		labels: ['cp1250', 'windows-1250', 'x-cp1250']
		name:   'windows-1250'
	},
	EncodingLabelGroup{
		labels: ['cp1251', 'windows-1251', 'x-cp1251']
		name:   'windows-1251'
	},
	EncodingLabelGroup{
		labels: ['ansi_x3.4-1968', 'ascii', 'cp1252', 'cp819', 'csisolatin1', 'ibm819', 'iso-8859-1',
			'iso-ir-100', 'iso8859-1', 'iso88591', 'iso_8859-1', 'iso_8859-1:1987', 'l1', 'latin1',
			'us-ascii', 'windows-1252', 'x-cp1252']
		name:   'windows-1252'
	},
	EncodingLabelGroup{
		labels: ['cp1253', 'windows-1253', 'x-cp1253']
		name:   'windows-1253'
	},
	EncodingLabelGroup{
		labels: ['cp1254', 'csisolatin5', 'iso-8859-9', 'iso-ir-148', 'iso8859-9', 'iso88599',
			'iso_8859-9', 'iso_8859-9:1989', 'l5', 'latin5', 'windows-1254', 'x-cp1254']
		name:   'windows-1254'
	},
	EncodingLabelGroup{
		labels: ['cp1255', 'windows-1255', 'x-cp1255']
		name:   'windows-1255'
	},
	EncodingLabelGroup{
		labels: ['cp1256', 'windows-1256', 'x-cp1256']
		name:   'windows-1256'
	},
	EncodingLabelGroup{
		labels: ['cp1257', 'windows-1257', 'x-cp1257']
		name:   'windows-1257'
	},
	EncodingLabelGroup{
		labels: ['cp1258', 'windows-1258', 'x-cp1258']
		name:   'windows-1258'
	},
	EncodingLabelGroup{
		labels: ['x-mac-cyrillic', 'x-mac-ukrainian']
		name:   'x-mac-cyrillic'
	},
	EncodingLabelGroup{
		labels: ['koi8-r', 'koi8r']
		name:   'koi8-r'
	},
	EncodingLabelGroup{
		labels: ['chinese', 'csgb2312', 'csiso58gb231280', 'gb2312', 'gb_2312', 'gb_2312-80', 'gbk',
			'iso-ir-58', 'x-gbk']
		name:   'GBK'
	},
	EncodingLabelGroup{
		labels: ['gb18030']
		name:   'gb18030'
	},
	EncodingLabelGroup{
		labels: ['big5', 'big5-hkscs', 'cn-big5', 'csbig5', 'x-x-big5']
		name:   'Big5'
	},
	EncodingLabelGroup{
		labels: ['cseucpkdfmtjapanese', 'euc-jp', 'x-euc-jp']
		name:   'EUC-JP'
	},
	EncodingLabelGroup{
		labels: ['csiso2022jp', 'iso-2022-jp']
		name:   'ISO-2022-JP'
	},
	EncodingLabelGroup{
		labels: ['csshiftjis', 'ms932', 'ms_kanji', 'shift-jis', 'shift_jis', 'sjis', 'windows-31j',
			'x-sjis']
		name:   'Shift_JIS'
	},
	EncodingLabelGroup{
		labels: ['cseuckr', 'csksc56011987', 'euc-kr', 'iso-ir-149', 'korean', 'ks_c_5601-1987',
			'ks_c_5601-1989', 'ksc5601', 'ksc_5601', 'windows-949']
		name:   'EUC-KR'
	},
	EncodingLabelGroup{
		labels: ['csiso2022kr', 'hz-gb-2312', 'iso-2022-cn', 'iso-2022-cn-ext', 'iso-2022-kr',
			'replacement']
		name:   'replacement'
	},
	EncodingLabelGroup{
		labels: ['unicodefffe', 'utf-16be']
		name:   'UTF-16BE'
	},
	EncodingLabelGroup{
		labels: ['csunicode', 'iso-10646-ucs-2', 'ucs-2', 'unicode', 'unicodefeff', 'utf-16',
			'utf-16le']
		name:   'UTF-16LE'
	},
	EncodingLabelGroup{
		labels: ['x-user-defined']
		name:   'x-user-defined'
	},
]

// https://encoding.spec.whatwg.org/#concept-encoding-get — the standardized encoding name for a label,
// or none for an unrecognized label (TextCodec::get_standardized_encoding).
pub fn get_an_encoding(label string) ?string {
	// 1. Remove leading and trailing ASCII whitespace from the label.
	// 2. Return the encoding whose (ASCII case-insensitive) label matches, or none.
	lowercased := encoding_ascii_lowercase(label.trim('\t\n\x0c\r '))
	for group in encoding_label_table {
		if lowercased in group.labels {
			return group.name
		}
	}
	return none
}

fn encoding_ascii_lowercase(input string) string {
	mut bytes := input.bytes()
	for i, ch in bytes {
		if ch >= `A` && ch <= `Z` {
			bytes[i] = ch + 0x20
		}
	}
	return bytes.bytestr()
}
