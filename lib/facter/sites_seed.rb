# (create and) return unique seed stored on the host
Facter.add('sites_seed') do

  seedfile_path = '/etc/puppet_sites_seed'

  unless File.exists?(seedfile_path)
    seedfile = File.new(seedfile_path, "w", 0400)
    seedfile.puts([*('A'..'Z')].sample(32).join)
    seedfile.close()
  end

  setcode do
    Facter::Core::Execution.exec('/bin/cat ' + seedfile_path)
  end
end
