package backend.system;

import haxe.io.Path;
import StringTools;
import tjson.TJSON;
import backend.system.ModTypes;
import backend.system.ModConfig;

#if sys
import sys.FileSystem;
import sys.io.File;
#end

/**
 * PSYCH ENGINE MINI MODLOADER (HYBRID)
 * Supports both Doido (Native) and Psych Engine mods.
 * Handles Lua scripts natively.
 */
class ModLoader
{
	#if sys
	public static var modRoot:String = "mods";
	#else
	public static var modRoot:String = "assets/mods";
	#end

	public static var currentModDirectory:String = "";
	public static var globalMods:Array<ModInfo> = [];
	
	// Internal state
	static var activeMods:Array<ModInfo> = [];
	static var allMods:Array<ModInfo> = [];
	static var modsById:Map<String, ModInfo> = new Map();
	static var resolveCache:Map<String, String> = new Map();
	static var dirty:Bool = true;

	public static var ignoredEntries:Array<String> = [
		'characters', 'custom_events', 'custom_notetypes', 'data', 'songs',
		'music', 'sounds', 'shaders', 'videos', 'images', 'stages', 'weeks',
		'fonts', 'scripts', 'achievements', '.git', '.vscode'
	];

	// --- Public API ---

	public static function refresh():Array<ModInfo>
	{
		dirty = false;
		activeMods = [];
		allMods = [];
		globalMods = [];
		currentModDirectory = "";
		modsById = new Map();
		resolveCache = new Map();

		#if sys
		// 1. Ensure mod root exists
		if (!FileSystem.exists(modRoot))
			try { FileSystem.createDirectory(modRoot); } catch(e) {}

		// 2. Read modsList.txt and scan folders
		var list = parseModsList();
		
		// 3. Process each mod
		for (modId in list.all) {
			var modPath = Path.join([modRoot, modId]);
			if (FileSystem.exists(modPath) && FileSystem.isDirectory(modPath)) {
				var meta = readModMetadata(modPath, modId, list.enabled.contains(modId));
				allMods.push(meta);
				modsById.set(modId, meta);
				
				if (meta.enabled) {
					activeMods.push(meta);
					if (meta.runsGlobally)
						globalMods.push(meta);
				}
			}
		}

		// 4. Set Current Mod (Topmost enabled)
		if (activeMods.length > 0)
			currentModDirectory = activeMods[0].id;
		
		#else
		// Basic HTML5/Embedded fallback
		#end
		
		Logs.print('Hybrid Loader: Active=${activeMods.length} Global=${globalMods.length} Top=$currentModDirectory');
		return activeMods;
	}

	public static function getActiveMods():Array<ModInfo>
	{
		if(dirty) refresh();
		return activeMods;
	}

	public static function getAllMods():Array<ModInfo>
	{
		if(dirty) refresh();
		return allMods;
	}

	public static function getMod(id:String):Null<ModInfo>
	{
		if(dirty) refresh();
		return modsById.get(id);
	}
	
	public static function getInvalidMods():Array<ModInfo> return [];

	public static function resolveAssetPath(key:String, ?library:String):Null<String>
	{
		if(dirty) refresh();
		var modKey = (library != null && library.length > 0) ? '$library/$key' : key;
		
		if(resolveCache.exists(modKey))
			return resolveCache.get(modKey);

		var normalized = modKey.replace("\\", "/");
		var stripped = normalized.startsWith("assets/") ? normalized.substr(7) : normalized;

		// 1. Check Top Mod
		if (currentModDirectory.length > 0) {
			var path = checkMod(currentModDirectory, stripped);
			if (path != null) {
				resolveCache.set(modKey, path);
				return path;
			}
		}

		// 2. Check Global Mods
		for (mod in globalMods) {
			if (mod.id == currentModDirectory) continue;
			var path = checkMod(mod.id, stripped);
			if (path != null) {
				resolveCache.set(modKey, path);
				return path;
			}
		}
		
		// 3. Check All Active Mods (Fallback for generic assets)
		// Usually Psych only checks top + global, but hybrid might need full scan?
		// For safety in hybrid mode, let's keep it restricted to top/global for now to avoid conflicts,
		// unless Doido usually scans everything.
		
		return null;
	}

