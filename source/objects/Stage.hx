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

	public function reloadStageFromSong(song:String = "test", gfSong:String = "stage-set"):Void
	{
		var stageList:Array<String> = [];
		
		var normalized = song == null ? "" : song.toLowerCase().trim();
		if(normalized != "" && normalized != "test")
			stageList = [normalized];
		else
		{
			stageList = switch(song)
			{
				default: ["stage"];
				
				case "collision": ["mugen"];
				
				case "senpai"|"roses": 	["school"];
				case "thorns": 			["school-evil"];
				
				//case "template": ["preload1", "preload2", "starting-stage"];
			};
		}

		//this stops you from fucking stuff up by changing this mid song
		lowQuality = SaveData.data.get("Low Quality");

		this.gfSong = gfSong;

		/*
		*	makes changing stages easier by preloading
		*	a bunch of stages at the create function
		*	(remember to put the starting stage at the last spot of the array)
		*/
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
		if(loadStageFromJson(curStage))
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
			if(!anyFound)
			{
				var files = ModPaths.listDir('images/$base', null, [".png", ".PNG"], false);
				for(file in files)
				{
					var name = file;
					if(name.lastIndexOf(".") != -1)
						name = name.substr(0, name.lastIndexOf("."));
					var spr = new FlxSprite().loadGraphic(Paths.image('$base/$name'));
					add(spr);
					anyFound = true;
				}
			}
			if(anyFound)
			{
				this.curStage = curStage;
				return;
			}
		}

		switch(curStage)
		{
			default:
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

		var base = 'stages/$stage';
		var resolved:Null<String> = ModPaths.resolveWithExtensions(base, null, [".json", ".JSON"]);
		if(resolved == null)
			resolved = Paths.fileExists('$base.json') ? '$base.json' : null;
		if(resolved == null)
			return false;

		var raw:String = null;
		#if sys
		if(FileSystem.exists(resolved) && !FileSystem.isDirectory(resolved))
			raw = File.getContent(resolved);
		#end
		if(raw == null || raw.trim() == "")
			raw = ModPaths.readText(resolved);
		if(raw == null || raw.trim() == "")
			return false;

		var data:Dynamic = null;
		try {
			data = TJSON.parse(raw);
		} catch(e) {
			return false;
		}
		if(data == null)
			return false;

		var directory:String = stage;
		if(Reflect.hasField(data, "directory"))
			directory = Std.string(Reflect.field(data, "directory"));

		if(Reflect.hasField(data, "defaultZoom"))
			camZoom = Std.parseFloat(Std.string(Reflect.field(data, "defaultZoom")));
		if(Reflect.hasField(data, "gfVersion"))
			gfVersion = Std.string(Reflect.field(data, "gfVersion"));

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

		var sprites:Dynamic = Reflect.field(data, "sprites");
		var any:Bool = false;
		if(sprites != null && Std.isOfType(sprites, Array))
		{
			for(entry in (sprites:Array<Dynamic>))
			{
				if(entry == null) continue;
				var image:String = Std.string(Reflect.field(entry, "image"));
				if(image == null || image.trim() == "") continue;
				var x:Float = Std.parseFloat(Std.string(Reflect.field(entry, "x")));
				var y:Float = Std.parseFloat(Std.string(Reflect.field(entry, "y")));
				if(Math.isNaN(x)) x = 0;
				if(Math.isNaN(y)) y = 0;
				var scrollX:Float = Reflect.hasField(entry, "scrollX") ? Std.parseFloat(Std.string(Reflect.field(entry, "scrollX"))) : 1;
				var scrollY:Float = Reflect.hasField(entry, "scrollY") ? Std.parseFloat(Std.string(Reflect.field(entry, "scrollY"))) : 1;
				var scale:Float = Reflect.hasField(entry, "scale") ? Std.parseFloat(Std.string(Reflect.field(entry, "scale"))) : 1;
				var foregroundSprite:Bool = Reflect.hasField(entry, "foreground") ? (Reflect.field(entry, "foreground") == true) : false;
				var pathBase = 'stages/$directory/$image';

				var spr:FlxSprite = new FlxSprite(x, y);
				var useAtlas:Bool = false;
				if(Paths.fileExists('$pathBase.xml'))
				{
					spr.frames = Paths.getSparrowAtlas(pathBase);
					useAtlas = spr.frames != null;
				}
				if(!useAtlas && Paths.fileExists('$pathBase.png'))
					spr.loadGraphic(Paths.image(pathBase));
				spr.scrollFactor.set(scrollX, scrollY);
				spr.scale.set(scale, scale);
				spr.updateHitbox();
				var animations:Dynamic = Reflect.field(entry, "animations");
				if(useAtlas && animations != null && Std.isOfType(animations, Array))
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
