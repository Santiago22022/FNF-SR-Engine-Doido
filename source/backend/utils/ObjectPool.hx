package backend.utils;

import flixel.group.FlxGroup.FlxTypedGroup;
import flixel.FlxSprite;

/**
 * A generic object pool for FlxSprite objects.
 * Helps to avoid garbage collection by recycling objects.
 */
class ObjectPool<T:FlxSprite>
{
	public var group:FlxTypedGroup<T>;
	private var _class:Class<T>;
	private var _factory:Void->T;
	private var _reset:T->Void;

	/**
	 * @param ObjClass The class of the objects to pool.
	 * @param initialSize The initial number of objects to create.
	 */
	public function new(ObjClass:Class<T>, initialSize:Int = 0, ?factory:Void->T, ?reset:T->Void)
	{
		_class = ObjClass;
		_factory = factory;
		_reset = reset;
		group = new FlxTypedGroup<T>(initialSize);
		for (i in 0...initialSize)
		{
			group.add(create());
		}
	}

	private function create():T
	{
		if (_factory != null)
			return _factory();
		
		return Type.createInstance(_class, []);
	}

	/**
	 * Get an object from the pool. Creates a new one if none are available.
	 */
	public function get():T
	{
		var obj = group.recycle(_class, _factory, false, true);
		if(_reset != null)
			_reset(obj);
		return obj;
	}

	/**
	 * Recycle an object back into the pool by killing it.
	 */
	public function recycle(obj:T)
	{
		obj.kill();
	}

	/**
	 * Recycle all objects in the pool.
	 */
	public function recycleAll()
	{
		group.forEach(function(member:T) {
			recycle(member);
		});
	}
}
