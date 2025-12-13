package backend.system;

import haxe.io.Path;
import StringTools;
import tjson.TJSON;
import backend.system.ModTypes;

#if sys
import sys.FileSystem;
import sys.io.File;
#end

class ModLoader
{
	public static var modRoot:String = "mods";
	public static var sharedFolders:Array<String> = [];
	public static var extraRoots:Array<String> = [];
	public static var ignoredEntries:Array<String> = [".git", ".svn", ".idea", ".vscode", "__MACOSX"];

	static var dirty:Bool = true;
	static var activeMods:Array<ModInfo> = [];
	static var modsById:Map<String, ModInfo> = new Map();
	static var manifestCache:Map<String, Dynamic> = new Map();
	static var resolveCache:Map<String, String> = new Map();

	public static function setRoot(path:String):Void
	{
		modRoot = path;
		dirty = true;
	}

	public static function clear():Void
	{
		activeMods = [];
		modsById = new Map();
		manifestCache = new Map();
		resolveCache = new Map();
		extraRoots = [];
		dirty = true;
	}

	public static function registerExtraRoot(path:String):Void
	{
		if(path == null || path.trim() == "") return;
		var norm = Path.normalize(path);
		if(!extraRoots.contains(norm))
		{
			extraRoots.push(norm);
			dirty = true;
		}
	}

	public static function getActiveMods():Array<ModInfo>
	{
		ensure();
		return activeMods;
	}

	public static function getMod(id:String):Null<ModInfo>
	{
		ensure();
		return modsById.get(id);
	}

	public static function refresh():Array<ModInfo>
	{
		dirty = false;
		activeMods = [];
		modsById = new Map();
		manifestCache = new Map();
		resolveCache = new Map();
		buildSharedFolders();
		#if sys
		var preferredOrder = loadOrderList();

		for(root in getScanRoots())
		{
			if(!FileSystem.exists(root)) continue;
			for(entry in FileSystem.readDirectory(root))
			{
				if(shouldSkipEntry(entry)) continue;

				var modPath = '$root/$entry';
				if(!FileSystem.isDirectory(modPath))
					continue;

				var meta = readMeta(modPath);
				if(meta.enabled)
				{
					activeMods.push(meta);
					modsById.set(meta.id, meta);
				}
			}
		}

		activeMods.sort(function(a:ModInfo, b:ModInfo) {
			return sortMods(preferredOrder, a, b);
		});
		validateMods(activeMods);
		#end
		return activeMods;
	}

	public static function resolveAssetPath(key:String, ?library:String):Null<String>
	{
		#if sys
		ensure();
		if(activeMods.length <= 0 && sharedFolders.length <= 0) return null;

		var modKey = (library != null && library.length > 0) ? '$library/$key' : key;
		if(resolveCache.exists(modKey))
			return resolveCache.get(modKey);

		for(mod in activeMods)
		{
			var resolved = ModManager.resolve(mod, modKey);
			if(resolved != null)
			{
				resolveCache.set(modKey, resolved);
				return resolved;
			}
		}

		for(shared in sharedFolders)
		{
			var sharedPath = '$shared/$modKey';
			if(FileSystem.exists(sharedPath))
			{
				resolveCache.set(modKey, sharedPath);
				return sharedPath;
			}
		}
		#end
		return null;
	}

	public static function resolveAllAssetPaths(key:String, ?library:String):Array<String>
	{
		#if sys
		ensure();
		var paths:Array<String> = [];
		var modKey = (library != null && library.length > 0) ? '$library/$key' : key;

		for(mod in activeMods)
		{
			var resolved = ModManager.resolve(mod, modKey);
			if(resolved != null)
				paths.push(resolved);
		}
		for(shared in sharedFolders)
		{
			var sharedPath = '$shared/$modKey';
			if(FileSystem.exists(sharedPath))
				paths.push(sharedPath);
		}
		return paths;
		#else
		return [];
		#end
	}

