require "test_helper"

class TavilyTest < ActiveSupport::TestCase
  setup do
    @key = ENV["TAVILY_API_KEY"]
    ENV["TAVILY_API_KEY"] = "tvly-test"
  end

  teardown { ENV["TAVILY_API_KEY"] = @key }

  test "posts the query with the key and maps the results" do
    stub = stub_request(:post, Tavily::SEARCH_URL)
           .with { |req| body = JSON.parse(req.body); body["api_key"] == "tvly-test" && body["query"] == "directeur usine MAPEI" && body["include_raw_content"] == true }
           .to_return(status: 200, body: { results: [{ title: "T", url: "https://example.com/a", content: "extrait",
                                                       raw_content: "page entière" }] }.to_json)

    results = Tavily.search("directeur usine MAPEI", raw: true)

    assert_requested stub
    assert_equal ["T", "https://example.com/a", "extrait", "page entière"], results.first.to_a
    assert_equal "extrait\npage entière", results.first.text
  end

  test "refuses to run without a key and reports an HTTP failure" do
    ENV["TAVILY_API_KEY"] = nil
    assert_raises(Tavily::NotConfiguredError) { Tavily.search("x") }

    ENV["TAVILY_API_KEY"] = "tvly-test"
    stub_request(:post, Tavily::SEARCH_URL).to_return(status: 432, body: "")
    error = assert_raises(RuntimeError) { Tavily.search("x") }
    assert_equal "Tavily HTTP 432", error.message
  end
end
