module browserjs

import webidl
import webassembly

fn test_actual_engine_table64_source_unsigned_bounds_and_original_coercion_errors() {
	$if !darwin { return }
	mut runtime := Runtime.create()
	defer { runtime.close() }
	owner_handle := voidptr(runtime)
	runtime.define_value_host_function('__actualTable64Address', fn [owner_handle] (_ voidptr, arguments []voidptr) !voidptr {
		mut owner := unsafe { &Runtime(owner_handle) }
		input := owner.webidl_value(arguments[0])!
		limit := webassembly.address_value_to_u64(input, .i64) or {
			return owner.actual_javascript_exception(owner.binding_exception_value(err))
		}
		return owner.javascript_bigint(webassembly.table_limit_to_js_value(limit, .i64))
	})!
	assert runtime.evaluate_host(r'{const values=[0n,9223372036854775808n,18446744073709551615n,"0xffffffffffffffff",true,false];const expected=[0n,9223372036854775808n,18446744073709551615n,18446744073709551615n,1n,0n];values.every((value,index)=>{const result=__actualTable64Address(value);return typeof result==="bigint"&&result===expected[index]})}')! == 'true'
	assert runtime.evaluate_host(r'{let hints=0;const result=__actualTable64Address({[Symbol.toPrimitive](hint){if(hint!=="number")throw "wrong hint";hints++;return 18446744073709551615n},valueOf(){throw "wrong hook"}});result===18446744073709551615n&&hints===1}')! == 'true'
	assert runtime.evaluate_host(r'{const inputs=[-1n,-18446744073709551616n,18446744073709551616n,18446744073709551617n,340282366920938463463374607431768211456n,1,null,undefined,Symbol()];inputs.every(value=>{try{__actualTable64Address(value);return false}catch(error){return error instanceof TypeError}})}')! == 'true'
	assert runtime.evaluate_host(r'{let gets=0;const reason={};const throwing={get [Symbol.toPrimitive](){gets++;throw reason}};let caught;try{__actualTable64Address(throwing)}catch(error){caught=error}caught===reason&&gets===1}')! == 'true'
	assert runtime.evaluate_host(r'{let calls=0;const overflowing={[Symbol.toPrimitive](hint){calls++;return "18446744073709551616"}};let caught;try{__actualTable64Address(overflowing)}catch(error){caught=error}caught instanceof TypeError&&calls===1&&caught.message==="Table size is too large"}')! == 'true'
	assert runtime.evaluate_host(r'{let caught;try{__actualTable64Address("1.5")}catch(error){caught=error}caught instanceof SyntaxError}')! == 'true'
}