	public static inline function modHasAsset(mod:ModInfo, key:String, ?library:String):Bool
	{
		#if sys
		var modKey = (library != null && library.length > 0) ? '$library/$key' : key;
		return ModManager.resolve(mod, modKey) != null;
		#else
		return false;
		#end
	}

	#if sys
	static inline function ensure():Void
	{
		if(dirty)
			refresh();
	}

	static function readManifest(path:String):Dynamic
	{
		if(path == null || path == "" || !FileSystem.exists(path) || FileSystem.isDirectory(path))
			return null;
		if(manifestCache.exists(path))
			return manifestCache.get(path);
		try {
			var data = TJSON.parse(File.getContent(path));
			manifestCache.set(path, data);
			return data;
		} catch(e) {
			Logs.print('error reading $path: $e', WARNING);
		}
		return null;
	}

	static function readMeta(path:String):ModInfo
	{
		var folder:String = Path.withoutDirectory(path);
		var metaPath = '$path/mod.json';
		var psychMetaPath = '$path/pack.json';
		var polymodMetaPath = '$path/_polymod_meta.json';
		var disabledFlag:Bool = FileSystem.exists('$path/disabled') || FileSystem.exists('$path/disabled.txt');

		var data:Dynamic = readManifest(metaPath);
		if(data == null) data = readManifest(psychMetaPath);
		if(data == null) data = readManifest(polymodMetaPath);
		if(data == null) data = {};

		function pick<T>(field:String, fallback:T):T
		{
			return Reflect.hasField(data, field) ? Reflect.field(data, field) : fallback;
		}
		function pickAlias<T>(fields:Array<String>, fallback:T):T
		{
			for(f in fields)
				if(Reflect.hasField(data, f))
					return Reflect.field(data, f);
			return fallback;
		}

		var id = normalizeId(pickAlias(["id", "name", "title"], folder));
		var icon = pickAlias(["icon", "icon_path"], null);
		if(icon != null)
			icon = Path.normalize('$path/$icon');

		var enabled = pickAlias(["enabled", "active"], true);
		if(pickAlias(["disabled", "hidden"], false))
			enabled = false;
		if(disabledFlag)
			enabled = false;

		var hasPolymod:Bool = polymodMetaPath != null && FileSystem.exists(polymodMetaPath);
		var modType = detectModType(path, data, pickAlias(["type", "engine", "loader"], hasPolymod ? "v-slice" : "generic"), hasPolymod);

		var assetRoots = buildAssetRoots(path, data);
		var authors = collectStringArray(pickAlias(["authors", "author", "creators", "credits", "contributors"], []));
		var license:Null<String> = pickAlias(["license", "licence"], null);
		var engineVersion:Null<String> = pickAlias(["engineVersion", "targetEngineVersion", "api_version"], null);
		var dependencies = collectStringArray(pickAlias(["dependencies", "depends", "requires"], []));
		var conflicts = collectStringArray(pickAlias(["conflicts", "incompatibilities"], []));

		if(icon == null)
		{
			var altIcons = [
				'$path/pack.png',
				'$path/icon.png',
				'$path/pack/icon.png',
				'$path/_polymod_icon.png'
			];
			for(ic in altIcons)
				if(FileSystem.exists(ic))
				{
					icon = Path.normalize(ic);
					break;
				}
		}

		var priorityFromFolder = extractPriorityFromFolder(folder);

		return {
			id: id,
			name: pickAlias(["name", "title"], folder),
			version: pickAlias(["version", "modVersion"], "0.0.0"),
			description: pickAlias(["description", "desc"], ""),
			priority: Std.int(pickAlias(["priority", "order", "index"], priorityFromFolder)),
			enabled: enabled,
			path: Path.normalize(path),
			type: modType,
			icon: icon,
			assetRoots: assetRoots,
			authors: authors,
			license: license,
			engineVersion: engineVersion,
			dependencies: dependencies,
			conflicts: conflicts
		};
	}

