# frozen_string_literal: true

require 'grape/util/lazy_object'

module Grape
  class Request < Rack::Request
    HTTP_PREFIX = 'HTTP_'

    alias rack_params params

    def initialize(env, **options)
      extend options[:build_params_with] || Grape.config.param_builder
      super(env)
    end

    def params
      @params ||= build_params
    rescue EOFError
      raise Grape::Exceptions::EmptyMessageBody.new(content_type)
    rescue Rack::Multipart::MultipartPartLimitError
      raise Grape::Exceptions::TooManyMultipartFiles.new(Rack::Utils.multipart_part_limit)
    end

    def headers
      @headers ||= build_headers
    end

    private

    def grape_routing_args
      args = env[Grape::Env::GRAPE_ROUTING_ARGS].dup
      # preserve version from query string parameters
      args.delete(:version)
      args.delete(:route_info)
      args
    end

    def build_headers
      Grape::Util::LazyObject.new do
        env.each_pair.with_object({}) do |(k, v), headers|
          next unless k.to_s.start_with? HTTP_PREFIX

          transformed_header = Grape::Http::Headers::HTTP_HEADERS[k] || transform_header(k)
          headers[transformed_header] = v
        end
      end
    end

    if Grape.rack3?
      def transform_header(header)
        -header[5..].tr('_', '-').downcase
      end
    else
      def transform_header(header)
        -header[5..].split('_').map(&:capitalize).join('-')
      end
    end
  end
end
