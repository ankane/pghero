module PgHero

  module HomeHelper
    def pghero_post_to(name, url, html_options = {})
      html_options.stringify_keys!

      form_options = html_options.delete('form') || {}
      form_options['class'] = 'button_to'
      params = html_options.delete('params')

      form_tag(url, form_options) do
        tags = ''.freeze.html_safe

        tags.safe_concat submit_tag(name, html_options)

        if params
          params.each do |param_key, param_value|
            tags.safe_concat hidden_field_tag(param_key, param_value)
          end
        end

        tags
      end
    end
  end

end