	static function detectModType(path:String, data:Dynamic, currentType:String, hasPolymod:Bool):String
	{
		var normPath = Path.normalize(path).toLowerCase();
		if(currentType != "generic")
			return currentType;

		if(hasPolymod || Reflect.hasField(data, "api_version"))
			return "v-slice";

		if(normPath.indexOf("psychengine") != -1 || normPath.indexOf("psych") != -1)
			return "psych";

		var psychHints = ["data", "stages", "characters", "songs", "scripts"];
		for(hint in psychHints)
		{
			var candidate = Path.normalize('$path/$hint');
			if(FileSystem.exists(candidate) && FileSystem.isDirectory(candidate))
				return "psych";
		}

		return currentType;
	}

	static function loadOrderList():Array<String>
	{
		var out:Array<String> = [];
		for(root in getScanRoots())
		{
			var orderPath = '$root/modsList.txt';
			if(FileSystem.exists(orderPath) && !FileSystem.isDirectory(orderPath))
			{
				try {
					var lines = File.getContent(orderPath).split("\n");
					for(line in lines)
					{
						var clean = StringTools.trim(line);
						if(clean == "" || clean.startsWith("#"))
							continue;
						out.push(normalizeId(clean));
					}
				} catch(e) {}
			}
		}
		return out;
	}

	static function sortByOrder(order:Array<String>, a:ModInfo, b:ModInfo):Int
	{
		var ai = order.indexOf(a.id);
		var bi = order.indexOf(b.id);
		if(ai == -1 && bi == -1) return 0;
		if(ai == -1) return 1;
		if(bi == -1) return -1;
		return ai - bi;
	}

	static function sortMods(order:Array<String>, a:ModInfo, b:ModInfo):Int
	{
		if(order.length > 0)
		{
			var ord = sortByOrder(order, a, b);
			if(ord != 0) return ord;
		}
		return b.priority - a.priority;
	}

	static function normalizeId(id:String):String
	{
		if(id == null)
			return 'mod-' + Std.int(Math.random() * 1000000);
		var cleaned = StringTools.trim(id).toLowerCase();
		if(cleaned == "")
			return 'mod-' + Std.int(Math.random() * 1000000);
		return cleaned;
	}

	static function extractPriorityFromFolder(folder:String):Int
	{
		var priority:Int = 0;
		var regex = ~/^([0-9]{1,3})/;
		if(regex.match(folder))
		{
			var match = regex.matched(1);
			if(match != null)
				priority = Std.parseInt(match);
		}
		return priority;
	}

	static function buildAssetRoots(path:String, data:Dynamic):Array<String>
	{
		var roots:Array<String> = [];
		var normalized = Path.normalize(path);
		roots.push(normalized);

		var candidate = Path.normalize('$normalized/assets');
		if(FileSystem.exists(candidate) && FileSystem.isDirectory(candidate))
			roots.push(candidate);

		var packCandidate = Path.normalize('$normalized/pack');
		if(FileSystem.exists(packCandidate) && FileSystem.isDirectory(packCandidate))
		{
			var packAssets = Path.normalize('$packCandidate/assets');
			if(FileSystem.exists(packAssets) && FileSystem.isDirectory(packAssets))
				roots.push(packAssets);
			else
				roots.push(packCandidate);
		}

		if(Reflect.hasField(data, "assetRoots"))
		{
			var custom:Array<Dynamic> = Reflect.field(data, "assetRoots");
			for(root in custom)
			{
				if(root == null) continue;
				var rStr:String = Std.string(root);
				if(rStr.trim() == "") continue;
				var full = Path.normalize('$normalized/$rStr');
				if(FileSystem.exists(full) && FileSystem.isDirectory(full))
					roots.push(full);
			}
		}

		var dedup:Map<String, Bool> = new Map();
		var finalRoots:Array<String> = [];
		for(r in roots)
		{
			if(!dedup.exists(r))
			{
				dedup.set(r, true);
				finalRoots.push(r);
			}
		}
		return finalRoots;
	}

