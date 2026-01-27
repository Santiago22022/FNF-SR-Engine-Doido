package backend.input;

enum InputType {
	Press;
	Release;
}

class InputEvent
{
	public var type:InputType;
	public var lane:Int;
	public var timeMs:Float;
	public var next:InputEvent = null; // For linked list pooling

	public function new(type:InputType, lane:Int, timeMs:Float)
	{
		this.type = type;
		this.lane = lane;
		this.timeMs = timeMs;
	}

	public function set(type:InputType, lane:Int, timeMs:Float)
	{
		this.type = type;
		this.lane = lane;
		this.timeMs = timeMs;
		return this;
	}
}