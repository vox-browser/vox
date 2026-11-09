module jpegxl

import crypto.sha256
import encoding.binary
import encoding.hex

fn coefficient_order_digest(orders []Permutation) string {
	mut words := 0
	for order in orders { words += order.values.len + 1 }
	mut data := []u8{len: words * 4}
	mut offset := 0
	for order in orders {
		binary.little_endian_put_u32_at(mut data, u32(order.values.len), offset)
		offset += 4
		for value in order.values {
			binary.little_endian_put_u32_at(mut data, value, offset)
			offset += 4
		}
	}
	return sha256.sum(data).hex()
}

fn test_natural_coefficient_orders_match_every_source_index_for_all_shapes() {
	mut count := 0
	mut indices := 0
	for line in $embed_file('testdata/natural-coefficient-orders.tsv').to_string().split_into_lines() {
		if line == '' || line.starts_with('#') { continue }
		f := line.split('\t')
		assert f.len == 2
		order := natural_coefficient_order(f[0].int())!
		assert order == f[1].split(',').map(it.u32()), 'natural order ${count}'
		indices += order.len
		count++
	}
	assert count == 13
	assert indices == 131328
}

fn test_entropy_coefficient_orders_match_complete_source_vectors_and_positions() {
	mut count := 0
	mut successes := 0
	mut source_overreads := 0
	for line in $embed_file('testdata/coefficient-orders.tsv').to_string().split_into_lines() {
		if line == '' || line.starts_with('#') { continue }
		f := line.split('\t')
		assert f.len == 4
		data := hex.decode(f[1])!
		mut reader := new_bit_reader(data)
		actual := if orders := reader.read_coefficient_orders(u32(f[0].u64())) {
			assert orders.len == 39
			successes++
			coefficient_order_digest(orders)
		} else {
			'err'
		}
		assert actual == f[3], 'coefficient orders ${count}'
		if f[2].int() <= data.len * 8 {
			assert reader.position == f[2].int(), 'coefficient cursor ${count}'
		} else {
			// The source's optimistic reads may report an EOF cursor past the input.
			assert actual == 'err'
			source_overreads++
		}
		count++
	}
	assert count == 256
	assert successes == 153
	assert source_overreads == 60
}

fn test_coefficient_order_shapes_and_component_ownership() {
	for shape in [-1, 13] {
		if _ := natural_coefficient_order(shape) {
			assert false
		}
	}
	mut reader := new_bit_reader([]u8{})
	mut orders := reader.read_coefficient_orders(0)!
	assert reader.position == 0
	assert orders[0].values[1] == 1 && orders[1].values[1] == 1
	orders[0].values[1] = 63
	assert orders[1].values[1] == 1
	assert orders[2].values[1] == 1
	second := reader.read_coefficient_orders(0)!
	assert second[0].values[1] == 1
	if _ := reader.read_coefficient_orders(1) {
		assert false
	}
	mut high := new_bit_reader([]u8{})
	// A nonzero mask with only unknown high bits still carries the entropy header.
	if _ := high.read_coefficient_orders(0x80000000) {
		assert false
	}
}
