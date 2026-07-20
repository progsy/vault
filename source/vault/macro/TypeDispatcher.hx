package vault.macro;

#if macro
import haxe.macro.Context;
import haxe.macro.Expr;
import haxe.macro.Type;

using haxe.macro.TypeTools;

class TypeDispatcher {
	public static function build(suffix:String):ComplexType {
		var cls = Context.getLocalClass().get();
		var typeParameters = switch (Context.getLocalType()) {
			case TInst(t, params):
				params;
			default:
				null;
		}
		var path = cls.pack.join('.') + '.' + cls.name + '.' + cls.name + typeParameters.length;
		var type = Context.getType(path);

		switch (type) {
			case TInst(_.get() => t, params):
				for (i in 0...typeParameters.length) {
					params[i] = typeParameters[i];
				}
			default:
		}

		return type.toComplexType();
	}
}
#end
