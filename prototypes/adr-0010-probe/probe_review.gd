extends SceneTree
enum BuildResult { OK = 0, HALTED, REENTERED, BAD_SLOT }
func _check() -> BuildResult:
	return BuildResult.OK
func _init() -> void:
	# R1: enum member named OK vs @GlobalScope.OK
	var r: BuildResult = _check()
	print("R1 enum OK parses; BuildResult.OK=", BuildResult.OK, " bare OK=", OK, " r==OK:", r == OK, " r!=BuildResult.OK:", r != BuildResult.OK)
	# R2: user:// exists headless? create-then-append sequence
	var p := "user://adr0010_review.jsonl"
	if FileAccess.file_exists(p): DirAccess.remove_absolute(ProjectSettings.globalize_path(p))
	print("R2 user dir exists=", DirAccess.dir_exists_absolute(ProjectSettings.globalize_path("user://")), " path=", ProjectSettings.globalize_path("user://"))
	var rw0 := FileAccess.open(p, FileAccess.READ_WRITE)
	print("R3 READ_WRITE missing null=", rw0 == null, " open_error=", FileAccess.get_open_error())
	var w := FileAccess.open(p, FileAccess.WRITE)
	print("R4 WRITE create null=", w == null, " open_error=", FileAccess.get_open_error()); w.close()
	for i in 2:
		var a := FileAccess.open(p, FileAccess.READ_WRITE)
		a.seek_end(); var ok: bool = a.store_line("line%d" % i); a.close()
		print("R5.", i, " append ok=", ok, " open_error=", FileAccess.get_open_error())
	print("R6 content=", FileAccess.get_file_as_string(p).c_escape(), " exists=", FileAccess.file_exists(p))
	# R7: Vector2 component precision
	var v := Vector2(0.1, 0.0); var f: float = 0.1
	print("R7 Vector2.x==float 0.1: ", v.x == f, " v.x=", "%.17f" % v.x, " f=", "%.17f" % f)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(p))
	quit()
