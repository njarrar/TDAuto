# ADR-0003 device spike

PROTOTYPE - NOT FOR PRODUCTION. A small standalone Godot 4.7 project. Nothing in
`src/` may load or copy from it.

## What it tests

ADR-0003 (`docs/architecture/adr-0003-input-adapter-display-stretch-platform-lifecycle.md`)
makes input, display and lifecycle decisions that the pinned engine reference
cannot confirm. Each one is a spike item, SP0 to SP12. This kit answers them by
logging what the engine actually does on your desktop and on your phone.

Hypothesis: with the settings ADR-0003 proposes (540x960 viewport, stretch mode
`canvas_items`, aspect `keep`, portrait, touch emulated from the mouse, mouse
emulated from touch, `quit_on_go_back` off), Godot 4.7.2 behaves as the
"expected" result of every spike item says. Any other result picks the fallback
branch the ADR names for that item.

Status: **in progress, not yet run.** The scripts were written without an
editor to check them. If the project shows a script error when you open it,
copy the error text (Output panel) into the results table under "Notes" and
tell the session; do not work around it yourself.

Findings: none yet. They go in the results table at the end.

## What is on the screen

The screen is the 540x960 field, in field units.

| Area | y range | What it is |
|---|---|---|
| Status line | 0 to 40 | Frame number, how many input events came after a PROC or after a PHYS marker, the last touch press position |
| Log | 40 to 595 | The newest lines of the log (the file keeps all of them). Lets touches through |
| STOP band (red) | 600 to 690 | A Control with `mouse_filter = STOP`. Logs what it receives as `CTRL-STOP` |
| PASS band (orange) | 700 to 770 | A Control with `mouse_filter = PASS`. Logs as `CTRL-PASS` |
| Free field | 770 to 885 | Nothing on top. Start drags here |
| Buttons | 890 to 950 | Mark, Clear, Copy, Aspect, Hover, Accept |

Also drawn: a white border round the field, yellow lines 36 units from each side
edge (the edge reject margin), magenta bands for the safe-area insets the ADR's
formula computes, a blue circle under each finger that is down, and a red cross
at the last press. Green crosshairs mark known field positions:
(270,300), (36,300), (504,300), (270,825), (36,825).

Buttons:

- **Mark**: writes a `MARK n` line. Tap it before every numbered action below,
  so you can find each action in the log.
- **Clear**: empties the screen view only.
- **Copy**: copies the whole log of this run to the clipboard. Use it on a phone
  to paste the log into a message or note.
- **Aspect** (shows `keep`): cycles the aspect `keep`, `keep_width`, `expand` and
  logs the new display state. Used only in SP7. Set it back to `keep` after.
- **Hover**: shows or hides mouse moves with no button held, on screen only.
- **Accept**: makes both bands call `accept_event()` on touch events. Used only
  in SP3, Branch C.

## How to read the log

Each file line is:

```
000123 f456 pf912 t12345678 after=PROC IN TOUCH dev=0 i=0 pos=(270.0,300.0) pressed=true canceled=false double=false
```

