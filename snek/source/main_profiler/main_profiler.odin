/*
A build that is identical to the release one, but with profiling enabled.
https://gravitymoth.com/spall/spall-web.html - for viewing the trace file.
*/

package main_profiler

import "base:runtime"
import "core:log"
import "core:os"
import "core:path/filepath"
import "core:prof/spall"
import "core:sync"

import game ".."

USE_TRACKING_ALLOCATOR :: #config(USE_TRACKING_ALLOCATOR, false)

spall_ctx: spall.Context
@(thread_local)
spall_buffer: spall.Buffer

main :: proc() {
	// Set working dir to dir of executable.
	exe_path := os.args[0]
	exe_dir := filepath.dir(string(exe_path), context.temp_allocator)
	os.set_current_directory(exe_dir)

	when USE_TRACKING_ALLOCATOR {
		default_allocator := context.allocator
		tracking_allocator: Tracking_Allocator
		tracking_allocator_init(&tracking_allocator, default_allocator)
		context.allocator = allocator_from_tracking_allocator(&tracking_allocator)
	}

	mode: int = 0
	when ODIN_OS == .Linux || ODIN_OS == .Darwin {
		mode = os.S_IRUSR | os.S_IWUSR | os.S_IRGRP | os.S_IROTH
	}

	logh, logh_err := os.open("log.txt", (os.O_CREATE | os.O_TRUNC | os.O_RDWR), mode)

	if logh_err == os.ERROR_NONE {
		os.stdout = logh
		os.stderr = logh
	}

	logger :=
		logh_err == os.ERROR_NONE ? log.create_file_logger(logh) : log.create_console_logger()
	context.logger = logger

	spall_ctx = spall.context_create("trace.spall")
	buffer_backing := make([]u8, spall.BUFFER_DEFAULT_SIZE)
	spall_buffer = spall.buffer_create(buffer_backing, u32(sync.current_thread_id()))

	game.game_init_window()
	game.game_init()

	window_open := true
	for window_open {
		window_open = game.game_update()

		when USE_TRACKING_ALLOCATOR {
			for b in tracking_allocator.bad_free_array {
				log.error("Bad free at: %v", b.location)
			}

			clear(&tracking_allocator.bad_free_array)
		}

		free_all(context.temp_allocator)
	}

	free_all(context.temp_allocator)
	game.game_shutdown()
	game.game_shutdown_window()

	spall.context_destroy(&spall_ctx)
	delete(buffer_backing)
	spall.buffer_destroy(&spall_ctx, &spall_buffer)

	if logh_err == os.ERROR_NONE {
		log.destroy_file_logger(logger)
	}

	when USE_TRACKING_ALLOCATOR {
		for key, value in tracking_allocator.allocation_map {
			log.error("%v: Leaked %v bytes\n", value.location, value.size)
		}

		tracking_allocator_destroy(&tracking_allocator)
	}
}

// make game use good GPU on laptops etc

@(export)
NvOptimusEnablement: u32 = 1

@(export)
AmdPowerXpressRequestHighPerformance: i32 = 1

// Automatic profiling of every procedure:
@(instrumentation_enter)
spall_enter :: proc "contextless" (
	proc_address, call_site_return_address: rawptr,
	loc: runtime.Source_Code_Location,
) {
	spall._buffer_begin(&spall_ctx, &spall_buffer, "", "", loc)
}

@(instrumentation_exit)
spall_exit :: proc "contextless" (
	proc_address, call_site_return_address: rawptr,
	loc: runtime.Source_Code_Location,
) {
	spall._buffer_end(&spall_ctx, &spall_buffer)
}
