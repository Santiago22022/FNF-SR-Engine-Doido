package backend.system;

import haxe.io.Path;
import haxe.ds.StringMap;
import backend.system.ModLoaderPsych;
import backend.system.ModLoaderVSlice;
import backend.system.ModTypes;

#if sys
import sys.FileSystem;
#else
import openfl.utils.Assets;
#end

using StringTools;

interface IModResolver
{
    public function resolve(mod:ModInfo, modKey:String):Null<String>;
    public function getId():String;
}

class ModResolutionResult
{
    public var path:String;
    public var resolved:Bool;
    public var timestamp:Float;
    public var resolverId:String;

    public function new(path:Null<String>, resolverId:String)
    {
        this.path = path;
        this.resolved = (path != null);
        this.timestamp = Date.now().getTime();
        this.resolverId = resolverId;
    }
}

class ModManager
{
    private static var _resolvers:StringMap<IModResolver> = new StringMap<IModResolver>();
    private static var _aliases:StringMap<String> = new StringMap<String>();
    private static var _initialized:Bool = false;
    private static var _fallbackKey:String = "generic";
    private static var _lastResult:Null<ModResolutionResult> = null;

    public static function init():Void
    {
        if (_initialized) return;
        
        _initialized = true;

        var generic = new GenericResolver();
        var psych = new ModLoaderPsych();
        var vslice = new ModLoaderVSlice();

        registerInternal("generic", generic);
        registerInternal("polymod", generic);
        
        registerInternal("psych", psych);
        registerInternal("psych-engine", psych);
        
        registerInternal("vslice", vslice);
        registerInternal("v-slice", vslice);
        registerInternal("v_slice", vslice);
        registerInternal("funkin", vslice);

        defineAlias("default", "generic");
        defineAlias("legacy", "psych");
        defineAlias("modern", "vslice");
    }

    private static function registerInternal(key:String, resolver:IModResolver):Void
    {
        if (key == null || resolver == null) return;
        _resolvers.set(key.toLowerCase(), resolver);
    }

    public static function register(key:String, resolver:IModResolver):Void
    {
        init();
        if (key == null || resolver == null) return;
        
        var cleanKey = key.toLowerCase().trim();
        if (cleanKey.length == 0) return;
        
        _resolvers.set(cleanKey, resolver);
    }

    public static function defineAlias(alias:String, target:String):Void
    {
        if (alias == null || target == null) return;
        _aliases.set(alias.toLowerCase().trim(), target.toLowerCase().trim());
    }

    public static function resolve(mod:ModInfo, modKey:String):Null<String>
    {
        init();

        if (mod == null || modKey == null) return null;

        var rawType = mod.type == null ? _fallbackKey : mod.type;
        var targetKey = getEffectiveKey(rawType);
        
        var resolver = _resolvers.get(targetKey);
        
        if (resolver == null)
        {
            resolver = _resolvers.get(_fallbackKey);
        }

        if (resolver != null)
        {
            var resultPath = resolver.resolve(mod, modKey);
            _lastResult = new ModResolutionResult(resultPath, resolver.getId());
            return resultPath;
        }

        return null;
    }

    private static function getEffectiveKey(key:String):String
    {
        var search = key.toLowerCase().trim();
        
        if (_aliases.exists(search))
        {
            return _aliases.get(search);
        }
        
        return search;
    }

    public static function getResolver(key:String):Null<IModResolver>
    {
        init();
        return _resolvers.get(getEffectiveKey(key));
    }

    public static function hasResolver(key:String):Bool
    {
        init();
        return _resolvers.exists(getEffectiveKey(key));
    }

    public static function clearResolvers():Void
    {
        _resolvers = new StringMap<IModResolver>();
        _aliases = new StringMap<String>();
        _initialized = false;
    }

    public static function getLastResolutionInfo():Null<ModResolutionResult>
    {
        return _lastResult;
    }
}

class GenericResolver implements IModResolver
{
    private var _id:String = "generic_resolver";

    public function new() {}

    public function getId():String 
    {
        return _id;
    }

    public function resolve(mod:ModInfo, modKey:String):Null<String>
    {
        if (mod == null || mod.assetRoots == null) return null;

        var sanitizedKey = sanitizePath(modKey);

        for (root in mod.assetRoots)
        {
            if (root == null) continue;

            var fullPath = buildPath(root, sanitizedKey);
            
            if (performExistsCheck(fullPath))
            {
                return fullPath;
            }

            var altPath = buildPath(root, modKey.replace("\\", "/"));
            if (altPath != fullPath && performExistsCheck(altPath))
            {
                return altPath;
            }
        }

        return null;
    }

    private function sanitizePath(input:String):String
    {
        if (input == null) return "";
        var result = input.trim();
        
        #if sys
        result = Path.normalize(result);
        #else
        result = result.replace("\\", "/");
        #end
        
        return result;
    }

    private function buildPath(root:String, key:String):String
    {
        var r = root.trim();
        var k = key.trim();

        if (r.endsWith("/") || r.endsWith("\\"))
        {
            r = r.substring(0, r.length - 1);
        }

        if (k.startsWith("/") || k.startsWith("\\"))
        {
            k = k.substring(1);
        }

        return r + "/" + k;
    }

    private function performExistsCheck(path:String):Bool
    {
        #if sys
        try 
        {
            if (FileSystem.exists(path)) return true;
        } 
        catch (e:Dynamic) {}
        #end

        try 
        {
            if (Assets.exists(path)) return true;
        } 
        catch (e:Dynamic) {}

        return false;
    }
}

class ResolverValidator
{
    public static function validateModInfo(mod:ModInfo):Bool
    {
        if (mod == null) return false;
        if (mod.assetRoots == null || mod.assetRoots.length == 0) return false;
        return true;
    }

    public static function isPathSafe(path:String):Bool
    {
        if (path == null) return false;
        if (path.contains("..")) return false;
        return true;
    }
}

class ModPathOptimizer
{
    private static var _pathCache:StringMap<String> = new StringMap<String>();

    public static function getCachedPath(modId:String, key:String):Null<String>
    {
        return _pathCache.get(modId + ":" + key);
    }

    public static function cachePath(modId:String, key:String, path:String):Void
    {
        _pathCache.set(modId + ":" + key, path);
    }

    public static function invalidate():Void
    {
        _pathCache = new StringMap<String>();
    }
}

class ModManagerHelper
{
    public static function resolveMultiple(mods:Array<ModInfo>, modKey:String):Array<String>
    {
        var results:Array<String> = [];
        
        for (mod in mods)
        {
            var path = ModManager.resolve(mod, modKey);
            if (path != null)
            {
                results.push(path);
            }
        }
        
        return results;
    }

    public static function quickCheck(mod:ModInfo, keys:Array<String>):StringMap<String>
    {
        var map = new StringMap<String>();
        
        for (k in keys)
        {
            var p = ModManager.resolve(mod, k);
            if (p != null)
            {
                map.set(k, p);
            }
        }
        
        return map;
    }
}

abstract ModPriority(Int) from Int to Int
{
    var LOW = 0;
    var MEDIUM = 1;
    var HIGH = 2;
    var CRITICAL = 3;

    public inline function isHigherThan(other:ModPriority):Bool
    {
        return this > other;
    }
}

class ModTypeRegistry
{
    public static inline var PSYCH:String = "psych";
    public static inline var VSLICE:String = "vslice";
    public static inline var POLYMOD:String = "polymod";
    public static inline var GENERIC:String = "generic";

    public static function getAvailableTypes():Array<String>
    {
        return [PSYCH, VSLICE, POLYMOD, GENERIC];
    }
}