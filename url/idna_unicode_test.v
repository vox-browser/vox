module url

import encoding.hex

fn test_unicode17_nontransitional_idna_conformance() {
	mut failures := 0
	mut count := 0
	for line in $embed_file('testdata/idna-unicode17.tsv').to_string().split_into_lines() {
		if line.starts_with('#') || line == '' { continue }
		fields := line.split('\t')
		source := hex.decode(fields[0])!.bytestr()
		expected := hex.decode(fields[1])!.bytestr()
		for strict in [true, false] {
			valid := fields[if strict { 2 } else { 3 }] == '1'
			if actual := idna_to_ascii(source, strict) {
				if !valid || actual != expected {
					if failures < 100 {
						eprintln('IDNA ${count} strict=${strict}: ${fields[0]} => ${actual}; valid=${valid} expected=${expected}')
					}
					failures++
				}
			} else if valid {
				if failures < 100 {
					eprintln('IDNA ${count} strict=${strict}: rejected ${fields[0]}; expected=${expected}')
				}
				failures++
			}
		}
		count++
	}
	assert count > 6000
	assert failures == 0, failures.str()
}
