package game

import "core:fmt"
import "core:strings"
import "core:math/rand"
import platform "../platform"

NUM_CELLS_Y :: 18
NUM_CELLS_X :: 32

Block :: enum {
  VOID,
  FLOOR,
  PLAYER,
  WALL,
  CRATE,
  BUTTON,
  CRATE_ON_BUTTON,
  COLUMN,
}

World :: [NUM_CELLS_Y][NUM_CELLS_X][2]Block

first_world := [2]string {`
................................
................................
................................
................................
................................
................................
................................
................................
................................
........................w.......
........................w.......
........................w.......
........................w.......
...............p........w.......
................................
................................
................................
................................
`,
`
................................
................................
................................
................................
...w............................
...w.......c....................
...w..............www...........
...w....c.........www...........
...w..............www...........
...w..............www...........
...w..............www...........
...w..............www...........
..................www...........
.......p........................
................................
................................
................................
................................
`}

str_to_world :: proc(surface, underground: string) -> World {

  assert(len(surface) == len(underground))
  assert(len(surface) >= NUM_CELLS_X * NUM_CELLS_Y)

  res : World

  char_to_block :: proc(r: u8) -> Block {
    res : Block
    switch r {
    case '.': res = .FLOOR
    case 'p': res = .PLAYER
    case 'c': res = .CRATE
    case 'w': res = .WALL
    case 'o': res = .VOID
    case 'b': res = .BUTTON
    case: unreachable()
    }
    return res
  }

  surface_lines := strings.split_lines(surface)
  defer delete(surface_lines)

  underground_lines := strings.split_lines(underground)
  defer delete(underground_lines)

  idx_x, idx_y := 0, 0
  #reverse for line, i in surface_lines {
    if len(line) == 0 do continue
    for char, j in line {
      res[idx_y][idx_x] = {
        char_to_block(surface_lines[i][j]),
        char_to_block(underground_lines[i][j]),
      }
      idx_x = (idx_x + 1) % NUM_CELLS_X
    }
    idx_y += 1
  }

  return res
}

Game_State :: struct {
  world: World,
  floor: int,
}

init_game_state :: proc() -> Game_State {
  return {
    world = str_to_world(first_world[0], first_world[1])
  }
}

reset_world :: proc(state: ^Game_State) {
  state.world = str_to_world(first_world[0], first_world[1])
}

counter := u32(0)
shader := u32(0)
exit := false
game_state : Game_State

@export
init :: proc() {
  platform.init("screen", 640, 360)

  game_state = init_game_state()

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

GRAY   :: platform.Color {92, 92, 92, 255}
WHITE  :: platform.Color {255, 255, 255, 255}
SKY_BLUE  :: platform.Color {66, 201, 201, 255}
CAVE_BROWN :: platform.Color {71, 52, 41, 255}
PURPLE :: platform.Color {128, 0, 255, 255}
BROWN  :: platform.Color {117, 75, 39, 255}

@export
deinit :: proc() {
  platform.deinit()
}

draw_game :: proc(state: Game_State) {
  width, height := platform.get_render_size()

  block_size := f32(height / NUM_CELLS_Y)

  platform.begin_drawing()
  {
    platform.clear_color({0, 0, 0, 0xff})
    for i in 0..<NUM_CELLS_Y {
      for j in 0..<NUM_CELLS_X {
        block := state.world[i][j][state.floor]

        pos_x := f32(j) * block_size
        pos_y := f32(i) * block_size
        color : platform.Color

        switch block {
        case .PLAYER: color = PURPLE
        case .WALL: color = GRAY
        case .CRATE: color = BROWN
        case .FLOOR: color =  SKY_BLUE if state.floor == 0 else CAVE_BROWN
        case .VOID: color = SKY_BLUE / {2, 2, 2, 1}
        case .COLUMN: color = BROWN
        case .BUTTON: color = GRAY
        case .CRATE_ON_BUTTON: color = GRAY
        }

        platform.draw_quad(pos_x, pos_y, block_size, block_size, color)
      }
    }
  }
  platform.end_drawing(shader)
}

spawn_block :: proc(state: ^Game_State, block: Block, position: [3]int) {
  current_block := &state.world[position.y][position.x][position.z]
  if current_block^ == .WALL do return
  current_block^ = block
}

Move_Direction :: enum{ UP, DOWN, LEFT, RIGHT} 
move_single_movable :: proc(state: ^Game_State, position: [3]int, direction: Move_Direction, force_move := false) -> bool {
  direction_map : [Move_Direction][3]int = {
    .UP    = { 0, +1, 0},
    .DOWN  = { 0, -1, 0},
    .LEFT  = {-1,  0, 0},
    .RIGHT = {+1,  0, 0},
  }
  next_indexes := direction_map[direction]
  next_position := position + next_indexes
  if next_position.y >= NUM_CELLS_Y || next_position.y < 0 do return false
  if next_position.x >= NUM_CELLS_X || next_position.x < 0 do return false

  // TODO: column logic
  current_block := &state.world[position.y][position.x][position.z]
  next_block := &state.world[next_position.y][next_position.x][next_position.z]
  #partial switch next_block^ {
  case .FLOOR: { /* do nothing */ }
  case .WALL:
    if !force_move || !move_single_movable(state, next_position, direction, false) do return false
  case .CRATE: 
    if current_block^ == .PLAYER && !move_single_movable(state, next_position, direction, true) do return false
  case .COLUMN:
    if current_block^ == .PLAYER && !move_single_movable(state, next_position + {0, 0, -1}, direction, true) do return false
  }
  next_block^ = current_block^
  current_block^ = .FLOOR
  return true

}

move_player :: proc(state: ^Game_State, direction : Move_Direction) {
  previous_world : World = state.world
  for line, i in previous_world {
    for block, j in line do if block[state.floor] == .PLAYER {
      move_single_movable(state, {j, i, state.floor}, direction)
    }
  }
}

try_move_single_crate :: proc(state: ^Game_State, position: [2]int, direction: Move_Direction) {}

update :: proc(state: ^Game_State) {
  assert(state.floor == 0 || state.floor == 1)
  if platform.is_key_pressed(.W) do move_player(state, .UP)
  if platform.is_key_pressed(.A) do move_player(state, .LEFT)
  if platform.is_key_pressed(.S) do move_player(state, .DOWN)
  if platform.is_key_pressed(.D) do move_player(state, .RIGHT)
  if platform.is_key_pressed(.R) do reset_world(state)
  if platform.is_key_pressed(.Space) {
    if state.floor == 0 {
      state.floor = 1
    } else {
      state.floor = 0
    }
  }
}

@export
step :: proc(dt: f64) -> (should_continue: bool) {
  update(&game_state)
  draw_game(game_state)
  return !exit
}

