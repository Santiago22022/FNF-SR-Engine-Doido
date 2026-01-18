package backend.psych;

import openfl.utils.Assets;
import haxe.Json;
import backend.song.SongData; // Doido's Song Data
import flixel.FlxSprite;
import flixel.util.FlxColor;
import flixel.FlxG;
import states.PlayState;
import backend.game.SaveData;
import backend.system.ModPaths; // Use ModPaths for file reading
import objects.Character.AnimArray;
import Paths;

#if sys
import sys.io.File;
import sys.FileSystem;
#end

typedef StageFile = {
	var directory:String;
	var defaultZoom:Float;
	@:optional var isPixelStage:Null<Bool>;
	var stageUI:String;
	@:optional var gfVersion:String;

	var boyfriend:Array<Dynamic>;
	var girlfriend:Array<Dynamic>;
	var opponent:Array<Dynamic>;
	var hide_girlfriend:Bool;

	var camera_boyfriend:Array<Float>;
	var camera_opponent:Array<Float>;
	var camera_girlfriend:Array<Float>;
	var camera_speed:Null<Float>;

	@:optional var preload:Dynamic;
	@:optional var objects:Array<Dynamic>;
	@:optional var _editorMeta:Dynamic;
}

enum abstract LoadFilters(Int) from Int from UInt to Int to UInt
{
	var LOW_QUALITY:Int = (1 << 0);
	var HIGH_QUALITY:Int = (1 << 1);

	var STORY_MODE:Int = (1 << 2);
	var FREEPLAY:Int = (1 << 3);
}

class StageData {
	public static function dummy():StageFile
	{
		return {
			directory: "",
			defaultZoom: 0.9,
			stageUI: "normal",

			boyfriend: [770, 100],
			girlfriend: [400, 130],
			opponent: [100, 100],
			hide_girlfriend: false,

			camera_boyfriend: [0, 0],
			camera_opponent: [0, 0],
			camera_girlfriend: [0, 0],
			camera_speed: 1,

			_editorMeta: {
				gf: "gf",
				dad: "dad",
				boyfriend: "bf"
			}
		};
	}

	public static var forceNextDirectory:String = null;
	public static function loadDirectory(SONG:SwagSong) {
		var stage:String = '';
		if(SONG.stage != null)
			stage = SONG.stage;
		else if(SongData.weeks != null) // Fallback logic
			stage = 'stage';
		else
			stage = 'stage';

		var stageFile:StageFile = getStageFile(stage);
		forceNextDirectory = (stageFile != null) ? stageFile.directory : ''; 
	}

	public static function getStageFile(stage:String):StageFile {
		try
		{
			// Try finding the file using our hybrid path logic
			var path = 'stages/' + stage;
			var resolved = ModPaths.resolveWithExtensions(path, null, [".json", ".JSON"]);
			
			if(resolved == null && Paths.fileExists(path + '.json'))
				resolved = path + '.json';

			if(resolved != null) {
				#if sys
				if(FileSystem.exists(resolved))
					return cast tjson.TJSON.parse(File.getContent(resolved));
				#else
				if(Assets.exists(resolved))
					return cast tjson.TJSON.parse(Assets.getText(resolved));
				#end
			}
		}
		return dummy();
	}

	public static var reservedNames:Array<String> = ['gf', 'gfGroup', 'dad', 'dadGroup', 'boyfriend', 'boyfriendGroup']; 
	
