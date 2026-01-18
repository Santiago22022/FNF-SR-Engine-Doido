package backend.psych;

import backend.system.ModPaths;
import backend.song.Conductor;
import backend.song.Timings;
import objects.note.Note;
import objects.note.Strumline;
import states.PlayState;
import flixel.FlxG;
import flixel.FlxSprite;

#if LUA_ALLOWED
import llua.Lua;
import llua.LuaL;
import llua.State;
import llua.Convert;
#end

class PsychLuaManager
{
	public var scripts:Array<PsychLuaScript> = [];
	public var active:Bool = false;

	public function new(song:String, diff:String)
	{
		#if LUA_ALLOWED
		var songLower = song.toLowerCase();
		loadGlobals();
		loadSongScripts(songLower, diff);
		active = scripts.length > 0;
		callAll("onCreate", []);
		#end
	}

	function loadGlobals():Void
	{
		#if LUA_ALLOWED
		for(path in backend.system.ModLoader.getGlobalScripts())
			addScript(path);
		#end
	}

	function loadSongScripts(song:String, diff:String):Void
	{
		#if LUA_ALLOWED
		for(path in backend.system.ModLoader.getSongScripts(song))
			addScript(path);
		#end
	}

	public function addScript(path:String):Void
	{
		#if LUA_ALLOWED
		// ModLoader now returns absolute paths, so we use them directly.
		if(path != null && backend.system.ModPaths.exists(path)) // Exists check handles sys paths too
		{
			try {
				scripts.push(new PsychLuaScript(path));
			} catch(e:Dynamic) {
				backend.system.Logs.print('Error loading Lua script $path: $e', WARNING);
			}
		}
		#end
	}

	public inline function onCreatePost():Void callAll("onCreatePost", []);
	public inline function onUpdate(elapsed:Float):Void callAll("onUpdate", [elapsed]);
	public inline function onUpdatePost(elapsed:Float):Void callAll("onUpdatePost", [elapsed]);
	public inline function onBeatHit(curBeat:Int):Void callAll("onBeatHit", [curBeat]);
	public inline function onStepHit(curStep:Int):Void callAll("onStepHit", [curStep]);
	public inline function onSongStart():Void callAll("onSongStart", []);
	public inline function onCountdownTick(count:Int):Void callAll("onCountdownTick", [count]);
	public inline function onEvent(name:String, v1:String, v2:String):Void callAll("onEvent", [name, v1, v2]);

	public function goodNoteHit(note:Note, strumline:Strumline):Void
	{
		callAll("goodNoteHit", [
			note.strumlineID,
			note.noteData,
			note.noteType,
			note.isHold,
			strumline.isPlayer
		]);
	}

	public function noteMiss(note:Note, strumline:Strumline):Void
	{
		callAll("noteMiss", [
			note.strumlineID,
			note.noteData,
			note.noteType,
			note.isHold,
			strumline.isPlayer
		]);
	}

	function callAll(func:String, args:Array<Dynamic>):Void
	{
		#if LUA_ALLOWED
		if(!active) return;
		for(script in scripts)
			script.call(func, args);
		#end
	}
}

class PsychLuaScript
{
	#if LUA_ALLOWED
	public var lua:State;
	public var scriptName:String;
	#end

