package objects;

import crowplexus.iris.Iris;
import flixel.FlxSprite;
import flixel.group.FlxGroup;
import flixel.math.FlxPoint;
import states.PlayState;
import objects.BackgroundGirls;
import backend.game.IStepHit;
import backend.system.ModPaths;
import tjson.TJSON;
#if sys
import sys.io.File;
import sys.FileSystem;
#end

class Stage extends FlxGroup implements IStepHit
{
	public static var instance:Stage;

	public var curStage:String = "";
	public var gfVersion:String = "no-gf";
	public var camZoom:Float = 1;
	public var isPsychStage:Bool = false;

	// things to help your stage get better
	public var bfPos:FlxPoint  = new FlxPoint();
	public var dadPos:FlxPoint = new FlxPoint();
	public var gfPos:FlxPoint  = new FlxPoint();

	public var bfCam:FlxPoint  = new FlxPoint();
	public var dadCam:FlxPoint = new FlxPoint();
	public var gfCam:FlxPoint  = new FlxPoint();

	public var foreground:FlxGroup;

	var loadedScripts:Array<Iris> = [];
	var scripted:Array<String> = [];

	var lowQuality:Bool = false;

	var gfSong:String = "stage-set";

	public function new() {
		super();
		foreground = new FlxGroup();
		instance = this;
	}

	public function reloadStageFromSong(song:String = "test", gfSong:String = "stage-set")
	{
		var stageList:Array<String> = [];
		
		var normalized = song == null ? "" : song.toLowerCase().trim();
		if(normalized != "" && normalized != "test")
		{
			// Check if we can find a JSON or script for this stage
			var found:Bool = false;
			var searchPaths:Array<String> = [
				'stages/$normalized',
				'data/stages/$normalized',
				'images/stages/$normalized'
			];
			for(path in searchPaths)
			{
				if(Paths.fileExists('$path.json') || Paths.fileExists('$path.hxc') || Paths.fileExists('$path.hx'))
				{
					stageList = [normalized];
					found = true;
					break;
				}
			}
			
			if(!found)
			{
				// Hardcoded fallbacks if no dynamic file is found
				stageList = switch(normalized)
				{
					case "collision": ["mugen"];
					case "senpai"|"roses": ["school"];
					case "thorns": ["school-evil"];
					default: [normalized];
				};
			}
		}
		else
		{
			stageList = ["stage"];
		}

		Logs.print('Attempting to load stage: ${stageList[0]}', TRACE);
		//this stops you from fucking stuff up by changing this mid song
		lowQuality = SaveData.data.get("Low Quality");

		this.gfSong = gfSong;

		for(i in stageList) {
			preloadScript(i);
			reloadStage(i);
		}
	}

	public function reloadStage(curStage:String = "")
	{
		this.clear();
		foreground.clear();
		this.curStage = curStage;
		isPsychStage = false;
		
		gfPos.set(660, 580);
		dadPos.set(260, 700);
		bfPos.set(1100, 700);
		
		if(scripted.contains(curStage))
			callScript("create");
		else
			loadCode(curStage);

		PlayState.defaultCamZoom = camZoom;
	}

	public function preloadScript(stage:String = "")
	{
		var path:String = 'images/stages/_scripts/$stage';
		
		if(Paths.fileExists('$path.hxc'))
			path += '.hxc';
		else if(Paths.fileExists('$path.hx'))
			path += '.hx';
		else
			return;

		var newScript:Iris = new Iris(Paths.script('$path'), {name: path, autoRun: false, autoPreset: true});

		// variables to be used inside the scripts
		newScript.set("FlxSprite", FlxSprite);
		newScript.set("Paths", Paths);
		newScript.set("this", instance);

		newScript.set("add", add);
		newScript.set("foreground", foreground);

		newScript.set("bfPos", bfPos);
		newScript.set("dadPos", dadPos);
		newScript.set("gfPos", gfPos);

		newScript.set("bfCam", bfCam);
		newScript.set("dadCam", dadCam);
		newScript.set("gfCam", gfCam);

		newScript.set("lowQuality", lowQuality);

		newScript.execute();

		loadedScripts.push(newScript);
		scripted.push(stage);
	}

