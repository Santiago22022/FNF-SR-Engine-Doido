package objects;

import flixel.FlxSprite;
import flixel.math.FlxPoint;
import flixel.util.FlxAxes;
import flxanimate.FlxAnimate;
import backend.utils.CharacterUtil;
import backend.utils.CharacterUtil.*;
import objects.note.Note;
import tjson.TJSON;

using StringTools;

class Character extends FlxAnimate
{
	// dont mess with these unless you know what youre doing!
	// they are used in important stuff
	public var curChar:String = "bf";
	public var isPlayer:Bool = false;
	public var onEditor:Bool = false;
	public var specialAnim:Int = 0;
	public var curAnimFrame(get, never):Int;
	public var curAnimFinished(get, never):Bool;
	public var holdTimer:Float = Math.NEGATIVE_INFINITY;

	// time (in seconds) that takes to the character return to their idle anim
	public var holdLength:Float = 0.7;
	// when (in frames) should the character singing animation reset when pressing long notes
	public var holdLoop:Int = 4;

	// modify these for your liking (idle will cycle through every array value)
	public var idleAnims:Array<String> = ["idle"];
	public var altIdle:String = "";
	public var altSing:String = "";
	
	// true: dances every beat // false: dances every other beat
	public var quickDancer:Bool = false;

	// warning, only uses this
	// if the current character doesnt have game over anims
	public var deathChar:String = "bf-dead";

	// you can modify these manually but i reccomend using the offset editor instead
	public var globalOffset:FlxPoint = new FlxPoint();
	public var cameraOffset:FlxPoint = new FlxPoint();
	private var scaleOffset:FlxPoint = new FlxPoint();

	// you're probably gonna use sparrow by default?
	var spriteType:SpriteType = SPARROW;

