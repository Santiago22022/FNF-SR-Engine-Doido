

package backend.system;

import backend.system.ModTypes;
import backend.system.ModManager.IModResolver;

#if sys
import sys.FileSystem;
import haxe.io.Path;
#else
import openfl.Assets;
import haxe.io.Path;
#end

class ModLoaderPsych implements IModResolver
{
	public function new() {}

	public function resolve(mod:ModInfo, modKey:String):Null<String>
	{
		// Common psych mappings: e.g. "characters/x" -> "images/characters/x"
		var testKeys:Array<String> = [modKey];
		var lowerKey = modKey.toLowerCase();
		
		if(lowerKey.startsWith("characters/") && !lowerKey.startsWith("images/"))
			testKeys.push('images/' + modKey);
		else if(lowerKey.startsWith("icons/") && !lowerKey.startsWith("images/"))
			testKeys.push('images/' + modKey);
		else if(lowerKey.startsWith("stages/") && !lowerKey.startsWith("images/") && (lowerKey.endsWith(".png") || lowerKey.endsWith(".xml") || lowerKey.endsWith(".txt")))
			testKeys.push('images/' + modKey);

		for(key in testKeys)
		{
			for(root in mod.assetRoots)
			{
				var full = '$root/$key';
				#if sys
				if(FileSystem.exists(full))
					return full;
				#else
				if(Assets.exists(full))
					return full;
				#end
			}
		}

		// Also Psych Engine fallback for global mods/ folder
		// If it's something like "images/characters/x.png", test "mods/images/characters/x.png"
		#if sys
		var globalRoots:Array<String> = [
			Path.normalize(ModLoader.modRoot + "/images"),
			Path.normalize(ModLoader.modRoot + "/data")
		];
		
		for(key in testKeys)
		{
			for(groot in globalRoots)
			{
				var testPath = Path.normalize(ModLoader.modRoot + "/" + key);
				if(FileSystem.exists(testPath))
					return testPath;
			}
		}
		#end

		return null;
	}
}
