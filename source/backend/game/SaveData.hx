package backend.game;

import flixel.FlxSprite;
import flixel.util.FlxSave;
import openfl.system.Capabilities;
import backend.song.Conductor;
import backend.song.Highscore;

/*
	Save data such as options and other things.
*/

enum SettingType
{
	CHECKMARK;
	SELECTOR;
}
class SaveData
{
	public static var data:Map<String, Dynamic> = [];
	public static var displaySettings:Map<String, Dynamic> = [
		/*
		*
		* PREFERENCES
		* 
		*/
		"Window Size" => [
			"1280x720",
			SELECTOR,
			"Change the game's resolution if it doesn't fit your monitor",
			["640x360","854x480","960x540","1024x576","1152x648","1280x720","1366x768","1600x900","1920x1080", "2560x1440", "3840x2160"],
		],
		'Flashing Lights' => [
			"ON",
			SELECTOR,
			"Whether to show flashing lights and colors",
			["ON", "REDUCED", "OFF"]
		],
		"Cutscenes" => [
			"ON",
			SELECTOR,
			"Decides if the song cutscenes should play",
			["ON", "FREEPLAY OFF", "OFF"],
		],
		"FPS Counter" => [
			false,
			CHECKMARK,
			"Whether you want a counter showing your framerate and memory usage counter in the corner of the game",
		],
		'Unfocus Pause' => [
			true,
			CHECKMARK,
			"Pauses the game when the window is unfocused",
		],
		"Delay on Unpause" => [
			#if desktop true #else false #end,
			CHECKMARK,
			"Whether you want to have a delay when unpausing the game",
		],
		'Discord RPC' => [
			#if DISCORD_RPC
			true,
			#else
			false,
			#end
			CHECKMARK,
			"Whether to use Discord's game activity.",
		],
		"Shaders" => [
			#if html5 false #else true #end,
			CHECKMARK,
			"Fancy graphical effects. Disable this if you get GPU related crashes."
		],
		"Low Quality" => [
			#if html5 true #else false #end,
			CHECKMARK,
			"Disables extra assets that might make very low end computers lag."
		],
		/*
		*
		* GAMEPLAY
		* 
		*/
		"Can Ghost Tap" => [
			"WHILE IDLING",
			SELECTOR,
			"Makes you able to press keys freely without missing notes",
			["ALWAYS", "WHILE IDLING", "NEVER"]
		],
		"Downscroll" => [
			false,
			CHECKMARK,
			"Makes the notes go down instead of up"
		],
		"Middlescroll" => [
			false,
			CHECKMARK,
			"Disables the opponent's notes and moves yours to the middle"
		],
		"Framerate Cap"	=> [
			60, // 120
			SELECTOR,
			"Self explanatory",
			[30, 360]
		],
		'Hitsounds' => [
			"OFF",
			SELECTOR,
			"Whether to play hitsounds whenever you hit a note",
			["OFF", "OSU", "NSWITCH", "CD"]
		],
		'Hitsound Volume' => [
			100,
			SELECTOR,
			"Only works when Hitsounds aren't off",
			[0, 100]
		],
		/*
		*
		* APPEARANCE
		* 
		*/
		"Note Splashes" => [
			"ON",
			SELECTOR,
			"Whether a splash appears when you hit a note perfectly.\nDisable if it distracts you.",
			["ON", "PLAYER ONLY", "OFF"],
		],
		"Hold Splashes" => [
			true,
			CHECKMARK,
			"Whether a splash appears when you completely press a hold note.\nDisable if it distracts you. (Only works if Note Splashes is enabled)."
		],
		"Antialiasing" => [
			#if html5 false #else true #end,
			CHECKMARK,
			"Disabling it might increase the fps at the cost of smoother sprites"
		],
		"Split Holds" => [
			false,
			CHECKMARK,
			"Cuts the end of each hold note like classic engines did"
		],
		"Static Hold Anim" => [
			true,
			CHECKMARK,
			"Whether the character stays static when playing a hold note."
		],
		"Single Rating" => [
			false,
			CHECKMARK,
			"Makes only one rating appear at a time",
		],
		"Song Timer" => [
			true,
			CHECKMARK,
			"Makes the song timer visible",
		],
		"Song Timer Info" => [
			"ELAPSED TIME",
			SELECTOR,
			"What information appears on the song timer.\nSong Timer must be enabled.",
			["ELAPSED TIME", "TIME LEFT", "FULL TIMER"],
		],
		"Song Timer Style" => [
			"MIN:SEC",
			SELECTOR,
			"How should the song timer look like.\nSong Timer must be enabled.",
			["MIN:SEC", "MIN'SEC\"MIL"],
		],
		/*
		*
		* MOBILE
		* 
		*/
		"Invert Swipes" => [
			"OFF",
			SELECTOR,
			"Inverts the direction of the swipes.",
			["HORIZONTAL", "VERTICAL", "BOTH", "OFF"],
		],
		"Button Opacity" => [
			5,
			SELECTOR,
			"Decides the transparency of the virtual buttons.",
			[0, 10]
		],
		"Hitbox Opacity" => [
			7,
			SELECTOR,
			"Decides the transparency of the playing Hitboxes.",
			[0, 10]
		],
		/*
		*
		* EXTRA STUFF
		* 
		*/
		"Song Offset" => [
			0,
			SELECTOR,
			"no one is going to see this anyway whatever",
			[-100, 100],
		],
		"Input Offset" => [
			0,
			SELECTOR,
			"same xd",
			[-100, 100],
		],
	];
	
