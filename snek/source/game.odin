// Code ideas:
// change G_MEM.cat_segments from AOS to SOA? Cat_Segment {pos_x: [1]f32, pos_y: [1]f32, direction: [1]Cat_Direction}
// a better way of generating random star positions? (get_new_random_star_pos) For example, using a list of all non-occupied positions? Or map each coordinate to unique index, so we can just pick a random index from the available ones?
// make a UI struct to calculate the text/camera offsets and zooms only once, run the size updates in the update function using rl.IsWindowResized(). Possibly make something like Text struct that would hold the font size, offsets, rects, etc.

// TODOs and issues
// Make a difficulty selection screen at the start to train ui coding/use an external ui raylib library
// Set the .exe icon
// Export images as code https://www.reddit.com/r/raylib/comments/ub09iq/how_to_bundle_assets_with_compiled_executable/
// Try making a webbuild

package game

import "core:fmt"
import rl "vendor:raylib"

// --- GLOBAL ---
// CONSTANTS
GRID_ELEMENT_PIXELS :: 16
NUMBER_OF_GRID_ELEMENTS_IN_A_ROW :: 4
CANVAS_SIZE :: GRID_ELEMENT_PIXELS * NUMBER_OF_GRID_ELEMENTS_IN_A_ROW
DEATH_ANIMATION_TIME_IN_SECONDS :: f32(1.2)
MOVE_SNAKE_EVERY_N_SECONDS :: f32(0.25)
VICTORY_ANIMATION_TOTAL_TIME_IN_SECONDS :: f32(5)
VICTORY_ANIMATION_INTERVAL_IN_SECONDS :: f32(0.25)
PURPLE :: rl.Color{255, 0, 255, 200}
UI_SCALING_FACTOR: i32 = 1
// TYPES
V2i8 :: [2]i8 // Vector2 integer, for grid positions
Cat_Direction :: enum u8 {
	LEFT,
	RIGHT,
	UP,
	DOWN,
}
Game_States :: enum u8 {
	START_SCREEN,
	GAMEPLAY,
	DYING_ANIMATION,
	VICTORY_ANIMATION,
	SCORE_SCREEN,
	VICTORY_SCREEN,
}
Cat_Segment :: struct {
	pos:           V2i8,
	direction:     Cat_Direction,
	texture_index: u8,
}
Cat_Textures :: struct {
	left:      rl.Texture, // 0
	right:     rl.Texture, // 1
	up:        rl.Texture, // 2
	down:      rl.Texture, // 3
	left_pop:  rl.Texture, // 4
	right_pop: rl.Texture, // 5
	up_pop:    rl.Texture, // 6
	down_pop:  rl.Texture, // 7
	dead:      rl.Texture, // 8
}
Star_Textures :: struct {
	star1: rl.Texture,
	star2: rl.Texture,
}
Game_Memory :: struct {
	cat_segments:                   [CANVAS_SIZE]Cat_Segment, // the last element is the tail
	cat_head:                       Cat_Segment,
	time_since_last_move:           f32,
	animation_helper_segment_index: i32,
	cat_tail_index:                 i32,
	star_pos:                       V2i8,
	star_textures_index:            i8,
	game_state:                     Game_States,
	pending_cat_direction:          Cat_Direction,
}

Game_Sounds :: struct {
	death: rl.Sound,
	eat:   rl.Sound,
	pop:   rl.Sound,
}
// VARIABLES & POINTERS
G_MEM: ^Game_Memory
CAT_TEXTURES: ^Cat_Textures
CAT_TEXTURES_INDEXABLE: ^[9]^rl.Texture
STAR_TEXTURES: ^Star_Textures
GAME_SOUNDS: ^Game_Sounds
game_camera :: proc() -> rl.Camera2D {
	screen_width := f32(rl.GetScreenWidth())
	screen_height := f32(rl.GetScreenHeight())

	offset_left := f32(screen_width / 2)
	offset_right := f32(screen_height / 2)

	zoom: f32 = f32(screen_width) / 308

	// center the game board
	if G_MEM.game_state == .GAMEPLAY ||
	   G_MEM.game_state == .DYING_ANIMATION ||
	   G_MEM.game_state == .VICTORY_ANIMATION {
		zoom += 3
		offset := CANVAS_SIZE * zoom
		offset_left = (screen_width - offset) / 2
		offset_right = (screen_height - offset) / 2
	}

	return {target = rl.Vector2{0, 0}, offset = rl.Vector2{offset_left, offset_right}, zoom = zoom}
}

