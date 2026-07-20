package vault.experimental.navigation;

class Path extends StructOfVectors<Node> {
	public inline function calculateTotalDistance():Float {
		if (length <= 1)
			return 0.0;

		var d = 0.0;

		for (i in 0...length - 1) {
			var dx = x[i] - x[i + 1];
			var dy = y[i] - y[i + 1];
			var dz = z[i] - z[i + 1];
			d += Math.sqrt(dx * dx + dy * dy + dz * dz);
		}

		return d;
	}

	public inline function calculateTotalDistanceSq():Float {
		if (length <= 1)
			return 0.0;

		var d = 0.0;

		for (i in 0...length - 1) {
			var dx = x[i] - x[i + 1];
			var dy = y[i] - y[i + 1];
			var dz = z[i] - z[i + 1];
			d += dx * dx + dy * dy + dz * dz;
		}

		return d;
	}
}
