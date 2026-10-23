$downloadList = @(
    @{
        name = "draconis_roar_1.ogg";
        url = "https://raw.githubusercontent.com/ElCeejo/draconis/main/sounds/fire_dragon/draconis_fire_dragon.1.ogg";
        source = "ElCeejo/draconis (Minetest Dragon Mod)";
        tag = "dragon_roar_alt1"
    },
    @{
        name = "draconis_roar_2.ogg";
        url = "https://raw.githubusercontent.com/ElCeejo/draconis/main/sounds/fire_dragon/draconis_fire_dragon.2.ogg";
        source = "ElCeejo/draconis (Minetest Dragon Mod)";
        tag = "dragon_roar_alt2"
    },
    @{
        name = "veloren_wyvern_roar.ogg";
        url = "https://raw.githubusercontent.com/veloren/veloren/master/assets/voxygen/audio/sfx/utterance/wyvern_angry.ogg";
        source = "veloren/veloren (Open-source RPG)";
        tag = "dragon_roar_alt3"
    },
    @{
        name = "veloren_gigas_roar.ogg";
        url = "https://raw.githubusercontent.com/veloren/veloren/master/assets/voxygen/audio/sfx/abilities/gigas_frost_roar.ogg";
        source = "veloren/veloren (Open-source RPG)";
        tag = "dragon_roar_alt4"
    },
    @{
        name = "wesnoth_drake_roar.ogg";
        url = "https://raw.githubusercontent.com/wesnoth/wesnoth/master/data/core/sounds/drake-die.ogg";
        source = "wesnoth/wesnoth (Battle for Wesnoth)";
        tag = "dragon_roar_alt5"
    },
    @{
        name = "draconis_wing_flap.ogg";
        url = "https://raw.githubusercontent.com/ElCeejo/draconis/main/sounds/draconis_flap.ogg";
        source = "ElCeejo/draconis (Minetest Dragon Mod)";
        tag = "dragon_flap"
    },
    @{
        name = "draconis_dragon_slam.ogg";
        url = "https://raw.githubusercontent.com/ElCeejo/draconis/main/sounds/effects/draconis_slam.ogg";
        source = "ElCeejo/draconis (Minetest Dragon Mod)";
        tag = "dragon_footstep_slam"
    },
    @{
        name = "draconis_fire_breath.ogg";
        url = "https://raw.githubusercontent.com/ElCeejo/draconis/main/sounds/draconis_fire_breath.ogg";
        source = "ElCeejo/draconis (Minetest Dragon Mod)";
        tag = "dragon_fire"
    },
    @{
        name = "veloren_fire_breath.ogg";
        url = "https://raw.githubusercontent.com/veloren/veloren/master/assets/voxygen/audio/sfx/abilities/fire_breath.ogg";
        source = "veloren/veloren (Open-source RPG)";
        tag = "dragon_fire_alt"
    },
    @{
        name = "veloren_wyvern_hurt.ogg";
        url = "https://raw.githubusercontent.com/veloren/veloren/master/assets/voxygen/audio/sfx/utterance/wyvern_hurt.ogg";
        source = "veloren/veloren (Open-source RPG)";
        tag = "dragon_hurt"
    },
    @{
        name = "wesnoth_drake_hit.ogg";
        url = "https://raw.githubusercontent.com/wesnoth/wesnoth/master/data/core/sounds/drake-hit-1.ogg";
        source = "wesnoth/wesnoth (Battle for Wesnoth)";
        tag = "dragon_hurt_alt"
    },
    @{
        name = "veloren_sword_swing.ogg";
        url = "https://raw.githubusercontent.com/veloren/veloren/master/assets/voxygen/audio/sfx/abilities/swing_sword.ogg";
        source = "veloren/veloren (Open-source RPG)";
        tag = "knight_attack"
    },
    @{
        name = "flare_sword_attack.ogg";
        url = "https://raw.githubusercontent.com/flareteam/flare-game/master/mods/fantasycore/soundfx/melee_attack.ogg";
        source = "flareteam/flare-game (Flare RPG)";
        tag = "knight_attack_alt"
    },
    @{
        name = "flare_step_metal.ogg";
        url = "https://raw.githubusercontent.com/flareteam/flare-game/master/mods/fantasycore/soundfx/steps/step_metal1.ogg";
        source = "flareteam/flare-game (Flare RPG)";
        tag = "knight_footstep"
    },
    @{
        name = "flare_knight_death.ogg";
        url = "https://raw.githubusercontent.com/flareteam/flare-game/master/mods/fantasycore/soundfx/male_die.ogg";
        source = "flareteam/flare-game (Flare RPG)";
        tag = "knight_death"
    },
    @{
        name = "veloren_arrow_shot.ogg";
        url = "https://raw.githubusercontent.com/veloren/veloren/master/assets/voxygen/audio/sfx/abilities/arrow_shot_1.ogg";
        source = "veloren/veloren (Open-source RPG)";
        tag = "ballista_fire"
    },
    @{
        name = "wesnoth_crossbow.ogg";
        url = "https://raw.githubusercontent.com/wesnoth/wesnoth/master/data/core/sounds/crossbow.ogg";
        source = "wesnoth/wesnoth (Battle for Wesnoth)";
        tag = "ballista_fire_alt"
    },
    @{
        name = "veloren_impact_klonk.ogg";
        url = "https://raw.githubusercontent.com/veloren/veloren/master/assets/voxygen/audio/sfx/abilities/smashklonk.ogg";
        source = "veloren/veloren (Open-source RPG)";
        tag = "ballista_impact"
    },
    @{
        name = "veloren_splash_big.ogg";
        url = "https://raw.githubusercontent.com/veloren/veloren/master/assets/voxygen/audio/sfx/footsteps/splash_big.ogg";
        source = "veloren/veloren (Open-source RPG)";
        tag = "water_splash"
    },
    @{
        name = "wesnoth_water_blast.wav";
        url = "https://raw.githubusercontent.com/wesnoth/wesnoth/master/data/core/sounds/water-blast.wav";
        source = "wesnoth/wesnoth (Battle for Wesnoth)";
        tag = "water_splash_alt"
    }
)

$targetDir = "c:\Proyectos\Dragonv3-original\assets\audio\github_sources"
if (!(Test-Path $targetDir)) { New-Item -ItemType Directory -Force -Path $targetDir }

Write-Host "=== DESCARGANDO SONIDOS REALES DE GITHUB ==="
$wc = New-Object System.Net.WebClient
$wc.Headers.Add("User-Agent", "Mozilla/5.0")

foreach ($item in $downloadList) {
    $outPath = Join-Path $targetDir $item.name
    Write-Host "Descargando $($item.name) desde $($item.source)..."
    try {
        $wc.DownloadFile($item.url, $outPath)
        $len = (Get-Item $outPath).Length
        Write-Host "  -> OK! Tamano: $len bytes"
    } catch {
        Write-Host "  -> ERROR: $_"
    }
}
Write-Host "Descargas completadas."