	public static function resolveAllAssetPaths(key:String, ?library:String):Array<String>
	{
		if(dirty) refresh();
		var paths:Array<String> = [];
		var modKey = (library != null && library.length > 0) ? '$library/$key' : key;
		var normalized = modKey.replace("\\", "/");
		var stripped = normalized.startsWith("assets/") ? normalized.substr(7) : normalized;

		for (mod in activeMods) {
			var path = checkMod(mod.id, stripped);
			if (path != null) paths.push(path);
		}
		return paths;
	}
	
	public static function loadTextFileList(key:String):Array<String>
	{
		var paths = resolveAllAssetPaths(key);
		var merged:Array<String> = [];
		var seen:Map<String, Bool> = new Map();
		
		for (path in paths) {
			var content = getTextContent(path);
			if (content != null) {
				for (line in content.split('\n')) {
					var clean = line.trim();
					if (clean.length > 0 && !clean.startsWith("#") && !seen.exists(clean)) {
						seen.set(clean, true);
						merged.push(clean);
					}
				}
			}
		}
		return merged;
	}

	// --- LUA / NATIVE SCRIPTING SUPPORT ---

	public static function getGlobalScripts():Array<String>
	{
		var scripts:Array<String> = [];
		#if sys
		if(dirty) refresh();
		
		var sourceList = activeMods.copy();
		sourceList.reverse(); 
		
		for (mod in sourceList) {
			for (root in mod.assetRoots) {
				var scriptDir = Path.join([root, "scripts"]);
				if (FileSystem.exists(scriptDir) && FileSystem.isDirectory(scriptDir)) {
					for (file in FileSystem.readDirectory(scriptDir)) {
						if (file.endsWith(".lua")) {
							var fullPath = Path.normalize(Path.join([scriptDir, file]));
							scripts.push(fullPath);
						}
					}
				}
			}
		}
		#end
		return scripts;
	}

	public static function getSongScripts(song:String):Array<String>
	{
		var scripts:Array<String> = [];
		#if sys
		if(dirty) refresh();
		
		var songLower = song.toLowerCase();
		
		for (mod in activeMods) {
			for (root in mod.assetRoots) {
				// Check data/songName
				var dataDir = Path.join([root, "data", songLower]);
				if (FileSystem.exists(dataDir) && FileSystem.isDirectory(dataDir)) {
					for (file in FileSystem.readDirectory(dataDir)) {
						if (file.endsWith(".lua")) {
							var fullPath = Path.normalize(Path.join([dataDir, file]));
							if(!scripts.contains(fullPath)) scripts.push(fullPath);
						}
					}
				}
			}
		}
		#end
		return scripts;
	}

	public static function getCustomEventScript(eventName:String):Null<String>
	{
		#if sys
		return resolveAssetPath('custom_events/$eventName.lua');
		#else
		return null;
		#end
	}

	public static function setEnabledIds(enabled:Array<String>):Void
	{
		#if sys
		var list = parseModsList();
		var newContent = "";
		for (mod in list.all) {
			var isEnabled = enabled.contains(mod);
			newContent += mod + "|" + (isEnabled ? "1" : "0") + "\n";
		}
		File.saveContent(Path.join([modRoot, "modsList.txt"]), newContent);
		dirty = true;
		#end
	}

	// --- Internal Helpers ---

	static function checkMod(modId:String, file:String):Null<String>
	{
		#if sys
		var path = Path.normalize(Path.join([modRoot, modId, file]));
		if (FileSystem.exists(path)) return path;
		#end
		return null;
	}

	static function getTextContent(path:String):String
	{
		#if sys
		try { return File.getContent(path); } catch(e) {}
		#end
		return null;
	}

