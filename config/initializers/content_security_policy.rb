# Be sure to restart your server when you modify this file.

# Content Security Policy — défense en profondeur contre l'injection de scripts.
# Voir https://guides.rubyonrails.org/security.html#content-security-policy-header
#
# Les origines externes autorisées ci-dessous correspondent exactement à ce que le site
# charge : les ajouter au coup par coup plutôt que d'ouvrir `:https` en grand.
Rails.application.configure do
  config.content_security_policy do |policy|
    policy.default_src      :self
    policy.base_uri         :self
    policy.object_src       :none
    policy.frame_ancestors  :self
    policy.form_action      :self

    # `:unsafe_inline` est nécessaire pour les attributs `style="..."` présents dans plusieurs
    # vues ; fonts.googleapis.com sert la feuille de style importée par
    # app/assets/stylesheets/config/_fonts.scss (Space Grotesk + Inter).
    policy.style_src  :self, :unsafe_inline, "https://fonts.googleapis.com"
    policy.font_src   :self, :data, "https://fonts.gstatic.com"

    # esm.sh héberge le paquet `marked` épinglé dans config/importmap.rb (rendu du Markdown
    # dans le chatbot de contact). Pas de `:unsafe_inline` ici : la balise importmap, qui est
    # inline, est signée par le nonce configuré plus bas.
    policy.script_src :self, "https://esm.sh"

    # Cloudinary sert les fichiers Active Storage et les visuels générés par le Studio.
    policy.img_src    :self, :data, "https://res.cloudinary.com"

    policy.connect_src :self
  end

  # Nonce aléatoire par réponse, et surtout PAS `request.session.id` (la suggestion par défaut
  # du template Rails) : aucune page publique de ce site n'écrit en session, donc `session.id`
  # y vaut `nil`. Le nonce sortirait vide (`'nonce-'`), et un nonce vide dans `script-src`
  # bloque toute balise inline — la balise `<script type="importmap">` avec elle, donc Turbo,
  # Stimulus et Bootstrap. Voir test/controllers/security_headers_test.rb.
  #
  # Effet de bord assumé : le nonce figurant dans le corps de la page, l'ETag change à chaque
  # réponse et le cache conditionnel du HTML ne joue plus. C'est ce qui rend l'approche sûre
  # (impossible de servir une 304 dont le corps porte un nonce périmé), et le coût est faible :
  # `must-revalidate, max-age=0` imposait déjà un aller-retour réseau à chaque navigation, seuls
  # les octets du corps sont retransmis.
  config.content_security_policy_nonce_generator = ->(_request) { SecureRandom.base64(16) }
  config.content_security_policy_nonce_directives = %w[script-src]

  # Ajoute automatiquement le nonce aux balises générées par `javascript_importmap_tags`.
  config.content_security_policy_nonce_auto = true
end
