# Promo video tools

These scripts build `../sunstone-promo-landscape.mp4` (1920x1080, 30 fps, about 64 s, for Play and YouTube) and `../youtube-thumbnail-1280x720.png`. The method comes from snake-classic's `store_listings/play-store-video/tools`. Raw recordings and the music are not committed.

## 1. Record

1. Device: the Galaxy A24 (`RR8W901JDRL`, 1080x2340). Other sessions share the phones, so ask them first and never restart adb.
2. Back up `files/` (save.json, online.json, outbox.json).
3. Install a debug build and switch the phone to light mode with `cmd uimode night no`.
4. Run `run-as com.pranta.sunstone touch files/dev_video`.
5. Start `screenrecord --bit-rate 8000000 --time-limit 178 /sdcard/sun_rec1.mp4`, then launch the game. The video sequence (`game.gd` `_run_video`) plays by itself:
   - the title;
   - each House of nights 1 and 2 (seed 2024, autopilot, can't die);
   - the pack;
   - dawn;
   - the shop shelves, Glyphs and Daily dusk.

   It logs `[video] <name>` at each cut. Their logcat times minus the recording's start time give the cut points.
6. Stop with `pkill -INT screenrecord`, or the mp4 won't play. Pull the clip here as `rec1.mp4`.
7. Afterwards, remove `files/dev_video`, restore `files/`, and put dark mode back if it was on.

## 2. Music

The game's own night music, `assets/audio/music.wav` (made by `tools/make_audio.py`, a seamless loop), looped under the video. It's ours, so YouTube's Content ID has nothing to match. Don't swap in stock music: the first upload used a Pixabay track ("royalty-free") and YouTube flagged it as claimed content, because some Pixabay artists register their tracks with Content ID.

## 3. Render

```
FF=$(python -c "import imageio_ffmpeg as i; print(i.get_ffmpeg_exe())")
python render.py "$FF" scenes.json ../sunstone-promo-landscape.mp4
python thumb.py
```

`scenes.json` lists the cuts: `src`, `a`/`b` in seconds, and `chip`/`title`/`sub` for the caption. The look is light only: the game's bark paper, Dela Gothic One and Nunito, ink, cinnabar and ochre. The phone footage sits on the right with captions on the left. There is a 3 s intro card and a 4.5 s outro card.

`thumb.py` scales the feature graphic (left unchanged) onto a blurred copy of itself at 1280x720.

## 4. Publish

1. Upload the landscape mp4 to YouTube, public or unlisted, not made for kids, with the thumbnail.
2. Paste the `youtube.com/watch?v=` URL (not `/shorts/`) into Play Console > Main store listing > Video.
