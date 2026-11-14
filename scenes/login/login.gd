extends Control
## Login screen: Guest, Google (honest "not available yet"), Email login, Create account, Forgot password.

var _card: VBoxContainer
var _status: Label

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(UITheme.gradient_background())
	add_child(UITheme.tricolor_strip())
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(540, 0)
	panel.add_theme_stylebox_override("panel", UITheme.box(UITheme.COL_PANEL, 22, Color(1, 1, 1, 0.10), 1, Vector2(34, 24)))
	center.add_child(panel)
	_card = VBoxContainer.new()
	_card.add_theme_constant_override("separation", 10)
	panel.add_child(_card)
	_show_welcome()

func _begin(subtitle: String) -> void:
	for c in _card.get_children():
		_card.remove_child(c)
		c.queue_free()
	_card.add_child(UITheme.label("CITY LIFE INDIA", 38, UITheme.COL_SAFFRON, HORIZONTAL_ALIGNMENT_CENTER))
	_card.add_child(UITheme.label(subtitle, 18, UITheme.COL_MUTED, HORIZONTAL_ALIGNMENT_CENTER))
	_status = UITheme.label("", 16, UITheme.COL_MUTED, HORIZONTAL_ALIGNMENT_CENTER)
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.custom_minimum_size = Vector2(470, 40)
	_card.add_child(_status)

func _add_button(text: String, accent: bool, action: Callable) -> void:
	var b := UITheme.button(text, accent, 50)
	b.pressed.connect(action)
	_card.add_child(b)

func _set_status(text: String, ok := false) -> void:
	_status.text = text
	_status.add_theme_color_override("font_color", UITheme.COL_OK if ok else UITheme.COL_DANGER)

func _show_welcome() -> void:
	_begin("Sign in to continue")
	_add_button("Continue as Guest", true, _on_guest)
	_add_button("Sign in with Google", false, _on_google)
	_add_button("Login with Email", false, func() -> void: _show_form("login"))
	_add_button("Create Account", false, func() -> void: _show_form("create"))
	_add_button("Forgot Password", false, func() -> void: _show_form("forgot"))
	if not AuthManager.FIREBASE_AVAILABLE:
		var note := UITheme.label("DEV MODE: online accounts (Firebase) arrive in Phase 5. Email accounts here are stored on this device only.", 14, UITheme.COL_MUTED, HORIZONTAL_ALIGNMENT_CENTER)
		note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		note.custom_minimum_size.x = 470
		_card.add_child(note)

func _show_form(kind: String) -> void:
	var titles := {"login": "Login with Email", "create": "Create Account", "forgot": "Reset Password"}
	_begin(titles[kind])
	var email := UITheme.line_edit("Email")
	email.keyboard_type = LineEdit.KEYBOARD_TYPE_EMAIL_ADDRESS
	_card.add_child(email)
	var username: LineEdit = null
	var pw: LineEdit = null
	var confirm: LineEdit = null
	if kind == "create":
		username = UITheme.line_edit("Username (3-20 characters)")
		_card.add_child(username)
	if kind != "forgot":
		pw = UITheme.line_edit("Password", true)
		_card.add_child(pw)
	if kind == "create":
		confirm = UITheme.line_edit("Confirm password", true)
		_card.add_child(confirm)
	var submit := func() -> void:
		var res: Dictionary
		match kind:
			"login": res = AuthManager.login_dev(email.text, pw.text)
			"create": res = AuthManager.create_dev_account(email.text, username.text, pw.text, confirm.text)
			_: res = AuthManager.request_password_reset(email.text)
		_handle(res)
	var labels := {"login": "Login", "create": "Create Account", "forgot": "Send Reset Link"}
	_add_button(labels[kind], true, submit)
	_add_button("Back", false, _show_welcome)
	var last: LineEdit = confirm if confirm != null else (pw if pw != null else email)
	last.text_submitted.connect(func(_t: String) -> void: submit.call())

func _handle(res: Dictionary) -> void:
	if res["ok"]:
		Game.go_to(Game.SCENE_MENU)
	else:
		_set_status(res["message"])

func _on_guest() -> void:
	_handle(AuthManager.continue_as_guest())

func _on_google() -> void:
	_handle(AuthManager.sign_in_google())
