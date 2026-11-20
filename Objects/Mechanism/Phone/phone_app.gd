class_name PhoneApp
extends Resource
## One icon on the NovaKia menu.
## Edit them in the Inspector: open PhoneWindow.tscn, select PhoneUI, expand "Apps".

## Name shown in the top bar and in the crash popup.
@export var title: String = "App"
## Colour of the top bar, the highlight and the popup title for this app.
@export var color: Color = Color("#3270d6")
## 16x16 pixel-art PNG. Shown at 2x, and 3x while highlighted.
@export var icon: Texture2D
## What opening it does. "crash" shows the "App stopped working" popup.
@export_enum("crash", "calls", "messages", "contacts", "gallery") var opens: String = "crash"
