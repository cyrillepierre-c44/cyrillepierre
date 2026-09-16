# Qui est derrière le site, pour tout ce qui doit le dire : balisage schema.org, pied de page,
# mentions légales, mails. Ces valeurs étaient recopiées dans chaque gabarit — le téléphone en
# trois formats différents. Une adresse qui change se change ici, et les tests de `seo_test.rb`
# vérifient qu'elle arrive bien dans le balisage et le pied de page.
module SiteIdentity
  NAME = "Cyrille PIERRE".freeze
  # L'apex répond 301 vers www : toute adresse déclarée doit désigner www.
  HOST = "https://www.cyrillepierre.com".freeze
  DESCRIPTION = "Cyrille PIERRE — Manager de transition et consultant en excellence " \
                "opérationnelle. Ingénieur Arts & Métiers, 20 ans d'industrie. Lyon.".freeze
  EMAIL = "contact@cyrillepierre.com".freeze
  PHONE_E164 = "+33618022452".freeze
  PHONE_DISPLAY = "06 18 02 24 52".freeze
  LINKEDIN_URL = "https://www.linkedin.com/in/cyrille-pierre".freeze
  # Public et vérifié depuis le 15/09/2026 : n'y mettre qu'une adresse que Google peut lire.
  MALT_URL = "https://www.malt.fr/profile/cyrillepierre".freeze
end
