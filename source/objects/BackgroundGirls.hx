package objects;

import flixel.FlxSprite;
import backend.game.IStepHit;
import states.PlayState;
import backend.utils.CoolUtil;
import Paths;

class BackgroundGirls extends FlxSprite implements IStepHit
{
    public function new(x:Float, y:Float)
    {
        super(x, y);

        frames = Paths.getSparrowAtlas('stages/school/bgFreaks');
        scrollFactor.set(0.9, 0.9);
        
        var girlAnim:String = "girls group";
        if(PlayState.SONG != null && PlayState.SONG.song == 'roses') // Added null check for safety
            girlAnim = 'fangirls dissuaded';
        
        animation.addByIndices('danceLeft',  'BG $girlAnim', CoolUtil.intArray(14), "", 24, false);
        animation.addByIndices('danceRight', 'BG $girlAnim', CoolUtil.intArray(30, 15), "", 24, false);
        animation.play('danceLeft');
    }

    public function stepHit(curStep:Int):Void
    {
        if(curStep % 4 == 0)
        {
            if(animation.curAnim.name == 'danceLeft')
                animation.play('danceRight', true);
            else
                animation.play('danceLeft', true);
        }
    }
}
