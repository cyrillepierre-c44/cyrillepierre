# Le manifeste doit rester relisable. Servi depuis public/, il héritait du cache d'un an posé
# par `config.public_file_server.headers` sur tout le dossier : un nom ou une icône corrigés
# n'atteignaient jamais un téléphone qui avait déjà installé le site. Une route permet de lui
# donner son propre en-tête.
class PwaController < ApplicationController
  MANIFEST_CACHE = 1.hour

  def manifest
    expires_in MANIFEST_CACHE, public: true
    render json: {
      # `name` est la phrase de la boîte d'installation : « Installer … ». Une accroche
      # commerciale y sonne comme une publicité système ; le nom seul se lit comme une
      # application ordinaire. L'accroche reste sur le site, à sa place.
      name: "Cyrille PIERRE",
      short_name: "Cyrille PIERRE",
      description: "Manager de transition et consultant en excellence opérationnelle, basé à Lyon.",
      start_url: "/",
      scope: "/",
      display: "standalone",
      lang: "fr",
      background_color: "#050a15",
      theme_color: "#050a15",
      icons: [
        { src: "/icon-192-v3.png", sizes: "192x192", type: "image/png", purpose: "any" },
        { src: "/icon-512-v3.png", sizes: "512x512", type: "image/png", purpose: "any" },
        { src: "/icon-maskable-512-v4.png", sizes: "512x512", type: "image/png", purpose: "maskable" }
      ]
    }
  end
end
