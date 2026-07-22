"""Build the SD-card ROM pack read by src/rtl/rom_loader.sv.

Raw sectors, no filesystem - the FPGA has no FAT reader (yet), and a fixed
layout keeps the gateware small. Written past the first megabyte so a card's
partition table area is left alone.

    sector 2048              header: "MCRPACK1", slot count, slot names
    sector 2049 + N*256      slot N payload, 128 KB

Payload layout == the core's ROM download address map:
    0x00000-0x0FFFF  CPU program ROM   (64 KB, zero padded)
    0x10000-0x13FFF  sound CPU ROM     (16 KB)
    0x14000-0x1BFFF  sprite gfx2       (32 KB)
    0x1C000-0x1DFFF  background gfx1_1 ( 8 KB)
    0x1E000-0x1FFFF  background gfx1_2 ( 8 KB)

Run from the repo root:  python3 tools/make_rompack.py [game ...]
"""

import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import merge_roms  # noqa: E402

SECTOR       = 512
PACK_BASE    = 2048            # sector; 1 MiB into the card
SLOT_SECTORS = 256             # 128 KiB per slot
SLOT_BYTES   = SLOT_SECTORS * SECTOR
OUT_PATH     = "mcr_rompack.img"

# region -> (offset, size) within a slot payload
LAYOUT = {
    "main":   (0x00000, 0x10000),
    "snd":    (0x10000, 0x04000),
    "gfx2":   (0x14000, 0x08000),
    "gfx1_1": (0x1C000, 0x02000),
    "gfx1_2": (0x1E000, 0x02000),
}


def build_slot(regions, game):
    """Pack one game's regions into a 128 KiB slot image."""
    buf = bytearray(SLOT_BYTES)
    for name, (off, size) in LAYOUT.items():
        data = regions[name]
        if len(data) > size:
            raise SystemExit(
                f"{game}: {name} is {len(data)} bytes, larger than its "
                f"{size}-byte slot region")
        buf[off:off + len(data)] = data
    return bytes(buf)


def main(argv):
    # LAYOUT above is the MCR-2 download map. MCR-1 uses a different one
    # (CPU 0x0000, sound 0x8000, sprites 0x10000, bg 0x18000/0x19000), so
    # MCR-1 games cannot share this pack format - that is the pack-format-v2
    # work (per-slot family + layout) tracked in docs/mcr_core_roadmap.md.
    # Until then, restrict to the MCR-2 family; MCR-1 boots from baked BSRAM.
    mcr2_games = [g for g, s in merge_roms.GAME_SPECS.items()
                  if s.get("family", "mcr2") == "mcr2"]
    games = argv[1:] or mcr2_games

    slots = []
    for game in games:
        if game not in merge_roms.GAME_SPECS:
            raise SystemExit(f"Unknown game '{game}'. "
                             f"Choices: {', '.join(mcr2_games)}")
        if merge_roms.GAME_SPECS[game].get("family", "mcr2") != "mcr2":
            raise SystemExit(
                f"'{game}' is not an MCR-2 game; the pack format is MCR-2 "
                "only for now (see docs/mcr_core_roadmap.md, pack v2). "
                "MCR-1 games boot from baked BSRAM.")
        regions = merge_roms.collect(game, quiet=True)
        if regions is None:
            print(f"  skipping {game} (ROM zip not found)")
            continue
        slots.append((game, build_slot(regions, game)))

    if not slots:
        raise SystemExit("No games could be packed - check roms/ for the zips.")

    # header sector
    hdr = bytearray(SECTOR)
    hdr[0:8] = b"MCRPACK1"
    hdr[8]   = len(slots)
    for i, (game, _) in enumerate(slots):
        name = game.encode("ascii")[:15]
        hdr[16 + i * 16: 16 + i * 16 + len(name)] = name

    with open(OUT_PATH, "wb") as f:
        f.write(hdr)
        f.write(bytes(SECTOR * (0)))          # payload starts at PACK_BASE+1
        for _, payload in slots:
            f.write(payload)

    total = os.path.getsize(OUT_PATH)
    print(f"\nWrote {OUT_PATH} ({total} bytes = {total // 1024} KiB)")
    print("\nSlot assignment (game-select DIP value -> game):")
    for i, (game, _) in enumerate(slots):
        print(f"  slot {i}  (SW1-3..5 = {i:03b})  {game}")

    print(f"""
To write it to a card, at sector {PACK_BASE} (1 MiB in):

  macOS:    diskutil list                 # find the card, e.g. /dev/disk4
            diskutil unmountDisk /dev/disk4
            sudo dd if={OUT_PATH} of=/dev/rdisk4 bs=512 seek={PACK_BASE}

  Linux:    sudo dd if={OUT_PATH} of=/dev/sdX bs=512 seek={PACK_BASE} conv=fsync

  Windows:  use Win32DiskImager/Rufus in raw mode, or in WSL use the Linux
            command above against /dev/sdX.

CHECK THE DEVICE NAME TWICE - dd to the wrong disk destroys it. Use a card
dedicated to this; anything already past the 1 MiB mark will be overwritten.
""")


if __name__ == "__main__":
    main(sys.argv)
