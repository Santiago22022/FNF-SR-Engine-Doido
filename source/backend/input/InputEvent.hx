package backend.input;

enum InputEventType {
	Press;
	Release;
}

typedef InputEvent = {
	var type:InputEventType;
	var lane:Int;
	var timeMs:Float;
}
