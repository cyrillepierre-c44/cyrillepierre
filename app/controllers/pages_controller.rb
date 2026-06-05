class PagesController < ApplicationController
  def home; end
  def operations; end
  def leadership; end
  def tech; end
  def realisations; end

  def cv
    render layout: false
  end
end
