extends RefCounted
signal fired(n: int)
signal inner(n: int)
signal nobody(n: int)
var log: Array[String] = []
