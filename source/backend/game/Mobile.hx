package backend.game;

#if TOUCH_CONTROLS
import flixel.FlxG;
import flixel.input.touch.FlxTouch;
import flixel.input.FlxInput.FlxInputState;

class Mobile
{
    public static function getTap(inputState:FlxInputState):Bool
    {
        for (touch in FlxG.touches.list)
        {
            if(touch == null)
                continue;

            switch(inputState)
            {
                case PRESSED:
                    if(touch.pressed) return true;
                case RELEASED:
                    if(touch.released) return true;
                case JUST_PRESSED:
                    if(touch.justPressed) return true;
                case JUST_RELEASED:
                    if(touch.justReleased) return true;
                default:
            }
        }

        return getMouse(inputState);
    }

    // Used for mouse control on mobile
    public static function getMouse(inputState:FlxInputState):Bool
    {
        if(FlxG.mouse == null)
            return false;

        return switch(inputState)
        {
            case PRESSED: FlxG.mouse.pressed;
            case RELEASED: FlxG.mouse.released;
            case JUST_PRESSED: FlxG.mouse.justPressed;
            case JUST_RELEASED: FlxG.mouse.justReleased;
            default: false;
        };
    }

    public static function getSwipe(direction:String = "ANY"):Bool
    {
        switch (direction) {
            case "UP" | "UI_UP":
                return invert("Y") ? swipe(45, 135) : swipe(-135, -45);
            case "DOWN" | "UI_DOWN":
                return invert("Y") ? swipe(-135, -45) : swipe(45, 135);
            case "RIGHT" | "UI_RIGHT":
                return invert("X") ? swipe(135, -135, false) : swipe(-45, 45);
            case "LEFT" | "UI_LEFT":
                return invert("X") ? swipe(-45, 45) : swipe(135, -135, false);
            default:
                return getSwipe("UP") || getSwipe("DOWN") || getSwipe("LEFT") || getSwipe("RIGHT");
        }
    }

    static function swipe(lower:Int, upper:Int, and:Bool = true, distance:Int = 20):Bool
    {
        for (swipe in FlxG.swipes)
        {
            // distance check first to avoid tiny accidental swipes
            if(swipe.distance <= distance)
                continue;

            return (and ?
                ((swipe.degrees > lower && swipe.degrees < upper)):
                ((swipe.degrees > lower || swipe.degrees < upper))
            );
        }

        return false;
    }

    static function invert(axes:String):Bool
    {
        switch(SaveData.data.get("Invert Swipes"))
        {
            case "HORIZONTAL":
                return axes == "X";
            case "VERTICAL":
                return axes == "Y";
            case "BOTH":
                return true;
            default:
                return false;
        }
    }

    public static var back(get, never):Bool;

    private static function get_back():Bool
    {
        #if android
        return FlxG.android.justReleased.BACK;
        #else
        return false;
        #end
    }
}
#end
