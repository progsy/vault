package vault.data;

#if macro
import haxe.macro.Expr;
import haxe.macro.Context;
import haxe.macro.Type;

using haxe.macro.ExprTools;
using haxe.macro.TypeTools;
using haxe.macro.ComplexTypeTools;
#end

abstract Handle<T>(Int) {
	public var index(get, set):Int;
	public var generation(get, set):Int;

	inline function get_index() {
		return (this >> 16 & 0xFFFF);
	}

	inline function set_index(value) {
		return this = (this & ~(0xFFFF << 16)) | (value << 16);
	}

	inline function get_generation() {
		return this & (0xFFFF);
	}

	inline function set_generation(value) {
		return this = (this & ~(0xFFFF)) | (value);
	}

	public macro function get(handle:haxe.macro.Expr, items:Expr, ?generations:haxe.macro.Expr):haxe.macro.Expr {
		var handleType = Context.typeof(handle);
		var parameterType = switch (handleType) {
			case TAbstract(_.get() => t, params):
				params[0].toComplexType();
			default:
				null;
		}

		var hasGenerations = switch (generations.expr) {
			case EConst(c):
				switch (c) {
					case CIdent(s) if (s == "null"):
						false;
					default:
						true;
				}
			default:
				true;
		}

		if (hasGenerations) {
			return macro {
				var item:Null<$parameterType> = null;
				if ($items.length > $handle.index && $generations.length > $handle.index) {
					if ($generations[$handle.index] == $handle.generation) {
						item = $items[$handle.index];
					}
				}
				item;
			};
		}

		return macro {
			var item:Null<$parameterType> = null;
			if ($items.length > $handle.index) {
				item = $items[$handle.index];
			}
			item;
		};
	}

	public macro function set(handle:haxe.macro.Expr, index:haxe.macro.Expr, items:Expr, ?generations:haxe.macro.Expr):haxe.macro.Expr {
		var handleType = Context.typeof(handle);
		var parameterType = switch (handleType) {
			case TAbstract(_.get() => t, params):
				params[0].toComplexType();
			default:
				null;
		}

		var hasGenerations = switch (generations.expr) {
			case EConst(c):
				switch (c) {
					case CIdent(s) if (s == "null"):
						false;
					default:
						true;
				}
			default:
				true;
		}

		if (hasGenerations) {
			return macro {
				var item:Null<$parameterType> = null;
				if ($items.length > $index && $generations.length > $index) {
					$handle.index = $index;
					$handle.generation = $generations[$index];
					item = $items[$index];
				}
				item;
			};
		}

		return macro {
			var item:Null<$parameterType> = null;
			if ($items.length > $index) {
				$handle.index = $index;
				item = $items[$index];
			}
			item;
		};
	}

	public inline function unset():Void {
		index = 0x7FFFFFFF;
		generation = 0;
	}

	public inline function isSet():Bool {
		return index != 0x7FFFFFFF;
	}

	public inline function new() {
		this = 0;
		set_index(0x7FFFFFFF);
	}
}
