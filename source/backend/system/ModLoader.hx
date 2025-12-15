package backend.system;

import haxe.io.Path;
import StringTools;
import tjson.TJSON;
import backend.system.ModTypes;
import backend.system.ModConfig;

#if sys
import sys.FileSystem;
import sys.io.File;
#if android
import lime.system.System;
#end
#else
import openfl.Assets;
import openfl.utils.AssetType;
#end

#if sys
typedef PsychList = {
	var order:Array<String>;
	var enabled:Array<String>;
}
#end

class ModLoader
{
	#if sys
	public static var modRoot:String = "mods";
	public static var sharedFolders:Array<String> = [];
	public static var extraRoots:Array<String> = [];
	public static var ignoredEntries:Array<String> = [".git", ".svn", ".idea", ".vscode", "__MACOSX"];
	#else
	public static var modRoot:String = "assets/mods";
	public static var sharedFolders:Array<String> = [];
	public static var extraRoots:Array<String> = [];
	public static var ignoredEntries:Array<String> = [];
	#end

	static var dirty:Bool = true;
	static var activeMods:Array<ModInfo> = [];
	static var allMods:Array<ModInfo> = [];
	static var modsById:Map<String, ModInfo> = new Map();
	static var manifestCache:Map<String, Dynamic> = new Map();
	static var resolveCache:Map<String, String> = new Map();

	public static function setRoot(path:String):Void
	{
		#if !sys
		return;
		#end
		modRoot = path;
		dirty = true;
	}

	public static function clear():Void
	{
		activeMods = [];
		allMods = [];
		modsById = new Map();
		manifestCache = new Map();
		resolveCache = new Map();
		extraRoots = [];
		dirty = true;
	}

	public static function registerExtraRoot(path:String):Void
	{
		#if !sys
		return;
		#end
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

	public static function getAllMods():Array<ModInfo>
	{
		ensure();
		return allMods;
	}

	public static function getMod(id:String):Null<ModInfo>
	{
		ensure();
		return modsById.get(id);
	}

	public static function saveUserConfig(mods:Array<ModInfo>):Void
	{
		ModConfig.init();
		ModConfig.persistFrom(mods);
		dirty = true;
	}

	public static function savePsychModsList(mods:Array<ModInfo>):Void
	{
		#if sys
		var path = Path.normalize('$modRoot/modsList.txt');
		var lines:Array<String> = [];
		for(mod in mods)
		{
			var folder = Path.withoutDirectory(mod.path);
			if(folder == null || folder.trim() == "")
				folder = mod.id;
			lines.push('$folder|${mod.enabled ? "1" : "0"}');
		}
		try {
			sys.io.File.saveContent(path, lines.join("\n"));
		} catch(e) {
			Logs.print('Failed to write modsList.txt: $e', WARNING);
		}
		#end
	}

	public static function refresh():Array<ModInfo>
	{
		dirty = false;
		activeMods = [];
		allMods = [];
		modsById = new Map();
		manifestCache = new Map();
		resolveCache = new Map();
		ModConfig.init();
		buildSharedFolders();

		var preferredOrder:Array<String> = [];
		var psychList:PsychList = null;
		#if sys
		preferredOrder = ModConfig.order.copy();
		psychList = loadPsychList();
		if(psychList != null && psychList.order.length > 0)
			preferredOrder = psychList.order.copy();
		var fileOrder = loadOrderList();
		for(id in fileOrder)
			if(!preferredOrder.contains(id))
				preferredOrder.push(id);

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
				allMods.push(meta);
				modsById.set(meta.id, meta);
			}
		}
		#else
		preferredOrder = ModConfig.order.copy();
		allMods = scanEmbeddedMods();
		for(mod in allMods)
			modsById.set(mod.id, mod);
		#end

		applyUserConfig(allMods, preferredOrder);
		if(psychList != null)
			applyPsychEnable(allMods, psychList.enabled);
		allMods.sort(function(a:ModInfo, b:ModInfo) {
			return sortMods(preferredOrder, a, b);
		});
		for(mod in allMods)
			if(mod.enabled)
				activeMods.push(mod);

