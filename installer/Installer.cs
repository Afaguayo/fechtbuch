// Fechtbuch installer: finds Half Sword, installs UE4SS if missing, installs/updates the
// Fechtbuch mod and enables it (and replaces the old "Battle Eye" install). Run with no arguments for the menu.
using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.IO;
using System.IO.Compression;
using System.Linq;
using System.Reflection;
using System.Security.Principal;
using System.Text.RegularExpressions;
using Microsoft.Win32;

static class Installer
{
    const string GameRelPath = @"steamapps\common\Half Sword\HalfswordUE5\Binaries\Win64";
    const string GameExe = "HalfSwordUE5-Win64-Shipping";
    const string ModName = "Fechtbuch";
    static readonly string[] UnneededMods = { "CheatManagerEnablerMod", "ConsoleCommandsMod", "ConsoleEnablerMod" };

    static int Main(string[] args)
    {
        Console.Title = "Fechtbuch installer";
        Console.ForegroundColor = ConsoleColor.Yellow;
        Console.WriteLine();
        Console.WriteLine("  FECHTBUCH  -  combat HUD for Half Sword");
        Console.ResetColor();
        Console.WriteLine("  ----------------------------------------");
        Console.WriteLine();
        try
        {
            // optional 2nd argument: game's Win64 folder (skips the search)
            string win64 = args.Length > 1 ? args[1] : FindGame();
            if (win64 == null) win64 = AskForGame();
            if (win64 == null) return Done(1);
            Console.WriteLine("  Game found: " + win64);
            Console.WriteLine();

            WaitForGameClosed();

            string choice = args.Length > 0 ? args[0] : Menu();
            switch (choice)
            {
                case "1": case "install": Install(win64); break;
                case "2": case "uninstall": UninstallMod(win64); break;
                case "3": case "uninstall-all": UninstallAll(win64); break;
                default: Console.WriteLine("  Nothing done."); break;
            }
            return Done(0);
        }
        catch (UnauthorizedAccessException)
        {
            if (!IsAdmin())
            {
                Console.WriteLine("  Windows blocked writing to the game folder. Restarting as administrator...");
                var psi = new ProcessStartInfo(Assembly.GetExecutingAssembly().Location, string.Join(" ", args.Select(a => "\"" + a + "\""))) { Verb = "runas", UseShellExecute = true };
                try { Process.Start(psi); return 0; } catch { }
            }
            Fail("Could not write to the game folder (access denied).");
            return Done(1);
        }
        catch (Exception e)
        {
            Fail(e.Message);
            return Done(1);
        }
    }

    static string Menu()
    {
        Console.WriteLine("  [1] Install / update Fechtbuch");
        Console.WriteLine("  [2] Uninstall Fechtbuch (keep UE4SS)");
        Console.WriteLine("  [3] Uninstall Fechtbuch and UE4SS");
        Console.WriteLine();
        Console.Write("  Choose 1, 2 or 3: ");
        string s = (Console.ReadLine() ?? "").Trim();
        Console.WriteLine();
        return s;
    }

    // ---------------------------------------------------------------- install

    static void Install(string win64)
    {
        string ue4ss = Path.Combine(win64, "ue4ss");
        string mods = Path.Combine(ue4ss, "Mods");

        if (File.Exists(Path.Combine(win64, "dwmapi.dll")) && File.Exists(Path.Combine(ue4ss, "UE4SS.dll")))
        {
            Step("UE4SS already installed, keeping it.");
        }
        else
        {
            Step("Installing UE4SS (mod loader)...");
            ExtractResource("ue4ss.zip", win64);
        }

        // Fechtbuch was called "Battle Eye" before 1.1: carry its settings over and remove it
        string oldDir = Path.Combine(mods, "BattleEye");
        string newDir = Path.Combine(mods, ModName);
        if (Directory.Exists(oldDir))
        {
            Step("Replacing the old Battle Eye install (settings kept)...");
            string oldSettings = Path.Combine(oldDir, "settings.txt");
            if (File.Exists(oldSettings) && !File.Exists(Path.Combine(newDir, "settings.txt")))
            {
                Directory.CreateDirectory(newDir);
                File.Copy(oldSettings, Path.Combine(newDir, "settings.txt"));
            }
            Directory.Delete(oldDir, true);
        }

        Step("Installing Fechtbuch...");
        ExtractResource("Fechtbuch.zip", mods);   // settings.txt is not in the zip, so your settings survive updates

        Step("Enabling Fechtbuch in mods.txt...");
        string list = Path.Combine(mods, "mods.txt");
        var lines = File.Exists(list) ? File.ReadAllLines(list).ToList() : new List<string>();
        lines.RemoveAll(l => l.Split(':')[0].Trim() == "BattleEye");
        for (int i = 0; i < lines.Count; i++)
        {
            string name = lines[i].Split(':')[0].Trim();
            if (UnneededMods.Contains(name)) lines[i] = name + " : 0";   // console/cheat mods aren't needed
        }
        int existing = lines.FindIndex(l => l.Split(':')[0].Trim() == ModName);
        if (existing >= 0) lines[existing] = ModName + " : 1";
        else
        {
            int at = lines.FindIndex(l => l.StartsWith("; Built-in keybinds"));
            if (at < 0) at = lines.FindIndex(l => l.Split(':')[0].Trim() == "Keybinds");
            if (at < 0) lines.Add(ModName + " : 1"); else lines.Insert(at, ModName + " : 1");
        }
        File.WriteAllLines(list, lines);

        Console.WriteLine();
        Console.ForegroundColor = ConsoleColor.Green;
        Console.WriteLine("  Fechtbuch is installed. Start Half Sword and fight!");
        Console.ResetColor();
        Console.WriteLine();
        Console.WriteLine("  Z      tag / untag the enemy you're looking at");
        Console.WriteLine("  Home   Fechtbuch menu (arrows to change, Enter to toggle)");
        Console.WriteLine("  F7     HUD on/off      F8 reset counters");
    }

