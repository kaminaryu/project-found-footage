# VHS Dialogue - README

Yellow subtitles with a black outline at the bottom of the screen,
like an old VHS tape. You use them for the story.


## The idea in 3 lines

1. You WRITE the lines in a text file.
2. You give a group of lines a NAME, like  [intro]
3. You PLAY that name when the story needs it.

That's it. Everything below is just details.


## Where things are

    Resources/Data/Dialogue/        <- YOUR LINES go here (.txt files)
        example.txt                 <- example, copy it to start

    addons/vhs_dialogue/            <- the plugin itself (you rarely touch this)
        subtitle_style.tres         <- colour, size, font, outline
        dialogue.tscn               <- timing, typewriter, skip key, position
        README.md                   <- this file

The plugin must be ON:
Project > Project Settings > Plugins > VHS Dialogue > Enable


===================================================================
## 1. WRITE the lines
===================================================================

Open  Resources/Data/Dialogue/example.txt  (double-click it in Godot).
New file: right-click the Dialogue folder > Create New > TextFile...
(it must end in .txt). You can have as many files as you like.

A conversation looks like this:

    [kitchen_scare]
    NATALIA: Hello? Is anyone home?
    NATALIA: Mom?
    @wait 2
    (a door slams upstairs)
    ???: Get out.

What each line means:

    [kitchen_scare]       the NAME of this conversation. No spaces is easiest.
    NATALIA: Hello?       a subtitle. The speaker name must be in CAPITALS.
    (a door slams)        a subtitle with no speaker
    @wait 2               2 seconds of nothing on screen
    ???: Get out.         "???" works as a speaker name too

Extras you can add:

    NATALIA: Run. | 4     "| 4" = keep this subtitle on screen 4 seconds
                          (without it, longer lines stay up longer by themselves)
    first\nsecond         \n = break the subtitle onto two lines
    @event lights_off     sends a message "lights_off" to your scripts (see 4.)
    # a note              lines that start with # are ignored

Save the file (Ctrl+S). That's all, no other setup.


===================================================================
## 2. PLAY it - no code (player walks into a spot)
===================================================================

1. In your level, click Add Node (+) and search  DialogueTrigger
2. Give it a child:  CollisionShape3D
3. In the Inspector of CollisionShape3D: Shape > New BoxShape3D.
   Move/resize the box to where the player should walk in.
4. Select the DialogueTrigger. In the Inspector:
	   Conversation   type or pick the name, e.g.  kitchen_scare
	   Only Once      ON  = plays one time per game
	   Delay          seconds to wait after the player walks in

Play the game, walk into the box, the subtitles appear.


===================================================================
## 3. PLAY it - from a script (objective done, item picked up...)
===================================================================

Anywhere in any script:

	Dialogue.play("kitchen_scare")

If the next thing should wait until the talking is over, put await in front:

	func _on_objective_completed() -> void:
		await Dialogue.play("objective_1_done")
		# this line runs AFTER the last subtitle is gone
		start_next_objective()

One quick line without writing it in a file:

	Dialogue.say("I need to find the key.")
	Dialogue.say("Who's there?", "NATALIA")        # with a speaker
	Dialogue.say("...", "", 3.0)                    # stays 3 seconds

Playing a new conversation stops the one that is playing.


===================================================================
## 4. Make things HAPPEN during a conversation (@event)
===================================================================

In the dialogue file:

	[power_back]
	NATALIA: There, the fuse is in.
	@event lights_on
	NATALIA: ...finally.

In the script of the thing that should react (e.g. the room):

	func _ready() -> void:
		Dialogue.event.connect(_on_dialogue_event)

	func _on_dialogue_event(event_name: String) -> void:
		if event_name == "lights_on":
			$Lights.visible = true

When the subtitles reach "@event lights_on", that function runs.


===================================================================
## 5. Useful checks for the story
===================================================================

	Dialogue.has_played("intro")    true if "intro" was already played this game
	Dialogue.is_playing()           true while subtitles are running
	Dialogue.stop()                 hide the subtitle right now
	Dialogue.reload()               read the .txt files again (after editing mid-game)

Example - only say something the first time:

	if not Dialogue.has_played("first_time_in_basement"):
		Dialogue.play("first_time_in_basement")


===================================================================
## 6. Change how it LOOKS
===================================================================

Double-click  addons/vhs_dialogue/subtitle_style.tres  and change in the Inspector:

	Font > Font Size      bigger / smaller text (now 30)
	Font > Font Color     the yellow
	Outline > Size        thickness of the black edge (now 8)
	Shadow                the soft shadow under the text
	Font                  Arial right now. To use your own font, drag a
						  .ttf file (e.g. Assets/Fonts/VCR_OSD_MONO_1.001.ttf)
						  onto the Font slot.

Position: open  addons/vhs_dialogue/dialogue.tscn, select "Bottom", and change
Theme Overrides > Constants > Margin Bottom (higher = subtitles sit higher up),
Margin Left / Margin Right (higher = narrower, wraps sooner).


===================================================================
## 7. Change the TIMING
===================================================================

Open  addons/vhs_dialogue/dialogue.tscn, click the top node "Dialogue":

	Min Time              every subtitle stays at least this long (1.5 s)
	Time Per Letter       extra time per letter, for long lines (0.055 s)
	Letters Per Second    0 = whole line at once. 30 = typewriter effect
	Gap                   tiny blank moment between two subtitles
	Show Speaker Names    OFF = hide the "NATALIA:" part
	Skip Action           ui_accept = Enter/Space skips to the next line.
						  Empty = players can't skip.


===================================================================
## 8. Something is WRONG?
===================================================================

Nothing shows up
  - Is the plugin ON? (Project Settings > Plugins)
  - Look at the Output panel at the bottom. "there is no [name]" means the
    name in your code/trigger is not written the same as in the .txt file.
  - Is the file inside Resources/Data/Dialogue and ending in .txt?

Error "Identifier Dialogue not declared"
  - The plugin is OFF. Turn it on.

The trigger does nothing
  - Does the DialogueTrigger have a CollisionShape3D with a shape?
  - Is "Only Once" on and it already played? It won't play again.
  - The player must be on physics layer 2 ("player"). Yours is.

The speaker name is wrong / missing
  - Names must be in CAPITALS:  NATALIA: hi   (not  Natalia: hi)

Yellow warnings in Output when the game starts
  - They tell you the file + line number of a typo in your .txt file.


## Commands cheat sheet

	In a .txt file                     In a script
	--------------------------------   ------------------------------------
	[name]          new conversation   Dialogue.play("name")
	NAME: text      subtitle           await Dialogue.play("name")
	text            no speaker         Dialogue.say("text", "NAME")
	... | 4         stay 4 seconds     Dialogue.stop()
	\n              new line           Dialogue.has_played("name")
	@wait 2         pause 2 seconds    Dialogue.is_playing()
	@event name     message to code    Dialogue.event.connect(my_function)
	# note          ignored
