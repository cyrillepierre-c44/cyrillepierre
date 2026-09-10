# Sitemap dynamique : les actus s'y ajoutent d'elles-mêmes à la publication. Un fichier
# statique aurait vieilli dès la première actu écrite depuis le Studio.
class SitemapsController < ApplicationController
  # Les pages fixes du site, avec leur priorité relative. `changefreq` et `priority` ne sont
  # que des indications, mais elles disent aux robots par où commencer.
  STATIC_PAGES = [
    { path: :root_path,         priority: "1.0", changefreq: "monthly" },
    { path: :operations_path,   priority: "0.9", changefreq: "monthly" },
    { path: :leadership_path,   priority: "0.9", changefreq: "monthly" },
    { path: :tech_path,         priority: "0.9", changefreq: "monthly" },
    { path: :realisations_path, priority: "0.9", changefreq: "monthly" },
    { path: :cv_path,           priority: "0.7", changefreq: "monthly" },
    { path: :actus_path,        priority: "0.7", changefreq: "weekly" },
    { path: :contact_path,      priority: "0.6", changefreq: "yearly" },
    { path: :legal_path,        priority: "0.2", changefreq: "yearly" },
    { path: :privacy_path,      priority: "0.2", changefreq: "yearly" }
  ].freeze

  def show
    @actus = Generation.published_on_site
    # La date de la dernière publication fait office de fraîcheur du site : sans elle, les
    # pages fixes n'auraient aucune date et les robots les recracheraient à leur rythme.
    @site_updated_at = @actus.first&.published_at || Time.current

    respond_to(&:xml)
  end
end
