package hxpkg;

import haxe.Json;
import sys.FileSystem;
import sys.io.File;
import sys.io.Process;

using StringTools;

typedef HxPKGFile = Array<PKGInfo>;

typedef PKGInfo =
{
	var name:String;
	var version:String;
	var link:String;
	var branch:String;
}

class Main
{
	static function main()
	{
		var oldArgs = Sys.args();
		Sys.setCwd(oldArgs.pop());

		if (!oldArgs.contains('--quiet'))
			Sys.println("\033[38;5;208m _   _       \033[38;5;33m ____  \033[38;5;33m _  __\033[38;5;33m ____ \n\033[38;5;208m| | | |\033[38;5;202m__  __\033[38;5;33m|  _ \\ \033[38;5;33m| |/ /\033[38;5;33m/ ___|\n\033[38;5;208m| |_| |\033[38;5;202m\\ \\/ /\033[38;5;33m| |_) |\033[38;5;33m| ' /\033[38;5;33m| |  _ \n\033[38;5;208m|  _  |\033[38;5;202m >  < \033[38;5;33m|  __/ \033[38;5;33m| . \\\033[38;5;33m| |_| |\n\033[38;5;208m|_| |_|\033[38;5;202m/_/\\_\\\033[38;5;33m|_|    \033[38;5;33m|_|\\_\\\033[38;5;33m\\____|\033[0;0m\n");

		var args:Array<String> = [];
		var flags:Array<String> = [];
		final supportedFlags = ['--quiet', '--force', '--beautify'];
		for (arg in oldArgs)
			if (arg.trim().startsWith('--'))
			{
				if (!supportedFlags.contains(arg))
					Sys.println('WARN: Unsupported flag: $arg');
				flags.push(arg);
			}
			else
				args.push(arg);

		if (args.length == 0)
		{
			Sys.println('Not enough arguments. Run `haxelib run hxpkg help` for help');
			return;
		}

		var cmd = args.shift();
		switch (cmd)
		{
			case 'install':
				install(args, flags);
			case 'add':
				add(args, flags);
			case 'remove':
				remove(args, flags);
			case 'clear':
				clear(args, flags);
			case 'uninstall':
				uninstall(args, flags);
			case 'help':
				help(args, flags);
			default:
				Sys.println('WARN: $cmd is not a valid command. Run `haxelib run hxpkg help` for help');
		}

		/*switch (args[0])
			{
				case 'help':
					for (msg in [
						'haxelib run hxpkg install - Installs all packages from the .hxpkg file',
						'haxelib run hxpkg add - Adds a package to the .hxpkg file (Add multiple by seperating with commas)\nExamples:\n\thaxelib run hxpkg add tjson\n\thaxelib run hxpkg add hmm 3.1.0\n\thaxelib run hxpkg add haxeui-core https://github.com/haxeui/haxeui-core/\n\thaxelib run hxpkg add flxanimate https://github.com/ShadowMario/flxanimate dev',
						'haxelib run hxpkg remove - Removes a package from the .hxpkg file',
						'haxelib run hxpkg clear - Removes all packages from the .hxpkg file',
						'haxelib run hxpkg uninstall - Removes all packages installed by the .hxpkg file\n\tNOTE: Does not remove dependencies',
						'haxelib run hxpkg help - Shows help information',
						'\nSwitches:\n\t--quiet - (Used with install) Silent Installation\n\t--force - (Used with install) Install packages even if a local haxelib repository (.haxelib) exists\n\t--beautify - (Used with add, remove and clear) Formats the .hxpkg file'
					])
						Sys.println(msg);
				default:
					Sys.println('Invalid command. Run `haxelib run hxpkg help` for help.');
		}*/
	}

	static function install(args:Array<String>, flags:Array<String>):Void
	{
		if (!HxPKG())
		{
			Sys.println('.hxpkg does not exist, aborting.');
			return;
		}

		var content = File.getContent('.hxpkg').trim();
		if (content == '')
			content = '[]';
		var hxpkgFile:HxPKGFile = Json.parse(content);

		if (Haxelib())
			if (!flags.contains('--force'))
			{
				Sys.println('.haxelib exists, aborting. (Run with --force to continue anyway)');
				return;
			}
			else
				Sys.println('.haxelib exists, continuing (--force)');
		else
			new Process('haxelib', ['newrepo']).exitCode();

		if (flags.contains('--quiet'))
			Sys.print('Installing package${if (hxpkgFile.length > 1) 's' else ''} ${[for (pkg in hxpkgFile) pkg.name].join(', ')}... ');

		var failedPackages:Array<String> = [];
		for (pkg in hxpkgFile)
		{
			if (!flags.contains('--quiet'))
				Sys.print('Installing package ${pkg.name}... ');

			var hxargs:Array<String> = [];
			var failMsg = '';
			if (pkg.link == null)
			{
				hxargs.push('install');
				hxargs.push(pkg.name);
				if (pkg.version != null)
					hxargs.push(pkg.version);
				failMsg = 'Check haxelib.';
			}
			else
			{
				hxargs.push('git');
				hxargs.push(pkg.name);
				hxargs.push(pkg.link);
				if (pkg.branch != null)
					hxargs.push(pkg.branch);
				failMsg = 'Check the github repository.';
			}

			hxargs.push('--never');
			var exitCode = new Process('haxelib', hxargs).exitCode();
			if (exitCode != 0)
			{
				Sys.println('failed. $failMsg');
				failedPackages.push(pkg.name);
			}
			else
				Sys.println('done.');
		}

		if (failedPackages.length > 0)
			Sys.println('Failed to install ${[for (pkg in failedPackages) pkg].join(', ')}');
	}

