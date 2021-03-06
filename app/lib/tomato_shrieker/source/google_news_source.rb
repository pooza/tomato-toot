module TomatoShrieker
  class GoogleNewsSource < FeedSource
    def uri
      uri = Ginseng::URI.parse(self['/source/google_news'])
      return nil unless uri&.absolute?
      return uri
    end

    def unique_title?
      return true
    end

    def template_name
      return 'title'
    end

    def fetch
      return enum_for(__method__) unless block_given?
      feedjira.entries.sort_by {|entry| entry.published.to_f}.each do |v|
        next if Entry.first(feed: id, title: NewsEntry.create_title(v['title'], self))
        next unless entry = NewsEntry.create(v, self)
        yield entry
      end
    end

    def self.all(&block)
      return enum_for(__method__) unless block
      Source.all.select {|s| s.is_a?(GoogleNewsSource)}.each(&block)
    end
  end
end