	public function new(path:String)
	{
		#if LUA_ALLOWED
		scriptName = path;
		lua = LuaL.newstate();
		LuaL.openlibs(lua);
		
		// --- Basic Psych API ---
		
		Lua_helper.add_callback(lua, "debugPrint", function(text:String) {
			backend.system.Logs.print(text);
		});

		Lua_helper.add_callback(lua, "close", function(printMessage:Bool = true) {
			if(printMessage) backend.system.Logs.print("Closing script: " + scriptName);
			stop();
		});
		
		Lua_helper.add_callback(lua, "getProperty", function(variable:String) {
			return getVar(variable);
		});
		
		Lua_helper.add_callback(lua, "setProperty", function(variable:String, value:Dynamic) {
			setVar(variable, value);
			return true;
		});

		Lua_helper.add_callback(lua, "getPropertyFromClass", function(classVar:String, variable:String) {
			var myClass:Dynamic = Type.resolveClass(classVar);
			if(myClass == null) return null;
			return Reflect.getProperty(myClass, variable);
		});

		Lua_helper.add_callback(lua, "setPropertyFromClass", function(classVar:String, variable:String, value:Dynamic) {
			var myClass:Dynamic = Type.resolveClass(classVar);
			if(myClass == null) return false;
			Reflect.setProperty(myClass, variable, value);
			return true;
		});

		// Basic Song/Game Vars
		setVar("curBeat", 0);
		setVar("curStep", 0);
		setVar("score", 0);
		setVar("misses", 0);
		setVar("hits", 0);
		setVar("health", 1);
		setVar("songName", PlayState.SONG.song);
		setVar("isStoryMode", PlayState.isStoryMode);
		setVar("difficulty", PlayState.songDiff);
		
		// Load File
		try {
			var result = LuaL.dofile(lua, path);
			if(result != 0) {
				var err = Lua.tostring(lua, -1);
				backend.system.Logs.print("Lua Error: " + err, ERROR);
				Lua.pop(lua, 1);
			}
		} catch(e:Dynamic) {
			backend.system.Logs.print("Lua Exception: " + e, ERROR);
		}
		#end
	}

	public function call(func:String, args:Array<Dynamic>):Dynamic
	{
		#if LUA_ALLOWED
		if(lua == null) return null;
		
		// Update standard variables before call
		if(PlayState.instance != null) {
			@:privateAccess {
				setVar("curBeat", PlayState.instance.curBeat);
				setVar("curStep", PlayState.instance.curStep);
			}
			setVar("health", PlayState.health);
			setVar("score", Timings.score);
			setVar("misses", Timings.misses);
		}

		Lua.getglobal(lua, func);
		if(Lua.isfunction(lua, -1) == 0) {
			Lua.pop(lua, 1);
			return null;
		}

		for(arg in args)
			Convert.toLua(lua, arg);

		var result = Lua.pcall(lua, args.length, 1, 0);
		if(result != 0) {
			var err = Lua.tostring(lua, -1);
			// Only print error if it's not a generic "attempt to call nil" (function missing)
			if(err != null && err.indexOf("attempt to call a nil value") == -1)
				backend.system.Logs.print("Lua Call Error (" + func + "): " + err, WARNING);
			Lua.pop(lua, 1);
			return null;
		}

		var returnVal = Convert.fromLua(lua, -1);
		Lua.pop(lua, 1);
		return returnVal;
		#else
		return null;
		#end
	}

	public function stop() {
		#if LUA_ALLOWED
		if(lua == null) return;
		Lua.close(lua);
		lua = null;
		#end
	}
	
	// --- Reflection Helpers ---

	function getVar(variable:String):Dynamic
	{
		var split = variable.split('.');
		var obj:Dynamic = PlayState.instance;
		if(split.length > 1) {
			// Handle object.property.subproperty
			for(i in 0...split.length-1) {
				obj = getObjectVar(obj, split[i]);
				if(obj == null) return null;
			}
			return getObjectVar(obj, split[split.length-1]);
		}
		return getObjectVar(obj, variable);
	}

	function setVar(variable:String, value:Dynamic):Void
	{
		var split = variable.split('.');
		var obj:Dynamic = PlayState.instance;
		if(split.length > 1) {
			for(i in 0...split.length-1) {
				obj = getObjectVar(obj, split[i]);
				if(obj == null) return;
			}
			setObjectVar(obj, split[split.length-1], value);
		} else {
			setObjectVar(obj, variable, value);
		}
	}
	
	function getObjectVar(obj:Dynamic, varName:String):Dynamic
	{
		if(obj == null) return null;
		// Handle Maps/Arrays/Groups specifically if needed, but Reflect usually works
		return Reflect.getProperty(obj, varName);
	}
	
	function setObjectVar(obj:Dynamic, varName:String, value:Dynamic):Void
	{
		if(obj == null) return;
		Reflect.setProperty(obj, varName, value);
	}
}

#if LUA_ALLOWED
class Lua_helper {
	public static function add_callback(lua:State, name:String, func:Dynamic) {
		Lua.pushstring(lua, name);
		Convert.toLua(lua, func);
		Lua.settable(lua, Lua.LUA_GLOBALSINDEX);
	}
}
#end