	static function add(args:Array<String>, flags:Array<String>):Void
	{
		if (!HxPKG())
			File.saveContent('.hxpkg', '[]');

		var content = File.getContent('.hxpkg').trim();
		if (content == '')
			content = '[]';
		var hxpkgFile:HxPKGFile = Json.parse(content);

		var map:Map<String, Int> = [for (i in 0...hxpkgFile.length) hxpkgFile[i].name => i];

		// https://stackoverflow.com/questions/3809401/what-is-a-good-regular-expression-to-match-a-url
		var matchUrl = new EReg('https?:\\/\\/(www\\.)?[-a-zA-Z0-9@:%._\\+~#=]{1,256}\\.[a-zA-Z0-9()]{1,6}\\b([-a-zA-Z0-9()@:%_\\+.~#?&//=]*)', 'i');

		for (pkg in [for (arg in args.join(" ").split(",")) arg.trim().split(" ")])
		{
			if (map.exists(pkg[0]))
			{
				Sys.println('Package ${pkg[0]} already exists in the .hxpkg. Continuing...');
				continue;
			}

			if (pkg.length >= 3)
				hxpkgFile.push({
					name: pkg[0],
					version: null,
					link: pkg[1],
					branch: pkg[2]
				});
			else
			{
				if (pkg[1] == null)
					hxpkgFile.push({
						name: pkg[0],
						version: null,
						link: null,
						branch: null
					});
				else
				{
					if (matchUrl.match(pkg[1]))
						hxpkgFile.push({
							name: pkg[0],
							version: null,
							link: pkg[1],
							branch: null
						});
					else
						hxpkgFile.push({
							name: pkg[0],
							version: pkg[1],
							link: null,
							branch: null
						});
				}
			}
			Sys.println('Added package ${pkg[0]} to .hxpkg.');
		}

		if (flags.contains('--beautify'))
			File.saveContent('.hxpkg', Json.stringify(hxpkgFile, null, '\t'));
		else
			File.saveContent('.hxpkg', Json.stringify(hxpkgFile));
	}

	static function remove(args:Array<String>, flags:Array<String>):Void
	{
		if (!HxPKG())
			File.saveContent('.hxpkg', '[]');

		var content = File.getContent('.hxpkg').trim();
		if (content == '')
			content = '[]';
		var hxpkgFile:HxPKGFile = Json.parse(content);

		var map:Map<String, Int> = [for (i in 0...hxpkgFile.length) hxpkgFile[i].name => i];

		for (pkg in args)
			if (map.exists(pkg))
			{
				Sys.println('Removing package ${pkg}');
				hxpkgFile.remove(hxpkgFile[map[pkg]]);
			}
			else
				Sys.println('Package $pkg does not exist in the .hxpkg.');

		if (flags.contains('--beautify'))
			File.saveContent('.hxpkg', Json.stringify(hxpkgFile, null, '\t'));
		else
			File.saveContent('.hxpkg', Json.stringify(hxpkgFile));
	}

	static function clear(args:Array<String>, flags:Array<String>):Void
	{
		File.saveContent('.hxpkg', '[]');
		Sys.println('Cleared all packages from the .hxpkg file.');
	}

	static function uninstall(args:Array<String>, flags:Array<String>):Void
	{
		if (!Haxelib())
		{
			Sys.println('.haxelib does not exist, aborting.');
			return;
		}

		if (!HxPKG())
		{
			Sys.println('.hxpkg does not exist, aborting.');
			return;
		}

		var content = File.getContent('.hxpkg').trim();
		if (content == '')
			content = '[]';
		var hxpkgFile:HxPKGFile = Json.parse(content);

		var failedPackages:Array<String> = [];
		for (pkg in hxpkgFile)
		{
			if (!flags.contains('--quiet'))
				Sys.print('Uninstalling package ${pkg.name}... ');
			var exitCode = new Process('haxelib', ['remove', pkg.name, '--never']).exitCode();
			if (exitCode != 0)
			{
				Sys.println('failed.');
				failedPackages.push(pkg.name);
			}
			else
				Sys.println('done.');
		}

		if (failedPackages.length > 0)
			Sys.println('Failed to uninstall ${[for (pkg in failedPackages) pkg].join(", ")}.');
		else
			Sys.println('Uninstalled all packages successfully.');
	}

	static function help(args:Array<String>, flags:Array<String>):Void {}

	static inline function HxPKG():Bool
		return FileSystem.exists('.hxpkg');

	static inline function Haxelib():Bool
		return FileSystem.exists('.haxelib');
}