// --- CORE EDITABLE PROCEDURES ---
@(export)
game_init_window :: proc() {
	icon: rl.Image = rl.LoadImage("assets/textures/cat/kot_front.png")
	rl.SetConfigFlags({.WINDOW_RESIZABLE})
	rl.InitWindow(800, 600, "Snek")
	rl.SetWindowIcon(icon)
	rl.MaximizeWindow()
	rl.SetTargetFPS(30)
	rl.InitAudioDevice()
	UI_SCALING_FACTOR = rl.GetMonitorWidth(0) / 15
}

@(export)
game_init :: proc() {
	G_MEM = new(Game_Memory)
	CAT_TEXTURES = new(Cat_Textures)
	CAT_TEXTURES_INDEXABLE = new([9]^rl.Texture)
	STAR_TEXTURES = new(Star_Textures)
	GAME_SOUNDS = new(Game_Sounds)

	CAT_TEXTURES^ = Cat_Textures {
		left      = rl.LoadTexture("assets/textures/cat/kot_left.png"),
		right     = rl.LoadTexture("assets/textures/cat/kot_right.png"),
		up        = rl.LoadTexture("assets/textures/cat/kot_back.png"),
		down      = rl.LoadTexture("assets/textures/cat/kot_front.png"),
		left_pop  = rl.LoadTexture("assets/textures/cat/kot_left_open.png"),
		right_pop = rl.LoadTexture("assets/textures/cat/kot_right_open.png"),
		up_pop    = rl.LoadTexture("assets/textures/cat/kot_back_open.png"),
		down_pop  = rl.LoadTexture("assets/textures/cat/kot_front_open.png"),
		dead      = rl.LoadTexture("assets/textures/cat/kot_ded.png"),
	}

	CAT_TEXTURES_INDEXABLE^ = [9]^rl.Texture {
		&CAT_TEXTURES.left,
		&CAT_TEXTURES.right,
		&CAT_TEXTURES.up,
		&CAT_TEXTURES.down,
		&CAT_TEXTURES.left_pop,
		&CAT_TEXTURES.right_pop,
		&CAT_TEXTURES.up_pop,
		&CAT_TEXTURES.down_pop,
		&CAT_TEXTURES.dead,
	}

	STAR_TEXTURES^ = Star_Textures {
		star1 = rl.LoadTexture("assets/textures/star/star_01.png"),
		star2 = rl.LoadTexture("assets/textures/star/star_02.png"),
	}

	GAME_SOUNDS^ = Game_Sounds {
		death = rl.LoadSound("assets/audio/death.ogg"),
		eat   = rl.LoadSound("assets/audio/hap.ogg"),
		pop   = rl.LoadSound("assets/audio/pop.ogg"),
	}

	set_memory_to_initial_state()

	game_hot_reloaded(G_MEM)

	fmt.printfln("Game memory size: %d", game_memory_size())
	fmt.printfln("Assets size: %d", game_assets_size())
}

@(export)
game_shutdown :: proc() {
	free(G_MEM)
	free(CAT_TEXTURES)
	free(CAT_TEXTURES_INDEXABLE)
	free(STAR_TEXTURES)
	free(GAME_SOUNDS)
}

set_memory_to_initial_state :: proc() {
	game_state := G_MEM.game_state
	G_MEM^ = Game_Memory {
		cat_head                       = Cat_Segment{V2i8{0, 0}, Cat_Direction.RIGHT, 1},
		cat_segments                   = [CANVAS_SIZE]Cat_Segment{},
		cat_tail_index                 = 0,
		animation_helper_segment_index = 0,
		game_state                     = .GAMEPLAY if game_state == .SCORE_SCREEN || game_state == .VICTORY_SCREEN else .START_SCREEN,
		pending_cat_direction          = Cat_Direction.RIGHT,
		star_textures_index            = 1,
		time_since_last_move           = 0,
	}
	new_star_pos := get_new_random_star_pos()
	G_MEM^.star_pos = new_star_pos
	determine_cat_texture()
}

