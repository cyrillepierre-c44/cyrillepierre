require "test_helper"

module Studio
  class GenerationsControllerTest < ActionDispatch::IntegrationTest
    setup do
      @editor = User.create!(email: "editor@example.com", password: "password123", role: :editor)
      @other_editor = User.create!(email: "other@example.com", password: "password123", role: :editor)
      @admin = User.create!(email: "admin@example.com", password: "password123", role: :admin)
      @generation = Generation.create!(user: @editor, kind: :linkedin_post)
    end

    test "redirects to sign in when not authenticated" do
      get studio_generations_path
      assert_redirected_to new_user_session_path
    end

    test "editor can list their own generations" do
      sign_in @editor
      get studio_generations_path
      assert_response :success
    end

    test "editor cannot view another editor's generation" do
      sign_in @other_editor
      get studio_generation_path(@generation)
      assert_response :not_found
    end

    test "admin can view any generation" do
      sign_in @admin
      get studio_generation_path(@generation)
      assert_response :success
    end

    test "create triggers content generation and redirects to show" do
      sign_in @editor
      original_call = ContentGenerator.method(:call)
      ContentGenerator.define_singleton_method(:call) do |generation|
        generation.update!(output: "stubbed", status: :generated)
      end

      begin
        assert_difference("Generation.count", 1) do
          post studio_generations_path, params: { generation: { kind: "linkedin_post", input_text: "hello" } }
        end

        assert_redirected_to studio_generation_path(Generation.last)
      ensure
        ContentGenerator.define_singleton_method(:call, original_call)
      end
    end

    test "create also generates a visual when generate_visual is checked" do
      sign_in @editor
      original_content_call = ContentGenerator.method(:call)
      original_visual_call = VisualGenerator.method(:call)
      ContentGenerator.define_singleton_method(:call) do |generation|
        generation.update!(output: "stubbed", status: :generated)
      end
      visual_called = false
      VisualGenerator.define_singleton_method(:call) { |_generation| visual_called = true }

      begin
        post studio_generations_path,
             params: { generation: { kind: "linkedin_post", input_text: "hello", generate_visual: "1" } }
        assert visual_called
      ensure
        ContentGenerator.define_singleton_method(:call, original_content_call)
        VisualGenerator.define_singleton_method(:call, original_visual_call)
      end
    end

    test "create does not generate a visual when generate_visual is unchecked" do
      sign_in @editor
      original_content_call = ContentGenerator.method(:call)
      original_visual_call = VisualGenerator.method(:call)
      ContentGenerator.define_singleton_method(:call) do |generation|
        generation.update!(output: "stubbed", status: :generated)
      end
      visual_called = false
      VisualGenerator.define_singleton_method(:call) { |_generation| visual_called = true }

      begin
        post studio_generations_path, params: { generation: { kind: "linkedin_post", input_text: "hello" } }
        assert_not visual_called
      ensure
        ContentGenerator.define_singleton_method(:call, original_content_call)
        VisualGenerator.define_singleton_method(:call, original_visual_call)
      end
    end

    test "generate_visual triggers VisualGenerator and redirects to show" do
      generation = Generation.create!(user: @editor, kind: :linkedin_post, status: :generated, output: "Un post.")
      sign_in @editor

      original_call = VisualGenerator.method(:call)
      called_with = nil
      VisualGenerator.define_singleton_method(:call) { |g| called_with = g }

      begin
        patch generate_visual_studio_generation_path(generation)
        assert_redirected_to studio_generation_path(generation)
        assert_equal generation, called_with
      ensure
        VisualGenerator.define_singleton_method(:call, original_call)
      end
    end

    test "editor cannot generate a visual for another editor's generation" do
      generation = Generation.create!(user: @other_editor, kind: :linkedin_post, status: :generated, output: "Un post.")
      sign_in @editor

      patch generate_visual_studio_generation_path(generation)
      assert_response :not_found
    end

    test "only admin can publish a site_actu" do
      site_actu = Generation.create!(user: @editor, kind: :site_actu, status: :generated, output: "text")

      sign_in @editor
      patch publish_studio_generation_path(site_actu)
      assert_redirected_to root_path
      assert_not site_actu.reload.published?

      sign_in @admin
      patch publish_studio_generation_path(site_actu)
      assert_redirected_to studio_generation_path(site_actu)
      assert site_actu.reload.published?
    end
  end
end
