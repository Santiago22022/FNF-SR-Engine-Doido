package backend.system;

import haxe.Json;
import haxe.io.Path;
import openfl.utils.Assets;
import tjson.TJSON;
import backend.system.ModTypes; // Asegúrate de que este typedef exista

#if sys
import sys.FileSystem;
import sys.io.File;
#end

using StringTools;

/**
 * Mod Loading System
 * Handles the loading, ordering, and metadata parsing of mods.
 * Supports both Psych Engine (pack.json) and Doido/Base (mod.json) formats.
 */
class ModLoader
{
    // --- CONSTANTS & CONFIG ---
    #if sys
    public static var modRoot:String = "mods";
    #else
    public static var modRoot:String = "assets/mods";
    #end
    
    // Carpetas que NO son mods
    public static final ignoreModFolders:Array<String> = [
        'characters', 'custom_events', 'custom_notetypes', 'data',
        'songs', 'music', 'sounds', 'shaders', 'videos',
        'images', 'stages', 'weeks', 'fonts', 'scripts', 'achievements'
    ];

    // --- STATE ---
    static var activeMods:Array<ModInfo> = [];
    static var allMods:Array<ModInfo> = [];
    
    // Acceso público para integraciones externas
    public static var globalMods:Array<ModInfo> = [];
    
    static var modsById:Map<String, ModInfo> = new Map();
    static var resolveCache:Map<String, String> = new Map();
    static var dirty:Bool = true;
    
    public static var currentModDirectory:String = '';

    // --- PUBLIC API ---

