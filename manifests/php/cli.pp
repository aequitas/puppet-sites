# install php cli
class sites::php::cli {
  # include module global php config
  include ::sites::php

  ensure_packages(['php5-cli'], {'ensure' => 'present'})
}
