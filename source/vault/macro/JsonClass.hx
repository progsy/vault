package vault.macro;

#if macro
import haxe.macro.Expr;
import haxe.macro.Context;
import haxe.macro.Type;

using haxe.macro.ExprTools;
using haxe.macro.TypeTools;
using haxe.macro.ComplexTypeTools;

class JsonClass {
	static function build(filepath:String, staticFields:Bool = true) {
		var buildFields = Context.getBuildFields();
		var fields:Array<Field> = [];
		var content = sys.io.File.getContent(filepath);
		var json = haxe.Json.parse(content);

		for (fieldName in Reflect.fields(json)) {
			var value = Reflect.field(json, fieldName);
			var kind = FieldType.FVar(null, macro $v{value});
			fields.push({
				name: fieldName,
				access: staticFields ? [APublic, AStatic] : [APublic],
				kind: kind,
				pos: Context.currentPos()
			});
		}

		var cls = Context.getLocalClass().get();
		var className = cls.name;

		var reloadAssigns:Array<Expr> = [];
		var reloadStaticAssigns:Array<Expr> = [];

		for (f in fields) {
			var fieldName = f.name;
			if (!staticFields) {
				reloadAssigns.push(macro {
					var value = Reflect.field(json, $v{fieldName});
					if (Reflect.hasField(json, $v{fieldName})) {
						$i{fieldName} = value;
					}
				});
			} else {
				reloadStaticAssigns.push(macro {
					var value = Reflect.field(json, $v{fieldName});
					if (Reflect.hasField(json, $v{fieldName})) {
						$i{fieldName} = value;
					}
				});
			}
		}

		var reloadJsonFunction:haxe.macro.Field;
		var reloadJsonStaticFunction:haxe.macro.Field;
		for (f in buildFields) {
			if (f.name == "reloadJson") {
				reloadJsonFunction = f;
			} else if (f.name == "reloadJsonStatic") {
				reloadJsonStaticFunction = f;
			}
		}

		if (reloadJsonFunction != null) {
			switch (reloadJsonFunction.kind) {
				case FFun(f):
					switch (f.expr.expr) {
						case EBlock(exprs):
							f.expr = macro $b{exprs.concat(reloadAssigns)};
						default:
					}
				default:
			};
		} else {
			fields.push({
				name: "reloadJson",
				access: [APublic],
				pos: Context.currentPos(),
				kind: FFun({
					args: [{name: "content", type: macro :String}],
					ret: macro :Void,
					expr: macro {
						var json:Dynamic = haxe.Json.parse(content);
						$b{reloadAssigns};
					}
				})
			});
		}

		if (reloadJsonStaticFunction != null) {
			switch (reloadJsonStaticFunction.kind) {
				case FFun(f):
					switch (f.expr.expr) {
						case EBlock(exprs):
							f.expr = macro $b{exprs.concat(reloadStaticAssigns)};
						default:
					}
				default:
			};
		} else {
			fields.push({
				name: "reloadJsonStatic",
				access: [APublic, AStatic],
				pos: Context.currentPos(),
				kind: FFun({
					args: [{name: "content", type: macro :String}],
					ret: macro :Void,
					expr: macro {
						var json:Dynamic = haxe.Json.parse(content);
						$b{reloadStaticAssigns};
					}
				})
			});
		}

		return buildFields.concat(fields);
	}
}
#end
