package vault.behavior;

class InternalStatusComponent {
	public var active:Bool;
	public var generation:Int;
	public var activeArrayIndex:Int = -1;
}

@:allow(vault.behavior.World)
@:autoBuild(vault.macro.System.build())
interface System {
	/**
		How many units we have.
	**/
	public var count(default, null):Int;

	/**
		Maximum number of units we can have.
	**/
	public var capacity(default, null):Int;

	public function update(dt:Float):Void;
}
