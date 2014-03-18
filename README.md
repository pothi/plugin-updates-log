Plugin Updates Log
------------------

Logging WordPress Plugin Updates

Updating plugins may not be an smooth experience for everyone those don't have a test site. Even after testing, some updates go wrong on the production environment. Logging what's updated may help at times. So, here's a logger script that does more than just logging. It also updates plugins automatically. You can, of course, disable automatic updates. The logging can be used to publish the log via a publishing platform, such as Jekyll. Jekyll has many advantages over WordPress, as a static blogging platform. Jekyll can be used with Github Pages for free hosting, or with Amazon S3. The possibilities are endless. Use this script however you wish.

__Things to change in the script__

    - Your site URL
    - Username
    - Path to WordPress file
    - Path to Jekyll source

__Things to change in source/_config.xml__

    - Source URL
    - Deploy URL
    - BaseURL

How to start Jekyll (as of version 1.4.3

`jekyll serve --config=/path/to/source/_config.xml`
