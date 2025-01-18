// Code ideas:
// put textures in an array, and then calculate the index by doing some math operation with snake_direction and is_open
// use grid coordinates and then convert them to screen coordinates

package game

// import "core:fmt"
import rl "vendor:raylib"

// --- GLOBAL ---
// CONSTANTS
GRID_ELEMENT_SIZE :: 16
NUMBER_OF_GRID_ELEMENTS :: 20
CANVAS_SIZE :: GRID_ELEMENT_SIZE * NUMBER_OF_GRID_ELEMENTS
MOVE_SNAKE_EVERY_N_SECONDS :: .5
// TYPES
V2i :: [2]u8 // Vector2 integer, for grid positions
Snake_Direction :: enum u8 {
	UP,
	DOWN,
	LEFT,
	RIGHT,
}
Snake_Textures :: struct {
	left:      rl.Texture,
	left_pop:  rl.Texture,
	right:     rl.Texture,
	right_pop: rl.Texture,
	up:        rl.Texture,
	up_pop:    rl.Texture,
	down:      rl.Texture,
	down_pop:  rl.Texture,
}
Star_Textures :: struct {
	star1: rl.Texture,
	star2: rl.Texture,
}
Game_Memory :: struct {
	snake_texture:        rl.Texture,
	snake_pos:            rl.Vector2,
	time_since_last_move: f32,
	snake_direction:      Snake_Direction,
	start_exists:         bool,
	star_pos:             rl.Vector2,
}
// VARIABLES & POINTERS
G_MEM: ^Game_Memory
SNAKE_TEXTURES: ^Snake_Textures
STAR_TEXTURES: ^Star_Textures
game_camera :: proc() -> rl.Camera2D {
	w := f32(rl.GetScreenWidth())
	h := f32(rl.GetScreenHeight())

	lower_dim := h if h < w else w
	zoom := lower_dim / CANVAS_SIZE

	offset_left := (w - CANVAS_SIZE * zoom) / 2
	offset_top := (h - CANVAS_SIZE * zoom) / 2

	return {target = rl.Vector2{0, 0}, offset = rl.Vector2{offset_left, offset_top}, zoom = zoom}

}

// --- CORE EDITABLE PROCEDURES ---
@(export)
game_init_window :: proc() {
	rl.SetConfigFlags({.WINDOW_RESIZABLE, .VSYNC_HINT})
	rl.InitWindow(800, 600, "Snek")
	rl.MaximizeWindow()
}

@(export)
game_init :: proc() {
	G_MEM = new(Game_Memory)
	SNAKE_TEXTURES = new(Snake_Textures)
	STAR_TEXTURES = new(Star_Textures)

	SNAKE_TEXTURES^ = Snake_Textures {
		left      = rl.LoadTexture("assets/kot_left.png"),
		left_pop  = rl.LoadTexture("assets/kot_left_open.png"),
		right     = rl.LoadTexture("assets/kot_right.png"),
		right_pop = rl.LoadTexture("assets/kot_right_open.png"),
		up        = rl.LoadTexture("assets/kot_back.png"),
		up_pop    = rl.LoadTexture("assets/kot_back_open.png"),
		down      = rl.LoadTexture("assets/kot_front.png"),
		down_pop  = rl.LoadTexture("assets/kot_front_open.png"),
	}

	STAR_TEXTURES^ = Star_Textures {
		star1 = rl.LoadTexture("assets/star_01.png"),
		star2 = rl.LoadTexture("assets/star_02.png"),
	}

	G_MEM^ = Game_Memory {
		snake_texture   = SNAKE_TEXTURES.right,
		snake_pos       = rl.Vector2{0, 0},
		snake_direction = Snake_Direction.RIGHT,
		start_exists    = false,
		star_pos        = get_random_pos(),
	}

	game_hot_reloaded(G_MEM)
}

draw :: proc() {
	rl.BeginDrawing()
	rl.ClearBackground(rl.Color{30, 30, 30, 255})

	snake_head := rl.Rectangle {
		f32(G_MEM.snake_pos[0]),
		f32(G_MEM.snake_pos[1]),
		GRID_ELEMENT_SIZE,
		GRID_ELEMENT_SIZE,
	}
	camera := game_camera()

	rl.BeginMode2D(camera)

	rl.DrawTextureEx(G_MEM.snake_texture, rl.Vector2{snake_head.x, snake_head.y}, 0, .9, rl.WHITE)

	draw_star()

	rl.EndMode2D()

	rl.EndDrawing()
}

