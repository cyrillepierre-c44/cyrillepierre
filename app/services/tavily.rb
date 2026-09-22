require "net/http"

# Moteur de recherche pour agents (clé `TAVILY_API_KEY`, la même que dans l'outil d'analyse
# financière). Une recherche « advanced » coûte deux crédits sur les mille gratuits du mois ;
# `raw` ramène le texte entier des pages, ce que les sites de presse refusent souvent à un
# simple curl.
module Tavily
  SEARCH_URL = "https://api.tavily.com/search".freeze
  TIMEOUT = 25
  RAW_LIMIT = 6_000

  class NotConfiguredError < StandardError; end

  Result = Struct.new(:title, :url, :content, :raw_content) do
    def text
      [content, raw_content].compact_blank.join("\n").truncate(RAW_LIMIT, omission: "")
    end
  end

  def self.search(query, max_results: 5, raw: false)
    key = ENV.fetch("TAVILY_API_KEY", nil)
    raise NotConfiguredError, "TAVILY_API_KEY absente" if key.blank?

    uri = URI(SEARCH_URL)
    request = Net::HTTP::Post.new(uri, "Content-Type" => "application/json")
    request.body = { api_key: key, query: query, search_depth: "advanced", include_answer: false,
                     include_raw_content: raw, max_results: max_results }.to_json
    options = { use_ssl: true, open_timeout: TIMEOUT, read_timeout: TIMEOUT }
    response = Net::HTTP.start(uri.host, uri.port, **options) { |http| http.request(request) }
    raise "Tavily HTTP #{response.code}" unless response.is_a?(Net::HTTPSuccess)

    JSON.parse(response.body).fetch("results", []).map do |r|
      Result.new(r["title"].to_s, r["url"].to_s, r["content"].to_s, r["raw_content"].to_s.presence)
    end
  end
end