draw :: proc() {
	rl.BeginDrawing()
	rl.ClearBackground(rl.Color{30, 30, 30, 255})

	camera := game_camera()

	rl.BeginMode2D(camera)

	if G_MEM.game_state == .START_SCREEN {
		rl.DrawText(
			"Press Enter to start",
			-rl.MeasureText("Press Enter to start", 20) / 2,
			0,
			20,
			rl.WHITE,
		)
		rl.EndMode2D()
		rl.EndDrawing()
		return
	}

	if G_MEM.game_state == .SCORE_SCREEN {
		rl.DrawText("Game over", -rl.MeasureText("Game over", 30) / 2, -30, 30, rl.WHITE)
		score_string := fmt.ctprintf("Score: %d", G_MEM.cat_tail_index)
		rl.DrawText(score_string, -rl.MeasureText(score_string, 20) / 2, 0, 20, rl.WHITE)
		rl.DrawText(
			"Press Enter to restart",
			-rl.MeasureText("Press Enter to restart", 20) / 2,
			20,
			20,
			rl.WHITE,
		)
		rl.EndMode2D()
		rl.EndDrawing()
		return
	}

	if G_MEM.game_state == .VICTORY_SCREEN {
		rl.DrawText("You won!", -rl.MeasureText("You won!", 30) / 2, -30, 30, rl.WHITE)
		rl.DrawText(
			"Press Enter to restart",
			-rl.MeasureText("Press Enter to restart", 20) / 2,
			0,
			20,
			rl.WHITE,
		)
		rl.EndMode2D()
		rl.EndDrawing()
		return
	}

	if G_MEM.game_state == .VICTORY_ANIMATION {
		play_victory_animation()
	}

	if G_MEM.game_state == .DYING_ANIMATION {
		play_dead_animation()
	}

	draw_edges()
	draw_cat_head()
	draw_cat_body()
	draw_star()

	rl.EndMode2D()

	rl.EndDrawing()
}

update :: proc() {
	G_MEM.time_since_last_move += rl.GetFrameTime()
	// if rl.IsWindowResized() {change_font_size()}
	if G_MEM.game_state == .DYING_ANIMATION || G_MEM.game_state == .VICTORY_ANIMATION {return}
	if G_MEM.game_state == .START_SCREEN {
		if rl.IsKeyPressed(.ENTER) {
			G_MEM.game_state = .GAMEPLAY
		}
		return
	}
	if G_MEM.game_state == .SCORE_SCREEN || G_MEM.game_state == .VICTORY_SCREEN {
		if rl.IsKeyPressed(.ENTER) {
			set_memory_to_initial_state()
		}
		return
	}

	set_direction_to_turn_on_next_step()

	if !should_step() {return}

	G_MEM.cat_head.texture_index %= 4
	G_MEM.cat_segments[G_MEM.cat_tail_index] = G_MEM.cat_head
	G_MEM.cat_head.direction = G_MEM.pending_cat_direction

	move_cat_head()

	if is_cat_outside_canvas() {
		move_cat_body()
		rl.PlaySound(GAME_SOUNDS.death)
		G_MEM.game_state = .DYING_ANIMATION
		G_MEM.time_since_last_move += DEATH_ANIMATION_TIME_IN_SECONDS
		G_MEM.animation_helper_segment_index = G_MEM.cat_tail_index
		return
	}

	G_MEM.time_since_last_move = 0
	G_MEM.star_textures_index *= -1

	if is_cat_pos_exactly_at_star_pos() {
		G_MEM.cat_tail_index += 1
		rl.PlaySound(GAME_SOUNDS.eat)
		if is_snake_taking_up_the_entire_board() {
			G_MEM.cat_head.texture_index = 7
			face_all_the_cats_down()
			G_MEM.game_state = .VICTORY_ANIMATION
			G_MEM.animation_helper_segment_index = 1 // here this will be a counter for the number of cycles the victory animation went through
			return
		}
		spawn_new_star()
	} else {
		move_cat_body()
	}

	if is_cat_head_inside_cat_body() {
		rl.PlaySound(GAME_SOUNDS.death)
		G_MEM.game_state = .DYING_ANIMATION
		G_MEM.time_since_last_move += DEATH_ANIMATION_TIME_IN_SECONDS
		G_MEM.animation_helper_segment_index = G_MEM.cat_tail_index
		return
	}

	determine_cat_texture()
}

// --- CUSTOM USER PROCEDURES ---

// since it's a snake game, the update of game state is done every N seconds
should_step :: proc() -> bool {
	return G_MEM.time_since_last_move >= MOVE_SNAKE_EVERY_N_SECONDS
}

should_update_death_animation :: proc() -> bool {
	time_to_die_for_segment :=
		DEATH_ANIMATION_TIME_IN_SECONDS if G_MEM.cat_tail_index == 0 else DEATH_ANIMATION_TIME_IN_SECONDS / f32(G_MEM.cat_tail_index)
	return G_MEM.time_since_last_move >= time_to_die_for_segment
}

