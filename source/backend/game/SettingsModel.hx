package backend.game;

import haxe.DynamicAccess;

typedef SettingsModel = {
	var schemaVersion:Int;
	var settings:DynamicAccess<Dynamic>;
}
