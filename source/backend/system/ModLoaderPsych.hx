

package backend.system;

import backend.system.ModTypes;
import backend.system.ModManager.IModResolver;

#if sys
import sys.FileSystem;
#end

class ModLoaderPsych implements IModResolver
{
	public function new() {}

	public function resolve(mod:ModInfo, modKey:String):Null<String>
	{
		#if sys
		for(root in mod.assetRoots)
		{
			var full = '$root/$modKey';
			if(FileSystem.exists(full))
				return full;
		}
		#end
		return null;
	}
}