	// Hardcode your stages here!
	public function loadCode(curStage:String = "")
	{
		gfVersion = getGfVersion(curStage);
		// Step 1: Try JSON (loads positions, zoom, and optional sprite definitions)
		var jsonLoaded = loadStageFromJson(curStage);
		
		// Step 2: Check if a Lua stage script exists — if so, PlayState will flush addQueue into us
		var luaLoaded = false;
		#if LUA_ALLOWED
		if(backend.system.ModPaths.exists('stages/$curStage.lua'))
			luaLoaded = true;
		#end

		if(jsonLoaded || luaLoaded)
		{
			this.curStage = curStage;
			return;
		}
		// Generic loader for mod stages (Psych-style): look for stageback/front/curtains under images/stages/<curStage>
		if(curStage != null && curStage.trim() != "" && scripted.contains(curStage))
			return;

		if(curStage != null && curStage.trim() != "" && !["stage","school","school-evil"].contains(curStage.toLowerCase()))
		{
			var base = 'stages/$curStage';
			var backPath = 'stages/$curStage/stageback';
			var frontPath = 'stages/$curStage/stagefront';
			var curtainsPath = 'stages/$curStage/stagecurtains';
			var anyFound:Bool = false;

			if(Paths.fileExists('$backPath.png'))
			{
				var bg = new FlxSprite(-600, -600).loadGraphic(Paths.image(backPath));
				bg.scrollFactor.set(0.6,0.6);
				add(bg);
				anyFound = true;
			}
			if(Paths.fileExists('$frontPath.png'))
			{
				var front = new FlxSprite(-580, 440).loadGraphic(Paths.image(frontPath));
				add(front);
				anyFound = true;
			}
			if(!lowQuality && Paths.fileExists('$curtainsPath.png'))
			{
				var curtains = new FlxSprite(-600, -400).loadGraphic(Paths.image(curtainsPath));
				curtains.scrollFactor.set(1.4,1.4);
				foreground.add(curtains);
				anyFound = true;
			}
			// NOTE: Removed the generic "dump all PNGs" fallback.
			// That code loaded every .png from the stage folder at position (0,0) with no
			// layering, which caused foreground sprites (like tentacles, overlays) to cover
			// the entire screen. Psych Engine stages that use Lua for visuals will now
			// gracefully show nothing extra instead of broken layering.
			if(anyFound)
			{
				this.curStage = curStage;
				return;
			}
		}

		switch(curStage)
		{
			case "stage":
				this.curStage = "stage";
				camZoom = 0.9;
				
				var bg = new FlxSprite(-600, -600).loadGraphic(Paths.image("stages/stage/stageback"));
				bg.scrollFactor.set(0.6,0.6);
				add(bg);
				
				var front = new FlxSprite(-580, 440);
				front.loadGraphic(Paths.image("stages/stage/stagefront"));
				add(front);
				
				if(!lowQuality) {
					var curtains = new FlxSprite(-600, -400).loadGraphic(Paths.image("stages/stage/stagecurtains"));
					curtains.scrollFactor.set(1.4,1.4);
					foreground.add(curtains);
				}
				
			case "school":
				bfPos.x -= 70;
				dadPos.x += 50;
				gfPos.x += 20;
				gfPos.y += 50;
				
				var bgSky = new FlxSprite().loadGraphic(Paths.image('stages/school/weebSky'));
				bgSky.scrollFactor.set(0.1, 0.1);
				add(bgSky);
				
				var bgSchool:FlxSprite = new FlxSprite(-200, 0).loadGraphic(Paths.image('stages/school/weebSchool'));
				bgSchool.scrollFactor.set(0.6, 0.90);
				add(bgSchool);
				
				var bgStreet:FlxSprite = new FlxSprite(-200).loadGraphic(Paths.image('stages/school/weebStreet'));
				bgStreet.scrollFactor.set(0.95, 0.95);
				add(bgStreet);
				
				var fgTrees:FlxSprite = new FlxSprite(-200 + 170, 130).loadGraphic(Paths.image('stages/school/weebTreesBack'));
				fgTrees.scrollFactor.set(0.9, 0.9);
				add(fgTrees);
				
				var bgTrees:FlxSprite = new FlxSprite(-200 - 380, -1100);
				bgTrees.frames = Paths.getPackerAtlas('stages/school/weebTrees');
				bgTrees.animation.add('treeLoop', CoolUtil.intArray(18), 12);
				bgTrees.animation.play('treeLoop');
				bgTrees.scrollFactor.set(0.85, 0.85);
				add(bgTrees);

				if(!lowQuality) {
					var treeLeaves:FlxSprite = new FlxSprite(-200, -40);
					treeLeaves.frames = Paths.getSparrowAtlas('stages/school/petals');
					treeLeaves.animation.addByPrefix('leaves', 'PETALS ALL', 24, true);
					treeLeaves.animation.play('leaves');
					treeLeaves.scrollFactor.set(0.85, 0.85);
					add(treeLeaves);
					
					var bgGirls = new BackgroundGirls(-100, 175);
					if (PlayState.instance != null) PlayState.instance.addStepHit(bgGirls);
					add(bgGirls);
				}
				
				// easier to manage
				for(rawItem in members)
				{
					if(Std.isOfType(rawItem, FlxSprite))
					{
						var item:FlxSprite = cast rawItem;
						item.antialiasing = false;
						item.isPixelSprite = true;
						item.scale.set(6,6);
						item.updateHitbox();
						item.x -= 170;
						item.y -= 145;
					}
				}
				
			case "school-evil":
				bfPos.x -= 70;
				dadPos.x += 50;
				gfPos.x += 20;
				gfPos.y += 50;
				
				var bg:FlxSprite = new FlxSprite(400, 100);
				bg.frames = Paths.getSparrowAtlas('stages/school/animatedEvilSchool');
				bg.animation.addByPrefix('idle', 'background 2', 24);
				bg.animation.play('idle');
				bg.scrollFactor.set(0.8, 0.9);
				bg.antialiasing = false;
				bg.scale.set(6,6);
				add(bg);
		}
	}

