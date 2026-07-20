package vault.macro;

#if macro
import haxe.macro.Expr;
import haxe.macro.Context;
import haxe.macro.Type;

using haxe.macro.ExprTools;
using haxe.macro.TypeTools;
using haxe.macro.ComplexTypeTools;

class JsonClass {
	static function build(filepath:String, staticByDefault:Bool = true) {
		var buildFields = Context.getBuildFields();

		var content = sys.io.File.getContent(filepath);
		var json = haxe.Json.parse(content);

		for (fieldName in Reflect.fields(json)) {
			var raw = Reflect.field(json, fieldName);
			var value = Reflect.hasField(raw, "value") ? Reflect.field(raw, "value") : raw;
			var comment:String = "";
			var typeString:String = "Dynamic";
			var isPublic:Bool = true;
			var isStatic:Bool = staticByDefault;
			var isFinal:Bool = false;
			var isInline:Bool = false;
			var formStr:String = "Normal";

			if (value != null) {
				comment = Reflect.hasField(raw, "comment") ? Reflect.field(raw, "comment") : "";
				typeString = Reflect.hasField(raw, "type") ? Reflect.field(raw, "type") : "Dynamic";
				isPublic = Reflect.hasField(raw, "public") ? Reflect.field(raw, "public") : true;
				isStatic = Reflect.hasField(raw, "static") ? Reflect.field(raw, "static") : staticByDefault;
				isFinal = Reflect.hasField(raw, "final") ? Reflect.field(raw, "final") : false;
				isInline = Reflect.hasField(raw, "inline") ? Reflect.field(raw, "inline") : false;
				formStr = Reflect.hasField(raw, "form") ? Reflect.field(raw, "form") : "Normal";
			}

			var type = try {
				Context.getType(typeString);
			} catch (e:Dynamic) {
				Context.getType("Dynamic");
			};

			var access:Array<Access> = [];
			if (isPublic) {
				access.push(APublic);
			} else {
				access.push(APrivate);
			}
			if (isStatic) {
				access.push(AStatic);
			}
			if (isInline) {
				access.push(AInline);
			}
			if (isFinal) {
				access.push(AFinal);
			}

			var kind = switch (formStr) {
				case "Property":
					FieldType.FProp("get", "set", type.toComplexType(), macro $v{value});
				default:
					FieldType.FVar(type.toComplexType(), macro $v{value});
			};

			buildFields.push({
				name: fieldName,
				access: access,
				kind: kind,
				doc: comment,
				pos: Context.currentPos()
			});
		}

		var cls = Context.getLocalClass().get();
		var className = cls.name;

		var reloadAssigns:Array<Expr> = [];
		var reloadStaticAssigns:Array<Expr> = [];

		for (f in buildFields) {
			var fieldName = f.name;
			var isStatic = f.access.contains(AStatic);

			if (!isStatic) {
				reloadAssigns.push(macro {
					var raw = Reflect.field(json, $v{fieldName});
					var value = Reflect.hasField(raw, "value") ? Reflect.field(raw, "value") : raw;
					if (Reflect.hasField(json, $v{fieldName})) {
						$i{fieldName} = value;
					}
				});
			} else {
				reloadStaticAssigns.push(macro {
					var raw = Reflect.field(json, $v{fieldName});
					var value = Reflect.hasField(raw, "value") ? Reflect.field(raw, "value") : raw;
					if (Reflect.hasField(json, $v{fieldName})) {
						$i{fieldName} = value;
					}
				});
			}
		}

		buildFields.push({
			name: "reloadJson",
			access: [APublic, AInline],
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

		buildFields.push({
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

		return buildFields;
	}
}
#end
