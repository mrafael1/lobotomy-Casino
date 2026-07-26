class_name SaveIO
extends RefCounted

## Shared file plumbing for the game's two save files (meta progression + live run).
##
## Writes are atomic: the payload goes to a sibling ".tmp" first and only replaces the
## real file once it is completely on disk. A crash, a task kill, or a phone running out
## of battery mid-write can therefore lose the newest write — never the save itself. The
## previous good copy is kept as ".bak" and read back when the primary turns out to be
## missing, empty, or unreadable, so one bad write cannot end a campaign.

const TMP_SUFFIX := ".tmp"
const BACKUP_SUFFIX := ".bak"

## Writes `text` to `path` atomically. Returns whether the file was committed.
static func write_text(path: String, text: String) -> bool:
	var tmp_path := path + TMP_SUFFIX
	var f := FileAccess.open(tmp_path, FileAccess.WRITE)
	if f == null:
		push_error("Could not open save for write: %s (error %d)"
			% [tmp_path, FileAccess.get_open_error()])
		return false
	f.store_string(text)
	f.close()
	# Never let a write that did not land replace a good save.
	if not FileAccess.file_exists(tmp_path):
		push_error("Save write vanished before commit: " + tmp_path)
		return false
	if FileAccess.file_exists(path):
		DirAccess.copy_absolute(path, path + BACKUP_SUFFIX)
	var err := DirAccess.rename_absolute(tmp_path, path)
	if err != OK:
		push_error("Could not commit save %s (error %d)" % [path, err])
		DirAccess.remove_absolute(tmp_path)
		return false
	return true

## Reads `path`, falling back to the backup when the primary is missing, empty, or
## rejected by `validator` (a Callable taking the text and returning bool). Returns ""
## when nothing usable exists.
static func read_text(path: String, validator := Callable()) -> String:
	for candidate in [path, path + BACKUP_SUFFIX]:
		if not FileAccess.file_exists(candidate):
			continue
		var f := FileAccess.open(candidate, FileAccess.READ)
		if f == null:
			continue
		var text := f.get_as_text()
		f.close()
		if text.is_empty():
			continue
		if validator.is_valid() and not bool(validator.call(text)):
			push_warning("Rejected unusable save: " + candidate)
			continue
		return text
	return ""

## Deletes a save and everything that could resurrect it — including the backup, so a
## deliberate reset cannot be undone by the next load falling through to it.
static func remove(path: String) -> void:
	for candidate in [path, path + TMP_SUFFIX, path + BACKUP_SUFFIX]:
		if FileAccess.file_exists(candidate):
			DirAccess.remove_absolute(candidate)
