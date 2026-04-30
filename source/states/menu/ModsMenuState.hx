package states.menu;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.group.FlxGroup.FlxTypedGroup;
import flixel.math.FlxMath;
import flixel.text.FlxText;
import flixel.util.FlxColor;
import backend.mobile.SafeArea;
import backend.mobile.UIScaler;
import backend.game.SaveData;
import Main;
import backend.system.ModLoader;
import backend.system.ModTypes.ModInfo;
import backend.system.ModConfig;
import states.menu.OptionsState;

class ModsMenuState extends MusicBeatState
{
	var mods:Array<ModInfo> = [];
	var list:FlxTypedGroup<FlxText>;
	var desc:FlxText;
	var header:FlxText;
	var help:FlxText;
	var selected:Int = 0;
	var dirty:Bool = false;
	var scrollOffset:Float = 0;
	var touchLastY:Float = 0;
	var isDragging:Bool = false;
	var cellHeight:Float = 36;
	var padding:Float = 12;

	override function create()
	{
		super.create();
		CoolUtil.playMusic("freakyMenu");
		SafeArea.init(SaveData.data.get("useSafeArea"));
		var uiScale = UIScaler.scale();
		cellHeight *= uiScale;
		padding *= uiScale;
		mods = ModLoader.getAllMods().copy();
		list = new FlxTypedGroup<FlxText>();

		var bg = new FlxSprite().makeGraphic(FlxG.width, FlxG.height, 0xFF0F0F1A);
		bg.scrollFactor.set();
		add(bg);

		header = new FlxText(SafeArea.safeRect.x + padding, SafeArea.safeRect.y + padding, SafeArea.safeRect.width - padding * 2, "Mods", Std.int(32 * uiScale));
		header.setFormat(Main.gFont, Std.int(32 * uiScale), FlxColor.WHITE, CENTER);
		header.scrollFactor.set();
		add(header);

		desc = new FlxText(SafeArea.safeRect.x + padding, SafeArea.safeRect.bottom - 96 * uiScale, SafeArea.safeRect.width - padding * 2, "", Std.int(20 * uiScale));
		desc.setFormat(Main.gFont, Std.int(20 * uiScale), FlxColor.WHITE, LEFT);
		desc.scrollFactor.set();
		add(desc);

		help = new FlxText(SafeArea.safeRect.x + padding, SafeArea.safeRect.bottom - 48 * uiScale, SafeArea.safeRect.width - padding * 2, "Enter: toggle | Left/Right: move priority | R: refresh | Esc/Back: save & exit", Std.int(18 * uiScale));
		help.setFormat(Main.gFont, Std.int(18 * uiScale), FlxColor.GRAY, LEFT);
		help.scrollFactor.set();
		add(help);

		add(list);
		rebuild();
	}

	function rebuild():Void
	{
		list.clear();
		if(mods.length == 0)
		{
			var empty = new FlxText(0, FlxG.height / 2 - 8, FlxG.width, "No mods found. Drop mods in /mods or assets/mods and press R to rescan.", 20);
			empty.setFormat(Main.gFont, 20, FlxColor.GRAY, CENTER);
			list.add(empty);
			desc.text = "";
			return;
		}

		var startY = header.y + header.height + padding;
		for(i in 0...mods.length)
		{
			var mod = mods[i];
			var enabledMark = mod.enabled ? "[ON] " : "[OFF]";
			var txt = new FlxText(SafeArea.safeRect.x + padding, startY + i * cellHeight + scrollOffset, SafeArea.safeRect.width - padding * 2, '${enabledMark}${mod.name} (${mod.id}) v${mod.version}', 22);
			txt.color = FlxColor.WHITE;
			txt.ID = i;
			list.add(txt);
		}
		clampScroll();
		updateSelection(0);
		updateDesc();
	}

	function updateSelection(change:Int):Void
	{
		if(mods.length == 0) return;
		selected = FlxMath.wrap(selected + change, 0, mods.length - 1);
		for(txt in list)
		{
			txt.alpha = (txt.ID == selected ? 1.0 : 0.6);
			if(txt.ID == selected)
				txt.color = mods[txt.ID].enabled ? FlxColor.LIME : FlxColor.GRAY;
			else
				txt.color = mods[txt.ID].enabled ? FlxColor.WHITE : 0xFF666666;
			txt.y = header.y + header.height + padding + txt.ID * cellHeight + scrollOffset;
		}
		updateDesc();
	}

	function updateDesc():Void
	{
		if(mods.length == 0)
		{
			desc.text = "";
			return;
		}
		var mod = mods[selected];
		var authors = (mod.authors != null && mod.authors.length > 0) ? mod.authors.join(", ") : "Unknown author";
		desc.text = '${mod.description}\n${authors} | target: ${mod.engineVersion == null ? "any" : mod.engineVersion}';
	}

	function toggleSelected():Void
	{
		if(mods.length == 0) return;
		mods[selected].enabled = !mods[selected].enabled;
		dirty = true;
		rebuild();
	}

	function moveSelected(delta:Int):Void
	{
		if(mods.length == 0) return;
		var newIndex = selected + delta;
		if(newIndex < 0 || newIndex >= mods.length)
			return;
		var cur = mods[selected];
		mods[selected] = mods[newIndex];
		mods[newIndex] = cur;
		selected = newIndex;
		dirty = true;
		rebuild();
	}

	function applyAndExit():Void
	{
		if(dirty)
		{
			ModConfig.persistFrom(mods);
			ModLoader.savePsychModsList(mods);
			ModLoader.refresh();
		}
		Main.switchState(new OptionsState());
	}

	function refreshMods():Void
	{
		ModLoader.refresh();
		mods = ModLoader.getAllMods().copy();
		selected = 0;
		dirty = false;
		rebuild();
	}

	override function update(elapsed:Float)
	{
		super.update(elapsed);

		#if FLX_TOUCH
		if(SaveData.data.get("useModMenuTouchList") && FlxG.touches != null && FlxG.touches.list.length > 0)
		{
			var touch = FlxG.touches.list[0];
			if(touch.justPressed)
			{
				isDragging = true;
				touchLastY = touch.screenY;
			}
			if(isDragging && touch.pressed)
			{
				var dy = touch.screenY - touchLastY;
				scrollOffset += dy;
				touchLastY = touch.screenY;
				clampScroll();
				updateSelection(0);
			}
			if(touch.justReleased)
				isDragging = false;
		}
		#end

		if(Controls.justPressed(UI_UP)) updateSelection(-1);
		if(Controls.justPressed(UI_DOWN)) updateSelection(1);

		if(Controls.justPressed(UI_LEFT)) moveSelected(-1);
		if(Controls.justPressed(UI_RIGHT)) moveSelected(1);

		if(Controls.justPressed(ACCEPT)) toggleSelected();

		if(FlxG.keys.justPressed.R)
			refreshMods();

		if(Controls.justPressed(BACK))
			applyAndExit();
	}

	function clampScroll():Void
	{
		var startY = header.y + header.height + padding;
		var contentHeight = mods.length * cellHeight;
		var minOffset = SafeArea.safeRect.bottom - help.height - padding - contentHeight - startY;
		if(minOffset > 0) minOffset = 0;
		if(scrollOffset > 0) scrollOffset = 0;
		if(scrollOffset < minOffset) scrollOffset = minOffset;
	}
}
