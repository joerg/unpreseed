#!/usr/bin/env ruby
require 'tmpdir'

help_text = <<EOF
Usage: #{File.basename(__FILE__)} [--help|-h] [--debug|-d] [--purge|-p] [--remove|-r] package1 package2 ...
This removes any previous preseeded values which is nice for testing preseeding in chef/sandwich, puppet and similar.
This Method is in no way supported by Debian. Do not use this on a production system!
Options:
debug: Does not alter config files but prints a message on how to do it manually.
purge: Purges packages before removing preseeded values.

Find Package names via 'debconf-get-selections'.
EOF

debug = purge = remove = false

packages = Array.new()
ARGV.each do |a|
  case a
  when /--help|-h/ then
    puts help_text
  when /--purge|-p/ then
    purge = true
  when /--remove|-r/ then
    remove = true
  when /--debug|-d/ then
    debug = true
  when /^-(.*)/
    raise "Option #{a} not supported"
  else 
    packages.push(a)
  end
end

debconf_dir = "/var/cache/debconf"
temp_dir = Dir.mktmpdir

Dir.chdir(debconf_dir)
debconf_files = Dir.glob("*")

search = Regexp.new("^Name: (#{packages.join('|')})")

`apt-get -y purge #{packages.join(' ')}` if purge
`apt-get -y remove #{packages.join(' ')}` if remove and !purge

remove_block = false
debconf_files.each do |f|
  deb_file = File.open("#{debconf_dir}/#{f}", "r")
  tmp_file = File.open("#{temp_dir}/#{f}", "w")
  deb_file.each_line do |l|
    next if ( remove_block and !(l =~ /Name:/))
    remove_block = false
    if l =~ search
      remove_block = true
    else
      tmp_file << l
    end
  end
  tmp_file.close
  deb_file.close
end

if debug == false
  Dir.chdir temp_dir
  FileUtils.cp debconf_files, debconf_dir
  FileUtils.rm_r temp_dir, :force => true
else
  puts "Debug selected, you may copy from #{temp_dir} to #{debconf_dir} manually."
end
