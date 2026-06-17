require "net/http"
require "resolv"
require "ipaddr"

# Fetches a URL and extracts its visible text content, for use as LLM input.
# Blocks requests to private/loopback/link-local addresses to prevent SSRF,
# since the URL is supplied by an authenticated user but isn't necessarily trustworthy.
class UrlScraper
  class UnsafeUrlError < StandardError; end

  MAX_RESPONSE_BYTES = 2.megabytes
  MAX_TEXT_LENGTH = 8_000
  TIMEOUT = 8

  RESERVED_RANGES = [
    IPAddr.new("0.0.0.0/8"),
    IPAddr.new("100.64.0.0/10"),
    IPAddr.new("224.0.0.0/4"),
    IPAddr.new("fc00::/7")
  ].freeze

  def self.call(url)
    new(url).call
  end

  def initialize(url)
    @url = url
  end

  def call
    uri = parse_and_validate_url
    extract_text(fetch(uri))
  end

  private

  attr_reader :url

  def parse_and_validate_url
    uri = URI.parse(url.to_s.strip)
    raise UnsafeUrlError, "URL invalide" unless uri.is_a?(URI::HTTP) || uri.is_a?(URI::HTTPS)
    raise UnsafeUrlError, "Hôte manquant" if uri.host.blank?

    ensure_public_host!(uri.host)
    uri
  end

  def ensure_public_host!(host)
    addresses = Resolv.getaddresses(host)
    raise UnsafeUrlError, "Impossible de résoudre l'hôte" if addresses.empty?

    addresses.each do |address|
      ip = IPAddr.new(address)
      raise UnsafeUrlError, "Adresse IP non autorisée" if private_or_reserved?(ip)
    end
  end

  def private_or_reserved?(ip)
    ip.private? || ip.loopback? || ip.link_local? || RESERVED_RANGES.any? { |range| range.include?(ip) }
  end

  def fetch(uri)
    response = build_http(uri).request(build_request(uri))
    raise UnsafeUrlError, "Réponse HTTP #{response.code}" unless response.is_a?(Net::HTTPSuccess)

    response.body.to_s.byteslice(0, MAX_RESPONSE_BYTES)
  rescue Timeout::Error, SocketError, OpenSSL::SSL::SSLError => e
    raise UnsafeUrlError, "Impossible de récupérer l'URL : #{e.message}"
  end

  def build_http(uri)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = uri.scheme == "https"
    http.open_timeout = TIMEOUT
    http.read_timeout = TIMEOUT
    http
  end

  def build_request(uri)
    request = Net::HTTP::Get.new(uri)
    request["User-Agent"] = "CyrillePierreStudioBot/1.0"
    request
  end

  def extract_text(html)
    doc = Nokogiri::HTML(html.to_s)
    doc.css("script, style, noscript").remove
    doc.text.to_s.squish.truncate(MAX_TEXT_LENGTH, omission: "")
  end
end
