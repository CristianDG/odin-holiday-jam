#+build js
package platform_functions

/*
TODO:
  - deinit proc
  - get window dimensions
  - set window dimensions
*/

import "base:runtime"
import "core:fmt"
import "core:mem"
import "core:sys/wasm/js"
import webgl "vendor:wasm/WebGL"
import glm "core:math/linalg/glsl"

foreign import platform "platform_functions"

@(default_calling_convention="contextless")
foreign platform {
	_get_platform_name :: proc() ---
  _get_ticks :: proc() -> u64 ---
  _resize_canvas :: proc(id: string, width, height: i32) ---
}

temp_key_state: Key_State

@(private="file")
key_callback :: proc(e: js.Event) {
  add := bool(uintptr(e.user_data))
  raw_key := e.data.key.key

  if len(raw_key) == 1 {
    key := rune(e.data.key.key[0])
    if key >= 'a' && key <= 'z' do key -= 32
    switch key {
    case ' ': change_key_state(&temp_key_state, .Space, add)
    case 'A'..='Z': change_key_state(&temp_key_state, Key(key), add)
    case: fmt.println("unknown key", key)
    }
  } else { 
    fmt.printfln("unhandled case '%v'", raw_key)
  }
}

@(private="file")
reset_keys :: proc(e: js.Event) {
  current_key_state = {}
}

_init :: proc "c" (name: string, width, height: i32) {
  context = runtime.default_context()
  id := "canvas"
  ok := webgl.CreateCurrentContextById(id, {})
  _resize_canvas(id, width, height)
  webgl.Viewport(0, 0, width, height)
  js.add_event_listener(id, .Key_Down, rawptr(uintptr(1)), key_callback)
  js.add_event_listener(id, .Key_Up, rawptr(uintptr(0)), key_callback)
  js.add_event_listener(id, .Focus_Out, rawptr(uintptr(0)), reset_keys)
}


@export clear_color :: proc "c" (c: Color) {
  color := u8color_to_f32color(c)
  webgl.Clear(webgl.COLOR_BUFFER_BIT)
  webgl.ClearColor(color.r, color.g, color.b, color.a)
}

create_shader :: proc (vertex_source, fragment_source: string) -> (u32, bool) {
  program, ok := webgl.CreateProgramFromStrings({vertex_source}, {fragment_source})
  return u32(program), ok
}

_update_key_state :: proc() {
  current_key_state = temp_key_state
}

_alloc_memory_buffer :: proc(bytes: u64) -> (buffer: []byte, err: mem.Allocator_Error) {
  page_divisible := bytes % js.PAGE_SIZE == 0
  pages := (int(bytes) / js.PAGE_SIZE) + (0 if page_divisible else 1)
  return js.page_alloc(pages)
}

// TODO:
deinit :: proc() {
  // webgl.DeleteProgram(shader)
}

_end_drawing   :: proc() {
  @static created := false
  @static vbo : webgl.Buffer
  @static vao : webgl.VertexArrayObject

  if !created {
    created = true
    vao = webgl.CreateVertexArray()

    vbo = webgl.CreateBuffer()
  }
  webgl.BindVertexArray(vao)
  webgl.BindBuffer(webgl.ARRAY_BUFFER, vbo)
  webgl.BufferData(webgl.ARRAY_BUFFER, size_of(vertices[0]) * int(current_vertex), &vertices[0], webgl.DYNAMIC_DRAW)

  webgl.VertexAttribPointer(0, 3, webgl.FLOAT, false, size_of(Vertex), offset_of(Vertex, pos))
  webgl.EnableVertexAttribArray(0)
  webgl.VertexAttribPointer(1, 4, webgl.FLOAT, false, size_of(Vertex), offset_of(Vertex, color))
  webgl.EnableVertexAttribArray(1)

  shader := global_shader
  program := webgl.Program(shader)
  webgl.UseProgram(program)
  {
    mpv_loc := webgl.GetUniformLocation(program, "u_mvp")
    webgl.UniformMatrix4fv(mpv_loc, camera_mvp)
  }
  webgl.DrawArrays(webgl.TRIANGLES, 0, int(current_vertex))
}

global_shader: u32


