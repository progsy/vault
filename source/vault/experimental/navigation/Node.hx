package vault.experimental.navigation;

class Node {
	public var x:Float = Math.NaN;
	public var y:Float = Math.NaN;
	public var z:Float = Math.NaN;

	public var flags:Int = 1;
	public var weight:Float = 1.0;
	@:ignore public var connectionCount:Int = 0;

	inline function new() {}

	public inline function isValid():Bool {
		return !Math.isNaN(x);
	}
}
