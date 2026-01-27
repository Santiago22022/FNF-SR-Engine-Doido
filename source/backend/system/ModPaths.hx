package backend.system;

import haxe.io.Path;
import StringTools;
import openfl.utils.Assets;
import backend.system.ModBackend;
import backend.system.ModLoader;
#if sys
import sys.FileSystem;
import sys.io.File;
#end

/**
 * Virtual File System that resolves assets through active mods before
 * falling back to base assets.
 * * POWERED UP VERSION: Includes caching, garbage filtering, and global search.
 */
class ModPaths
{
    // ========================================================================
    // CACHE & CONFIG
    // ========================================================================
    
    // Archivos que el sistema debe ignorar siempre
    public static var ignoreFiles:Array<String> = [
        '.DS_Store', 
        'thumbs.db', 
        'desktop.ini',
        '.git',
        '.gitignore'
    ];

    // Cache simple para evitar llamadas excesivas a FileSystem.exists
    private static var _existenceCache:Map<String, Bool> = new Map();

    public static function clearCache():Void
    {
        _existenceCache.clear();
    }

    // ========================================================================
    // CORE RESOLUTION
    // ========================================================================

    public static function resolveAssetPath(key:String, ?library:String):Null<String>
    {
        // Wrapper for ModLoader, but allows us to intercept logging if needed
        return ModLoader.resolveAssetPath(key, library);
    }

    public static function resolveWithExtensions(base:String, ?library:String, exts:Array<String>):Null<String>
    {
        if(exts == null || exts.length == 0) return resolveAssetPath(base, library);

        // Optimization: Deduplicate extensions only once
        var extsToCheck:Array<String> = [];
        for(ext in exts) {
            if(ext == null) continue;
            extsToCheck.push(ext);
            var upper = ext.toUpperCase();
            if(ext != upper && !exts.contains(upper)) extsToCheck.push(upper);
        }

        for(ext in extsToCheck)
        {
            var testPath = '$base$ext';
            // Check cache first if implemented inside resolveAssetPath, otherwise check explicitly
            var res = resolveAssetPath(testPath, library);
            if(res != null) return res;
        }
        return null;
    }

    public static function exists(key:String, ?library:String):Bool
    {
        var cacheKey = '$library:$key';
        if (_existenceCache.exists(cacheKey)) 
            return _existenceCache.get(cacheKey);

        var exists = false;
        var resolved = resolveAssetPath(key, library);
        
        if(resolved != null && ModBackend.exists(resolved))
            exists = true;
        else 
        {
            var basePath = resolveBasePath(key, library);
            if(ModBackend.exists(basePath)) 
                exists = true;
            else
            {
                var doidoPath = (library == null) ? 'assets/Doido/$key' : 'assets/Doido/$library/$key';
                exists = ModBackend.exists(doidoPath);
            }
        }

        _existenceCache.set(cacheKey, exists);
        return exists;
    }

    // ========================================================================
    // READ & WRITE
    // ========================================================================

    public static function readText(key:String, ?library:String):String
    {
        var resolved = resolveAssetPath(key, library);
        if(resolved != null && ModBackend.exists(resolved))
            return ModBackend.readText(resolved);
        return ModBackend.readText(resolveBasePath(key, library));
    }

    public static function readBytes(key:String, ?library:String):haxe.io.Bytes
    {
        var resolved = resolveAssetPath(key, library);
        if(resolved != null && ModBackend.exists(resolved))
            return ModBackend.readBytes(resolved);
        return ModBackend.readBytes(resolveBasePath(key, library));
    }

    // ========================================================================
    // DIRECTORY & LISTING TOOLS
    // ========================================================================