		activeMods.sort(function(a:ModInfo, b:ModInfo) {
			return sortMods(preferredOrder, a, b);
		});
		validateMods(activeMods);
		return activeMods;
	}

	public static function resolveAssetPath(key:String, ?library:String):Null<String>
	{
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

		#if sys
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
		ensure();
		var paths:Array<String> = [];
		var modKey = (library != null && library.length > 0) ? '$library/$key' : key;

		for(mod in activeMods)
		{
			var resolved = ModManager.resolve(mod, modKey);
			if(resolved != null)
				paths.push(resolved);
		}
		#if sys
		for(shared in sharedFolders)
		{
			var sharedPath = '$shared/$modKey';
			if(FileSystem.exists(sharedPath))
				paths.push(sharedPath);
		}
		#end
		return paths;
	}

	public static inline function modHasAsset(mod:ModInfo, key:String, ?library:String):Bool
	{
		var modKey = (library != null && library.length > 0) ? '$library/$key' : key;
		return ModManager.resolve(mod, modKey) != null;
	}

	static inline function ensure():Void
	{
		if(dirty)
			refresh();
	}
	#if sys
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
	#else
	static function readManifest(path:String):Dynamic
	{
		if(path == null || path == "" || !Assets.exists(path))
			return null;
		if(manifestCache.exists(path))
			return manifestCache.get(path);
		try {
			var data = TJSON.parse(Assets.getText(path));
			manifestCache.set(path, data);
			return data;
		} catch(e) {
			Logs.print('error reading $path: $e', WARNING);
		}
		return null;
	}
	#end

	#if sys
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
	#else
	static function readMeta(path:String):ModInfo
	{
		return readEmbeddedMeta(path, Path.withoutDirectory(path));
	}
	#end

	#if sys
	static function detectModType(path:String, data:Dynamic, currentType:String, hasPolymod:Bool):String
	{
		var normPath = Path.normalize(path).toLowerCase();
		if(currentType != "generic")
			return currentType;

		if(hasPolymod || Reflect.hasField(data, "api_version"))
			return "v-slice";

		// Psych mods usually ship pack.json; prefer psych resolver when found
		var psychMeta = Path.normalize('$path/pack.json');
		if(FileSystem.exists(psychMeta))
			return "psych";

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
	#else
	static function detectModType(path:String, data:Dynamic, currentType:String, hasPolymod:Bool):String
	{
		if(hasPolymod || Reflect.hasField(data, "api_version"))
			return "v-slice";

		var normPath = Path.normalize(path).toLowerCase();
		var psychMeta = Path.normalize('$path/pack.json');
		if(Assets.exists(psychMeta))
			return "psych";

		if(normPath.indexOf("psychengine") != -1 || normPath.indexOf("psych") != -1)
			return "psych";

		return currentType;
	}
	#end

	#if sys
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
	#else
	static function loadOrderList():Array<String> return [];
	#end

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

	#if sys
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
	#else
	static function buildAssetRoots(path:String, data:Dynamic):Array<String>
	{
		var roots:Array<String> = [];
		var normalized = Path.normalize(path);
		roots.push(normalized);
		roots.push(Path.normalize('$normalized/assets'));
		roots.push(Path.normalize('$normalized/pack'));
		roots.push(Path.normalize('$normalized/pack/assets'));
		if(Reflect.hasField(data, "assetRoots"))
		{
			var custom:Array<Dynamic> = Reflect.field(data, "assetRoots");
			for(root in custom)
			{
				if(root == null) continue;
				var rStr:String = Std.string(root);
				if(rStr.trim() == "") continue;
				roots.push(Path.normalize('$normalized/$rStr'));
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
	#end

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

	static function applyUserConfig(mods:Array<ModInfo>, preferredOrder:Array<String>):Void
	{
		for(mod in mods)
		{
			mod.enabled = ModConfig.isEnabled(mod.id, mod.enabled);
			if(!preferredOrder.contains(mod.id))
				preferredOrder.push(mod.id);
		}
	}

	#if !sys
	static function scanEmbeddedMods():Array<ModInfo>
	{
		var mods:Array<ModInfo> = [];
		var seen:Map<String, Bool> = new Map();
		for(asset in Assets.list())
		{
			if(!asset.startsWith('assets/mods/'))
				continue;

			var parts = asset.split("/");
			if(parts.length < 3) continue;
			var modFolder = parts[2];
			if(seen.exists(modFolder)) continue;
			seen.set(modFolder, true);

			var modBase = Path.normalize('assets/mods/$modFolder');
			mods.push(readEmbeddedMeta(modBase, modFolder));
		}
		return mods;
	}

	static function readEmbeddedMeta(base:String, folder:String):ModInfo
	{
		var metaPath = '$base/mod.json';
		var psychMetaPath = '$base/pack.json';
		var polymodMetaPath = '$base/_polymod_meta.json';

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
			icon = Path.normalize('$base/$icon');

		var enabled = pickAlias(["enabled", "active"], true);
		if(pickAlias(["disabled", "hidden"], false))
			enabled = false;

		var hasPolymod:Bool = polymodMetaPath != null && Assets.exists(polymodMetaPath);
		var modType = detectModType(base, data, pickAlias(["type", "engine", "loader"], hasPolymod ? "v-slice" : "generic"), hasPolymod);

		var assetRoots = buildAssetRoots(base, data);
		var authors = collectStringArray(pickAlias(["authors", "author", "creators", "credits", "contributors"], []));
		var license:Null<String> = pickAlias(["license", "licence"], null);
		var engineVersion:Null<String> = pickAlias(["engineVersion", "targetEngineVersion", "api_version"], null);
		var dependencies = collectStringArray(pickAlias(["dependencies", "depends", "requires"], []));
		var conflicts = collectStringArray(pickAlias(["conflicts", "incompatibilities"], []));

		if(icon == null)
		{
			var altIcons = [
				'$base/pack.png',
				'$base/icon.png',
				'$base/pack/icon.png',
				'$base/_polymod_icon.png'
			];
			for(ic in altIcons)
				if(Assets.exists(ic))
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
			path: Path.normalize(base),
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
	#end

	#if sys
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

		#if android
		var appStorage = Path.normalize(System.applicationStorageDirectory + "/mods");
		if(!roots.contains(appStorage))
			roots.push(appStorage);
		var sdcard = Path.normalize("/storage/emulated/0/SREngine/mods");
		if(!roots.contains(sdcard))
			roots.push(sdcard);
		#end

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
	#else
	static function buildSharedFolders():Void
	{
		sharedFolders = [];
		var base = Path.normalize('$modRoot/shared');
		sharedFolders.push(base);
		sharedFolders.push(Path.normalize('$base/assets'));
	}
	static function getScanRoots():Array<String> return [];
	#end

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

	#if sys
	static function loadPsychList():PsychList
	{
		var path = Path.normalize('$modRoot/modsList.txt');
		if(!FileSystem.exists(path) || FileSystem.isDirectory(path))
			return null;

		var order:Array<String> = [];
		var enabled:Array<String> = [];
		try {
			var lines = File.getContent(path).split("\n");
			for(line in lines)
			{
				var clean = StringTools.trim(line);
				if(clean == "" || clean.startsWith("#"))
					continue;
				var dat = clean.split("|");
				var folder = normalizeId(dat[0]);
				if(folder == null || folder == "") continue;
				order.push(folder);
				var flag = (dat.length > 1 ? dat[1].trim() : "1");
				if(flag == "1")
					enabled.push(folder);
			}
		} catch(e) {
			Logs.print('Failed to read modsList.txt: $e', WARNING);
		}
		return {order: order, enabled: enabled};
	}

	static function applyPsychEnable(mods:Array<ModInfo>, enabled:Array<String>):Void
	{
		if(enabled == null || enabled.length == 0) return;
		var enabledSet:Map<String, Bool> = new Map();
		for(id in enabled)
			enabledSet.set(id, true);
		for(mod in mods)
			mod.enabled = enabledSet.exists(mod.id);
	}
	#end
}
