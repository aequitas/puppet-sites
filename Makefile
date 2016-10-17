Gemfile.lock: Gemfile
	bundle install --path vendor/bundle

fix:
	puppet-lint --fix manifests

check test: Gemfile.lock
	bundle exec rake validate

clean:
	rm -rf pkg Gemfile.lock vendor .bundle
