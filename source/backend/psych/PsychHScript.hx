package backend.psych;

import crowplexus.iris.Iris;
import flixel.FlxG;
import flixel.FlxSprite;
import flixel.group.FlxGroup;
import states.PlayState;
import backend.psych.BGSprite;
import backend.system.Logs;
import objects.note.EventNote;

class PsychHScript
{
	public static function implement(script:Iris, game:PlayState)
	{
		// Basic Flixel exposure
		script.set("FlxG", FlxG);
		script.set("FlxSprite", FlxSprite);
		script.set("FlxTimer", flixel.util.FlxTimer);
		script.set("FlxTween", flixel.tweens.FlxTween);
		script.set("FlxEase", flixel.tweens.FlxEase);
		script.set("BGSprite", BGSprite); // Our port
		
		// Game Object Access
		script.set("game", game);
		script.set("getInstance", function() return game);
		
		// Function Mapping (Psych API style)
		
		script.set("add", function(obj:Dynamic) {
			game.add(obj);
		});
		
		script.set("insert", function(pos:Int, obj:Dynamic) {
			game.insert(pos, obj);
		});
		
		script.set("remove", function(obj:Dynamic) {
			game.remove(obj);
		});

		// Property Access (HScript allows direct access usually, but for compat with getProperty)
		script.set("getProperty", function(variable:String) {
			var split = variable.split('.');
			var obj:Dynamic = game;
			if(split.length > 1) {
				for(i in 0...split.length-1) {
					obj = Reflect.getProperty(obj, split[i]);
					if(obj == null) return null;
				}
				return Reflect.getProperty(obj, split[split.length-1]);
			}
			return Reflect.getProperty(game, variable);
		});

		script.set("setProperty", function(variable:String, value:Dynamic) {
			var split = variable.split('.');
			var obj:Dynamic = game;
			if(split.length > 1) {
				for(i in 0...split.length-1) {
					obj = Reflect.getProperty(obj, split[i]);
					if(obj == null) return;
				}
				Reflect.setProperty(obj, split[split.length-1], value);
			} else {
				Reflect.setProperty(game, variable, value);
			}
		});
		
		// Lua-style sprite creation helpers (ported to Haxe)
		script.set("makeLuaSprite", function(tag:String, image:String, x:Float, y:Float) {
			var spr = new FlxSprite(x, y);
			if(image != null && image.length > 0) spr.loadGraphic(Paths.image(image));
			script.set(tag, spr);
			// Ideally we should track this in a map to allow getObject(tag)
			// For now, it just creates it and sets the variable in the script
			return spr;
		});
		
		script.set("makeAnimatedLuaSprite", function(tag:String, image:String, x:Float, y:Float) {
			var spr = new FlxSprite(x, y);
			if(image != null && image.length > 0) spr.frames = Paths.getSparrowAtlas(image);
			script.set(tag, spr);
			return spr;
		});
		
		script.set("luaDebugMode", false);
		script.set("debugPrint", function(text:String) {
			Logs.print(text, TRACE);
		});
		
		// Event & Sound functions
		script.set("triggerEvent", function(name:String, v1:String, v2:String) {
			var event = new EventNote();
			event.eventName = name;
			event.value1 = v1;
			event.value2 = v2;
			@:privateAccess game.onEventHit(event);
		});
		
		script.set("playSound", function(sound:String, ?volume:Float = 1, ?tag:String = null) {
			flixel.FlxG.sound.play(Paths.sound(sound), volume);
		});
		
		script.set("characterDance", function(char:String) {
			var obj:Dynamic = null;
			switch(char) {
				case 'dad': obj = game.dad.char;
				case 'gf': obj = game.gf.char;
				default: obj = game.boyfriend.char;
			}
			if(obj != null && Reflect.hasField(obj, "dance"))
				obj.dance();
		});
		
		script.set("playAnim", function(obj:String, anim:String, ?forced:Bool = false) {
			// Psych usually maps 'boyfriend', 'dad' to characters
			if(obj == 'boyfriend') { game.boyfriend.char.playAnim(anim, forced); return; }
			if(obj == 'dad') { game.dad.char.playAnim(anim, forced); return; }
			if(obj == 'gf') { game.gf.char.playAnim(anim, forced); return; }
			
			// Custom objects
			@:privateAccess {
				var spr:FlxSprite = script.interp.variables.get(obj);
				if(spr != null) {
					if(spr.animation.getByName(anim) != null)
						spr.animation.play(anim, forced);
				}
			}
		});
		
		// Tweens
		script.set("doTweenX", function(tag:String, obj:String, value:Float, duration:Float, ease:String) {
			var spr:Dynamic = null;
			@:privateAccess spr = script.interp.variables.get(obj);
			if(spr == null) {
				// Try finding by name in game
				if(obj == 'boyfriend') spr = game.boyfriend;
				else if(obj == 'dad') spr = game.dad;
				else if(obj == 'gf') spr = game.gf;
				else if(obj == 'camGame') spr = game.camGame;
				else if(obj == 'camHUD') spr = game.camHUD;
			}
			if(spr != null)
				flixel.tweens.FlxTween.tween(spr, {x: value}, duration, {ease: getEase(ease)});
		});
		
		script.set("doTweenY", function(tag:String, obj:String, value:Float, duration:Float, ease:String) {
			var spr:Dynamic = null;
			@:privateAccess spr = script.interp.variables.get(obj);
			if(spr == null) {
				if(obj == 'boyfriend') spr = game.boyfriend;
				else if(obj == 'dad') spr = game.dad;
				else if(obj == 'gf') spr = game.gf;
				else if(obj == 'camGame') spr = game.camGame;
				else if(obj == 'camHUD') spr = game.camHUD;
			}
			if(spr != null)
				flixel.tweens.FlxTween.tween(spr, {y: value}, duration, {ease: getEase(ease)});
		});
		
		script.set("doTweenAlpha", function(tag:String, obj:String, value:Float, duration:Float, ease:String) {
			var spr:Dynamic = null;
			@:privateAccess spr = script.interp.variables.get(obj);
			if(spr != null)
				flixel.tweens.FlxTween.tween(spr, {alpha: value}, duration, {ease: getEase(ease)});
		});

		script.set("cameraShake", function(camera:String, intensity:Float, duration:Float) {
			var cam = (camera == 'camHUD') ? game.camHUD : game.camGame;
			cam.shake(intensity, duration);
		});
		
		script.set("screenCenter", function(obj:String, ?axes:String = "XY") {
			var spr:FlxSprite = null;
			@:privateAccess spr = script.interp.variables.get(obj);
			if(spr != null) {
				if(axes == null) axes = "XY";
				if(axes.toUpperCase() == "XY") spr.screenCenter();
				else if(axes.toUpperCase() == "X") spr.screenCenter(flixel.util.FlxAxes.X);
				else if(axes.toUpperCase() == "Y") spr.screenCenter(flixel.util.FlxAxes.Y);
			}
		});
	}
	
	static function getEase(ease:String):Dynamic {
		// Basic implementation, expand as needed
		return switch(ease.toLowerCase()) {
			case 'linear': flixel.tweens.FlxEase.linear;
			case 'quadin': flixel.tweens.FlxEase.quadIn;
			case 'quadout': flixel.tweens.FlxEase.quadOut;
			case 'quadinout': flixel.tweens.FlxEase.quadInOut;
			case 'cubein': flixel.tweens.FlxEase.cubeIn;
			case 'cubeout': flixel.tweens.FlxEase.cubeOut;
			case 'cubeinout': flixel.tweens.FlxEase.cubeInOut;
			default: flixel.tweens.FlxEase.linear;
		}
	}
}
