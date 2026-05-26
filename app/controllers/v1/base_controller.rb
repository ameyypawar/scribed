module V1
  class BaseController < ApplicationController
    include ApiAuthenticatable
    include ErrorEnvelope

    before_action :authenticate!
  end
end
