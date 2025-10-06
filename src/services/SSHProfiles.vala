/* SSHProfiles.vala
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

public class Terminal.SSHProfile : Object {
  public string id        { get; construct set; }
  public string name      { get; set; default = ""; }
  public string host      { get; set; default = ""; }
  public string username  { get; set; default = ""; }
  public string password  { get; set; default = ""; }
  public uint   port      { get; set; default = 22; }

  public SSHProfile (string id,
                     string name = "",
                     string host = "",
                     string username = "",
                     string password = "",
                     uint port = 22) {
    Object (
      id: id,
      name: name,
      host: host,
      username: username,
      password: password,
      port: port == 0 ? 22 : port
    );
  }

  public static SSHProfile create_new () {
    return new SSHProfile (GLib.Uuid.string_random ());
  }

  public string connection_label {
    owned get {
      var trimmed_name = this.name.strip ();
      if (trimmed_name != "") {
        return trimmed_name;
      }

      var trimmed_host = this.host.strip ();
      var trimmed_user = this.username.strip ();

      if (trimmed_user != "") {
        return "%s@%s".printf (trimmed_user, trimmed_host);
      }

      return trimmed_host;
    }
  }

  public SSHProfile copy () {
    return new SSHProfile (
      this.id,
      this.name,
      this.host,
      this.username,
      this.password,
      this.port
    );
  }

  public string target {
    owned get {
      var trimmed_host = this.host.strip ();
      var trimmed_user = this.username.strip ();

      if (trimmed_user != "") {
        return "%s@%s".printf (trimmed_user, trimmed_host);
      }

      return trimmed_host;
    }
  }

  public bool has_password {
    get {
      return this.password.strip () != "";
    }
  }

  public string build_command (bool include_password = true) {
    string target = GLib.Shell.quote (this.target);
    string port_part = this.port != 22 ? "-p %u ".printf (this.port) : "";
    string command = "ssh %s%s".printf (port_part, target);

    if (include_password && this.has_password) {
      string quoted_password = GLib.Shell.quote (this.password);
      command = "sshpass -p %s %s".printf (quoted_password, command);
    }

    return command;
  }
}

public class Terminal.SSHProfileStore : Object {
  public signal void profiles_changed ();

  private const string VARIANT_TYPE = "a(sssssu)";

  private static SSHProfileStore? instance = null;

  private Gee.ArrayList<SSHProfile> profiles = new Gee.ArrayList<SSHProfile> ();
  private Settings settings;
  private bool ignore_next_reload = false;

  private SSHProfileStore () {
    this.settings = Settings.get_default ();
    this.reload_from_settings ();

    this.settings.notify ["ssh-profiles"].connect (() => {
      this.reload_from_settings ();
    });
  }

  public static SSHProfileStore get_default () {
    if (SSHProfileStore.instance == null) {
      SSHProfileStore.instance = new SSHProfileStore ();
    }

    return SSHProfileStore.instance;
  }

  public Gee.Iterable<SSHProfile> get_profiles () {
    return this.profiles.read_only_view;
  }

  public SSHProfile? get_profile (string id) {
    foreach (var profile in this.profiles) {
      if (profile.id == id) {
        return profile;
      }
    }

    return null;
  }

  public SSHProfile create_profile () {
    return SSHProfile.create_new ();
  }

  public void upsert_profile (SSHProfile profile) {
    int index = this.index_of (profile.id);

    if (index >= 0) {
      this.profiles.set (index, profile);
    }
    else {
      this.profiles.add (profile);
    }

    this.persist ();
    this.profiles_changed ();
  }

  public void remove_profile (string id) {
    int index = this.index_of (id);

    if (index < 0) {
      return;
    }

    this.profiles.remove_at (index);
    this.persist ();
    this.profiles_changed ();
  }

  private int index_of (string id) {
    for (int i = 0; i < this.profiles.size; i++) {
      if (this.profiles.get (i).id == id) {
        return i;
      }
    }

    return -1;
  }

  private void reload_from_settings () {
    if (this.ignore_next_reload) {
      this.ignore_next_reload = false;
      return;
    }

    this.profiles.clear ();

    try {
      var current = this.settings.ssh_profiles;
      var iter = current.iterator ();

      string id;
      string name;
      string host;
      string username;
      string password;
      uint port;

      while (iter.next ("(sssssu)",
                        out id,
                        out name,
                        out host,
                        out username,
                        out password,
                        out port)) {
        var profile = new SSHProfile (id) {
          name = name,
          host = host,
          username = username,
          password = password,
          port = port == 0 ? 22 : port
        };

        this.profiles.add (profile);
      }
    }
    catch (Error e) {
      warning ("Failed to load SSH profiles: %s", e.message);
    }

    this.profiles_changed ();
  }

  private void persist () {
    var builder = new GLib.VariantBuilder (new GLib.VariantType (VARIANT_TYPE));

    foreach (var profile in this.profiles) {
      builder.add (
        "(sssssu)",
        profile.id,
        profile.name,
        profile.host,
        profile.username,
        profile.password,
        profile.port
      );
    }

    this.ignore_next_reload = true;
    this.settings.ssh_profiles = builder.end ();
  }
}
