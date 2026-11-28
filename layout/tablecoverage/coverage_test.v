module tablecoverage

fn test_table_cell_coverage_preserves_spans_and_gaps_across_worker_ranges() {
	rows := 77
	columns := 6
	mut placements := [CellSpan{row: 0, column: 1, row_span: 400}]
	for row in 1 .. rows {
		if row % 3 == 0 {
			placements << CellSpan{
				row: row
				column: 2
				column_span: 3
				row_span: 5
			}
		} else {
			placements << CellSpan{row: row, column: 4, column_span: 2}
		}
	}
	actual := build(placements, rows, columns)
	assert actual.len == rows * columns
	for row in 0 .. rows {
		for column in 0 .. columns {
			mut expected := false
			for placement in placements {
				if row >= placement.row && row < placement.row + placement.row_span
					&& column >= placement.column && column < placement.column + placement.column_span {
					expected = true
					break
				}
			}
			assert actual[row * columns + column] == expected
		}
	}
}

fn test_table_cell_coverage_checks_the_grid_size_before_multiplying() {
	assert use_dense_coverage(1024, 1024)
	assert !use_dense_coverage(1025, 1024)
	assert !use_dense_coverage(max_int, max_int)
	assert !use_dense_coverage(32, 0)
	assert !use_dense_coverage(0, 16)
	assert !use_dense_coverage(31, 16)
}
