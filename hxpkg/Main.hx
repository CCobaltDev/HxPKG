package hxpkg;

import haxe.ds.ArraySort;
import haxe.io.Path;
import hxpkg.PKGFile;
import sys.FileSystem;
import sys.io.File;
import sys.io.Process;

using StringTools;

class Main
{
	// A bit overkill but i'm too lazy to rework it
	static final validFlags:Map<String, Array<String>> = [
		'install' => ['--global', '--force', '--update'],
		'uninstall' => ['--remove-all']
	];

	// https://stackoverflow.com/questions/3809401/what-is-a-good-regular-expression-to-match-a-url
	static final urlMatch = new EReg('https?:\\/\\/(www\\.)?[-a-zA-Z0-9@:%._\\+~#=]{1,256}\\.[a-zA-Z0-9()]{1,6}\\b([-a-zA-Z0-9()@:%_\\+.~#?&//=]*)', 'i');

	public static var quiet:Bool = false;

	static function main()
	{
		var parsed = Util.parseArgs();

		if (!quiet)
			Sys.println("\033[38;5;208m _   _       \033[38;5;33m ____  \033[38;5;33m _  __\033[38;5;33m ____ \n\033[38;5;208m| | | |\033[38;5;202m__  __\033[38;5;33m|  _ \\ \033[38;5;33m| |/ /\033[38;5;33m/ ___|\n\033[38;5;208m| |_| |\033[38;5;202m\\ \\/ /\033[38;5;33m| |_) |\033[38;5;33m| ' /\033[38;5;33m| |  _ \n\033[38;5;208m|  _  |\033[38;5;202m >  < \033[38;5;33m|  __/ \033[38;5;33m| . \\\033[38;5;33m| |_| |\n\033[38;5;208m|_| |_|\033[38;5;202m/_/\\_\\\033[38;5;33m|_|    \033[38;5;33m|_|\\_\\\033[38;5;33m\\____|\033[0;0m\n");

		var args:Array<String> = parsed[0];
		var flags:Array<String> = parsed[1];
		if (args.length == 0)
		{
			Sys.println('Not enough arguments. Run "hxpkg help" for help');
			Sys.exit(1);
		}

		var cmd = args.shift().toLowerCase();
		if (validFlags.exists(cmd))
			for (flag in flags)
				if (!validFlags[cmd].contains(flag))
					Sys.println('Unsupported flag for $cmd command: $flag');

		switch (cmd)
		{
			case 'install':
				install(args, flags.contains('--global'), flags.contains('--force'), flags.contains('--update'));
			case 'add':
				add(args);
			case 'remove':
				remove(args);
			case 'clear':
				clear();
			case 'uninstall':
				uninstall(args, flags.contains('--force'), flags.contains('--remove-all'));
			case 'list':
				list();
			case 'lock':
				lock(args);
			case 'upgrade':
				Util.savePKGFile(Util.parsePKGFile());
				Sys.println('.hxpkg updated');
			case 'compact':
				Util.savePKGFile(Util.parsePKGFile(), false);
				Sys.println('.hxpkg compacted');
			case 'setup':
				setupAlias();
			case 'help':
				help();
			default:
				Sys.println('$cmd is not a valid command. Run "hxpkg help" for help');
		}
	}