    public static function refresh():Array<ModInfo>
    {
        dirty = false;
        resolveCache.clear();
        activeMods = [];
        globalMods = []; 
        allMods = [];
        modsById.clear();
        currentModDirectory = "";

        #if sys
        // 1. Asegurar que la carpeta mods existe
        if (!FileSystem.exists(modRoot)) {
            try { FileSystem.createDirectory(modRoot); } catch(e:Dynamic) { trace('Error creating mods folder: $e'); }
        }

        // 2. Parsear modsList.txt y escanear directorio real
        updateModList(); 

        // 3. Construir objetos ModInfo
        var list = parseList();
        
        // Cargar metadata de TODOS los mods encontrados
        for (modId in list.all) {
            var modPath = Path.join([modRoot, modId]);
            if (FileSystem.exists(modPath) && FileSystem.isDirectory(modPath)) {
                var meta = parseModInfo(modId, modPath, list.enabled.contains(modId));
                allMods.push(meta);
                modsById.set(modId, meta);
            }
        }

        // Construir Stack Activo basado en el orden de 'modsList.txt'
        for (modId in list.enabled) {
            var mod = modsById.get(modId);
            if (mod != null && !mod.invalid) {
                activeMods.push(mod);
                if (mod.runsGlobally) globalMods.push(mod);
            }
        }

        if (activeMods.length > 0)
            currentModDirectory = activeMods[0].id;
        
        trace('[ModLoader] Refreshed: Active=${activeMods.length}, Total=${allMods.length}');
        #end
        
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
    
    public static function getInvalidMods():Array<ModInfo>
    {
        if(dirty) refresh();
        return allMods.filter(function(m) return m.invalid);
    }

    // --- ASSET RESOLUTION ---

    public static function resolveAssetPath(key:String, ?library:String):Null<String>
    {
        if(dirty) refresh();
        
        var modKey = (library != null && library.length > 0) ? '$library/$key' : key;
        
        // Retornar de caché si existe
        if(resolveCache.exists(modKey))
            return resolveCache.get(modKey);

        var normalized = modKey.replace("\\", "/");
        // Remover prefijo 'assets/' para chequear dentro de la raíz del mod
        var stripped = normalized.startsWith('assets/') ? normalized.substr(7) : normalized;

        for (mod in activeMods) {
            // 1. Chequear Raíz (mods/MyMod/images/bf.png)
            var path = checkFile(mod.path, stripped);
            if (path != null) {
                resolveCache.set(modKey, path);
                return path;
            }
            
            // 2. Chequear Subcarpeta Assets (mods/MyMod/assets/images/bf.png)
            var pathAlt = checkFile(mod.path, 'assets/$stripped');
            if (pathAlt != null) {
                resolveCache.set(modKey, pathAlt);
                return pathAlt;
            }
        }
        
        // Debugging específico (mantenido de tu código pero más limpio)
        #if debug
        if(key.indexOf("bfairship") != -1 || key.indexOf("grey") != -1) {
            trace('ModLoader DEBUG: Could not find $key');
        }
        #end
        
        return null;
    }
    
    /**
     * Finds and merges contents of text files from all active mods (additive loading).
     * Useful for things like introText.txt or credits.txt.
     */
    public static function loadTextFileList(key:String):Array<String>
    {
        var paths = resolveAllAssetPaths(key);
        var merged:Array<String> = [];
        var seen:Map<String, Bool> = new Map();
        
        for (path in paths) {
            #if sys
            try {
                var content = File.getContent(path);
                for (line in content.split('\n')) {
                    var clean = line.trim();
                    // Ignorar comentarios (#) y líneas vacías
                    if (clean.length > 0 && !clean.startsWith("#") && !seen.exists(clean)) {
                        seen.set(clean, true);
                        merged.push(clean);
                    }
                }
            } catch(e:Dynamic) {
                trace('Error reading text list $path: $e');
            }
            #end
        }
        return merged;
    }
    
    /**
     * Returns ALL paths for a specific asset key across all active mods.
     */
    public static function resolveAllAssetPaths(key:String, ?library:String):Array<String>
    {
        if(dirty) refresh();
        var paths:Array<String> = [];
        var modKey = (library != null && library.length > 0) ? '$library/$key' : key;
        var normalized = modKey.replace("\\", "/");
        var stripped = normalized.startsWith("assets/") ? normalized.substr(7) : normalized;

        for (mod in activeMods) {
            var path = checkFile(mod.path, stripped);
            if (path != null) paths.push(path);
            
            var pathAlt = checkFile(mod.path, 'assets/$stripped');
            if (pathAlt != null) paths.push(pathAlt);
        }
        return paths;
    }

    // --- SCRIPTING ---

    public static function getGlobalScripts():Array<String>
    {
        var scripts:Array<String> = [];
        #if sys
        if(dirty) refresh();
        
        for (mod in activeMods) {
            scanScripts(Path.join([mod.path, "scripts"]), scripts);
            scanScripts(Path.join([mod.path, "data", "scripts"]), scripts);
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
        var songSpace = songLower.replace("-", " ");
        
        for (mod in activeMods) {
            // Formato Psych Estándar
            scanScripts(Path.join([mod.path, "data", songLower]), scripts);
            if(songLower != songSpace)
                scanScripts(Path.join([mod.path, "data", songSpace]), scripts);
            
            // Formato Doido/Legacy (carpeta songs/)
            scanScripts(Path.join([mod.path, "songs", songLower]), scripts);
        }
        #end
        return scripts;
    }

    static function scanScripts(dir:String, list:Array<String>) {
        #if sys
        if (FileSystem.exists(dir) && FileSystem.isDirectory(dir)) {
            try {
                for (file in FileSystem.readDirectory(dir)) {
                    var lowerFile = file.toLowerCase();
                    if (lowerFile.endsWith(".lua") || lowerFile.endsWith(".hx")) {
                        var fullPath = Path.normalize(Path.join([dir, file]));
                        if(!list.contains(fullPath)) list.push(fullPath); 
                    }
                }
            } catch(e:Dynamic) {
                trace('Error scanning scripts in $dir: $e');
            }
        }
        #end
    }

    // --- MANAGEMENT ---

    public static function setEnabledIds(enabled:Array<String>):Void
    {
        #if sys
        var list = parseList();
        var newContent = "";
        
        // Reescribir lista manteniendo orden de 'all' pero actualizando estado
        for (mod in list.all) {
            var isEnabled = enabled.contains(mod);
            newContent += mod + "|" + (isEnabled ? "1" : "0") + "\n";
        }
        try {
            File.saveContent(Path.join([modRoot, "modsList.txt"]), newContent);
            dirty = true;
        } catch(e:Dynamic) {
            trace('Error saving modsList.txt: $e');
        }
        #end
    }
    
    // Stubs para compatibilidad UI
    public static function setOrder(order:Array<String>):Void {} 
    public static function setOrderAndEnabled(order:Array<String>, enabled:Array<String>):Void {} 

    // --- INTERNAL UTILS ---

    static function checkFile(modPath:String, file:String):Null<String>
    {
        #if sys
        try {
            var path = Path.join([modPath, file]);
            if (FileSystem.exists(path) && !FileSystem.isDirectory(path)) // Asegurar que es archivo
                return Path.normalize(path);
        } catch(e:Dynamic) {}
        #end
        return null;
    }

    static function parseModInfo(id:String, path:String, enabled:Bool):ModInfo
    {
        var meta:ModInfo = {
            id: id,
            name: id,
            description: "No description provided.",
            version: "1.0",
            priority: 0,
            enabled: enabled,
            path: path,
            type: "psych", // Default
            icon: null,
            assetRoots: [path],
            authors: [],
            license: "",
            engineVersion: "",
            dependencies: [],
            conflicts: [],
            runsGlobally: false,
            restartRequired: false,
            invalid: false,
            invalidReason: null
        };

        // 1. Try Psych Engine (pack.json)
        var psychPath = Path.join([path, "pack.json"]);
        var jsonLoaded = false;
        
        #if sys
        if (FileSystem.exists(psychPath)) {
            try {
                var content = File.getContent(psychPath);
                if(content.length > 0) {
                    var raw:Dynamic = TJSON.parse(content);
                    // Mapeo seguro de campos
                    if(Reflect.hasField(raw, "name")) meta.name = raw.name;
                    if(Reflect.hasField(raw, "description")) meta.description = raw.description;
                    if(Reflect.hasField(raw, "restart")) meta.restartRequired = raw.restart;
                    if(Reflect.hasField(raw, "runsGlobally")) meta.runsGlobally = raw.runsGlobally;
                    if(Reflect.hasField(raw, "version")) meta.version = raw.version;
                    if(Reflect.hasField(raw, "dependencies")) meta.dependencies = raw.dependencies;
                    // Color is often in pack.json too, but ignored here for simplicity
                    jsonLoaded = true;
                }
            } catch(e:Dynamic) {
                trace('Error parsing pack.json for $id: $e');
            }
        }
        #end

        // 2. Try Doido/Base (mod.json) if pack.json failed or doesn't exist
        if (!jsonLoaded) {
            var doidoPath = Path.join([path, "mod.json"]);
            #if sys
            if (FileSystem.exists(doidoPath)) {
                try {
                    var content = File.getContent(doidoPath);
                    var raw:Dynamic = TJSON.parse(content);
                    meta.type = "doido";
                    if(Reflect.hasField(raw, "name")) meta.name = raw.name;
                    if(Reflect.hasField(raw, "description")) meta.description = raw.description;
                    if(Reflect.hasField(raw, "version")) meta.version = raw.version;
                } catch(e:Dynamic) {}
            }
            #end
        }

        // Icon Logic
        var iconPath = Path.join([path, "icon.png"]);
        #if sys
        if (FileSystem.exists(iconPath)) meta.icon = iconPath;
        else {
            var packIcon = Path.join([path, "pack.png"]); // Psych Backup
            if (FileSystem.exists(packIcon)) meta.icon = packIcon;
        }
        #end

        return meta;
    }

    // --- LOW LEVEL IO ---

    static function parseList():{enabled:Array<String>, disabled:Array<String>, all:Array<String>} {
        var list = {enabled: [], disabled: [], all: []};
        #if sys
        try {
            var content = coolTextFile(Path.join([modRoot, 'modsList.txt']));
            for (mod in content)
            {
                if(mod.trim().length < 1) continue;
                var dat = mod.split("|");
                var name = dat[0];
                list.all.push(name);
                if (dat[1] == "1") list.enabled.push(name);
                else list.disabled.push(name);
            }
        } catch(e:Dynamic) {}
        #end
        return list;
    }
    
    /**
     * Scans the mods directory and updates modsList.txt with new finds.
     */
    static function updateModList()
    {
        #if sys
        var list:Array<Array<Dynamic>> = [];
        var added:Array<String> = [];
        
        // 1. Leer archivo existente
        try {
            var content = coolTextFile(Path.join([modRoot, 'modsList.txt']));
            for (mod in content) {
                var dat:Array<String> = mod.split("|");
                var folder:String = dat[0];
                var modDir = Path.join([modRoot, folder]);
                
                // Verificar que el mod aun existe
                if(folder.trim().length > 0 && FileSystem.exists(modDir) && FileSystem.isDirectory(modDir) && !added.contains(folder))
                {
                    added.push(folder);
                    list.push([folder, (dat[1] == "1")]);
                }
            }
        } catch(e:Dynamic) {}
        
        // 2. Escanear carpetas nuevas (no en lista)
        if(FileSystem.exists(modRoot)) {
            try {
                for (folder in FileSystem.readDirectory(modRoot)) {
                    var modDir = Path.join([modRoot, folder]);
                    if(folder.trim().length > 0 && FileSystem.isDirectory(modDir) &&
                    !ignoreModFolders.contains(folder.toLowerCase()) && !folder.startsWith(".") && !added.contains(folder)) {
                        added.push(folder);
                        list.push([folder, true]); // Enable new mods by default
                        trace('Found new mod: $folder');
                    }
                }
            } catch(e:Dynamic) {
                trace('Error reading mod directory: $e');
            }
        }

        // 3. Guardar Lista
        var fileStr:String = '';
        for (values in list) {
            if(fileStr.length > 0) fileStr += '\n';
            fileStr += values[0] + '|' + (values[1] ? '1' : '0');
        }

        try {
            File.saveContent(Path.join([modRoot, 'modsList.txt']), fileStr);
        } catch(e:Dynamic) {
            trace('Could not save modsList.txt: $e');
        }
        #end
    }

    static function coolTextFile(path:String):Array<String>
    {
        var daList:Array<String> = [];
        #if sys
        if(FileSystem.exists(path)) {
            try {
                var content = File.getContent(path);
                daList = content.trim().split('\n');
                for (i in 0...daList.length) daList[i] = daList[i].trim();
            } catch(e:Dynamic) {}
        }
        #end
        return daList;
    }
}