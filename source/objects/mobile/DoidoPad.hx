package objects.mobile;

import flixel.FlxG;
import flixel.group.FlxSpriteGroup;
import flixel.ui.FlxButton;
import flixel.input.FlxInput.FlxInputState;
import flixel.util.FlxTimer;

class DoidoPad extends FlxSpriteGroup
{
	public var padActive:Bool = false;

	var buttonWidth:Float = 105;
	var buttonMap:Map<String, PadButton> = [];
	var mode:String = "blank";
	var resizeHandlerAdded:Bool = false;

	inline function addNavigationButtons()
	{
		var margin:Float = 12;
		var baseX:Float = margin + buttonWidth;
		var baseY:Float = FlxG.height - buttonWidth - margin;

		inline function addNav(id:String, offsetX:Float, offsetY:Float, path:String)
		{
			var button:PadButton = new PadButton(baseX + offsetX, baseY + offsetY, path);
			buttonMap.set(id, button);
			add(button);
		}

		addNav("UI_UP", 0, -buttonWidth, 'navigation/up');
		addNav("UI_DOWN", 0, 0, 'navigation/down');
		addNav("UI_LEFT", -buttonWidth, 0, 'navigation/left');
		addNav("UI_RIGHT", buttonWidth, 0, 'navigation/right');
	}

	public function new(mode:String = "blank"):Void
	{
		super();
		this.mode = mode;
		padActive = true;
		buttonWidth = computeButtonWidth();

		buildButtons();
		togglePad(true);
		FlxG.signals.gameResized.add(onResize);
		resizeHandlerAdded = true;
	}

	public function togglePad(active:Bool)
	{
		if(active)
			padActive = (Lambda.count(buttonMap) > 0);
		else
			padActive = false;

		for (button in buttonMap) {
			if(padActive)
				button.alpha = (SaveData.data.get("Button Opacity") / 10);
			else
				button.alpha = 0;
		}
	}

	// buttons get manually destroyed when changing states
	override public function destroy():Void
	{
		super.destroy();
		padActive = false;

		if(resizeHandlerAdded)
		{
			FlxG.signals.gameResized.remove(onResize);
			resizeHandlerAdded = false;
		}

		for (button in buttonMap)
			button.destroy();

		buttonMap = [];
	}

	public function checkButton(buttonID:String, inputState:FlxInputState):Bool
	{
		if(!padActive)
			return false;
		
		var button = buttonMap.get(buttonID);
		if(button != null)
		{
			switch(inputState) {
				case PRESSED:
					return button.pressed;
				case RELEASED:
					return button.released;
				case JUST_PRESSED:
					return button.justPressed && !button.justReleased;
				case JUST_RELEASED:
					return button.justReleased;
			}
		}
		return false;
	}

	inline function computeButtonWidth():Float
	{
		var target:Float = FlxG.width * 0.09;
		if(target < 90) target = 90;
		if(target > 150) target = 150;
		return target;
	}

	function clearButtons()
	{
		for(button in buttonMap)
		{
			remove(button, true);
			button.destroy();
		}
		buttonMap = [];
	}

	function buildButtons()
	{
		clearButtons();
		buttonWidth = computeButtonWidth();

		switch (mode)
		{
			case "pause":
				var button:PadButton = new PadButton(FlxG.width - buttonWidth, 0, 'util/pause', 0.8);
				buttonMap.set("PAUSE", button);
				add(button);
			case "back":
				var button:PadButton = new PadButton(FlxG.width - buttonWidth, 0, 'util/back', 0.8);
				buttonMap.set("BACK", button);
				add(button);

			case "reset":
				var button:PadButton = new PadButton(FlxG.width - buttonWidth, 0, 'util/back', 0.8);
				buttonMap.set("BACK", button);
				add(button);

				var button:PadButton = new PadButton(FlxG.width - (buttonWidth*2), 0, 'util/reset', 0.8);
				buttonMap.set("RESET", button);
				add(button);

				addNavigationButtons();

			case "dialogue":
				var button:PadButton = new PadButton(FlxG.width - buttonWidth, 0, 'util/skip', 0.8);
				buttonMap.set("BACK", button);
				add(button);

				var button:PadButton = new PadButton(FlxG.width - (buttonWidth*2), 0, 'util/log', 0.8);
				buttonMap.set("TEXT_LOG", button);
				add(button);

			case "menu":
				var button:PadButton = new PadButton(FlxG.width - buttonWidth, 0, 'util/back', 0.8);
				buttonMap.set("BACK", button);
				add(button);

				addNavigationButtons();
		}
	}

	function onResize(w:Int, h:Int)
	{
		buildButtons();
		togglePad(padActive);
	}

	public function anyButtonActive(inputState:FlxInputState):Bool
	{
		if(!padActive)
			return false;

		for (button in buttonMap)
		{
			switch(inputState) {
				case PRESSED: if(button.pressed) return true;
				case RELEASED: if(button.released) return true;
				case JUST_PRESSED: if(button.justPressed) return true;
				case JUST_RELEASED: if(button.justReleased) return true;
			}
		}
		return false;
	}
}

class PadButton extends FlxButton
{
	public function new(x:Float, y:Float, path:String, scale:Float = 1)
	{
		super();

		if (Paths.fileExists('images/mobile/buttons/${path}.png'))
			loadGraphic(Paths.getGraphic('mobile/buttons/$path'));
		else
			loadGraphic(Paths.getGraphic('mobile/buttons/default.png'));

		solid = false;
		immovable = true;

		this.scale.set(scale, scale);
		updateHitbox();

		this.x = x;
		this.y = y;
	}
}
