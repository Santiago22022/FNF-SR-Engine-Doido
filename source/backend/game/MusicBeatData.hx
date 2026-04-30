package backend.game;

import flixel.FlxCamera;
import flixel.FlxState;
import flixel.FlxSubState;
import flixel.addons.ui.FlxUIState;
import flixel.group.FlxGroup;
import backend.song.Conductor;
import backend.game.IStepHit;
import crowplexus.iris.Iris;

#if TOUCH_CONTROLS
import objects.mobile.*;
import flixel.FlxSubState;
#end

/*
	Custom state and substate classes. Use them instead of FlxState or FlxSubstate
*/

class MusicBeatState extends FlxUIState
{
	static inline var STEP_LOOP_CAP:Int = 2048;
	private var stepHitables:Array<IStepHit> = [];

	public function addStepHit(item:IStepHit)
	{
		if (!stepHitables.contains(item))
			stepHitables.push(item);
	}

	public function removeStepHit(item:IStepHit)
	{
		stepHitables.remove(item);
	}

	#if TOUCH_CONTROLS
	public var pad:DoidoPad;
	#end

	override function create()
	{
		super.create();
		Main.activeState = this;
		Logs.print('switched to ${Type.getClassName(Type.getClass(this))}');
		persistentDraw = true;
		persistentUpdate = false;
		
		Controls.setSoundKeys();

		if(!Main.skipClearMemory)
			Paths.clearMemory();
		
		if(!Main.skipTrans)
			openSubState(new GameTransition(true, Main.lastTransition));

		Iris.destroyAll();

		// go back to default automatically i dont want to do it
		Main.skipStuff(false);
		curStep = _curStep = Conductor.calcStateStep();
		curBeat = Math.floor(curStep / 4);

		#if TOUCH_CONTROLS
		createPad("blank");
		Controls.resetTimer();
		#end
	}

	private var _curStep = 0; // actual curStep
	private var curStep = 0;
	private var curBeat = 0;

	override function update(elapsed:Float)
	{
		super.update(elapsed);
		updateBeat();

		if(FlxG.keys.justPressed.F5) {
			Main.skipClearMemory = (!FlxG.keys.pressed.SHIFT);
			Main.skipTrans = true;
			Main.resetState();
		}
	}

	private function updateBeat()
	{
		_curStep = Conductor.calcStateStep();

		var loops:Int = 0;
		while(_curStep != curStep && loops < STEP_LOOP_CAP)
		{
			stepHit();
			loops++;
		}

		if(loops >= STEP_LOOP_CAP && _curStep != curStep)
		{
			curStep = _curStep;
			curBeat = Math.floor(curStep / 4);
		}
	}

	private function stepHit()
	{
		if(_curStep > curStep)
			curStep++;
		else
		{
			curStep = _curStep;
		}

		if(curStep % 4 == 0)
			beatHit();

		for (item in stepHitables)
		{
			item.stepHit(curStep);
		}
	}

	private function beatHit()
	{
		// finally you're useful for something
		curBeat = Math.floor(curStep / 4);
	}

	#if TOUCH_CONTROLS
	function createPad(mode:String = "blank", ?cameras:Array<FlxCamera>)
	{
		remove(pad);
		if(!Controls.shouldUseTouch())
		{
			pad = null;
			return;
		}
		pad = new DoidoPad(mode);

		if(mode != "blank") {
			if(cameras != null)
				pad.cameras = cameras;

			add(pad);
		}
	}

	override function openSubState(SubState:FlxSubState) {
		if(!(SubState is GameTransition) && pad != null)
			pad.togglePad(false);
		super.openSubState(SubState);
	}

	override function closeSubState() {
		if(pad != null)
			pad.togglePad(true);
		super.closeSubState();
	}
	#end

	override function destroy()
	{
		stepHitables = [];
		#if TOUCH_CONTROLS
		pad = null;
		#end
		super.destroy();
	}
}

class MusicBeatSubState extends FlxSubState
{
	static inline var STEP_LOOP_CAP:Int = 2048;
	private var stepHitables:Array<IStepHit> = [];

	public function addStepHit(item:IStepHit)
	{
		if (!stepHitables.contains(item))
			stepHitables.push(item);
	}

	public function removeStepHit(item:IStepHit)
	{
		stepHitables.remove(item);
	}

	var subParent:FlxState;

	#if TOUCH_CONTROLS
	public var pad:DoidoPad = new DoidoPad();
	#end

	override function create()
	{
		super.create();
		subParent = Main.activeState;
		Main.activeState = this;
		persistentDraw = true;
		persistentUpdate = false;
		curStep = _curStep = Conductor.calcStateStep();
		curBeat = Math.floor(curStep / 4);

		#if TOUCH_CONTROLS
		Controls.resetTimer();
		#end
	}
	
	override function close()
	{
		#if TOUCH_CONTROLS
		Controls.resetTimer();
		#end
		
		Main.activeState = subParent;
		super.close();
	}

	private var _curStep = 0; // actual curStep
	private var curStep = 0;
	private var curBeat = 0;

	override function update(elapsed:Float)
	{
		super.update(elapsed);
		updateBeat();
	}

	private function updateBeat()
	{
		_curStep = Conductor.calcStateStep();

		var loops:Int = 0;
		while(_curStep != curStep && loops < STEP_LOOP_CAP)
		{
			stepHit();
			loops++;
		}

		if(loops >= STEP_LOOP_CAP && _curStep != curStep)
		{
			curStep = _curStep;
			curBeat = Math.floor(curStep / 4);
		}
	}

	private function stepHit()
	{
		if(_curStep > curStep)
			curStep++;
		else
		{
			curStep = _curStep;
		}

		if(curStep % 4 == 0)
			beatHit();

		for (item in stepHitables)
		{
			item.stepHit(curStep);
		}
	}

	private function beatHit()
	{
		// finally you're useful for something
		curBeat = Math.floor(curStep / 4);
	}

	#if TOUCH_CONTROLS
	function createPad(mode:String = "blank", ?cameras:Array<FlxCamera>)
	{
		remove(pad);
		if(!Controls.shouldUseTouch())
		{
			pad = null;
			return;
		}
		pad = new DoidoPad(mode);

		if(mode != "blank") {
			if(cameras != null)
				pad.cameras = cameras;

			add(pad);
		}
	}
	#end

	override function destroy()
	{
		stepHitables = [];
		#if TOUCH_CONTROLS
		pad = null;
		#end
		super.destroy();
	}
}
