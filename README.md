<div align="center">
  <h1><img src="./data/icons/hicolor/scalable/apps/com.raggesilver.BlackBox.svg" height="64"/>Black Box</h1>
  <h4>An elegant and customizable terminal for GNOME</h4>
  <p>
    <a href="#features">Features</a> •
    <a href="#install">Install</a> •
    <a href="#gallery">Gallery</a> •
    <a href="./CHANGELOG.md">Changelog</a>
    <br/>
    <a href="https://gitlab.gnome.org/raggesilver/blackbox/-/wikis/home">Wiki</a> •
    <a href="./COPYING">License</a> •
    <a href="./CONTRIBUTING.md">Contributing</a>
  </p>
  <p>
  </p>
</div>

<div align="center">
  <img src="https://github.com/hunter-gunter/blackbox-terminal/blob/main/img/blackbox-terminal.png?raw=true" alt="Preview"/><br/>
  <small><i>
    Black Box 0.15.0 (theme <a href="https://github.com/storm119/Tilix-Themes/blob/master/Themes/japanesque.json" target="_blank">"Japanesque"</a>, fetch <a href="https://github.com/Rosettea/bunnyfetch">bunnyfetch</a>)
  </i></small>
  <br/><br/>
</div>

## Features
**New :**
- Added an SSH connection manager with saved profiles, quick-connect actions, and tab naming.
- New pane layout controls allow splitting a tab into 2, 3, or 4 panes.
- Added the option to mirror input across panes for synchronized commands.
- Added pane layout and broadcast controls to the main and tab context menus, plus an SSH menu button in the header bar.

**Current Features :**
- Color schemes - ([Tilix](https://github.com/gnunn1/tilix) compatible color scheme support)
- Theming - your color scheme can be used to style the whole app
- Background transparency
- Custom fonts, padding, and cell spacing
- Tabs
- Support for drag and dropping files
- Sixel (experimental)
- Customizable keybindings
- Toggle-able header bar
- Search your backlog with text or regex
- Context aware header bar - the header bar changes colors when running commands with sudo and in ssh sessions
- Desktop notifications - get notified when a command is finished in the background
- Customizable UI

## Install

**Flathub**

<a href='https://flathub.org/apps/details/com.raggesilver.BlackBox'><img width='240' alt='Download on Flathub' src='https://flathub.org/assets/badges/flathub-badge-en.svg'/></a>

```bash
flatpak install flathub com.raggesilver.BlackBox
```

**Flatpak Nightly**

You can also download the most recent build. Note that these are _unstable_ and completely unavailable if the latest pipeline failed.

- [Flatpak](https://gitlab.gnome.org/raggesilver/blackbox/-/jobs/artifacts/main/raw/blackbox.flatpak?job=flatpak)
- [Zip](https://gitlab.gnome.org/raggesilver/blackbox/-/jobs/artifacts/main/download?job=flatpak)

**Looking for an older release?**

Check out the [releases page](https://gitlab.gnome.org/raggesilver/blackbox/-/releases).

## Compile

**Flatpak**

To build and run Black Box, use GNOME Builder or VS Code along with [Vala](https://marketplace.visualstudio.com/items?itemName=prince781.vala) and [Flatpak](https://marketplace.visualstudio.com/items?itemName=bilelmoussaoui.flatpak-vscode) extensions.

If you want to build Black Box manually, look at the build script in [.gitlab-ci.yml](./.gitlab-ci.yml).

**Compile without Flatpack**
```bash
meson setup builddir --prefix=/usr --buildtype=release -Dblackbox_is_flatpak=false
meson compile -C builddir
sudo meson install -C builddir
blackbox
```
## Translations

Black Box is accepting translations through Weblate! If you'd like to
contribute with translations, visit the
[Weblate project](https://hosted.weblate.org/projects/blackbox/).

<a href="https://hosted.weblate.org/projects/blackbox/blackbox/">
  <img src="https://hosted.weblate.org/widgets/blackbox/-/blackbox/multi-auto.svg" alt="Translation status" />
</a>

## Gallery

> Some of these screenshot are from older versions of Black Box.

<div align="center">
  <img src="https://i.imgur.com/O7Nblz8.png" alt="Black Box with 'Show Header bar' off"/><br/>
  <small><i>
    Black Box with "show header bar" off.
  </i></small>
  <br/><br/>
  <img src="https://i.imgur.com/CNwZhpJ.png" alt="Black Box with 'Show Header bar' off"/><br/>
  <small><i>
    Black Box with transparent background* and sixel support. *blur is controled
    by your compositor.
  </i></small>
  <br/><br/>
  <img src="https://github.com/hunter-gunter/blackbox-terminal/blob/main/img/split-screen.png?raw=true"><br/>
  <small><i>
    Split-Screen feature to manage up to 4 terminal at the same time !.
  </i></small>
  <br/><br/>
  <img src="https://github.com/hunter-gunter/blackbox-terminal/blob/main/img/ssh-manager.png?raw=true"><br/>
  <small><i>
    Now you can manage all your SSH connection at one place.
  </i></small>
  <br/><br/>
  <img src="https://github.com/hunter-gunter/blackbox-terminal/blob/main/img/ssh-manager-add.png?raw=true"><br/>
</div>

## Credits

- Most of Black Box's themes come (straight out copied) from [Tilix](https://github.com/gnunn1/tilix)
- Most non-Tilix-default themes come (straight out copied) from [Tilix-Themes](https://github.com/storm119/Tilix-Themes)
- Thank you, @linuxllama, for QA testing and creating Black Box's app icon
- Thank you, @predvodnik, for coming up with the name "Black Box"
- Source code that derives from other projects is properly attributed in the code itself
