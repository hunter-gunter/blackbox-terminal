/* TerminalTab.vala
 *
 * Copyright 2021-2024 Paulo Queiroz
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 */

public enum Terminal.SplitMode {
  SINGLE = 1,
  DOUBLE = 2,
  TRIPLE = 3,
  QUAD   = 4,
}

[GtkTemplate (ui = "/com/raggesilver/BlackBox/gtk/terminal-tab.ui")]
public class Terminal.TerminalTab : Gtk.Box {

  public signal void close_request ();

  [GtkChild] unowned Adw.Banner banner;
  [GtkChild] unowned Gtk.Box terminal_container;
  [GtkChild] unowned SearchToolbar search_toolbar;

  private class TerminalPane : Gtk.Box {
    public Terminal terminal            { get; private set; }
    public Gtk.ScrolledWindow scrolled  { get; private set; }

    public TerminalPane (Terminal terminal, bool show_scrollbars) {
      Object (orientation: Gtk.Orientation.VERTICAL, spacing: 0);

      this.terminal = terminal;
      this.hexpand = true;
      this.vexpand = true;

      this.scrolled = new Gtk.ScrolledWindow () {
        child = terminal,
        hexpand = true,
        vexpand = true
      };

      this.update_scrollbars (show_scrollbars);
    }

    public void update_scrollbars (bool show_scrollbars) {
      if (show_scrollbars) {
        if (this.scrolled.child != this.terminal) {
          this.scrolled.child = this.terminal;
        }

        if (this.scrolled.parent != this) {
          if (this.terminal.parent == this) {
            this.remove (this.terminal);
          }
          this.append (this.scrolled);
        }
      }
      else {
        if (this.scrolled.child == this.terminal) {
          this.scrolled.child = null;
        }

        if (this.scrolled.parent == this) {
          this.remove (this.scrolled);
        }

        if (this.terminal.parent != this) {
          this.append (this.terminal);
        }
      }
    }
  }

  private class TerminalBinding : Object {
    public ulong focus_handler;
    public ulong window_title_handler;
    public ulong spawn_failed_handler;
    public ulong exit_handler;
    public ulong commit_handler;
    public Gtk.EventControllerKey? key_controller;
    public Gtk.GestureClick? context_click;
  }

  private string default_title;
  private Gtk.Grid split_grid;

  private Gee.ArrayList<TerminalPane> panes = new Gee.ArrayList<TerminalPane> ();
  private Gee.HashMap<Terminal, TerminalBinding> bindings
    = new Gee.HashMap<Terminal, TerminalBinding> ();

  private TerminalPane primary_pane;
  private Terminal? active_terminal = null;

  public string?        title_override     { get; private set; default = null; }
  public SplitMode      split_mode         { get; private set; default = SplitMode.SINGLE; }
  public bool           broadcast_enabled  { get; private set; default = false; }
  private bool          is_forwarding_input = false;

  public Terminal terminal {
    get {
      if (this.active_terminal != null) {
        return this.active_terminal;
      }

      return this.primary_pane.terminal;
    }
  }

  public string title {
    owned get {
      string base_title;

      if (this.title_override != null) {
        return this.title_override;
      }

      if (this.terminal.window_title != "") {
        base_title = this.terminal.window_title;
      }
      else {
        base_title = this.default_title;
      }

      uint pane_count = this.get_required_pane_count (this.split_mode);
      if (pane_count > 1) {
        base_title = _("%s (%u panes)").printf (base_title, pane_count);
      }

      if (this.broadcast_enabled && pane_count > 1) {
        base_title = _("%s [sync]").printf (base_title);
      }

      return base_title;
    }
  }

  public bool can_broadcast {
    get {
      return this.panes.size > 1;
    }
  }

  static construct {
    typeof (SearchToolbar).class_ref ();
  }

