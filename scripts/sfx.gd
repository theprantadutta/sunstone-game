class_name Sfx
extends Node
## Sound effects, music and vibration. Clips are synthesized by
## tools/make_audio.py into assets/audio/; a missing clip just stays silent.

const JUMP := "jump"
const SLIDE := "slide"
const LANE := "lane"
const TURN := "turn"
const COIN := "coin"
const STUMBLE := "stumble"
const CRASH := "crash"
const FALL := "fall"
const ROAR := "roar"
const RESULTS := "results"
const TAP := "tap"
const FLARE := "flare"
const FIZZLE := "fizzle"

const VOLUMES := {
	"jump": -6.0, "slide": -8.0, "lane": -14.0, "turn": -8.0, "coin": -10.0,
	"stumble": -4.0, "crash": -2.0, "fall": -4.0, "roar": -3.0, "results": -6.0, "tap": -10.0,
	"flare": -4.0, "fizzle": -10.0,
}

var _streams := {}
var _pool: Array[AudioStreamPlayer] = []
var _music: AudioStreamPlayer
var _sound_on := true
var _music_on := true
var _coin_pitch := 0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for clip in VOLUMES:
		var path := "res://assets/audio/%s.wav" % clip
		if ResourceLoader.exists(path):
			_streams[clip] = load(path)
	for i in 8:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_pool.append(p)
	_music = AudioStreamPlayer.new()
	_music.volume_db = -11.0
	add_child(_music)
	var music_path := "res://assets/audio/music.wav"
	if ResourceLoader.exists(music_path):
		# Looping is set in music.wav.import (forward loop, whole file).
		_music.stream = load(music_path)

func apply_settings(save: SaveData) -> void:
	_sound_on = save.sound
	_music_on = save.music
	if not _music_on:
		_music.stop()
	elif _music.stream and not _music.playing:
		_music.play()

func play_music() -> void:
	if _music_on and _music.stream and not _music.playing:
		_music.play()

func play(clip: String) -> void:
	if not _sound_on or not _streams.has(clip):
		return
	for p in _pool:
		if not p.playing:
			p.stream = _streams[clip]
			p.volume_db = VOLUMES[clip]
			# Coins climb a pentatonic step each pickup, then wrap.
			if clip == COIN:
				p.pitch_scale = [1.0, 1.125, 1.25, 1.5, 1.667][_coin_pitch]
				_coin_pitch = (_coin_pitch + 1) % 5
			else:
				p.pitch_scale = randf_range(0.96, 1.04)
			p.play()
			return

func vibrate(save: SaveData, ms: int) -> void:
	if save.vibration:
		Input.vibrate_handheld(ms)
