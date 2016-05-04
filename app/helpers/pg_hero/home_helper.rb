module PgHero

  module HomeHelper
    def pghero_post_to(name, url, html_options)
      html_options = html_options.stringify_keys
      html_options['value'] = name
      html_options['type'] = 'submit'

      params = html_options.delete('params')

      form_options = html_options.delete('form') || {}
      form_options[:method] = 'post'
      form_options[:action] = url
      form_options[:class] = 'button_to'

      # required for post html method
      request_token_tag = token_tag(nil)

      button = tag('input', html_options)

      inner_tags = ''.freeze.html_safe.
        safe_concat(request_token_tag).
        safe_concat(button)

      if params
        params.each do |param_name, param_value|
          inner_tags.safe_concat tag(:input, type: 'hidden', name: param_name, value: param_value)
        end
      end

      content_tag('form', inner_tags, form_options)
    end
  end

end