	public static function addObjectsToState(objectList:Array<Dynamic>, gf:FlxSprite, dad:FlxSprite, boyfriend:FlxSprite, ?group:Dynamic = null, ?ignoreFilters:Bool = false)
	{
		var addedObjects:Map<String, FlxSprite> = [];
		for (num => data in objectList)
		{
			if (addedObjects.exists(data.name)) continue;

			switch(data.type)
			{
				case 'gf', 'gfGroup':
					if(gf != null)
					{
						gf.ID = num; 
						if (group != null) group.add(gf);
						addedObjects.set('gf', gf);
					}
				case 'dad', 'dadGroup':
					if(dad != null)
					{
						dad.ID = num;
						if (group != null) group.add(dad);
						addedObjects.set('dad', dad);
					}
				case 'boyfriend', 'boyfriendGroup':
					if(boyfriend != null)
					{
						boyfriend.ID = num;
						if (group != null) group.add(boyfriend);
						addedObjects.set('boyfriend', boyfriend);
					}

				case 'square', 'sprite', 'animatedSprite':
					if(!ignoreFilters && !validateVisibility(data.filters)) continue;

					var spr:FlxSprite;
					if(data.type == 'square')
						spr = new FlxSprite(data.x, data.y);
					else
						spr = new BGSprite(null, data.x, data.y, 1, 1, null);
						
					spr.ID = num;
					if(data.type != 'square')
					{
						if(data.type == 'sprite') {
							// FIX: Handle image paths correctly using Doido/Psych hybrid logic
							var imgName:String = data.image;
							var dir = forceNextDirectory;
							
							// Logic from PsychBridge injected here:
							var pathBase = 'stages/$dir/$imgName';
							if(!Paths.fileExists(pathBase + '.png')) {
								if(dir != null && dir.length > 0 && Paths.fileExists('$dir/$imgName.png'))
									pathBase = '$dir/$imgName';
								else if(Paths.fileExists('$imgName.png'))
									pathBase = imgName;
							}
							
							spr.loadGraphic(Paths.image(pathBase));
						} else {
							// FIX: Handle atlas loading without getAtlas
							if(Paths.fileExists('images/' + data.image + '.txt'))
								spr.frames = Paths.getPackerAtlas(data.image);
							else
								spr.frames = Paths.getSparrowAtlas(data.image);
						}
						
						if(data.type == 'animatedSprite' && data.animations != null)
						{
							var anims:Array<AnimArray> = cast data.animations;
							for (key => anim in anims)
							{
								if(anim.indices == null || anim.indices.length < 1)
									spr.animation.addByPrefix(anim.anim, anim.name, anim.fps, anim.loop);
								else
									spr.animation.addByIndices(anim.anim, anim.name, anim.indices, '', anim.fps, anim.loop);
	
								if(anim.offsets != null)
									// Assuming FlxSprite extension or BGSprite handles offsets, standard FlxSprite only has .offset
									// For now we map 0,0. To support offsets fully we need ModchartSprite port.
									// spr.addOffset(anim.anim, anim.offsets[0], anim.offsets[1]);
									spr.offset.set(anim.offsets[0], anim.offsets[1]); // Rough fallback
	
								if(spr.animation.curAnim == null || data.firstAnimation == anim.anim)
									spr.animation.play(anim.anim, true);
							}
						}
						
						// Reflect properties
						if(Reflect.hasField(data, "antialiasing")) spr.antialiasing = data.antialiasing;
						if(Reflect.hasField(data, "flipX")) spr.flipX = data.flipX;
						if(Reflect.hasField(data, "flipY")) spr.flipY = data.flipY;

						if(!SaveData.data.get("Antialiasing")) spr.antialiasing = false;
					}
					else
					{
						spr.makeGraphic(1, 1, FlxColor.WHITE);
						spr.antialiasing = false;
					}

					if(data.scale != null && (data.scale[0] != 1.0 || data.scale[1] != 1.0))
					{
						spr.scale.set(data.scale[0], data.scale[1]);
						spr.updateHitbox();
					}
					
					if(data.scroll != null)
						spr.scrollFactor.set(data.scroll[0], data.scroll[1]);
						
					if(data.color != null) {
						var col:String = data.color;
						if(!col.startsWith("0x")) col = "0xFF" + col.replace("#","");
						spr.color = Std.parseInt(col);
					}
					
					if(Reflect.hasField(data, "alpha")) spr.alpha = data.alpha;
					if(Reflect.hasField(data, "angle")) spr.angle = data.angle;

					if (group != null) group.add(spr);
					addedObjects.set(data.name, spr);

				default:
					// unknown type
			}
		}
		return addedObjects;
	}

	public static function validateVisibility(filters:LoadFilters)
	{
		if((filters & STORY_MODE) == STORY_MODE)
			if(!PlayState.isStoryMode) return false;
		else if((filters & FREEPLAY) == FREEPLAY)
			if(PlayState.isStoryMode) return false;

		var lowQuality = SaveData.data.get("Low Quality");
		return ((lowQuality && (filters & LOW_QUALITY) == LOW_QUALITY) ||
			(!lowQuality && (filters & HIGH_QUALITY) == HIGH_QUALITY));
	}
}
