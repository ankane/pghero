module PgHero
  class Assets
    JAVASCRIPTS = %w(jquery nouislider Chart.bundle chartkick highlight.pack application).map { |name| "pghero/#{name}.js" }.freeze
    STYLESHEETS = %w(nouislider arduino-light application).map { |name| "pghero/#{name}.css" }.freeze
    FAVICON = "pghero/favicon.png".freeze

    attr_reader :javascript_root, :stylesheet_root, :image_root

    def initialize(root)
      @javascript_root = root.join("javascripts")
      @stylesheet_root = root.join("stylesheets")
      @image_root = root.join("images")
    end

    # Javacript

    def javascript_sources
      JAVASCRIPTS
    end

    def javascript_source
      javascript_sources.last
    end

    def javascript_content
      javascript_sources.map { |source| javascript_root.join(source).read }.join("\n\n").freeze
    end

    # Stylesheets

    def stylesheet_sources
      STYLESHEETS
    end

    def stylesheet_source
      stylesheet_sources.last
    end

    def stylesheet_content
      stylesheet_sources.map { |source| stylesheet_root.join(source).read }.join("\n\n").freeze
    end

    # Favicon

    def favicon_source
      FAVICON
    end

    def favicon_type
      @favicon_type ||= "image/#{favicon_source.split(".").last}".freeze
    end

    def favicon_data_uri
      @favicon_data_uri ||= "data:#{favicon_type};base64,#{Base64.strict_encode64(image_root.join(favicon_source).binread)}".freeze
    end
  end
end