	public static var saveSettings:FlxSave = new FlxSave();
	public static var saveControls:FlxSave = new FlxSave();
	public static function init()
	{
		saveSettings.bind("settings"); // use these for settings
		saveControls.bind("controls"); // controls :D
		FlxG.save.bind("save-data"); // these are for other stuff, not recquiring to access the SaveData class
		
		load();
		Controls.load();
		Highscore.load();
		subStates.editors.ChartAutoSaveSubState.load(); // uhhh
		updateWindowSize();
		update();
	}
	
	public static function load()
	{
		if(saveSettings.data.volume != null)
			FlxG.sound.volume = saveSettings.data.volume;
		if(saveSettings.data.muted != null)
			FlxG.sound.muted  = saveSettings.data.muted;

		var storedSettings:Dynamic = saveSettings.data.settings;
		if(storedSettings != null && Reflect.hasField(storedSettings, "keys"))
			data = cast storedSettings;
		else
			data = new Map<String, Dynamic>();

		migrateLegacySettings();
		syncSettingsWithDefaults();
		addDynamicOptions();
		sanitizeSettings();
		save();
	}
	
	public static function save()
	{
		saveSettings.data.settings = data;
		saveSettings.flush();
		update();
	}

	public static function update()
	{
		Main.changeFramerate(data.get("Framerate Cap"));
		
		if(Main.fpsCounter != null)
			Main.fpsCounter.visible = data.get("FPS Counter");

		FlxSprite.defaultAntialiasing = data.get("Antialiasing");

		FlxG.autoPause = data.get('Unfocus Pause');

		Conductor.musicOffset = data.get('Song Offset');
		Conductor.inputOffset = data.get('Input Offset');

		DiscordIO.check();
	}