	static function install(args:Array<String>, global:Bool, force:Bool, update:Bool):Void
	{
		Util.checkPKGFile(true);
		var pkgFile = Util.parsePKGFile();

		if (!global && !update)
			if (Util.checkLocalHaxelib())
			{
				if (!force)
				{
					Sys.println('.haxelib exists, aborting (Run with --force to continue anyway)');
					Sys.exit(1);
				}
				else if (!quiet)
					Sys.println('.haxelib exists, continuing (--force)');
			}
			else
				Util.process('haxelib', ['--quiet', 'newrepo']);

		var pkgs = pkgFile["default"];

		for (arg in args)
			if (pkgFile.exists(arg.trim()))
				pkgs = pkgs.concat(pkgFile[arg.trim()]);

		var dontSkipDependencies:Array<String> = ['grig.audio', 'hxCodec'];

		if (quiet)
			Sys.print('Installing package${pkgs.length > 1 ? 's' : ''} ${[for (pkg in pkgs) pkg.name].join(', ')}... ');

		var failedPackages:Array<String> = [];

		for (i => pkg in pkgs)
		{
			if (update)
			{
				if (!quiet)
					Sys.print('Checking current version of ${pkg.name}... ');

				var haxelibVersion:Null<String> = Util.getHaxelibVersion(pkg.name, global);
				if (haxelibVersion != null)
				{
					if (haxelibVersion != 'git')
					{
						if (haxelibVersion == pkg.version)
						{
							if (!quiet)
								Sys.println('done. Can be skipped.');

							continue;
						}
					}
					else
					{
						var hash:Null<String> = Util.getGitHashForHaxelib(pkg.name, global);
						if (hash != null && hash == pkg.branch)
						{
							if (!quiet)
								Sys.println('done. Can be skipped.');

							continue;
						}
					}
				}

				if (!quiet)
					Sys.println('done.');
			}
			if (!quiet)
				Sys.print('Installing package ${pkg.name}... ');

			var hxargs = [pkg.link != null ? '--always' : '--never', '--quiet'];
			if (!dontSkipDependencies.contains(pkg.name))
				hxargs.insert(1, '--skip-dependencies');

			if (global)
				hxargs.push('--global');
			var failMsg:String = null;

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
				if (pkg.dir != null)
					hxargs.push(pkg.dir);
				failMsg = 'Check the github repository.';
			}

			if (Util.process('haxelib', hxargs) != 0)
			{
				if (!quiet)
					Sys.println('failed. $failMsg');
				failedPackages.push(pkg.name);
			}
			else if (!quiet)
				Sys.println('done.');
		}

		if (failedPackages.length > 0)
		{
			if (quiet)
				Sys.println('failed.');
			Sys.println('Failed to install ${[for (pkg in failedPackages) pkg].join(', ')}.');
		}
		else if (quiet)
			Sys.println('done.');

		// git HXCPP auto setup
		if ([
			for (pkg in pkgs)
				if (pkg.name == 'hxcpp' && pkg.link != null && !failedPackages.contains('hxcpp')) pkg
		].length > 0)
		{
			Sys.print('Setting up hxcpp... ');
			var curCwd = Sys.getCwd();
			var pathProc = new Process('haxelib', ['libpath', 'hxcpp']);
			pathProc.exitCode();
			var path = pathProc.stdout.readAll().toString().trim();
			pathProc.close();
			Sys.setCwd(Path.join([path, 'tools', 'run']));
			Util.process('haxe', ['compile.hxml']);
			Sys.setCwd(Path.join([path, 'tools', 'hxcpp']));
			Util.process('haxe', ['compile.hxml']);
			Sys.setCwd(curCwd);
			Sys.println('done.');
		}