	public function new(curChar:String = "bf", isPlayer:Bool = false, onEditor:Bool = false)
	{
		super(0,0,false);
		this.onEditor = onEditor;
		this.isPlayer = isPlayer;
		this.curChar = curChar.toLowerCase().trim();
		curChar = this.curChar;
		
		antialiasing = FlxSprite.defaultAntialiasing;
		isPixelSprite = false;
		
		var doidoChar = CharacterUtil.defaultChar();
		var charData:Dynamic = null;
		
		var jsonPaths:Array<String> = [
			'images/characters/_offsets/${curChar}',
			'images/characters/${curChar}',
			'characters/${curChar}',
			'data/characters/${curChar}'
		];

		Logs.print('Attempting to load character: $curChar', TRACE);
		for(path in jsonPaths)
		{
			if(Paths.fileExists(path + '.json'))
			{
				try {
					var rawJson = Paths.getContent(path + '.json');
					if(rawJson != null && rawJson.length > 0) {
						charData = TJSON.parse(rawJson);
						Logs.print('Successfully loaded character data from: $path.json', TRACE);
						break;
					}
				} catch(e) {
					Logs.print('Error parsing JSON at $path.json: $e', ERROR);
				}
			}
		}

		if(charData == null)
			Logs.print('No configuration JSON found for character: $curChar. Using defaults.', WARNING);

		if(charData != null)
		{
			try {
				if(Reflect.hasField(charData, "image") && Reflect.hasField(charData, "animations"))
				{
					var img:String = Reflect.field(charData, "image");
					if(img == null || img.length == 0)
						img = 'characters/face';
					
					if(img.indexOf("/") == -1)
						img = 'characters/$img';
					
					doidoChar.spritesheet = img;
					var psychAnims:Array<Dynamic> = Reflect.field(charData, "animations");
					for (anim in psychAnims)
					{
						if(anim == null) continue;
						var name:String = Reflect.field(anim, "anim");
						var symbol:String = Reflect.field(anim, "name");
						if(name == null || symbol == null) continue;
						
						var fps:Int = 24;
						try { fps = Reflect.field(anim, "fps"); } catch(e) {}
						var loop:Bool = false;
						try { loop = Reflect.field(anim, "loop"); } catch(e) {}
						var indices:Array<Int> = Reflect.field(anim, "indices");
						
						if (indices != null && indices.length > 0)
							doidoChar.anims.push([name, symbol, fps, loop, indices]);
						else
							doidoChar.anims.push([name, symbol, fps, loop]);
	
						var off:Array<Float> = Reflect.field(anim, "offsets");
						if (off != null && off.length >= 2)
							addOffset(name, off[0], off[1]);
					}
					
					if (Reflect.hasField(charData, "no_antialiasing"))
						antialiasing = !Reflect.field(charData, "no_antialiasing");
					if (Reflect.hasField(charData, "flip_x"))
						flipX = Reflect.field(charData, "flip_x");
					
					if (Reflect.hasField(charData, "scale"))
					{
						var s:Float = 1;
						try { s = Std.parseFloat(Std.string(Reflect.field(charData, "scale"))); } catch(e) { s = 1; }
						scale.set(s, s);
					}

					// Psych Engine character position offset (shifts character relative to stage position)
					if (Reflect.hasField(charData, "position"))
					{
						var pos:Array<Dynamic> = Reflect.field(charData, "position");
						if(pos != null && pos.length >= 2)
						{
							var px:Float = Std.parseFloat(Std.string(pos[0]));
							var py:Float = Std.parseFloat(Std.string(pos[1]));
							if(!Math.isNaN(px)) globalOffset.x = px;
							if(!Math.isNaN(py)) globalOffset.y = py;
						}
					}

					// Psych Engine camera position offset (shifts camera when focusing on this character)
					if (Reflect.hasField(charData, "camera_position"))
					{
						var cam:Array<Dynamic> = Reflect.field(charData, "camera_position");
						if(cam != null && cam.length >= 2)
						{
							var cx:Float = Std.parseFloat(Std.string(cam[0]));
							var cy:Float = Std.parseFloat(Std.string(cam[1]));
							if(!Math.isNaN(cx)) cameraOffset.x = cx;
							if(!Math.isNaN(cy)) cameraOffset.y = cy;
						}
					}
				}
				else
				{
					if(Reflect.hasField(charData, "spritesheet"))
						doidoChar.spritesheet = Reflect.field(charData, "spritesheet");
					if(Reflect.hasField(charData, "anims"))
						doidoChar.anims = Reflect.field(charData, "anims");
					if(Reflect.hasField(charData, "extrasheets"))
						doidoChar.extrasheets = Reflect.field(charData, "extrasheets");
				}
			} catch(e) {
				Logs.print('Error processing character data for $curChar: $e', ERROR);
			}
		}

		switch(curChar)
		{
			case "zero":
				doidoChar.spritesheet += 'zero/zero';
				doidoChar.anims = [
					["idle", 	 'idle', 24, false],
					['intro', 	'intro', 24, false],

					["singLEFT", 'left', 24, false],
					["singDOWN", 'down', 24, false],
					["singUP",   'up', 	 24, false],
					["singRIGHT",'right',24, false],
				];
				isPixelSprite = true;
				scale.set(12,12);
			case "gemamugen":
				doidoChar.spritesheet += 'gemamugen/gemamugen';
				doidoChar.anims = [
					["idle", 	 'idle', 24, true],
					['idle-alt', 'chacharealsmooth', 24, true],

					["singLEFT", 'left', 24, false],
					["singDOWN", 'down', 24, false],
					["singUP",   'up', 	 24, false],
					["singRIGHT",'right',24, false],
				];
				scale.set(2,2);
			
			case "senpai" | "senpai-angry":
				doidoChar.spritesheet = 'characters/senpai/senpai';

				if(curChar == "senpai") {
					doidoChar.anims = [
						['idle', 		'Senpai Idle instance 1', 		24, false],
						['singLEFT', 	'SENPAI LEFT NOTE instance 1', 	24, false],
						['singDOWN', 	'SENPAI DOWN NOTE instance 1', 	24, false],
						['singUP', 		'SENPAI UP NOTE instance 1', 	24, false],
						['singRIGHT', 	'SENPAI RIGHT NOTE instance 1',	24, false],
					];
				} else {
					doidoChar.anims = [
						['idle', 		'Angry Senpai Idle instance 1', 		24, false],
						['singLEFT', 	'Angry Senpai LEFT NOTE instance 1', 	24, false],
						['singDOWN', 	'Angry Senpai DOWN NOTE instance 1', 	24, false],
						['singUP', 		'Angry Senpai UP NOTE instance 1', 		24, false],
						['singRIGHT', 	'Angry Senpai RIGHT NOTE instance 1',	24, false],
					];
				}
				isPixelSprite = true;
				scale.set(6,6);
				
			case "spirit":
				doidoChar.spritesheet += 'senpai/spirit';
				doidoChar.anims = [
					['idle', 		"idle spirit_", 24, true],
					['singLEFT', 	"left_", 		24, false],
					['singDOWN', 	"spirit down_", 24, false],
					['singUP', 		"up_", 			24, false],
					['singRIGHT', 	"right_", 		24, false],
				];

				isPixelSprite = true;
				scale.set(6,6);
				
			case "bf-pixel":
				deathChar = "bf-pixel-dead";
				doidoChar.spritesheet += 'bf-pixel/bfPixel';
				doidoChar.anims = [
					['idle', 			'BF IDLE', 		24, false],
					['singUP', 			'BF UP NOTE', 	24, false],
					['singLEFT', 		'BF LEFT NOTE', 24, false],
					['singRIGHT', 		'BF RIGHT NOTE',24, false],
					['singDOWN', 		'BF DOWN NOTE', 24, false],
					['singUPmiss', 		'BF UP MISS', 	24, false],
					['singLEFTmiss', 	'BF LEFT MISS', 24, false],
					['singRIGHTmiss', 	'BF RIGHT MISS',24, false],
					['singDOWNmiss', 	'BF DOWN MISS', 24, false],
				];

				flipX = true;
				isPixelSprite = true;
				scale.set(6,6);

				if(!isPlayer)
					invertDirections(X);

			case "bf-pixel-dead":
				deathChar = "bf-pixel-dead";
				doidoChar.spritesheet += 'bf-pixel/bfPixelsDEAD';
				doidoChar.anims = [
					['firstDeath', 		"BF Dies pixel",24, false, CoolUtil.intArray(55)],
					['deathLoop', 		"Retry Loop", 	24, true],
					['deathConfirm', 	"RETRY CONFIRM",24, false],
				];

				idleAnims = ["firstDeath"];

				flipX = true;
				scale.set(6,6);
				isPixelSprite = true;
				
			case "gf-pixel":
				doidoChar.spritesheet += 'gf-pixel/gfPixel';
				doidoChar.anims = [
					['danceLeft', 	"GF IDLE", 24, false, [30, 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14]],
					['danceRight', 	"GF IDLE", 24, false, [15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27, 28, 29]],
				];

				idleAnims = ["danceLeft", "danceRight"];
				
				scale.set(6,6);
				isPixelSprite = true;
				quickDancer = true;
				flipX = isPlayer;
			
			case 'luano-day'|'luano-night':
				var pref:String = (curChar == 'luano-night') ? 'night ' : '';
				doidoChar.spritesheet += 'luano/luano';
				doidoChar.anims = [
					['idle', 		'${pref}idle', 24, false],
					['singLEFT', 	'${pref}left', 24, false],
					['singDOWN', 	'${pref}down', 24, false],
					['singUP', 		'${pref}up',   24, false],
					['singRIGHT', 	'${pref}right',24, false],
					['jump', 		'${pref}jump', 24, false],
				];

				holdLoop = 0;
			
			case 'spooky'|'spooky-player':
				doidoChar.spritesheet += 'spooky/SpookyKids';
				doidoChar.anims = [
					['danceLeft',	'Idle', 12, false, [0,2,4,8]],
					['danceRight',	'Idle', 12, false, [10,12,14,16]],

					['singLEFT',	'SingLEFT', 24, false],
					['singDOWN', 		'SingDOWN', 24, false],
					['singUP', 			'SingUP',   24, false],
					['singRIGHT',	'SingRIGHT',24, false],
				];
				
				idleAnims = ["danceLeft", "danceRight"];
				quickDancer = true;

				if(curChar == 'spooky-player')
					invertDirections(X);
			
			case "pico":
				doidoChar.spritesheet += 'pico/Pico_Basic';
				doidoChar.extrasheets = ['characters/pico/Pico_Playable'];

				doidoChar.anims = [
					['idle',		'Pico Idle Dance', 24, false],
					['singRIGHT',	'Pico NOTE LEFT0', 24, false],
					['singDOWN', 	'Pico Down Note0', 24, false],
					['singUP', 		'pico Up note0',   24, false],
					['singLEFT',	'Pico Note Right0',24, false],

					['singRIGHTmiss',	'Pico Left Note MISS', 24, false],
					['singDOWNmiss',	'Pico Down Note MISS', 24, false],
					['singUPmiss', 		'Pico Up Note MISS',   24, false],
					['singLEFTmiss',	'Pico Right Note MISS',24, false],
				];
				flipX = true;

			case "gf":
				spriteType = ATLAS;
				doidoChar.spritesheet += 'gf/gf-spritemap';
				doidoChar.anims = [
					['sad',			'gf sad',			24, false, [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12]],
					['danceLeft',	'GF Dancing Beat',	24, false, [30, 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14]],
					['danceRight',	'GF Dancing Beat',	24, false, [15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27, 28, 29]],
					
					['cheer', 		'GF Cheer', 	24, false],
					['singLEFT', 	'GF left note', 24, false],
					['singRIGHT', 	'GF Right Note',24, false],
					['singUP', 		'GF Up Note', 	24, false],
					['singDOWN', 	'GF Down Note', 24, false],
				];

				idleAnims = ["danceLeft", "danceRight"];
				quickDancer = true;
				flipX = isPlayer;
			
			case "no-gf":
				doidoChar.spritesheet += 'gf/no-gf/no-gf';
				doidoChar.anims = [
					['idle', 'idle'],
				];

			case "dad":
				doidoChar.spritesheet += 'dad/DADDY_DEAREST';
				doidoChar.anims = [
					['idle', 		'Dad idle dance', 		24, false],
					['singUP', 		'Dad Sing Note UP', 	24, false],
					['singRIGHT', 	'Dad Sing Note RIGHT', 	24, false],
					['singDOWN', 	'Dad Sing Note DOWN', 	24, false],
					['singLEFT', 	'Dad Sing Note LEFT', 	24, false],

					['idle-loop', 		'Dad idle dance', 		24, true, [11,12,13,14]],
					['singUP-loop', 	'Dad Sing Note UP', 	24, true, [3,4,5,6]],
					['singRIGHT-loop',	'Dad Sing Note RIGHT', 	24, true, [3,4,5,6]],
					['singLEFT-loop', 	'Dad Sing Note LEFT', 	24, true, [3,4,5,6]],
				];
			
			default: // case "bf"
				if(doidoChar.anims.length == 0)
				{
					if(!["bf", "face"].contains(curChar))
						curChar = (isPlayer ? "bf" : "face");

					if(curChar == "bf")
					{
						doidoChar.spritesheet += 'bf/BOYFRIEND';
						doidoChar.anims = [
							['idle', 			'BF idle dance', 		24, false],
							['singUP', 			'BF NOTE UP0', 			24, false],
							['singLEFT', 		'BF NOTE LEFT0', 		24, false],
							['singRIGHT', 		'BF NOTE RIGHT0', 		24, false],
							['singDOWN', 		'BF NOTE DOWN0', 		24, false],
							['singUPmiss', 		'BF NOTE UP MISS', 		24, false],
							['singLEFTmiss', 	'BF NOTE LEFT MISS', 	24, false],
							['singRIGHTmiss', 	'BF NOTE RIGHT MISS', 	24, false],
							['singDOWNmiss', 	'BF NOTE DOWN MISS', 	24, false],
							['hey', 			'BF HEY', 				24, false],
							['scared', 			'BF idle shaking', 		24, true],
						];
						
						flipX = true;
					}
					else if(curChar == "face")
					{
						spriteType = ATLAS;
						doidoChar.spritesheet += 'face';
						doidoChar.anims = [
							['idle', 			'idle-alive', 		24, false],
							['idlemiss', 		'idle-dead', 		24, false],

							['singLEFT', 		'left-alive', 		24, false],
							['singDOWN', 		'down-alive', 		24, false],
							['singUP', 			'up-alive', 		24, false],
							['singRIGHT', 		'right-alive', 		24, false],
							['singLEFTmiss', 	'left-dead', 		24, false],
							['singDOWNmiss', 	'down-dead', 		24, false],
							['singUPmiss', 		'up-dead', 			24, false],
							['singRIGHTmiss', 	'right-dead', 		24, false],
						];
					}
				}
				this.curChar = curChar;
			
			case "bf-dead":
				doidoChar.spritesheet += 'bf/BOYFRIEND';
				doidoChar.anims = [
					['firstDeath', 		"BF dies", 			24, false],
					['deathLoop', 		"BF Dead Loop", 	24, true],
					['deathConfirm', 	"BF Dead confirm", 	24, false],
				];

				idleAnims = ['firstDeath'];
				
				flipX = true;
		}

		if(isPixelSprite) antialiasing = false;

		try {
			if(spriteType != ATLAS)
			{
				if(Paths.fileExists('images/${doidoChar.spritesheet}.txt')) {
					frames = Paths.getPackerAtlas(doidoChar.spritesheet);
					spriteType = PACKER;
					Logs.print('Loaded Packer Atlas for $curChar', TRACE);
				}
				else if(Paths.fileExists('images/${doidoChar.spritesheet}.json')) {
					frames = Paths.getAsepriteAtlas(doidoChar.spritesheet);
					spriteType = ASEPRITE;
					Logs.print('Loaded Aseprite Atlas for $curChar', TRACE);
				}
				else if(doidoChar.extrasheets != null) {
					frames = Paths.getMultiSparrowAtlas(doidoChar.spritesheet, doidoChar.extrasheets);
					spriteType = MULTISPARROW;
					Logs.print('Loaded Multi-Sparrow Atlas for $curChar', TRACE);
				}
				else {
					var xmlExists = Paths.fileExists('images/${doidoChar.spritesheet}.xml') || Paths.fileExists('images/${doidoChar.spritesheet}.XML');
					if(xmlExists) {
						frames = Paths.getSparrowAtlas(doidoChar.spritesheet);
						spriteType = SPARROW;
						Logs.print('Loaded Sparrow Atlas for $curChar', TRACE);
					} else {
						Logs.print('No atlas found for ${doidoChar.spritesheet} (tried .xml, .txt, .json)', WARNING);
						// fallback to BF to avoid crash?
					}
				}

				if(frames != null) {
					for(i in 0...doidoChar.anims.length)
					{
						var anim:Array<Dynamic> = doidoChar.anims[i];
						if(anim.length > 4)
							animation.addByIndices(anim[0],  anim[1], anim[4], "", anim[2], anim[3]);
						else
							animation.addByPrefix(anim[0], anim[1], anim[2], anim[3]);
					}
				}
			}
			else
			{
				// :shushing_face:
				isAnimateAtlas = true;
				var atlasPath = 'images/${doidoChar.spritesheet}';
				Logs.print('Loading Animate Atlas from $atlasPath', TRACE);
				loadAtlas(Paths.getPath(atlasPath));
				showPivot = false;
				for(i in 0...doidoChar.anims.length)
				{
					var dAnim:Array<Dynamic> = doidoChar.anims[i];
					if(dAnim.length > 4)
						anim.addBySymbolIndices(dAnim[0], dAnim[1], dAnim[4], dAnim[2], dAnim[3]);
					else
						anim.addBySymbol(dAnim[0], dAnim[1], dAnim[2], dAnim[3]);
				}
			}
		} catch(e) {
			Logs.print('CRITICAL ERROR loading frames for $curChar: $e', ERROR);
		}

		// adding animations to array
		try {
			for(i in 0...doidoChar.anims.length) {
				var daAnim = doidoChar.anims[i][0];
				if(animExists(daAnim) && !animList.contains(daAnim))
					animList.push(daAnim);
			}
		} catch(e) {
			Logs.print('Error adding animations to list for $curChar: $e', ERROR);
		}

		// prevents crashing
		if(animList.length > 0)
		{
			for(i in 0...idleAnims.length)
			{
				if(!animList.contains(idleAnims[i]))
					idleAnims[i] = animList[0];
			}
		}
		else
		{
			Logs.print('CRITICAL: No animations were loaded for $curChar!', ERROR);
			// Add a dummy animation to prevent crashes during playback
			animList.push('idle');
			idleAnims = ['idle'];
		}
		
		// offset gettin'
		if(charData != null && Reflect.hasField(charData, "animOffsets"))
		{
			try {
				var offsets:Array<Array<Dynamic>> = cast Reflect.field(charData, "animOffsets");
				for(i in 0...offsets.length)
				{
					var animData:Array<Dynamic> = offsets[i];
					if(animData != null && animData.length >= 3)
						addOffset(animData[0], animData[1], animData[2]);
				}
				
				var gOff:Array<Float> = cast Reflect.field(charData, "globalOffset");
				if(gOff != null && gOff.length >= 2)
					globalOffset.set(gOff[0], gOff[1]);
					
				var cOff:Array<Float> = cast Reflect.field(charData, "cameraOffset");
				if(cOff != null && cOff.length >= 2)
					cameraOffset.set(cOff[0], cOff[1]);
			} catch(e) {
				Logs.print('Error loading offsets for $curChar: $e', ERROR);
			}
		}
		
		if(animExists(idleAnims[0]))
			playAnim(idleAnims[0]);
		else if(animList.length > 0)
			playAnim(animList[0]);

		updateHitbox();
		scaleOffset.set(offset.x, offset.y);

		if(isPlayer)
			flipX = !flipX;

		dance();
	}

