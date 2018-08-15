.DELETE_ON_ERROR:

vendor/bundle: Gemfile.lock
	bundle install --path vendor/bundle
	@touch $@

fix:
	bundle exec puppet-lint --fix manifests

check test: vendor/bundle
	bundle exec rake validate

clean:
	rm -rf pkg vendor 
