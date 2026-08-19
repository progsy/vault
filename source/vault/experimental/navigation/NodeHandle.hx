package vault.experimental.navigation;

abstract NodeHandle(Int) {
	public static final INVALID = new NodeHandle(0x3FFFF, 0x3FFF);

	public var index(get, set):Int;
	public var generation(get, set):Int;

	inline function get_index() {
		return (this >> 18 & 0x3FFFF);
	}

	inline function set_index(value) {
		return this = (this & ~(0x3FFFF << 18)) | (value << 18);
	}

	inline function get_generation() {
		return this & (0x3FFF);
	}

	inline function set_generation(value) {
		return this = (this & ~(0x3FFF)) | (value);
	}

	inline function new(i:Int, g:Int) {
		this = 0;
		index = i;
		generation = g;
	}
}
