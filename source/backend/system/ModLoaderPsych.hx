

package backend.system;

import backend.system.ModTypes;
import backend.system.ModManager.IModResolver;

#if sys
import sys.FileSystem;
#else
import openfl.Assets;
#end

class ModLoaderPsych implements IModResolver
{
	public function new() {}

	public function resolve(mod:ModInfo, modKey:String):Null<String>
	{
		for(root in mod.assetRoots)
		{
			var full = '$root/$modKey';
			#if sys
			if(FileSystem.exists(full))
				return full;
			#else
			if(Assets.exists(full))
				return full;
			#end
		}
		return null;
	}
}