		// i wish haxe 5 came sooner IM SICK OF HXCODEC'S ERRORS
		if ([
			for (pkg in pkgs)
				if (pkg.name == 'hxCodec' && pkg.link != null && !failedPackages.contains('hxCodec')) pkg
		].length > 0)
		{
			Sys.print('Setting up hxCodec... ');
			var pathProc = new Process('haxelib', ['libpath', 'hxCodec']);
			pathProc.exitCode();
			var path = pathProc.stdout.readAll().toString().trim();
			pathProc.close();
			Util.process('haxelib', ['--global', 'dev', 'hxCodec', path]);
			Sys.println('done.');
		}
	}

	static function add(args:Array<String>):Void
	{
		if (!Util.checkPKGFile())
			File.saveContent('.hxpkg', '[]');

		var pkgFile = Util.parsePKGFile();

		if (args.length == 0)
		{
			Sys.println('Not enough arguments. Run "hxpkg help" for help');
			Sys.exit(1);
		}

		var profile:String = 'default';

		if (args.indexOf('profile') != -1)
		{
			if (args.indexOf('profile') + 1 >= args.length)
			{
				Sys.println('No profile specified, aborting');
				Sys.exit(1);
			}

			profile = args[args.indexOf('profile') + 1].trim();
			if (pkgFile[profile] == null)
				pkgFile.set(profile, []);
			args = args.splice(0, args.indexOf('profile'));
		}

		var packages = pkgFile[profile];
		if (profile != 'default')
			packages.concat(pkgFile['default']);

		final pkgMap = [for (pkg in packages) pkg.name => pkg];

		if (pkgMap.exists(args[0]))
		{
			Sys.println('Package ${args[0]} already exists in the .hxpkg, aborting');
			Sys.exit(1);
		}

		var pkg:PKG = {name: args[0]}

		if (args.length >= 3)
		{
			pkg.link = args[1];
			pkg.branch = args[2];
			if (args.length == 4)
				pkg.dir = args[3];
		}
		else if (args[1] != null)
		{
			if (urlMatch.match(args[1]))
				pkg.link = args[1];
			else
				pkg.version = args[1];
		}

		pkgFile[profile].push(pkg);
		Sys.println('Added package ${args[0]}${profile != null ? ' (profile $profile)' : ''} to .hxpkg');
		Util.savePKGFile(pkgFile);
	}

	static function remove(args:Array<String>):Void
	{
		Util.checkPKGFile(true);
		var pkgFile = Util.parsePKGFile();

		if (args.length == 0)
		{
			Sys.println('Not enough arguments. Run "hxpkg help" for help');
			Sys.exit(1);
		}

		var profile:String = 'default';

		if (args.indexOf('profile') != -1)
		{
			if (args.indexOf('profile') + 1 >= args.length)
			{
				Sys.println('No profile specified, aborting');
				Sys.exit(1);
			}

			profile = args[args.indexOf('profile') + 1].trim();
			if (pkgFile[profile] == null)
				pkgFile.set(profile, []);
			args = args.splice(0, args.indexOf('profile'));
		}

		var packages = pkgFile[profile];
		if (profile != 'default')
			packages.concat(pkgFile['default']);

		final pkgMap = [for (pkg in packages) pkg.name => pkg];

		for (arg in args)
		{
			if (!pkgMap.exists(arg))
			{
				Sys.println('Package $arg doesn\'t exist in the .hxpkg, continuing');
				continue;
			}

			pkgFile[profile].remove(pkgMap[arg]);
			Sys.println('Removed package ${arg}${profile != 'default' ? ' (profile $profile)' : ''} from .hxpkg');
		}

		if (pkgFile[profile].length == 0)
			pkgFile.remove(profile);

		Util.savePKGFile(pkgFile);
	}

	static function clear():Void
	{
		File.saveContent('.hxpkg', '[]');
	}

	static function uninstall(args:Array<String>, force:Bool, removeAll:Bool):Void
	{
		if (!Util.checkLocalHaxelib())
			if (!force)
			{
				Sys.println('.haxelib exists, aborting (Run with --force to continue anyway)');
				Sys.exit(1);
			}
			else if (!quiet)
				Sys.println('.haxelib exists, continuing (--force)');

		Util.checkPKGFile(true);
		var pkgFile = Util.parsePKGFile();

		if (removeAll)
		{
			Util.process('haxelib', ['--quiet', 'deleterepo']);
			Sys.println('Uninstalled all packages successfully');
		}
		else
		{
			var profile:String = 'default';

			if (args.length > 0)
				profile = args[0].trim();

			var packages = pkgFile[profile];
			if (profile != 'default')
				packages.concat(pkgFile['default']);
			var failedPackages:Array<String> = [];
			for (pkg in packages)
			{
				if (!quiet)
					Sys.print('Uninstalling package ${pkg.name}... ');
				if (Util.process('haxelib', ['--never', '--quiet', 'remove', pkg.name]) != 0)
				{
					if (!quiet)
						Sys.println('failed.');
					failedPackages.push(pkg.name);
				}
				else if (!quiet)
					Sys.println('done. ');
			}

			if (failedPackages.length > 0)
				Sys.println('Failed to uninstall ${[for (pkg in failedPackages) pkg].join(", ")}.');
			else
				Sys.println('Uninstalled all packages successfully.');
		}
	}

	static function list():Void
	{
		Util.checkPKGFile(true);
		var pkgFile = Util.parsePKGFile();

		var allpkgs = [];
		for (pkgs in pkgFile)
			allpkgs = allpkgs.concat(pkgs);

		if (allpkgs.length == 0)
		{
			Sys.println('No packages to list, aborting');
			Sys.exit(1);
		}

		var msgs:Array<String> = [];

		for (profile => packages in pkgFile)
		{
			var msg = '$profile:\n';

			for (pkg in packages)
			{
				var pkgmsg = pkg.name;

				if (pkg.version != null)
					pkgmsg += ' ${pkg.version}';
				else if (pkg.link != null)
				{
					pkgmsg += ' ${pkg.link}';
					if (pkg.branch != null)
						pkgmsg += ' ${pkg.branch}';
					if (pkg.dir != null)
						pkgmsg += ' ${pkg.dir}';
				}

				msg += '$pkgmsg\n';
			}
			msgs.push(msg);
		}

		ArraySort.sort(msgs, (a, b) -> (a > b ? 1 : a < b ? -1 : 0));
		for (msg in msgs)
			Sys.println(msg);
	}

	static function lock(args:Array<String>):Void
	{
		Util.checkPKGFile(true);
		var pkgFile = Util.parsePKGFile();

		var profile:String = 'default';
		if (args.indexOf('profile') != -1)
		{
			if (args.indexOf('profile') + 1 >= args.length)
			{
				Sys.println('No profile specified, aborting');
				Sys.exit(1);
			}

			profile = args[args.indexOf('profile') + 1].trim();
			if (pkgFile[profile] == null)
				pkgFile.set(profile, []);
			args = args.splice(0, args.indexOf('profile'));
		}

		for (pkg in pkgFile[profile])
		{
			Sys.println('Locking ${pkg.name}');

			var haxelibVersion:Null<String> = Util.getHaxelibVersion(pkg.name);
			if (haxelibVersion != null)
			{
				if (haxelibVersion != 'git')
				{
					pkg.version = haxelibVersion;
				}
				else
				{
					var hash:Null<String> = Util.getGitHashForHaxelib(pkg.name);
					if (hash == null)
					{
						Sys.println('Failed to get git hash of ${pkg.name}');
						continue;
					}

					pkg.branch = hash;
				}
			}
			else
			{
				Sys.println('Package ${pkg.name} not installed - can\'t lock');
			}
		}

		Sys.println('Locked package versions');
		Util.savePKGFile(pkgFile);
	}

	/*
		Based on:
		https://github.com/openfl/hxp/blob/master/src/hxp/System.hx#L1505
		https://github.com/openfl/lime/blob/develop/tools/utils/PlatformSetup.hx#L812
	 */
	static function setupAlias():Void
	{
		var sysName = Sys.systemName().toLowerCase();
		try
		{
			if (sysName.contains('window'))
			{
				var haxePath:String = Sys.getEnv('HAXEPATH').trim();
				if (haxePath == null || haxePath == '')
					haxePath = 'C:\\HaxeToolkit\\haxe';

				File.saveContent(Path.join([haxePath, 'hxpkg.bat']), '@echo off\nhaxelib --global run hxpkg %*');
			}
			else if (sysName.contains('linux') || sysName.contains('mac'))
			{
				Sys.command('${sysName.contains('mac') ? '' : 'sudo '}cp -f ${Path.join([Util.ogPath, 'hxpkg.sh'])} ${Path.join(["/usr/local/bin", 'hxpkg'])}');
				Sys.command('${sysName.contains('mac') ? '' : 'sudo '}chmod 775 ${Path.join(["/usr/local/bin", 'hxpkg'])}');
			}
			else
			{
				Sys.println('Installing the command line alias is not supported on this OS');
				Sys.exit(1);
			}

			// THANK YOU CYN
			Sys.println('Installed command-line alias "hxpkg" for "haxelib --global run hxpkg"');
		}
		catch (e)
		{
			Sys.println('Failed to install command-line alias');
			Sys.exit(1);
		}
	}

	static function help():Void
	{
		Sys.println("Usage: hxpkg [command] [flags]

Commands:

hxpkg install - Installs all packages from the .hxpkg file
hxpkg add - Adds a package to the .hxpkg file
	hxpkg add [name] [version/git link] [branch/hash] profile [profile]
    Only name is required
hxpkg remove - Removes a package from the .hxpkg file
hxpkg clear - Removes all packages from the .hxpkg file
hxpkg uninstall - Removes all packages installed by the .hxpkg file
	Does not remove dependencies
hxpkg list - Lists all packages in the .hxpkg file
hxpkg lock - Locks all package versions in the .hxpkg file
hxpkg upgrade - Updates the .hxpkg file to the new format
	Also happens when attempting to add a package profile in the old format
hxpkg compact - Compacts the .hxpkg file
hxpkg setup - Installs the command alias for hxpkg. Use \"haxelib --global run hxpkg setup\" to install
hxpkg help - Shows help information

Flags:
--quiet: Silent Install/Uninstall
--force: Installs/Uninstalls even if .haxelib exists

install:
	--global: Installs packages globally
	--update: Updates installed packages to the latest version
uninstall:
	--remove-all: Removes the local repo");
	}
}
