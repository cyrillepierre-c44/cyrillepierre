require "test_helper"

module Studio
  class GenerationsControllerLinkedinTest < ActionDispatch::IntegrationTest
    setup do
      @editor = User.create!(email: "editor@example.com", password: "password123", role: :editor)
      @other_editor = User.create!(email: "other@example.com", password: "password123", role: :editor)
    end

    test "publish_to_linkedin triggers LinkedinPublisher and redirects to show" do
      generation = Generation.create!(user: @editor, kind: :linkedin_post, status: :generated, output: "Un post.")
      sign_in @editor

      original_call = LinkedinPublisher.method(:call)
      called_with = nil
      LinkedinPublisher.define_singleton_method(:call) { |g| called_with = g }

      begin
        patch publish_to_linkedin_studio_generation_path(generation)
        assert_redirected_to studio_generation_path(generation)
        assert_equal generation, called_with
      ensure
        LinkedinPublisher.define_singleton_method(:call, original_call)
      end
    end

    test "publish_to_linkedin shows an alert when LinkedinPublisher raises" do
      generation = Generation.create!(user: @editor, kind: :linkedin_post, status: :generated, output: "Un post.")
      sign_in @editor

      original_call = LinkedinPublisher.method(:call)
      LinkedinPublisher.define_singleton_method(:call) { |_g| raise LinkedinPublisher::Error, "compte non connecté" }

      begin
        patch publish_to_linkedin_studio_generation_path(generation)
        assert_redirected_to studio_generation_path(generation)
        assert_equal "compte non connecté", flash[:alert]
      ensure
        LinkedinPublisher.define_singleton_method(:call, original_call)
      end
    end

    test "editor cannot publish another editor's generation to linkedin" do
      generation = Generation.create!(user: @other_editor, kind: :linkedin_post, status: :generated, output: "Un post.")
      sign_in @editor

      patch publish_to_linkedin_studio_generation_path(generation)
      assert_response :not_found
    end
  end
end
