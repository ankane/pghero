require_relative "test_helper"

class AssetsTest < Minitest::Test
  def test_javascript_source
    assert_equal "pghero/application.js", PgHero.assets.javascript_source
  end

  def test_javascript_sources
    sources = PgHero.assets.javascript_sources
    assert_equal "pghero/application.js", sources.last
    assert_operator sources.size, :>, 1
    sources.each do |source|
      assert_match /^pghero\/[^\/]+\.js$/, source
    end
  end

  def test_javascript_content
    content = PgHero.assets.javascript_content
    assert_kind_of String, content
    assert_operator content.size, :>, 0
    PgHero.assets.javascript_sources.each do |source|
      source_file = PgHero::Engine.root.join("app/assets/javascripts/#{source}")
      assert content.include?(source_file.read), "Expected javascript_content to include the contents of #{source_file.basename}"
    end
  end

  def test_stylesheet_source
    assert_equal "pghero/application.css", PgHero.assets.stylesheet_source
  end

  def test_stylesheet_sources
    sources = PgHero.assets.stylesheet_sources
    assert_equal "pghero/application.css", sources.last
    assert_operator sources.size, :>, 1
    sources.each do |source|
      assert_match /^pghero\/[^\/]+\.css$/, source
    end
  end

  def test_stylesheet_content
    content = PgHero.assets.stylesheet_content
    assert_kind_of String, content
    assert_operator content.size, :>, 0
    PgHero.assets.stylesheet_sources.each do |source|
      source_file = PgHero::Engine.root.join("app/assets/stylesheets/#{source}")
      assert content.include?(source_file.read), "Expected stylesheet_content to include the contents of #{source_file.basename}"
    end
  end

  def test_favicon_source
    assert_equal "pghero/favicon.png", PgHero.assets.favicon_source
  end

  def test_favicon_type
    assert_equal "image/png", PgHero.assets.favicon_type
  end

  def test_favicon_data_uri
    assert_match /^data:image\/png;base64,\w{20,}+/, PgHero.assets.favicon_data_uri
  end
end
