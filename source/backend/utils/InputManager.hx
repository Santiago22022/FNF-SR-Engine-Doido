package backend.utils;

import backend.game.Controls;
#if TOUCH_CONTROLS
import objects.mobile.Hitbox;
import objects.mobile.MobileInput.MobileInputType;
#end

class InputManager
{
	public var pressed:Array<Bool> = [false, false, false, false];
	public var justPressed:Array<Bool> = [false, false, false, false];
	public var released:Array<Bool> = [false, false, false, false];
	// buffer de unos frames para no perder taps cuando hay stutter
	public var holdFrames:Int = 1;
	var justPressedBuffer:Array<Int> = [0, 0, 0, 0];

	inline function setState(arr:Array<Bool>, idx:Int, value:Bool)
	{
		arr[idx] = value;
	}

    #if TOUCH_CONTROLS
    private var hitbox:Hitbox;
    #end

	public function new(#if TOUCH_CONTROLS hitbox:Hitbox #end)
	{
        #if TOUCH_CONTROLS
        this.hitbox = hitbox;
        #end
	}

	public function update():Void
	{
		setState(pressed, 0, Controls.pressed(LEFT));
		setState(pressed, 1, Controls.pressed(DOWN));
		setState(pressed, 2, Controls.pressed(UP));
		setState(pressed, 3, Controls.pressed(RIGHT));

		var freshJP:Array<Bool> = [
			Controls.justPressed(LEFT),
			Controls.justPressed(DOWN),
			Controls.justPressed(UP),
			Controls.justPressed(RIGHT)
		];
		for(i in 0...freshJP.length)
		{
			if(freshJP[i])
				justPressedBuffer[i] = holdFrames;

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
                    justPressedBuffer[i] = holdFrames;
                    justPressed[i] = true;
                }

                if(hitbox.checkButton(CoolUtil.directions[i], RELEASED))
                    released[i] = true;
            }
        }
		#end
	}
}