	public static function updateWindowSize()
	{
		#if desktop
		if(FlxG.stage == null || FlxG.stage.window == null) return;
		if(FlxG.fullscreen) return;
		var savedSize:String = Std.string(data.get("Window Size"));
		var ws:Array<String> = savedSize.split("x");
		if(ws.length < 2)
			ws = Std.string(displaySettings.get("Window Size")[0]).split("x");
        var windowSize:Array<Int> = [Std.parseInt(ws[0]),Std.parseInt(ws[1])];
		var defaultSize:Array<String> = Std.string(displaySettings.get("Window Size")[0]).split("x");
		for(i in 0...windowSize.length)
		{
			if(Math.isNaN(windowSize[i]) || windowSize[i] <= 0)
				windowSize[i] = Std.parseInt(defaultSize[i]);
		}
        FlxG.stage.window.width = windowSize[0];
        FlxG.stage.window.height= windowSize[1];
		
		// centering the window
		FlxG.stage.window.x = Math.floor(Capabilities.screenResolutionX / 2 - windowSize[0] / 2);
		FlxG.stage.window.y = Math.floor(Capabilities.screenResolutionY / 2 - (windowSize[1] + 16) / 2);
		#end
	}

	static function migrateLegacySettings()
	{
		var freeze:Null<Bool> = data.get("Unfocus Freeze");
		if(freeze != null) {
			data.set("Unfocus Pause", freeze);
			data.remove("Unfocus Freeze");
		}
	}

	static function syncSettingsWithDefaults()
	{
		for(key => values in displaySettings)
		{
			if(!data.exists(key))
				data.set(key, values[0]);
		}

		var keysToRemove:Array<String> = [];
		for(key in data.keys())
			if(!displaySettings.exists(key))
				keysToRemove.push(key);
		for(key in keysToRemove)
			data.remove(key);

		saveSettings.data.settings = data;
	}

	static function addDynamicOptions()
	{
		var hitsoundsSetting = displaySettings.get("Hitsounds");
		if(hitsoundsSetting == null || hitsoundsSetting.length < 4)
			return;

		var list:Array<Dynamic> = hitsoundsSetting[3];
		for(hitsound in Paths.readDir('sounds/hitsounds', [".ogg"], true))
			if(!list.contains(hitsound))
				list.insert(1, hitsound);
	}

	static function sanitizeSettings()
	{
		for(key => values in displaySettings)
		{
			var current:Dynamic = data.get(key);
			var fixed:Dynamic = sanitizeValue(key, current, values);
			if(current != fixed)
				data.set(key, fixed);
		}
	}

	static function sanitizeValue(key:String, current:Dynamic, values:Array<Dynamic>):Dynamic
	{
		var defaultValue:Dynamic = values[0];
		var type:SettingType = values[1];
		if(current == null)
			return defaultValue;

		switch(type)
		{
			case CHECKMARK:
				return toBool(current, defaultValue == true);
			case SELECTOR:
				if(values.length < 4 || values[3] == null)
					return current;

				var options:Array<Dynamic> = values[3];
				var rangeMin = options[0];
				var rangeMax = options[1];
				var hasRange:Bool = options.length == 2 && isNumber(rangeMin) && isNumber(rangeMax);

				if(hasRange)
					return clampInt(current, rangeMin, rangeMax);

				var idx = options.indexOf(current);
				if(idx == -1)
				{
					var matched:Dynamic = matchOption(options, current);
					return matched == null ? defaultValue : matched;
				}
				return options[idx];
		}

		return defaultValue;
	}

	inline static function clampInt(value:Dynamic, min:Int, max:Int):Int
	{
		var parsed:Float = Std.parseFloat(Std.string(value));
		if(Math.isNaN(parsed))
			parsed = min;
		var num:Int = Std.int(parsed);
		if(num < min) num = min;
		if(num > max) num = max;
		return num;
	}

	static inline function isNumber(value:Dynamic):Bool
		return Std.isOfType(value, Int) || Std.isOfType(value, Float);

	static function toBool(value:Dynamic, fallback:Bool):Bool
	{
		if(Std.isOfType(value, Bool))
			return value;

		var lower = Std.string(value).toLowerCase();
		if(lower == "true") return true;
		if(lower == "false") return false;
		return fallback;
	}

	static function matchOption(options:Array<Dynamic>, current:Dynamic):Dynamic
	{
		var curStr = Std.string(current).toLowerCase();
		for(opt in options)
			if(Std.string(opt).toLowerCase() == curStr)
				return opt;
		return null;
	}
}
