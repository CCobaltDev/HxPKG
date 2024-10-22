package hxpkg;

typedef PKGFile = Map<String, Array<PKG>>;

// JSON
typedef JSONPKGFile = Array<{profile:String, pkgs:Array<PKG>}>;

typedef PKG =
{
	var name:String;
	@:optional var version:String;
	@:optional var link:String;
	@:optional var branch:String; // Or hash, doesn't matter
	@:optional var dir:String;
}