	static function collectStringArray(val:Dynamic):Array<String>
	{
		var out:Array<String> = [];
		if(val == null) return out;
		if(Std.isOfType(val, Array))
		{
			for(item in (cast val : Array<Dynamic>))
			{
				if(item == null) continue;
				var s = StringTools.trim(Std.string(item));
				if(s != "") out.push(s);
			}
			return normalizeStringArray(out);
		}
		var asStr = StringTools.trim(Std.string(val));
		if(asStr.indexOf(",") >= 0)
			out = asStr.split(",").map(StringTools.trim);
		else if(asStr != "")
			out.push(asStr);
		return normalizeStringArray(out);
	}

	static function normalizeStringArray(arr:Array<String>):Array<String>
	{
		var out:Array<String> = [];
		var seen:Map<String, Bool> = new Map();
		for(s in arr)
		{
			var clean = StringTools.trim(s);
			var key = clean.toLowerCase();
			if(!seen.exists(key))
			{
				seen.set(key, true);
				out.push(clean);
			}
		}
		return out;
	}

	static function buildSharedFolders():Void
	{
		sharedFolders = [];
		var candidate = Path.normalize('$modRoot/shared');
		if(FileSystem.exists(candidate) && FileSystem.isDirectory(candidate))
			sharedFolders.push(candidate);
		var assetsCandidate = Path.normalize('$candidate/assets');
		if(FileSystem.exists(assetsCandidate) && FileSystem.isDirectory(assetsCandidate))
			sharedFolders.push(assetsCandidate);
	}

	static function getScanRoots():Array<String>
	{
		var roots:Array<String> = [];
		var main = Path.normalize(modRoot);
		roots.push(main);
		for(extra in extraRoots)
			roots.push(extra);

		var vsliceExample = Path.normalize('$main/../Funkin-main/example_mods');
		if(FileSystem.exists(vsliceExample) && FileSystem.isDirectory(vsliceExample))
			roots.push(vsliceExample);

		var psychMods = Path.normalize('$main/../FNF-PsychEngine-main/mods');
		if(FileSystem.exists(psychMods) && FileSystem.isDirectory(psychMods))
			roots.push(psychMods);
		var psychExample = Path.normalize('$main/../FNF-PsychEngine-main/example_mods');
		if(FileSystem.exists(psychExample) && FileSystem.isDirectory(psychExample))
			roots.push(psychExample);

		var dedup:Map<String, Bool> = new Map();
		var finalRoots:Array<String> = [];
		for(r in roots)
		{
			if(!dedup.exists(r))
			{
				dedup.set(r, true);
				finalRoots.push(r);
			}
		}
		return finalRoots;
	}

	static function validateMods(mods:Array<ModInfo>):Void
	{
		var missingDeps:Array<String> = [];
		var conflicting:Array<String> = [];

		for(mod in mods)
			for(dep in mod.dependencies)
				if(!modsById.exists(dep))
					missingDeps.push('${mod.id} -> $dep');

		for(mod in mods)
			for(conf in mod.conflicts)
				if(modsById.exists(conf))
					conflicting.push('${mod.id} x $conf');

		if(missingDeps.length > 0)
			Logs.print('Missing mod dependencies: $missingDeps', WARNING);
		if(conflicting.length > 0)
			Logs.print('Mod conflicts detected: $conflicting', WARNING);
	}

	static inline function shouldSkipEntry(entry:String):Bool
	{
		if(entry == null || entry.length == 0) return true;
		if(entry.startsWith(".") || ignoredEntries.contains(entry))
			return true;
		// skip compressed templates (like Psych modTemplate.zip)
		if(entry.toLowerCase().endsWith(".zip"))
			return true;
		return false;
	}
	#end
}
