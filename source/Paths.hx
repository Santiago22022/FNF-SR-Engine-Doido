package;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.graphics.FlxGraphic;
import flixel.graphics.frames.FlxAtlasFrames;
import flixel.graphics.frames.FlxFramesCollection;
import flixel.sound.FlxSound;
import lime.utils.Assets;
import openfl.display.BitmapData;
import openfl.media.Sound;
import openfl.system.System;
import openfl.utils.AssetType;
import openfl.utils.Assets as OpenFlAssets;
import states.PlayState;
import backend.system.ModLoader;
import backend.system.ModPaths;
import backend.system.ModBackend;
import tjson.TJSON;

using StringTools;

class Paths
{
    // ========================================================================
    // VARIABLES & CACHE
    // ========================================================================
    public static var renderedGraphics:Map<String, FlxGraphic> = [];
    public static var renderedSounds:Map<String, Sound> = [];
    
    // Lista de extensiones de sonido permitidas
    public static var soundExtensions:Array<String> = [".ogg", ".mp3", ".wav"];

    public static var dumpExclusions:Array<String> = [
        "menu/alphabet/default.png",
        "menu/checkmark.png",
        "menu/menuArrows.png",
        // Gameplay Essentials (Notes)
        "notes/base/notes.png",
        "notes/doido/notes.png",
        "notes/pixel/notesPixel.png",
        "notes/pixel/notesEnds.png",
        // Gameplay Essentials (HUD)
        "hud/base/healthBar.png",
        "hud/base/iconGrid.png",
        "hud/base/ready.png",
        "hud/base/set.png",
        "hud/base/go.png",
        // Judgements & Combo
        "hud/base/sick.png",
        "hud/base/good.png",
        "hud/base/bad.png",
        "hud/base/shit.png",
        "hud/base/num0.png",
        "hud/base/num1.png",
        "hud/base/num2.png",
        "hud/base/num3.png",
        "hud/base/num4.png",
        "hud/base/num5.png",
        "hud/base/num6.png",
        "hud/base/num7.png",
        "hud/base/num8.png",
        "hud/base/num9.png",
        // Splashes
        "notes/base/noteSplashes.png",
        "notes/doido/noteSplashes.png",
        // Mouse
        "cursor.png"
    ];

    // ========================================================================
    // INTERNAL HELPERS
    // ========================================================================
    
    static inline function modAssetPath(filePath:String, ?library:String):String
    {
        var modPath = ModPaths.resolveAssetPath(filePath, library);
        if(modPath != null) return modPath;
        return getPath(filePath, library);
    }

    static inline function cacheKey(key:String, ?library:String):String
        return (library != null && library.length > 0) ? '$library:$key' : key;

    static inline function cacheParts(key:String):{ key:String, library:Null<String> }
    {
        var sep = key.indexOf(":");
        return sep == -1 ? { key: key, library: null } : { key: key.substr(sep + 1), library: key.substr(0, sep) };
    }

    // Lógica core para encontrar archivos (Mantenida intacta para compatibilidad Doido)
    public static function getPath(key:String, ?library:String):String {
        // 1. MODS PRIORITY (Real-Time Modding)
        var modPath = ModPaths.resolveAssetPath(key, library);
        if(modPath != null) return modPath;

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

        var pathDoido:String = (library != null) ? 'assets/Doido/$library/$key' : 'assets/Doido/$key';
        var pathRoot:String  = (library != null) ? 'assets/$library/$key'       : 'assets/$key';

        // 2. DOIDO PRIORITY
        #if sys
        if (sys.FileSystem.exists(pathDoido)) return pathDoido;
        #end

        // 3. Last resort: Root assets
        return pathRoot;
    }
    
    public static function fileExists(filePath:String, ?library:String):Bool
    {
        if(ModPaths.exists(filePath, library)) return true;
        
        var pathDoido:String = (library != null) ? 'assets/Doido/$library/$filePath' : 'assets/Doido/$filePath';
        
        #if sys
        if(sys.FileSystem.exists(pathDoido)) return true;
        
        var pathRoot:String = (library != null) ? 'assets/$library/$filePath' : 'assets/$filePath';
        if(sys.FileSystem.exists(pathRoot)) return true;
        #else
        var pathRoot:String = (library != null) ? 'assets/$library/$filePath' : 'assets/$filePath';
        if(OpenFlAssets.exists(pathRoot)) return true;
        #end
        
        return false;
    }

