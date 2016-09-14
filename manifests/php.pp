# manage global php settings
class sites::php {
  # php related
  php::module { [ 'gd', 'mysql']: }
}
