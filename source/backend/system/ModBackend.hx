package backend.system;

import haxe.io.Path;
#if sys
import sys.FileSystem;
import sys.io.File;
#end
import haxe.io.Bytes;
import openfl.utils.Assets;

typedef ModStat = {
	var mtimeMs:Float;
	var size:Int;
};

/**
 * Platform-aware filesystem helpers for the mod loader.
 * Guards all sys calls and provides safe fallbacks for html5.
 */
class ModBackend
{
	public static function exists(path:String):Bool
	{
		#if sys
		var normalized = normalize(path);
		if(FileSystem.exists(normalized))
			return true;
		return Assets.exists(normalized);
		#else
		return Assets.exists(normalize(path));
		#end
	}

	public static function readText(path:String):String
	{
		#if sys
		var normalized = normalize(path);
		if(FileSystem.exists(normalized))
			return File.getContent(normalized);
		return Assets.getText(normalized);
		#else
		return Assets.getText(normalize(path));
		#end
	}

	public static function readBytes(path:String):Bytes
	{
		#if sys
		var normalized = normalize(path);
		if(FileSystem.exists(normalized))
			return File.getBytes(normalized);
		return Assets.getBytes(normalized);
		#else
		return Assets.getBytes(normalize(path));
		#end
	}

	public static function listDir(path:String):Array<String>
	{
		var output:Array<String> = [];
		#if sys
		var normalized = normalize(path);
		if(!FileSystem.exists(normalized) || !FileSystem.isDirectory(normalized))
			return output;
		for(entry in FileSystem.readDirectory(normalized))
			output.push(entry);
		#else
		var prefix = normalize(path);
		if(!prefix.endsWith("/")) prefix += "/";
		for(asset in Assets.list())
		{
			if(asset.startsWith(prefix))
			{
				var rest = asset.substr(prefix.length);
				if(rest.indexOf("/") == -1)
					output.push(rest);
			}
		}
		#end
		return output;
	}

	public static function stat(path:String):Null<ModStat>
	{
		#if sys
		try {
			var info = FileSystem.stat(normalize(path));
			return { mtimeMs: info.mtime.getTime(), size: info.size };
		} catch(e) {}
		return null;
		#else
		// html5/openfl lacks stat; return null for safe callers
		return null;
		#end
	}

	static inline function normalize(path:String):String
	{
		#if sys
		return Path.normalize(path);
		#else
		return path;
		#end
	}
}
