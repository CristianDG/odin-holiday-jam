package main

import "game"
import "core:fmt"
import "base:runtime"

HOT_RELOAD :: #config(HOT_RELOAD, false)

import "platform"

main :: proc() {
  when ODIN_OS != .JS {
    main_native()
  } else when ODIN_OS == .JS {
    main_js()
  }
}

main_js :: proc() {
  game.init()
}

main_native :: proc() {
  when HOT_RELOAD {
    main_hot_reload()
  } else {
    main_static()
  }
}

main_static :: proc() {
  game.init()

  frame_start : u64
  frame_end   : u64

  frame_start = platform.get_ticks()
  for {
    frame_end = platform.get_ticks()
    if frame_end - frame_start > 17 {
      dt := f64(frame_end - frame_start) / 1000
      if !game.step(dt) do break
      frame_start = frame_end
    }
  }

  game.deinit()
}
