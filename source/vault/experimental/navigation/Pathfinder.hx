package vault.experimental.navigation;

enum abstract PathMode(Int) {
	var Normal = 1;
	var ClosestPossible;
}

private class ConnectionData {
	public var target:NodeHandle;
	public var distance:Float;
}

private class ValidationData {
	@:ignore public var freed:Bool = false;
	@:ignore public var generation:Int = 0;
}

private class Searcher {
	@:ignore public var gScore:Float;
	@:ignore public var fScore:Float;
	@:ignore public var parent:NodeHandle;
	@:ignore public var searchId:Int = -1;
	@:ignore public var closedId:Int = -1;
	@:ignore public var heapIndex:Int = -1;
}

private class PendingChange {
	public var node:NodeHandle;
	public var flags:Int;
	public var weight:Float;
}

private class Request {
	public var callback:() -> Void;
	public var path:Path;
	public var mode:PathMode;
	public var flags:Int;
	public var sX:Float;
	public var sY:Float;
	public var sZ:Float;
	public var dX:Float;
	public var dY:Float;
	public var dZ:Float;
}

private class Heap {
	var currentId:Int;
	var nodes:Array<NodeHandle> = [];
	var length:Int;

	public function new(capacity:Int) {
		nodes.resize(capacity);
	}

	public inline function clear() {
		length = 0;
	}

	public inline function push(node:NodeHandle, searchers:StructOfVectors<Searcher>):Void {
		var heapIndex = length++;
		nodes[heapIndex] = node;
		searchers.heapIndex[node.index] = heapIndex;
		fetchUpper(heapIndex, searchers);
	}

	public inline function pop(searchers:StructOfVectors<Searcher>):NodeHandle {
		var top = nodes[0];
		searchers.heapIndex[top.index] = -1;
		length--;
		if (length > 0) {
			nodes[0] = nodes[length];
			searchers.heapIndex[nodes[0].index] = 0;
			fetchBottom(0, searchers);
		}
		return top;
	}

	public inline function fetchUpper(heapIndex:Int, searchers:StructOfVectors<Searcher>):Void {
		var node = nodes[heapIndex];
		var nodeIndex = node.index;
		while (heapIndex > 0) {
			var parentNodeHeapIndex = (heapIndex - 1) >> 1;
			var parentNode = nodes[parentNodeHeapIndex];
			var parentNodeIndex = parentNode.index;
			if (searchers.fScore[nodeIndex] < searchers.fScore[parentNodeIndex]) {
				nodes[heapIndex] = parentNode;
				searchers.heapIndex[parentNodeIndex] = heapIndex;
				heapIndex = parentNodeHeapIndex;
			} else {
				break;
			}
		}

		nodes[heapIndex] = node;
		searchers.heapIndex[nodeIndex] = heapIndex;
	}

	public inline function fetchBottom(heapIndex:Int, searchers:StructOfVectors<Searcher>):Void {
		var node = nodes[heapIndex];
		var nodeIndex = node.index;
		var f = searchers.fScore[nodeIndex];
		while (true) {
			var left = (heapIndex << 1) + 1;
			if (left >= length) {
				break;
			}

			var right = left + 1;
			var smallest = left;
			if (right < length && searchers.fScore[nodes[right].index] < searchers.fScore[nodes[left].index]) {
				smallest = right;
			}

			var childNode = nodes[smallest];
			var childNodeIndex = childNode.index;
			if (searchers.fScore[childNodeIndex] < f) {
				nodes[heapIndex] = childNode;
				searchers.heapIndex[childNodeIndex] = heapIndex;
				heapIndex = smallest;
			} else {
				break;
			}
		}
		nodes[heapIndex] = node;
		searchers.heapIndex[nodeIndex] = heapIndex;
	}
}

@:access(vault.experimental.navigation)
class Pathfinder {
	public static var spatialMapCellInvSize:Float = 1 / 2.5;

	public var connectionsPerNode(default, null):Int;
	#if sys
	public var locked(default, null):haxe.atomic.AtomicBool = new haxe.atomic.AtomicBool(false);
	#end

	var nodes:StructOfVectors<Node, ValidationData>;
	var pendingChanges:StructOfVectors<PendingChange>;
	var connections:StructOfVectors<ConnectionData>;
	var localSearchers:StructOfVectors<Searcher>;
	var localHeap:Heap;
	#if sys
	var threadSearchers:StructOfVectors<Searcher>;
	var threadHeap:Heap;
	var requests:StructOfVectors<Request>;
	#end
	var spatialMap:Map<Int, Array<NodeHandle>> = [];

