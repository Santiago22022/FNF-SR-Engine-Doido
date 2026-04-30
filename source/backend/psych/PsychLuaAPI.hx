package backend.psych;

#if LUA_ALLOWED
import llua.Lua;
import llua.LuaL;
import llua.State;
import llua.Lua.Lua_helper;
import flixel.FlxG;
import flixel.FlxSprite;
import flixel.group.FlxGroup;
import objects.Stage;

/**
 * Registers Psych Engine compatible Lua API callbacks so that
 * mod .lua scripts (especially stage scripts) can call
 * makeLuaSprite, addLuaSprite, setScrollFactor, etc.
 */
class PsychLuaAPI
{
	// Storage for sprites created by Lua
	public static var luaSprites:Map<String, FlxSprite> = new Map();
	
	// Queue for adding/removing sprites before Stage is instantiated
	public static var addQueue:Array<{spr:FlxSprite, inFront:Bool}> = [];
	public static var removeQueue:Array<FlxSprite> = [];

	public static function registerCallbacks(lua:State):Void
	{
		luaSprites = new Map();
		addQueue = [];
		removeQueue = [];

		// Set some global variables Psych scripts expect
		Lua.pushstring(lua, states.PlayState.SONG != null ? states.PlayState.SONG.song : "");
		Lua.setglobal(lua, "songName");

		Lua.pushstring(lua, "0.7.0");
		Lua.setglobal(lua, "version");

		Lua.pushinteger(lua, 0);
		Lua.setglobal(lua, "curBeat");

		Lua.pushinteger(lua, 0);
		Lua.setglobal(lua, "curStep");

		Lua.pushboolean(lua, false);
		Lua.setglobal(lua, "mustHitSection");

		Lua.pushboolean(lua, FlxG.save.data.downscroll == true);
		Lua.setglobal(lua, "downscroll");

		Lua.pushboolean(lua, false);
		Lua.setglobal(lua, "inGameOver");

		Lua.pushnumber(lua, FlxG.width);
		Lua.setglobal(lua, "screenWidth");

		Lua.pushnumber(lua, FlxG.height);
		Lua.setglobal(lua, "screenHeight");

		// Register API functions
		Lua_helper.add_callback(lua, "makeLuaSprite", function(tag:String, image:String, x:Float, y:Float):Void {
			if(tag == null) return;
			var spr = new FlxSprite(x, y);
			if(image != null && image.length > 0)
			{
				spr.loadGraphic(Paths.image(image));
			}
			luaSprites.set(tag, spr);
		});

		Lua_helper.add_callback(lua, "makeAnimatedLuaSprite", function(tag:String, image:String, x:Float, y:Float):Void {
			if(tag == null) return;
			var spr = new FlxSprite(x, y);
			if(image != null && image.length > 0)
			{
				spr.frames = Paths.getSparrowAtlas(image);
			}
			luaSprites.set(tag, spr);
		});

		Lua_helper.add_callback(lua, "makeGraphic", function(tag:String, w:Int, h:Int, color:String):Void {
			var spr = luaSprites.get(tag);
			if(spr != null)
			{
				spr.makeGraphic(w, h, backend.utils.CoolUtil.stringToColor(color));
			}
		});

		Lua_helper.add_callback(lua, "addLuaSprite", function(tag:String, inFront:Bool):Void {
			var spr = luaSprites.get(tag);
			if(spr == null) return;
			var stage = Stage.instance;
			if(stage != null)
			{
				if(inFront)
					stage.foreground.add(spr);
				else
					stage.add(spr);
			}
			else
			{
				// Stage not instantiated yet, queue it
				addQueue.push({spr: spr, inFront: inFront});
			}
		});

		Lua_helper.add_callback(lua, "removeLuaSprite", function(tag:String):Void {
			var spr = luaSprites.get(tag);
			if(spr == null) return;
			var stage = Stage.instance;
			if(stage != null)
			{
				stage.remove(spr, true);
				stage.foreground.remove(spr, true);
			}
			else
			{
				// Stage not instantiated yet, queue it
				removeQueue.push(spr);
			}
			luaSprites.remove(tag);
		});

		Lua_helper.add_callback(lua, "setScrollFactor", function(tag:String, x:Float, y:Float):Void {
			var spr = luaSprites.get(tag);
			if(spr != null)
				spr.scrollFactor.set(x, y);
		});

		Lua_helper.add_callback(lua, "setGraphicSize", function(tag:String, w:Dynamic, h:Dynamic, updateHitbox:Bool):Void {
			var spr = luaSprites.get(tag);
			if(spr == null) return;
			var ww:Int = 0;
			var hh:Int = 0;
			if(w != null && Std.isOfType(w, Int))
				ww = cast w;
			else if(w != null && Std.isOfType(w, Float))
				ww = Std.int(cast(w, Float));
			if(h != null && Std.isOfType(h, Int))
				hh = cast h;
			else if(h != null && Std.isOfType(h, Float))
				hh = Std.int(cast(h, Float));
			spr.setGraphicSize(ww, hh);
			if(updateHitbox)
				spr.updateHitbox();
		});

		Lua_helper.add_callback(lua, "updateHitbox", function(tag:String):Void {
			var spr = luaSprites.get(tag);
			if(spr != null)
				spr.updateHitbox();
		});

		Lua_helper.add_callback(lua, "screenCenter", function(tag:String, axes:String):Void {
			var spr = luaSprites.get(tag);
			if(spr != null)
			{
				if(axes == null) axes = 'xy';
				axes = axes.toLowerCase().trim();
				
				if(axes == 'x') spr.screenCenter(flixel.util.FlxAxes.X);
				else if(axes == 'y') spr.screenCenter(flixel.util.FlxAxes.Y);
				else spr.screenCenter(flixel.util.FlxAxes.XY);
			}
		});

		Lua_helper.add_callback(lua, "scaleObject", function(tag:String, x:Float, y:Float, updateHitbox:Bool):Void {
			var spr = luaSprites.get(tag);
			if(spr == null) return;
			spr.scale.set(x, y);
			if(updateHitbox)
				spr.updateHitbox();
		});

		Lua_helper.add_callback(lua, "doTweenAlpha", function(tag:String, vars:String, value:Dynamic, duration:Float, ease:String):Void {
			var obj:Dynamic = luaSprites.get(vars);
			if(obj == null) {
				var ps = states.PlayState.instance;
				if(vars == "gfGroup") vars = "gf";
				else if(vars == "dadGroup") vars = "dad";
				else if(vars == "boyfriendGroup") vars = "boyfriend";
				obj = Reflect.getProperty(ps, vars);
				if(obj != null && Std.isOfType(obj, objects.CharGroup)) obj = cast(obj, objects.CharGroup).char;
			}
			if(obj != null) {
				var e = backend.utils.CoolUtil.stringToEase(ease);
				flixel.tweens.FlxTween.tween(obj, {alpha: cast(value, Float)}, duration, {ease: e});
			}
		});

		Lua_helper.add_callback(lua, "doTweenX", function(tag:String, vars:String, value:Dynamic, duration:Float, ease:String):Void {
			var obj:Dynamic = luaSprites.get(vars);
			if(obj == null) {
				var ps = states.PlayState.instance;
				if(vars == "gfGroup") vars = "gf";
				else if(vars == "dadGroup") vars = "dad";
				else if(vars == "boyfriendGroup") vars = "boyfriend";
				obj = Reflect.getProperty(ps, vars);
				if(obj != null && Std.isOfType(obj, objects.CharGroup)) obj = cast(obj, objects.CharGroup).char;
			}
			if(obj != null) {
				var e = backend.utils.CoolUtil.stringToEase(ease);
				flixel.tweens.FlxTween.tween(obj, {x: cast(value, Float)}, duration, {ease: e});
			}
		});

		Lua_helper.add_callback(lua, "doTweenY", function(tag:String, vars:String, value:Dynamic, duration:Float, ease:String):Void {
			var obj:Dynamic = luaSprites.get(vars);
			if(obj == null) {
				var ps = states.PlayState.instance;
				if(vars == "gfGroup") vars = "gf";
				else if(vars == "dadGroup") vars = "dad";
				else if(vars == "boyfriendGroup") vars = "boyfriend";
				obj = Reflect.getProperty(ps, vars);
				if(obj != null && Std.isOfType(obj, objects.CharGroup)) obj = cast(obj, objects.CharGroup).char;
			}
			if(obj != null) {
				var e = backend.utils.CoolUtil.stringToEase(ease);
				flixel.tweens.FlxTween.tween(obj, {y: cast(value, Float)}, duration, {ease: e});
			}
		});

		Lua_helper.add_callback(lua, "addAnimationByPrefix", function(tag:String, name:String, prefix:String, fps:Int, loop:Bool):Void {
			var spr = luaSprites.get(tag);
			if(spr != null && spr.frames != null)
				spr.animation.addByPrefix(name, prefix, fps, loop);
		});

		Lua_helper.add_callback(lua, "addAnimationByIndices", function(tag:String, name:String, prefix:String, indices:String, fps:Int):Void {
			var spr = luaSprites.get(tag);
			if(spr == null || spr.frames == null) return;
			var indicesArr:Array<Int> = [];
			if(indices != null && indices.length > 0)
			{
				for(s in indices.split(","))
				{
					var parsed = Std.parseInt(StringTools.trim(s));
					if(parsed != null)
						indicesArr.push(parsed);
				}
			}
			spr.animation.addByIndices(name, prefix, indicesArr, "", fps);
		});

		Lua_helper.add_callback(lua, "playAnim", function(tag:String, anim:String, forced:Bool, reversed:Bool, frame:Int):Void {
			var spr = luaSprites.get(tag);
			if(spr != null && spr.animation != null)
				spr.animation.play(anim, forced, reversed, frame);
		});

		Lua_helper.add_callback(lua, "setProperty", function(prop:String, val:Dynamic):Void {
			if(prop == null) return;
			
			// Psych Engine compatibility mapping
			if(prop.startsWith("gfGroup.")) prop = StringTools.replace(prop, "gfGroup.", "gf.");
			else if(prop.startsWith("dadGroup.")) prop = StringTools.replace(prop, "dadGroup.", "dad.");
			else if(prop.startsWith("boyfriendGroup.")) prop = StringTools.replace(prop, "boyfriendGroup.", "boyfriend.");
			
			if(prop.startsWith("gf.") || prop.startsWith("dad.") || prop.startsWith("boyfriend.")) {
				var field = prop.split(".")[1];
				switch(field) {
					case "alpha", "color", "angle", "antialiasing", "x", "y", "scale", "flipX", "flipY", "velocity", "acceleration", "offset", "drag", "scrollFactor", "animation", "frame":
						prop = StringTools.replace(prop, prop.split(".")[0] + ".", prop.split(".")[0] + ".char.");
				}
			}

			// Handle lua sprite properties like 'sky.antialiasing'
			var dotIdx = prop.indexOf('.');
			if(dotIdx != -1)
			{
				var objName = prop.substr(0, dotIdx);
				var field = prop.substr(dotIdx + 1);
				
				// Check lua sprites first
				var spr = luaSprites.get(objName);
				if(spr != null)
				{
					setNestedProperty(spr, field, val);
					return;
				}
				
				// Check PlayState properties
				var ps = states.PlayState.instance;
				if(ps != null)
				{
					var obj:Dynamic = Reflect.getProperty(ps, objName);
					if(obj != null)
					{
						setNestedProperty(obj, field, val);
						return;
					}
				}
			}

			// Direct PlayState property
			var ps = states.PlayState.instance;
			if(ps != null && Reflect.hasField(ps, prop))
				Reflect.setProperty(ps, prop, val);
		});

		Lua_helper.add_callback(lua, "getProperty", function(prop:String):Dynamic {
			if(prop == null) return null;
			
			// Psych Engine compatibility mapping
			if(prop.startsWith("gfGroup.")) prop = StringTools.replace(prop, "gfGroup.", "gf.");
			else if(prop.startsWith("dadGroup.")) prop = StringTools.replace(prop, "dadGroup.", "dad.");
			else if(prop.startsWith("boyfriendGroup.")) prop = StringTools.replace(prop, "boyfriendGroup.", "boyfriend.");
			
			if(prop.startsWith("gf.") || prop.startsWith("dad.") || prop.startsWith("boyfriend.")) {
				var field = prop.split(".")[1];
				switch(field) {
					case "alpha", "color", "angle", "antialiasing", "x", "y", "scale", "flipX", "flipY", "velocity", "acceleration", "offset", "drag", "scrollFactor", "animation", "frame":
						prop = StringTools.replace(prop, prop.split(".")[0] + ".", prop.split(".")[0] + ".char.");
				}
			}

			var dotIdx = prop.indexOf('.');
			if(dotIdx != -1)
			{
				var objName = prop.substr(0, dotIdx);
				var field = prop.substr(dotIdx + 1);
				
				var spr = luaSprites.get(objName);
				if(spr != null)
					return getNestedProperty(spr, field);
				
				var ps = states.PlayState.instance;
				if(ps != null)
				{
					var obj:Dynamic = Reflect.getProperty(ps, objName);
					if(obj != null)
						return getNestedProperty(obj, field);
				}
			}

			var ps = states.PlayState.instance;
			if(ps != null && Reflect.hasField(ps, prop))
				return Reflect.getProperty(ps, prop);
			return null;
		});

		Lua_helper.add_callback(lua, "setPropertyFromClass", function(cls:String, prop:String, val:Dynamic):Void {
			// Stub - log but don't crash
			Logs.print('Lua setPropertyFromClass: $cls.$prop (stubbed)', TRACE);
		});

		Lua_helper.add_callback(lua, "getPropertyFromClass", function(cls:String, prop:String):Dynamic {
			Logs.print('Lua getPropertyFromClass: $cls.$prop (stubbed)', TRACE);
			return null;
		});

		Lua_helper.add_callback(lua, "triggerEvent", function(name:String, v1:String, v2:String):Void {
			var ps = states.PlayState.instance;
			if(ps != null) {
				var ev = new objects.note.EventNote();
				ev.eventName = name;
				ev.value1 = v1;
				ev.value2 = v2;
				@:privateAccess ps.onEventHit(ev);
			}
		});

		Lua_helper.add_callback(lua, "debugPrint", function(text:Dynamic):Void {
			Logs.print('Lua: $text', TRACE);
		});

		Lua_helper.add_callback(lua, "close", function():Void {
			// no-op; lifecycle managed by PsychLuaManager
		});

		// Stub for Std.int which some Lua scripts define but shouldn't crash
		// The polus.lua actually defines its own Std table at the bottom
	}

	static function setNestedProperty(obj:Dynamic, field:String, val:Dynamic):Void
	{
		var dotIdx = field.indexOf('.');
		if(dotIdx != -1)
		{
			var first = field.substr(0, dotIdx);
			var rest = field.substr(dotIdx + 1);
			var sub = Reflect.getProperty(obj, first);
			if(sub != null)
				setNestedProperty(sub, rest, val);
		}
		else
		{
			try {
				Reflect.setProperty(obj, field, val);
			} catch(e) {
				// silently fail
			}
		}
	}

	static function getNestedProperty(obj:Dynamic, field:String):Dynamic
	{
		var dotIdx = field.indexOf('.');
		if(dotIdx != -1)
		{
			var first = field.substr(0, dotIdx);
			var rest = field.substr(dotIdx + 1);
			var sub = Reflect.getProperty(obj, first);
			if(sub != null)
				return getNestedProperty(sub, rest);
			return null;
		}
		try {
			return Reflect.getProperty(obj, field);
		} catch(e) {
			return null;
		}
	}
}
#end
