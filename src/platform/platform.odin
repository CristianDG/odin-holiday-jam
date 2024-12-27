package platform_functions

import "core:fmt"
import "core:mem"
import glm "core:math/linalg/glsl"

VERTEX_SHADER_SOURCE :: #load("../shaders/vs.glsl", string)
FRAGMENT_SHADER_SOURCE :: #load("../shaders/fs.glsl", string)

Key :: enum u32 {
  Unknown,
  A = 'A',
  B = 'B',
  C = 'C',
  D = 'D',
  E = 'E',
  F = 'F',
  G = 'G',
  H = 'H',
  I = 'I',
  J = 'J',
  K = 'K',
  L = 'L',
  M = 'M',
  N = 'N',
  O = 'O',
  P = 'P',
  Q = 'Q',
  R = 'R',
  S = 'S',
  T = 'T',
  U = 'U',
  V = 'V',
  W = 'W',
  X = 'X',
  Y = 'Y',
  Z = 'Z',
  Space,
  Escape,
  Alt_Left,
  Alt_Right,
  Mouse_Left,
  Mouse_Right,
  Mouse_Middle,
  Mouse_4,
  Mouse_5,
}

Key_State :: bit_set[Key]

// TODO: colocar em uma struct
previous_key_state, current_key_state : Key_State

// TODO: colocar em uma struct
// TODO: trocar para `render_`
window_width, window_height: i32

is_key_down :: proc(k: Key) -> bool {
  return k in current_key_state
}

get_render_size :: proc() -> (width: i32, height: i32) {
  return window_width, window_height
}

is_key_pressed :: proc(k: Key) -> bool {
  res := k in current_key_state && k not_in previous_key_state
  // fmt.println(k, current_key_state, k in current_key_state, previous_key_state, k not_in previous_key_state, res)
  return res
}

camera_mvp : glm.mat4

Vertex :: struct {
  pos: [3]f32,
  color: [4]f32,
}

Color :: [4]u8

// TODO: mover para o jogo
vertices := [2048 * 2]Vertex {}
current_vertex := u32(0)


alloc_memory_buffer :: proc(bytes: u64) -> (buffer: []byte, err: mem.Allocator_Error) {
  return _alloc_memory_buffer(bytes)
}

init :: proc(name: string, width, height: i32) {
  window_width, window_height = width, height
  camera_mvp = glm.mat4Ortho3d(0, f32(width), 0, f32(height), -10, 100_000)
  _init(name, width, height)
}

add_vertex :: proc(v: Vertex) {
  assert(current_vertex + 1 < len(vertices))
  vertices[current_vertex] = v
  current_vertex += 1
}

begin_drawing :: proc() {
  current_vertex = 0
}

change_key_state :: proc(key_state: ^Key_State, k: Key, add: bool) {
  if add {
    key_state^ += { k }
  } else {
    key_state^ -= { k }
  }
}

end_drawing :: proc(shader: u32) {
  global_shader = shader
  previous_key_state = current_key_state
  _update_key_state()
  // TODO: passar o shader pro `_end_drawing`
  _end_drawing()
}

get_ticks :: proc() -> u64 {
  return _get_ticks()
}

f32color_to_u8color :: proc "c" (r, g, b, a: f32) -> Color {
  r := u8(r*255)
  g := u8(g*255)
  b := u8(b*255)
  a := u8(a*255)
  return {r, g, b, a}
}

u8color_to_f32color :: proc "c" (color: Color) -> [4]f32 {
  r := f32(color.r)/255
  g := f32(color.g)/255
  b := f32(color.b)/255
  a := f32(color.a)/255
  return {r, g, b, a}
}

draw_triangle :: proc(x, y, size: f32, color: Color) {

  c := u8color_to_f32color(color)

  pos := [3]f32{x, y, 0} + size/2

  // FIXME: multiplicar pela matriz mvp?????
  add_vertex({
    pos = ({-1, -1, 0} * size/2 + pos), // left
    color = c,
  })
  add_vertex({
    pos = ({+1, -1, 0} * size/2 + pos), // right
    color = c,
  })
  add_vertex({
    pos = ({ 0, +1, 0} * size/2 + pos), // middle
    color = c,
  })

}

draw_quad_with_transform :: proc(transform: glm.mat4, color: Color) {
  color := u8color_to_f32color(color)
  transform := transform
  transform *= glm.mat4Scale({.5, .5, 1})
  transform *= glm.mat4Translate({1, 1, 0})

  top_left := Vertex{
    pos   = (transform * [?]f32{-1, +1, 0, 1}).xyz,
    color = color,
  }
  top_right := Vertex{
    pos   = (transform * [?]f32{+1, +1, 0, 1}).xyz,
    color = color,
  }
  bottom_left := Vertex{
    pos   = (transform * [?]f32{-1, -1, 0, 1}).xyz,
    color = color,
  }
  bottom_right := Vertex{
    pos   = (transform * [?]f32{+1, -1, 0, 1}).xyz,
    color = color,
  }

  add_vertex(top_right)
  add_vertex(top_left)
  add_vertex(bottom_left)

  add_vertex(bottom_left)
  add_vertex(bottom_right)
  add_vertex(top_right)
}

draw_quad :: proc(x, y, size_x, size_y: f32, color: Color) {

  transform : glm.mat4 = 1

  transform *= glm.mat4Translate({x, y, 0})
  transform *= glm.mat4Scale({size_x, size_y, 1})

  draw_quad_with_transform(transform, color)

}

// create_buffer

/*
TODO: input handling
*/
