/* SSHManagerWindow.vala
 *
 * Copyright 2024 BlackBox Contributors
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

public class Terminal.SSHProfileRow : Adw.ActionRow {
  public SSHProfile profile { get; private set; }

  public SSHProfileRow (SSHProfile profile) {
    Object (activatable: true);

    this.profile = profile;
    this.update_display ();
  }

  public void update_profile (SSHProfile profile) {
    this.profile = profile;
    this.update_display ();
  }

  private void update_display () {
    this.title = this.profile.connection_label;

    string host = this.profile.host.strip ();
    if (host == "") {
      host = _("Unnamed host");
    }

    if (this.profile.port != 22) {
      host = "%s:%u".printf (host, this.profile.port);
    }

    var username = this.profile.username.strip ();

    if (username != "") {
      host = "%s@%s".printf (username, host);
    }

    if (this.profile.password.strip () != "") {
      host = _("%s (password stored)").printf (host);
    }

    this.subtitle = host;
  }
}

public class Terminal.SSHManagerWindow : Adw.Window {
  private const int DEFAULT_WIDTH = 460;
  private const int DEFAULT_HEIGHT = 420;

  private SSHProfileStore store;
  private weak Window parent_window;

  private Gtk.ListBox list_box;
  private Gtk.Label empty_label;
  private Gtk.ScrolledWindow scrolled;
  private Gtk.Button add_button;
  private Gtk.Button edit_button;
  private Gtk.Button remove_button;
  private Gtk.Button connect_button;

  private ulong store_handler_id = 0;
  private string? pending_selection_id = null;

  private Gtk.Widget create_form_label (string text) {
    return new Gtk.Label (text) {
      halign = Gtk.Align.START
    };
  }

  public SSHManagerWindow (Window parent) {
    Object (
      application: parent.application,
      transient_for: parent,
      modal: true,
      destroy_with_parent: true,
      default_width: DEFAULT_WIDTH,
      default_height: DEFAULT_HEIGHT
    );

    this.parent_window = parent;
    this.store = SSHProfileStore.get_default ();

    this.build_ui ();
    this.connect_signals ();

    this.populate ();

    this.store_handler_id =
      this.store.profiles_changed.connect (this.on_profiles_changed);

    this.close_request.connect (() => {
      if (this.store_handler_id != 0) {
        this.store.disconnect (this.store_handler_id);
        this.store_handler_id = 0;
      }
      return false;
    });
  }

  public void show_new_profile_dialog () {
    this.open_editor (null);
  }

  public void show_edit_profile_dialog (SSHProfile profile) {
    this.open_editor (profile);
  }

  private void build_ui () {
    var toolbar_view = new Adw.ToolbarView ();

    var window_title = new Adw.WindowTitle (_("SSH Connections"), "");
    var header_bar = new Adw.HeaderBar () {
      title_widget = window_title
    };

    this.add_button = new Gtk.Button.with_label (_("Add"));
    header_bar.pack_end (this.add_button);

    toolbar_view.add_top_bar (header_bar);

    var content_box = new Gtk.Box (Gtk.Orientation.VERTICAL, 12) {
      margin_start = 12,
      margin_end = 12,
      margin_top = 12,
      margin_bottom = 12
    };

    this.empty_label = new Gtk.Label (_("No saved SSH connections yet")) {
      hexpand = true,
      halign = Gtk.Align.CENTER,
      margin_top = 24,
      margin_bottom = 24
    };

    this.list_box = new Gtk.ListBox () {
      selection_mode = Gtk.SelectionMode.BROWSE,
      vexpand = true
    };
    this.list_box.add_css_class ("boxed-list");

    this.scrolled = new Gtk.ScrolledWindow () {
      child = this.list_box,
      hexpand = true,
      vexpand = true
    };

    content_box.append (this.scrolled);
    content_box.append (this.empty_label);

    var action_box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 6) {
      halign = Gtk.Align.END
    };

    this.connect_button = new Gtk.Button.with_label (_("Connect")) {
      sensitive = false
    };
    this.edit_button = new Gtk.Button.with_label (_("Edit")) {
      sensitive = false
    };
    this.remove_button = new Gtk.Button.with_label (_("Remove")) {
      sensitive = false
    };

    action_box.append (this.connect_button);
    action_box.append (this.edit_button);
    action_box.append (this.remove_button);

    content_box.append (action_box);

    toolbar_view.content = content_box;
    this.content = toolbar_view;
  }

  private void connect_signals () {
    this.add_button.clicked.connect (() => {
      this.open_editor (null);
    });

    this.edit_button.clicked.connect (() => {
      var profile = this.get_selected_profile ();
      if (profile != null) {
        this.open_editor (profile);
      }
    });

    this.remove_button.clicked.connect (this.remove_selected_profile);
    this.connect_button.clicked.connect (this.connect_selected_profile);

    this.list_box.row_selected.connect ((row) => {
      this.on_selection_changed (row as SSHProfileRow);
    });

    this.list_box.row_activated.connect ((row) => {
      this.connect_selected_profile ();
    });
  }

  private SSHProfile? get_selected_profile () {
    return (this.list_box.get_selected_row () as SSHProfileRow)?.profile;
  }

  private void on_selection_changed (SSHProfileRow? row) {
    bool has_selection = row != null;

    this.connect_button.sensitive = has_selection;
    this.edit_button.sensitive = has_selection;
    this.remove_button.sensitive = has_selection;
  }

  private void on_profiles_changed () {
    this.populate ();
  }

  private void populate () {
    Gtk.Widget? child = this.list_box.get_first_child ();
    while (child != null) {
      var next = child.get_next_sibling ();
      this.list_box.remove (child);
      child = next;
    }

    bool has_profiles = false;

    foreach (var profile in this.store.get_profiles ()) {
      has_profiles = true;
      var row = new SSHProfileRow (profile);
      this.list_box.append (row);

      if (this.pending_selection_id != null &&
          profile.id == this.pending_selection_id) {
        this.list_box.select_row (row);
      }
    }

    if (!has_profiles) {
      this.list_box.unselect_all ();
      this.on_selection_changed (null);
    }

    this.scrolled.visible = has_profiles;
    this.empty_label.visible = !has_profiles;
    this.pending_selection_id = null;
  }

  private void open_editor (SSHProfile? profile) {
    bool is_new = profile == null;
    var working_copy = profile != null ? profile.copy () : this.store.create_profile ();

    var dialog = new Adw.MessageDialog (
      this,
      is_new ? _("New SSH Connection") : _("Edit SSH Connection"),
      null
    );

    dialog.add_response ("cancel", _("Cancel"));
    dialog.add_response ("save", _("Save"));
    dialog.set_default_response ("save");
    dialog.set_close_response ("cancel");

    var grid = new Gtk.Grid () {
      column_spacing = 12,
      row_spacing = 12,
      margin_top = 12,
      margin_bottom = 12,
      margin_start = 12,
      margin_end = 12
    };

    int row = 0;

    var name_entry = new Gtk.Entry () {
      text = working_copy.name,
      hexpand = true,
      placeholder_text = _("Friendly name (optional)")
    };

    grid.attach (this.create_form_label (_("Name")), 0, row, 1, 1);
    grid.attach (name_entry, 1, row++, 1, 1);

    var host_entry = new Gtk.Entry () {
      text = working_copy.host,
      hexpand = true,
      placeholder_text = _("Hostname or IP address")
    };
    grid.attach (this.create_form_label (_("Host")), 0, row, 1, 1);
    grid.attach (host_entry, 1, row++, 1, 1);

    var user_entry = new Gtk.Entry () {
      text = working_copy.username,
      hexpand = true,
      placeholder_text = _("Username (optional)")
    };
    grid.attach (this.create_form_label (_("Username")), 0, row, 1, 1);
    grid.attach (user_entry, 1, row++, 1, 1);

    var password_entry = new Gtk.PasswordEntry () {
      text = working_copy.password,
      hexpand = true
    };
    password_entry.show_peek_icon = true;
    grid.attach (this.create_form_label (_("Password")), 0, row, 1, 1);
    grid.attach (password_entry, 1, row++, 1, 1);

    var port_adjustment = new Gtk.Adjustment (
      working_copy.port > 0 ? working_copy.port : 22,
      1,
      65535,
      1,
      10,
      0
    );
    var port_spin = new Gtk.SpinButton (port_adjustment, 1, 0) {
      hexpand = false
    };

    grid.attach (this.create_form_label (_("Port")), 0, row, 1, 1);
    grid.attach (port_spin, 1, row++, 1, 1);

    var password_hint = new Gtk.Label (_("Leave blank to use SSH keys")) {
      halign = Gtk.Align.START,
      wrap = true
    };
    password_hint.add_css_class ("dim-label");
    grid.attach (password_hint, 1, row++, 1, 1);

    dialog.extra_child = grid;

    host_entry.changed.connect (() => {
      dialog.set_response_enabled ("save", host_entry.text.strip () != "");
    });
    dialog.set_response_enabled ("save", host_entry.text.strip () != "");

    dialog.response.connect ((response) => {
      if (response == "save") {
        working_copy.name = name_entry.text.strip ();
        working_copy.host = host_entry.text.strip ();
        working_copy.username = user_entry.text.strip ();
        working_copy.password = password_entry.text;
        working_copy.port = (uint) port_spin.value;

        this.pending_selection_id = working_copy.id;
        this.store.upsert_profile (working_copy);
      }

      dialog.destroy ();
    });

    host_entry.activate.connect (() => {
      if (dialog.get_response_enabled ("save")) {
        dialog.response.emit ("save");
      }
    });

    dialog.present ();
  }

  private void remove_selected_profile () {
    var profile = this.get_selected_profile ();
    if (profile == null) {
      return;
    }

    this.store.remove_profile (profile.id);
  }

  private void connect_selected_profile () {
    var profile = this.get_selected_profile ();
    if (profile == null) {
      return;
    }

    this.parent_window?.connect_to_ssh_profile (profile.id);
    this.close ();
  }
}