    static void UninstallMod(string win64)
    {
        string mods = Path.Combine(win64, "ue4ss", "Mods");
        bool removed = false;
        foreach (string name in new[] { ModName, "BattleEye" })
        {
            string dir = Path.Combine(mods, name);
            if (Directory.Exists(dir)) { Directory.Delete(dir, true); removed = true; }
        }
        Step(removed ? "Removed Fechtbuch." : "Fechtbuch was not installed.");
        string list = Path.Combine(mods, "mods.txt");
        if (File.Exists(list))
            File.WriteAllLines(list, File.ReadAllLines(list).Where(l => { string n = l.Split(':')[0].Trim(); return n != ModName && n != "BattleEye"; }));
    }

    static void UninstallAll(string win64)
    {
        Console.Write("  This removes UE4SS and every UE4SS mod in this game. Type YES to continue: ");
        if ((Console.ReadLine() ?? "").Trim() != "YES") { Console.WriteLine("  Cancelled."); return; }
        UninstallMod(win64);
        string ue4ss = Path.Combine(win64, "ue4ss");
        if (Directory.Exists(ue4ss)) Directory.Delete(ue4ss, true);
        string dll = Path.Combine(win64, "dwmapi.dll");
        if (File.Exists(dll)) File.Delete(dll);
        Step("Removed UE4SS.");
    }

    static void ExtractResource(string name, string destRoot)
    {
        destRoot = Path.GetFullPath(destRoot);
        using (Stream s = Assembly.GetExecutingAssembly().GetManifestResourceStream(name))
        using (var zip = new ZipArchive(s, ZipArchiveMode.Read))
        {
            foreach (ZipArchiveEntry e in zip.Entries)
            {
                string dest = Path.GetFullPath(Path.Combine(destRoot, e.FullName));
                if (!dest.StartsWith(destRoot, StringComparison.OrdinalIgnoreCase)) continue;  // ignore paths escaping the folder
                if (e.Name.Length == 0) { Directory.CreateDirectory(dest); continue; }
                Directory.CreateDirectory(Path.GetDirectoryName(dest));
                e.ExtractToFile(dest, true);
            }
        }
    }

    // ---------------------------------------------------------------- finding the game

    static string FindGame()
    {
        var steamRoots = new List<string>();
        foreach (var key in new[] { @"HKEY_CURRENT_USER\Software\Valve\Steam|SteamPath",
                                    @"HKEY_LOCAL_MACHINE\SOFTWARE\WOW6432Node\Valve\Steam|InstallPath",
                                    @"HKEY_LOCAL_MACHINE\SOFTWARE\Valve\Steam|InstallPath" })
        {
            var parts = key.Split('|');
            var v = Registry.GetValue(parts[0], parts[1], null) as string;
            if (!string.IsNullOrEmpty(v)) steamRoots.Add(v.Replace('/', '\\'));
        }
        steamRoots.Add(@"C:\Program Files (x86)\Steam");

        var libraries = new List<string>();
        foreach (string root in steamRoots.Distinct(StringComparer.OrdinalIgnoreCase))
        {
            libraries.Add(root);
            string vdf = Path.Combine(root, @"steamapps\libraryfolders.vdf");
            if (!File.Exists(vdf)) continue;
            foreach (Match m in Regex.Matches(File.ReadAllText(vdf), "\"path\"\\s+\"([^\"]+)\""))
                libraries.Add(m.Groups[1].Value.Replace(@"\\", @"\"));
        }
        foreach (string lib in libraries.Distinct(StringComparer.OrdinalIgnoreCase))
        {
            string win64 = Path.Combine(lib, GameRelPath);
            if (File.Exists(Path.Combine(win64, GameExe + ".exe"))) return win64;
        }
        return null;
    }

    static string AskForGame()
    {
        Console.WriteLine("  Couldn't find Half Sword automatically.");
        Console.WriteLine("  Paste the path of your 'Half Sword' game folder (Steam > Half Sword > Manage > Browse local files):");
        Console.Write("  > ");
        string p = (Console.ReadLine() ?? "").Trim().Trim('"');
        foreach (string candidate in new[] { Path.Combine(p, @"HalfswordUE5\Binaries\Win64"), p })
            if (File.Exists(Path.Combine(candidate, GameExe + ".exe"))) return candidate;
        Fail("That folder doesn't contain Half Sword.");
        return null;
    }

    static void WaitForGameClosed()
    {
        while (Process.GetProcessesByName(GameExe).Length > 0)
        {
            Console.WriteLine("  Half Sword is running. Close the game, then press Enter.");
            if (Console.ReadLine() == null) throw new Exception("Half Sword is still running.");
        }
    }

    // ---------------------------------------------------------------- helpers

    static bool IsAdmin()
    {
        return new WindowsPrincipal(WindowsIdentity.GetCurrent()).IsInRole(WindowsBuiltInRole.Administrator);
    }

    static void Step(string msg) { Console.WriteLine("  - " + msg); }

    static void Fail(string msg)
    {
        Console.ForegroundColor = ConsoleColor.Red;
        Console.WriteLine("  Error: " + msg);
        Console.ResetColor();
    }

    static int Done(int code)
    {
        Console.WriteLine();
        Console.Write("  Press Enter to close.");
        Console.ReadLine();
        return code;
    }
}
