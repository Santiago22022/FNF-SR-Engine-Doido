package objects.mobile;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.group.FlxSpriteGroup;
import flixel.ui.FlxButton;
import flixel.tweens.FlxTween;
import flixel.tweens.FlxEase;
import flixel.input.FlxInput.FlxInputState;
import flixel.input.touch.FlxTouch;
import flixel.math.FlxRect;
import flixel.math.FlxPoint;
import flixel.util.FlxSpriteUtil;

class Hitbox extends FlxSpriteGroup
{
	var hint:FlxSprite;
	var hbxWidth:Float = 320;
	var hbxHeight:Float = 0;
	var hbxMap:Map<String, HitboxButton> = [];
	var touchActive:Array<Bool> = [false, false, false, false];
	var lastTouchId:Array<Int> = [-1, -1, -1, -1];
	var justPressedState:Array<Bool> = [false, false, false, false];
	var justReleasedState:Array<Bool> = [false, false, false, false];
	var touchBindings:Map<Int, String> = new Map(); // touchId -> direction

	var assetModifier:String = "base";
	var margin:Float = 16;
	var resizeHandlerAdded:Bool = false;
	static final VALID_STYLES:Array<String> = ["base", "doido", "pixel"];
	public var debugDraw:Bool = false;
	var debugLayer:FlxSprite;
	
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

		debugLayer = new FlxSprite().makeGraphic(FlxG.width, FlxG.height, 0x0, true);
		debugLayer.alpha = 0.6;
		debugLayer.visible = false;
		add(debugLayer);
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

	override public function update(elapsed:Float):Void
	{
		super.update(elapsed);
		refreshTouches();
		updateButtonVisuals();
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
				return touchActive[dirIndex];
			case JUST_PRESSED:
				return justPressedState[dirIndex];
			case RELEASED | JUST_RELEASED:
				return (!touchActive[dirIndex] && justReleasedState[dirIndex]);
			default:
				return false;
		}
	}

	function onResize(w:Int, h:Int)
		reflow();

	function refreshTouches():Void
	{
		for(i in 0...touchActive.length)
		{
			touchActive[i] = false;
			lastTouchId[i] = -1;
			justPressedState[i] = false;
			justReleasedState[i] = false;
		}

		// release bindings that ended
		var activeIds:Map<Int, Bool> = new Map();
		for(touch in FlxG.touches.list)
			if(touch != null)
				activeIds.set(touch.touchPointID, true);

		var dead:Array<Int> = [];
		for(id in touchBindings.keys())
			if(!activeIds.exists(id))
				dead.push(id);
		for(id in dead)
			touchBindings.remove(id);

		// release bindings that no longer overlap
		for(touch in FlxG.touches.list)
		{
			if(touch == null) continue;
			var dir = touchBindings.get(touch.touchPointID);
			if(dir != null)
			{
				var button = hbxMap.get(dir);
				if(button == null || !button.isActive || !overlapsButton(touch, button))
				{
					touchBindings.remove(touch.touchPointID);
					var idx = CoolUtil.directions.indexOf(dir);
					if(idx >= 0)
						justReleasedState[idx] = true;
				}
			}
		}

		// preserve existing bindings if still overlapping
		for(touch in FlxG.touches.list)
		{
			if(touch == null) continue;
			var dir = touchBindings.get(touch.touchPointID);
			if(dir != null)
			{
				var button = hbxMap.get(dir);
				if(button != null && button.isActive && overlapsButton(touch, button))
				{
					var idx = CoolUtil.directions.indexOf(dir);
					if(idx >= 0)
					{
						touchActive[idx] = true;
						lastTouchId[idx] = touch.touchPointID;
					}
					continue;
				}
				else
					touchBindings.remove(touch.touchPointID);
			}
		}

		// capture new touches
		for(touch in FlxG.touches.list)
		{
			if(touch == null) continue;
			if(touchBindings.exists(touch.touchPointID)) continue;

			var bestDir:String = null;
			var bestDist:Float = Math.POSITIVE_INFINITY;

			for(dir in CoolUtil.directions)
			{
				var button = hbxMap.get(dir);
				if(button == null || !button.isActive) continue;
				if(!overlapsButton(touch, button)) continue;

				var dist = distanceToCenter(touch, button);
				if(dist < bestDist)
				{
					bestDist = dist;
					bestDir = dir;
				}
			}

			if(bestDir != null)
			{
				touchBindings.set(touch.touchPointID, bestDir);
				var idx = CoolUtil.directions.indexOf(bestDir);
				if(idx >= 0)
				{
					touchActive[idx] = true;
					lastTouchId[idx] = touch.touchPointID;
					justPressedState[idx] = true;
				}
			}
		}

		// mark actives by bindings
		for(id => dir in touchBindings)
		{
			var idx = CoolUtil.directions.indexOf(dir);
			if(idx >= 0)
				touchActive[idx] = true;
		}
	}

	function overlapsButton(touch:FlxTouch, button:HitboxButton):Bool
	{
		if(touch == null || button == null) return false;
		var cam = (button.cameras != null && button.cameras.length > 0) ? button.cameras[0] : FlxG.camera;
		var pt = FlxPoint.get();
		touch.getWorldPosition(cam, pt);
		var result = button.overlapsPoint(pt, true, cam);
		pt.put();
		return result;
	}

	function distanceToCenter(touch:FlxTouch, button:HitboxButton):Float
	{
		var cam = (button.cameras != null && button.cameras.length > 0) ? button.cameras[0] : FlxG.camera;
		var pt = FlxPoint.get();
		touch.getWorldPosition(cam, pt);
		var dx = pt.x - (button.x + button.width / 2);
		var dy = pt.y - (button.y + button.height / 2);
		pt.put();
		return dx * dx + dy * dy;
	}

	function drawDebugLayer():Void
	{
		if(debugLayer == null) return;
		debugLayer.makeGraphic(FlxG.width, FlxG.height, 0x00000000, true);
		var cam = (cameras != null && cameras.length > 0) ? cameras[0] : FlxG.camera;
		for(dir in CoolUtil.directions)
		{
			var button = hbxMap.get(dir);
			if(button == null) continue;
			var rect = button.getScreenBounds(cam);
			flixel.util.FlxSpriteUtil.drawRect(debugLayer, rect.x, rect.y, rect.width, rect.height, 0x3344FF44);
		}

		for(touch in FlxG.touches.list)
		{
			if(touch == null) continue;
			var pt = FlxPoint.get();
			touch.getWorldPosition(cam, pt);
			flixel.util.FlxSpriteUtil.drawRect(debugLayer, pt.x - 4, pt.y - 4, 8, 8, 0x88FF0000);
			pt.put();
		}
	}

	function updateButtonVisuals():Void
	{
		for(dir in CoolUtil.directions)
		{
			var idx = CoolUtil.directions.indexOf(dir);
			var button = hbxMap.get(dir);
			if(button == null) continue;
			if(touchActive[idx])
				button.setAlpha(true);
			else if(!button.justPressed)
				button.setAlpha(false);
		}

		#if debug
		if(debugDraw)
			drawDebugLayer();
		if(debugLayer != null)
			debugLayer.visible = debugDraw;
		#end
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