	#if sys
	static function parseModsList():{enabled:Array<String>, all:Array<String>}
	{
		var list = {enabled: [], all: []};
		var listPath = Path.join([modRoot, "modsList.txt"]);
		
		var folders:Array<String> = [];
		if (FileSystem.exists(modRoot)) {
			for (entry in FileSystem.readDirectory(modRoot)) {
				if (!ignoredEntries.contains(entry.toLowerCase()) && FileSystem.isDirectory(Path.join([modRoot, entry]))) {
					folders.push(entry);
				}
			}
		}

		var existingMods:Map<String, Bool> = new Map();

		if (FileSystem.exists(listPath)) {
			var content = File.getContent(listPath);
			for (line in content.split("\n")) {
				var parts = line.trim().split("|");
				if (parts.length < 1 || parts[0].length == 0) continue;
				
				var id = parts[0];
				if (folders.contains(id)) {
					list.all.push(id);
					existingMods.set(id, true);
					if (parts.length > 1 && parts[1] == "1")
						list.enabled.push(id);
				}
			}
		}

		// Add new folders not in list
		var changed = false;
		for (folder in folders) {
			if (!existingMods.exists(folder)) {
				list.all.push(folder);
				list.enabled.push(folder); 
				changed = true;
			}
		}
		
		if (changed) {
			var out = "";
			for (mod in list.all)
				out += mod + "|" + (list.enabled.contains(mod) ? "1" : "0") + "\n";
			File.saveContent(listPath, out);
		}
		
		return list;
	}

	static function readModMetadata(path:String, id:String, enabled:Bool):ModInfo
	{
		// 1. Check for Doido native (mod.json)
		var doidoMetaPath = Path.join([path, "mod.json"]);
		if (FileSystem.exists(doidoMetaPath)) {
			try {
				var content = File.getContent(doidoMetaPath);
				var data:Dynamic = TJSON.parse(content);
				
				return {
					id: id,
					name: Reflect.hasField(data, "name") ? data.name : id,
					description: Reflect.hasField(data, "description") ? data.description : "",
					version: Reflect.hasField(data, "version") ? data.version : "1.0",
					priority: 0,
					enabled: enabled,
					path: path,
					type: "doido", // Native support
					icon: Path.join([path, "icon.png"]),
					assetRoots: [path],
					authors: [],
					license: "",
					engineVersion: "",
					dependencies: [],
					conflicts: [],
				runsGlobally: Reflect.hasField(data, "runsGlobally") ? data.runsGlobally : false,
				restartRequired: false,
					invalid: false,
					invalidReason: null
				};
			} catch(e) {
				Logs.print('Error parsing mod.json for $id: $e', WARNING);
			}
		}

		// 2. Check for Psych Engine (pack.json)
		var psychMetaPath = Path.join([path, "pack.json"]);
		var data:Dynamic = {};
		if (FileSystem.exists(psychMetaPath)) {
			try { data = TJSON.parse(File.getContent(psychMetaPath)); } catch(e) {}
		}

		return {
			id: id,
			name: Reflect.hasField(data, "name") ? data.name : id,
			description: Reflect.hasField(data, "description") ? data.description : "",
			version: "1.0",
			priority: 0,
			enabled: enabled,
			path: path,
			type: "psych",
			icon: Path.join([path, "pack.png"]),
			assetRoots: [path], // Simple root
			authors: [],
			license: "",
			engineVersion: "",
			dependencies: [],
			conflicts: [],
			runsGlobally: Reflect.hasField(data, "runsGlobally") ? data.runsGlobally : false,
			restartRequired: Reflect.hasField(data, "restart") ? data.restart : false,
			invalid: false,
			invalidReason: null
		};
	}
	#end
	
	// Stubs for compatibility
	public static function setOrder(order:Array<String>) {}
	public static function setOrderAndEnabled(order:Array<String>, enabled:Array<String>) {}
	public static function saveUserConfig(mods:Array<ModInfo>) {}
	public static function setRoot(path:String) {}
	public static function clear() {}
	public static function registerExtraRoot(path:String) {}
	public static function modHasAsset(mod:ModInfo, key:String, ?library:String):Bool return false;
}