	private var curDance:Int = 0;

	public function dance(forced:Bool = false)
	{
		if(specialAnim > 0) return;

		switch(curChar)
		{
			default:
				var daIdle = idleAnims[curDance];
				if(animExists(daIdle + altIdle))
					daIdle += altIdle;
				playAnim(daIdle);
				curDance++;

				if (curDance >= idleAnims.length)
					curDance = 0;
		}
	}

	override public function update(elapsed:Float)
	{
		super.update(elapsed);
		if(!onEditor)
		{
			if(animExists(curAnimName + '-loop') && curAnimFinished)
				playAnim(curAnimName + '-loop');
	
			if(specialAnim > 0 && specialAnim != 3 && curAnimFinished)
			{
				specialAnim = 0;
				dance();
			}
		}
	}

	public var singAnims:Array<String> = ['singLEFT', 'singDOWN', 'singUP', 'singRIGHT'];
	public function playNote(note:Note, miss:Bool = false)
	{
		var daAnim:String = singAnims[note.noteData];
		if(animExists(daAnim + 'miss') && miss)
			daAnim += 'miss';

		if(animExists(daAnim + altSing))
			daAnim += altSing;

		holdTimer = 0;
		specialAnim = 0;
		playAnim(daAnim, true);
	}

	// animation handler
	public var curAnimName:String = '';
	public var animList:Array<String> = [];
	public var animOffsets:Map<String, Array<Float>> = [];

