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
end
