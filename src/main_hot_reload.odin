#+build linux
package main

import "core:fmt"
import "core:mem"
import "core:mem/virtual"
import "core:dynlib"
import "core:log"
import "core:os"
import "core:time"
import "base:intrinsics"

import "third_party:hot_reload"


Lib :: struct {
  step : proc(f64) -> bool,
  start_game : proc(),
  deinit : proc(),

  game_memory : proc() -> rawptr,
  game_memory_size : proc() -> u32, 
  init_memory : proc(),
  deinit_memory : proc(),
  reload_memory : proc(memory: rawptr),

  __last_time_modified : time.Time,
  __swap: bool,
  __handle : dynlib.Library,
}

main_hot_reload :: proc() {
  context.logger = log.create_console_logger()

  log.info("RUNNING WITH HOT RELOAD")

  // FIXME: colocar tracking allocator em outro lugar ou algo assim :+1:
  tracking_allocator : mem.Tracking_Allocator
  mem.tracking_allocator_init(&tracking_allocator, context.allocator)
  context.allocator = mem.tracking_allocator(&tracking_allocator)

  reset_tracking_allocator :: proc(a: ^mem.Tracking_Allocator) -> bool {
    leaks := false

    for k, v in a.allocation_map {
      log.infof("%v leaked %v bytes\n", v.location, v.size)
      leaks = true
    }

    for v in a.bad_free_array {
      log.errorf("%v badly freed ptr %v\n", v.location, v.memory)
      leaks = true
    }

    mem.tracking_allocator_clear(a)
    return leaks
  }
  defer reset_tracking_allocator(&tracking_allocator)

  /// real thing

  game : Lib

  // _count , ok_game := dynlib.initialize_symbols(&game, "./game.so")
  _, ok_game := hot_reload.load_lib(&game, "./game.so")
  if !ok_game {
    log.errorf("could't load lib")
    return
  }

  // FIXME(cristiandg): refazer
  /*
  game.start_game()
  memory, memory_size := game.game_memory(), game.game_memory_size()
  for {
    new, ok_game := hot_reload.load_lib(&game, "./game.so")
    if !ok_game do break

    // TODO:
    if new {
      log.debug("new lib found, loading...")

      if memory_size != game.game_memory_size() {
        reset_tracking_allocator(&tracking_allocator)
        game.deinit_memory()

        game.init_memory()
        memory = game.game_memory()
      }

      game.reload_memory(memory)
      memory, memory_size = game.game_memory(), game.game_memory_size()
    }

    should_close := game.step(memory)
    if should_close do break
  }
  game.deinit()
  game.deinit_memory()
  */
}
