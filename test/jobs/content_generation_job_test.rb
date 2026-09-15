require "test_helper"

class ContentGenerationJobTest < ActiveSupport::TestCase
  setup do
    @user = User.create!(email: "job-gen@example.com", password: "password123")
    @generation = Generation.create!(user: @user, kind: :linkedin_post, generating_since: Time.current)
  end

  test "it generates the content and releases the waiting state" do
    ContentGenerator.stub(:call, ->(g) { g.update!(output: "généré", status: :generated) }) do
      ContentGenerationJob.perform_now(@generation)
    end

    assert_equal "généré", @generation.reload.output
    assert_nil @generation.generating_since
  end

  test "it generates the visual only when asked" do
    called = false
    ContentGenerator.stub(:call, ->(_g) {}) do
      VisualGenerator.stub(:call, ->(_g) { called = true }) do
        ContentGenerationJob.perform_now(@generation)
        assert_not called

        ContentGenerationJob.perform_now(@generation, with_visual: true)
        assert called
      end
    end
  end

  # Sans cette garantie, un échec laisserait la page annoncer une génération éternelle.
  test "a failure still releases the waiting state" do
    ContentGenerator.stub(:call, ->(_g) { raise "la passerelle est tombée" }) do
      assert_raises(RuntimeError) { ContentGenerationJob.perform_now(@generation) }
    end

    assert_nil @generation.reload.generating_since
  end
end
