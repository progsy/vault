package vault.navigation;

private class Vector {
	public var x:Float;
	public var y:Float;
	public var z:Float;

	public inline function new(x:Float = 0.0, y:Float = 0.0, z:Float = 0.0) {
		this.x = x;
		this.y = y;
		this.z = z;
	}
}

@:access(vault.navigation)
class Path {
	public var length(default, null):Int;
	public var pathfinder(default, null):Pathfinder;
	public var version(default, null):Int;
	public var smoothingAllowed(get, never):Bool;
	public var smoothed(default, null):Bool;

	inline function get_smoothingAllowed() {
		return smoothPositions != null;
	}

	var smoothPositions:StructOfVectors<Vector>;
	var nodes:haxe.ds.Vector<NodeHandle>;
	var distances:haxe.ds.Vector<Float>;
	#if sys
	var back:Path;
	#end

	public function new(capacity:Int, allowSmoothing:Bool = true #if sys, allowBack:Bool = true #end) {
		if (capacity < 1) {
			throw 'Capacity must not be less than 1';
		}
		nodes = new haxe.ds.Vector(capacity);
		distances = new haxe.ds.Vector(capacity);
		if (allowSmoothing) {
			smoothPositions = new StructOfVectors<Vector>(capacity);
		}
		#if sys
		if (allowBack) {
			back = new Path(capacity, false, false);
		}
		#end
	}

	public function smooth(smoothFactor:Float = 0.5):Bool {
		if (length == 0 || smoothed || !smoothingAllowed) {
			return true;
		}
		inline function lerp(a:Float, b:Float, k:Float):Float {
			return a + k * (b - a);
		}
		var firstNode = nodes[0];
		var firstNodeIndex = firstNode.index;
		var lastNode = nodes[length - 1];
		var lastNodeIndex = lastNode.index;
		smoothPositions.x[0] = pathfinder.nodes.x[firstNodeIndex];
		smoothPositions.y[0] = pathfinder.nodes.y[firstNodeIndex];
		smoothPositions.z[0] = pathfinder.nodes.z[firstNodeIndex];
		smoothPositions.x[length - 1] = pathfinder.nodes.x[lastNodeIndex];
		smoothPositions.y[length - 1] = pathfinder.nodes.y[lastNodeIndex];
		smoothPositions.z[length - 1] = pathfinder.nodes.z[lastNodeIndex];
		for (i in 1...length - 1) {
			var currentNode = nodes[i];
			var currentNodeIndex = currentNode.index;
			var nextNode = nodes[i + 1];
			var nextNodeIndex = nextNode.index;
			var previousNode = nodes[i - 1];
			var previousNodeIndex = previousNode.index;
			var point = new Vector(pathfinder.nodes.x[currentNodeIndex], pathfinder.nodes.y[currentNodeIndex], pathfinder.nodes.z[currentNodeIndex]);
			var nextPoint = new Vector(pathfinder.nodes.x[nextNodeIndex], pathfinder.nodes.y[nextNodeIndex], pathfinder.nodes.z[nextNodeIndex]);
			var previousPoint = new Vector(pathfinder.nodes.x[previousNodeIndex], pathfinder.nodes.y[previousNodeIndex], pathfinder.nodes.z[previousNodeIndex]);
			smoothPositions.x[i] = point.x = lerp(point.x, lerp(previousPoint.x, nextPoint.x, 0.5), smoothFactor);
			smoothPositions.y[i] = point.y = lerp(point.y, lerp(previousPoint.y, nextPoint.y, 0.5), smoothFactor);
			smoothPositions.z[i] = point.z = lerp(point.z, lerp(previousPoint.z, nextPoint.z, 0.5), smoothFactor);
		}
		return smoothed = true;
	}

	public inline function getNode(offset:Int = 0):Node {
		var node = new Node();
		if (length >= 1) {
			var localIndex = (length - 1) - offset;
			var nodeHandle = nodes[localIndex];
			var nodeIndex = nodeHandle.index;
			var nodeGeneration = nodeHandle.generation;
			if (!pathfinder.nodes.freed[nodeIndex] && pathfinder.nodes.generation[nodeIndex] == nodeGeneration) {
				if (smoothed) {
					node.x = smoothPositions.x[localIndex];
					node.y = smoothPositions.y[localIndex];
					node.z = smoothPositions.z[localIndex];
				} else {
					node.x = pathfinder.nodes.x[nodeIndex];
					node.y = pathfinder.nodes.y[nodeIndex];
					node.z = pathfinder.nodes.z[nodeIndex];
				}
				node.flags = pathfinder.nodes.flags[nodeIndex];
				node.weight = pathfinder.nodes.weight[nodeIndex];
				node.connectionCount = pathfinder.nodes.connectionCount[nodeIndex];
			}
		}
		return node;
	}

	public inline function clear() {
		length = 0;
	}

	#if sys
	public function sync() {
		for (i in 0...back.length) {
			nodes[i] = back.nodes[i];
			distances[i] = back.distances[i];
		}
		length = back.length;
		version = back.version;
		pathfinder = back.pathfinder;
		smoothed = back.smoothed;
	}
	#end

	public inline function getDistance(nodeOffset:Int = 0):Float {
		var d = 0.0;
		for (i in 0...Std.int(Math.max(nodes.length - nodeOffset, 0))) {
			d += distances[i];
		}
		return d;
	}
}