	static inline function hash(x:Float, y:Float, z:Float) {
		var ix = Std.int(x * spatialMapCellInvSize);
		var iy = Std.int(y * spatialMapCellInvSize);
		var iz = Std.int(z * spatialMapCellInvSize);
		return (ix << 20) | (iy << 8) | (iz);
	}

	public inline function new(maxNodes:Int, connectionsPerNode:Int = 12) {
		this.connectionsPerNode = connectionsPerNode;
		connections = new StructOfVectors<ConnectionData>(maxNodes * connectionsPerNode);
		nodes = new StructOfVectors<Node, ValidationData>(maxNodes);
		pendingChanges = new StructOfVectors<PendingChange>(maxNodes);
		localSearchers = new StructOfVectors<Searcher>(maxNodes);
		localHeap = new Heap(maxNodes);
		#if sys
		threadSearchers = new StructOfVectors<Searcher>(maxNodes);
		threadHeap = new Heap(maxNodes);
		requests = new StructOfVectors<Request>(32);
		#end
	}

	public inline function getNodeHandle(index:Int):NodeHandle {
		return new NodeHandle(index, nodes.generation[index]);
	}

	public function createNode(x:Float, y:Float, z:Float, flags:Int, weight:Float):NodeHandle {
		var node:NodeHandle = NodeHandle.INVALID;
		if (locked.load() || nodes.length + 1 >= node.index) {
			return node;
		}

		var index = nodes.push(x, y, z, flags, weight);
		node.index = index;
		node.generation = ++nodes.generation[index];
		nodes.freed[index] = false;

		var key = hash(x, y, z);
		var cell = spatialMap.get(key);
		if (cell == null) {
			cell = [];
			spatialMap.set(key, cell);
		}
		cell.push(node);
		return node;
	}

	public function destroyNode(node:NodeHandle):Bool {
		var nodeIndex = node.index;
		if (locked.load() || node == NodeHandle.INVALID || node.generation != nodes.generation[nodeIndex]) {
			return false;
		}

		nodes.removeAt(nodeIndex);
		nodes.freed[nodeIndex] = true;

		var key = hash(nodes.x[nodeIndex], nodes.x[nodeIndex], nodes.x[nodeIndex]);
		var cell = spatialMap.get(key);
		if (cell != null) {
			var targetIndex = cell.indexOf(node);
			if (cell.length > 0 && targetIndex != -1) {
				cell[targetIndex] = cell.pop();
			}
		}
		return true;
	}

	public function connectNodes(nodeA:NodeHandle, nodeB:NodeHandle):Void {
		var nodeAIndex = nodeA.index;
		var nodeBIndex = nodeB.index;
		if (locked.load() || nodeA == NodeHandle.INVALID || nodeB == NodeHandle.INVALID) {
			return;
		}
		if (nodes.freed[nodeAIndex]
			|| nodes.freed[nodeBIndex]
			|| nodeA.generation != nodes.generation[nodeAIndex]
			|| nodeB.generation != nodes.generation[nodeBIndex]) {
			return;
		}

		if (nodes.connectionCount[nodeAIndex] < connectionsPerNode) {
			var connectionStartIndex = (nodeAIndex * connectionsPerNode);
			var lastConnectionIndex = connectionStartIndex + nodes.connectionCount[nodeAIndex];
			connections.target[lastConnectionIndex] = nodeB;
			connections.distance[lastConnectionIndex] = estimate(nodeA, nodeB);
			nodes.connectionCount[nodeAIndex]++;
		}
	}

	public function disconnectNodes(nodeA:NodeHandle, nodeB:NodeHandle):Void {
		var nodeAIndex = nodeA.index;
		var nodeBIndex = nodeB.index;
		if (locked.load() || nodeA == NodeHandle.INVALID || nodeB == NodeHandle.INVALID) {
			return;
		}
		if (nodes.freed[nodeAIndex]
			|| nodes.freed[nodeBIndex]
			|| nodeA.generation != nodes.generation[nodeAIndex]
			|| nodeB.generation != nodes.generation[nodeBIndex]) {
			return;
		}

		var connectionStartIndex = (nodeAIndex * connectionsPerNode);
		var count = nodes.connectionCount[nodeAIndex];
		for (i in connectionStartIndex...connectionStartIndex + count) {
			if (connections.target[i] == nodeB) {
				var lastIndex = connectionStartIndex + count - 1;
				connections.target[i] = connections.target[lastIndex];
				connections.distance[i] = connections.distance[lastIndex];
				connections.target[lastIndex] = NodeHandle.INVALID;
				nodes.connectionCount[nodeAIndex]--;
			}
		}
	}

