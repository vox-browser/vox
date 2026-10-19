module encoding

import json2
import os

pub struct Jis0208NativeSourceHelper {
pub:
	pointer string
	symbol  ?u16
	range   ?u16
}

fn test_exact_source_jis0208_and_ibm_literal_tables_match_actual_native_statics() {
	tables := json2.decode[[][]u16](os.read_file('${os.dir(@DIR)}/encoding/fixtures/jis0208_tables.json')!)!
	assert tables.len == 6
	assert tables[0] == source_jis0208_level1_kanji
	assert tables[1] == source_jis0208_level2_and_additional_kanji
	assert tables[2] == source_ibm_kanji
	assert tables[3] == source_jis0208_symbols
	assert tables[4] == source_jis0208_symbol_triples
	assert tables[5] == source_jis0208_range_triples
	assert tables[0].len == 2965 && tables[1].len == 3390 && tables[2].len == 360
	assert tables[3].len == 240 && tables[4].len == 33 && tables[5].len == 54
}

fn test_source_jis0208_symbol_and_range_ordered_helpers_match_actual_native_bodies() {
	cases := json2.decode[[]Jis0208NativeSourceHelper](os.read_file('${os.dir(@DIR)}/encoding/fixtures/jis0208_helpers.json')!)!
	assert cases.len == 11286
	for item in cases {
		pointer := item.pointer.u64()
		if expected := item.symbol {
			assert source_jis0208_symbol_decode(pointer)? == expected
		} else {
			assert source_jis0208_symbol_decode(pointer) == none
		}
		if expected := item.range {
			assert source_jis0208_range_decode(pointer)? == expected
		} else {
			assert source_jis0208_range_decode(pointer) == none
		}
	}
}
