module buildtools

import os
import time

#include <io.h>
#include <sys/locking.h>

fn C._locking(i32, i32, i32) i32
fn C._lseek(i32, i32, i32) i32

struct Lock {
mut:
	file os.File
	held bool
}

fn acquire(path string, nonblocking bool) !Lock {
	mkdir(os.dir(path))!
	mut file := os.open_file(path, 'a', 0o600)!
	for {
		C._lseek(file.fd, 0, 0)
		if C._locking(file.fd, 2, 1) == 0 { return Lock{ file: file, held: true } }
		if nonblocking {
			file.close()
			return error('Lock busy: ${path}')
		}
		time.sleep(50 * time.millisecond)
	}
	return error('Cannot lock ${path}')
}

fn (mut held_lock Lock) release() {
	if held_lock.held {
		C._lseek(held_lock.file.fd, 0, 0)
		C._locking(held_lock.file.fd, 0, 1)
		held_lock.file.close()
		held_lock.held = false
	}
}

fn exchange_directories(source string, target string) ! {
	return error('Atomic application-directory publication requires macOS')
}
