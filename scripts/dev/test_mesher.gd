extends Node3D
## Dev-only: renders one of each Mesher primitive to check winding and normals.

func _ready() -> void:
	var m := Mesher.new()
	m.box(Transform3D(Basis(), Vector3(-2.5, 0.5, 0)), Vector3(1.4, 1.0, 1.4), Color("#3FA7B5"))
	m.prism(Transform3D(Basis(), Vector3(0, 0, 0)), 0.7, 0.4, 1.6, 6, Color("#B8322A"))
	m.blob(Transform3D(Basis(), Vector3(2.5, 0.8, 0)), 0.8, Color("#2F6B3A"), 0.15, 3)
	m.prism(Transform3D(Basis(), Vector3(0, 2.2, 0)), 0.5, 0.0, 0.8, 5, Color("#F4B732"), true)
	add_child(m.to_instance())
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-45, -30, 0)
	add_child(sun)
	var cam := Camera3D.new()
	cam.position = Vector3(0, 2.5, 6.5)
	add_child(cam)
	cam.look_at(Vector3(0, 0.8, 0))
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color("#2A1B3D")
	env.environment.ambient_light_color = Color(0.5, 0.45, 0.55)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.glow_enabled = true
	add_child(env)
