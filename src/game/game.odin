package game

import "core:fmt"
import "core:math/rand"
import platform "../platform"

// TODO: Game_State struct
Game_State :: struct {}

counter := u32(0)
shader := u32(0)

exit := false
@export
init :: proc() {
  platform.init("screen", 640, 360)

  shader_ok: bool
  shader, shader_ok = platform.create_shader(
    platform.VERTEX_SHADER_SOURCE,
    platform.FRAGMENT_SHADER_SOURCE,
  )
  if !shader_ok {
    fmt.println("error when creating shader")
    exit = true
  }
}

@export
deinit :: proc() {
  platform.deinit()
}

draw_game :: proc() {
  platform.clear_color({255, 0, 0, 255})
}

update_cooldown := f64(0)

@export
step :: proc(dt: f64) -> (should_continue: bool) {

  draw_game()
  return true
}