    // ========================================================================
    // SOUNDS & AUDIO
    // ========================================================================

    public static function getSound(key:String, ?library:String):Sound
    {
        var cacheId = cacheKey(key, library);
        if(!renderedSounds.exists(cacheId))
        {
            var resolved = ModPaths.resolveWithExtensions(key, library, soundExtensions);
            
            // Check alt path logic
            if(resolved == null && key.indexOf("/audio/") != -1)
            {
                var altKey = key.split("/audio/").join("/");
                var altId = cacheKey(altKey, library);
                var altRes = ModPaths.resolveWithExtensions(altKey, library, soundExtensions);
                if(altRes != null || fileExists('$altKey.ogg', library)) // legacy check
                {
                    key = altKey;
                    cacheId = altId;
                    resolved = altRes;
                }
            }

            // Fallback to beep if missing
            if(resolved == null && !fileExists('$key.ogg', library))
            {
                Logs.print('$key.ogg doesnt exist', WARNING);
                key = 'sounds/beep';
                library = null;
                cacheId = cacheKey(key, library);
                resolved = ModPaths.resolveWithExtensions(key, library, soundExtensions);
            }

            if(resolved == null) resolved = getPath('$key.ogg', library);

            Logs.print('created new sound $resolved');
            
            #if sys
            if(sys.FileSystem.exists(resolved))
                renderedSounds.set(cacheId, Sound.fromFile(resolved));
            else
                renderedSounds.set(cacheId, OpenFlAssets.getSound(resolved, false));
            #else
            renderedSounds.set(cacheId, OpenFlAssets.getSound(resolved, false));
            #end
        }
        return renderedSounds.get(cacheId);
    }

    public static function music(key:String, ?library:String):Sound
        return getSound('music/$key', library);
    
    public static function sound(key:String, ?library:String):Sound
        return getSound('sounds/$key', library);

    public static function inst(song:String, diff:String = ''):Sound
        return getSound(songPath(song, 'Inst', diff));

    public static function vocals(song:String, diff:String = '', ?prefix:String = ''):Sound
        return getSound(songPath(song, 'Voices', diff, prefix));

    /**
     * Helper rápido para tocar un sonido sin instanciar FlxSound manualmente fuera.
     * Útil para sonidos de menú o UI rápidos.
     */
    public static function playSound(key:String, ?library:String, volume:Float = 1.0, pitch:Float = 1.0)
    {
        FlxG.sound.play(sound(key, library), volume, false, null, true, function() {
            // Callback opcional
        }).pitch = pitch;
    }

    public static function songPath(song:String, key:String, diff:String, prefix:String = ''):String
    {
        var base:String = 'songs/$song';
        var diffPref:String = '';
        
        // erect / nightmare logic
        if(['erect', 'nightmare'].contains(diff.toLowerCase()))
            diffPref = '-erect';
        
        var candidates:Array<String> = [
            '$base/audio/$key$diffPref$prefix',
            '$base/audio/$key$diffPref',
            '$base/$key$diffPref$prefix',
            '$base/$key$diffPref'
        ];
        for(path in candidates)
        {
            if(fileExists('$path.ogg'))
                return path;
        }
        return '$base/$key$diffPref';
    }

    // ========================================================================
    // IMAGES & GRAPHICS
    // ========================================================================

    public static function image(key:String, ?library:String):FlxGraphic
        return getGraphic(key, library);

