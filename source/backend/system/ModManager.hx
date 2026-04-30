package backend.system;

#if sys
import sys.FileSystem;
#else
import openfl.Assets;
#end
import backend.system.ModLoaderPsych;
import backend.system.ModLoaderVSlice;
import backend.system.ModTypes;

interface IModResolver
{
	public function resolve(mod:ModInfo, modKey:String):Null<String>;
}

class ModManager
{
	static var resolvers:Map<String, IModResolver> = new Map();
	static var initialized:Bool = false;

	static inline function ensureInit():Void
	{
		if(initialized) return;
		initialized = true;
		register("generic", new ModManager.GenericResolver());
		register("polymod", new ModManager.GenericResolver());
		register("v-slice", new ModLoaderVSlice());
		register("vslice", new ModLoaderVSlice());
		register("psych", new ModLoaderPsych());
	}

	public static function register(key:String, resolver:IModResolver):Void
	{
		if(key == null || resolver == null) return;
		resolvers.set(key.toLowerCase(), resolver);
	}

	public static function resolve(mod:ModInfo, modKey:String):Null<String>
	{
		ensureInit();
		var key = (mod.type == null ? "generic" : mod.type.toLowerCase());
		var resolver = resolvers.get(key);
		if(resolver == null)
			resolver = resolvers.get("generic");
		return resolver.resolve(mod, modKey);
	}
}

class GenericResolver implements IModResolver
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
			if(openfl.Assets.exists(full))
				return full;
			#end
		}
		return null;
	}
}
