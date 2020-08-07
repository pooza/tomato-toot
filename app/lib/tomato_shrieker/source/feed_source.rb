require 'feedjira'

module TomatoShrieker
  class FeedSource < Source
    def initialize(params)
      super
      @http = HTTP.new
      @http.base_uri = uri
    end

    def exec(options = {})
      if multi_entries?
        shriek(text: multi_entries_body, visibility: visibility)
      elsif options['silence']
        touch
      elsif touched? || options['all']
        fetch(&:shriek)
        logger.info(source: hash, message: 'crawl')
      elsif entry = fetch.to_a.last
        entry.shriek
      end
    end

    def unique_title?
      return self['/source/title/unique'] unless self['/source/title/unique'].nil?
      return true
    end

    def multi_entries?
      return self['/dest/multi_entries'] unless self['/dest/multi_entries'].nil?
      return false
    end

    def category
      return self['/dest/category']
    end

    def limit
      return self['/dest/limit'] || 5
    end

    def multi_entries_body
      template = Template.new(self.template)
      template[:entries] = feedjira.entries
        .select {|entry| category.nil? || entry.categories.member?(category)}
        .sort_by {|entry| entry.published.to_f}
        .first(limit)
        .reverse
      return template.to_s
    end

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
      Entry.create(feedjira.entries.max_by(&:published), self)
      logger.info(source: hash, message: 'touch')
    end

    def fetch
      return enum_for(__method__) unless block_given?
      feedjira.entries.sort_by {|entry| entry.published.to_f}.each do |v|
        next unless entry = Entry.create(v, self)
        yield entry
      end
    end

    def present?
      return feedjira.entries.present?
    end

    def uri
      return nil unless uri = Ginseng::URI.parse(self['/source/url'])
      return nil unless uri.absolute?
      return uri
    end

    def feedjira
      return Feedjira.parse(@http.get(uri).body)
    rescue Feedjira::NoParserAvailable => e
      raise Ginseng::GatewayError, "Invalid feed #{uri} #{e.message}"
    end

    def prefix
      return super || feedjira.title
    end

    def create_uri(href)
      uri = @http.create_uri(href)
      uri.fragment ||= self.uri.fragment
      return uri
    end
  end
end