    public static function getGraphic(key:String, ?library:String):FlxGraphic
    {
        if(key.endsWith('.png'))
            key = key.substring(0, key.lastIndexOf('.png'));
        var cacheId = cacheKey(key, library);
        
        // 1. Try to find the file (Mod -> Shared -> Base)
        var path = ModPaths.resolveWithExtensions('images/$key', library, [".png"]);
        
        // 2. Legacy fallback
        if(path == null) path = getPath('images/$key.png', library);

        var exists = (ModPaths.resolveAssetPath('images/$key.png', library) != null) || fileExists('images/$key.png', library);

        if(exists)
        {
            if(!renderedGraphics.exists(cacheId))
            {
                var bitmap:BitmapData;
                #if sys
                if(sys.FileSystem.exists(path))
                    bitmap = BitmapData.fromFile(path);
                else
                    bitmap = OpenFlAssets.getBitmapData(path, false);
                #else
                bitmap = OpenFlAssets.getBitmapData(path, false);
                #end
                
                var newGraphic = FlxGraphic.fromBitmapData(bitmap, false, cacheId, false);
                newGraphic.persist = true; 
                
                // Auto-protect essential assets
                var cleanKey = key + ".png";
                if (library != null) cleanKey = library + "/" + cleanKey;
                
                if (dumpExclusions.contains(cleanKey) || dumpExclusions.contains('images/$cleanKey')) {
                    newGraphic.destroyOnNoUse = false;
                    Logs.print('Protected asset from dumping: $cleanKey', TRACE);
                }

                Logs.print('created new image $path');
                renderedGraphics.set(cacheId, newGraphic);
            }
            return renderedGraphics.get(cacheId);
        }

        Logs.print('$path doesnt exist, returning placeholder', WARNING);
        return getPlaceholderGraphic(cacheId);
    }

    /**
     * Genera una textura de "Error" (cuadrícula rosa/negra) si falta el asset,
     * previniendo que el juego crashee por nulls.
     */
    private static function getPlaceholderGraphic(key:String):FlxGraphic
    {
        if(renderedGraphics.exists("fallback_placeholder"))
            return renderedGraphics.get("fallback_placeholder");

        var pSize = 32;
        var pGrid = 2;
        var bitmap = new BitmapData(pSize * pGrid, pSize * pGrid, true, 0xFF000000);
        for(x in 0...pGrid) {
            for(y in 0...pGrid) {
                if((x + y) % 2 == 0)
                    bitmap.fillRect(new openfl.geom.Rectangle(x*pSize, y*pSize, pSize, pSize), 0xFFFF00FF); // Rosa
            }
        }
        var graph = FlxGraphic.fromBitmapData(bitmap, false, "fallback_placeholder");
        graph.persist = true;
        renderedGraphics.set("fallback_placeholder", graph);
        return graph;
    }

    // ========================================================================
    // ATLAS & ANIMATION DATA
    // ========================================================================

    public static function getSparrowAtlas(key:String, ?library:String)
    {
        var graphic = getGraphic(key, library);
        var xmlPath = 'images/$key.xml';
        if(!ModPaths.exists(xmlPath, library) && ModPaths.exists('images/$key.XML', library))
            xmlPath = 'images/$key.XML';
        
        // Check if XML exists, if not, try to load graphic only to avoid crash
        if (!fileExists(xmlPath, library)) {
            Logs.print('XML not found for $key', WARNING);
            return FlxAtlasFrames.findFrame(graphic); // Returns simple frames
        }

        return FlxAtlasFrames.fromSparrow(graphic, getContent(xmlPath, library));
    }

    public static function getPackerAtlas(key:String, ?library:String)
    {
        var graphic = getGraphic(key, library);
        var txtPath = 'images/$key.txt';
        if(!ModPaths.exists(txtPath, library) && ModPaths.exists('images/$key.TXT', library))
            txtPath = 'images/$key.TXT';
            
        return FlxAtlasFrames.fromSpriteSheetPacker(graphic, getContent(txtPath, library));
    }

    public static function getAsepriteAtlas(key:String, ?library:String)
    {
        var graphic = getGraphic(key, library);
        var jsonPath = 'images/$key.json';
        if(!ModPaths.exists(jsonPath, library) && ModPaths.exists('images/$key.JSON', library))
            jsonPath = 'images/$key.JSON';

        return FlxAtlasFrames.fromAseprite(graphic, getContent(jsonPath, library));
    }

    // Sparrow (.xml) sheets split into multiple graphics
    public static function getMultiSparrowAtlas(baseSheet:String, otherSheets:Array<String>, ?library:String) {
        var frames:FlxFramesCollection = getSparrowAtlas(baseSheet, library);

        if(otherSheets != null && otherSheets.length > 0) {
            for(i in 0...otherSheets.length) {
                var newFrames:FlxFramesCollection = getSparrowAtlas(otherSheets[i], library);
                if (newFrames != null) {
                    for(frame in newFrames.frames) {
                        frames.pushFrame(frame);
                    }
                }
            }
        }
        return frames;
    }
    
