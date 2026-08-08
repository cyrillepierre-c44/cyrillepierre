require "test_helper"

class UrlScraperTest < ActiveSupport::TestCase
  test "rejects non-http(s) schemes" do
    assert_raises(UrlScraper::UnsafeUrlError) { UrlScraper.call("ftp://example.com") }
    assert_raises(UrlScraper::UnsafeUrlError) { UrlScraper.call("file:///etc/passwd") }
  end

  test "rejects URLs without a host" do
    assert_raises(UrlScraper::UnsafeUrlError) { UrlScraper.call("http://") }
  end

  test "rejects loopback addresses" do
    assert_raises(UrlScraper::UnsafeUrlError) { UrlScraper.call("http://127.0.0.1") }
    assert_raises(UrlScraper::UnsafeUrlError) { UrlScraper.call("http://localhost") }
  end

  test "rejects private network addresses" do
    assert_raises(UrlScraper::UnsafeUrlError) { UrlScraper.call("http://192.168.1.1") }
    assert_raises(UrlScraper::UnsafeUrlError) { UrlScraper.call("http://10.0.0.1") }
  end

  test "rejects link-local addresses" do
    assert_raises(UrlScraper::UnsafeUrlError) { UrlScraper.call("http://169.254.169.254") }
  end

  test "rejects reserved ranges such as carrier-grade NAT and multicast" do
    assert_raises(UrlScraper::UnsafeUrlError) { UrlScraper.call("http://100.64.0.1") }
    assert_raises(UrlScraper::UnsafeUrlError) { UrlScraper.call("http://224.0.0.1") }
  end

  test "rejects a host that does not resolve" do
    Resolv.stub(:getaddresses, []) do
      assert_raises(UrlScraper::UnsafeUrlError) { UrlScraper.call("http://nowhere.example") }
    end
  end

  # --- chemin nominal --------------------------------------------------------
  # L'hôte est résolu vers une adresse publique, la requête HTTP est interceptée.

  PUBLIC_IP = "93.184.216.34".freeze

  def with_public_host(&block)
    Resolv.stub(:getaddresses, [ PUBLIC_IP ], &block)
  end

  test "returns the visible text of the page" do
    stub_request(:get, "https://example.com/article")
      .to_return(status: 200, body: "<html><body><h1>Titre</h1>\n<p>Le corps du texte.</p></body></html>")

    text = with_public_host { UrlScraper.call("https://example.com/article") }

    assert_includes text, "Titre"
    assert_includes text, "Le corps du texte."
    assert_not_includes text, "<p>"
  end

  # Nokogiri#text concatène les blocs sans séparateur : deux éléments collés dans la source
  # ressortent soudés. Comportement connu, acté ici pour qu'un changement soit délibéré.
  test "adjacent block elements are concatenated without a separator" do
    stub_request(:get, "https://example.com/")
      .to_return(status: 200, body: "<h1>Titre</h1><p>Corps</p>")

    text = with_public_host { UrlScraper.call("https://example.com/") }

    assert_equal "TitreCorps", text
  end

  test "drops scripts, styles and noscript blocks" do
    body = <<~HTML
      <html><head><style>.a { color: red }</style></head>
      <body><script>var secret = 1;</script><noscript>Activez JS</noscript><p>Contenu utile.</p></body></html>
    HTML
    stub_request(:get, "https://example.com/").to_return(status: 200, body: body)

    text = with_public_host { UrlScraper.call("https://example.com/") }

    assert_equal "Contenu utile.", text
  end

  test "identifies itself with a dedicated user agent" do
    stub_request(:get, "https://example.com/").to_return(status: 200, body: "<p>ok</p>")

    with_public_host { UrlScraper.call("https://example.com/") }

    assert_requested :get, "https://example.com/",
                     headers: { "User-Agent" => "CyrillePierreStudioBot/1.0" }
  end

  test "truncates a very long page without an ellipsis" do
    stub_request(:get, "https://example.com/")
      .to_return(status: 200, body: "<p>#{'mot ' * 5_000}</p>")

    text = with_public_host { UrlScraper.call("https://example.com/") }

    assert_equal UrlScraper::MAX_TEXT_LENGTH, text.length
    assert_not_includes text, "..."
  end

  test "raises on a non-success HTTP response" do
    stub_request(:get, "https://example.com/").to_return(status: 404, body: "nope")

    error = assert_raises(UrlScraper::UnsafeUrlError) do
      with_public_host { UrlScraper.call("https://example.com/") }
    end
    assert_includes error.message, "404"
  end

  test "raises a readable error when the host cannot be reached" do
    stub_request(:get, "https://example.com/").to_timeout

    error = assert_raises(UrlScraper::UnsafeUrlError) do
      with_public_host { UrlScraper.call("https://example.com/") }
    end
    assert_includes error.message, "Impossible de récupérer l'URL"
  end

  test "works over plain http as well as https" do
    stub_request(:get, "http://example.com/").to_return(status: 200, body: "<p>en clair</p>")

    text = with_public_host { UrlScraper.call("http://example.com/") }

    assert_equal "en clair", text
  end
end
