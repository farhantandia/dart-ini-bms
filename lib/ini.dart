library ini;

import 'dart:async';

/// This library deals with reading and writing ini files. This implements the
/// standard as defined here:
///
/// https://en.wikipedia.org/wiki/INI_file
///
/// The ini file reader will return data organized by section and option. The
/// default section will be the blank string.

// Strings are split on newlines
final RegExp _newlinePattern = new RegExp(r"[\r\n]+");
// Blank lines are stripped.
final RegExp _blankLinePattern = new RegExp(r"^\s*$");
// Comment lines start with a semicolon or a hash. This permits leading whitespace.
final RegExp _commentPattern = new RegExp(r"^\s*[;#]");
// sections and entries can span lines if subsequent lines start with
// whitespace. See http://tools.ietf.org/html/rfc822.html#section-3.1
final RegExp _longHeaderFieldPattern = new RegExp(r"^\s+");
// sections are surrounded by square brakets. This does not trim section names.
final RegExp _sectionPattern = new RegExp(r"^\s*\[(.*\S.*)]\s*$");
// entries are made up of a key and a value. The key must have at least one non
// blank character. The value can be completely blank. This does not trim key
// or value.
final RegExp _entryPattern = new RegExp(r"^([^=]+)=(.*?)$");

class _Parser {
  /// The stream of unparsed data
  List<String> _strings;

  /// The parsed config object
  Config _config;

  static Iterable<String> _removeBlankLines(Iterable<String> source) => source.where((String line) => ! _blankLinePattern.hasMatch(line));

  static Iterable<String> _removeComments(Iterable<String> source) => source.where((String line) => ! _commentPattern.hasMatch(line));

  /// Turns the lines that have been continued over multiple lines into single lines.
  static List<String> _joinLongHeaderFields(Iterable<String> source) {
    List<String> result = new List<String>();
    String line = '';

    for (String current in source) {
      if ( _longHeaderFieldPattern.hasMatch(current) ) {
        // The leading whitespace makes this a long header field.
        // It is not part of the value.
        line += current.replaceFirst(_longHeaderFieldPattern, "");
      }
      else {
        if ( line != '' ) {
          result.add(line);
        }
        line = current;
      }
    }
    if ( line != '' ) {
      result.add(line);
    }

    return result;
  }

  _Parser.fromString(String string) : this.fromStrings(string.split(_newlinePattern));

  _Parser.fromStrings(List<String> strings) :
    _strings = _joinLongHeaderFields(_removeComments(_removeBlankLines(strings)));

  /// Returns the parsed Config.
  /// The first call will trigger the parse.
  get config {
    if ( _config == null ) {
      _config = _parse();
    }
    return _config;
  }

  /// Creates a Config from the cleaned list of strings.
  Config _parse() {
    Config result = new Config();
    String section = 'default';

    for (String current in _strings) {
      Match is_section = _sectionPattern.firstMatch(current);
      if ( is_section != null ) {
        section = is_section[1].trim();
        result.addSection(section);
      }
      else {
        Match is_entry = _entryPattern.firstMatch(current);
        if ( is_entry != null ) {
          result.set(section, is_entry[1].trim(), is_entry[2].trim());
        }
        else {
          throw new Exception('Unrecognized line: "${current}"');
        }
      }
    }

    return result;
  }
}

class Config {
  /// The defaults consist of all entries that are not within a section.
  Map<String, String> _defaults = new Map<String, String>();

  /// The sections contains all entries organized by section.
  Map<String, Map<String, String>> _sections = new Map<String, Map<String, String>>();

  Config();

  factory Config.fromString(String string) {
    return new _Parser.fromString(string).config;
  }

  factory Config.fromStrings(List<String> strings) {
    return new _Parser.fromStrings(strings).config;
  }

  /// Convert the Config to a parseable string version.
  String toString() {
    StringBuffer buffer = new StringBuffer();

    buffer.writeAll(items('default').map((e) => "${e[0]} = ${e[1]}"), "\n");
    buffer.write("\n");
    for (String section in sections()) {
      buffer.write("[${section}]\n");
      buffer.writeAll(items(section).map((e) => "${e[0]} = ${e[1]}"), "\n");
      buffer.write("\n");
    }

    return buffer.toString();
  }

  /// Return a dictionary containing the instance-wide defaults.
  Map<String, String> defaults() => _defaults;

  /// Return a list of the sections available; DEFAULT is not included in the list.
  Iterable<String> sections() => _sections.keys;

  /// Add a section with the [name] provided to the config.
  /// If a section by the given [name] already exists then a DuplicateSectionError is raised.
  /// If the [name] is DEFAULT (case insensitive) then a ValueError is raised.
  void addSection(String name) {
    if ( name.toLowerCase() == 'default' ) {
      throw new Exception('ValueError');
    }
    if ( _sections.containsKey(name) ) {
      throw new Exception('DuplicateSectionError');
    }
    _sections[name] = new Map<String, String>();
  }

  /// Indicates whether the [name] is an existing section.
  /// The DEFAULT section is not acknowledged.
  bool hasSection(String name) => _sections.containsKey(name);

  /// Returns a list of options available in the section with the [name] provided.
  Iterable<String> options(String name) {
    Map<String,String> s = this._getSection(name);
    return s != null ? s.keys : null;
  }

  /// If the section with the [name] exists, and contains the given [option], return True;
  /// otherwise return False
  bool hasOption(String name, String option) {
    Map<String,String> s = this._getSection(name);
    return s != null ? s.containsKey(option) : false;
  }

  /// Get the [option] value for the section with the [name].
  String get(String name, option) {
    Map<String,String> s = this._getSection(name);
    return s != null ? s[option] : null;
  }

  /// Return a list of (name, value) pairs for each option in the section with the [name].
  List<List<String>> items(String name) {
    Map<String,String> s = this._getSection(name);
    return s != null ? s.keys.map((String key) => [key, s[key]]).toList() : null;
  }

  /// If the section with the [name] exists, set the given [option] to the specified [value];
  /// otherwise raise NoSectionError.
  void set(String name, String option, String value) {
    Map<String,String> s = this._getSection(name);
    if ( s == null ) {
      throw new Exception('NoSectionError');
    }
    s[option] = value;
  }

  /// Remove the [option] from the section with the [name].
  /// If the section does not exist, raise NoSectionError.
  /// If the option existed and was removed, return True;
  /// otherwise return False
  bool removeOption(String section, String option) {
    Map<String,String> s = this._getSection(section);
    if ( s != null ) {
      if ( s.containsKey(option) ) {
        s.remove(option);
        return true;
      }
      return false;
    }
    throw new Exception('NoSectionError');
  }

  /// Remove the specified section from the configuration.
  /// If the section in fact existed, return True. Otherwise return False
  bool removeSection(String section) {
    if ( section.toLowerCase() == 'default' ) {
      // Can't add the default section, so removing is just clearing.
      _defaults.clear();
    }
    if ( _sections.containsKey(section) ) {
      _sections.remove(section);
      return true;
    }
    return false;
  }

  /// Returns the section or null if the section does not exist.
  /// The string 'default' (case insensitive) will return the default section.
  Map<String, String> _getSection(String section) {
    if ( section.toLowerCase() == 'default' ) {
      return _defaults;
    }
    if ( _sections.containsKey(section) ) {
      return _sections[section];
    }
    return null;
  }
}

// vim: set ai et sw=2 syntax=dart :
