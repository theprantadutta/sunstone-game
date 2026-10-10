class_name Codex
## The look of the world: a Maya codex page that only shows its colours where
## there is light. Everything 3D is drawn with three shared materials:
##
## - [world]: flat codex shading (three hard bands from a fixed sun, no real
##   lights, no shadows). Inside the light it is the painted colour; outside it
##   is bare night paper, so shapes only read by their ink lines.
## - [glow]: flames, sun-drops, the Sunstone, jaguar eyes — always bright,
##   because they ARE light.
## - [outline]: the scribe's ink line around every shape (an inverted hull,
##   pushed out along a per-vertex direction the Mesher stores in UV/UV2).
##   Black ink in the light, pale chalk in the dark.
##
## The light itself is a handful of circles on the ground plane: the Sunstone,
## up to eight braziers, and the dusk/dawn flood around the runner. [update]
## pushes them to every material once a frame. Beyond the stone's [sight] the
## night swallows even the pale ink: a dim stone sees only a little way ahead.

const MAX_LIGHTS := 8

const NIGHT_LO := Color("#11163A")
const NIGHT_HI := Color("#2B3672")
const PALE_INK := Color("#8391D2")
const INK := Color("#1B1410")
const CINNABAR := Color("#B8322A")

const _PAINT_UNIFORMS := """
uniform vec4 stone = vec4(0.0, 0.0, 0.0, 3.0);
uniform float amb = 0.0;
uniform vec4 lights[8];
uniform float wob_t = 0.0;
uniform vec3 fade_col : source_color = vec3(0.07, 0.09, 0.23);
uniform float fade_near = 30.0;
uniform float fade_far = 58.0;
uniform float sight = 1000.0;

// 1 where the night has swallowed even the ink: unlit and far from the stone.
float swallowed(vec2 p, float m) {
	return (1.0 - m) * smoothstep(sight * 0.45, sight, length(p - stone.xz));
}

float wobble(vec2 p) {
	return (sin(p.x * 1.7 + p.y * 0.9 + wob_t * 0.5) + sin(p.y * 2.3 - p.x * 1.3)) * 0.11;
}

// 1 where the world is painted (lit), 0 where it is bare night paper.
// [edge] is the cinnabar line round each circle of light — only where that
// circle meets the dark, never where another light already paints the ground.
float paint(vec2 p, out float edge) {
	float w = wobble(p);
	float ds = length(p - stone.xz);
	float ma = 1.0 - smoothstep(amb - 1.5, amb, ds + w * 6.0);
	float d = ds + w;
	float best = 1.0 - smoothstep(stone.w - 0.2, stone.w, d);
	float best_e = (1.0 - smoothstep(0.0, 0.07, abs(d - stone.w + 0.05))) * step(0.05, stone.w);
	float second = ma;
	float e_other = 0.0;
	for (int i = 0; i < 8; i++) {
		vec4 L = lights[i];
		if (L.w > 0.0) {
			float dl = length(p - L.xz) + w;
			float mi = 1.0 - smoothstep(L.w - 0.18, L.w, dl);
			float ei = 0.6 * (1.0 - smoothstep(0.0, 0.05, abs(dl - L.w + 0.04)));
			if (mi > best) {
				second = max(second, best);
				e_other = max(e_other, best_e * (1.0 - mi));
				best = mi;
				best_e = ei;
			} else {
				second = max(second, mi);
				e_other = max(e_other, ei * (1.0 - best));
			}
		}
	}
	edge = max(best_e * (1.0 - second), e_other * (1.0 - ma));
	edge *= 1.0 - smoothstep(stone.w - 0.5, stone.w + 1.0, amb);
	return max(best, ma);
}
"""

const _WORLD_SHADER := """
shader_type spatial;
render_mode unshaded, cull_back;
%s
uniform vec3 night_lo : source_color = vec3(0.07, 0.09, 0.23);
uniform vec3 night_hi : source_color = vec3(0.17, 0.21, 0.45);
uniform vec3 ring_col : source_color = vec3(0.72, 0.2, 0.16);
uniform vec3 stone_col : source_color = vec3(1.0, 0.8, 0.45);
uniform sampler2D grain : filter_linear, repeat_enable;
uniform float grain_amount = 1.0;
uniform float grain_scale = 256.0;
uniform vec3 sun_dir = vec3(-0.4, 0.9, 0.22);

varying vec3 wpos;
varying vec3 wnorm;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnorm = (MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz;
}

void fragment() {
	vec3 base = pow(COLOR.rgb, vec3(2.2));
	float ndl = dot(normalize(wnorm), normalize(sun_dir));
	float band = ndl > 0.55 ? 1.0 : (ndl > -0.3 ? 0.82 : 0.66);
	if (COLOR.a > 0.9 && COLOR.a < 0.99) {
		// Characters: soft toon light, so faces never fall into deep shade.
		band = ndl > 0.15 ? 1.0 : (ndl > -0.55 ? 0.92 : 0.84);
	}
	vec3 col = base * band;
	vec3 night = mix(night_lo, night_hi, smoothstep(0.6, 1.0, band));
	if (COLOR.a < 0.9) {
		// Hatched ground: the scribe's diagonal strokes on bare earth.
		float h = step(0.8, fract((wpos.x + wpos.z) * 1.6));
		col *= 1.0 - 0.3 * h;
		night *= 1.0 - 0.12 * h;
	}
	float edge;
	float m = paint(wpos.xz, edge);
	// A warm wash close to the stone: its own light on the ground.
	float near = 1.0 - clamp(length(wpos.xz - stone.xz) / max(stone.w, 0.01), 0.0, 1.0);
	col *= 1.0 + near * near * 0.35 * (1.0 - smoothstep(stone.w, stone.w + 4.0, amb));
	col = mix(col, col * stone_col * 1.25, near * 0.25);
	col = mix(night, col, m);
	col = mix(col, ring_col, edge);
	col = mix(col, fade_col, swallowed(wpos.xz, m));
	col = mix(col, fade_col, smoothstep(fade_near, fade_far, distance(CAMERA_POSITION_WORLD, wpos)));
	// The bark-paper grain of the page, in screen space so it never swims.
	vec3 g = texture(grain, SCREEN_UV * VIEWPORT_SIZE / grain_scale).rgb;
	col *= mix(vec3(1.0), g, grain_amount);
	ALBEDO = col;
}
""" % _PAINT_UNIFORMS

