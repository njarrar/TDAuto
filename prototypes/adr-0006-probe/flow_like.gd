extends RefCounted
enum Phase { BUILD, WAVE, FATAL }
signal phase_changed(value: Phase)
signal gold_changed(current: int)
