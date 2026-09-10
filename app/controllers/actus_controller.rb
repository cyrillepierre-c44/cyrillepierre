class ActusController < ApplicationController
  def index
    @actus = Generation.published_on_site
  end

  def show
    @actu = Generation.published_on_site.find(params[:id])
  end
end
