require "test_helper"

class LinkedinPublisherTest < ActiveSupport::TestCase
  FakeResponse = Struct.new(:status, :body, :headers) do
    def success?
      status.to_i.between?(200, 299)
    end
  end

  def connected_user
    User.create!(email: "linkedin-#{SecureRandom.hex(4)}@example.com", password: "password123",
                 linkedin_access_token: "token", linkedin_token_expires_at: 60.days.from_now,
                 linkedin_member_urn: "member-123")
  end

  test "raises when the user has no connected LinkedIn account" do
    user = User.create!(email: "nolinkedin@example.com", password: "password123")
    generation = Generation.create!(user: user, kind: :linkedin_post, output: "Un post.")

    assert_raises(LinkedinPublisher::Error) { LinkedinPublisher.call(generation) }
  end

  test "raises when there is no output to publish" do
    generation = Generation.create!(user: connected_user, kind: :linkedin_post)

    assert_raises(LinkedinPublisher::Error) { LinkedinPublisher.call(generation) }
  end

  test "publishes the post, stamps linkedin_published_at and stores the post urn" do
    generation = Generation.create!(user: connected_user, kind: :linkedin_post, output: "Un **post** de test.")

    original_post = Faraday.method(:post)
    Faraday.define_singleton_method(:post) do |*_args, **_kwargs|
      FakeResponse.new(201, "", { "x-restli-id" => "urn:li:share:123" })
    end

    begin
      LinkedinPublisher.call(generation)
      generation.reload
      assert generation.linkedin_published_at.present?
      assert_equal "urn:li:share:123", generation.linkedin_post_urn
      assert_equal "https://www.linkedin.com/feed/update/urn:li:share:123/", generation.linkedin_post_url
    ensure
      Faraday.define_singleton_method(:post, original_post)
    end
  end

  test "raises a readable error when LinkedIn rejects the post" do
    generation = Generation.create!(user: connected_user, kind: :linkedin_post, output: "Un post.")

    original_post = Faraday.method(:post)
    Faraday.define_singleton_method(:post) do |*_args, **_kwargs|
      FakeResponse.new(401, { message: "Invalid access token" }.to_json)
    end

    begin
      error = assert_raises(LinkedinPublisher::Error) { LinkedinPublisher.call(generation) }
      assert_includes error.message, "Invalid access token"
    ensure
      Faraday.define_singleton_method(:post, original_post)
    end
  end
end
