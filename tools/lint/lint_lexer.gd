extends RefCounted
## Hand-written lexer for the layer lint (pure, no file access).
##
## lex() masks comments and string contents (same length, line numbers kept) and
## lists the string literals. logical_lines() joins statements continued inside
## brackets or after a backslash and records, for each line, its indent and the
## name of the enclosing function.

const FUNC_PATTERN: String = r"^(?:static\s+)?func\s+(\w+)"


## Masks comments and string contents. Returns {"masked": String, "strings": Array[Dictionary]}.
## A string entry holds: start (index of the opening quote), line, content (unmasked),
## prefix ("", "&", "^", "r", "$" or "%") and triple (bool).
static func lex(text: String) -> Dictionary:
	var out: PackedStringArray = PackedStringArray()
	var strings: Array[Dictionary] = []
	var n: int = text.length()
	var i: int = 0
	var line: int = 1
	while i < n:
		var c: String = text[i]
		if c == "\n":
			out.append(c)
			line += 1
			i += 1
			continue
		if c == "#":
			while i < n and text[i] != "\n":
				out.append(" ")
				i += 1
			continue
		if c == "\"" or c == "'":
			var prefix: String = _prefix_before(text, i)
			var triple: bool = text.substr(i, 3) == c + c + c
			var quote_len: int = 3 if triple else 1
			var raw: bool = prefix == "r"
			var start: int = i
			var start_line: int = line
			for _q in quote_len:
				out.append(c)
			i += quote_len
			var content: String = ""
			while i < n:
				var d: String = text[i]
				if d == "\\" and not raw and i + 1 < n:
					content += d + text[i + 1]
					out.append(" ")
					if text[i + 1] == "\n":
						out.append("\n")
						line += 1
					else:
						out.append(" ")
					i += 2
					continue
				if triple:
					if d == c and text.substr(i, 3) == c + c + c:
						for _q in 3:
							out.append(c)
						i += 3
						break
				else:
					if d == c:
						out.append(c)
						i += 1
						break
					if d == "\n":
						# Unterminated string: leave the newline to the outer loop.
						break
				if d == "\n":
					out.append("\n")
					line += 1
				else:
					out.append(" ")
				content += d
				i += 1
			strings.append({
				"start": start,
				"line": start_line,
				"content": content,
				"prefix": prefix,
				"triple": triple,
			})
			continue
		out.append(c)
		i += 1
	return {"masked": "".join(out), "strings": strings}


## Joins the masked text into logical lines. Each entry: line (first physical line),
## text (leading blanks removed), indent (tab = 4, space = 1), func (enclosing function
## name or ""), is_def (true for a func line). Blank lines are dropped.
static func logical_lines(masked: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var phys: PackedStringArray = masked.split("\n")
	var depth: int = 0
	var buf: String = ""
	var start_line: int = 0
	var start_indent: int = 0
	var continuing: bool = false
	for idx in phys.size():
		var raw: String = phys[idx].rstrip("\r")
		var backslash: bool = raw.rstrip(" \t").ends_with("\\")
		if not continuing:
			start_line = idx + 1
			start_indent = _indent_of(raw)
			buf = raw.lstrip(" \t")
		else:
			buf += " " + raw.strip_edges()
		for ch_i in raw.length():
			var ch: String = raw[ch_i]
			if ch == "(" or ch == "[" or ch == "{":
				depth += 1
			elif ch == ")" or ch == "]" or ch == "}":
				depth -= 1
		if depth < 0:
			depth = 0
		continuing = depth > 0 or backslash
		if backslash:
			buf = buf.rstrip(" \t")
			buf = buf.substr(0, buf.length() - 1)
		if not continuing:
			if buf.strip_edges() != "":
				result.append({
					"line": start_line,
					"text": buf,
					"indent": start_indent,
					"func": "",
					"is_def": false,
				})
			buf = ""
	var func_re: RegEx = RegEx.create_from_string(FUNC_PATTERN, true)
	var cur_name: String = ""
	var cur_indent: int = -1
	for ln: Dictionary in result:
		var ind: int = ln["indent"]
		if cur_indent >= 0 and ind <= cur_indent:
			cur_name = ""
			cur_indent = -1
		var m: RegExMatch = func_re.search(ln["text"])
		if m != null:
			cur_name = m.get_string(1)
			cur_indent = ind
			ln["is_def"] = true
		ln["func"] = cur_name
	return result


## Returns the index just past the body of the line at idx: the following lines
## indented deeper than it. Blank lines are already dropped.
static func body_end(lines: Array[Dictionary], idx: int) -> int:
	var base: int = lines[idx]["indent"]
	var j: int = idx + 1
	while j < lines.size() and int(lines[j]["indent"]) > base:
		j += 1
	return j


static func is_ident_char(c: String) -> bool:
	if c.is_empty():
		return false
	var u: int = c.unicode_at(0)
	return u == 95 or (u >= 48 and u <= 57) or (u >= 65 and u <= 90) or (u >= 97 and u <= 122)


static func _prefix_before(text: String, i: int) -> String:
	if i == 0:
		return ""
	var ch: String = text[i - 1]
	if ch == "&" or ch == "^" or ch == "$" or ch == "%":
		return ch
	if ch == "r" and (i < 2 or not is_ident_char(text[i - 2])):
		return "r"
	return ""


static func _indent_of(raw: String) -> int:
	var total: int = 0
	for k in raw.length():
		var c: String = raw[k]
		if c == "\t":
			total += 4
		elif c == " ":
			total += 1
		else:
			break
	return total