    /**
     * Finds ALL instances of a file across ALL active mods.
     * Useful for "Additive" content (e.g., getting credits.json from all mods to merge them).
     */
    public static function getAllFiles(key:String, ?library:String):Array<String>
    {
        var paths:Array<String> = [];
        
        // 1. Check Mods
        for(mod in ModLoader.getActiveMods()) {
            var modKey = Path.join([ModLoader.modRoot, mod.id, "assets", key]); // Try standard assets
            if (ModBackend.exists(modKey)) paths.push(modKey);
            else {
                // Try root
                modKey = Path.join([ModLoader.modRoot, mod.id, key]);
                if (ModBackend.exists(modKey)) paths.push(modKey);
            }
        }
        
        // 2. Check Base Game
        var basePath = resolveBasePath(key, library);
        if(ModBackend.exists(basePath)) paths.push(basePath);

        var doidoPath = (library == null) ? 'assets/Doido/$key' : 'assets/Doido/$library/$key';
        if(ModBackend.exists(doidoPath)) paths.push(doidoPath);

        return paths;
    }

    /**
     * Lists directories only (not files).
     */
    public static function getDirectories(dir:String, ?library:String):Array<String>
    {
        // This reuses listDir logic but forces filtering for folders
        #if sys
        var rawList = listDir(dir, library, null, false);
        var folders:Array<String> = [];
        
        // We need to verify if the result is a directory, listDir returns files mostly
        // So we do a manual custom scan here for folders
        for(mod in ModLoader.getActiveMods())
        {
            var rootsToCheck = mod.assetRoots.copy();
            rootsToCheck.push(Path.join([ModLoader.modRoot, mod.id, "assets"]));

            for(root in rootsToCheck) {
                var target = Path.normalize('$root/$dir');
                if(FileSystem.exists(target) && FileSystem.isDirectory(target)) {
                    for(entry in FileSystem.readDirectory(target)) {
                        if(FileSystem.isDirectory('$target/$entry') && !folders.contains(entry)) {
                            folders.push(entry);
                        }
                    }
                }
            }
        }
        // Check base
        var baseRoot = resolveBasePath(dir, library);
        if(FileSystem.exists(baseRoot) && FileSystem.isDirectory(baseRoot)) {
            for(entry in FileSystem.readDirectory(baseRoot)) {
                if(FileSystem.isDirectory('$baseRoot/$entry') && !folders.contains(entry)) {
                    folders.push(entry);
                }
            }
        }
        return folders;
        #else
        return []; // Folder listing on web is not reliably supported via standard Assets
        #end
    }

    public static function listDir(dir:String, ?library:String, extensions:Array<String> = null, recursive:Bool = false):Array<String>
    {
        var output:Array<String> = [];
        var seen:Map<String, Bool> = new Map();

        function addItem(item:String)
        {
            // Check junk files
            var fileName = Path.withoutDirectory(item);
            if (ignoreFiles.contains(fileName)) return;

            if(!seen.exists(item)) {
                seen.set(item, true);
                output.push(item);
            }
        }

        // 1. Scan Active Mods
        for(mod in ModLoader.getActiveMods())
        {
            var rootsToCheck = mod.assetRoots.copy();
            // Ensure we check the standard "assets" folder inside the mod too
            rootsToCheck.push(Path.join([ModLoader.modRoot, mod.id, "assets"]));

            for(root in rootsToCheck)
            {
                #if sys
                var baseRoot = Path.normalize('$root/$dir');
                scanFileSystem(baseRoot, extensions, recursive, addItem);
                #else
                scanOpenFLAssets('$root/$dir', extensions, recursive, addItem);
                #end
            }
        }

        // 2. Scan Base Game
        var resolvedBase = resolveBasePath(dir, library);
        var resolvedDoido = (library == null) ? 'assets/Doido/$dir' : 'assets/Doido/$library/$dir';

        #if sys
        scanFileSystem(resolvedBase, extensions, recursive, addItem);
        scanFileSystem(resolvedDoido, extensions, recursive, addItem);
        #else
        scanOpenFLAssets(resolvedBase, extensions, recursive, addItem);
        scanOpenFLAssets(resolvedDoido, extensions, recursive, addItem);
        #end

        return output;
    }

