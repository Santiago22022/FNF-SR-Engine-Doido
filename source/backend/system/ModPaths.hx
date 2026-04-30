package backend.system;

import haxe.io.Path;
import StringTools;
import openfl.utils.Assets;
import backend.system.ModLoader;
#if sys
import sys.FileSystem;
import sys.io.File;
#end

/**
 * Virtual File System that resolves assets through active mods before
 * falling back to base assets.
 */
class ModPaths
{
	public static function resolveAssetPath(key:String, ?library:String):Null<String>
		return ModLoader.resolveAssetPath(key, library);

	public static function resolveWithExtensions(base:String, ?library:String, exts:Array<String>):Null<String>
	{
		if(exts == null) exts = [];
		var extsToCheck:Array<String> = [];
		for(ext in exts)
		{
			if(ext == null) continue;
			extsToCheck.push(ext);
			var upper = ext.toUpperCase();
			if(!extsToCheck.contains(upper))
				extsToCheck.push(upper);
		}
		for(ext in extsToCheck)
		{
			var res = resolveAssetPath('$base$ext', library);
			if(res != null)
				return res;
		}
		return null;
	}

	public static function exists(key:String, ?library:String):Bool
	{
		var resolved = resolveAssetPath(key, library);
		#if sys
		if(resolved != null && FileSystem.exists(resolved))
			return true;
		#end
		if(resolved != null && Assets.exists(resolved))
			return true;
		return Assets.exists(resolveBasePath(key, library));
	}

	public static function readText(key:String, ?library:String):String
	{
		var resolved = resolveAssetPath(key, library);
		#if sys
		if(resolved != null && FileSystem.exists(resolved))
			return File.getContent(resolved);
		#end
		if(resolved != null && Assets.exists(resolved))
			return Assets.getText(resolved);
		return Assets.getText(resolveBasePath(key, library));
	}

	public static function readBytes(key:String, ?library:String):haxe.io.Bytes
	{
		var resolved = resolveAssetPath(key, library);
		#if sys
		if(resolved != null && FileSystem.exists(resolved))
			return File.getBytes(resolved);
		#end
		if(resolved != null && Assets.exists(resolved))
			return Assets.getBytes(resolved);
		return Assets.getBytes(resolveBasePath(key, library));
	}

	public static function listDir(dir:String, ?library:String, extensions:Array<String> = null, recursive:Bool = false):Array<String>
	{
		var output:Array<String> = [];
		var seen:Map<String, Bool> = new Map();

		function addItem(item:String)
		{
			if(!seen.exists(item))
			{
				seen.set(item, true);
				output.push(item);
			}
		}

		for(mod in ModLoader.getActiveMods())
		{
			for(root in mod.assetRoots)
			{
				#if sys
				var baseRoot = Path.normalize('$root/$dir');
				if(!FileSystem.exists(baseRoot) || !FileSystem.isDirectory(baseRoot))
					continue;

					var stack:Array<String> = [baseRoot];
					while(stack.length > 0)
					{
						var current = stack.pop();
						for(file in FileSystem.readDirectory(current))
						{
							var normalized = Path.normalize('$current/$file');
							if(FileSystem.isDirectory(normalized))
							{
								if(recursive)
									stack.push(normalized);
								continue;
							}
							if(matchesExt(normalized, extensions))
								addItem(Path.withoutDirectory(normalized));
						}
					}
					#else
					var prefix = normalizeAssetPath('$root/$dir');
					for(asset in Assets.list())
				{
					if(!asset.startsWith(prefix))
						continue;
					var rest = asset.substr(prefix.length);
					if(rest.startsWith("/"))
						rest = rest.substr(1);
					if(!recursive && rest.indexOf("/") != -1)
						continue;
					if(matchesExt(asset, extensions))
					{
						var trimmed = asset.startsWith('assets/') ? asset.substr('assets/'.length) : asset;
						addItem(Path.withoutDirectory(trimmed));
					}
				}
				#end
			}
		}

		var resolvedBase = resolveBasePath(dir, library);
		#if sys
		if(FileSystem.exists(resolvedBase) && FileSystem.isDirectory(resolvedBase))
		{
			for(file in FileSystem.readDirectory(resolvedBase))
			{
				var normalized = Path.normalize('$resolvedBase/$file');
				if(FileSystem.isDirectory(normalized)) continue;
				if(matchesExt(normalized, extensions))
					addItem(Path.withoutDirectory(normalized));
			}
		}
		#else
		for(asset in Assets.list())
		{
			if(!asset.startsWith(resolvedBase))
				continue;
			var rest = asset.substr(resolvedBase.length);
			if(rest.startsWith("/"))
				rest = rest.substr(1);
			if(!recursive && rest.indexOf("/") != -1)
				continue;
				if(matchesExt(asset, extensions))
				{
					var trimmed = asset;
					if(asset.startsWith('assets/'))
						trimmed = asset.substr('assets/'.length);
					addItem(Path.withoutDirectory(trimmed));
				}
			}
			#end

			return output;
	}