	public function hasConnection(nodeA:NodeHandle, nodeB:NodeHandle):Bool {
		var nodeAIndex = nodeA.index;
		var nodeBIndex = nodeB.index;
		if (nodeA == NodeHandle.INVALID || nodeB == NodeHandle.INVALID) {
			return false;
		}
		if (nodes.freed[nodeAIndex]
			|| nodes.freed[nodeBIndex]
			|| nodeA.generation != nodes.generation[nodeAIndex]
			|| nodeB.generation != nodes.generation[nodeBIndex]) {
			return false;
		}

		var connectionStartIndex = (nodeAIndex * connectionsPerNode);
		var count = nodes.connectionCount[nodeAIndex];
		for (i in connectionStartIndex...connectionStartIndex + count) {
			if (connections.target[i] == nodeB) {
				return true;
			}
		}
		return false;
	}

	public inline function setNodeFlags(node:NodeHandle, flags:Int):Void {
		if (node != NodeHandle.INVALID) {
			var nodeIndex = node.index;
			if (!nodes.freed[nodeIndex] && node.generation == nodes.generation[nodeIndex]) {
				if (!locked.load()) {
					nodes.flags[nodeIndex] = flags;
				} else {
					pendingChanges.push(node, flags, nodes.weight[nodeIndex]);
				}
			}
		}
	}

	public inline function getNodeFlags(node:NodeHandle):Int {
		var nodeIndex = node.index;
		var flags = 0;
		if (node != NodeHandle.INVALID) {
			if (!nodes.freed[nodeIndex] && node.generation == nodes.generation[nodeIndex]) {
				flags = nodes.flags[nodeIndex];
			}
		}
		return flags;
	}

	public inline function setNodeWeight(node:NodeHandle, weight:Float):Void {
		var nodeIndex = node.index;
		if (node != NodeHandle.INVALID) {
			if (!nodes.freed[nodeIndex] && node.generation == nodes.generation[nodeIndex]) {
				if (!locked.load()) {
					nodes.weight[nodeIndex] = weight;
				} else {
					pendingChanges.push(node, nodes.flags[nodeIndex], weight);
				}
			}
		}
	}

	public inline function getNodeWeight(node:NodeHandle):Float {
		var nodeIndex = node.index;
		var weight = Math.NaN;
		if (node != NodeHandle.INVALID) {
			if (!nodes.freed[nodeIndex] && node.generation == nodes.generation[nodeIndex]) {
				weight = nodes.weight[nodeIndex];
			}
		}
		return weight;
	}

	public inline function getNodeX(node:NodeHandle):Float {
		var nodeIndex = node.index;
		var x = Math.NaN;
		if (node != NodeHandle.INVALID) {
			if (!nodes.freed[nodeIndex] && node.generation == nodes.generation[nodeIndex]) {
				x = nodes.x[nodeIndex];
			}
		}
		return x;
	}

	public inline function getNodeY(node:NodeHandle):Float {
		var nodeIndex = node.index;
		var y = Math.NaN;
		if (node != NodeHandle.INVALID) {
			if (!nodes.freed[nodeIndex] && node.generation == nodes.generation[nodeIndex]) {
				y = nodes.y[nodeIndex];
			}
		}
		return y;
	}

	public inline function getNodeZ(node:NodeHandle):Float {
		var nodeIndex = node.index;
		var z = Math.NaN;
		if (node != NodeHandle.INVALID) {
			if (!nodes.freed[nodeIndex] && node.generation == nodes.generation[nodeIndex]) {
				z = nodes.z[nodeIndex];
			}
		}
		return z;
	}

	#if heaps
	public inline function getNodePosition(node:NodeHandle):h3d.Vector {
		var nodeIndex = node.index;
		var position = new h3d.Vector(Math.NaN, Math.NaN, Math.NaN);
		if (node != NodeHandle.INVALID) {
			if (!nodes.freed[nodeIndex] && node.generation == nodes.generation[nodeIndex]) {
				position.set(nodes.x[nodeIndex], nodes.y[nodeIndex], nodes.z[nodeIndex]);
			}
		}
		return position;
	}
	#elseif hxmath
	public inline function getNodePosition(node:NodeHandle):hxmath.math.Vector3 {
		var nodeIndex = node.index;
		var position = new hxmath.math.Vector3(Math.NaN, Math.NaN, Math.NaN);
		if (node != NodeHandle.INVALID) {
			if (!nodes.freed[nodeIndex] && node.generation == nodes.generation[nodeIndex]) {
				position.set(nodes.x[nodeIndex], nodes.y[nodeIndex], nodes.z[nodeIndex]);
			}
		}
		return position;
	}
	#end

