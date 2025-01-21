// Code ideas:
// use grid coordinates and then convert them to screen coordinates?
// change G_MEM.cat_segments from AOS to SOA? Cat_Segment {pos_x: [1]f32, pos_y: [1]f32, direction: [1]Cat_Direction}

// TODOs and issues
// Set the exe icon
// Stars can spawn on the cat
// If a star spawns next to the cat's head, it will have the wrong texture
// If cat eats a star, and a new star spawns next to cat's head, it will have the wrong texture

package game

import "core:fmt"
// import "core:prof/spall"
import rl "vendor:raylib"

// --- GLOBAL ---
// CONSTANTS
GRID_ELEMENT_SIZE :: 16
NUMBER_OF_GRID_ELEMENTS :: 8
CANVAS_SIZE :: GRID_ELEMENT_SIZE * NUMBER_OF_GRID_ELEMENTS
MOVE_SNAKE_EVERY_N_SECONDS :: .5
PURPLE :: rl.Color{255, 0, 255, 200}
// TYPES
V2u8 :: [2]u8 // Vector2 integer, for grid positions
Cat_Direction :: enum u8 {
	LEFT,
	RIGHT,
	UP,
	DOWN,
}
Cat_Textures :: struct {
	left:      rl.Texture,
	right:     rl.Texture,
	up:        rl.Texture,
	down:      rl.Texture,
	left_pop:  rl.Texture,
	right_pop: rl.Texture,
	up_pop:    rl.Texture,
	down_pop:  rl.Texture,
}
Star_Textures :: struct {
	star1: rl.Texture,
	star2: rl.Texture,
}
Cat_Segment :: struct {
	pos:       rl.Vector2,
	direction: Cat_Direction,
}
Game_Memory :: struct {
	cat_segments:          [CANVAS_SIZE]Cat_Segment, // the last element is the tail
	cat_head:              Cat_Segment,
	cat_texture:           ^rl.Texture,
	star_pos:              rl.Vector2,
	time_since_last_move:  f32,
	pending_cat_direction: Cat_Direction,
	cat_alive:             bool,
	star_exists:           bool,
	cat_tail_index:        u8,
	star_textures_index:   i8,
}
// VARIABLES & POINTERS
G_MEM: ^Game_Memory
CAT_TEXTURES: ^Cat_Textures
CAT_TEXTURES_INDEXABLE: [8]^rl.Texture
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
	icon: rl.Image = rl.LoadImage("assets/kot_front.png")
	rl.SetConfigFlags({.WINDOW_RESIZABLE, .VSYNC_HINT})
	rl.InitWindow(800, 600, "Snek")
	rl.SetWindowIcon(icon)
	rl.MaximizeWindow()
}

@(export)
game_init :: proc() {
	G_MEM = new(Game_Memory)
	CAT_TEXTURES = new(Cat_Textures)
	STAR_TEXTURES = new(Star_Textures)

	CAT_TEXTURES^ = Cat_Textures {
		left      = rl.LoadTexture("assets/kot_left.png"),
		right     = rl.LoadTexture("assets/kot_right.png"),
		up        = rl.LoadTexture("assets/kot_back.png"),
		down      = rl.LoadTexture("assets/kot_front.png"),
		left_pop  = rl.LoadTexture("assets/kot_left_open.png"),
		right_pop = rl.LoadTexture("assets/kot_right_open.png"),
		up_pop    = rl.LoadTexture("assets/kot_back_open.png"),
		down_pop  = rl.LoadTexture("assets/kot_front_open.png"),
	}

	CAT_TEXTURES_INDEXABLE = [8]^rl.Texture {
		&CAT_TEXTURES.left,
		&CAT_TEXTURES.right,
		&CAT_TEXTURES.up,
		&CAT_TEXTURES.down,
		&CAT_TEXTURES.left_pop,
		&CAT_TEXTURES.right_pop,
		&CAT_TEXTURES.up_pop,
		&CAT_TEXTURES.down_pop,
	}

	STAR_TEXTURES^ = Star_Textures {
		star1 = rl.LoadTexture("assets/star_01.png"),
		star2 = rl.LoadTexture("assets/star_02.png"),
	}

	set_initial_memory()

	game_hot_reloaded(G_MEM)

	fmt.printfln("Game memory size: %d", game_memory_size())
	fmt.printfln("Textures size: %d", game_textures_size())
}

@(export)
game_shutdown :: proc() {
	free(G_MEM)
	free(CAT_TEXTURES)
	free(STAR_TEXTURES)
}

set_initial_memory :: proc() {
	G_MEM^ = Game_Memory {
		cat_head              = Cat_Segment{rl.Vector2{0, 0}, Cat_Direction.RIGHT},
		cat_tail_index        = 0,
		cat_alive             = true,
		cat_texture           = &CAT_TEXTURES.right,
		pending_cat_direction = Cat_Direction.RIGHT,
		star_exists           = false,
		star_pos              = get_random_pos(),
		star_textures_index   = 1,
	}
}


