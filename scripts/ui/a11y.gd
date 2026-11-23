class_name A11y
extends RefCounted
## Keyboard access for the menu screens: focusable buttons, number-key picks and
## modal focus traps. Ui.button() makes buttons unfocusable (the match screen wants
## that); menu screens call focus_all() after building their controls.

const MODAL_GROUP := &"modal_overlay"


## Makes every button under `root` reachable with Tab / arrows and pressable with Enter / Space.
static func focus_all(root: Node) -> void:
	for node in root.find_children("*", "BaseButton", true, false):
		(node as BaseButton).focus_mode = Control.FOCUS_ALL


## Focuses the first control that is visible and enabled (next frame, after layout).
static func focus_first(controls: Array) -> void:
	(func() -> void:
		for control in controls:
			if is_instance_valid(control) and _can_focus(control):
				control.grab_focus()
				return).call_deferred()


static func _can_focus(control: Control) -> bool:
	if not control.is_inside_tree() or not control.is_visible_in_tree():
		return false
	if control is BaseButton and control.disabled:
		return false
	return control.get_focus_mode_with_override() != Control.FOCUS_NONE


## Draws the theme's focus ring around `target` (in `holder`: the target itself
## or a parent that contains it) while `target` has visible keyboard focus. For
## widgets with no focus style (cards, panels): the ring sits outside, so it never
## reads as "chosen". A parent holder draws under its children (under the card).
static func ring_on_focus(holder: Control, target: Control, radius: int = UiTheme.RADIUS) -> void:
	holder.draw.connect(func() -> void:
		if is_instance_valid(target) and target.has_focus(true):
			var rect := Rect2(Vector2.ZERO if holder == target else target.position, target.size)
			holder.draw_style_box(UiTheme.focus_ring(radius), rect.grow(2)))
	target.focus_entered.connect(holder.queue_redraw)
	target.focus_exited.connect(holder.queue_redraw)


## 0 for the "1" key (number row or keypad) up to 8 for "9"; -1 for anything else.
static func number_key(event: InputEvent) -> int:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return -1
	for code in [key.keycode, key.physical_keycode]:
		if code >= KEY_1 and code <= KEY_9:
			return code - KEY_1
		if code >= KEY_KP_1 and code <= KEY_KP_9:
			return code - KEY_KP_1
	return -1


## The display text of the first key bound to an InputMap action ("E", "Space",
## "F1"), in the player's keyboard layout. "" when the action has no key.
static func key_label(action: StringName) -> String:
	if not InputMap.has_action(action):
		return ""
	for event in InputMap.action_get_events(action):
		var key := event as InputEventKey
		if key != null:
			return key_name(key.physical_keycode if key.physical_keycode != KEY_NONE else key.keycode)
	return ""


## Short display text for a physical key, as the current layout labels it.
static func key_name(physical_keycode: int) -> String:
	var code := physical_keycode as Key
	# The headless display server has no keyboard layout (and errors on the call).
	if DisplayServer.get_name() != "headless":
		var layout_code := DisplayServer.keyboard_get_keycode_from_physical(code)
		if layout_code != KEY_NONE:
			code = layout_code
	var text := OS.get_keycode_string(code)
	return {"Escape": "Esc", "Kp 1": "Num 1"}.get(text, text)


## A fresh press of a game action (InputMap rc_*), ignoring held-key repeats.
static func is_action(event: InputEvent, action: StringName) -> bool:
	return event.is_action_pressed(action, false, false) and not event.is_echo()


## A fresh press of `keycode` (layout key, no modifiers).
static func is_key(event: InputEvent, keycode: Key) -> bool:
	var key := event as InputEventKey
	return key != null and key.pressed and not key.echo and key.keycode == keycode \
		and not (key.ctrl_pressed or key.meta_pressed or key.alt_pressed)


## True while a modal overlay (one that called trap_focus) is open: screens
## ignore their own shortcuts then.
static func is_modal_open(node: Node) -> bool:
	return node.is_inside_tree() and node.get_tree().has_group(MODAL_GROUP)


## Keeps keyboard focus inside a modal overlay: everything drawn before it stops
## taking focus until release is called (or the overlay leaves the tree), then focus
## goes back to the control that had it. Returns the release callable.
## Until then the overlay is in MODAL_GROUP (see is_modal_open).
static func trap_focus(overlay: Control) -> Callable:
	overlay.add_to_group(MODAL_GROUP)
	# Weak: the control that had focus may be freed before the overlay closes.
	var owner := overlay.get_viewport().gui_get_focus_owner()
	var previous: WeakRef = weakref(owner) if owner != null else null
	var blocked: Array[Control] = []
	var node: Node = overlay
	while node.get_parent() is Control:
		for sibling in node.get_parent().get_children():
			if sibling == node:
				break
			if sibling is Control and sibling.focus_behavior_recursive == Control.FOCUS_BEHAVIOR_INHERITED:
				sibling.focus_behavior_recursive = Control.FOCUS_BEHAVIOR_DISABLED
				blocked.append(sibling)
		node = node.get_parent()
	var release := func() -> void:
		if is_instance_valid(overlay) and overlay.is_in_group(MODAL_GROUP):
			overlay.remove_from_group(MODAL_GROUP)
		for control in blocked:
			if is_instance_valid(control):
				control.focus_behavior_recursive = Control.FOCUS_BEHAVIOR_INHERITED
		blocked.clear()
		(func() -> void:
			var control: Control = previous.get_ref() if previous != null else null
			if control != null and _can_focus(control):
				control.grab_focus()).call_deferred()
	overlay.tree_exiting.connect(release)
	return release
