extends RefCounted

const VERB_LOOK := "look"
const VERB_USE := "use"
const VERB_TALK := "talk"
const VERB_HACK := "hack"
const VERB_ENTER := "enter"

const ALLOWED_VERBS := [VERB_LOOK, VERB_USE, VERB_TALK, VERB_HACK, VERB_ENTER]

static func build_intent(
	id: String,
	verb: String,
	target: String,
	scene_path: String,
	node_path: String,
	params: Dictionary = {},
	turn: int = -1
) -> Dictionary:
	var intent := {
		"id": id,
		"verb": verb,
		"target": target,
		"params": params,
		"source": {
			"scene_path": scene_path,
			"node_path": node_path
		}
	}
	if turn >= 0:
		intent["turn"] = turn
	return intent

static func validate_intent(intent: Dictionary) -> Dictionary:
	var errors: Array[String] = []

	if not intent.has("id") or typeof(intent["id"]) != TYPE_STRING:
		errors.append("Missing or invalid id.")

	if not intent.has("verb") or typeof(intent["verb"]) != TYPE_STRING:
		errors.append("Missing or invalid verb.")
	else:
		var verb: String = intent["verb"]
		if not ALLOWED_VERBS.has(verb):
			errors.append("Unsupported verb: " + verb)

	if not intent.has("target") or typeof(intent["target"]) != TYPE_STRING:
		errors.append("Missing or invalid target.")

	if not intent.has("params") or typeof(intent["params"]) != TYPE_DICTIONARY:
		errors.append("Missing or invalid params.")

	if not intent.has("source") or typeof(intent["source"]) != TYPE_DICTIONARY:
		errors.append("Missing or invalid source.")
	else:
		var source: Dictionary = intent["source"] as Dictionary
		if not source.has("scene_path") or typeof(source["scene_path"]) != TYPE_STRING:
			errors.append("Missing or invalid source.scene_path.")
		if not source.has("node_path") or typeof(source["node_path"]) != TYPE_STRING:
			errors.append("Missing or invalid source.node_path.")

	return {
		"ok": errors.is_empty(),
		"errors": errors
	}