    public static function getFrame(key:String, frame:String, ?library:String):FlxGraphic
        return FlxGraphic.fromFrame(getSparrowAtlas(key, library).getByName(frame));

    // ========================================================================
    // TEXT, DATA & SCRIPTS
    // ========================================================================

    public static function text(key:String, ?library:String):String
        return getContent('$key.txt', library).trim();

    public static function getContent(filePath:String, ?library:String):String
    {
        var modPath = ModPaths.resolveAssetPath(filePath, library);
        if(modPath != null && ModBackend.exists(modPath))
            return ModBackend.readText(modPath);

        var finalPath = getPath(filePath, library);
        
        #if sys
        if (sys.FileSystem.exists(finalPath))
            return sys.io.File.getContent(finalPath);
        #else
        if (OpenFlAssets.exists(finalPath))
            return OpenFlAssets.getText(finalPath);
        #end
        
        return "";
    }

    public static function json(key:String, ?library:String):Dynamic
    {
        var raw = getContent('$key.json', library).trim();
        if(raw == null || raw.length == 0) return null;

        // Try-Catch para JSON malformado
        try {
            return TJSON.parse(raw);
        } catch(e:Dynamic) {
            Logs.print('Error parsing JSON for $key: $e', ERROR);
            return null;
        }
    }

    // Nuevo: Soporte para YAML si en el futuro lo usas
    public static function yaml(key:String, ?library:String):String
        return getContent('$key.yaml', library);

    public static function font(key:String, ?library:String):String
        return modAssetPath('fonts/$key', library);

    public static function video(key:String, ?library:String):String
        return modAssetPath('videos/$key.mp4', library);

    public static function script(key:String, ?library:String):String
        return getContent('$key', library);

    public static function shader(key:String, ?library:String):Null<String>
        return getContent('shaders/$key', library);

    /**
     * Busca scripts en Haxe (.hx), HScript (.hxc), Lua (.lua)
     */
    public static function getScriptArray(?song:String):Array<String>
    {
        var arr:Array<String> = [];
        var foldersToCheck = [
            "scripts", 
            'songs/$song/scripts',
            'data/$song',      
            'data/scripts',    
            'stages'           
        ];

        // Añadido soporte para Lua y scripts compilados
        var extensions = [".hx", ".hxc", ".lua"];

        for(folder in foldersToCheck)
        {
            var files = readDir(folder, extensions, false);
            for(file in files)
                arr.push('$folder/$file');
        }
        return arr;
    }

    // ========================================================================
    // FILE SYSTEM & TOOLS
    // ========================================================================

    public static function readDir(dir:String, ?typeArr:Array<String>, ?removeType:Bool = true, ?library:String):Array<String>
    {
        var swagList:Array<String> = [];
        var rawList = ModPaths.listDir(dir, library, typeArr, false);
        
        if (rawList == null) return [];

        for(item in rawList)
        {
            var cleaned = item;
            if(typeArr != null && removeType)
                for(type in typeArr)
                    if(cleaned.endsWith(type))
                        cleaned = cleaned.replace(type, "");
            swagList.push(cleaned);
        }
        
        Logs.print('read dir ${(swagList.length > 0) ? '$swagList' : 'EMPTY'} at ${getPath(dir, library)}');
        return swagList;
    }