	public function clear() {
		for (i in 0...nodes.length) {
			nodes.freed[i] = false;
			nodes.connectionCount[i] = 0;
		}
		for (i in 0...localSearchers.length) {
			localSearchers.searchId[i] = -1;
			localSearchers.closedId[i] = -1;
			localSearchers.heapIndex[i] = -1;
		}
		for (cell in spatialMap) {
			cell.resize(0);
		}
		@:privateAccess {
			localHeap.currentId = 0;
			localHeap.length = 0;
		}
	}

	function applyPendingChanges():Void {
		for (i in 0...pendingChanges.length) {
			var node = pendingChanges.node[i];
			var nodeIndex = node.index;
			var nodeGeneration = node.generation;
			if (!nodes.freed[nodeIndex] && nodeGeneration == nodes.generation[nodeIndex]) {
				nodes.flags[nodeIndex] = pendingChanges.flags[i];
				nodes.weight[nodeIndex] = pendingChanges.weight[i];
			}
		}
		pendingChanges.clear();
	}

	function track(searchers:StructOfVectors<Searcher>, heap:Heap, path:Path, mode:PathMode, flags:Int, start:NodeHandle, end:NodeHandle):Void {
		var startIndex = start.index;
		var endIndex = end.index;
		if (start == NodeHandle.INVALID || end == NodeHandle.INVALID) {
			return;
		}
		if (nodes.freed[startIndex]
			|| nodes.freed[endIndex]
			|| start.generation != nodes.generation[startIndex]
			|| end.generation != nodes.generation[endIndex]) {
			return;
		}

		path.clear();
		path.pathfinder = this;
		path.smoothed = false;

		if (start == end) {
			path.nodes[path.length++] = start;
			return;
		}

		var bestClosest = start;
		var bestClosestScore = estimate(start, end);
		heap.clear();
		heap.push(start, searchers);
		heap.currentId++;
		searchers.gScore[startIndex] = 0;
		searchers.fScore[startIndex] = bestClosestScore;
		searchers.searchId[startIndex] = heap.currentId;
		searchers.closedId[startIndex] = -1;
		searchers.parent[startIndex] = NodeHandle.INVALID;

		while (heap.length > 0) {
			var current = heap.pop(searchers);
			var currentIndex = current.index;
			var currentGeneration = current.generation;
			if (currentGeneration != nodes.generation[currentIndex]) {
				continue;
			}

			var h = estimate(current, end);
			if (mode == ClosestPossible && h < bestClosestScore) {
				bestClosestScore = h;
				bestClosest = current;
			}

			if (current == end) {
				backtrack(searchers, path, end);
				return;
			}

			searchers.closedId[currentIndex] = heap.currentId;
			var connectionStart = (currentIndex * connectionsPerNode);
			for (i in 0...nodes.connectionCount[currentIndex]) {
				var connectionIndex = connectionStart + i;
				var neighbor = connections.target[connectionIndex];
				var neighborDistance = connections.distance[connectionIndex];
				var neighborIndex = neighbor.index;
				var neighborGeneration = neighbor.generation;

				if (neighbor == NodeHandle.INVALID
					|| searchers.closedId[neighborIndex] == heap.currentId
					|| nodes.freed[neighborIndex]
					|| neighborGeneration != nodes.generation[neighborIndex]
					|| nodes.flags[neighborIndex] & flags == 0) {
					continue;
				}

				var ng = searchers.gScore[currentIndex] + connections.distance[connectionIndex] * nodes.weight[neighborIndex];
				if (searchers.searchId[neighborIndex] != heap.currentId || ng < searchers.gScore[neighborIndex]) {
					searchers.parent[neighborIndex] = current;
					searchers.gScore[neighborIndex] = ng;
					searchers.fScore[neighborIndex] = ng + neighborDistance;

					if (searchers.searchId[neighborIndex] != heap.currentId) {
						searchers.searchId[neighborIndex] = heap.currentId;
						heap.push(neighbor, searchers);
					} else {
						if (searchers.heapIndex[neighborIndex] != -1) {
							heap.fetchUpper(searchers.heapIndex[neighborIndex], searchers);
						}
					}
				}
			}
		}

		if (mode == ClosestPossible && bestClosest != NodeHandle.INVALID) {
			backtrack(searchers, path, bestClosest);
		}
	}