- `000123` sequence number. The file order is the real order.
- `f456` process frame (`Engine.get_process_frames()`), `pf912` physics frame.
- `t...` time in microseconds (`Time.get_ticks_usec()`).
- `after=PROC` the last frame marker before this line: `PROC` (the root's
  `_process`), `PHYS` (the root's `_physics_process`) or `START`.
- Tag: `IN` (`_input` of the adapter stand-in), `UNH` (its `_unhandled_input`),
  `CTRL-STOP` / `CTRL-PASS` (a band's `_gui_input`, positions local to the
  band), `NOTE-ROOT` / `NOTE-DEEP` (a notification on the scene root, or on the
  node two levels below it, where the real adapter will sit), `WIN-SIG` (a
  root Window signal), `DISPLAY`, `INFO`, `MARK`.
- Event text: `TOUCH` (InputEventScreenTouch), `DRAG` (InputEventScreenDrag),
  `MBTN` (InputEventMouseButton), `MMOV` (InputEventMouseMotion), `KEY`, or the
  class name. `dev=` is the device ID, with `(MOUSE)`, `(KEYBOARD)` or
  `(EMULATION)` added when it matches that `InputEvent.DEVICE_ID_*` constant.
- `PHYS` and `PROC` lines are frame markers. Frames with nothing else in them
  are left out. A `ctx` line shows the quiet PROC that a group follows.
- Notification lines show the number and every constant name with that number.
  `LIFE` marks the app and window lifecycle ones. The start-up `INFO` line
  "lifecycle constants" lists each name with its number, or `absent`.

The log file is `user://spike_log.txt`. The previous run is kept as
`spike_log_prev.txt` next to it. The start-up `INFO` line `user_dir=` gives the
full path. Every line is also printed to standard output (the editor's Output
panel, `adb logcat`, or the Xcode console).

## How to run it

### Desktop (Windows, macOS or Linux)

1. Open Godot 4.7.2. In the Project Manager choose **Import**, pick
   `prototypes/adr-0003-device-spike/project.godot`, and open it. (Opening it
   lets the editor import the project once.)
2. Press **F5** (Run Project). A 450x800 window opens.
3. Do the desktop actions below, tapping **Mark** before each one.
4. Close the window. Copy `spike_log.txt` from the `user_dir` shown at the top
   of the log (on Windows `%APPDATA%\Godot\app_userdata\ADR-0003 device spike\`,
   on macOS `~/Library/Application Support/Godot/app_userdata/ADR-0003 device spike/`,
   on Linux `~/.local/share/godot/app_userdata/ADR-0003 device spike/`).

### Android phone

1. In the editor: **Editor > Editor Settings > Export > Android**, set the Java
   SDK path and the Android SDK path (Godot's Android export docs list what to
   install). Install the Android export templates if the editor asks.
2. **Project > Export > Add... > Android**. Keep the defaults, including
   **Screen > Immersive Mode** and the edge-to-edge option as they are, and
   note their values in the results table. Close the dialog.
3. On the phone: turn on Developer options and USB debugging, connect it by USB,
   and accept the computer's key. Use gesture navigation if the phone has it
   (Settings > System > Gestures), because the Pillar 4 test uses it.
4. In the editor, click the Android icon at the top right (one-click deploy).
   The app installs and starts.
5. Do the phone actions below, tapping **Mark** before each one.
6. Get the log, one of two ways:
   - Tap **Copy** and paste into a note or message to yourself, or
   - With the phone connected:
     `adb shell run-as <package> cat files/spike_log.txt > spike_log_android.txt`.
     `<package>` is the preset's **Package > Unique Name**.
7. Write down the phone model, Android version, screen resolution and the
   phone's dp width (Developer options > Smallest width).

### iPhone (if you have a Mac and an Apple developer account)

1. **Project > Export > Add... > iOS**, fill in the team ID and bundle ID, and
   export the Xcode project.
2. Open it in Xcode, pick your phone, press Run.
3. Do the phone actions below. Read the log in the Xcode console, or tap
   **Copy** and paste it into a note.

## Actions

Tap **Mark** before each numbered action. "Phone" means Android, and iOS if you
have one.

### Desktop

1. Wait 3 seconds without touching anything. (SP0, SP1 baseline)
2. Left-click each green crosshair once. (SP5, SP6)
3. Right-click, middle-click and scroll the wheel once each in the free field. (SP5)
4. Press in the free field, drag up into the STOP band, release there. (SP2)
5. Press in the free field, drag up across both bands into the log area, release there. (SP2)
6. Click the STOP band once, then the PASS band once. (SP3)
7. Press on the STOP band, drag down into the free field, release there. (SP3)
8. Turn **Accept** on, repeat action 6, turn **Accept** off. (SP3)
9. Click another window so the spike loses focus, wait 2 seconds, click back. (SP10)
10. Minimise the window, wait 2 seconds, restore it. (SP10, SP11)
11. Press and hold in the free field, and while holding, press Alt+Tab (Cmd+Tab
    on macOS) to another window; release the button there; come back. (SP11)
12. Drag a window edge to resize it, then maximise it, then restore it. (SP7, SP12)
13. Tap **Aspect** until it shows `keep_width`, then `expand`, then `keep`,
    resizing the window tall and thin each time. (SP7)

### Phone

1. Wait 3 seconds without touching anything. (SP0, SP1, SP7, SP8, SP9)
2. Tap each green crosshair once with one finger. (SP4, SP5, SP6)
3. Tap once in each letterbox bar (the black area above and below the field),
   if the phone shows bars. (SP6, SP7)
4. Press in the free field, drag up into the STOP band, lift there. (SP2)
5. Press in the free field, drag up across both bands into the log area, lift there. (SP2)
6. Tap the STOP band once, then the PASS band once. (SP3)
7. Press on the STOP band, drag down into the free field, lift there. (SP3)
8. Turn **Accept** on, repeat action 6, turn **Accept** off. (SP3)
9. Put two fingers down in the free field one after the other, move both, lift
    one, then the other. (SP4)
10. Rest the side of your hand on the screen for 2 seconds, then lift it. (SP4)
11. Start a swipe from the very left edge, slowly, as a back gesture, and let
    it complete. The app should stay open. (SP4, SP10)
12. Hold one finger in the free field, and with the other hand pull down the
    notification shade, then close it, then lift the finger. (SP4, SP10)
13. Go home (home gesture or button), wait 3 seconds, open the app again from
    Recents. (SP10, SP11)
14. Switch to another app through Recents, then back. (SP10, SP11)
15. Lock the phone with the power button, wait 3 seconds, unlock. (SP10, SP11)
16. Hold one finger in the free field, and with the other hand go home; come
    back to the app while still holding; move the finger, then lift it. (SP11)
17. Turn the phone sideways with auto-rotate on. The app should stay portrait. (SP0, SP7)
18. If the phone supports split screen or pop-up view, open the app in it,
    then go back to full screen. (SP12)
19. Tap **Aspect** until it shows `keep_width`, look at the screen, then
    `expand`, then back to `keep`. Take a screenshot of each. (SP7)
20. On a phone with a notch or punch-hole camera: check that the magenta
    overlay (if any) covers the notch and the home indicator area, and take a
    screenshot. (SP8)

## What each spike item checks

The expected result and the branch for each other result are in the ADR,
Engine Compatibility, Spike items. This list says where to look in the log.

| Item | Question | Where to look |
|---|---|---|
| SP0 | Do the settings take effect? | Start-up `INFO setting ...` and `runtime ...` lines; the `DISPLAY start` line shows `content_scale mode` and `aspect`; phone action 17 |
| SP1 | Are input events delivered between frames, never after a physics step and before the frame's `_process`? | `after=` on every `IN` line; the status counter "after PHYS" |
| SP2 | Does a drag that crosses or ends on a STOP Control still reach `_input` with every move and the release? | `IN` lines for `DRAG` and the `TOUCH pressed=false` in desktop and phone actions 4 and 5; note whether `UNH` and `CTRL-STOP` lines also appear |
| SP3 | Does a STOP Control take a press so that `_unhandled_input` never sees it? Does the Control get `TOUCH`, `MBTN` or both? What do PASS and `accept_event()` change? | Actions 6 to 8: compare `IN`, `CTRL-STOP`, `CTRL-PASS` and `UNH` lines for the same press |
| SP4 | Which fields do touch events carry? Does a system gesture or palm give `canceled=true`? | `TOUCH` lines in phone actions 9 to 12 |
| SP5 | Does one click or tap give exactly one touch press? What device IDs do real and emulated events carry? Do right and middle buttons make touch events? | Desktop actions 2 and 3, phone action 2; the start-up `INFO devices` line |
| SP6 | Are event positions in field units? | `pos=` of each `IN TOUCH` press against the crosshair labels; letterbox taps |
| SP7 | Is the visible rect 540x960 under `keep` everywhere? Where are the bars, what colour? What do `keep_width` and `expand` look like? | `DISPLAY` lines (`visible_rect`, `final_xform`, `root.size`), screenshots |
| SP8 | What does `get_display_safe_area()` return, in what units and space? | `safe=`, `screen=`, `window=`, `window_pos=`, `cutouts=` in `DISPLAY` lines; the magenta overlay |
| SP9 | Does density give the right dp width? | `dpi=`, `scale=` and `formula_field_width_dp=` against the phone's Smallest width |
| SP10 | Which lifecycle notifications fire, in what order, and do they reach the deep node? Do Window signals fire? Does the back gesture quit? | `NOTE-ROOT`, `NOTE-DEEP` and `WIN-SIG` lines around desktop actions 9 and 10, phone actions 11 to 15 |
| SP11 | On return, do the notifications come before the first `PROC`, and how large is its `delta_ms`? What happens to a finger held across the switch? | Lines after the return in phone actions 13 to 16 and desktop actions 10 and 11 |
| SP12 | Does `Viewport.size_changed` fire on resize, and does the visible rect stay 540x960? | `DISPLAY Viewport.size_changed` lines and `changed (seen by polling)` lines in desktop action 12 and phone action 18 |

## Results

Fill in one column per device. Write what the log shows, not a verdict; the
branch column is filled in by whoever records the result against the ADR.

Devices:

| Column | Device | OS and version | Resolution | dp width | Godot | Export options (immersive, edge-to-edge) | Date |
|---|---|---|---|---|---|---|---|
| D | | | | n/a | 4.7.2 | n/a | |
| A1 | | | | | 4.7.2 | | |
| A2 | | | | | 4.7.2 | | |
| I | | | | | 4.7.2 | | |

| Item | What to record | D | A1 | A2 | I | Branch taken (ADR) | Notes |
|---|---|---|---|---|---|---|---|
| SP0 | Running stretch mode, aspect, orientation, both emulation flags, quit_on_go_back; did the phone rotate? | | | | | | |
| SP1 | Count of `IN` lines with `after=PHYS` (0 expected); any event between two PHYS lines of one frame? | | | | | | |
| SP2 | For a drag ending on the STOP band: did `_input` get every DRAG and the release? Did `UNH` and `CTRL-STOP` get them? | | | | | | |
| SP3 | Press on STOP band: `UNH` line present? `CTRL-STOP` got TOUCH, MBTN or both? PASS band? Effect of Accept? | | | | | | |
| SP4 | Touch fields present (`canceled`, `double`)? Which actions gave `canceled=true`? | | | | | | |
| SP5 | Touch presses per click or tap; device IDs of real touch, emulated touch, real mouse, emulated mouse; right or middle click made a TOUCH? | | | | | | |
| SP6 | Largest gap between a crosshair and its `pos=`; letterbox tap positions | | | | | | |
| SP7 | `visible_rect`, `root.size`, `final_xform`; bar positions and colour; what keep_width and expand showed | | | | | | |
| SP8 | `safe=`, `screen=`, `window=`, `window_pos=`, `cutouts=`; formula insets; overlay matches notch? | | | | | | |
| SP9 | `dpi=`, `scale=`, `formula_field_width_dp=` against the real dp width | | | | | | |
| SP10 | Notifications (number and name) in order, per action; seen on NOTE-DEEP as well as NOTE-ROOT? WIN-SIG lines? Did back quit the app? | | | | | | |
| SP11 | First `PROC` after return: before or after the resume notifications, and its `delta_ms`; events for the held finger after return | | | | | | |
| SP12 | `size_changed` fired on resize or split screen? `visible_rect` after it | | | | | | |

When every row has a result for D and at least one Android column, copy the
facts into `docs/engine-reference/godot/modules/input.md` and `modules/ui.md`
(with device, OS version and date), revise ADR-0003 to any fallback branch the
results chose, and keep the logs and screenshots in `production/qa/evidence/`.

## Files

| File | What it does |
|---|---|
| `project.godot` | The spike's own project, with ADR-0003's display and input settings |
| `main.tscn`, `main.gd` | Scene root: builds the screen, writes the start-up report, marks PHYS and PROC, logs notifications, Window signals and display changes |
| `adapter_stand_in.gd` | Sits where the real InputAdapter will sit; logs `_input`, `_unhandled_input` and its own notifications |
| `spike_panel.gd` | The STOP and PASS bands; logs `_gui_input` |
| `field_view.gd` | Draws the field, margins, insets, crosshairs and touches |
| `spike_log.gd` | Groups lines by frame and writes the screen view, the file and stdout |
| `spike_info.gd` | Notification and device names read from the engine, and the one-line event description |
