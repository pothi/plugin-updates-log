#!/usr/bin/env ruby

# script to commit changes to plugin installations, deletions, activations, and deactivations

require 'open3'
require 'git'
require 'logger'

#--- Variables ---#
sites   = %w[ domainname.tld anotherdomain.net ]

class PluginStatus
    #--- Functions ---#
    def self.create_hash ( log_file )
        # on line #1 the number of plugins is displayed
        first_line = 1
        line_count = first_line
        plugins_count = 0
        hash = Hash.new

        File.readlines( log_file ).each do | line |
            # convert the line into a string
            line_string = line.to_s

            if line_count == first_line # true for only once :)
                # on line #1, the number of plugins is displayed at the first WORD
                plugins_count = line_string.split[0].to_i;

            # let's count ((plugins_count+1)).times
            # first line only contains the info about number of plugins
            # we don't need other lines following the required data
            elsif line_count <= plugins_count + first_line
                # second line onwards, the plugins are displayed in the following format
                # State_of_Plugin(Active/Inactive/Mustuse)  Plugin_Name Plugin_Version
                if line_string.split[0] =~ /[ANI]/ # we don't need to check / update, must-use plugins that are denoted by 'M'
                    plugin_name = line_string.split[1];
                    plugin_version = line_string.split[2];
                    hash[plugin_name] = plugin_version;
                end
            end

            # if we don't do this, then we'd have an infinite loop
            line_count += 1;
        end

        return hash
    end # function - create_hash

    # Create backup using username, site URL, and DIR to save the backup
    def create_db_backup( username, site_url, save_in_dir )
        p "function: create_db_backup; #{username} is the user of the site: #{site_url}" if @debug
        wpconfig_file = "/home/#{username}/sites/#{site_url}/wp-config.php"

        wpdb   = ''
        wpuser = ''
        wppass = ''
        Open3.pipeline_rw( "sed \"s/[()',;]/ /g\" #{wpconfig_file}", 'grep DB_NAME', "awk '{print $3}'" ) {|i, o, thrs| wpdb = o.gets.chomp }
        Open3.pipeline_rw( "sed \"s/[()',;]/ /g\" #{wpconfig_file}", 'grep DB_USER', "awk '{print $3}'" ) {|i, o, thrs| wpuser = o.gets.chomp }
        Open3.pipeline_rw( "sed \"s/[()',;]/ /g\" #{wpconfig_file}", 'grep DB_PASSWORD', "awk '{print $3}'" ) {|i, o, thrs| wppass = o.gets.chomp }
        p "DB Credentials: User - '#{wpuser}', Pass - '#{wppass}', DB - '#{wpdb}'" if @debug

        system( "mysqldump --add-drop-table -u#{wpuser} -p'#{wppass}' #{wpdb} > #{save_in_dir}db.sql" )
        if !$?.exitstatus
            puts 'Could not create MySQL Dump'
            exit 1
        end

        system( "zip #{save_in_dir}#{site_url}-db.sql.zip #{save_in_dir}db.sql && rm #{save_in_dir}db.sql" )
        if !$?.exitstatus
            puts 'Could not zip or delete the SQL file'
            exit 1
        end

    end # function - create_db_backup

    def initialize( site_url )
        @site_name = site_url

        # Change the value to true to enable debugging
        @debug = false

        date = Time.now.strftime( "%Y-%m-%d" );
        time = Time.now.strftime( "%H:%M:%S" );

        #--- Variables ---#
        @username = 'pothi'
        if @username == ''
            puts 'Could not get USERNAME. Exiting.'
            exit 1
        end

        @wpcli_path = "/usr/local/bin/"
        @jekyllroot = "/home/#{@username}/others/plugins-updates-system/source/"
        @site_path  = "/home/#{@username}/sites/#{@site_name}/wordpress/"

        @git_working_dir = "/home/#{@username}/sites/#{@site_name}/"

        @blog_file_name = "#{@jekyllroot}_posts/#{date}-plugin-updates.md"

        @log_dir    = "/home/#{@username}/log/wpcli/"
        @wpcli_log  = "#{@log_dir}wp-cli.log"
        @prev_log    = "#{@log_dir}wp-cli-prev-#{@site_name}.log"
        @current_log = "#{@log_dir}wp-cli-current-#{@site_name}.log"
        @updated_log = "#{@log_dir}wp-cli-updated-#{@site_name}.log"

        #--- Internal variables ---#
        @prev_plugins_list    = Hash.new
        @current_plugins_list = Hash.new
        @updated_plugins_list = Hash.new
        @diff_auto_updated_plugins_list = Array.new

        #--- Actions ---#
        if !File.directory?( @log_dir )
            system( "mkdir -p #{@log_dir} &> /dev/null" )
            if !$?.exitstatus
                puts 'Could not create log directory'
                exit 1
            end
        end

        # Let's wait for the previous system process to exit :)
        sleep 1

        system( "echo >> #{@wpcli_log}" )
        if !$?.exitstatus
            puts 'Could not write to wp-cli.log file. Exiting!!!'
            exit 1
        end
        system( "date '+%F %H:%M:%S - #{@site_name}' >> #{@wpcli_log}" )

        # For FileUtils.*
        require 'fileutils'

        #-- prepare to record / display the results --#
        @blog_format = "---\n"
        @blog_format += "published: true\n"
        @blog_format += "title: Plugins changes\n"
        @blog_format += "date: #{date} #{time}\n"
        @blog_format += "layout: post\n"
        @blog_format += "category: plugins\n"
        @blog_format += "---\n\n"

        # prepend blog_format, for new file/s
        if !File.exists?( @blog_file_name )
            @blog_content = @blog_format
        else
            @blog_content = ''
        end

        @blog_content += "In [#{@site_name}](http://#{@site_name})\n\n"
        @any_auto_plugin_update = false # assume, no auto updates
        @any_manual_plugin_update = false # assume, no manual update/insert/removal occurred

        #- create current log -#
        system( "#{@wpcli_path}wp --path='#{@site_path}' --no-color plugin status > #{@current_log}" )
        if !$?.exitstatus
            puts 'Could not get current log / status of plugins. Exiting!'
            exit 1
        end

        #- create the hash for the current log -#
        @current_plugins_list = self.class.create_hash( @current_log )

        #-- This routine is NOT executed only once, when no previous data is found --#
        if File.exists?( @prev_log )
            #- create hash for prev log -#
            @prev_plugins_list = self.class.create_hash( @prev_log )

            #- compare prev hash and current hash -#
            @current_plugins_list.each { |name, version|
                if (version != @prev_plugins_list[name])
                    @any_manual_plugin_update = true
                    if @prev_plugins_list[name] == nil
                        @blog_content += "+    #{name} (at version #{version}) was activated.\n"
                    else
                        @blog_content += "+    #{name} was __manually__ modified from #{@prev_plugins_list[name]} to #{version}.\n"
                    end
                end
            }

            @prev_plugins_list.each { |name, version|
                if (version != @current_plugins_list[name]) and (@current_plugins_list[name] == nil)
                    @blog_content += "+    #{name} (at version #{version}) was deactivated.\n"
                    @any_manual_plugin_update = true
                end
            }

        end # File.exists? prev_log

        #--- update plugins and log results in site's root ---#
        system( "#{@wpcli_path}wp --path='#{@site_path}' plugin update-all >> #{@wpcli_log}" )
        if !$?.exitstatus
            puts 'Could not update all the plugins, even though, the previous log is found. Please check the wp-cli.log. Exiting!'
            exit 1
        end

        #- create the update status log -#
        system( "#{@wpcli_path}wp --path='#{@site_path}' --no-color plugin status > #{@updated_log}" )
        if !$?.exitstatus
            puts 'Could not get plugin status of updated plugins, even though, the previous log is found. Something must have gone wrong after updating plugins. Exiting!'
            exit 1
        end

        #- check if any plugins are updated and if any plugins were manually updated -#
        # create a hash of updated plugins
        @updated_plugins_list = self.class.create_hash( @updated_log )

        #- create a hash of updated plugins -#
        @current_plugins_list.each { |name, version|
            if @current_plugins_list[name] != @updated_plugins_list[name]
                @blog_content += "+    #{name} has been updated from #{version} to #{@updated_plugins_list[name]}.\n"
                @any_auto_plugin_update = true
            end
        }

        #- copy upload log to prev log via current log -#
        FileUtils.cp @updated_log, @current_log
        FileUtils.cp @current_log, @prev_log

        #- display results and commit changes, if updates were done -#
        if @any_manual_plugin_update or @any_auto_plugin_update
            # display results via Jekyll
            File.open( @blog_file_name, 'a' ) { |fh| fh.puts( @blog_content + "\n" ) }

            # Take SQL dump
            create_db_backup( @username, @site_name, @git_working_dir )

            #-- Commit changes --#
            g = Git.open(@git_working_dir, :log => Logger.new(STDOUT))
            g.add("#{@site_name}-db.sql.zip")
            g.add("wordpress/wp-content/plugins")
            g.commit( 'Automatic commit after plugin updates' )
            g.push
        end
    end # initialize
end # class PluginStatus

sites.each { | site_name | PluginStatus.new( site_name ) }
