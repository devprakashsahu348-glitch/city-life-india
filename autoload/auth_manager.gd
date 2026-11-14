extends Node
## AuthManager - account/session handling.
##
## IMPORTANT: Firebase is NOT integrated yet (Phase 5). Until then this runs in a
## clearly labelled DEV MODE: guest play (real, local) and local "dev accounts"
## that exist only on this device. Google sign-in is deliberately NOT faked.
## Passwords are never stored in plaintext (salted, iterated SHA-256 in dev mode;
## Firebase handles this server-side in production).

signal auth_changed

enum Mode { NONE, GUEST, DEV_ACCOUNT }

const FIREBASE_AVAILABLE := false
const DEV_ACCOUNTS_PATH := "user://dev_accounts.json"
const SESSION_PATH := "user://session.json"
const HASH_ROUNDS := 10000
const MIN_PASSWORD_LENGTH := 8

var mode: Mode = Mode.NONE
var email := ""

func is_signed_in() -> bool:
	return mode != Mode.NONE

func is_guest() -> bool:
	return mode == Mode.GUEST

func mode_label() -> String:
	match mode:
		Mode.GUEST: return "Guest"
		Mode.DEV_ACCOUNT: return "Dev account (local)"
		_: return "Signed out"

func continue_as_guest() -> Dictionary:
	_activate(Mode.GUEST, "guest", "", "Guest")
	return _res(true, "Welcome!")

func sign_in_google() -> Dictionary:
	return _res(false, "Google sign-in needs Firebase and the Android plugin (Phase 5). It is not available in this build.")

func create_dev_account(p_email: String, username: String, password: String, confirm: String) -> Dictionary:
	p_email = p_email.strip_edges().to_lower()
	username = username.strip_edges()
	if not _valid_email(p_email):
		return _res(false, "Enter a valid email address.")
	if username.length() < 3 or username.length() > 20:
		return _res(false, "Username must be 3-20 characters.")
	if password.length() < MIN_PASSWORD_LENGTH:
		return _res(false, "Password must be at least %d characters." % MIN_PASSWORD_LENGTH)
	if password != confirm:
		return _res(false, "Passwords do not match.")
	var accounts := _read_json(DEV_ACCOUNTS_PATH)
	if accounts.has(p_email):
		return _res(false, "An account with this email already exists on this device.")
	var salt := Crypto.new().generate_random_bytes(16).hex_encode()
	accounts[p_email] = {"username": username, "salt": salt, "hash": _hash_password(password, salt)}
	if not _write_json(DEV_ACCOUNTS_PATH, accounts):
		return _res(false, "Could not store the account on this device.")
	_activate(Mode.DEV_ACCOUNT, _slot_for(p_email), p_email, username)
	return _res(true, "Account created.")

func login_dev(p_email: String, password: String) -> Dictionary:
	p_email = p_email.strip_edges().to_lower()
	if not _valid_email(p_email) or password.is_empty():
		return _res(false, "Enter your email and password.")
	var accounts := _read_json(DEV_ACCOUNTS_PATH)
	var generic := _res(false, "Incorrect email or password.")
	if not accounts.has(p_email):
		return generic
	var acc: Dictionary = accounts[p_email]
	if _hash_password(password, str(acc.get("salt", ""))) != str(acc.get("hash", "")):
		return generic
	_activate(Mode.DEV_ACCOUNT, _slot_for(p_email), p_email, str(acc.get("username", "Player")))
	return _res(true, "Logged in.")

func request_password_reset(p_email: String) -> Dictionary:
	if not _valid_email(p_email.strip_edges().to_lower()):
		return _res(false, "Enter a valid email address.")
	return _res(false, "Password reset emails need the online account service (Firebase, Phase 5). Dev-mode accounts live only on this device and cannot be reset.")

func logout() -> void:
	SaveManager.save_game()
	SaveManager.unload_slot()
	mode = Mode.NONE
	email = ""
	if FileAccess.file_exists(SESSION_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SESSION_PATH))
	auth_changed.emit()

## Restores the previous guest/dev session on app start. Returns true on success.
func restore_session() -> bool:
	var s := _read_json(SESSION_PATH)
	match str(s.get("mode", "")):
		"guest":
			continue_as_guest()
			return true
		"dev":
			var e := str(s.get("email", ""))
			var accounts := _read_json(DEV_ACCOUNTS_PATH)
			if accounts.has(e):
				_activate(Mode.DEV_ACCOUNT, _slot_for(e), e, str(accounts[e].get("username", "Player")))
				return true
	return false

# --- internals ---------------------------------------------------------------

func _activate(new_mode: Mode, slot: String, p_email: String, username: String) -> void:
	mode = new_mode
	email = p_email
	SaveManager.load_slot(slot)
	var profile: Dictionary = SaveManager.data["profile"]
	if str(profile["player_id"]).is_empty():
		profile["player_id"] = "CLI-" + Crypto.new().generate_random_bytes(4).hex_encode().to_upper()
	profile["username"] = username
	SaveManager.save_game()
	_write_json(SESSION_PATH, {"mode": "guest" if new_mode == Mode.GUEST else "dev", "email": p_email})
	auth_changed.emit()

func _slot_for(p_email: String) -> String:
	return "acct_" + p_email.sha256_text().substr(0, 16)

func _valid_email(e: String) -> bool:
	var re := RegEx.new()
	re.compile("^[^@\\s]+@[^@\\s]+\\.[^@\\s]+$")
	return re.search(e) != null

func _hash_password(password: String, salt: String) -> String:
	var h := (salt + password).sha256_text()
	for i in HASH_ROUNDS:
		h = (h + salt).sha256_text()
	return h

func _res(ok: bool, message: String) -> Dictionary:
	return {"ok": ok, "message": message}

func _read_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed if typeof(parsed) == TYPE_DICTIONARY else {}

func _write_json(path: String, d: Dictionary) -> bool:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(JSON.stringify(d))
	f.close()
	return true
