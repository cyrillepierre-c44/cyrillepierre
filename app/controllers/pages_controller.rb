class PagesController < ApplicationController
  # La page CV est volontairement autonome : pas de layout, tout son CSS et son JS sont inline,
  # avec des gestionnaires `onclick`/`onchange` dans le HTML. Un nonce ne couvre pas les
  # gestionnaires inline, et cette page n'affiche aucune donnée saisie par un visiteur : sa
  # surface d'injection est nulle. On lève donc la CSP pour elle seule plutôt que de réécrire
  # 700 lignes qui fonctionnent.
  content_security_policy false, only: :cv

  def home; end
  def operations; end
  def leadership; end
  def tech; end
  def realisations; end
  def legal; end
  def privacy; end

  def cv
    render layout: false
  end
end
