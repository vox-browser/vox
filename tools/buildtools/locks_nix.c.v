module buildtools

import os

#include <sys/file.h>
#include <fcntl.h>
#include <sys/stat.h>
#include <unistd.h>
#include <signal.h>

fn C.flock(i32, i32) i32
fn C.fcntl(i32, i32, i32) i32
fn C.kill(i32, i32) i32
fn C.renameatx_np(i32, &char, i32, &char, u32) i32
fn C.setsid() i32

struct Lock {
mut:
	file os.File
	held bool
}

fn acquire(path string, nonblocking bool) !Lock {
	mkdir(os.dir(path))!
	mut file := os.open_file(path, 'a', 0o600)!
	// Workers and compilers must not inherit the parent's lock ownership.
	if C.fcntl(file.fd, 2, 1) != 0 {
		file.close()
		return error('Cannot set close-on-exec on build lock: ${path}')
	}
	if C.flock(file.fd, i32(2 | if nonblocking { 4 } else { 0 })) != 0 {
		file.close()
		return error('Lock busy: ${path}')
	}
	return Lock{ file: file, held: true }
}

fn (mut held_lock Lock) release() {
	if held_lock.held {
		C.flock(held_lock.file.fd, 8)
		held_lock.file.close()
		held_lock.held = false
	}
}

fn exchange_directories(source string, target string) ! {
	if !exists(target) {
		os.rename(source, target)!
		return
	}
	$if macos {
		if C.renameatx_np(-2, source.str, -2, target.str, 2) != 0 {
			return error('Atomic application-directory publication failed')
		}
	} $else {
		return error('Atomic application-directory publication requires macOS')
	}
}
