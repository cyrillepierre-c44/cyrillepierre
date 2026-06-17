class ActusController < ApplicationController
  def index
    @actus = Generation.published_site_actus
  end

  def show
    @actu = Generation.published_site_actus.find(params[:id])
  end
end
