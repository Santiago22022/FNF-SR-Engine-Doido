package objects.mobile;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.group.FlxSpriteGroup;
import flixel.ui.FlxButton;
import flixel.tweens.FlxTween;
import flixel.tweens.FlxEase;
import flixel.input.FlxInput.FlxInputState;
import flixel.input.touch.FlxTouch;

class Hitbox extends FlxSpriteGroup
{
	var hint:FlxSprite;
	var hbxWidth:Float = 320;
	var hbxHeight:Float = 0;
	var hbxMap:Map<String, HitboxButton> = [];
	var touchActive:Array<Bool> = [false, false, false, false];
	var lastTouchId:Array<Int> = [-1, -1, -1, -1];

	var assetModifier:String = "base";
	var margin:Float = 16;
	var resizeHandlerAdded:Bool = false;
	static final VALID_STYLES:Array<String> = ["base", "doido", "pixel"];
	
	public function new(assetModifier:String = "base")
	{
		super();
		this.assetModifier = resolveStyle(assetModifier);

		hint = new FlxSprite(0, 0);
		hint.loadGraphic(Paths.image('mobile/hitbox/$assetModifier/hints'));
		hint.alpha = 0;
		add(hint);
		hbxHeight = hint.height;

		var directions = CoolUtil.directions;
		for (i in 0...directions.length) {
			var button = new HitboxButton(hbxWidth * i, hbxWidth, hbxHeight, directions[i], assetModifier);
			hbxMap.set(directions[i], button);
			add(button);
		}

		reflow();
		FlxG.signals.gameResized.add(onResize);
		resizeHandlerAdded = true;
	}

	public function toggleHbx(active)
	{
		hint.alpha = (active ? (SaveData.data.get("Hitbox Opacity") / 10) * 0.2 : 0);

		for(button in hbxMap)
		{
			button.isActive = active;
			button.setAlpha(false);
		}

		for(i in 0...touchActive.length)
		{
			touchActive[i] = false;
			lastTouchId[i] = -1;
		}
	}

	override public function destroy():Void
    {
        super.destroy();

		if(resizeHandlerAdded)
		{
			FlxG.signals.gameResized.remove(onResize);
			resizeHandlerAdded = false;
		}

		for(button in hbxMap)
			button.destroy();

		hbxMap = [];
    }

	public function checkButton(buttonID:String, inputState:FlxInputState):Bool
	{
		var dirIndex:Int = CoolUtil.directions.indexOf(buttonID);
		if(dirIndex == -1) return false;

		var button = hbxMap.get(buttonID);
		if(button == null || !button.isActive)
			return false;

		// track by touchId to keep holds alive even if fingers slide a bit
		refreshTouches();

		switch(inputState) {
			case PRESSED:
				return touchActive[dirIndex] || button.pressed;
			case JUST_PRESSED:
				return button.justPressed;
			case RELEASED | JUST_RELEASED:
				return (!touchActive[dirIndex] && button.justReleased);
			default:
				return false;
		}
	}

	function onResize(w:Int, h:Int)
		reflow();

	function refreshTouches():Void
	{
		// reset activity, will be marked true if touch still overlaps
		for(i in 0...touchActive.length)
			touchActive[i] = false;

		for(touch in FlxG.touches.list)
		{
			if(touch == null) continue;

			for(dir in CoolUtil.directions)
			{
				var idx = CoolUtil.directions.indexOf(dir);
				var button = hbxMap.get(dir);
				if(button == null || !button.isActive) continue;

				// reuse last touch ID to make holds stable
				if(lastTouchId[idx] != -1 && touchIDMatches(touch, lastTouchId[idx]) && button.overlapsPoint(touch.getWorldPosition()))
				{
					touchActive[idx] = true;
					continue;
				}

				// otherwise check overlap and assign
				if(button.overlapsPoint(touch.getWorldPosition()))
				{
					touchActive[idx] = true;
					lastTouchId[idx] = touch.touchPointID;
				}
			}
		}

		// clear dead touch IDs
		for(i in 0...touchActive.length)
			if(!touchActive[i])
				lastTouchId[i] = -1;
	}

	inline function touchIDMatches(touch:flixel.input.touch.FlxTouch, id:Int):Bool
		return touch != null && touch.touchPointID == id;

	inline function computeButtonWidth():Float
	{
		var target:Float = FlxG.width / CoolUtil.directions.length;
		if(target < 140) target = 140;
		if(target > 360) target = 360;
		return target;
	}

	function reflow():Void
	{
		hbxWidth = computeButtonWidth();

		var totalWidth:Float = hbxWidth * CoolUtil.directions.length;
		hint.setGraphicSize(Math.floor(totalWidth));
		hint.updateHitbox();

		hbxHeight = hint.height;
		var startX:Float = (FlxG.width - totalWidth) / 2;
		var startY:Float = FlxG.height - hbxHeight - margin;

		hint.x = startX;
		hint.y = startY;

		var i:Int = 0;
		for(dir in CoolUtil.directions)
		{
			var button = hbxMap.get(dir);
			if(button == null) continue;

			button.resize(hbxWidth, hbxHeight);
			button.x = startX + (hbxWidth * i);
			button.y = startY;
			i++;
		}
	}

	inline function resolveStyle(defaultStyle:String):String
	{
		var setting:Dynamic = SaveData.data.get("Hitbox Style");
		var chosen:String = (setting == null ? defaultStyle : Std.string(setting)).toLowerCase();

		if(!VALID_STYLES.contains(chosen))
			chosen = defaultStyle;

		if(!Paths.fileExists('images/mobile/hitbox/$chosen/hitbox.png'))
			chosen = "base";

		return chosen;
	}
}

class HitboxButton extends FlxButton
{
	public var isActive:Bool = false;
	var tween:FlxTween = null;

	public function new(x:Float, width:Float, height:Float, frame:String, assetModifier:String)
	{
		super(x, 0);

		loadGraphic(Paths.getFrame('mobile/hitbox/$assetModifier/hitbox', frame));
		alpha = 0;
		resize(width, height);

		onDown.callback = function () {
			setAlpha(true);
		};

		onUp.callback = function () {
			setAlpha(false);
		}
		
		onOut.callback = function () {
			setAlpha(false);
		}
		
		active = true;
	}

	public function resize(width:Float, height:Float)
	{
		if(graphic != null)
		{
			setGraphicSize(Math.floor(width), Math.floor(height));
			updateHitbox();
		}
	}
	
	public function setAlpha(visible:Bool = false)
	{
		if (tween != null)
			tween.cancel();

		if(!isActive) {
			alpha = 0;
			return;
		}

		if(visible)
			alpha = SaveData.data.get("Hitbox Opacity") / 10;
		else
			tween = FlxTween.num(
				alpha,
				0,
				0.15,
				{ease: FlxEase.circInOut},
				function (a:Float) {
					alpha = a;
				}
			);
	}
}
