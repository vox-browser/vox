module jpegxl

import encoding.hex

const source_predictor_names = ['Zero', 'West', 'North', 'AverageWestAndNorth', 'Select', 'Gradient',
	'Weighted', 'NorthEast', 'NorthWest', 'WestWest', 'AverageWestAndNorthWest',
	'AverageNorthAndNorthWest', 'AverageNorthAndNorthEast', 'AverageAll']

fn tree_source_result(mut reader BitReader, limit int) !string {
	tree := reader.read_modular_tree(limit)!
	mut nodes := []string{}
	for node in tree.nodes {
		nodes << if node.is_leaf {
			'Leaf { predictor: ${source_predictor_names[int(node.predictor)]}, offset: ${node.offset}, multiplier: ${node.multiplier}, id: ${node.context} }'
		} else {
			'Split { property: ${node.property}, val: ${node.threshold}, left: ${node.left}, right: ${node.right} }'
		}
	}
	hist := tree.histograms
	count := hist.num_histograms()
	mut map_ := []string{}
	for i in 0 .. (tree.nodes.len + 1) / 2 { map_ << hist.map_context_to_cluster(i)!.str() }
	mut single := []string{}
	for i in 0 .. count { single << if value := hist.single_symbol(i) { value.str() } else { '-' } }
	mut symbols := SymbolReader.new(hist, mut reader, none)!
	mut output := []string{}
	for i in 0 .. 8 {
		output << symbols.read_unsigned(hist, i % ((tree.nodes.len + 1) / 2), mut reader)!.str()
	}
	mut valid := 1
	symbols.check_final_state(hist, reader) or { valid = 0 }
	return 'Tree[[${nodes.join(', ')}]]|${tree.num_properties}|${count},${hist.max_num_bits()!},${if hist.is_rle() {
		1
	} else {
		0
	}},${if hist.can_use_config_420_fast_path() { 1 } else { 0 }}|${map_.join(',')}|${single.join(',')}|${output.join(',')}|${valid}'
}

fn test_modular_tree_matches_source_nodes_histograms_and_consumed_bits() {
	mut count := 0
	mut parsed := 0
	for line in $embed_file('testdata/modular-tree.tsv').to_string().split_into_lines() {
		if line == '' || line.starts_with('#') { continue }
		f := line.split('\t')
		assert f.len == 4
		mut reader := new_bit_reader(hex.decode(f[1])!)
		result := tree_source_result(mut reader, f[0].int()) or { 'err' }
		assert result == f[3], 'Modular tree source case ${count}'
		assert reader.position == f[2].int(), 'Modular tree position ${count}: ${reader.position} expected ${f[2]}'
		if result != 'err' { parsed++ }
		count++
	}
	assert count == 747
	assert parsed == 488
}

fn tree_test_chain(depth int) []ModularTreeNode {
	mut nodes := []ModularTreeNode{cap: 2 * depth + 1}
	for i in 0 .. depth {
		nodes << ModularTreeNode{ property: 0, threshold: i32(i - 1024), left: u32(i + 1), right: u32(depth + 1 + i) }
	}
	for i in 0 .. depth + 1 {
		nodes << ModularTreeNode{ is_leaf: true, multiplier: 1, context: u32(i) }
	}
	return nodes
}

fn test_modular_tree_ranges_depth_and_traversal_are_bounded() {
	validate_modular_tree([], 0)!
	validate_modular_tree(tree_test_chain(2048), 1)!
	mut rejected := false
	validate_modular_tree(tree_test_chain(2049), 1) or { rejected = true }
	assert rejected
	nodes := [ModularTreeNode{ threshold: 10, left: 1, right: 2 },
		ModularTreeNode{ is_leaf: true, predictor: .west, offset: -1, multiplier: 2, context: 0 },
		ModularTreeNode{ is_leaf: true, predictor: .north, multiplier: 3, context: 1 }]
	validate_modular_tree(nodes, 1)!
	tree := ModularTree{ nodes: nodes }
	assert tree.walk([i32(11)])!.predictor == .west
	assert tree.walk([i32(10)])!.predictor == .north
	if _ := tree.walk([]) {
		assert false
	}
	if _ := ModularTree{}.walk([]) {
		assert false
	}
	cycle := ModularTree{ nodes: [ModularTreeNode{ threshold: 0, left: 0, right: 0 }] }
	if _ := cycle.walk([i32(1)]) {
		assert false
	}
	for bad in [
		[ModularTreeNode{ threshold: 2147483647, left: 1, right: 1 }, nodes[1]],
		[ModularTreeNode{ property: 1, left: 1, right: 1 }, nodes[1]],
		[ModularTreeNode{ left: 99, right: 99 }],
	] {
		rejected = false
		validate_modular_tree(bad, 1) or { rejected = true }
		assert rejected
	}
	for limit in [-1, 131071] {
		mut reader := new_bit_reader([])
		if _ := reader.read_modular_tree(limit) {
			assert false
		}
		assert reader.position == 0
	}
}
