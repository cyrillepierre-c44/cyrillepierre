# Publishes a Generation's LinkedIn post (text + optional visual) directly to the connected
# user's LinkedIn profile, via LinkedIn's Posts API.
class LinkedinPublisher
  API_BASE = "https://api.linkedin.com"
  # LinkedIn deprecates API versions after ~12 months — bump this at least once a year
  # (format YYYYMM, current month is generally safe).
  LINKEDIN_VERSION = "202606"

  class Error < StandardError; end

  def self.call(generation)
    new(generation).call
  end

  def initialize(generation)
    @generation = generation
    @user = generation.user
  end

  def call
    raise Error, "Compte LinkedIn non connecté ou expiré." unless user.linkedin_connected?
    raise Error, "Aucun texte à publier." if generation.output.blank?

    image_urn = upload_visual if generation.visual.attached?
    create_post(image_urn)
    generation.update!(linkedin_published_at: Time.current)
    generation
  end

  private

  attr_reader :generation, :user

  def author_urn
    "urn:li:person:#{user.linkedin_member_urn}"
  end

  def rest_headers
    {
      "Authorization" => "Bearer #{user.linkedin_access_token}",
      "LinkedIn-Version" => LINKEDIN_VERSION,
      "X-Restli-Protocol-Version" => "2.0.0",
      "Content-Type" => "application/json"
    }
  end

  def post_body(image_urn)
    body = {
      author: author_urn,
      commentary: LinkedinTextFormatter.call(generation.output),
      visibility: "PUBLIC",
      distribution: { feedDistribution: "MAIN_FEED" },
      lifecycleState: "PUBLISHED",
      isReshareDisabledByAuthor: false
    }
    body[:content] = { media: { id: image_urn } } if image_urn
    body
  end

  def create_post(image_urn)
    response = Faraday.post("#{API_BASE}/rest/posts", post_body(image_urn).to_json, rest_headers)
    raise Error, error_message(response) unless response.success?
  end

  def upload_visual
    upload = initialize_upload
    Faraday.put(upload.fetch("uploadUrl"), generation.visual.download,
                "Authorization" => "Bearer #{user.linkedin_access_token}")
    upload.fetch("image")
  end

  def initialize_upload
    response = Faraday.post(
      "#{API_BASE}/rest/images?action=initializeUpload",
      { initializeUploadRequest: { owner: author_urn } }.to_json,
      rest_headers
    )
    raise Error, error_message(response) unless response.success?

    JSON.parse(response.body).fetch("value")
  end

  def error_message(response)
    detail = begin
      JSON.parse(response.body)["message"]
    rescue JSON::ParserError
      response.body
    end
    "Erreur LinkedIn (#{response.status}) : #{detail}"
  end
end
