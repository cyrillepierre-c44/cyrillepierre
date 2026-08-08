require "test_helper"

class SecurityHeadersTest < ActionDispatch::IntegrationTest
  test "sends a Content Security Policy on public pages" do
    get root_path

    csp = response.headers["content-security-policy"]
    assert csp.present?, "aucun en-tête Content-Security-Policy"
    assert_includes csp, "default-src 'self'"
    assert_includes csp, "object-src 'none'"
  end

  test "allows the external origins the site actually loads" do
    get root_path
    csp = response.headers["content-security-policy"]

    # Google Fonts : importé par app/assets/stylesheets/config/_fonts.scss
    assert_includes csp, "https://fonts.googleapis.com"
    assert_includes csp, "https://fonts.gstatic.com"
    # esm.sh : le paquet `marked` épinglé dans config/importmap.rb
    assert_includes csp, "https://esm.sh"
    # Cloudinary : fichiers Active Storage et visuels du Studio
    assert_includes csp, "https://res.cloudinary.com"
  end

  test "script-src carries a nonce and no unsafe-inline" do
    get root_path
    csp = response.headers["content-security-policy"]

    script_src = csp.split(";").find { |directive| directive.strip.start_with?("script-src") }
    assert script_src.present?, "pas de directive script-src"
    assert_includes script_src, "nonce-"
    refute_includes script_src, "unsafe-inline",
                    "un nonce et 'unsafe-inline' sont incompatibles : les navigateurs ignorent le second"
  end

  # Le garde-fou qui compte : la balise <script type="importmap"> est inline. Sans nonce sur
  # cette balise, tout le JavaScript du site (Turbo, Stimulus, Bootstrap) serait bloqué.
  test "the inline importmap tag is signed with the nonce" do
    get root_path

    nonce = response.headers["content-security-policy"][/nonce-([^']+)/, 1]
    assert nonce.present?, "pas de nonce dans l'en-tête CSP"
    assert_match(/<script[^>]+type="importmap"[^>]+nonce="#{Regexp.escape(nonce)}"/, response.body)
  end

  # Le risque classique des nonces : une revalidation qui renvoie 304 ferait réutiliser au
  # navigateur un corps en cache dont le nonce ne correspond plus à l'en-tête, et tous les
  # scripts inline seraient bloqués. Ici le nonce est dans le corps, donc l'ETag change avec
  # lui : une 304 ne peut jamais servir un corps au nonce périmé.
  test "a fresh nonce per response makes a stale-nonce 304 impossible" do
    get root_path
    first_etag = response.headers["etag"]
    first_nonce = response.headers["content-security-policy"][/nonce-([^']+)/, 1]
    assert first_etag.present?, "pas d'ETag sur la réponse"

    get root_path, headers: { "HTTP_IF_NONE_MATCH" => first_etag }

    assert_response :success, "l'ETag devrait avoir changé avec le nonce, donc pas de 304"
    refute_equal first_etag, response.headers["etag"]
    refute_equal first_nonce, response.headers["content-security-policy"][/nonce-([^']+)/, 1]
  end

  # Page autonome, tout son CSS/JS est inline avec des gestionnaires onclick : la CSP y est
  # volontairement levée (aucune donnée visiteur n'y est affichée).
  test "the standalone CV page opts out of the policy" do
    get cv_path

    assert_response :success
    assert_nil response.headers["content-security-policy"]
  end
end
