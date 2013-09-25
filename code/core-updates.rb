#!/usr/bin/env ruby

# Script to check the status of plugins, update them and publish the changelog

#--- Variables ---#
site_name	= "domainname.com"

class CoreStatus
	#--- Functions ---#
	def CoreStatus.create_hash ( log_file )
		# on line #1 the number of plugins is displayed
		first_line = 1
		line_count = first_line
		plugins_count = 0
		hash = Hash.new

		File.open( log_file, "r" ) do | file_handle |
			file_handle.each_line do | line |
				# convert the line into a string
				line_string = String.try_convert( line )

				if line_count == first_line # true for only once :)
					# on line #1, the number of plugins is displayed at the first WORD
					plugins_count = line_string.split[0].to_i;
					# puts "plugins count: #{plugins_count}"

				# let's count ((plugins_count+1)).times
				# first line only contains the info about number of plugins
				# we don't need other lines following the required data
				elsif line_count <= plugins_count + first_line
					# second line onwards, the plugins are displayed in the following format
					# State_of_Plugin(Active/Inactive/Mustuse)	Plugin_Name	Plugin_Version
					if line_string.split[0] == 'A' # we don't need to check / update, must-use plugins that are denoted by 'M'
						plugin_name = line_string.split[1];
						plugin_version = line_string.split[2];
						hash[plugin_name] = plugin_version;
					end
				end

				# if we don't do this, then we'd have an infinite loop
				line_count += 1;
			end
		end

		return hash
	end

	# def create_log( path, log_file ) system( "wp --path='#{path}' plugin status > #{log_file}" ) end

	def initialize( site_url )
		@site_name = site_url


		# @site_name  = ''
		@site_path	= "/home/pothi/sites/#{@site_name}/wordpress/"

		@data_dir    = '/home/pothi/sites/dostatus.tinywp.com/log/'
		@wp_cli_log  = "#{@data_dir}/wp-cli.log"
		@prev_log    = "#{@data_dir}wp-cli-prev-#{@site_name}.log"
		@current_log = "#{@data_dir}wp-cli-current-#{@site_name}.log"
		@updated_log = "#{@data_dir}wp-cli-updated-#{@site_name}.log"

		@jekyll_blog_url  = 'dostatus.tinywp.com'
		@jekyll_post_path = '/home/pothi/sites/dostatus.tinywp.com/sources/_posts/'

		#--- Internal variables ---#
		@prev_plugins_list    = Hash.new
		@current_plugins_list = Hash.new
		@updated_plugins_list = Hash.new
		@diff_auto_updated_plugins_list	= Array.new
		@diff_manually_updated_plugins_list	= Array.new

		#--- Actions ---#
		require 'fileutils'
		# system( "date '+%F %H:%M:%S' >> #{@wp_cli_log}" )

		#-- prepare to record / display the results --#
		date = Time.now.strftime( "%Y-%m-%d" );
		time = Time.now.strftime( "%H:%M:%S" );

		@blog_format = "---\n"
		@blog_format += "published: true\n"
		@blog_format += "title: Plugins changes\n"
		@blog_format += "date: #{date} #{time}\n"
		@blog_format += "layout: post\n"
		@blog_format += "category: plugins\n"
		@blog_format += "---\n"

		@blog_content = "#Since last check...#\n"
		@blog_content += "##In [#{@site_name}](http://#{@site_name})...##\n"

		open( @wp_cli_log, 'a' ) { |fh|
			fh << "#{date} #{time} - #{@site_name}\n" 
		}

		#-- This routine is executed only once, when no previous data is found --#
		if !File.exists?( @prev_log )

			#- create the current log -#
			# create_log( @site_path, @current_log )
			system( "/home/pothi/.wp-cli/bin/wp --path='#{@site_path}' plugin status > #{@current_log}" )

			# create the hash for current log
			@current_plugins_list = self.class.create_hash( @current_log )
			# @current_plugins_list.each { |key, value| puts "#{key} is at version #{value}." } # debug
			
			#- update plugins -#
			system( "/home/pothi/.wp-cli/bin/wp --path='#{@site_path}' plugin update-all >> #{@wp_cli_log}" )
			#- create the updated log -#
			# create_log( @site_path, @updated_log )
		system( "/home/pothi/.wp-cli/bin/wp --path='#{@site_path}' plugin status > #{@updated_log}" )
		#- create the hash for updated log -#
		@updated_plugins_list = self.class.create_hash( @updated_log )

		#- create a hash of updated plugins -#
		@current_plugins_list.each { |name, version|
			@diff_auto_updated_plugins_list.push(name) if @current_plugins_list[name] != @updated_plugins_list[name]
		}

		#- create diff between plugins' lists -#
		if !@diff_auto_updated_plugins_list.empty?
			@diff_auto_updated_plugins_list.each { |plugin_name|
				@blog_content += "#{plugin_name} has been updated from #{@current_plugins_list[plugin_name]} to #{@updated_plugins_list[plugin_name]}."
			}
		else
			# no updates to display; so exit
			FileUtils.cp @updated_log, @prev_log
			exit
		end
		
		# display the result
		@blog_file_path = "/home/pothi/sites/dostatus.tinywp.com/source/_posts/"
		@blog_file_name = "#{date}-plugin-updates.md"
		File.open( @blog_file_path + @blog_file_name, "w" ) { |file_handle|
			file_handle.write( @blog_format + @blog_content )
		}

		# move update log to prev log
		FileUtils.cp @updated_log, @prev_log
		exit
	end

	#-- This is executed only when previous data is found --#
	#--- Compare previous log and current log ---#
	#- create hash for prev log -#
	@prev_plugins_list = self.class.create_hash( @prev_log )

	#- create current log -#
	# create_log( @site_path, @current_log )
	system( "/home/pothi/.wp-cli/bin/wp --path='#{@site_path}' plugin status > #{@current_log}" )

	#- create the hash for the current log -#
	@current_plugins_list = self.class.create_hash( @current_log )

	#- compare prev hash and current hash -#
	@any_manual_plugin_update = false # assume, no manual update/insert/removal occurred
	@current_plugins_list.each { |name, version|
		if @current_plugins_list[name] != @prev_plugins_list[name]
			@any_manual_plugin_update = true
			if @prev_plugins_list[name] == nil
				# on production environment
				@blog_content += "+    #{name} (at version #{version}) has been activated."
				# on dev environment, check wp-cli.log
				# puts "#{name} (at version #{version}) has been activated."
			else
				# on production environment
				@blog_content += "+    #{name} has been updated __manually__ from #{@prev_plugins_list[name]} to #{version}."
				# on dev environment, check wp-cli.log
				# puts "#{name} has been updated __manually__ from #{@prev_plugins_list[name]} to #{version}."
			end
		end
	}

	@prev_plugins_list.each { |name, version|
		if @prev_plugins_list[name] != @current_plugins_list[name]
			if @current_plugins_list[name] == nil
				@blog_content += "+    #{name} (at version #{version}) has been deactivated __manually__."
				@any_manual_plugin_update = true
			end
		end
	}

	#--- update plugins and log results in site's root ---#
		system( "/home/pothi/.wp-cli/bin/wp --path='#{@site_path}' plugin update-all >> #{@wp_cli_log}" )
		#- create the update status log -#
		# create_log( @site_path, @updated_log )
		system( "/home/pothi/.wp-cli/bin/wp --path='#{@site_path}' plugin status > #{@updated_log}" )

	#- check if any plugins are updated and if any plugins were manually updated -#
		# create a hash of updated plugins
		@updated_plugins_list = self.class.create_hash( @updated_log )

		#- compare the hash with the current plugins hash -#
		@current_plugins_list.each { |name, version|
			@diff_auto_updated_plugins_list.push(name) if @current_plugins_list[name] != @updated_plugins_list[name]
		}

		if !@diff_auto_updated_plugins_list.empty?
			@diff_auto_updated_plugins_list.each { |plugin_name|
				@blog_content += "+    #{plugin_name} has been _automatically_ updated from #{@current_plugins_list[plugin_name]} to #{@updated_plugins_list[plugin_name]}."
			}
			@any_auto_plugin_update = true
		else
			@any_auto_plugin_update = false
		end
		
	#- mv upload log to prev log -#
		FileUtils.cp @updated_log, @prev_log

		#- display results, if found -#
		if (@any_manual_plugin_update == false) and (@any_auto_plugin_update == false)
			# nothing to display, then exit
			exit
		else
			# publish the blog post
			@blog_file_path = "/home/pothi/sites/dostatus.tinywp.com/source/_posts/"
			@blog_file_name = "#{date}-plugin-updates.md"
			File.open( @blog_file_path + @blog_file_name, "w" ) { |file_handle|
				file_handle.write( @blog_format + @blog_content )
				# file_handle.write( @blog_content )
			}
		end
	end
end

# PluginStatus.new( site_name )
#- Variables -#
get_wp_version_script = '/home/pothi/miscsites/dostatus.tinywp.com/code/get_wp_version.php'
wp_version_log        = '/home/pothi/miscsites/dostatus.tinywp.com/log/wp-version.log'

#- get WP version -#
system(" /usr/bin/php #{get_wp_version_script} > #{wp_version_log} ")

lines_count = 1
next_wp_version = ''
File.readlines( wp_version_log ).each do |line|
	# puts line
	next_wp_version = line
	if /\d\.\d\.[1-9]/.match( next_wp_version )
		# prev_version = %x( echo pothi )
		prev_wp_version = %x( /home/pothi/.wp-cli/vendor/wp-cli/wp-cli/bin/wp --path=/home/pothi/sites/wpsc.tinywp.com/wordpress/ core version ).sub( /\n/, '' )
		# p prev_version
		if ( /^\d\.\d$/.match(prev_wp_version) ) and ( prev_wp_version =~ next_wp_version )
			p 'Ready to upgrade'
		end
	end
	exit if lines_count > 1
	lines_count += 1
end
