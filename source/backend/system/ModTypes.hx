package backend.system;

typedef ModInfo = {
	var id:String;
	var name:String;
	var version:String;
	var description:String;
	var priority:Int;
	var enabled:Bool;
	var path:String;
	var type:String;
	var icon:Null<String>;
	var assetRoots:Array<String>;
	var authors:Array<String>;
	var license:Null<String>;
	var engineVersion:Null<String>;
	var dependencies:Array<String>;
	var conflicts:Array<String>;
}
