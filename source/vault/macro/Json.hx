package vault.macro;

#if macro
import haxe.macro.Expr;
import haxe.macro.Context;
import haxe.macro.Type;

using haxe.macro.ExprTools;
using haxe.macro.TypeTools;
using haxe.macro.ComplexTypeTools;

class Json {
	static function build():ComplexType {
		var type = Context.getLocalType();
		var fields:Array<Field> = [];

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
				var fullPack = ["vault", "data"];
				var typePath:TypePath = {
					pack: fullPack,
					name: uniqueName
				};
				var complexType = TPath(typePath);

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

				var toStringExprs:Array<Expr> = [];
				for (i in 0...fields.length) {
					var f = fields[i];
					var value:Expr;
					switch (f.kind) {
						case FVar(_, e):
							value = e;
						default:
							continue;
					}
					if (i == 0) {
						toStringExprs.push(macro output += '{' + $v{f.name} + ': ' + $i{f.name} + ', ');
					} else if (i + 1 == fields.length) {
						toStringExprs.push(macro output += $v{f.name} + ': ' + $i{f.name} + '}');
					} else {
						toStringExprs.push(macro output += $v{f.name} + ': ' + $i{f.name} + ', ');
					}
				}
				toStringExprs.insert(0, macro var output = '');
				toStringExprs.push(macro return output);
				fields.push({
					name: "toString",
					access: [APublic, AInline],
					pos: Context.currentPos(),
					kind: FFun({
						args: [],
						expr: macro $b{toStringExprs}
					})
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
					access: [APublic, AInline],
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
					access: [APublic, AInline],
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

				var copyExprs = [
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
						macro $p{['instance', f.name]} = $i{f.name};
					}
				];
				copyExprs.insert(0, macro var instance = new $typePath());
				copyExprs.push(macro return instance);
				fields.push({
					name: "copy",
					access: [APublic, AInline],
					pos: Context.currentPos(),
					kind: FFun({
						args: [],
						expr: macro $b{copyExprs}
					})
				});

				Context.defineType({
					pack: fullPack,
					name: uniqueName,
					pos: Context.currentPos(),
					kind: TDClass(),
					fields: fields.concat(Context.getBuildFields())
				});
				return complexType;
			default:
				return Context.error("Invalid usage", Context.currentPos());
		}
	}
}
#end