  public TerminalTab (Window  window,
                      uint    tab_id,
                      string? command,
                      string? cwd) {
    Object (
      orientation: Gtk.Orientation.VERTICAL,
      spacing: 0
    );

    this.default_title = command ?? "%s %u".printf (_("tab"), tab_id);

    this.split_grid = new Gtk.Grid () {
      column_spacing = 6,
      row_spacing = 6,
      hexpand = true,
      vexpand = true
    };

    this.terminal_container.append (this.split_grid);

    var first_terminal = new Terminal (window, command, cwd);
    this.primary_pane = this.create_pane (first_terminal, true);
    this.panes.add (this.primary_pane);
    this.split_grid.attach (this.primary_pane, 0, 0, 1, 1);

    this.set_active_terminal (first_terminal);
    first_terminal.grab_focus ();

    this.connect_common_signals ();
  }

#if BLACKBOX_DEBUG_MEMORY
  ~TerminalTab () {
    message ("TerminalTab destroyed");
  }

  public override void dispose () {
    message ("TerminalTab dispose");
    base.dispose ();
  }
#endif

  private void connect_common_signals () {
    var settings = Settings.get_default ();

    settings.notify ["show-scrollbars"].connect (this.on_show_scrollbars_updated);
    this.on_show_scrollbars_updated ();

    this.notify ["title-override"].connect (() => {
      this.notify_property ("title");
    });
  }

  private void set_active_terminal (Terminal terminal) {
    if (this.active_terminal == terminal) {
      return;
    }

    this.active_terminal = terminal;
    this.notify_property ("terminal");
    this.notify_property ("title");
  }

  private TerminalPane create_pane (Terminal terminal, bool close_on_exit) {
    var pane = new TerminalPane (terminal, Settings.get_default ().show_scrollbars);
    this.setup_terminal (terminal, pane, close_on_exit);
    return pane;
  }

  private void setup_terminal (Terminal terminal,
                               TerminalPane pane,
                               bool close_on_exit) {
    var settings = Settings.get_default ();
    var binding = new TerminalBinding ();

    this.bindings.set (terminal, binding);

    binding.focus_handler = terminal.notify ["has-focus"].connect (() => {
      if (terminal.has_focus) {
        this.set_active_terminal (terminal);
      }
    });

    binding.window_title_handler = terminal.notify ["window-title"].connect (() => {
      this.notify_property ("title");
    });

    binding.spawn_failed_handler = terminal.spawn_failed.connect ((message) => {
      this.show_spawn_error (message);
    });

    if (close_on_exit) {
      binding.exit_handler = terminal.exit.connect (() => {
        this.close_request ();
      });
    }

    settings.bind_property (
      "use-sixel",
      terminal,
      "enable-sixel",
      BindingFlags.SYNC_CREATE
    );

    settings.schema.bind (
      "use-overlay-scrolling",
      pane.scrolled,
      "overlay-scrolling",
      SettingsBindFlags.GET
    );

    pane.update_scrollbars (settings.show_scrollbars);

    binding.commit_handler = terminal.commit.connect ((text) => {
      this.on_terminal_commit (terminal, text);
    });

    binding.key_controller = this.create_broadcast_controller (terminal);

    var click = new Gtk.GestureClick () {
      button = Gdk.BUTTON_SECONDARY,
    };
    click.pressed.connect ((gesture, n_pressed, x, y) => {
      this.show_menu (terminal, n_pressed, x, y);
    });
    terminal.add_controller (click);
    binding.context_click = click;
  }

  private void teardown_terminal (Terminal terminal) {
    var binding = this.bindings.get (terminal);
    if (binding == null) {
      return;
    }

    if (binding.focus_handler != 0) {
      terminal.disconnect (binding.focus_handler);
    }
    if (binding.window_title_handler != 0) {
      terminal.disconnect (binding.window_title_handler);
    }
    if (binding.spawn_failed_handler != 0) {
      terminal.disconnect (binding.spawn_failed_handler);
    }
    if (binding.exit_handler != 0) {
      terminal.disconnect (binding.exit_handler);
    }
    if (binding.commit_handler != 0) {
      terminal.disconnect (binding.commit_handler);
    }

    if (binding.key_controller != null) {
      terminal.remove_controller (binding.key_controller);
    }
    if (binding.context_click != null) {
      terminal.remove_controller (binding.context_click);
    }

    this.bindings.unset (terminal);
  }

