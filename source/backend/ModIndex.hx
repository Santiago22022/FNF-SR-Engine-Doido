package backend;

import backend.system.ModLoader;
import backend.system.ModTypes.ModInfo;

/**
 * Thin facade over ModLoader for menu/state code.
 * Keeps UI code decoupled from loader internals.
 */
class ModIndex
{
	public static function refresh():Array<ModInfo>
		return ModLoader.refresh().copy();

	public static function getAllMods():Array<ModInfo>
		return ModLoader.getAllMods().copy();

	public static function getActiveMods():Array<ModInfo>
		return ModLoader.getActiveMods().copy();
	
	/**
	 * Returns mods that are active AND have 'runsGlobally' set to true.
	 * Useful for global scripts.
	 */
	public static function getGlobalMods():Array<ModInfo>
		return ModLoader.globalMods.copy();

	public static function getInvalidMods():Array<ModInfo>
		return ModLoader.getInvalidMods().copy();

	public static function getEnabledIds():Array<String>
	{
		var out:Array<String> = [];
		for(mod in ModLoader.getActiveMods())
			out.push(mod.id);
		return out;
	}

	/**
	 * The directory (ID) of the highest priority active mod.
	 * Equivalent to Psych Engine's Mods.currentModDirectory.
	 */
	public static var currentModDirectory(get, never):String;
	static function get_currentModDirectory():String return ModLoader.currentModDirectory;

	public static function find(id:String):Null<ModInfo>
		return ModLoader.getMod(id);

	public static function setEnabled(ids:Array<String>):Void
		ModLoader.setEnabledIds(ids);

	public static function setOrder(order:Array<String>):Void
		ModLoader.setOrder(order);

	public static function setOrderAndEnabled(order:Array<String>, enabled:Array<String>):Void
		ModLoader.setOrderAndEnabled(order, enabled);

	/**
	 * Merges text files from all active mods (e.g. for introText.txt).
	 */
	public static function loadTextFileList(key:String):Array<String>
		return ModLoader.loadTextFileList(key);
}