    public static function formatToSongPath(path:String) {
        var invalidChars = ~/[~&\\;:<>#]/;
        var hideChars = ~/[.,'"%?!]/;

        var path = invalidChars.split(path.replace(' ', '-')).join("-");
        return hideChars.split(path).join("").toLowerCase();
    }

    // ========================================================================
    // MEMORY MANAGEMENT & PRELOADING
    // ========================================================================

    public static function clearMemory()
    {   
        // 1. Sprite Caching Clearing
        var clearCount:Array<String> = [];
        for(key => graphic in renderedGraphics)
        {
            if (graphic == null) continue;
            
            // Do not delete persistent graphics or the placeholder
            if (graphic.persist || key == "fallback_placeholder") continue;

            var parts = cacheParts(key);
            if(dumpExclusions.contains(parts.key + '.png')) continue;
            
            var assetPath = getPath('images/${parts.key}.png', parts.library);

            clearCount.push(key);
            
            if(OpenFlAssets.cache.hasBitmapData(assetPath))
                OpenFlAssets.cache.removeBitmapData(assetPath);
            
            FlxG.bitmap.remove(graphic);
            #if (flixel < "6.0.0")
            graphic.dump();
            #end
            graphic.destroy();
        }
        
        for(key in clearCount)
            renderedGraphics.remove(key);

        Logs.print('cleared ${clearCount.length} image assets');

        // 2. OpenFL Assets Cache Cleanup
        @:privateAccess
        for(key in FlxG.bitmap._cache.keys())
        {
            var obj = FlxG.bitmap._cache.get(key);
            if(obj != null && !renderedGraphics.exists(key))
            {
                OpenFlAssets.cache.removeBitmapData(key);
                FlxG.bitmap._cache.remove(key);
                #if (flixel < "6.0.0")
                obj.dump();
                #end
                obj.destroy();
            }
        }
        
        // 3. Sound Clearing
        var soundKeys:Array<String> = [];
        for (key => sound in renderedSounds)
        {
            var parts = cacheParts(key);
            if(dumpExclusions.contains(parts.key + '.ogg')) continue;
            
            var assetPath = getPath('${parts.key}.ogg', parts.library);
            
            Assets.cache.clear(assetPath);
            soundKeys.push(key);
        }
        for(key in soundKeys)
            renderedSounds.remove(key);
        
        // 4. Force Garbage Collection
        runGC();
    }

    public static inline function runGC():Void {
        #if cpp
        System.gc();
        #else
        System.gc(); // Does mostly nothing on html5 but good habit
        #end
    }

    /**
     * Agrega un archivo a la lista de exclusiones para que no sea purgado de la RAM.
     */
    public static function excludeAsset(key:String) {
        if (!dumpExclusions.contains(key))
            dumpExclusions.push(key);
    }

    // preloads stuff for playstate
    public static function preloadPlayStuff():Void
    {
        var preGraphics:Array<String> = [];
        var preSounds:Array<String> = [
            "music/death/deathSound",
            "music/death/deathMusic",
            "music/death/deathMusicEnd",
        ];

        // Safely check for save data
        if(SaveData.data != null && SaveData.data.get("Hitsounds") != "OFF")
            preSounds.push('sounds/hitsounds/${SaveData.data.get("Hitsounds")}');
        
        for(i in 1...4) preSounds.push('sounds/miss/missnote${i}');
        
        for(i in 0...4)
        {
            var soundName:String = ["3", "2", "1", "Go"][i];
            var soundPath:String = PlayState.countdownModifier;
            
            // Check existence before pushing
            if(!fileExists('sounds/countdown/$soundPath/intro$soundName.ogg'))
                soundPath = 'base';
            
            preSounds.push('sounds/countdown/$soundPath/intro$soundName');
            
            if(i >= 1)
            {
                var countName:String = ["ready", "set", "go"][i - 1];
                var spritePath:String = PlayState.countdownModifier;
                if(!fileExists('images/hud/$spritePath/$countName.png'))
                    spritePath = 'base';
                
                preGraphics.push('hud/$spritePath/$countName');
            }
        }

        for(i in preGraphics) preloadGraphic(i);
        for(i in preSounds) preloadSound(i);
        
        Logs.print("Preloaded PlayState assets");
    }

    public static function preloadGraphic(key:String, ?library:String)
    {
        if(renderedGraphics.exists(cacheKey(key, library))) return;

        var graph = image(key, library);
        // Pequeño hack para forzar la carga en GPU sin agregarlo a un estado visible
        var what = new FlxSprite().loadGraphic(graph);
        what.destroy(); 
    }

    public static function preloadSound(key:String, ?library:String)
    {
        if(renderedSounds.exists(cacheKey(key, library))) return;

        var what = new FlxSound().loadEmbedded(getSound(key, library), false, false);
        what.volume = 0.001;
        what.play();
        what.stop();
        what.destroy();
    }
}