  private Gtk.EventControllerKey create_broadcast_controller (Terminal terminal) {
    var controller = new Gtk.EventControllerKey () {
      propagation_phase = Gtk.PropagationPhase.CAPTURE
    };

    controller.key_pressed.connect ((keyval, keycode, state) => {
      return this.on_terminal_key_pressed (terminal, keyval, keycode, state);
    });

    terminal.add_controller (controller);
    return controller;
  }

  private void on_show_scrollbars_updated () {
    bool show_scrollbars = Settings.get_default ().show_scrollbars;

    foreach (var pane in this.panes) {
      pane.update_scrollbars (show_scrollbars);
    }
  }

  private void show_spawn_error (string? message) {
    this.override_title (_("Error"));
    this.banner.title = message ?? _("Failed to start terminal");
    this.banner.revealed = true;
  }

  private void show_menu (Terminal source,
                          int      n_pressed,
                          double   x,
                          double   y) {
    if (source.hyperlink_hover_uri != null) {
      source.window.link = source.hyperlink_hover_uri;
    } else {
      source.window.link = source.check_match_at (x, y, null);
    }

    var builder = new Gtk.Builder.from_resource ("/com/raggesilver/BlackBox/gtk/terminal-menu.ui");
    var pop = builder.get_object ("popover") as Gtk.PopoverMenu;

    double x_in_view, y_in_view;
    source.translate_coordinates (this, x, y, out x_in_view, out y_in_view);

    var r = Gdk.Rectangle () {
      x = (int) x_in_view,
      y = (int) y_in_view
    };

    pop.closed.connect_after (() => {
      pop.destroy ();
      source.grab_focus ();
    });

    pop.set_parent (this);
    pop.set_has_arrow (false);
    pop.set_halign (Gtk.Align.START);
    pop.set_pointing_to (r);
    pop.popup ();
  }

  public void search () {
    this.search_toolbar.open ();
  }

  public void override_title (string? _title) {
    this.title_override = _title;
    this.notify_property ("title");
  }

  public void change_split_mode (SplitMode mode) {
    if (this.split_mode == mode) {
      return;
    }

    int required = (int) this.get_required_pane_count (mode);
    this.ensure_pane_count (required);
    this.split_mode = mode;

    this.notify_property ("split-mode");

    if (required <= 1 && this.broadcast_enabled) {
      this.broadcast_enabled = false;
    }

    this.rebuild_split_layout ();
    this.notify_property ("title");
  }

  private void ensure_pane_count (int required) {
    while (this.panes.size < required) {
      string? cwd = Terminal
        .get_current_working_directory_for_new_session (this.terminal);

      var new_terminal = new Terminal (
        this.primary_pane.terminal.window,
        null,
        cwd
      );

      var pane = this.create_pane (new_terminal, false);
      this.panes.add (pane);
    }

    while (this.panes.size > required) {
      var pane = this.panes.remove_at (this.panes.size - 1);
      this.teardown_terminal (pane.terminal);
      this.split_grid.remove (pane);
      pane.destroy ();
    }

    this.on_show_scrollbars_updated ();
  }

  private void rebuild_split_layout () {
    foreach (var pane in this.panes) {
      if (pane.parent == this.split_grid) {
        this.split_grid.remove (pane);
      }
    }

    int required = (int) this.get_required_pane_count (this.split_mode);

    for (int i = 0; i < required; i++) {
      var pane = this.panes.get (i);
      var placement = this.get_pane_placement (this.split_mode, i);
      this.split_grid.attach (
        pane,
        placement.column,
        placement.row,
        placement.width,
        placement.height
      );
    }

    this.split_grid.column_homogeneous = required > 1;
    this.split_grid.row_homogeneous = this.split_mode == SplitMode.QUAD;
  }

  private struct PanePlacement {
    public int column;
    public int row;
    public int width;
    public int height;
  }

