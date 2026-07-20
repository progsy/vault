package vault.experimental.navigation;

class Node {
	public var x:Float;
	public var y:Float;
	public var z:Float;

	public var flags:Int = 1;
	public var weight:Float = 1.0;
	@:ignore public var firstEdge:Int = -1;
}
