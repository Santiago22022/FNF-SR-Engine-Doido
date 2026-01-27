package backend.system;

import haxe.io.Path;
import haxe.io.Bytes;
import openfl.utils.Assets;

#if sys
import sys.FileSystem;
import sys.io.File;
import sys.FileStat;
#end

using StringTools;

typedef ModStat = {
    var mtimeMs:Float;
    var size:Int;
}

class PathUtils {
    public static inline function normalizePath(path:String):String {
        if (path == null) return "";
        var formatted = path.replace("\\", "/");
        #if sys
        return Path.normalize(formatted);
        #else
        return formatted;
        #end
    }

    public static inline function forceForwardSlashes(path:String):String {
        if (path == null) return "";
        return path.replace("\\", "/");
    }

    public static function combine(base:String, segment:String):String {
        var cleanBase = normalizePath(base);
        var cleanSegment = normalizePath(segment);
        
        if (!cleanBase.endsWith("/")) cleanBase += "/";
        if (cleanSegment.startsWith("/")) cleanSegment = cleanSegment.substring(1);
        
        return normalizePath(cleanBase + cleanSegment);
    }
}

class ModBackend {
    public static function exists(path:String):Bool {
        var normal = PathUtils.normalizePath(path);
        
        #if sys
        if (FileSystem.exists(normal)) return true;
        #end

        if (Assets.exists(normal)) return true;
        
        var alt = PathUtils.forceForwardSlashes(path);
        if (alt != normal && Assets.exists(alt)) return true;

        return false;
    }

    public static function isDirectory(path:String):Bool {
        var normal = PathUtils.normalizePath(path);
        
        #if sys
        if (FileSystem.exists(normal) && FileSystem.isDirectory(normal)) return true;
        #end

        var prefix = normal.endsWith("/") ? normal : normal + "/";
        for (asset in Assets.list()) {
            if (asset.startsWith(prefix)) return true;
        }

        return false;
    }

    public static function readText(path:String):String {
        var normal = PathUtils.normalizePath(path);

        #if sys
        if (FileSystem.exists(normal) && !FileSystem.isDirectory(normal)) {
            try {
                return File.getContent(normal);
            } catch (e:Dynamic) {
                return null;
            }
        }
        #end

        if (Assets.exists(normal)) return Assets.getText(normal);

        var alt = PathUtils.forceForwardSlashes(path);
        if (Assets.exists(alt)) return Assets.getText(alt);

        return null;
    }

    public static function readBytes(path:String):Bytes {
        var normal = PathUtils.normalizePath(path);

        #if sys
        if (FileSystem.exists(normal) && !FileSystem.isDirectory(normal)) {
            try {
                return File.getBytes(normal);
            } catch (e:Dynamic) {
                return null;
            }
        }
        #end

        if (Assets.exists(normal)) return Assets.getBytes(normal);

        var alt = PathUtils.forceForwardSlashes(path);
        if (Assets.exists(alt)) return Assets.getBytes(alt);

        return null;
    }

    public static function listDir(path:String):Array<String> {
        var results:Array<String> = [];
        var normal = PathUtils.normalizePath(path);

        #if sys
        if (FileSystem.exists(normal) && FileSystem.isDirectory(normal)) {
            try {
                var items = FileSystem.readDirectory(normal);
                for (item in items) {
                    if (item != "." && item != "..") {
                        results.push(item);
                    }
                }
            } catch (e:Dynamic) {}
        }
        #end

        var prefix = normal;
        if (prefix.length > 0 && !prefix.endsWith("/")) prefix += "/";

        var assetList = Assets.list();
        for (asset in assetList) {
            if (asset.startsWith(prefix)) {
                var sub = asset.substr(prefix.length);
                if (sub.length > 0) {
                    var slashIndex = sub.indexOf("/");
                    var entry = (slashIndex == -1) ? sub : sub.substr(0, slashIndex);
                    if (results.indexOf(entry) == -1) {
                        results.push(entry);
                    }
                }
            }
        }

        return results;
    }