should_update_victory_animation :: proc() -> bool {
	return(
		G_MEM.time_since_last_move >=
		VICTORY_ANIMATION_INTERVAL_IN_SECONDS + random_step_offset_in_secs() \
	)
}

move_cat_head :: proc() {
	switch G_MEM.cat_head.direction {
	case Cat_Direction.UP:
		G_MEM.cat_head.pos.y -= 1
	case Cat_Direction.DOWN:
		G_MEM.cat_head.pos.y += 1
	case Cat_Direction.LEFT:
		G_MEM.cat_head.pos.x -= 1
	case Cat_Direction.RIGHT:
		G_MEM.cat_head.pos.x += 1
	}
}

move_cat_body :: proc() {
	for i in 0 ..< G_MEM.cat_tail_index {
		G_MEM.cat_segments[i] = G_MEM.cat_segments[i + 1]
	}
}

play_dead_animation :: proc() {
	if !should_update_death_animation() {return}
	if G_MEM.animation_helper_segment_index == -1 {
		G_MEM.game_state = .SCORE_SCREEN
		return
	}

	G_MEM.cat_segments[G_MEM.animation_helper_segment_index].texture_index = 8
	G_MEM.cat_head.texture_index = 8
	G_MEM.animation_helper_segment_index -= 1
	G_MEM.time_since_last_move = 0
	rl.PlaySound(GAME_SOUNDS.death)
}

play_victory_animation :: proc() {
	if !should_update_victory_animation() {return}

	if VICTORY_ANIMATION_INTERVAL_IN_SECONDS * f32(G_MEM.animation_helper_segment_index) >=
	   VICTORY_ANIMATION_TOTAL_TIME_IN_SECONDS {
		G_MEM.game_state = .VICTORY_SCREEN
		return
	}

	closed_or_poped_texture: u8 = 7 if rl.GetRandomValue(0, 1) == 1 else 3
	for _ in 0 ..< G_MEM.animation_helper_segment_index {
		random_cat_segment_index := rl.GetRandomValue(0, G_MEM.cat_tail_index - 1)
		G_MEM.cat_segments[random_cat_segment_index].texture_index = closed_or_poped_texture
		closed_or_poped_texture = 7 if closed_or_poped_texture == 3 else 3
		if closed_or_poped_texture == 7 {
			rl.PlaySound(GAME_SOUNDS.pop)
		}
	}
	G_MEM.cat_head.texture_index = closed_or_poped_texture

	G_MEM.animation_helper_segment_index += 1
	G_MEM.time_since_last_move = 0
}

draw_edges :: proc() {
	rl.DrawRectangleLinesEx(rl.Rectangle{0, 0, CANVAS_SIZE, CANVAS_SIZE}, 1, PURPLE)
}

draw_cat_head :: proc() {
	rl.DrawTextureEx(
		CAT_TEXTURES_INDEXABLE[G_MEM.cat_head.texture_index]^,
		grid_to_world(G_MEM.cat_head.pos),
		0,
		.9,
		rl.WHITE,
	)
}

draw_cat_body :: proc() {
	cat_tail_index := G_MEM.cat_tail_index
	if cat_tail_index == 0 {return}
	if G_MEM.game_state == .GAMEPLAY {
		G_MEM.cat_segments[cat_tail_index - 1].texture_index = G_MEM.cat_head.texture_index % 4
	}

	for i in 0 ..< cat_tail_index {
		cat_segment := G_MEM.cat_segments[i]
		rl.DrawTextureEx(
			CAT_TEXTURES_INDEXABLE[cat_segment.texture_index]^,
			grid_to_world(cat_segment.pos),
			0,
			.9,
			PURPLE,
		)
	}
}

draw_star :: proc() {
	if G_MEM.game_state == .VICTORY_ANIMATION {return}
	rl.DrawTextureEx(determine_star_texture()^, grid_to_world(G_MEM.star_pos), 0, .9, rl.WHITE)
}

face_all_the_cats_down :: proc() {
	for i in 0 ..< G_MEM.cat_tail_index {
		G_MEM.cat_segments[i].texture_index = 3
	}
}

