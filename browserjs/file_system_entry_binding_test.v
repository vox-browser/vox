module browserjs

import dom
import entriesapi
import html
import libjs

fn entry_record_fixture(url string) (&Runtime, &dom.Document) {
	document := html.parse_document_with_url('<!doctype html><body>Entries</body>', dom.URL{ value: url })
	_ = html.WindowModel.create_top_level(document, none, '') or { panic(err) }
	mut runtime := Runtime.create()
	runtime.bind_scripting_environment(unsafe { &html.EnvironmentSettingsObject(document.relevant_settings_object()) }) or { panic(err) }
	runtime.install_event_target_binding() or { panic(err) }
	return runtime, document
}

fn entry_record_export(mut runtime Runtime, name string, value voidptr) ! {
	runtime.define_value_host_function(name, fn [value] (_ voidptr, _ []voidptr) !voidptr { return value })!
}

fn test_native_file_system_entry_registry_caches_actual_file_and_directory_records() {
	$if !darwin { return }
	mut runtime, mut document := entry_record_fixture('https://entry-records.example/')
	defer {
		runtime.close()
		document.finalize()
	}
	name := libjs.utf16_string_from_code_units([u16(`n`), 0xd800, 0, 0xdc00, 0xd83d, 0xde00])
	file := entriesapi.FileSystemEntry.create_utf16(.file, name)
	directory := entriesapi.FileSystemEntry.create_utf16(.directory, name)
	wrapper := runtime.javascript_file_system_entry(file)!
	assert runtime.javascript_file_system_entry(file)! == wrapper
	assert voidptr(runtime.native_file_system_entry(wrapper)!) == voidptr(file)
	dir_wrapper := runtime.javascript_file_system_entry(directory)!
	assert dir_wrapper != wrapper
	assert voidptr(runtime.native_file_system_entry(dir_wrapper)!) == voidptr(directory)
	entry_record_export(mut runtime, '__entryRecordFile', wrapper)!
	entry_record_export(mut runtime, '__entryRecordDirectory', dir_wrapper)!
	assert runtime.evaluate_host(r'(()=>{const a=__entryRecordFile(),b=__entryRecordDirectory(),p=FileSystemEntry.prototype;return a instanceof FileSystemEntry&&b instanceof FileSystemEntry&&Object.getPrototypeOf(a)===p&&Object.getPrototypeOf(b)===p&&a.isFile&&!a.isDirectory&&!b.isFile&&b.isDirectory&&a.name==="n\ud800\u0000\udc00\ud83d\ude00"&&b.name===a.name&&!Reflect.set(a,"name","changed")&&!Reflect.set(b,"isFile",true)&&a.name===b.name&&Object.keys(a).length===0&&Object.getOwnPropertyNames(p).sort().join(",")==="constructor,isDirectory,isFile,name"})()')! == 'true'
	second := entriesapi.FileSystemEntry.create_utf16(.file, name)
	assert voidptr(second) != voidptr(file)
	assert runtime.javascript_file_system_entry(second)! != wrapper
	assert runtime.libjs_vm().execution_context_stack().len == 0
}

fn test_native_file_system_entry_late_identity_rejects_foreign_records_and_clears_on_close() {
	$if !darwin { return }
	mut runtime := Runtime.create()
	defer { runtime.close() }
	runtime.install_event_target_binding()!
	entry := entriesapi.FileSystemEntry.create(.directory, '目录')
	wrapper := runtime.javascript_file_system_entry(entry)!
	entry_record_export(mut runtime, '__entryLateRecord', wrapper)!
	assert runtime.evaluate_host('typeof FileSystemEntry==="undefined"&&Object.prototype.toString.call(__entryLateRecord())==="[object FileSystemEntry]"')! == 'true'
	runtime.evaluate_host('globalThis.entryActualGlobal=globalThis;globalThis.entryOriginalTypeError=TypeError;globalThis.TypeError=function AuthorTypeError(){throw 0};globalThis={};0')!
	mut document := html.parse_document_with_url('<!doctype html><body>Late entries</body>', dom.URL{ value: 'http://entry-late.example/' })
	defer { document.finalize() }
	_ = html.WindowModel.create_top_level(document, none, '')!
	runtime.bind_scripting_environment(unsafe { &html.EnvironmentSettingsObject(document.relevant_settings_object()) })!
	runtime.install_event_target_binding()!
	assert runtime.javascript_file_system_entry(entry)! == wrapper
	assert runtime.evaluate_host('entryActualGlobal.FileSystemEntry===FileSystemEntry&&globalThis.FileSystemEntry===undefined&&__entryLateRecord() instanceof FileSystemEntry&&__entryLateRecord().isDirectory&&!__entryLateRecord().isFile&&__entryLateRecord().name==="目录"&&Object.getPrototypeOf(__entryLateRecord())===FileSystemEntry.prototype&&(()=>{try{new FileSystemEntry();return false}catch(error){return error instanceof entryOriginalTypeError}})()')! == 'true'
	mut other, mut other_document := entry_record_fixture('https://entry-foreign.example/')
	defer {
		other.close()
		other_document.finalize()
	}
	foreign := other.javascript_file_system_entry(entry)!
	assert foreign != wrapper
	assert voidptr(other.native_file_system_entry(foreign)!) == voidptr(entry)
	runtime.native_file_system_entry(foreign) or {
		if err is JavaScriptValueException {
			entry_record_export(mut runtime, '__entryForeignError', err.value)!
			assert runtime.evaluate_host('(()=>{const error=__entryForeignError();return error instanceof entryOriginalTypeError&&error.message==="Not an object of type FileSystemEntry"})()')! == 'true'
			runtime.release_javascript_value(err.value)
		} else {
			assert false, 'native entry brand must preserve an actual JavaScript TypeError'
		}
		mut binding := runtime.event_binding()!.file_system_entry_binding
		assert binding.entries.len == 1 && binding.wrappers.len == 1
		runtime.close()
		assert binding.entries.len == 0 && binding.wrappers.len == 0
		assert runtime.protected_values_.len == 0
		runtime.native_file_system_entry(wrapper) or {
			assert err.msg() == 'TypeError: FileSystemEntry binding is closed'
			assert other.native_file_system_entry(foreign)! == entry
			return
		}
		assert false, 'closed native entry registry must reject'
		return
	}
	assert false, 'foreign wrapper must not alias the owning entry registry'
}
