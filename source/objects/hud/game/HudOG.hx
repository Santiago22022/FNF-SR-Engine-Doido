package objects.hud.game;

import flixel.math.FlxPoint;
import backend.song.Conductor;
import backend.song.Timings;
import flixel.FlxSprite;
import flixel.group.FlxGroup;
import flixel.math.FlxMath;
import flixel.text.FlxText;
import flixel.util.FlxColor;
import flixel.ui.FlxBar;
import flixel.tweens.FlxEase;
import flixel.tweens.FlxTween;
import objects.hud.HudClass.IconChange;
import states.PlayState;
import flixel.util.FlxStringUtil;

class HudOG extends HudClass
{
	public var infoTxt:FlxText;
	public var timeBar:FlxBar;
	public var timeTxt:FlxText;
	
	var botplaySin:Float = 0;
	var botplayTxt:FlxText;
	var badScoreTxt:FlxText;

	// health bar
	public var healthBar:DoidoBar;
	public var iconP1:HealthIcon;
	public var iconP2:HealthIcon;

	public function new()
	{
		super("OG");
		add(ratingGrp);
		
		// --- Health Bar ---
		healthBar = new DoidoBar("hud/base/healthBar", "hud/base/healthBarBorder");
        healthBar.sideL.color = 0xFFFF0000;
        healthBar.sideR.color = 0xFF66FF33;
		add(healthBar);
		
		final SONG = PlayState.SONG;
		iconP1 = new HealthIcon();
		changeIcon(SONG.player1, PLAYER);
		add(iconP1);

		iconP2 = new HealthIcon();
		changeIcon(SONG.player2, ENEMY);
		add(iconP2);
		
		// --- Info Text ---
		infoTxt = new FlxText(0, 0, FlxG.width, "Score: 0 | Misses: 0 | Rating: ?");
		infoTxt.setFormat(Main.gFont, 20, 0xFFFFFFFF, CENTER);
		infoTxt.setBorderStyle(OUTLINE, FlxColor.BLACK, 1.25);
		add(infoTxt);
		
		// --- Time Bar (Psych Style) ---
		timeTxt = new FlxText(0, 19, 400, "SONG NAME", 32);
		timeTxt.setFormat(Main.gFont, 32, FlxColor.WHITE, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		timeTxt.scrollFactor.set();
		timeTxt.alpha = 0;
		timeTxt.borderSize = 2;

		timeBar = new FlxBar(0, 0, LEFT_TO_RIGHT, 400, 19, this, 'songPercent', 0, 1);
		timeBar.scrollFactor.set();
		timeBar.createFilledBar(0xFF000000, 0xFFFFFFFF);
		timeBar.numDivisions = 800; // Smoother
		timeBar.alpha = 0;

		add(timeBar);
		add(timeTxt);
		
		// --- Extra Texts ---
		badScoreTxt = new FlxText(0,0,0,"SCORE WILL NOT BE SAVED");
		badScoreTxt.setFormat(Main.gFont, 26, 0xFFFF0000, CENTER);
		badScoreTxt.setBorderStyle(OUTLINE, FlxColor.BLACK, 1.5);
		badScoreTxt.screenCenter(X);
		badScoreTxt.visible = false;
		add(badScoreTxt);
		
		botplayTxt = new FlxText(0,0,0,"BOTPLAY");
		botplayTxt.setFormat(Main.gFont, 32, 0xFFFFFFFF, CENTER);
		botplayTxt.setBorderStyle(OUTLINE, FlxColor.BLACK, 1.25);
		botplayTxt.screenCenter();
		botplayTxt.visible = false;
		add(botplayTxt);

		updatePositions();
		for(i in [infoTxt, healthBar, iconP1, iconP2, timeBar, timeTxt])
			alphaList.push(i);
	}

	public var songPercent:Float = 0;

	override function updateInfoTxt()
	{
		super.updateInfoTxt();
		// Psych Style Formatting
		infoTxt.text = 'Score: ' + FlxStringUtil.formatMoney(Timings.score, false, true) + 
					   ' | Misses: ' + Timings.misses + 
					   ' | Rating: ' + (Timings.getRank() != "N/A" ? Timings.getRank() + ' (' + Timings.accuracy + '%)' : '?');
	}

	public function updateIconPos()
	{
		var healthBarPos = FlxPoint.get(
			healthBar.x + FlxMath.lerp(healthBar.border.width, 0, healthBar.percent / 100),
			healthBar.y - (healthBar.border.height / 2)
		);

		// Psych logic: Icons move dynamically based on health
		var iconOffset:Int = 26;
		iconP1.x = healthBarPos.x + (150 * iconP1.scale.x - 150) / 2 - iconOffset;
		iconP2.x = healthBarPos.x - (150 * iconP2.scale.x) / 2 - iconOffset * 2;
		
		iconP1.y = healthBar.y - (iconP1.height / 2);
		iconP2.y = healthBar.y - (iconP2.height / 2);
	}

	override function updatePositions()
	{
		super.updatePositions();
		healthBar.x = (FlxG.width / 2) - (healthBar.border.width / 2);
		healthBar.y = (downscroll ? 0.11 * FlxG.height : 0.89 * FlxG.height);
		
		infoTxt.y = healthBar.y + (downscroll ? -30 : 30);
		
		timeBar.x = FlxG.width / 2 - timeBar.width / 2;
		timeBar.y = (downscroll ? FlxG.height - 31 : 19);
		
		timeTxt.text = PlayState.SONG.song.toUpperCase();
		timeTxt.size = 24; // Smaller for HUD
		timeTxt.y = timeBar.y + (timeBar.height / 2) - (timeTxt.height / 2);
		timeTxt.x = timeBar.x + (timeBar.width / 2) - (timeTxt.width / 2);

		badScoreTxt.y = healthBar.y + (downscroll ? 100 : -100);
	}

	override function update(elapsed:Float)
	{
		super.update(elapsed);
		healthBar.percent = (health * 50);
		
		// Update Time Bar
		var curTime:Float = Conductor.songPos - backend.game.SaveData.data.get("Note Offset");
		if(curTime < 0) curTime = 0;
		songPercent = (curTime / PlayState.songLength);
		if (songPercent > 1) songPercent = 1;
		
		botplayTxt.visible = PlayState.botplay;
		badScoreTxt.visible = !PlayState.validScore;
		
		if(botplayTxt.visible)
		{
			botplaySin += elapsed * Math.PI;
			botplayTxt.alpha = 0.5 + Math.sin(botplaySin) * 0.8;
		}

		for(icon in [iconP1, iconP2])
		{
			// Psych Engine Icon Bumping
			var mult:Float = FlxMath.lerp(1, icon.scale.x, Math.exp(-elapsed * 9));
			icon.scale.set(mult, mult);
			
			if(!icon.isPlayer)
				icon.setAnim(2 - health);
			else
				icon.setAnim(health);
			
			icon.updateHitbox();
		}
		updateIconPos();
	}

	override function addRating(rating:Rating)
	{
		// Psych Engine Rating Placement (Centered)
		super.addRating(rating);
		
		// Rating is a FlxGroup, use setPos instead of direct x/y assignment
		var centerX = FlxG.width / 2;
		var centerY = FlxG.height / 2;
		
		rating.setPos(centerX - 40, centerY - 60); // Offset to center
		
		if(rating.assetModifier == "pixel")
		{
			rating.setPos(centerX - 20, centerY - 40);
		}
		rating.playRating();
	}

	override function changeIcon(newIcon:String = "face", type:IconChange = ENEMY)
	{
		super.changeIcon(newIcon, type);
		var isPlayer:Bool = (type == PLAYER);
		var icon = (isPlayer ? iconP1 : iconP2);
		icon.setIcon(newIcon, isPlayer);
	}

	override function beatHit(curBeat:Int = 0)
	{
		super.beatHit(curBeat);
		if(curBeat % 2 == 0) // Changed to every 2 beats for simpler bop, can be 1
		{
			for(icon in [iconP1, iconP2])
			{
				icon.scale.set(1.2, 1.2);
				icon.updateHitbox();
			}
			updateIconPos();
		}
	}
}