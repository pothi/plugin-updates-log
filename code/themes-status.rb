#!/usr/bin/env ruby

# Script to check the status of plugins, update them and publish the changelog

#--- Variables ---#
DATA_DIR        = '/home/pothi/sites/dostatus.tinywp.com/data/'
git_status_log  = DATA_DIR + 'git-status.log'
updated_log     = DATA_DIR + 'git-temp.log'

site_name	= "wpsc.tinywp.com"
site_path	= "/home/pothi/sites/#{site_name}/wordpress/wp-content/themes/"

jekyll_blog_url  = 'dostatus.tinywp.com'
jekyll_post_path = '/home/pothi/sites/dostatus.tinywp.com/sources/_posts/'

#--- Internal variables ---#
prev_plugins    = Hash.new
current_plugins = Hash.new
updated_plugins = Hash.new
diff_plugins	= Array.new

#--- Functions ---#

#--- Actions ---#

#--- Run git status and get its output as a log file ---#
# system( "cd #{site_path}; git status > #{git_status_log}" )
system ( "echo test" );
if $?.exitstatus == 0
	puts 'Step #1 - Success - Git log file is ready'
else
	puts 'Something has gone wrong, while checking the git status'
	exit 1
end

#--- Process the output log file and see if there are any changes since the last check ---#
lines_count = File.readlines( git_status_log ).count
puts "Total number of lines in the git log: #{lines_count}"
if lines_count == 2
	second_line = File.readlines( git_status_log )[1]
#--- if no change, quit ---#
	if /^nothing to commit.*/.match( second_line )
		# no changes in the themes folder; so exit
		exit
	else
		puts 'Something is wrong; Please check the second line of the git log'
		exit 1
	end
	# puts "Second Line is #{second_line}"
	# exit
end

#--- Upon changes: get changed files and folders ---#
changed_files = Array.new
File.readlines( git_status_log ).each do |line|
	if /^#\t/.match( line )
		changed_files.push( String.try_convert(line).gsub( /#\t(modified:[[:blank:]]{3})?/, '' ) )
	end
end

#--- Record it as a new blog post ---#

date = Time.now.strftime( "%Y-%m-%d" );
time = Time.now.strftime( "%H:%M:%S" );
# puts time
blog_format = "---\n"
blog_format += "published: true\n"
blog_format += "title: Changes in Themes Directory\n"
blog_format += "date: #{date} #{time}\n"
blog_format += "layout: post\n"
blog_format += "category: themes\n"
blog_format += "---\n"
# puts blog_format

blog_content = "#Since last check...#\n"
blog_content += "##In [#{site_name}](http://#{site_name})...##\n"
blog_content += "Changed files / folders are...\n\n"
changed_files.each do |file|
	blog_content += '+    ' + String.try_convert( file )
end
commit_ID = nil
# puts blog_content

#--- Run git add . && git commit -m 'some message' ---#
# system( "cd #{site_path}; git add ." )
# system( "cd #{site_path}; git commit -m 'Changes as of #{date} #{time}...'" )
# test_msg = system( "cd #{site_path}; git log -1 --pretty=oneline " )
IO.popen( "cd #{site_path}; git log -1 --pretty=oneline " ) { |file_handle|
	commit_ID = file_handle.gets.split[0]
}
# puts commit_ID
# File.readline( updated_log ).each do |line|

#--- Append the commit ID in the blog post ---#
blog_content += "\nFor more info, please contact Pothi, with the log ID `#{commit_ID}` or the URL of this post!\n\n"
# puts blog_content

#--- Publish the blog post ---#
blog_file_path = "/home/pothi/sites/dostatus.tinywp.com/source/_posts/"
blog_file_name = "#{date}-theme-updates.md"
File.open( blog_file_path + blog_file_name, "w" ) {
	|file_handle|
	file_handle.write( blog_format )
	file_handle.write( blog_content )
}

#--- quit ---#
