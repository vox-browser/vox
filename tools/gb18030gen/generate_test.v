module gb18030gen

import os

fn test_pinned_indexes_regenerate_the_existing_browser_mapping_exactly() {
	index, ranges := read_pinned_indexes(os.join_path(@VMODROOT, 'encoding/indices'))!
	source := generate(index, ranges)!
	current := os.read_file(os.join_path(@VMODROOT, 'encoding/gb18030_data.v'))!
	// Only the generator attribution changes when migrating from encoding_rs.
	assert source.all_after('\n') == current.all_after('\n')
}

fn test_index_reader_rejects_bad_scalars_duplicate_and_unsorted_pointers() {
	for source in ['0 0xD800', '0 0x110000', '0 0x41\n0 0x42', '2 0x41\n1 0x42', '0 invalid', '0',
		'-1 0x41'] {
		if _ := parse_index(source) {
			assert false, source
		}
	}
	index := parse_index('# comment\n  0\t0x0041 A\n  2 0x1F600 emoji\n')!
	assert index.len == 2 && index[0].point == 65 && index[1].point == 0x1f600
	if _ := generate(index, []IndexEntry{}) {
		assert false
	}
}
