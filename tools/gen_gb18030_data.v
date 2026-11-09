// SPDX-License-Identifier: BSD-2-Clause
module main

import flag
import os
import tools.gb18030gen

fn main() {
	mut args := flag.new_flag_parser(os.args)
	args.application('gen_gb18030_data')
	args.description('Generate the GB18030 tables from pinned WHATWG indexes using V.')
	args.skip_executable()
	directory := args.string('index-dir', 0, os.join_path(@VMODROOT, 'encoding/indices'), 'Pinned index directory')
	output := args.string('output', `o`, os.join_path(@VMODROOT, 'encoding/gb18030_data.v'), 'Generated V source')
	check := args.bool('check', 0, false, 'Check the output without changing it')
	remaining := args.finalize() or {
		eprintln(err)
		exit(1)
	}
	if remaining.len > 0 {
		eprintln('Unexpected arguments: ${remaining}')
		exit(1)
	}
	index, ranges := gb18030gen.read_pinned_indexes(directory) or {
		eprintln(err)
		exit(1)
	}
	source := gb18030gen.generate(index, ranges) or {
		eprintln(err)
		exit(1)
	}
	if check {
		current := os.read_file(output) or {
			eprintln(err)
			exit(1)
		}
		if current != source {
			eprintln('GB18030 generated source differs: ${output}')
			exit(1)
		}
	} else {
		os.write_file(output, source) or {
			eprintln(err)
			exit(1)
		}
	}
	println('${output}: 23940 two-byte pointers; pinned WHATWG ranges and encoder index verified')
}