draw :: proc() {
	rl.BeginDrawing()
	rl.ClearBackground(rl.Color{30, 30, 30, 255})

	camera := game_camera()

	rl.BeginMode2D(camera)

	if !G_MEM.cat_alive {
		rl.DrawText("Game Over", 10, CANVAS_SIZE / 2 - 20, 20, rl.WHITE)
		rl.DrawText("Press Enter to restart", 0, CANVAS_SIZE / 2, 10, rl.WHITE)
		rl.EndMode2D()
		rl.EndDrawing()
		return
	}

	draw_edges()

	// draw a cat for each body part
	for i in 0 ..< G_MEM.cat_tail_index {
		cat_segment := G_MEM.cat_segments[i]
		cat_body := rl.Rectangle {
			f32(cat_segment.pos.x),
			f32(cat_segment.pos.y),
			GRID_ELEMENT_SIZE,
			GRID_ELEMENT_SIZE,
		}
		rl.DrawTextureEx(
			CAT_TEXTURES_INDEXABLE[u8(cat_segment.direction)]^,
			rl.Vector2{cat_body.x, cat_body.y},
			0,
			.9,
			PURPLE,
		)
	}

	// draw cat head
	cat_head := rl.Rectangle {
		f32(G_MEM.cat_head.pos[0]),
		f32(G_MEM.cat_head.pos[1]),
		GRID_ELEMENT_SIZE,
		GRID_ELEMENT_SIZE,
	}
	rl.DrawTextureEx(G_MEM.cat_texture^, rl.Vector2{cat_head.x, cat_head.y}, 0, .9, rl.WHITE)

	draw_star()

	rl.EndMode2D()

	rl.EndDrawing()
}

update :: proc() {
	if !G_MEM.cat_alive {
		if rl.IsKeyPressed(.ENTER) {
			G_MEM.cat_alive = true
			set_initial_memory()
		}
		return
	}
	G_MEM.time_since_last_move += rl.GetFrameTime()

	determine_new_cat_direction()

	if !should_update_state() {return}

	G_MEM.cat_segments[G_MEM.cat_tail_index] = G_MEM.cat_head
	G_MEM.cat_head.direction = G_MEM.pending_cat_direction

	move_cat_head()

	if is_cat_outside_canvas() {
		G_MEM.cat_alive = false
		return
	}

	is_cat_pos_at_star_pos := is_cat_pos_exactly_at_star_pos()
	G_MEM.time_since_last_move = 0
	G_MEM.star_textures_index *= -1

	if is_cat_pos_at_star_pos {
		G_MEM.star_exists = false // star will be redrawn in update:draw_star()
		G_MEM.cat_tail_index += 1
	} else {
		for i in 0 ..< G_MEM.cat_tail_index {
			G_MEM.cat_segments[i] = G_MEM.cat_segments[i + 1]
		}
	}

	if is_cat_head_inside_cat_body() {
		G_MEM.cat_alive = false
		return
	}

	G_MEM.cat_texture = determine_cat_texture(is_cat_pos_at_star_pos)
}

// --- CUSTOM USER PROCEDURES ---

// since it's a snake game, the update of game state is done every N seconds
should_update_state :: proc() -> bool {
	return G_MEM.time_since_last_move >= MOVE_SNAKE_EVERY_N_SECONDS
}

move_cat_head :: proc() {
	if G_MEM.cat_head.direction == Cat_Direction.UP {
		G_MEM.cat_head.pos.y -= GRID_ELEMENT_SIZE
	} else if G_MEM.cat_head.direction == Cat_Direction.DOWN {
		G_MEM.cat_head.pos.y += GRID_ELEMENT_SIZE
	} else if G_MEM.cat_head.direction == Cat_Direction.LEFT {
		G_MEM.cat_head.pos.x -= GRID_ELEMENT_SIZE
	} else if G_MEM.cat_head.direction == Cat_Direction.RIGHT {
		G_MEM.cat_head.pos.x += GRID_ELEMENT_SIZE
	}
}

is_cat_outside_canvas :: proc() -> bool {
	return(
		G_MEM.cat_head.pos.x < 0 ||
		G_MEM.cat_head.pos.x >= CANVAS_SIZE ||
		G_MEM.cat_head.pos.y < 0 ||
		G_MEM.cat_head.pos.y >= CANVAS_SIZE \
	)
}

is_cat_pos_exactly_at_star_pos :: proc() -> bool {
	return G_MEM.cat_head.pos.x == G_MEM.star_pos.x && G_MEM.cat_head.pos.y == G_MEM.star_pos.y
}

