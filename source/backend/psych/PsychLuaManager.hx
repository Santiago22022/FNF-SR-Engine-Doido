package backend.psych;

import backend.system.ModPaths;
import backend.song.Conductor;
import objects.note.Note;
import objects.note.Strumline;

/**
 * Minimal Psych Lua bridge. Real Lua execution only happens if LUA_ALLOWED is defined
 * and a Lua backend is available; otherwise it safely no-ops but still loads script paths.
 */
class PsychLuaManager
{
	var scripts:Array<PsychLuaScript> = [];
	public var active:Bool = false;

	public function new(song:String, diff:String)
	{
		var songLower = song.toLowerCase();
		loadGlobals();
		loadSongScripts(songLower, diff);
		active = scripts.length > 0;
		callAll("onCreate");
	}

	function loadGlobals():Void
	{
		for(path in ModPaths.listDirRelative("scripts", null, [".lua"], false))
			addScript('scripts/$path');
			
		for(path in ModPaths.listDirRelative("custom_events", null, [".lua"], false))
			addScript('custom_events/$path');
			
		for(path in ModPaths.listDirRelative("custom_notetypes", null, [".lua"], false))
			addScript('custom_notetypes/$path');
	}

	function loadSongScripts(song:String, diff:String):Void
	{
		for(path in ModPaths.listDirRelative('data/$song', null, [".lua"], false))
			addScript('data/$song/$path');

		// compatibility: direct song.lua
		if(ModPaths.exists('data/$song/$song.lua'))
			addScript('data/$song/$song.lua');
			
		// load stage lua script
		if(states.PlayState.SONG != null)
		{
			var stage:String = states.PlayState.SONG.stage;
			if(stage == null) stage = states.PlayState.SONG.song;
			if(ModPaths.exists('stages/$stage.lua'))
				addScript('stages/$stage.lua');
		}
	}

	function addScript(path:String):Void
	{
		var content:String = null;
		if(ModPaths.exists(path))
			content = ModPaths.readText(path);
		if(content == null || content.trim() == "")
			return;
		scripts.push(new PsychLuaScript(path, content));
	}

	public inline function onCreatePost():Void callAll("onCreatePost");
	public inline function onUpdate(elapsed:Float):Void callAll("onUpdate", [elapsed]);
	public inline function onUpdatePost(elapsed:Float):Void callAll("onUpdatePost", [elapsed]);
	public inline function onBeatHit(curBeat:Int):Void callAll("onBeatHit", [curBeat]);
	public inline function onStepHit(curStep:Int):Void callAll("onStepHit", [curStep]);
	public inline function onSongStart():Void callAll("onSongStart");
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

	function callAll(func:String, ?args:Array<Dynamic>):Void
	{
		if(!active) return;
		for(script in scripts)
			script.call(func, args);
	}
}

/**
 * Individual Psych Engine Lua script backed by a real LuaJIT VM (when LUA_ALLOWED).
 */
private class PsychLuaScript
{
	var path:String;
	#if LUA_ALLOWED
	var lua:llua.State;
	#end

	public function new(path:String, code:String)
	{
		this.path = path;
		#if LUA_ALLOWED
		lua = createState();
		if(lua != null)
		{
			// Register all Psych Engine API functions
			PsychLuaAPI.registerCallbacks(lua);
			// Execute the script
			var ret = llua.LuaL.dostring(lua, code);
			if(ret != 0)
			{
				var err = llua.Lua.tostring(lua, -1);
				Logs.print('Lua error in $path: $err', ERROR);
				llua.Lua.pop(lua, 1);
			}
		}
		#end
	}

	public function call(func:String, ?args:Array<Dynamic>):Void
	{
		#if LUA_ALLOWED
		if(lua == null) return;
		llua.Lua.getglobal(lua, func);
		if(llua.Lua.isfunction(lua, -1))
		{
			if(args != null)
			{
				for(arg in args)
					pushArg(lua, arg);
			}
			var ret = llua.Lua.pcall(lua, args != null ? args.length : 0, 0, 0);
			if(ret != 0)
			{
				var err = llua.Lua.tostring(lua, -1);
				Logs.print('Lua call error ($func) in $path: $err', ERROR);
				llua.Lua.pop(lua, 1);
			}
		}
		else
			llua.Lua.pop(lua, 1);
		#end
	}

	#if LUA_ALLOWED
	function createState():llua.State
	{
		var l = llua.LuaL.newstate();
		if(l == null) return null;
		llua.LuaL.openlibs(l);
		return l;
	}

	static function pushArg(l:llua.State, arg:Dynamic):Void
	{
		if(arg == null)
			llua.Lua.pushnil(l);
		else if(Std.isOfType(arg, Bool))
			llua.Lua.pushboolean(l, cast arg);
		else if(Std.isOfType(arg, Int))
			llua.Lua.pushinteger(l, cast arg);
		else if(Std.isOfType(arg, Float))
			llua.Lua.pushnumber(l, cast arg);
		else if(Std.isOfType(arg, String))
			llua.Lua.pushstring(l, cast arg);
		else
			llua.Lua.pushstring(l, Std.string(arg));
	}
	#end
}
