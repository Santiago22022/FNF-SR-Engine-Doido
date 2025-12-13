package backend.utils;

import backend.game.Controls;
import flixel.FlxG;
#if TOUCH_CONTROLS
import objects.mobile.Hitbox;
import objects.mobile.MobileInput.MobileInputType;
#end

class InputManager
{
	static inline var DEFAULT_HOLD_MS:Int = 38; // ~2 frames at 60fps, scaled by FPS

	public var pressed:Array<Bool> = [false, false, false, false];
	public var justPressed:Array<Bool> = [false, false, false, false];
	public var released:Array<Bool> = [false, false, false, false];
	// buffer de unos frames para no perder taps cuando hay stutter
	// set to -1 for automatic scaling based on framerate
	public var holdFrames:Int = -1;
	var justPressedBuffer:Array<Int> = [0, 0, 0, 0];
	var freshJP:Array<Bool> = [false, false, false, false];

	inline function setState(arr:Array<Bool>, idx:Int, value:Bool)
	{
		arr[idx] = value;
	}

    #if TOUCH_CONTROLS
    private var hitbox:Hitbox;
    #end

    private var focusHandlerAdded:Bool = false;

	public function new(#if TOUCH_CONTROLS hitbox:Hitbox #end)
	{
        #if TOUCH_CONTROLS
        this.hitbox = hitbox;
        #end
		FlxG.signals.focusLost.add(clearStates);
		FlxG.signals.focusGained.add(clearStates);
		focusHandlerAdded = true;
	}

	public function update():Void
	{
		var hold:Int = computeHoldFrames();

		setState(pressed, 0, Controls.pressed(LEFT));
		setState(pressed, 1, Controls.pressed(DOWN));
		setState(pressed, 2, Controls.pressed(UP));
		setState(pressed, 3, Controls.pressed(RIGHT));

		freshJP[0] = Controls.justPressed(LEFT);
		freshJP[1] = Controls.justPressed(DOWN);
		freshJP[2] = Controls.justPressed(UP);
		freshJP[3] = Controls.justPressed(RIGHT);
		for(i in 0...freshJP.length)
		{
			if(freshJP[i])
				justPressedBuffer[i] = hold;

			if(justPressedBuffer[i] > 0)
			{
				setState(justPressed, i, true);
				justPressedBuffer[i]--;
			}
			else
				setState(justPressed, i, false);
		}

		setState(released, 0, Controls.released(LEFT));
		setState(released, 1, Controls.released(DOWN));
		setState(released, 2, Controls.released(UP));
		setState(released, 3, Controls.released(RIGHT));

		#if TOUCH_CONTROLS
        if (hitbox != null)
        {
            for(i in 0...CoolUtil.directions.length) {
                if(hitbox.checkButton(CoolUtil.directions[i], PRESSED))
                    pressed[i] = true;

                if(hitbox.checkButton(CoolUtil.directions[i], JUST_PRESSED))
                {
                    justPressedBuffer[i] = hold;
                    justPressed[i] = true;
                }

                if(hitbox.checkButton(CoolUtil.directions[i], RELEASED))
                    released[i] = true;
            }
        }
		#end
	}

	public function clearStates():Void
	{
		for(i in 0...pressed.length)
		{
			pressed[i] = false;
			justPressed[i] = false;
			released[i] = false;
			justPressedBuffer[i] = 0;
		}
	}

	public function destroy():Void
	{
		if(focusHandlerAdded)
		{
			FlxG.signals.focusLost.remove(clearStates);
			FlxG.signals.focusGained.remove(clearStates);
			focusHandlerAdded = false;
		}
	}

	inline function computeHoldFrames():Int
	{
		if(holdFrames >= 0)
		{
			var manual = holdFrames;
			if(manual < 0) manual = 0;
			if(manual > 12) manual = 12;
			return manual;
		}

		var fps:Float = FlxG.updateFramerate;
		if(fps <= 0) fps = 60;

		var frameMs:Float = 1000 / fps;
		var frames:Int = Math.ceil(DEFAULT_HOLD_MS / frameMs);
		if(frames < 1) frames = 1;
		if(frames > 6) frames = 6;
		return frames;
	}
}
