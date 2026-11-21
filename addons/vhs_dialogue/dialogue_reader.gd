@tool
extends RefCounted
## Reads the dialogue .txt files. Used by the Dialogue autoload, DialogueTrigger and the exporter.
##
## File format (see the example file in FOLDER):
##   [name]              starts a conversation called "name"
##   NAME: text          a subtitle said by NAME (speaker names in CAPITALS)
##   text                a subtitle with no speaker
##   NAME: text | 4      this subtitle stays up for 4 seconds
##   @wait 1.5           1.5 seconds with no subtitle
##   @event lights_off   sends Dialogue.event("lights_off") to your scripts
##   # note              ignored, on its own line or at the end of a line ("... | 2  # note")
##   \#                  a real # inside a subtitle

## Where the dialogue files live. Subfolders are read too.
const FOLDER := "res://Resources/Data/Dialogue"


## Every .txt file in the folder and its subfolders.
static func find_files(folder: String) -> PackedStringArray:
	var found := PackedStringArray()
	if not DirAccess.dir_exists_absolute(folder):
		return found
	for file in DirAccess.get_files_at(folder):
		if file.get_extension().to_lower() == "txt":
			found.append(folder.path_join(file))
	for sub in DirAccess.get_directories_at(folder):
		found.append_array(find_files(folder.path_join(sub)))
	return found


## Reads every file. Returns { "conversation name": [step, step, ...] }.
## A step is a Dictionary: {type = "line", speaker, text, time} / {type = "wait", time} / {type = "event", name}.
static func read_all(quiet := false) -> Dictionary:
	var conversations := {}
	for path in find_files(FOLDER):
		read_file(path, conversations, quiet)
	return conversations


static func read_file(path: String, into: Dictionary, quiet := false) -> void:
	var current := ""
	var line_number := 0
	for raw in FileAccess.get_file_as_string(path).split("\n"):
		line_number += 1
		var line := _without_note(raw).strip_edges()
		if line.is_empty() or line.begins_with("#"):
			continue
		var where := "%s line %d" % [path.get_file(), line_number]

		# [name] starts a new conversation.
		if line.begins_with("[") and line.ends_with("]"):
			current = line.substr(1, line.length() - 2).strip_edges()
			if into.has(current) and not quiet:
				push_warning("Dialogue: \"%s\" is written twice (%s). The later one is used." % [current, where])
			into[current] = []
			continue
		if current.is_empty():
			if not quiet:
				push_warning("Dialogue: %s is not under a [name] heading, so it is skipped." % where)
			continue

		var step := _read_line(line, where, quiet)
		if not step.is_empty():
			into[current].append(step)


## Cuts off a note at the end of a line: "YOU: Hi | 2   # waves" -> "YOU: Hi | 2".
## A note starts at a # that has a space (or tab) before it. Write \# for a real #.
static func _without_note(raw: String) -> String:
	var line := raw.replace("\\#", char(1))
	for i in range(1, line.length()):
		if line[i] == "#" and (line[i - 1] == " " or line[i - 1] == "\t"):
			line = line.substr(0, i)
			break
	return line.replace(char(1), "#")


static func _read_line(line: String, where: String, quiet: bool) -> Dictionary:
	# @commands
	if line.begins_with("@"):
		var parts := line.substr(1).strip_edges().split(" ", false, 1)
		var command := parts[0].to_lower() if parts.size() > 0 else ""
		var value := parts[1].strip_edges() if parts.size() > 1 else ""
		if command == "wait" and value.is_valid_float():
			return {"type": "wait", "time": value.to_float()}
		if command == "event" and value != "":
			return {"type": "event", "name": value}
		if not quiet:
			push_warning("Dialogue: %s: \"%s\" is not a command I know (use @wait 1.5 or @event name)." % [where, line])
		return {}

	# "... | 4" at the end = how many seconds the subtitle stays up.
	var time := -1.0
	var bar := line.rfind("|")
	if bar != -1 and line.substr(bar + 1).strip_edges().is_valid_float():
		time = line.substr(bar + 1).strip_edges().to_float()
		line = line.substr(0, bar).strip_edges()

	# "NAME: text". The name must be in capitals, so "It is 10:30" is not read as a speaker.
	var speaker := ""
	var colon := line.find(":")
	if colon > 0:
		var who := line.substr(0, colon).strip_edges()
		var has_letters := who.to_lower() != who.to_upper() or who.contains("?")
		if who.length() <= 24 and has_letters and who == who.to_upper():
			speaker = who
			line = line.substr(colon + 1).strip_edges()

	return {"type": "line", "speaker": speaker, "text": line.replace("\\n", "\n"), "time": time}