  private PanePlacement get_pane_placement (SplitMode mode, int index) {
    switch (mode) {
      case SplitMode.SINGLE:
        return PanePlacement () {
          column = 0,
          row = 0,
          width = 1,
          height = 1
        };
      case SplitMode.DOUBLE:
        return PanePlacement () {
          column = index,
          row = 0,
          width = 1,
          height = 1
        };
      case SplitMode.TRIPLE:
        switch (index) {
          case 0:
            return PanePlacement () {
              column = 0,
              row = 0,
              width = 1,
              height = 1
            };
          case 1:
            return PanePlacement () {
              column = 1,
              row = 0,
              width = 1,
              height = 1
            };
          default:
            return PanePlacement () {
              column = 0,
              row = 1,
              width = 2,
              height = 1
            };
        }
      case SplitMode.QUAD:
        return PanePlacement () {
          column = index % 2,
          row = index / 2,
          width = 1,
          height = 1
        };
      default:
        return PanePlacement () {
          column = 0,
          row = 0,
          width = 1,
          height = 1
        };
    }
  }

  public void change_broadcast_enabled (bool enabled) {
    bool can_enable = this.panes.size > 1;
    bool new_state = enabled && can_enable;

    if (this.broadcast_enabled == new_state) {
      return;
    }

    this.broadcast_enabled = new_state;
    this.notify_property ("title");
    this.notify_property ("broadcast-enabled");
  }

  private void on_terminal_commit (Terminal source, string text) {
    if (!this.broadcast_enabled || this.is_forwarding_input) {
      return;
    }

    this.is_forwarding_input = true;

    foreach (var pane in this.panes) {
      var target = pane.terminal;
      if (target == source) {
        continue;
      }
      target.feed_child (text.data);
    }

    this.is_forwarding_input = false;
  }

  private bool on_terminal_key_pressed (Terminal source,
                                        uint keyval,
                                        uint keycode,
                                        Gdk.ModifierType state) {
    if (!this.broadcast_enabled || this.is_forwarding_input) {
      return false;
    }

    string? sequence = this.translate_special_key (keyval, state);
    if (sequence == null) {
      return false;
    }

    this.is_forwarding_input = true;

    foreach (var pane in this.panes) {
      var target = pane.terminal;
      if (target == source) {
        continue;
      }
      target.feed_child (sequence.data);
    }

    this.is_forwarding_input = false;
    return false;
  }

  private string? translate_special_key (uint keyval, Gdk.ModifierType state) {
    switch (keyval) {
      case Gdk.Key.Return:
      case Gdk.Key.KP_Enter:
        return "\r";
      case Gdk.Key.Escape:
        return "\u001b";
      case Gdk.Key.BackSpace:
        return "\b";
      case Gdk.Key.Delete:
      case Gdk.Key.KP_Delete:
        return "\u007f";
      case Gdk.Key.Tab:
        if ((state & Gdk.ModifierType.SHIFT_MASK) != 0) {
          return "\u001b[Z";
        }
        return "\t";
      case Gdk.Key.Up:
      case Gdk.Key.KP_Up:
        return "\u001b[A";
      case Gdk.Key.Down:
      case Gdk.Key.KP_Down:
        return "\u001b[B";
      case Gdk.Key.Left:
      case Gdk.Key.KP_Left:
        return "\u001b[D";
      case Gdk.Key.Right:
      case Gdk.Key.KP_Right:
        return "\u001b[C";
      case Gdk.Key.Home:
        return "\u001b[H";
      case Gdk.Key.End:
        return "\u001b[F";
      case Gdk.Key.Page_Up:
        return "\u001b[5~";
      case Gdk.Key.Page_Down:
        return "\u001b[6~";
    }

    if ((state & Gdk.ModifierType.CONTROL_MASK) != 0) {
      switch (keyval) {
        case 'c': return "\u0003";
        case 'd': return "\u0004";
        case 'z': return "\u001a";
        case 'l': return "\u000c";
        case 'u': return "\u0015";
        case 'w': return "\u0017";
        case 'h': return "\u0008";
      }

      unichar ch = Gdk.keyval_to_unicode (keyval);
      if (ch != 0) {
        unichar control = (unichar) (ch & 0x1f);
        return ((char) control).to_string ();
      }
    }

    return null;
  }

  private uint get_required_pane_count (SplitMode mode) {
    switch (mode) {
      case SplitMode.SINGLE: return 1;
      case SplitMode.DOUBLE: return 2;
      case SplitMode.TRIPLE: return 3;
      case SplitMode.QUAD:   return 4;
    }

    return 1;
  }
}
