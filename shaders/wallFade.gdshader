shader_type canvas_item;

// Fades only the part of a wall that is actually covering the player, instead
// of dimming every front wall in the map at once.
//
// The previous approach was a hand-drawn trigger polygon that modulated the
// whole FrontWalls layer. It only covered part of the room, so standing
// anywhere else left the player hidden behind a solid wall, and it could not
// work at all in a generated level where no such polygon exists.

// Player position in world space, pushed in from WallFade.gd each frame.
uniform vec2 player_world = vec2(0.0);
// Fully transparent within this distance of the player.
uniform float radius : hint_range(0.0, 400.0) = 70.0;
// Distance over which the wall fades back to solid.
uniform float softness : hint_range(1.0, 400.0) = 90.0;
// Never go fully invisible; a ghost of the wall keeps the room readable.
uniform float min_alpha : hint_range(0.0, 1.0) = 0.22;
// Only fade walls nearer the camera than the player. A wall behind her is not
// in the way, and fading it would open holes in the far side of the room.
uniform float behind_bias = 24.0;

varying vec2 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

void fragment() {
	COLOR = texture(TEXTURE, UV);

	// Screen is 2:1, so undo the vertical squash before measuring distance or
	// the cutout comes out as an ellipse.
	vec2 delta = world_pos - player_world;
	delta.y *= 2.0;
	float ring = smoothstep(radius, radius + softness, length(delta));

	// 1.0 when this pixel belongs to a wall in front of the player.
	float in_front = step(player_world.y - behind_bias, world_pos.y);

	float fade = mix(min_alpha, 1.0, ring);
	COLOR.a *= mix(1.0, fade, in_front);
}
