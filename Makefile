test: Gemfile.lock
	bundle exec rake validate

Gemfile.lock: Gemfile
	bundle install --path vendor/bundle