	function loadStageFromJson(stage:String):Bool
	{
		if(stage == null || stage.trim() == "")
			return false;

		var data:Dynamic = null;
		var searchPaths:Array<String> = [
			'stages/$stage',
			'data/stages/$stage',
			'images/stages/$stage'
		];
		
		for(path in searchPaths)
		{
			if(Paths.fileExists('$path.json'))
			{
				try {
					data = Paths.json(path);
					Logs.print('Successfully loaded stage JSON from: $path.json', TRACE);
					break;
				} catch(e) {
					Logs.print('Error parsing stage JSON at $path.json: $e', ERROR);
				}
			}
		}

		if(data == null)
			return false;

		// Detect Psych Engine format stage JSON (has defaultZoom and character position fields)
		if(Reflect.hasField(data, "defaultZoom") && (Reflect.hasField(data, "boyfriend") || Reflect.hasField(data, "opponent")))
			isPsychStage = true;

		var directory:String = "";
		if(Reflect.hasField(data, "directory"))
			directory = Std.string(Reflect.field(data, "directory"));

		if(Reflect.hasField(data, "defaultZoom"))
			camZoom = Std.parseFloat(Std.string(Reflect.field(data, "defaultZoom")));
		
		// In Psych Engine JSONs, gfVersion might not be present, but stage-set can be used as a fallback
		if(Reflect.hasField(data, "gfVersion"))
			gfVersion = Std.string(Reflect.field(data, "gfVersion"));
		else
			gfVersion = getGfVersion(stage);

		inline function setPoint(field:String, pt:FlxPoint)
		{
			if(Reflect.hasField(data, field))
			{
				var arr:Dynamic = Reflect.field(data, field);
				if(arr != null && Std.isOfType(arr, Array) && (arr:Array<Dynamic>).length >= 2)
				{
					var a:Array<Dynamic> = cast arr;
					pt.set(Std.parseFloat(Std.string(a[0])), Std.parseFloat(Std.string(a[1])));
				}
			}
		}
		setPoint("boyfriend", bfPos);
		setPoint("opponent", dadPos);
		setPoint("girlfriend", gfPos);

		setPoint("camera_boyfriend", bfCam);
		setPoint("camera_opponent", dadCam);
		setPoint("camera_girlfriend", gfCam);

		// Support both "sprites" (Doido format) and "objects" (Psych Engine 0.7+ format)
		var sprites:Dynamic = Reflect.field(data, "sprites");
		if(sprites == null)
			sprites = Reflect.field(data, "objects");
		var any:Bool = false;
		if(sprites != null && Std.isOfType(sprites, Array))
		{
			for(entry in (sprites:Array<Dynamic>))
			{
				if(entry == null) continue;
				var image:String = Std.string(Reflect.field(entry, "image"));
				if(image == null || image.trim() == "") continue;
				
				// Position: support both "x"/"y" and "position" array formats
				var x:Float = 0;
				var y:Float = 0;
				if(Reflect.hasField(entry, "position"))
				{
					var posArr:Dynamic = Reflect.field(entry, "position");
					if(posArr != null && Std.isOfType(posArr, Array))
					{
						var pa:Array<Dynamic> = cast posArr;
						if(pa.length >= 2)
						{
							x = Std.parseFloat(Std.string(pa[0]));
							y = Std.parseFloat(Std.string(pa[1]));
						}
					}
				}
				else
				{
					x = Std.parseFloat(Std.string(Reflect.field(entry, "x")));
					y = Std.parseFloat(Std.string(Reflect.field(entry, "y")));
				}
				if(Math.isNaN(x)) x = 0;
				if(Math.isNaN(y)) y = 0;
				
				var scrollArr:Array<Dynamic> = Reflect.hasField(entry, "scroll") ? cast Reflect.field(entry, "scroll") : [1, 1];
				var scrollX:Float = Std.parseFloat(Std.string(scrollArr[0]));
				var scrollY:Float = Std.parseFloat(Std.string(scrollArr[1]));
				
				// Scale: support both number and [scaleX, scaleY] array
				var scaleX:Float = 1;
				var scaleY:Float = 1;
				if(Reflect.hasField(entry, "scale"))
				{
					var scaleField:Dynamic = Reflect.field(entry, "scale");
					if(Std.isOfType(scaleField, Array))
					{
						var sa:Array<Dynamic> = cast scaleField;
						if(sa.length >= 2)
						{
							scaleX = Std.parseFloat(Std.string(sa[0]));
							scaleY = Std.parseFloat(Std.string(sa[1]));
						}
					}
					else
					{
						scaleX = Std.parseFloat(Std.string(scaleField));
						scaleY = scaleX;
					}
				}
				
				// Foreground detection: supports "foreground":true AND Psych Engine "type":"fg"
				var foregroundSprite:Bool = false;
				if(Reflect.hasField(entry, "foreground"))
					foregroundSprite = (Reflect.field(entry, "foreground") == true);
				if(Reflect.hasField(entry, "type"))
				{
					var entryType:String = Std.string(Reflect.field(entry, "type")).toLowerCase();
					if(entryType == "fg" || entryType == "foreground")
						foregroundSprite = true;
				}
				
				// Try various paths for the sprite image
				var pathBases:Array<String> = [
					(directory != "" ? 'stages/$directory/$image' : 'stages/$stage/$image'),
					'images/$image',
					image
				];
				
				var spr:FlxSprite = new FlxSprite(x, y);
				var loaded:Bool = false;
				
				for(pathBase in pathBases)
				{
					if(Paths.fileExists('$pathBase.xml'))
					{
						spr.frames = Paths.getSparrowAtlas(pathBase);
						loaded = spr.frames != null;
						if(loaded) break;
					}
					if(Paths.fileExists('$pathBase.png'))
					{
						spr.loadGraphic(Paths.image(pathBase));
						loaded = true;
						break;
					}
				}
				
				if(!loaded) {
					Logs.print('Could not find image for sprite: $image', WARNING);
					continue;
				}

				spr.scrollFactor.set(scrollX, scrollY);
				spr.scale.set(scaleX, scaleY);
				spr.updateHitbox();
				
				if(Reflect.hasField(entry, "antialiasing"))
					spr.antialiasing = (Reflect.field(entry, "antialiasing") == true);
				if(Reflect.hasField(entry, "flipX"))
					spr.flipX = (Reflect.field(entry, "flipX") == true);

				var animations:Dynamic = Reflect.field(entry, "animations");
				if(animations != null && Std.isOfType(animations, Array))
				{
					for(animEntry in (animations:Array<Dynamic>))
					{
						if(animEntry == null) continue;
						var animName:String = Std.string(Reflect.field(animEntry, "anim"));
						var prefix:String = Std.string(Reflect.field(animEntry, "name"));
						if(animName == null || prefix == null) continue;
						var fps:Int = Std.int(Reflect.hasField(animEntry, "fps") ? Std.parseInt(Std.string(Reflect.field(animEntry, "fps"))) : 24);
						var loop:Bool = Reflect.hasField(animEntry, "loop") ? (Reflect.field(animEntry, "loop") == true) : true;
						spr.animation.addByPrefix(animName, prefix, fps, loop);
					}
					if(spr.animation != null)
					{
						var names = spr.animation.getNameList();
						if(names != null && names.length > 0)
							spr.animation.play(names[0], true);
					}
				}

				if(foregroundSprite)
					foreground.add(spr);
				else
					add(spr);
				any = true;
			}
		}
		
		// Return whether we actually loaded any visual sprite elements.
		// If the JSON only had positions/zoom (Psych 0.6.x), this returns false
		// and loadCode will try loadStageFromLua next.
		return any;
	}

	public function getGfVersion(curStage:String)
	{
		if(gfSong != "stage-set")
			return gfSong;

		return switch(curStage)
		{
			case "mugen": "no-gf";
			case "school"|"school-evil": "gf-pixel";
			default: "gf";
		}
	}
	
	override function update(elapsed:Float)
	{
		super.update(elapsed);
		callScript("update", [elapsed]);
	}
	
	public function stepHit(curStep:Int)
	{
		// beat hit
		// if(curStep % 4 == 0)

		callScript("stepHit", [curStep]);
	}

	public function callScript(fun:String, ?args:Array<Dynamic>)
	{
		for(i in 0...loadedScripts.length) {
			if(scripted[i] != curStage)
				continue;

			var script:Iris = loadedScripts[i];

			@:privateAccess {
				var ny: Dynamic = script.interp.variables.get(fun);
				try {
					if(ny != null && Reflect.isFunction(ny))
						script.call(fun, args);
				} catch(e) {
					Logs.print('error parsing script: ' + e, ERROR);
				}
			}
		}
	}
}
