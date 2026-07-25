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

	static function buildGeneric():ComplexType {
		var type = Context.getLocalType();
		var fields = Context.getBuildFields();

		switch (type) {
			case TInst(_.get() => cl, params):
				if (params.length == 0) {
					Context.error("Please specify the schema path", Context.currentPos());
				}
				var schemaPath:String;
				switch (params[0]) {
					case TInst(_.get() => t, _):
						if (t.name.charAt(0) == 'S') {
							schemaPath = t.name.substring(1);
						}
					default:
				}
				if (!sys.FileSystem.exists(schemaPath)) {
					Context.error('Path $schemaPath does not exist', Context.currentPos());
				}
				var signature = Context.signature(schemaPath);
				var uniqueName = 'Json_${signature}';
				var fullPack = ["vault", "behavior"];

				var complexType = TPath({
					pack: fullPack,
					name: uniqueName
				});

				try {
					var existingPath = fullPack.join(".") + "." + uniqueName;
					Context.getType(existingPath);
					return complexType;
				} catch (e:Dynamic) {}

				var content = sys.io.File.getContent(schemaPath);
				var json = haxe.Json.parse(content);

				for (fieldName in Reflect.fields(json)) {
					var value = Reflect.field(json, fieldName);
					var kind = FieldType.FVar(null, macro $v{value});
					fields.push({
						name: fieldName,
						access: [APublic],
						kind: kind,
						pos: Context.currentPos()
					});
				}

				var cls = Context.getLocalClass().get();
				var className = cls.name;

				var reloadAssigns:Array<Expr> = [];

				for (f in fields) {
					var fieldName = f.name;
					reloadAssigns.push(macro {
						var value = Reflect.field(json, $v{fieldName});
						if (Reflect.hasField(json, $v{fieldName})) {
							$i{fieldName} = value;
						}
					});
				}

				fields.push({
					name: "new",
					access: [APublic],
					pos: Context.currentPos(),
					kind: FFun({
						args: [],
						expr: macro {}
					})
				});

				fields.push({
					name: "reload",
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

				Context.defineType({
					pack: fullPack,
					name: uniqueName,
					pos: Context.currentPos(),
					kind: TDClass(),
					fields: fields
				});
				return complexType;
			default:
				return Context.error("Invalid usage", Context.currentPos());
		}
	}
}
#end
