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
	}

	function loadSongScripts(song:String, diff:String):Void
	{
		for(path in ModPaths.listDirRelative('data/$song', null, [".lua"], false))
			addScript('data/$song/$path');

		// compatibility: direct song.lua
		if(ModPaths.exists('data/$song/$song.lua'))
			addScript('data/$song/$song.lua');
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

private class PsychLuaScript
{
	var path:String;
	#if LUA_ALLOWED
	var lua:Dynamic; // placeholder; requires a Lua backend like llua
	#end

	public function new(path:String, code:String)
	{
		this.path = path;
		#if LUA_ALLOWED
		lua = createState(code);
		#end
	}

	public function call(func:String, ?args:Array<Dynamic>):Void
	{
		#if LUA_ALLOWED
		if(lua == null) return;
		// Implement actual Lua function lookup/invocation when Lua backend is available.
		#end
	}

	#if LUA_ALLOWED
	function createState(code:String):Dynamic
	{
		// Stub to avoid compile errors when LUA_ALLOWED is not provided.
		return null;
	}
	#end
}
