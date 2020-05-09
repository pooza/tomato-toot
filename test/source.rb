module TomatoToot
  class SourceTest < Test::Unit::TestCase
    def test_all
      Source.all do |source|
        assert_kind_of(Source, source)
      end
    end

    def test_to_h
      Source.all do |source|
        assert_kind_of(Hash, source.to_h)
      end
    end

    def test_mulukhiya?
      Source.all do |source|
        assert_boolean(source.mulukhiya?)
      end
    end

    def test_bot_account?
      Source.all do |source|
        assert_boolean(source.bot_account?)
        assert_boolean(source.bot?)
      end
    end

    def test_template
      Source.all do |source|
        assert_kind_of(String, source.template)
      end
    end

    def test_mastodon
      Source.all do |source|
        assert_boolean(source.mastodon?)
        next unless source.mastodon?
        assert_kind_of(Mastodon, source.mastodon)
      end
    end

    def test_webhooks
      Source.all do |source|
        source.webhooks.each do |webhook|
          assert_kind_of(Slack, webhook)
        end
      end
    end

    def test_tags
      Source.all do |source|
        source.tags.each do |tag|
          assert_kind_of(String, tag)
        end
      end
    end

    def test_visibility
      Source.all do |source|
        assert_kind_of(String, source.visibility)
      end
    end

    def test_prefix
      Source.all do |source|
        next if source.prefix.nil?
        assert_kind_of(String, source.prefix)
      end
    end

    def test_period
      Source.all do |source|
        assert_kind_of(String, source.period)
      end
    end
  end
end