	inline function estimate(nodeA:NodeHandle, nodeB:NodeHandle):Float {
		var nodeAIndex = nodeA.index;
		var nodeBIndex = nodeB.index;
		var dx = nodes.x[nodeAIndex] - nodes.x[nodeBIndex];
		var dy = nodes.y[nodeAIndex] - nodes.y[nodeBIndex];
		var dz = nodes.z[nodeAIndex] - nodes.z[nodeBIndex];
		return Math.sqrt(dx * dx + dy * dy + dz * dz);
	}

	inline function backtrack(searchers:StructOfVectors<Searcher>, path:Path, end:NodeHandle):Void {
		var current = end;
		while (current != NodeHandle.INVALID && path.length < path.nodes.length) {
			var currentIndex = current.index;
			path.nodes[path.length++] = current;
			current = searchers.parent[currentIndex];
		}
		path.version++;
	}

	public function queryNearestNode(x:Float, y:Float, z:Float, flags:Int, maxRadius:Float = 1e38):NodeHandle {
		var best = NodeHandle.INVALID;
		var bestDistance = maxRadius * maxRadius;
		var key = hash(x, y, z);
		var cell = spatialMap.get(key);

		inline function process(index:Int) {
			if (nodes.flags[index] & flags != 0) {
				var dx = nodes.x[index] - x;
				var dy = nodes.y[index] - y;
				var dz = nodes.z[index] - z;
				var distance = dx * dx + dy * dy + dz * dz;
				if (distance < bestDistance) {
					bestDistance = distance;
					best.index = index;
					best.generation = nodes.generation[index];
				}
			}
		}

		if (cell != null) {
			for (node in cell) {
				process(node.index);
			}
		}
		if (best == NodeHandle.INVALID) {
			for (i in 0...nodes.length) {
				process(i);
			}
		}
		return best;
	}

	public inline function findPath(path:Path, mode:PathMode, flags:Int, sX:Float, sY:Float, sZ:Float, dX:Float, dY:Float, dZ:Float):Void {
		var start = queryNearestNode(sX, sY, sZ, flags);
		var end = queryNearestNode(dX, dY, dZ, flags);
		if (start == NodeHandle.INVALID || end == NodeHandle.INVALID) {
			return;
		}
		track(localSearchers, localHeap, path, mode, flags, start, end);
	}

	#if sys
	public function requestPath(callback:() -> Void, path:Path, mode:PathMode, flags:Int, sX:Float, sY:Float, sZ:Float, dX:Float, dY:Float, dZ:Float):Bool {
		var l = locked.load();
		if (!l) {
			requests.push(callback, path, mode, flags, sX, sY, sZ, dX, dY, dZ);
		}
		return !l;
	}

	public extern inline overload function processRequests(thread:sys.thread.Thread):Void {
		if (locked.load()) {
			return;
		}

		var maxNodes = nodes.length;
		locked.store(true);
		thread.events.run(() -> {
			for (i in 0...requests.length) {
				var start = queryNearestNode(requests.sX[i], requests.sY[i], requests.sZ[i], requests.flags[i]);
				var end = queryNearestNode(requests.dX[i], requests.dY[i], requests.dZ[i], requests.flags[i]);
				if (start == NodeHandle.INVALID || end == NodeHandle.INVALID) {
					return;
				}
				track(threadSearchers, threadHeap, requests.path[i], requests.mode[i], requests.flags[i], start, end);
				haxe.MainLoop.runInMainThread(requests.callback[i]);
			}
			haxe.MainLoop.runInMainThread(applyPendingChanges);
			requests.clear();
			locked.store(false);
		});
	}

	public extern inline overload function processRequests(threadPool:sys.thread.IThreadPool):Void {
		if (locked.load()) {
			return;
		}

		var maxNodes = nodes.capacity;
		locked.store(true);
		threadPool.run(() -> {
			for (i in 0...requests.length) {
				var start = queryNearestNode(requests.sX[i], requests.sY[i], requests.sZ[i], requests.flags[i]);
				var end = queryNearestNode(requests.dX[i], requests.dY[i], requests.dZ[i], requests.flags[i]);
				if (start == NodeHandle.INVALID || end == NodeHandle.INVALID) {
					return;
				}
				track(threadSearchers, threadHeap, requests.path[i], requests.mode[i], requests.flags[i], start, end);
				haxe.MainLoop.runInMainThread(requests.callback[i]);
			}
			haxe.MainLoop.runInMainThread(applyPendingChanges);
			requests.clear();
			locked.store(false);
		});
	}
	#end
}