draw_snake :: proc() {
	snake_head := rl.Rectangle {
		f32(G_MEM.cat_head.pos[0]),
		f32(G_MEM.cat_head.pos[1]),
		GRID_ELEMENT_SIZE,
		GRID_ELEMENT_SIZE,
	}
	rl.DrawTextureEx(G_MEM.cat_texture^, rl.Vector2{snake_head.x, snake_head.y}, 0, .9, rl.WHITE)
}

draw_edges :: proc() {
	rl.DrawRectangleLinesEx(rl.Rectangle{0, 0, CANVAS_SIZE, CANVAS_SIZE}, 1, PURPLE)
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

// -- BEGIN: cat direction
determine_new_cat_direction :: proc() {
	new_cat_direction := G_MEM.pending_cat_direction
	#partial switch rl.GetKeyPressed() {
	case .UP, .W:
		new_cat_direction = Cat_Direction.UP
	case .DOWN, .S:
		new_cat_direction = Cat_Direction.DOWN
	case .LEFT, .A:
		new_cat_direction = Cat_Direction.LEFT
	case .RIGHT, .D:
		new_cat_direction = Cat_Direction.RIGHT
	}
	if !is_new_direction_oposite_to_current(new_cat_direction) {
		G_MEM.pending_cat_direction = new_cat_direction
	}
}

is_new_direction_oposite_to_current :: proc(new_direction: Cat_Direction) -> bool {
	switch G_MEM.cat_head.direction {
	case Cat_Direction.UP:
		return new_direction == Cat_Direction.DOWN
	case Cat_Direction.DOWN:
		return new_direction == Cat_Direction.UP
	case Cat_Direction.LEFT:
		return new_direction == Cat_Direction.RIGHT
	case Cat_Direction.RIGHT:
		return new_direction == Cat_Direction.LEFT
	}
	return false
}
// -- END: cat direction

determine_cat_texture :: proc(is_cat_pos_at_star_pos: bool) -> ^rl.Texture {
	cat_texture_index :=
		u8(G_MEM.cat_head.direction) + u8(4) * u8(is_cat_head_next_to_star(is_cat_pos_at_star_pos))

	return CAT_TEXTURES_INDEXABLE[cat_texture_index]
}

// star
draw_star :: proc() {
	star_pos := G_MEM.star_pos

	if !G_MEM.star_exists {
		random_pos := get_random_pos()
		star_pos.x = random_pos.x
		star_pos.y = random_pos.y
		G_MEM.star_exists = true
		G_MEM.star_pos = star_pos
	}

	star_texture := &STAR_TEXTURES.star1
	if G_MEM.star_textures_index == 1 {
		star_texture = &STAR_TEXTURES.star2
	}

	rl.DrawTextureEx(star_texture^, rl.Vector2{star_pos.x, star_pos.y}, 0, .9, rl.WHITE)
}

get_random_pos :: proc() -> rl.Vector2 {
	return rl.Vector2 {
		f32(rl.GetRandomValue(0, NUMBER_OF_GRID_ELEMENTS - 1) * GRID_ELEMENT_SIZE),
		f32(rl.GetRandomValue(0, NUMBER_OF_GRID_ELEMENTS - 1) * GRID_ELEMENT_SIZE),
	}
}

world_to_grid :: proc(world_pos: rl.Vector2) -> V2u8 {
	return [2]u8{u8(world_pos.x / GRID_ELEMENT_SIZE), u8(world_pos.y / GRID_ELEMENT_SIZE)}
}

is_cat_head_inside_cat_body :: proc() -> bool {
	cat_head_pos := world_to_grid(G_MEM.cat_head.pos)
	for i in 0 ..< G_MEM.cat_tail_index {
		cat_segment_pos := world_to_grid(G_MEM.cat_segments[i].pos)
		if cat_head_pos.x == cat_segment_pos.x && cat_head_pos.y == cat_segment_pos.y {
			return true
		}
	}
	return false
}

is_cat_head_next_to_star :: proc(is_cat_pos_at_star_pos: bool) -> bool {
	if is_cat_pos_at_star_pos {
		return false
	}
	cat_grid_pos := world_to_grid(G_MEM.cat_head.pos)
	star_grid_pos := world_to_grid(G_MEM.star_pos)

	// cast to i8 because of underflow issues
	if cat_grid_pos.x == star_grid_pos.x {
		y_diff := abs(i8(cat_grid_pos.y - star_grid_pos.y))
		return y_diff == 1
	}
	if cat_grid_pos.y == star_grid_pos.y {
		x_diff := abs(i8(cat_grid_pos.x - star_grid_pos.x))
		return x_diff == 1
	}

	return false
}

// --- CORE UNEDITABLE PROCEDURES ---
@(export)
game_update :: proc() -> bool {
	update()
	draw()
	return !rl.WindowShouldClose()
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

game_textures_size :: proc() -> int {
	return size_of(Cat_Textures) + size_of(Star_Textures)
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