	public static function listDirRelative(dir:String, ?library:String, extensions:Array<String> = null, recursive:Bool = false):Array<String>
	{
		var output:Array<String> = [];
		var basePath = resolveBasePath(dir, library);

		#if sys
		for(root in ModLoader.getActiveMods())
		{
			for(assetRoot in root.assetRoots)
			{
				var baseRoot = Path.normalize('$assetRoot/$dir');
				if(!FileSystem.exists(baseRoot) || !FileSystem.isDirectory(baseRoot))
					continue;

				var stack:Array<String> = [baseRoot];
				while(stack.length > 0)
				{
					var current = stack.pop();
					for(file in FileSystem.readDirectory(current))
					{
						var normalized = Path.normalize('$current/$file');
						if(FileSystem.isDirectory(normalized))
						{
							if(recursive)
								stack.push(normalized);
							continue;
						}
						if(matchesExt(normalized, extensions))
						{
							var rel = normalized.substr(baseRoot.length);
							if(rel.startsWith("/") || rel.startsWith("\\")) rel = rel.substr(1);
							output.push(rel);
						}
					}
				}
			}
		}
		if(FileSystem.exists(basePath) && FileSystem.isDirectory(basePath))
		{
			var stack:Array<String> = [basePath];
			while(stack.length > 0)
			{
				var current = stack.pop();
				for(file in FileSystem.readDirectory(current))
				{
					var normalized = Path.normalize('$current/$file');
					if(FileSystem.isDirectory(normalized))
					{
						if(recursive)
							stack.push(normalized);
						continue;
					}
					if(matchesExt(normalized, extensions))
					{
						var rel = normalized.substr(basePath.length);
						if(rel.startsWith("/") || rel.startsWith("\\")) rel = rel.substr(1);
						output.push(rel);
					}
				}
			}
		}
		#else
		var prefixes:Array<String> = [];
		for(mod in ModLoader.getActiveMods())
			for(assetRoot in mod.assetRoots)
			{
				var prefix = normalizeAssetPath('$assetRoot/$dir');
				if(!prefix.endsWith("/")) prefix += "/";
				prefixes.push(prefix);
			}
		var basePrefix = resolveBasePath(dir, library);
		if(!basePrefix.endsWith("/"))
			basePrefix += "/";
		prefixes.push(basePrefix);

		for(asset in Assets.list())
		{
			for(prefix in prefixes)
			{
				if(!asset.startsWith(prefix))
					continue;
				var rel = asset.substr(prefix.length);
				if(!recursive && rel.indexOf("/") != -1)
					continue;
				if(matchesExt(asset, extensions))
					output.push(rel);
				break;
			}
		}
		#end

		return output;
	}

	static function matchesExt(path:String, extensions:Array<String>):Bool
	{
		if(extensions == null || extensions.length == 0)
			return true;
		for(ext in extensions)
			if(path.toLowerCase().endsWith(ext.toLowerCase()))
				return true;
		return false;
	}

	static function resolveBasePath(key:String, ?library:String):String
	{
		#if RENAME_UNDERSCORE
		var pathArray:Array<String> = key.split("/").copy();
		var loopCount = 0;
		key = "";

		for (folder in pathArray) {
			var truFolder:String = folder;

			if(folder.startsWith("_"))
				truFolder = folder.substr(1);

			loopCount++;
			key += truFolder + (loopCount == pathArray.length ? "" : "/");
		}

		if(library != null)
			library = (library.startsWith("_") ? library.split("_")[1] : library);
		#end

		if(library == null)
			return 'assets/$key';
		else
			return 'assets/$library/$key';
	}

	static function normalizeAssetPath(path:String):String
	{
		#if sys
		return StringTools.replace(path, "\\", "/");
		#else
		return path;
		#end
	}
}
