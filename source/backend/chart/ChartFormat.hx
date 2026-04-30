package backend.chart;

typedef ChartMeta = {
	var version:Int;
	var song:String;
	var difficulty:String;
}

typedef ChartNote = {
	var time:Float;
	var lane:Int;
	var length:Float;
	var kind:String;
}

typedef ChartEvent = {
	var time:Float;
	var name:String;
	var value1:String;
	var value2:String;
}

typedef ChartDataV2 = {
	var meta:ChartMeta;
	var bpm:Float;
	var changes:Array<{time:Float, bpm:Float}>;
	var notes:Array<ChartNote>;
	var events:Array<ChartEvent>;
}
