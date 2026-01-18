#if !macro
//Discord API
#if DISCORD_ALLOWED
import psych_core.backend.Discord;
#end

//Psych
#if LUA_ALLOWED
import llua.*;
import llua.Lua;
#end

#if ACHIEVEMENTS_ALLOWED
import psych_core.backend.Achievements;
#end

#if sys
import sys.*;
import sys.io.*;
#elseif js
import js.html.*;
#end

import psych_core.backend.Paths;
import psych_core.backend.Controls;
import psych_core.backend.CoolUtil;
import psych_core.backend.MusicBeatState;
import psych_core.backend.MusicBeatSubstate;
import psych_core.backend.CustomFadeTransition;
import psych_core.backend.ClientPrefs;
import psych_core.backend.Conductor;
import psych_core.backend.BaseStage;
import psych_core.backend.Difficulty;
import psych_core.backend.Mods;
import psych_core.backend.Language;

import psych_core.backend.ui.*; //Psych-UI

import psych_core.objects.Alphabet;
import psych_core.objects.BGSprite;

import psych_core.states.PlayState;
import psych_core.states.LoadingState;

#if flxanimate
import psych_core.flxanimate.*;
import psych_core.flxanimate.PsychFlxAnimate as FlxAnimate;
#end

//Flixel
import flixel.sound.FlxSound;
import flixel.FlxG;
import flixel.FlxSprite;
import flixel.FlxCamera;
import flixel.math.FlxMath;
import flixel.math.FlxPoint;
import flixel.util.FlxColor;
import flixel.util.FlxTimer;
import flixel.text.FlxText;
import flixel.tweens.FlxEase;
import flixel.tweens.FlxTween;
import flixel.group.FlxSpriteGroup;
import flixel.group.FlxGroup.FlxTypedGroup;
import flixel.addons.transition.FlxTransitionableState;

using StringTools;
#end