	public function addOffset(animName:String, offX:Float = 0, offY:Float = 0):Void
		return animOffsets.set(animName, [offX, offY]);

	public function playAnim(animName:String, ?forced:Bool = false, ?reversed:Bool = false, ?frame:Int = 0)
	{
		if(!animExists(animName)) return;
		
		curAnimName = animName;
		if(spriteType != ATLAS)
			animation.play(animName, forced, reversed, frame);
		else
			anim.play(animName, forced, reversed, frame);
		
		try
		{
			var daOffset = animOffsets.get(animName);
			offset.set(daOffset[0] * scale.x, daOffset[1] * scale.y);
		}
		catch(e)
			offset.set(0,0);

		// useful for pixel notes since their offsets are not 0, 0 by default
		offset.x += scaleOffset.x;
		offset.y += scaleOffset.y;
	}

	public function invertDirections(axes:FlxAxes = NONE)
	{
		switch(axes) {
			case X:
				singAnims = ['singRIGHT', 'singDOWN', 'singUP', 'singLEFT'];
			case Y:
				singAnims = ['singLEFT', 'singUP', 'singDOWN', 'singRIGHT'];
			case XY:
				singAnims = ['singRIGHT', 'singUP', 'singDOWN', 'singLEFT'];
			default:
				singAnims = ['singLEFT', 'singDOWN', 'singUP', 'singRIGHT'];
		}
	}

	public function pauseAnim()
	{
		if(spriteType != ATLAS)
			animation.pause();
		else
			anim.pause();
	}

	public function animExists(animName:String):Bool
	{
		if(spriteType != ATLAS)
			return animation.getByName(animName) != null;
		else
			return anim.getByName(animName) != null;
	}

	public function get_curAnimFrame():Int
	{
		if(spriteType != ATLAS)
			return animation.curAnim.curFrame;
		else
			return anim.curSymbol.curFrame;
	}

	public function get_curAnimFinished():Bool
	{
		if(spriteType != ATLAS)
			return animation.curAnim.finished;
		else
			return anim.finished;
	}
}