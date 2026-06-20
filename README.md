# Extest - X11 XTEST Reimplementation for Steam Controller on Wayland

Extest is a drop in replacement for the X11 XTEST extension. It creates a virtual device with the uinput kernel module.
It's been primarily developed for allowing the desktop functionality on the Steam Controller to work while Steam is open on Wayland.

## Why this fork?

On **Fedora 44 with GNOME (Wayland)** and **AMD GPUs**, the XTEST extension is **unavailable** in Xwayland.
This causes a critical bug: whenever a controller is connected (Bluetooth or 2.4G dongle),
Steam's `CSteamController` thread segfaults at instruction pointer `0x0`, crashing Steam entirely.

The crash affects:
- Any controller (Xbox, PlayStation, 8BitDo, generic HID)
- Both native Steam (RPM Fusion) and Flatpak Steam
- All controller modes (Bluetooth HID, 2.4G XInput dongle)
- Gamescope does **not** fix it — the crash is in Steam's own controller thread, not the game

**Console log before fix:**
```
src/clientdll/inputgenerator_linux.cpp (347) : The XTest extension doesn't exist
The XTest extension doesn't exist, using old style input simulation
CSteamControlle: segfault at 0 ip 0000000000000000
```

### What we added

The original extest only hooked the `XTestFake*` functions (key/motion/button events), but Steam calls
`XTestQueryExtension()` **first** to check if XTEST exists. Since Xwayland reports it as unavailable,
Steam falls back to a crashy "old style" code path and never calls the hooked functions.

This fork additionally hooks:

- **`XTestQueryExtension()`** — Returns `true` so Steam believes XTEST is available
- **`XQueryExtension("XTEST")`** — Returns `true` for the raw X11 extension query

With these hooks, Steam proceeds to call the `XTestFake*` functions which extest correctly handles via uinput.

## Quick Install (pre-built binary)

Download the pre-built `libextest.so` from the [Releases](https://github.com/nmd2k/extest-steam-input-fix/releases) page, then:

```sh
# Install the library
mkdir -p ~/.local/lib
cp libextest.so ~/.local/lib/

# Run the setup script to configure your Steam launcher
chmod +x install.sh
./install.sh
```

## Usage (manual)

Be sure you have [Rust](https://www.rust-lang.org/learn/get-started) installed.
You will also need to install a 32 bit Rust toolchain.

```sh
rustup target add i686-unknown-linux-gnu
cargo build --release
```

This will create a library named `libextest.so` in `target/i686-unknown-linux-gnu/release`.
Note that this library is 32 bit by default because Steam is a 32 bit application.

You will also need to add your user to the `input` group if not added already, so that your user can be allowed to actually create fake devices:

```sh
sudo usermod -a -G input <your username>
```

You can then use `LD_PRELOAD` to override any app that wants to use XTEST functions that have been reimplemented by Extest:

```sh
LD_PRELOAD=/path/to/libextest.so steam
```

For a permanent setup that also works from your desktop/app menu launcher, run:

```sh
./install.sh
```

This creates a wrapper script at `~/.local/bin/steam-extest` and a desktop file override
at `~/.local/share/applications/steam.desktop` so Steam always launches with extest.

## License

MIT
