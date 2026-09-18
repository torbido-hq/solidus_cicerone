# frozen_string_literal: true

require "json"
require "net/http"
require "uri"

require "solidus_cicerone/errors"

module SolidusCicerone
  class Client
    DEFAULT_TIMEOUT = 15

    attr_reader :base_url, :token, :events_token, :trigger_url, :trigger_token, :timeout

    def self.from_config(config = SolidusCicerone.configuration)
      new(
        base_url: config.serve_url,
        token: config.serve_token,
        events_token: config.events_token,
        trigger_url: config.trigger_url,
        trigger_token: config.trigger_token
      )
    end

    def initialize(base_url:, token: nil, events_token: nil, trigger_url: nil, trigger_token: nil,
                   timeout: DEFAULT_TIMEOUT)
      @base_url = normalize_base(base_url)
      @token = presence(token)
      @events_token = presence(events_token) || @token
      @trigger_url = normalize_base(trigger_url)
      @trigger_token = presence(trigger_token)
      @timeout = timeout
    end

    def health
      request(:get, "/health", auth: false)
    end

    def recommendations(user_id, limit: nil, k: nil, category: nil, exclude_unavailable: nil)
      raise ConfigurationError, "serve_url is required" if @base_url.nil?

      params = {}
      params[:limit] = limit unless limit.nil?
      params[:k] = k unless k.nil?
      params[:category] = category unless category.nil?
      unless exclude_unavailable.nil?
        params[:exclude_unavailable] = exclude_unavailable ? "true" : "false"
      end

      path = "/recommendations/#{URI.encode_www_form_component(user_id.to_s)}"
      request(:get, path, params: params, token: @token)
    end

    def post_events(events)
      raise ConfigurationError, "serve_url is required" if @base_url.nil?

      request(:post, "/events", json_body: wrap_events(events), token: @events_token)
    end

    def post_track(events)
      raise ConfigurationError, "serve_url is required" if @base_url.nil?

      request(:post, "/track", json_body: wrap_events(events), token: @token)
    end

    def trigger_retrain
      raise ConfigurationError, "trigger_url is required" if @trigger_url.nil?

      request(:post, "/trigger/retrain", token: @trigger_token, base: @trigger_url)
    end

    private

    def wrap_events(events)
      list = events.is_a?(Array) ? events : [events]
      return list.first if list.size == 1

      { "events" => list }
    end

    def request(method, path, params: nil, json_body: nil, token: nil, auth: true, base: @base_url)
      uri = URI.join("#{base}/", path.delete_prefix("/"))
      uri.query = URI.encode_www_form(params) if params && !params.empty?

      klass = method == :post ? Net::HTTP::Post : Net::HTTP::Get
      req = klass.new(uri)
      req["Accept"] = "application/json"
      req["Authorization"] = "Bearer #{token}" if auth && token
      if json_body
        req["Content-Type"] = "application/json"
        req.body = JSON.generate(json_body)
      end

      res = Net::HTTP.start(uri.hostname, uri.port, use_ssl: uri.scheme == "https") do |http|
        http.open_timeout = @timeout
        http.read_timeout = @timeout
        http.request(req)
      end

      parse_response(res)
    end

    def parse_response(res)
      body = parse_body(res.body)
      code = res.code.to_i
      return body if res.is_a?(Net::HTTPSuccess)

      message = error_detail(body) || res.message
      error_class = retryable?(code) ? RetryableError : Error
      raise error_class.new("HTTP #{code}: #{message}", status_code: code, body: body)
    end

    def parse_body(raw)
      return {} if raw.nil? || raw.empty?

      JSON.parse(raw)
    rescue JSON::ParserError
      raw
    end

    def error_detail(body)
      return unless body.is_a?(Hash)

      detail = body["detail"] || body["message"]
      detail.is_a?(Array) ? detail.to_json : detail
    end

    def retryable?(code)
      code == 429 || code >= 500
    end

    def normalize_base(url)
      value = presence(url)
      return if value.nil?

      value.to_s.sub(%r{/\z}, "")
    end

    def presence(value)
      return if value.nil?

      stripped = value.respond_to?(:strip) ? value.strip : value
      stripped.to_s.empty? ? nil : stripped
    end
  end
end