    public static function listDirRecursive(path:String):Array<String> {
        var results:Array<String> = [];
        var normal = PathUtils.normalizePath(path);

        #if sys
        if (FileSystem.exists(normal) && FileSystem.isDirectory(normal)) {
            _recursiveSysCollect(normal, "", results);
        }
        #end

        var prefix = normal;
        if (prefix.length > 0 && !prefix.endsWith("/")) prefix += "/";

        for (asset in Assets.list()) {
            if (asset.startsWith(prefix)) {
                var relative = asset.substr(prefix.length);
                if (results.indexOf(relative) == -1) {
                    results.push(relative);
                }
            }
        }

        return results;
    }

    #if sys
    private static function _recursiveSysCollect(root:String, rel:String, out:Array<String>):Void {
        var full = PathUtils.combine(root, rel);
        if (!FileSystem.isDirectory(full)) return;

        for (item in FileSystem.readDirectory(full)) {
            var itemRel = rel == "" ? item : rel + "/" + item;
            var itemFull = PathUtils.combine(root, itemRel);
            
            if (out.indexOf(itemRel) == -1) out.push(itemRel);
            
            if (FileSystem.isDirectory(itemFull)) {
                _recursiveSysCollect(root, itemRel, out);
            }
        }
    }
    #end

    public static function stat(path:String):Null<ModStat> {
        var normal = PathUtils.normalizePath(path);

        #if sys
        if (FileSystem.exists(normal)) {
            try {
                var s:FileStat = FileSystem.stat(normal);
                return {
                    mtimeMs: s.mtime.getTime(),
                    size: s.size
                };
            } catch (e:Dynamic) {}
        }
        #end

        return null;
    }

    public static function writeText(path:String, content:String):Bool {
        #if sys
        var normal = PathUtils.normalizePath(path);
        try {
            var dir = Path.directory(normal);
            if (!FileSystem.exists(dir)) {
                createDir(dir);
            }
            File.saveContent(normal, content);
            return true;
        } catch (e:Dynamic) {
            return false;
        }
        #else
        return false;
        #end
    }

    public static function writeBytes(path:String, bytes:Bytes):Bool {
        #if sys
        var normal = PathUtils.normalizePath(path);
        try {
            var dir = Path.directory(normal);
            if (!FileSystem.exists(dir)) {
                createDir(dir);
            }
            File.saveBytes(normal, bytes);
            return true;
        } catch (e:Dynamic) {
            return false;
        }
        #else
        return false;
        #end
    }

    public static function createDir(path:String):Bool {
        #if sys
        var normal = PathUtils.normalizePath(path);
        if (FileSystem.exists(normal)) return FileSystem.isDirectory(normal);

        try {
            var parts = normal.split("/");
            var current = "";
            for (part in parts) {
                if (current == "") current = part;
                else current += "/" + part;
                
                if (current != "" && !FileSystem.exists(current)) {
                    FileSystem.createDirectory(current);
                }
            }
            return true;
        } catch (e:Dynamic) {
            return false;
        }
        #else
        return false;
        #end
    }

    public static function deleteFile(path:String):Bool {
        #if sys
        var normal = PathUtils.normalizePath(path);
        if (!FileSystem.exists(normal)) return true;

        try {
            if (FileSystem.isDirectory(normal)) {
                _recursiveDelete(normal);
            } else {
                FileSystem.deleteFile(normal);
            }
            return true;
        } catch (e:Dynamic) {
            return false;
        }
        #else
        return false;
        #end
    }

    #if sys
    private static function _recursiveDelete(path:String):Void {
        for (item in FileSystem.readDirectory(path)) {
            var full = path + "/" + item;
            if (FileSystem.isDirectory(full)) {
                _recursiveDelete(full);
            } else {
                FileSystem.deleteFile(full);
            }
        }
        FileSystem.deleteDirectory(path);
    }
    #end

    public static function getExtension(path:String):String {
        return Path.extension(path);
    }

    public static function withoutExtension(path:String):String {
        return Path.withoutExtension(path);
    }

    public static function getFileName(path:String):String {
        return Path.withoutDirectory(path);
    }

    public static function getDirectory(path:String):String {
        return Path.directory(path);
    }
}