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
    post_urn = create_post(image_urn)
    generation.update!(linkedin_published_at: Time.current, linkedin_post_urn: post_urn)
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

    response.headers["x-restli-id"]
  end

  def upload_visual
    upload = initialize_upload
    put_response = Faraday.put(upload.fetch("uploadUrl"), generation.visual.download,
                                "Authorization" => "Bearer #{user.linkedin_access_token}",
                                "Content-Type" => "application/octet-stream")
    raise Error, "Échec de l'envoi de l'image vers LinkedIn (#{put_response.status})." unless put_response.success?

    image_urn = upload.fetch("image")
    wait_for_image_ready(image_urn)
    image_urn
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

  # LinkedIn processes an uploaded image asynchronously (PROCESSING -> AVAILABLE) — referencing
  # it in a post immediately after the PUT can attach a not-yet-ready image, silently producing
  # a broken/invisible post even though post creation itself returns 201. Poll briefly; if the
  # status endpoint isn't accessible (some scopes don't allow reading it back), fall back to a
  # short flat wait instead of failing the whole publish.
  def wait_for_image_ready(image_urn)
    5.times do
      status = fetch_image_status(image_urn)
      return if status == "AVAILABLE"

      sleep 1
    end
  end

  def fetch_image_status(image_urn)
    encoded = URI.encode_www_form_component(image_urn)
    response = Faraday.get("#{API_BASE}/rest/images/#{encoded}", nil, rest_headers)
    return nil unless response.success?

    JSON.parse(response.body)["status"]
  rescue Faraday::Error
    nil
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
