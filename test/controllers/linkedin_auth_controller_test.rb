require "test_helper"

class LinkedinAuthControllerTest < ActionDispatch::IntegrationTest
  FakeResponse = Struct.new(:body)

  setup do
    @user = User.create!(email: "editor@example.com", password: "password123")
    sign_in @user
  end

  test "connect redirects to LinkedIn and stores a state in session" do
    get linkedin_auth_connect_path
    assert_response :redirect
    assert_match %r{\Ahttps://www\.linkedin\.com/oauth/v2/authorization\?}, @response.redirect_url
  end

  test "callback rejects a missing or mismatched state" do
    get linkedin_auth_callback_path, params: { code: "abc", state: "wrong" }
    assert_redirected_to studio_generations_path
    assert_not @user.reload.linkedin_connected?
  end

  test "callback redirects with an alert when LinkedIn reports an error" do
    get linkedin_auth_callback_path, params: { error: "access_denied" }
    assert_redirected_to studio_generations_path
    assert_equal "Connexion LinkedIn annulée.", flash[:alert]
  end

  test "callback stores the token and member urn on success" do
    get linkedin_auth_connect_path
    state = session_state

    original_post = Faraday.method(:post)
    original_get = Faraday.method(:get)
    Faraday.define_singleton_method(:post) do |*_args, **_kwargs|
      FakeResponse.new({ access_token: "a-token", expires_in: 5_184_000 }.to_json)
    end
    Faraday.define_singleton_method(:get) do |*_args, **_kwargs, &_blk|
      FakeResponse.new({ sub: "member-123" }.to_json)
    end

    begin
      get linkedin_auth_callback_path, params: { code: "abc", state: state }
      assert_redirected_to studio_generations_path
      @user.reload
      assert @user.linkedin_connected?
      assert_equal "member-123", @user.linkedin_member_urn
    ensure
      Faraday.define_singleton_method(:post, original_post)
      Faraday.define_singleton_method(:get, original_get)
    end
  end

  test "disconnect clears the stored token" do
    @user.update!(linkedin_access_token: "token", linkedin_token_expires_at: 60.days.from_now,
                  linkedin_member_urn: "member-123")

    delete linkedin_auth_disconnect_path
    assert_redirected_to studio_generations_path
    assert_not @user.reload.linkedin_connected?
    assert_nil @user.linkedin_member_urn
  end

  private

  def session_state
    session[:linkedin_oauth_state]
  end
end
