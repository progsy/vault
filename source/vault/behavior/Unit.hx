package vault.behavior;

@:allow(vault.behavior.World)
@:allow(vault.behavior.System)
@:allow(vault.behavior.SystemExtension)
abstract Unit(Int) {
	public static final INVALID:Unit = new Unit(0xFFFF, 0xFFFF);

	public var index(get, set):Int;
	public var generation(get, set):Int;

	inline function get_index() {
		return (this >> 16 & 0xFFFF);
	}

	inline function set_index(value) {
		return this = (this & ~(0xFFFF << 16)) | (value << 16);
	}

	inline function get_generation() {
		return this & 0xFFFF;
	}

	inline function set_generation(value) {
		return this = this & ~(0xFFFF) | value;
	}

	inline function new(i, g) {
		this = 0;
		index = i;
		generation = g;
	}
}