    public static function listDirRelative(dir:String, ?library:String, extensions:Array<String> = null, recursive:Bool = false):Array<String>
    {
        var output:Array<String> = [];
        var seen:Map<String, Bool> = new Map(); // Avoid duplicates across mods

        function addItem(relPath:String) {
             var fileName = Path.withoutDirectory(relPath);
             if (ignoreFiles.contains(fileName)) return;

             if(!seen.exists(relPath)) {
                 seen.set(relPath, true);
                 output.push(relPath);
             }
        }
        
        // 1. Scan Active Mods
        for(mod in ModLoader.getActiveMods())
        {
            var rootsToCheck = mod.assetRoots.copy();
            rootsToCheck.push(Path.join([ModLoader.modRoot, mod.id, "assets"]));

            for(root in rootsToCheck)
            {
                #if sys
                var absRoot = Path.normalize('$root/$dir');
                scanFileSystem(absRoot, extensions, recursive, addItem);
                #else
                scanOpenFLAssets('$root/$dir', extensions, recursive, addItem);
                #end
            }
        }

        // 2. Base & Doido
        var basePath = resolveBasePath(dir, library);
        var doidoPath = (library == null) ? 'assets/Doido/$dir' : 'assets/Doido/$library/$dir';

        #if sys
        scanFileSystem(basePath, extensions, recursive, addItem);
        scanFileSystem(doidoPath, extensions, recursive, addItem);
        #else
        scanOpenFLAssets(basePath, extensions, recursive, addItem);
        scanOpenFLAssets(doidoPath, extensions, recursive, addItem);
        #end

        return output;
    }

    // ========================================================================
    // INTERNAL HELPERS
    // ========================================================================

    #if sys
    static function scanFileSystem(path:String, extensions:Array<String>, recursive:Bool, onFound:String->Void)
    {
        var normPath = Path.normalize(path);
        if(!FileSystem.exists(normPath) || !FileSystem.isDirectory(normPath)) return;

        var stack:Array<String> = [normPath];
        while(stack.length > 0)
        {
            var current = stack.pop();
            var dirContents = [];
            try { dirContents = FileSystem.readDirectory(current); } catch(e:Dynamic) { continue; }

            for(file in dirContents)
            {
                var fullPath = Path.normalize('$current/$file');
                if(FileSystem.isDirectory(fullPath))
                {
                    if(recursive) stack.push(fullPath);
                    continue;
                }
                if(matchesExt(fullPath, extensions))
                {
                    // Calculate relative path
                    var rel = fullPath.substr(normPath.length);
                    if(rel.startsWith("/") || rel.startsWith("\\")) rel = rel.substr(1);
                    onFound(rel);
                }
            }
        }
    }
    #else
    static function scanOpenFLAssets(prefix:String, extensions:Array<String>, recursive:Bool, onFound:String->Void)
    {
        var normPrefix = normalizeAssetPath(prefix);
        for(asset in Assets.list())
        {
            if(!asset.startsWith(normPrefix)) continue;
            
            var rest = asset.substr(normPrefix.length);
            if(rest.startsWith("/")) rest = rest.substr(1);
            
            if(!recursive && rest.indexOf("/") != -1) continue;

            if(matchesExt(asset, extensions))
            {
                var trimmed = asset.startsWith('assets/') ? asset.substr('assets/'.length) : asset;
                onFound(Path.withoutDirectory(trimmed));
            }
        }
    }
    #end

    static function matchesExt(path:String, extensions:Array<String>):Bool
    {
        if(extensions == null || extensions.length == 0) return true;
        
        var pathLower = path.toLowerCase();
        for(ext in extensions)
            if(pathLower.endsWith(ext.toLowerCase())) return true;
            
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
            if(folder.startsWith("_")) truFolder = folder.substr(1);
            loopCount++;
            key += truFolder + (loopCount == pathArray.length ? "" : "/");
        }

        if(library != null)
            library = (library.startsWith("_") ? library.split("_")[1] : library);
        #end
        
        if(library == null) return 'assets/$key';
        return 'assets/$library/$key';
    }

    static inline function normalizeAssetPath(path:String):String
    {
        #if sys
        return StringTools.replace(path, "\\", "/");
        #else
        return path;
        #end
    }
}