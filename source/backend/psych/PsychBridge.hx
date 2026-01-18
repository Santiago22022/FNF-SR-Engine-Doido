package backend.psych;

import flixel.FlxSprite;
import flixel.FlxG;
import flixel.group.FlxGroup;
import flixel.math.FlxPoint;
import backend.system.ModPaths;
import tjson.TJSON;
import states.PlayState;
import objects.Stage;
import crowplexus.iris.Iris;
import backend.system.Logs;
import backend.psych.StageData;
import backend.psych.PsychHScript;
import backend.song.Timings;
import backend.game.SaveData;

using StringTools;

class PsychBridge
{
	/**
	 * Carga un Stage usando el formato JSON de Psych Engine.
	 * Maneja la búsqueda de imágenes en carpetas raíz y la configuración de capas.
	 */
	public static function loadStage(stageInstance:Stage, stageName:String):Bool
	{
		if(stageName == null || stageName.trim() == "") return false;

		// 1. Obtener datos usando StageData (que ya maneja JSON y fallbacks)
		var stageFile:StageFile = StageData.getStageFile(stageName);
		if(stageFile == null || stageFile.directory == "") return false;

		Logs.print('PsychBridge: Loading stage $stageName using StageData', TRACE);
		StageData.forceNextDirectory = stageFile.directory;

		// 2. Configurar Datos del Stage
		stageInstance.camZoom = stageFile.defaultZoom;
		
		if(stageFile.gfVersion != null)
			stageInstance.gfVersion = stageFile.gfVersion;
			
		if(stageFile.hide_girlfriend)
			stageInstance.gfVersion = "no-gf";

		inline function setPos(target:FlxPoint, src:Array<Float>) {
			if(src != null && src.length >= 2) target.set(src[0], src[1]);
		}
		
		setPos(stageInstance.bfPos, [stageFile.boyfriend[0], stageFile.boyfriend[1]]);
		setPos(stageInstance.dadPos, [stageFile.opponent[0], stageFile.opponent[1]]);
		setPos(stageInstance.gfPos, [stageFile.girlfriend[0], stageFile.girlfriend[1]]);
		
		setPos(stageInstance.bfCam, stageFile.camera_boyfriend);
		setPos(stageInstance.dadCam, stageFile.camera_opponent);
		setPos(stageInstance.gfCam, stageFile.camera_girlfriend);

		// 3. Cargar Objetos usando StageData
		if(stageFile.objects != null)
		{
			var added = StageData.addObjectsToState(stageFile.objects, null, null, null, null);
			
			for(key => spr in added) {
				stageInstance.add(spr);
			}
		}

		return true;
	}

	/**
	 * Configura un script de Iris (HScript) con las variables globales de Psych Engine.
	 * Esto hace que los scripts .hx de Psych funcionen en Doido.
	 */
	public static function initPsychScript(script:Iris, game:PlayState):Void
	{
		// Variables Principales
		script.set("boyfriend", game.boyfriend);
		script.set("dad", game.dad);
		script.set("gf", game.gf);
		script.set("camGame", game.camGame);
		script.set("camHUD", game.camHUD);
		script.set("camOther", game.camOther);
		
		// Variables de Estado
		script.set("curBeat", 0); 
		script.set("curStep", 0);
		script.set("score", 0);
		script.set("misses", 0);
		script.set("hits", 0);
		script.set("health", PlayState.health);
		script.set("botPlay", SaveData.data.get("Botplay"));
		script.set("songName", PlayState.SONG.song);
		script.set("isStoryMode", PlayState.isStoryMode);
		script.set("difficulty", PlayState.songDiff);
		script.set("cameraX", 0);
		script.set("cameraY", 0);
		
		// Utilidades de Psych
		script.set("getColorFromHex", function(color:String) {
			if(!color.startsWith("0x")) color = "0xFF" + color.replace("#", "");
			return Std.parseInt(color);
		});
		
		// Implementar API Completa de HScript
		PsychHScript.implement(script, game);
	}
	
	public static function updateScriptVars(script:Iris, game:PlayState):Void
	{
		@:privateAccess {
			script.set("curBeat", game.curBeat);
			script.set("curStep", game.curStep);
		}
		script.set("health", PlayState.health);
		script.set("score", Timings.score);
		script.set("misses", Timings.misses);
		script.set("hits", Timings.notesHit);
	}
}