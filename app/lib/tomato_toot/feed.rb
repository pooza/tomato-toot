require 'feedjira'
require 'digest/sha1'
require 'nokogiri'
require 'optparse'

module TomatoToot
  class Feed
    attr_reader :logger

    def initialize(params)
      @config = Config.instance
      @params = params
      @http = HTTP.new
      @http.base_uri = uri
      @logger = Logger.new
    end

    def [](name)
      [@params.key_flatten, @params].each do |v|
        return v[name] unless v[name].nil?
      end
      return nil
    end

    def to_h
      return {hash: hash}.merge(@params)
    end

    def hash
      return Digest::SHA1.hexdigest(@params.to_json)
    end

    def exec(options = {})
      if options['silence']
        touch
      elsif command?
        command.exec
        raise command.stderr || command.stdout unless command.status.zero?
        post(command.stdout)
      elsif touched?
        fetch(&:post)
        logger.info(feed: hash, message: 'crawl')
      elsif entry = fetch.to_a.last
        entry.post
      end
    end

    alias crawl exec

    def time
      unless @time
        records = Entry.dataset
          .select(:published)
          .where(feed: hash)
          .order(Sequel.desc(:published))
          .limit(1)
        @time = records.first&.published
      end
      return @time
    end

    def touched?
      return time.present?
    end

    def touch
      return unless feedjira
      Entry.create(feedjira.entries.max_by(&:published), self)
      logger.info(feed: hash, message: 'touch')
    end

    def command?
      return command.present?
    end

    def command
      return nil unless self['/source/command'].present?
      args = self['/source/command']
      args = args.split(/\s+/) unless args.is_a?(Array)
      @command ||= Ginseng::CommandLine.new(args)
      return @command
    end

    def fetch
      return enum_for(__method__) unless block_given?
      feedjira.entries.sort_by {|entry| entry.published.to_f}.each do |v|
        entry = Entry.create(v, self)
        yield entry if entry
      end
    end

    def post(text)
      mastodon&.toot(status: text, visibility: visibility)
      hooks {|hook| hook.say({text: text}, :hash)}
      logger.info(feed: hash, message: 'post')
    end

    def mulukhiya?
      return self['/mulukhiya/enable'] || true
    end

    def bot_account?
      return self['/bot_account'] || false
    end

    alias bot? bot_account?

    def template
      return self['/template'] || 'default'
    end

    def present?
      return feedjira&.entries.present?
    end

    def uri
      return nil unless uri = Ginseng::URI.parse(self['/source/url'])
      return nil unless uri.absolute?
      return uri
    end

    def mastodon
      unless @mastodon
        return nil unless uri = self['/mastodon/url']
        return nil unless token = self['/mastodon/token']
        @mastodon = Mastodon.new(uri, token)
        @mastodon.mulukhiya_enable = mulukhiya?
      end
      return @mastodon
    end

    def mastodon?
      return mastodon.present?
    end

    def webhooks
      return enum_for(__method__) unless block_given?
      (self['/hooks'] || []).each do |hook|
        yield Slack.new(Ginseng::URI.parse(hook))
      end
    end

    alias hooks webhooks

    def feedjira
      return Feedjira.parse(@http.get(uri).body) if uri
      return nil
    rescue Feedjira::NoParserAvailable => e
      raise Ginseng::GatewayError, "Invalid feed #{uri} #{e.message}"
    end

    def mode
      unless @mode
        @mode = self['/source/mode'] || 'title'
        @mode = 'summary' if @mode == 'body'
      end
      return @mode
    end

    def tags
      return (self['/toot/tags'] || []).map do |tag|
        Mastodon.create_tag(tag)
      end
    end

    alias toot_tags tags

    def visibility
      return self['/visibility'] || 'public'
    end

    def prefix
      return self['/prefix'] || feedjira.title
    end

    def period
      return self['/period'] || '5m'
    end

    def create_uri(href)
      uri = @http.create_uri(href)
      uri.fragment ||= self.uri.fragment
      return uri
    end

    def self.all
      return enum_for(__method__) unless block_given?
      Config.instance['/entries'].each do |entry|
        next unless entry['source']
        yield Feed.new(entry)
      end
    end

    def self.create(hash)
      all do |feed|
        return feed if feed.hash == hash
      end
    end

    def self.exec_all
      options = ARGV.getopts('', 'silence')
      threads = []
      Sequel.connect(Environment.dsn).transaction do
        all do |feed|
          threads.push(Thread.new {feed.exec(options)})
        rescue => e
          e = Ginseng::Error.create(e)
          e.package = Package.full_name
          Slack.broadcast(e)
          feed.logger.error(e)
        end
        threads.map(&:join)
      end
    end
  end
end