update :: proc() {
	G_MEM.time_since_last_move += rl.GetFrameTime()

	if rl.IsKeyPressed(.UP) || rl.IsKeyPressed(.W) {
		G_MEM.snake_direction = Snake_Direction.UP
		G_MEM.snake_texture = SNAKE_TEXTURES.up
	}
	if rl.IsKeyPressed(.DOWN) || rl.IsKeyPressed(.S) {
		G_MEM.snake_direction = Snake_Direction.DOWN
		G_MEM.snake_texture = SNAKE_TEXTURES.down
	}
	if rl.IsKeyPressed(.LEFT) || rl.IsKeyPressed(.A) {
		G_MEM.snake_direction = Snake_Direction.LEFT
		G_MEM.snake_texture = SNAKE_TEXTURES.left
	}
	if rl.IsKeyPressed(.RIGHT) || rl.IsKeyPressed(.D) {
		G_MEM.snake_direction = Snake_Direction.RIGHT
		G_MEM.snake_texture = SNAKE_TEXTURES.right
	}

	if should_snake_move() {
		if G_MEM.snake_direction == Snake_Direction.UP {
			G_MEM.snake_pos[1] -= GRID_ELEMENT_SIZE
		} else if G_MEM.snake_direction == Snake_Direction.DOWN {
			G_MEM.snake_pos[1] += GRID_ELEMENT_SIZE
		} else if G_MEM.snake_direction == Snake_Direction.LEFT {
			G_MEM.snake_pos[0] -= GRID_ELEMENT_SIZE
		} else if G_MEM.snake_direction == Snake_Direction.RIGHT {
			G_MEM.snake_pos[0] += GRID_ELEMENT_SIZE
		}

		G_MEM.time_since_last_move = 0
	}
}

// --- CUSTOM USER PROCEDURES ---

should_snake_move :: proc() -> bool {
	return G_MEM.time_since_last_move >= MOVE_SNAKE_EVERY_N_SECONDS
}

draw_snake :: proc() {
	snake_head := rl.Rectangle {
		f32(G_MEM.snake_pos[0]),
		f32(G_MEM.snake_pos[1]),
		GRID_ELEMENT_SIZE,
		GRID_ELEMENT_SIZE,
	}
	rl.DrawTextureEx(G_MEM.snake_texture, rl.Vector2{snake_head.x, snake_head.y}, 0, .9, rl.WHITE)
}

draw_grid :: proc() {
	grid_rect := rl.Rectangle{0, 0, GRID_ELEMENT_SIZE, GRID_ELEMENT_SIZE}
	for x in 0 ..< NUMBER_OF_GRID_ELEMENTS {
		for y in 0 ..< NUMBER_OF_GRID_ELEMENTS {
			grid_rect.x = f32(x * GRID_ELEMENT_SIZE)
			grid_rect.y = f32(y * GRID_ELEMENT_SIZE)
			rl.DrawRectangleLinesEx(grid_rect, .5, rl.RED)
		}
	}
}

// apple
draw_star :: proc() {
	apple_pos := G_MEM.star_pos

	if !G_MEM.start_exists {
		random_pos := get_random_pos()
		apple_pos.x = random_pos.x
		apple_pos.y = random_pos.y
		G_MEM.start_exists = true
	}

	rl.DrawTextureEx(STAR_TEXTURES.star1, rl.Vector2{apple_pos.x, apple_pos.y}, 0, .9, rl.WHITE)
}

get_random_pos :: proc() -> rl.Vector2 {
	return rl.Vector2 {
		f32(rl.GetRandomValue(0, NUMBER_OF_GRID_ELEMENTS - 1) * GRID_ELEMENT_SIZE),
		f32(rl.GetRandomValue(0, NUMBER_OF_GRID_ELEMENTS - 1) * GRID_ELEMENT_SIZE),
	}
}


// --- CORE UNEDITABLE PROCEDURES ---
@(export)
game_update :: proc() -> bool {
	update()
	draw()
	return !rl.WindowShouldClose()
}

@(export)
game_shutdown :: proc() {
	free(G_MEM)
	free(SNAKE_TEXTURES)
	free(STAR_TEXTURES)
}

@(export)
game_shutdown_window :: proc() {
	rl.CloseWindow()
}

@(export)
game_memory :: proc() -> rawptr {
	return G_MEM
}

@(export)
game_memory_size :: proc() -> int {
	return size_of(Game_Memory)
}

@(export)
game_hot_reloaded :: proc(mem: rawptr) {
	G_MEM = (^Game_Memory)(mem)
}

@(export)
game_force_reload :: proc() -> bool {
	return rl.IsKeyPressed(.F5)
}

@(export)
game_force_restart :: proc() -> bool {
	return rl.IsKeyPressed(.F6)
}

// In a web build, this is called when browser changes size. Remove the
// `rl.SetWindowSize` call if you don't want a resizable game.
game_parent_window_size_changed :: proc(w, h: int) {
	rl.SetWindowSize(i32(w), i32(h))
}