// -- BEGIN: cat direction
set_direction_to_turn_on_next_step :: proc() {
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

is_snake_taking_up_the_entire_board :: proc() -> bool {
	return(
		G_MEM.cat_tail_index ==
		NUMBER_OF_GRID_ELEMENTS_IN_A_ROW * NUMBER_OF_GRID_ELEMENTS_IN_A_ROW - 1 \
	)
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

determine_cat_texture :: proc() {
	cat_texture_index := u8(G_MEM.cat_head.direction) + u8(4) * u8(is_cat_head_next_to_star())
	G_MEM.cat_head.texture_index = cat_texture_index
	G_MEM.cat_segments[G_MEM.cat_tail_index] = G_MEM.cat_head
}

// returns -0.1 or 0.1
random_step_offset_in_secs :: proc() -> f32 {
	return -0.1 if rl.GetRandomValue(0, 1) == 0 else 0.1
}

// star
spawn_new_star :: proc() {
	random_pos := get_new_random_star_pos()
	G_MEM.star_pos = random_pos
}

determine_star_texture :: proc() -> ^rl.Texture {
	star_texture := &STAR_TEXTURES.star1
	if G_MEM.star_textures_index == 1 {
		star_texture = &STAR_TEXTURES.star2
	}
	return star_texture
}

draw_fps :: proc() {
	corner_x := rl.GetScreenWidth() - CANVAS_SIZE
	corner_y: i32 = 0
	rl.DrawFPS(corner_x, corner_y)
}

// naive solution of not spawning stars in the snake, is there a better way?
get_new_random_star_pos :: proc() -> V2i8 {
	new_pos := V2i8 {
		i8(rl.GetRandomValue(0, NUMBER_OF_GRID_ELEMENTS_IN_A_ROW - 1)),
		i8(rl.GetRandomValue(0, NUMBER_OF_GRID_ELEMENTS_IN_A_ROW - 1)),
	}
	if new_pos.x == G_MEM.cat_head.pos.x && new_pos.y == G_MEM.cat_head.pos.y {
		return get_new_random_star_pos()
	}
	for i in 0 ..< G_MEM.cat_tail_index {
		if new_pos.x == G_MEM.cat_segments[i].pos.x && new_pos.y == G_MEM.cat_segments[i].pos.y {
			return get_new_random_star_pos()
		}
	}
	return new_pos
}

grid_to_world :: proc(grid_pos: V2i8) -> rl.Vector2 {
	return rl.Vector2 {
		f32(int(grid_pos[0]) * GRID_ELEMENT_PIXELS),
		f32(int(grid_pos[1]) * GRID_ELEMENT_PIXELS),
	}
}

is_cat_pos_exactly_at_star_pos :: proc() -> bool {
	return G_MEM.cat_head.pos.x == G_MEM.star_pos.x && G_MEM.cat_head.pos.y == G_MEM.star_pos.y
}

is_cat_head_inside_cat_body :: proc() -> bool {
	cat_head_pos := G_MEM.cat_head.pos
	for i in 0 ..< G_MEM.cat_tail_index {
		cat_segment_pos := G_MEM.cat_segments[i].pos
		if cat_head_pos.x == cat_segment_pos.x && cat_head_pos.y == cat_segment_pos.y {
			return true
		}
	}
	return false
}


is_cat_outside_canvas :: proc() -> bool {
	return(
		G_MEM.cat_head.pos.x < 0 ||
		G_MEM.cat_head.pos.x >= NUMBER_OF_GRID_ELEMENTS_IN_A_ROW ||
		G_MEM.cat_head.pos.y < 0 ||
		G_MEM.cat_head.pos.y >= NUMBER_OF_GRID_ELEMENTS_IN_A_ROW \
	)
}

is_cat_head_next_to_star :: proc() -> bool {
	result := false
	cat_grid_pos := G_MEM.cat_head.pos
	star_grid_pos := G_MEM.star_pos

	// cast to i8 because of underflow issues
	if cat_grid_pos.x == star_grid_pos.x {
		y_diff := abs(i8(cat_grid_pos.y - star_grid_pos.y))
		result = y_diff == 1
	}
	if cat_grid_pos.y == star_grid_pos.y {
		x_diff := abs(i8(cat_grid_pos.x - star_grid_pos.x))
		result = x_diff == 1
	}

	if result && G_MEM.game_state == .GAMEPLAY {
		rl.PlaySound(GAME_SOUNDS.pop)
	}

	return result
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
game_assets_size :: proc() -> int {
	return(
		size_of(Cat_Textures) +
		size_of(Star_Textures) +
		size_of(Game_Sounds) +
		size_of([9]^rl.Texture) \
	)
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
