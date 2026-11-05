class_name ViewStyles extends RefCounted
## Presentation constants for the battle field (ADR-0011 Decisions 4 and 6). Const only;
## never instantiated. Colours, sizes, durations and pool sizes are presentation values
## (Data Rule 1), provisional until the art bible pass. Each group cites its ADR line.

## Added to every stated stroke width (ADR-0011 Decision 6). PROVISIONAL until V4.
const LINE_BIAS: float = 1.0
## No stroke is drawn thinner than this after the bias.
const MIN_STROKE: float = 2.0
const ENEMY_POOL: int = 48
const FLASH_POOL: int = 16
const TRACER_POOL: int = 64
const DEATH_POOL: int = 48
const GLOW_POOL: int = 8
## HUD text sizes in field units (14, 16 and 24 dp). No other size is drawn.
const TEXT_SIZES: PackedInt32Array = [21, 24, 36]

## View durations in view milliseconds (they run on view_ms and freeze on Pause).
const FLASH_MS: float = 80.0
const TRACER_MS: float = 100.0
const DEATH_MS: float = 250.0
const GLOW_MS: float = 400.0
const DANGER_HOLD_MS: float = 1500.0
const LEAK_POP_MS: float = 200.0
const CLEARANCE_TAIL_MS: float = 150.0
const FLASH_ALPHA_TOWER: float = 0.5
const FLASH_ALPHA_HERO: float = 0.9
const DANGER_PULSE_PERIOD_MS: float = 800.0
## Path length from the exit inside which an enemy counts as dangerous.
const DANGER_ZONE: float = 160.0
const FIELD_DIP: float = 0.02
const GRID_STEP: float = 60.0
const SLOT_RADIUS: float = 36.0
const ENEMY_RADIUS: float = 16.0
const HERO_RADIUS: float = 20.0
const DEATH_RADIUS: float = 18.0
const BOB_AMPLITUDE: float = 2.0

## Kinds of enemy for draw order: heavy, then normal, then fast.
const KIND_HEAVY: int = 0
const KIND_NORMAL: int = 1
const KIND_FAST: int = 2

## Words that a visual key must contain to have a style.
const WORDS: Array[StringName] = [&"heavy", &"normal", &"fast", &"grunt", &"single", &"splash", &"slow", &"hero"]

const FIELD_HUE_MIN: float = 170.0
const FIELD_HUE_MAX: float = 280.0
const BASE_VALUE_MIN: float = 0.08
const BASE_VALUE_MAX: float = 0.14
const GRID_TILTS: Array[int] = [0, 15, 30]

const PATH_EDGE: Color = Color(0.55, 0.60, 0.70, 1.0)
const PATH_BODY: Color = Color(0.20, 0.23, 0.30, 1.0)
const GRID_LINE: Color = Color(1.0, 1.0, 1.0, 0.06)
const SLOT_RING: Color = Color(0.80, 0.85, 0.95, 0.9)
const DANGER_TINT: Color = Color(0.95, 0.25, 0.20, 0.35)
const CHEVRON: Color = Color(0.95, 0.45, 0.35, 0.9)
const RING_RANGE: Color = Color(1.0, 1.0, 1.0, 0.35)
const RING_READY: Color = Color(0.95, 0.95, 0.60, 1.0)
const RING_COOLING: Color = Color(0.55, 0.55, 0.60, 1.0)
const TRACER_TOWER: Color = Color(1.0, 0.95, 0.60, 1.0)
const TRACER_HERO: Color = Color(0.60, 0.95, 1.0, 1.0)
const TRACER_BURST: Color = Color(1.0, 0.70, 0.30, 1.0)
const FLASH: Color = Color(1.0, 1.0, 1.0, 1.0)
const DEATH_DISC: Color = Color(1.0, 0.85, 0.50, 1.0)
const CORE_DAMAGED: Color = Color(0.15, 0.05, 0.05, 1.0)
const SLOW_LINE: Color = Color(0.50, 0.80, 1.0, 0.8)
const KEYLINE: Color = Color(0.05, 0.05, 0.08, 1.0)
const HERO_BODY: Color = Color(0.40, 0.90, 1.0, 1.0)
const HERO_LEASH: Color = Color(0.40, 0.90, 1.0, 0.4)
const HERO_GHOST: Color = Color(0.40, 0.90, 1.0, 0.5)
const HERO_REACH: Color = Color(1.0, 0.85, 0.40, 0.5)
const HERO_PREVIEW: Color = Color(1.0, 0.85, 0.40, 0.9)
const KILL_MARK: Color = Color(1.0, 0.30, 0.30, 1.0)
const HUD_TEXT: Color = Color(0.95, 0.96, 0.98, 1.0)
const HUD_DIM: Color = Color(0.95, 0.96, 0.98, 0.4)
const HUD_PANEL: Color = Color(0.08, 0.09, 0.12, 0.85)
const HUD_FILL: Color = Color(0.95, 0.96, 0.98, 1.0)
const SCRIM: Color = Color(0.0, 0.0, 0.0, 0.4)


## Number of points for a ring of this radius.
static func ring_points(radius: float) -> int:
	return clampi(int(radius * 0.5), 16, 96)


## A stated stroke width with the provisional bias, never under MIN_STROKE.
static func stroke(stated: float) -> float:
	return maxf(MIN_STROKE, stated + LINE_BIAS)


## The style word inside a visual key, or &"" if none matches.
static func word_of(key: StringName) -> StringName:
	var text: String = String(key)
	for word: StringName in WORDS:
		if text.contains(String(word)):
			return word
	return &""


## True when the key has a style entry.
static func has_style(key: StringName) -> bool:
	return word_of(key) != &""


## Enemy draw kind (heavy, normal, fast) for a visual key; unknown words draw as normal.
static func kind_of(key: StringName) -> int:
	var word: StringName = word_of(key)
	if word == &"heavy":
		return KIND_HEAVY
	if word == &"fast":
		return KIND_FAST
	return KIND_NORMAL


## Body colour for a visual key.
static func color_of(key: StringName) -> Color:
	match word_of(key):
		&"heavy":
			return Color(0.85, 0.35, 0.35, 1.0)
		&"fast":
			return Color(0.95, 0.80, 0.30, 1.0)
		&"single":
			return Color(0.55, 0.80, 0.95, 1.0)
		&"splash":
			return Color(0.95, 0.60, 0.35, 1.0)
		&"slow":
			return Color(0.60, 0.55, 0.95, 1.0)
		&"hero":
			return HERO_BODY
		_:
			return Color(0.75, 0.80, 0.55, 1.0)
