#+build windows, linux
package platform_functions

import "base:runtime"
import "core:fmt"
import "core:mem"
import glm "core:math/linalg/glsl"
import "core:strings"
import sdl "vendor:sdl2"
import gl "vendor:OpenGL"

foreign import platform "bin:native/platform_functions.so"

@export get_platform_name :: proc "contextless" () {
  context = runtime.default_context()
  fmt.println("native")
}


global_window  : ^sdl.Window
global_surface : ^sdl.Surface
global_gl_context : sdl.GLContext

_init :: proc(name: string, width, height: i32) {

  global_window = sdl.CreateWindow(
    strings.unsafe_string_to_cstring(name),
    sdl.WINDOWPOS_UNDEFINED,
    sdl.WINDOWPOS_UNDEFINED,
    width,
    height,
    { .OPENGL },
  )
  if global_window == nil {
    fmt.println("could not create window: %s", sdl.GetError())
  }

  global_gl_context = sdl.GL_CreateContext(global_window)
  sdl.GL_MakeCurrent(global_window, global_gl_context)
  gl.load_up_to(3, 3, sdl.gl_set_proc_address)

}

deinit :: proc() {
  sdl.DestroyWindow(global_window)
  sdl.Quit()
}

create_shader :: proc(vertex_source, fragment_source: string) -> (u32, bool) {
  return gl.load_shaders_source(vertex_source, fragment_source)
}

clear_color :: proc(c: Color) {
  color := u8color_to_f32color(c)
  gl.Clear(gl.COLOR_BUFFER_BIT)
  gl.ClearColor(color.r, color.g, color.b, color.a)
}

_get_ticks :: proc() -> u64 {
  return u64(sdl.GetTicks())
}

_alloc_memory_buffer :: proc(bytes: u64) -> ([]u8, mem.Allocator_Error) {
  unimplemented("WIP")
}

_update_key_state :: proc() {
  event: sdl.Event
  for sdl.PollEvent(&event) {
  add : bool
    if event.type == .KEYDOWN do add = true
    #partial switch event.type {
    case .KEYDOWN, .KEYUP: {
      key := event.key.keysym.sym
      #partial switch key {
      case .ESCAPE: change_key_state(&current_key_state, .Escape, add)
      case .SPACE: change_key_state(&current_key_state, .Space, add)
      case .a..=.z: change_key_state(&current_key_state, Key(u32(key) - 32), add)
      case: fmt.println("unknown key", key)
      }
    }
    }
  }
}


global_shader : u32
_end_drawing :: proc() {
  @static vbo : u32
  @static created := false
  @static vao : u32

  shader := global_shader
  gl.UseProgram(shader)

  if !created {
    created = true
    gl.GenVertexArrays(1, &vao)
    gl.BindVertexArray(vao)

    gl.GenBuffers(1, &vbo)
  }
  gl.BindBuffer(gl.ARRAY_BUFFER, vbo)
  gl.BufferData(gl.ARRAY_BUFFER, size_of(vertices[0]) * int(current_vertex), &vertices[0], gl.DYNAMIC_DRAW)

  gl.VertexAttribPointer(0, 3, gl.FLOAT, false, size_of(Vertex), offset_of(Vertex, pos))
  gl.EnableVertexAttribArray(0)
  gl.VertexAttribPointer(1, 4, gl.FLOAT, false, size_of(Vertex), offset_of(Vertex, color))
  gl.EnableVertexAttribArray(1)

  {
    mpv_loc := gl.GetUniformLocation(shader, "u_mvp")
    gl.UniformMatrix4fv(mpv_loc, 1, false, raw_data(camera_mvp[0][:]))
  }
  gl.DrawArrays(gl.TRIANGLES, 0, i32(current_vertex))

  sdl.GL_SwapWindow(global_window)
}