const _GLOW_SHADER := """
shader_type spatial;
render_mode unshaded, cull_back;
%s
uniform float strength = 1.0;
varying vec3 wpos;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec3 col = pow(COLOR.rgb, vec3(2.2)) * strength;
	col = mix(col, fade_col, smoothstep(fade_near, fade_far, distance(CAMERA_POSITION_WORLD, wpos)) * 0.7);
	ALBEDO = col;
}
""" % _PAINT_UNIFORMS

const _OUTLINE_SHADER := """
shader_type spatial;
render_mode unshaded, cull_front, world_vertex_coords;
%s
uniform float width = 0.045;
uniform vec3 ink : source_color = vec3(0.1, 0.08, 0.06);
uniform vec3 pale_ink : source_color = vec3(0.5, 0.56, 0.82);
varying vec3 wpos;

void vertex() {
	vec3 dir = mat3(MODEL_MATRIX) * vec3(UV.x, UV.y, UV2.x);
	float dist = length(CAMERA_POSITION_WORLD - VERTEX);
	VERTEX += dir * width * clamp(dist / 20.0, 0.06, 3.0);
	wpos = VERTEX;
}

void fragment() {
	float edge;
	float m = paint(wpos.xz, edge);
	vec3 col = mix(pale_ink, ink, m);
	col = mix(col, fade_col, swallowed(wpos.xz, m));
	col = mix(col, fade_col, smoothstep(fade_near, fade_far, distance(CAMERA_POSITION_WORLD, wpos)));
	ALBEDO = col;
}
""" % _PAINT_UNIFORMS

static var _world: ShaderMaterial
static var _world_flat: ShaderMaterial
static var _glow: ShaderMaterial
static var _outline: ShaderMaterial
static var _extra: Array[ShaderMaterial] = []

static func world() -> ShaderMaterial:
	_ensure()
	return _world

## The world shading without the ink-line pass (ground, decals).
static func world_flat() -> ShaderMaterial:
	_ensure()
	return _world_flat

static func glow() -> ShaderMaterial:
	_ensure()
	return _glow

static func outline() -> ShaderMaterial:
	_ensure()
	return _outline

## Any other material that uses the paint uniforms (water, decals) joins here
## so [update] feeds it too.
static func register(m: ShaderMaterial) -> void:
	_ensure()
	_extra.append(m)
	m.set_shader_parameter("lights", _empty_lights())

static func paint_uniforms() -> String:
	return _PAINT_UNIFORMS

static func _ensure() -> void:
	if _world != null:
		return
	_outline = _material(_OUTLINE_SHADER)
	_outline.set_shader_parameter("ink", INK)
	_outline.set_shader_parameter("pale_ink", PALE_INK)
	_world = _material(_WORLD_SHADER)
	_world.set_shader_parameter("night_lo", NIGHT_LO)
	_world.set_shader_parameter("night_hi", NIGHT_HI)
	_world.set_shader_parameter("ring_col", CINNABAR)
	_world_flat = _world.duplicate()
	_world.next_pass = _outline
	_glow = _material(_GLOW_SHADER)
	_glow.next_pass = _outline

static func _material(code: String) -> ShaderMaterial:
	var sh := Shader.new()
	sh.code = code
	var m := ShaderMaterial.new()
	m.shader = sh
	m.set_shader_parameter("lights", _empty_lights())
	return m

static func _empty_lights() -> PackedVector4Array:
	var a := PackedVector4Array()
	a.resize(MAX_LIGHTS)
	return a

## Once a frame: where the light is. [stone] = (x, y, z, radius) of the
## Sunstone's circle; [amb] = radius of the dusk/dawn flood around it (0 at
## night, huge in daylight); [lights] = up to eight (x, y, z, radius) braziers;
## [fade] = the colour far things melt into; [sight] = metres from the stone's
## circle centre past which unlit things vanish.
## The paper grain multiplied over the painted world (white = no change).
## [amount] 0 switches it off.
static func set_grain(tex: Texture2D, amount := 1.0, scale := 256.0) -> void:
	_ensure()
	for m in [_world, _world_flat]:
		m.set_shader_parameter("grain", tex)
		m.set_shader_parameter("grain_amount", amount)
		m.set_shader_parameter("grain_scale", scale)

## The tint of the Sunstone's light (its hue from the Market).
static func set_stone_color(c: Color) -> void:
	_ensure()
	_world.set_shader_parameter("stone_col", c)
	_world_flat.set_shader_parameter("stone_col", c)

static func update(stone: Vector4, amb: float, lights: PackedVector4Array, fade: Color, t: float, sight := 1000.0) -> void:
	_ensure()
	var l := lights
	if l.size() != MAX_LIGHTS:
		l = lights.duplicate()
		l.resize(MAX_LIGHTS)
	for m in [_world, _world_flat, _glow, _outline] + _extra:
		m.set_shader_parameter("stone", stone)
		m.set_shader_parameter("amb", amb)
		m.set_shader_parameter("lights", l)
		m.set_shader_parameter("fade_col", fade)
		m.set_shader_parameter("wob_t", t)
		m.set_shader_parameter("sight", sight)
