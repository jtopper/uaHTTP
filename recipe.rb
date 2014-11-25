class UA2uaHTTP < FPM::Cookery::Recipe

    source      'nothing', :with => :noop
    name        'ua2-uahttp'
    description 'uaHTTP server'
    maintainer  'Jon Topper <jon@scalefactory.com>'
    vendor      'fpm'
    revision    0

    depends 'perl-HTTP-Daemon-SSL', 'daemonize'

    post_install "dist/post-install"

    if ENV.has_key?('PKG_VERSION')
        version ENV['PKG_VERSION']
    else
        raise 'No PKG_VERSION passed in the environment'
    end

    def build
        # Nothing to do here
    end

    def install

        root('srv/uahttp').install Dir["#{workdir}/app/*"]
        mkdir_p etc('init.d')
        mkdir_p etc('logrotate.d')
        cp "#{workdir}/dist/init", etc("init.d/ua2-uahttp")
        cp "#{workdir}/dist/logrotate", etc("logrotate.d/ua2-uahttpd")

    end

end
