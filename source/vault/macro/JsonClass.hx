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

		var loadAssigns:Array<Expr> = [];
		var loadStaticAssigns:Array<Expr> = [];

		for (f in fields) {
			var fieldName = f.name;
			if (!staticFields) {
				loadAssigns.push(macro {
					var value = Reflect.field(json, $v{fieldName});
					if (Reflect.hasField(json, $v{fieldName})) {
						$i{fieldName} = value;
					}
				});
			} else {
				loadStaticAssigns.push(macro {
					var value = Reflect.field(json, $v{fieldName});
					if (Reflect.hasField(json, $v{fieldName})) {
						$i{fieldName} = value;
					}
				});
			}
		}

		var parseFunction:haxe.macro.Field;
		var parseStaticFunction:haxe.macro.Field;
		for (f in buildFields) {
			if (f.name == "parse") {
				parseFunction = f;
			} else if (f.name == "parseStatic") {
				parseStaticFunction = f;
			}
		}

		if (parseFunction != null) {
			switch (parseFunction.kind) {
				case FFun(f):
					switch (f.expr.expr) {
						case EBlock(exprs):
							f.expr = macro $b{exprs.concat(loadAssigns)};
						default:
					}
				default:
			};
		} else {
			fields.push({
				name: "parse",
				access: [APublic],
				pos: Context.currentPos(),
				kind: FFun({
					args: [{name: "content", type: macro :String}],
					ret: macro :Void,
					expr: macro {
						var json:Dynamic = haxe.Json.parse(content);
						$b{loadAssigns};
					}
				})
			});
		}

		if (parseStaticFunction != null) {
			switch (parseStaticFunction.kind) {
				case FFun(f):
					switch (f.expr.expr) {
						case EBlock(exprs):
							f.expr = macro $b{exprs.concat(loadStaticAssigns)};
						default:
					}
				default:
			};
		} else {
			fields.push({
				name: "parseStatic",
				access: [APublic, AStatic],
				pos: Context.currentPos(),
				kind: FFun({
					args: [{name: "content", type: macro :String}],
					ret: macro :Void,
					expr: macro {
						var json:Dynamic = haxe.Json.parse(content);
						$b{loadStaticAssigns};
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
				var schemaPaths:Array<String> = [];
				for (param in params) {
					switch (param) {
						case TInst(_.get() => t, _) if (t.name.charAt(0) == 'S'):
							var path = t.name.substring(1);
							if (!sys.FileSystem.exists(path)) {
								Context.error('Path $path does not exist', t.pos);
							}
							schemaPaths.push(t.name.substring(1));
						default:
							Context.error("Invalid parameter", Context.currentPos());
					}
				}

				var signature = Context.signature(schemaPaths.join('#'));
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

				for (schemaPath in schemaPaths) {
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
				}

				var cls = Context.getLocalClass().get();
				var className = cls.name;
				var loadAssigns:Array<Expr> = [];

				for (f in fields) {
					var fieldName = f.name;
					loadAssigns.push(macro if (Reflect.hasField(json, $v{fieldName})) {
						$i{fieldName} = Reflect.field(json, $v{fieldName});
					});
				}

				fields.push({
					name: "SCHEMA_PATH",
					access: [APublic, AStatic, AFinal],
					pos: Context.currentPos(),
					kind: schemaPaths.length == 1 ? FieldType.FVar(macro :String,
						macro $v{schemaPaths[0]}) : FieldType.FVar(macro :Array<String>, macro $v{schemaPaths})
				});

				fields.push({
					name: "getSchemaPath",
					access: [APublic, AInline],
					pos: Context.currentPos(),
					kind: FFun({
						args: [],
						expr: macro return SCHEMA_PATH
					})
				});

				fields.push({
					name: "new",
					access: [APublic, AInline],
					pos: Context.currentPos(),
					kind: FFun({
						args: [],
						expr: macro {}
					})
				});

				fields.push({
					name: "reset",
					access: [APublic],
					pos: Context.currentPos(),
					kind: FFun({
						args: [],
						ret: macro :Void,
						expr: macro $b{
							[
								for (f in fields) {
									var value:Expr;
									if (f.access.contains(AStatic)) {
										continue;
									}
									switch (f.kind) {
										case FVar(_, e):
											value = e;
										default:
											continue;
									}
									macro $i{f.name} = $value;
								}
							]
						}
					})
				});

				fields.push({
					name: "parse",
					access: [APublic],
					pos: Context.currentPos(),
					kind: FFun({
						args: [{name: "content", type: macro :String}],
						ret: macro :Void,
						expr: macro {
							var json:Dynamic = haxe.Json.parse(content);
							$b{loadAssigns};
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
