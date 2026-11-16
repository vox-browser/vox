module libjs

$if test {
	__global native_primitive_ops_disabled bool
	pub fn set_native_primitive_ops_for_testing(enabled bool) { native_primitive_ops_disabled = !enabled }
}

fn use_native_primitive_ops() bool {
	$if test { if native_primitive_ops_disabled { return false } }
	return true
}

// Disk entries may be shared by builds made with different V integer/array
// layouts. Source identity alone does not capture compiler layout decisions.
fn native_primitive_layout_identity() string {
	sample := PrimitiveString{}
	return '${sizeof(int)}:${uint(&sample.utf16.data.len) - uint(&sample)}:${uint(&sample.utf16.data.data) - uint(&sample)}'
}

// Generated code reads immutable UTF-16 storage using offsets from this exact
// compiler layout. memcpy avoids alignment/aliasing assumptions. No realm cell
// address is embedded in the library; every string comes from its current frame.
fn native_primitive_helpers() string {
	sample := PrimitiveString{}
	length_offset := uint(&sample.utf16.data.len) - uint(&sample)
	data_offset := uint(&sample.utf16.data.data) - uint(&sample)
	return '
#include <string.h>
static int${sizeof(int) * 8}_t string_length(NV v) {
 int${sizeof(int) * 8}_t n; memcpy(&n,(char*)v.cell+${length_offset},sizeof(n)); return n;
}
static int string_equal(NV a,NV b) {
 if(a.cell==b.cell) return 1;
 int${sizeof(int) * 8}_t n=string_length(a);
 if(n!=string_length(b)) return 0;
 if(!n) return 1;
 void *x,*y; memcpy(&x,(char*)a.cell+${data_offset},sizeof(x)); memcpy(&y,(char*)b.cell+${data_offset},sizeof(y));
 return memcmp(x,y,(size_t)n*sizeof(uint16_t))==0;
}
static int primitive_equal(NV a,NV b) {
 if(number(a)&&number(b)) return a.number==b.number;
 if(a.tag!=b.tag) return 0;
 switch(a.tag) {
 case ${int(ValueTag.undefined)}: case ${int(ValueTag.null)}: return 1;
 case ${int(ValueTag.boolean)}: return a.number==b.number;
 case ${int(ValueTag.string)}: return string_equal(a,b);
 case ${int(ValueTag.symbol)}: case ${int(ValueTag.object)}: return a.cell==b.cell;
 default: return 0;
 }
}
'
}

fn native_primitive_equality(instruction Instruction, executable &Executable, left string) !string {
	right := 'v[${native_slot(instruction.rhs, executable)!}]'
	dst := native_slot(instruction.dst, executable)!
	mut code := 'if(${right}.tag==${int(ValueTag.empty)} || ${left}.tag==${int(ValueTag.bigint)} || ${right}.tag==${int(ValueTag.bigint)}) goto SLOW;\n'
	loose := instruction.op in [.loose_equals, .loose_inequals]
	nullish := '((${left}.tag==${int(ValueTag.null)} || ${left}.tag==${int(ValueTag.undefined)}) && (${right}.tag==${int(ValueTag.null)} || ${right}.tag==${int(ValueTag.undefined)}))'
	if loose {
		// Cross-type coercion (including author hooks) remains in the VM.
		code += 'if(${left}.tag!=${right}.tag && !(number(${left})&&number(${right})) && !${nullish}) goto SLOW;\n'
	}
	negate := if instruction.op in [.strict_inequals, .loose_inequals] { '!' } else { '' }
	equal := if loose { '(${nullish} || primitive_equal(${left},${right}))' } else { 'primitive_equal(${left},${right})' }
	return code + 'BUDGET v[${dst}]=boolean(${negate}${equal});'
}
